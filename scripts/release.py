#!/usr/bin/env python3
"""Local candidate build, immutable GitHub artifact, appcast published last."""
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REPO = 'artoshirei/Tonica'
FEED = f'https://raw.githubusercontent.com/{REPO}/main/docs/appcast.xml'
PUBLIC_KEY = 'iEPxBBVp6WlGL9yXXVqoVAh9N1+GKsWHpun1jzHEWuU='
SPARKLE = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'

def run(*args, cwd=ROOT, capture=False, env=None):
    result = subprocess.run([str(x) for x in args], cwd=cwd, check=True, text=True, stdout=subprocess.PIPE if capture else None, stderr=subprocess.PIPE if capture else None, env=env)
    return result.stdout.strip() if capture else None

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def fetch(url, path):
    run('curl', '--fail', '--silent', '--show-error', '--location', '--retry', '3', '--output', path, url)

def identity():
    source = (ROOT / 'project.yml').read_text()
    return re.search(r'MARKETING_VERSION: (\S+)', source)[1], int(re.search(r'CURRENT_PROJECT_VERSION: (\d+)', source)[1])

def live_build(directory):
    path = Path(directory) / 'live-appcast.xml'
    fetch(FEED, path)
    versions = [int(v.text) for v in ET.parse(path).findall(f'.//{SPARKLE}version')]
    require(versions, 'The live appcast has no build number. Inspect it before releasing.')
    return max(versions)

def clean_main():
    require(run('git', 'branch', '--show-current', capture=True) == 'main', 'Release from main.')
    require(not run('git', 'status', '--porcelain', '--untracked-files=no', capture=True), 'Commit tracked changes before releasing.')
    # Untracked local research cannot enter a git archive. Untracked source must not be silently omitted.
    untracked = run('git', 'ls-files', '--others', '--exclude-standard', '--', 'Sources', 'Resources', 'Assets.xcassets', 'scripts', 'Tests', 'docs/release-notes', 'project.yml', 'Tonica-Info.plist', capture=True)
    require(not untracked, f'Commit these build inputs first:\n{untracked}')
    run('git', 'fetch', 'origin', 'main', '--tags')
    require(run('git', 'rev-parse', 'HEAD', capture=True) == run('git', 'rev-parse', 'origin/main', capture=True), 'Push main before releasing; local HEAD must equal origin/main.')

def verify_signature(archive, signature, public_key=PUBLIC_KEY):
    openssl = '/opt/homebrew/opt/openssl@3/bin/openssl'
    if not Path(openssl).exists():
        openssl = shutil.which('openssl')
    require(openssl and run(openssl, 'version', capture=True).startswith('OpenSSL'), 'OpenSSL with Ed25519 support is required.')
    with tempfile.TemporaryDirectory(prefix='tonica-signature-') as scratch:
        key, sig = Path(scratch) / 'key.der', Path(scratch) / 'signature'
        key.write_bytes(bytes.fromhex('302a300506032b6570032100') + base64.b64decode(public_key, validate=True))
        sig.write_bytes(base64.b64decode(signature, validate=True))
        run(openssl, 'pkeyutl', '-verify', '-pubin', '-inkey', key, '-keyform', 'DER', '-rawin', '-in', archive, '-sigfile', sig, capture=True)

def sparkle_tool(name):
    for folder in ['.build', '.build-preview', '.derived_ci']:
        path = ROOT / folder / 'SourcePackages/artifacts/sparkle/Sparkle/bin' / name
        if path.exists():
            return path
    raise RuntimeError('Build Tonica first to resolve Sparkle tools.')

def preflight():
    require('Developer ID Application: Artur Karapetyan (XSBK4ZK282)' in run('security', 'find-identity', '-v', '-p', 'codesigning', capture=True), 'The production Developer ID identity is missing.')
    run('xcrun', 'notarytool', 'history', '--keychain-profile', os.environ.get('APPLE_NOTARY_KEYCHAIN_PROFILE', 'fowl-notary'), capture=True)
    with tempfile.TemporaryDirectory(prefix='tonica-key-check-') as scratch:
        probe = Path(scratch) / 'probe'; probe.write_text('Tonica release key verification')
        signature = run(sparkle_tool('sign_update'), '--account', 'tonica', '-p', probe, capture=True)
        verify_signature(probe, signature)
    print('Signing identity, notarization, and the existing Tonica Sparkle key verified.', flush=True)

