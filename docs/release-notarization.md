# Release and notarization

Tonica now builds and publishes locally. The authoritative workflow, signing invariants, recovery commands, and verification gates are in [agents/releases.md](agents/releases.md).

Start with `./scripts/release.sh --dry-run`. Build with `patch`, `minor`, or `major`; publish the completed candidate with `publish vX.Y.Z`.
