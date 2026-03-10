Mac App Store Readiness Audit

Current status on 2026-03-10:
- The app builds locally in Debug.
- The app is not yet submit-ready for the Mac App Store.
- Biggest blockers: signing, sandbox validation, empty app icon catalog, App Store metadata, and lack of tests.

What changed in this pass:
- Added structured `OSLog` logging for launch, hot key registration, activation-policy changes, and panel presentation.
- Added explicit hot key registration failure handling so silent startup failures are now diagnosable.
- Fixed enharmonic comparison logic so shared notes/chords are correct across `F#/Gb` and flat/sharp neighbors.
- Added a sandbox entitlements file and wired `CODE_SIGN_ENTITLEMENTS` into the project config.

Ship-today checklist:
- [ ] Add real app icons to `Assets.xcassets/AppIcon.appiconset`.
- [ ] In Xcode, select a valid Apple Developer team and turn signing on for the Release archive workflow.
- [ ] Archive a Release build with App Sandbox enabled and verify the hot key still registers inside the sandbox.
- [ ] Create the app record in App Store Connect.
- [ ] Set pricing in App Store Connect using the current paid-app pricing tiers.
- [ ] Complete App Privacy answers in App Store Connect.
- [ ] Prepare the store listing: description, subtitle, keywords, support URL, marketing URL, and screenshots.
- [ ] Run manual QA on the core loop: launch, menu bar presence, hot key reveal/hide, panel close, multi-display placement, and behavior while a DAW is frontmost.
- [ ] Add at least one small test target for circle data correctness and enharmonic/shared-material logic.

Product/UX improvements to queue after submission prep:
- Reduce how aggressively the app steals focus from whatever the musician is using.
- Add keyboard navigation and better accessibility labels for the custom circle.
- Add copy/export affordances for progressions and chords.
- Add spelling preferences for sharps vs flats.
- Clarify where the theory model is intentionally simplified, especially on minor-key function.

Relevant Apple references reviewed on 2026-03-10:
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App Sandbox capability: https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox
- Distribute outside or through App Store overview: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
- App Privacy details in App Store Connect: https://developer.apple.com/app-store/app-privacy-details/

Notes:
- This repo still has an empty `Assets.xcassets` directory, so icon work remains a hard blocker.
- Sandboxing is now scaffolded, but it still needs a real signed archive test before submission.