def verify_candidate(directory, metadata):
    archive = directory / 'Tonica.dmg'
    require(digest(archive) == metadata['sha256'], 'Candidate archive changed after signing.')
    require(digest(directory / 'appcast.xml') == metadata['appcast_sha256'], 'Candidate appcast changed after verification.')
    require(metadata['notarized'] is True, 'Candidate was not notarized.')
    feed = ET.parse(directory / 'appcast.xml')
    items = feed.findall('.//item')
    require(len(items) == 1, 'Candidate appcast must contain exactly one release.')
    item = items[0]; enclosure = item.find('enclosure')
    require(item.findtext(f'{SPARKLE}version') == str(metadata['build']), 'Appcast build mismatch.')
    require(item.findtext(f'{SPARKLE}shortVersionString') == metadata['version'], 'Appcast version mismatch.')
    require(enclosure.get('url') == f'https://github.com/{REPO}/releases/download/{metadata["tag"]}/Tonica.dmg', 'Unexpected archive URL.')
    require(int(enclosure.get('length')) == archive.stat().st_size, 'Appcast archive length mismatch.')
    require(item.findtext(f'{SPARKLE}minimumSystemVersion') in ['14.0', '14.0.0'], 'Unexpected minimum macOS version.')
    verify_signature(archive, enclosure.get(f'{SPARKLE}edSignature'))

def require_committed_notes(version, ref='HEAD'):
    path = f'docs/release-notes/{version}.md'
    run('git', 'cat-file', '-e', f'{ref}:{path}', capture=True)


def build(tag):
    clean_main()
    version, build_number = identity()
    require(tag == f'v{version}', 'Candidate tag must match project.yml.')
    require_committed_notes(version, tag)
    commit = run('git', 'rev-parse', f'{tag}^{{commit}}', capture=True)
    require(commit == run('git', 'rev-parse', 'HEAD', capture=True), 'Build the tag at the current clean main commit.')
    directory = ROOT / '.release' / tag
    require(not (directory / 'metadata.json').exists(), f'Candidate already exists. Run ./scripts/release.sh publish {tag}.')
    directory.mkdir(parents=True, exist_ok=True)
    require(build_number > live_build(directory), 'Build number must exceed the live feed. Never bump twice to recover a failed publish.')
    preflight()
    with tempfile.TemporaryDirectory(prefix='tonica-release-source-') as scratch:
        source = Path(scratch)
        archive = source / 'source.tar'
        run('git', 'archive', '--format=tar', '--output', archive, tag)
        run('tar', '-xf', archive, '-C', source)
        archive.unlink()
        run(source / 'scripts/test.sh', cwd=source)
        env = dict(os.environ, DIST_DIR=str(directory / 'build'), DERIVED_DATA_PATH=str(ROOT / '.derived_ci'), APPLE_NOTARY_KEYCHAIN_PROFILE=os.environ.get('APPLE_NOTARY_KEYCHAIN_PROFILE', 'fowl-notary'))
        run(source / 'scripts/build_release.sh', cwd=source, env=env)
        app = directory / 'build/export/Tonica.app'
        plist = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        for key, expected in [('CFBundleIdentifier', 'com.playground.tonica'), ('CFBundleVersion', str(build_number)), ('CFBundleShortVersionString', version), ('SUPublicEDKey', PUBLIC_KEY), ('SUFeedURL', FEED)]:
            require(plist.get(key) == expected, f'Built app has incorrect {key}.')
        require(set(run('lipo', '-archs', app / 'Contents/MacOS/Tonica', capture=True).split()) == {'arm64', 'x86_64'}, 'Both Mac architectures must ship.')
        signing = subprocess.run(['codesign', '-dv', '--verbose=4', str(app)], capture_output=True, text=True, check=True).stderr
        require('runtime' in signing and 'TeamIdentifier=XSBK4ZK282' in signing, 'Hardened runtime or production signing team missing.')
        run('codesign', '--verify', '--deep', '--strict', app)
        run('xcrun', 'stapler', 'validate', app)
        shutil.copy2(directory / 'build/Tonica.dmg', directory / 'Tonica.dmg')
        run('xcrun', 'stapler', 'validate', directory / 'Tonica.dmg')
        run(ROOT / 'scripts/generate_appcast.sh', directory / 'Tonica.dmg', directory / 'appcast.xml', f'https://github.com/{REPO}/releases/download/{tag}/', f'https://github.com/{REPO}/releases/tag/{tag}')
        shutil.copy2(source / f'docs/release-notes/{version}.md', directory / 'release-notes.md')
    metadata = dict(tag=tag, version=version, build=build_number, commit=commit, sha256=digest(directory / 'Tonica.dmg'), appcast_sha256=digest(directory / 'appcast.xml'), notarized=True, xcode=run('xcodebuild', '-version', capture=True))
    verify_candidate(directory, metadata)
    (directory / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'Candidate ready: {directory}\nNothing published. Next: ./scripts/release.sh publish {tag}', flush=True)

