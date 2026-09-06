---
name: ship-stable-macos-tonica
description: Build, publish, recover, or verify Tonica stable releases.
---

Read `docs/agents/releases.md` before shipping. It is the authoritative local release contract, adapted from FowlCode.

Run `./scripts/release.sh --dry-run`, then `preflight`. Commit release notes before `patch|minor|major`. Build stops before publication. Publish only the completed candidate with `publish vX.Y.Z`, then run `verify vX.Y.Z` when checking live status.

Keep the bundle ID, Sparkle key, feed URL, and monotonic build number. No CI, no interactive worktrees, no second bump for recovery, no overwritten public artifacts. Existing shipping authorization covers immediate iterations of this workflow.
