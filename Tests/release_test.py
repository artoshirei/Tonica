import base64
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release', Path(__file__).resolve().parents[1] / 'scripts/release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)

class ReleaseValidationTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.directory = Path(self.scratch.name)
        (self.directory / 'Tonica.dmg').write_bytes(b'candidate archive')
        self.xml = '''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:version>7</sparkle:version><sparkle:shortVersionString>1.1.0</sparkle:shortVersionString><sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion><enclosure url="https://github.com/artoshirei/Tonica/releases/download/v1.1.0/Tonica.dmg" length="17" sparkle:edSignature="signature"/></item></channel></rss>'''
        self.metadata = dict(tag='v1.1.0', version='1.1.0', build=7, notarized=True, sha256=release.digest(self.directory / 'Tonica.dmg'))
        self.write_feed(self.xml)
    def write_feed(self, xml):
        (self.directory / 'appcast.xml').write_text(xml)
        self.metadata['appcast_sha256'] = release.digest(self.directory / 'appcast.xml')
    def test_valid_metadata_reaches_signature_verification(self):
        with patch.object(release, 'verify_signature') as verify:
            release.verify_candidate(self.directory, self.metadata)
            verify.assert_called_once()
    def test_tampered_archive_is_rejected(self):
        (self.directory / 'Tonica.dmg').write_bytes(b'changed')
        with self.assertRaisesRegex(RuntimeError, 'archive changed'):
            release.verify_candidate(self.directory, self.metadata)
    def test_wrong_version_url_and_length_are_rejected(self):
        for before, after, reason in [('>7<', '>6<', 'build mismatch'), ('/v1.1.0/', '/v1.0.5/', 'archive URL'), ('length="17"', 'length="18"', 'length mismatch')]:
            with self.subTest(reason=reason):
                self.write_feed(self.xml.replace(before, after))
                with self.assertRaisesRegex(RuntimeError, reason):
                    release.verify_candidate(self.directory, self.metadata)
    def test_modified_feed_is_rejected(self):
        (self.directory / 'appcast.xml').write_text(self.xml + '\n')
        with self.assertRaisesRegex(RuntimeError, 'appcast changed'):
            release.verify_candidate(self.directory, self.metadata)
    def test_release_notes_must_exist_in_commit(self):
        repo = self.directory / 'repo'; repo.mkdir()
        def git(*args, **kwargs):
            return subprocess.run(args, cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
        git('git', 'init', '-q')
        notes = repo / 'docs/release-notes/1.1.0.md'; notes.parent.mkdir(parents=True)
        notes.write_text('Release notes')
        with patch.object(release, 'run', side_effect=git):
            with self.assertRaises(subprocess.CalledProcessError):
                release.require_committed_notes('1.1.0')
            git('git', 'add', '.')
            git('git', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture')
            release.require_committed_notes('1.1.0')
            with self.assertRaises(subprocess.CalledProcessError):
                release.require_committed_notes('1.1.1')
    def test_actual_ed25519_signature_and_modified_bytes(self):
        openssl = '/opt/homebrew/opt/openssl@3/bin/openssl'
        key, pub, sig = [self.directory / name for name in ['private.pem', 'public.der', 'signature']]
        archive = self.directory / 'Tonica.dmg'
        subprocess.run([openssl, 'genpkey', '-algorithm', 'ED25519', '-out', str(key)], check=True, capture_output=True)
        subprocess.run([openssl, 'pkey', '-in', str(key), '-pubout', '-outform', 'DER', '-out', str(pub)], check=True, capture_output=True)
        subprocess.run([openssl, 'pkeyutl', '-sign', '-inkey', str(key), '-rawin', '-in', str(archive), '-out', str(sig)], check=True, capture_output=True)
        signature = base64.b64encode(sig.read_bytes()).decode()
        public = base64.b64encode(pub.read_bytes()[-32:]).decode()
        release.verify_signature(archive, signature, public)
        archive.write_bytes(b'tampered')
        with self.assertRaises(subprocess.CalledProcessError):
            release.verify_signature(archive, signature, public)