def publish(tag):
    clean_main()
    directory = ROOT / '.release' / tag
    metadata = json.loads((directory / 'metadata.json').read_text())
    require(metadata['tag'] == tag and metadata['version'] == tag[1:], 'Candidate identity mismatch.')
    require(metadata['commit'] == run('git', 'rev-parse', f'{tag}^{{commit}}', capture=True), 'Tag no longer matches candidate.')
    run('git', 'merge-base', '--is-ancestor', metadata['commit'], 'HEAD')
    verify_candidate(directory, metadata)
    require(metadata['build'] >= live_build(directory), 'Refusing to replace a newer live feed.')
    run('git', 'push', 'origin', tag)
    result = subprocess.run(['gh', 'release', 'view', tag, '--repo', REPO, '--json', 'assets,isDraft,targetCommitish'], capture_output=True, text=True)
    if result.returncode == 0:
        release = json.loads(result.stdout)
        require(not release['isDraft'], 'Inspect the existing draft release before continuing.')
        require(any(asset['name'] == 'Tonica.dmg' for asset in release['assets']), 'Existing release has no DMG. Inspect it before recovery.')
    else:
        # Fail on authentication/network errors; only a confirmed missing tag release permits creation.
        run('gh', 'api', f'repos/{REPO}', capture=True)
        releases = json.loads(run('gh', 'release', 'list', '--repo', REPO, '--limit', '1000', '--json', 'tagName', capture=True))
        require(not any(r['tagName'] == tag for r in releases), 'Release lookup failed. Retry before publishing.')
        run('gh', 'release', 'create', tag, directory / 'Tonica.dmg', '--repo', REPO, '--verify-tag', '--title', f'Tonica {metadata["version"]}', '--notes-file', directory / 'release-notes.md', '--latest')
    with tempfile.TemporaryDirectory(prefix='tonica-live-') as scratch:
        downloaded = Path(scratch) / 'Tonica.dmg'
        for url in [f'https://github.com/{REPO}/releases/download/{tag}/Tonica.dmg', f'https://github.com/{REPO}/releases/latest/download/Tonica.dmg']:
            fetch(url, downloaded)
            require(digest(downloaded) == metadata['sha256'], f'Public archive differs from candidate: {url}. Never overwrite published bytes.')
    # GitHub serves Tonica's existing feed directly from main. This is the final public write.
    run('git', 'fetch', 'origin', 'main')
    require(run('git', 'rev-parse', 'HEAD', capture=True) == run('git', 'rev-parse', 'origin/main', capture=True), 'Main changed during publication. Synchronize before publishing the feed.')
    target = ROOT / 'docs/appcast.xml'
    if target.read_bytes() != (directory / 'appcast.xml').read_bytes():
        shutil.copy2(directory / 'appcast.xml', target)
        run('git', 'add', 'docs/appcast.xml')
        run('git', 'commit', '-m', f'Publish Sparkle update for {tag}')
        run('git', 'push', 'origin', 'main')
    verify_live(tag, directory, metadata)

