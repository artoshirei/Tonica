# Tonica Notes

- This app is a macOS menu bar utility. Prefer the explicit AppKit `NSStatusItem` in [StatusBarController.swift](/Users/argo/Projects/Playground/Tonica/Sources/StatusBarController.swift) over SwiftUI `MenuBarExtra`; `MenuBarExtra` proved unreliable here after rebuild/relaunch and could appear "missing" even while the process was alive.
- Official mac app icon source lives in [Resources/Tonica.icon](/Users/argo/Projects/Playground/Tonica/Resources/Tonica.icon). Keep it as a direct `.icon` file reference in `project.yml`; do not expand it into loose SVG resources or tuck it inside `Assets.xcassets`, or Xcode will stop emitting the real compiled app icon.
- The old PNG app icon set is parked in [LegacyAssets/AppIcon.appiconset.bak](/Users/argo/Projects/Playground/Tonica/LegacyAssets/AppIcon.appiconset.bak) and should stay out of `Assets.xcassets` so it does not compete with the Icon Composer asset.
- Keep the menu bar symbol geometry aligned to the official layered assets, but do not reuse the full square app icon treatment for the tiny status item.
- When asked to relaunch/debug the menu bar item:
  verify the process with `pgrep -alf Tonica`
  inspect recent logs with `/usr/bin/log show --last 5m --predicate 'process == "Tonica"' --style compact`
  rebuild with `xcodegen generate` then `xcodebuild -project Tonica.xcodeproj -scheme Tonica -configuration Debug -derivedDataPath .build clean build`
  relaunch with `open -n /Users/argo/Projects/Playground/Tonica/.build/Build/Products/Debug/Tonica.app`
