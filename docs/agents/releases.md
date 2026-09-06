# Tonica releases

Tonica uses the local candidate and publish flow from FowlCode. No GitHub Actions or release runner is involved. Run from the saved project on main.

```
./scripts/release.sh --dry-run
./scripts/release.sh preflight
./scripts/release.sh minor
./scripts/release.sh publish v1.1.0
./scripts/release.sh verify v1.1.0
```

The build command stops after producing a verified candidate. Publish promotes those exact bytes. A push to main alone never publishes an update. The old `ship_stable.sh` entrypoint forwards to the local command.

## Permanent app identity

* `project.yml` owns the marketing version and monotonic integer build number. Increment build by one per release. Regenerate and commit the Xcode project with each version bump.
* Bundle: `com.playground.tonica`. Team: `XSBK4ZK282`.
* Feed: `https://raw.githubusercontent.com/artoshirei/Tonica/main/docs/appcast.xml`.
* Archive: `https://github.com/artoshirei/Tonica/releases/download/vX.Y.Z/Tonica.dmg`.
* Latest alias: `https://github.com/artoshirei/Tonica/releases/latest/download/Tonica.dmg`.
* Existing Sparkle public key: `iEPxBBVp6WlGL9yXXVqoVAh9N1+GKsWHpun1jzHEWuU=`. Private key stays in the login keychain under account `tonica`. Never generate or rotate a key during release.
* Notarization profile: `fowl-notary`, overridable with `APPLE_NOTARY_KEYCHAIN_PROFILE`.

## Build gates

1. Tracked source is clean, all build inputs are committed, and HEAD equals origin/main. Untracked local research is excluded from the exported source.
2. Commit `docs/release-notes/X.Y.Z.md` before the bump command. The command bumps once, regenerates the project, commits, pushes main, and creates the local tag.
3. Source is exported with `git archive` from that exact tag. This respects the project rule against interactive worktrees. Nothing from untracked files enters the build.
4. Verify the production Developer ID, notarization credentials, and a probe signed by Tonica's existing Sparkle key before building.
5. Run theory and release validation tests. Build both arm64 and x86_64. Validate bundle identity, feed, key, version, hardened runtime, and architecture.
6. Sign the exported app's outer bundle after the icon fallback is added. Preserve Xcode's nested Sparkle signatures. Never sign with `--deep`.
7. Notarize, staple, and validate both app and DMG. Gatekeeper assesses the actual output.
8. Generate appcast only after final packaging. Verify its version, URL, length, and Ed25519 signature against the pinned key.
9. Save the immutable candidate, appcast, notes, metadata, archive, dSYMs, and build diagnostics in `.release/vX.Y.Z/`.

## Publish gates

Verify candidate checksums, signature, tag commit, and build number again. Upload the DMG to GitHub without overwriting an existing asset. Download both exact and latest URLs anonymously and compare SHA-256. Only then commit and push the generated appcast to main. Refetch the public appcast and enclosure, verify version, length, hash, and signature. A lock prevents concurrent local publishers.

A feed cache delay is not a new release. Verification retries the real raw URL for five minutes. If it remains stale, retry `verify` after the cache expires. Never bump twice to recover.

If building fails, fix the setup and retry `candidate vX.Y.Z` at the same tag. If publishing fails, retry `publish vX.Y.Z`. Existing public DMGs must match the candidate byte for byte; the publisher refuses to overwrite them.

## App verification

`./script/build_and_run.sh --verify` builds an isolated preview with a distinct bundle identity and preferences. Its updater feed is removed, updater construction and login registration are disabled, and no global shortcut is registered. It never quits the installed production app.

Before shipping, use the preview to inspect keys, triads, instrument notes, dark appearance, resizing, window lifecycle, and menu bar actions. Then inspect the production candidate and test the real previous version's Sparkle update when a separate user or Mac is available. Do not claim an installation was verified from feed checks alone.