def verify_live(tag, directory, metadata):
    with tempfile.TemporaryDirectory(prefix='tonica-feed-') as scratch:
        path = Path(scratch) / 'appcast.xml'
        for attempt in range(13):
            fetch(FEED, path)
            if path.read_bytes() == (directory / 'appcast.xml').read_bytes():
                break
            require(attempt < 12, 'Public appcast is still cached. Retry verify after the GitHub cache expires; do not bump.')
            print('Waiting for GitHub raw appcast cache to refresh…', flush=True)
            time.sleep(25)
        enclosure = ET.parse(path).find('.//enclosure')
        archive = Path(scratch) / 'Tonica.dmg'; fetch(enclosure.get('url'), archive)
        require(archive.stat().st_size == int(enclosure.get('length')), 'Live archive length differs from feed.')
        require(digest(archive) == metadata['sha256'], 'Live archive differs from candidate.')
        verify_signature(archive, enclosure.get(f'{SPARKLE}edSignature'))
        run('curl', '--fail', '--silent', '--show-error', '--location', '--head', FEED)
    print(f'LIVE: Tonica {metadata["version"]} ({metadata["build"]})\nhttps://github.com/{REPO}/releases/tag/{tag}\n{FEED}', flush=True)

def main():
    args = sys.argv[1:]
    require(args, 'Usage: release.sh --dry-run | preflight | patch|minor|major | candidate vX.Y.Z | publish vX.Y.Z | verify vX.Y.Z')
    mode = args[0]
    if mode == '--dry-run':
        version, number = identity()
        print(f'Local Tonica release from {ROOT}\nCurrent: {version} ({number}). Next build: {number + 1}.\nClean committed main → immutable source archive → tests → universal Developer ID app → notarized app and DMG → verified Sparkle appcast → STOP.\nPublish separately: GitHub DMG first, verify bytes, existing raw appcast last. No worktrees or CI.')
    elif mode == 'preflight':
        preflight()
    elif mode in ['patch', 'minor', 'major']:
        clean_main(); preflight()
        version, number = identity()
        parts = [int(v) for v in version.split('.')]
        at = ['major', 'minor', 'patch'].index(mode); parts[at] += 1
        for index in range(at + 1, 3): parts[index] = 0
        version = '.'.join(map(str, parts)); tag = f'v{version}'
        require_committed_notes(version)
        require(subprocess.run(['git', 'rev-parse', '--verify', tag], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0, 'Tag already exists. Use candidate/publish to recover.')
        with tempfile.TemporaryDirectory() as scratch:
            require(number + 1 > live_build(scratch), 'Next build would not exceed the live feed.')
        path = ROOT / 'project.yml'
        source = re.sub(r'MARKETING_VERSION: \S+', f'MARKETING_VERSION: {version}', path.read_text())
        path.write_text(re.sub(r'CURRENT_PROJECT_VERSION: \d+', f'CURRENT_PROJECT_VERSION: {number + 1}', source))
        run('xcodegen', 'generate'); run('git', 'add', 'project.yml', 'Tonica.xcodeproj/project.pbxproj')
        run('git', 'commit', '-m', f'Release {tag}'); run('git', 'push', 'origin', 'main'); run('git', 'tag', tag)
        build(tag)
    else:
        require(len(args) == 2 and re.fullmatch(r'v\d+\.\d+\.\d+', args[1]), 'Specify an exact vX.Y.Z tag.')
        tag = args[1]
        if mode == 'candidate': build(tag)
        elif mode == 'publish': publish(tag)
        elif mode == 'verify':
            directory = ROOT / '.release' / tag
            verify_live(tag, directory, json.loads((directory / 'metadata.json').read_text()))
        else: raise RuntimeError('Unknown release command.')

if __name__ == '__main__':
    try:
        # One writer across build and publish, released automatically on exit.
        import fcntl
        (ROOT / '.release').mkdir(exist_ok=True)
        with (ROOT / '.release/lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            main()
    except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError) as error:
        print(f'Release stopped: {error}', file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr[-2000:], file=sys.stderr)
        sys.exit(1)
