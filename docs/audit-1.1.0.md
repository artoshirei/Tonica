# Tonica 1.1.0 audit

The app is rebuilt in AppKit, including its entrypoint, circle, instrument views, settings, and window lifecycle. The permanent bundle identity, compiled Icon Composer asset, Sparkle feed, and signing key are preserved.

## Findings fixed

| Area | Previous behavior | Result |
| --- | --- | --- |
| Idle work | Installed 1.0.4 used 21 to 22% CPU in three idle samples; sampling showed continuous status item drawing | Static template symbol. Preview measured 0.0% in three open and three hidden samples |
| Selection | Hover, pin, preview, expanded, and collapsed states competed | One selected key and one chord degree; navigation never changes on hover |
| Instrument use | Theory reference without an instrument view | Two octave piano and standard guitar fretboard, scale/chord/root highlights and note playback |
| Harmony | F#/Gb title mixed F# notes with two signatures | Consistent F# major / D# minor spelling and enharmonic matching at neighboring keys |
| Copy feedback | Confirmation replaced progression labels permanently | All three copy buttons restore their labels after 1.5 seconds; repeated clicks restart the delay and key changes cancel stale feedback |
| Keyboard shortcut | Startup restored the default when users cleared their shortcut | The library's first-use default is retained; cleared shortcuts stay disabled |
| Window | Large fixed SwiftUI composition and asynchronous hide completion | Native resizable window, saved/clamped frame, synchronous hide/show, Escape and standard window commands |
| Settings | Theme and shortcut only | Permanent near-black app and Settings; launch, always-on-top, shortcut, login, and update controls |
| Focus | Native control could become the initial responder | Explicit focusable root view; controls acquire focus through user navigation |
| Menu bar | Open a menu before revealing the circle; continual animation | Click to toggle the circle; right-click for settings, updates, about, and quit |
| Development | Debug app could construct its production updater | Debug builds cannot self-update; preview also has a separate bundle/preferences domain and no feed |
| Releases | CI candidate/publish machinery and overwrite-capable asset upload | Local tagged source export, universal signed/notarized candidate, explicit immutable publication |
| Update verification | URL availability without checking version or bytes | Pinned Ed25519, metadata, byte length, exact SHA-256, version and anonymous feed verification |

## Verification

* Debug and universal Release builds passed. `lipo` confirmed arm64 and x86_64.
* Theory checks cover 24 scales, 168 diatonic triads, ascending playback including octave completion, enharmonic equivalence, and all 12 neighboring key pairs.
* Six release tests cover metadata validation, changed archive/feed rejection, incorrect build/URL/length rejection, real Ed25519 verification with modified-byte rejection, and a real git fixture proving release notes are committed before the bump.
* Production Developer ID, the `fowl-notary` profile, and a probe signed by the original Tonica key passed preflight.
* Sol drove the isolated native preview, with its exact bundle path and AppKit title verified: C, G, F#, D# minor, diminished chord, piano/guitar, scale/chord highlights, settings controls, keep-on-top, Escape, Cmd-W, and minimum window layout.
* At the observed minimum outer width of 994 pixels, F# major and D# minor chord rows fit; the detail pane scrolls vertically.

* Fable 5.1 at high effort reviewed the complete change and a focused followup. No substantive findings remained after copy, focus, piano layout, and committed release note fixes.
* The final near-black app and Settings were rebuilt and driven on the isolated native preview. All three copy buttons, repeated copying, selection changes, instrument modes, and menu bar reopen passed. Settings has no Appearance picker.
* LLDB traced negative geometry logs to AppKit positioning the CUA window sharing indicator, with no Tonica frames. A separate AppKit layout recursion warning did not reproduce with its breakpoint armed.

The instrument diagrams use standard guitar tuning and major/natural minor scales. The minor view explicitly describes raising degree 7 for harmonic minor. This release does not add alternate tunings, a metronome, or a microphone tuner.

A published feed and cryptographically valid archive prove update availability. A previous-version installation and relaunch is a separate verification layer and must be reported separately.
