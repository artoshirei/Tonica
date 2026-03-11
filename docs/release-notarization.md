# Notarized Release Setup

Tonica ships as a notarized DMG attached to GitHub Releases.

Stable public download URL:

- `https://github.com/artoshirei/Tonica/releases/latest/download/Tonica.dmg`

Stable Sparkle appcast URL:

- `https://raw.githubusercontent.com/artoshirei/Tonica/main/docs/appcast.xml`

The release flow:

1. builds a signed Release archive with the `Developer ID Application` certificate,
2. exports the signed `Tonica.app`,
3. notarizes and staples the app bundle,
4. builds the styled DMG from the stapled app,
5. notarizes and staples the DMG,
6. uploads `Tonica.dmg` to the matching GitHub Release.

## One-Time GitHub Secrets

- `APPLE_DEVELOPER_ID_APPLICATION_CERT_P12`
  Base64-encoded `.p12` export of the `Developer ID Application` certificate.
- `APPLE_DEVELOPER_ID_APPLICATION_CERT_PASSWORD`
  Password used when exporting that `.p12`.
- `APPLE_DEVELOPER_ID_APPLICATION_IDENTITY`
  Exact certificate common name:
  `Developer ID Application: Artur Karapetyan (XSBK4ZK282)`.
- `APPLE_TEAM_ID`
  Apple Developer Team ID: `XSBK4ZK282`.
- `APPLE_NOTARY_API_KEY_P8`
  Raw contents of the App Store Connect API key `.p8` file.
- `APPLE_NOTARY_KEY_ID`
  App Store Connect API key ID.
- `APPLE_NOTARY_ISSUER_ID`
  App Store Connect issuer ID for that key.
- `SPARKLE_PRIVATE_ED_KEY`
  Exported private Sparkle EdDSA key text from `generate_keys -x`.

## Preferred Human Workflow

Use the repo wrapper instead of replaying the workflow by hand:

```bash
cd /Users/argo/Projects/Playground/Tonica

./scripts/ship_stable.sh --dry-run
./scripts/ship_stable.sh patch
```

Other release modes:

- `./scripts/ship_stable.sh minor`
- `./scripts/ship_stable.sh major`
- `./scripts/ship_stable.sh candidate --ref <git-ref>`
- `./scripts/ship_stable.sh republish --tag vX.Y.Z --version X.Y.Z`

What the wrapper does for `patch|minor|major`:

1. Fails fast on a dirty tree.
2. Reads the current version/build from `project.yml`.
3. Bumps `MARKETING_VERSION` and increments the monotonic `CURRENT_PROJECT_VERSION` by exactly `1`.
4. Runs `xcodegen generate`.
5. Commits `project.yml` plus the generated project change together.
6. Pushes the release commit.
7. Dispatches `.github/workflows/build-candidate.yml` with the exact commit/version/tag.
8. Waits for candidate success.
9. Pushes tag `v<version>`.
10. Lets `.github/workflows/release.yml` publish stable from that candidate artifact.
11. Verifies the GitHub Release DMG, latest-download DMG URL, and raw GitHub appcast URL.

Recovery rules:

- Never assume `push main` publishes stable.
- Never bump the version twice to recover a bad release.
- Use `republish --tag vX.Y.Z --version X.Y.Z` for same-version recovery.
- `republish` does not create a new tag and does not bump the version.

`--no-wait` stays conservative:

- for `candidate`, it skips waiting for candidate completion
- for `republish`, it skips waiting for stable publish completion
- for `patch|minor|major`, it still waits for candidate success before tagging, then skips only the final stable publish wait

## Local Signed Build

For a local notarized release:

```bash
cd /Users/argo/Projects/Playground/Tonica

APPLE_NOTARY_KEYCHAIN_PROFILE=<profile> \
./scripts/build_release.sh
```

The helper also supports:

- `APPLE_NOTARY_API_KEY_PATH` + `APPLE_NOTARY_KEY_ID` + optional `APPLE_NOTARY_ISSUER_ID`
- `APPLE_ID` + `APPLE_APP_SPECIFIC_PASSWORD` + `APPLE_TEAM_ID`

Output artifacts land in `dist/`.
