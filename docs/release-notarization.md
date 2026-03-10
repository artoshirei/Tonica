# Notarized Release Setup

Tonica ships as a notarized DMG attached to GitHub Releases.

Stable public download URL:

- `https://github.com/artemiscosmo/Tonica/releases/latest/download/Tonica.dmg`

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

## Release Workflow

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Run `xcodegen generate` and commit the generated project changes.
3. Push the commit.
4. Tag the release commit as `v<version>`.
5. Push the tag.

GitHub Actions will build, notarize, package, and publish `Tonica.dmg`.

`workflow_dispatch` stays available as a manual republish path from `main`.

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

