# Tonica 1.2.0 audit

A playability and polish release on the 1.1.0 AppKit app. No change to bundle identity, Sparkle feed, signing key, or the local release pipeline.

## Findings fixed

| Area | Previous behavior | Result |
| --- | --- | --- |
| Toggle | Shortcut and menu bar click hid a window that was only buried behind other apps or left on another Space | Hides only when Tonica is in focus on the active Space, or kept on top. Otherwise it comes forward |
| Menu title | Right-click menu could say Hide while minimized or hidden | Title is recomputed when the menu opens, from the same rule as the toggle |
| Labels | Every label was selectable: text cursor over headings, and a click moved keyboard focus into a field editor | Labels are not selectable. The scale has a Copy button instead |
| Audio | Each new sound deallocated the previous player mid-wave, which can click | Single notes overlap. Chords and phrases fade earlier sound out over 50 ms |
| Scale card | Degree numbers were a separate string in a smaller font and did not line up with notes | Seven fixed columns, note above degree |
| Copy feedback | Title was replaced, so buttons changed width and progression labels vanished during feedback | Icon becomes a checkmark, width is held, VoiceOver announces the copy |
| Instrument mode | Scale or Chord was forgotten on relaunch | Saved like the instrument choice |

## Added

Click to hear chords, play buttons for progressions, keyboard control with an on-screen hint, hover feedback on the circle, emphasized inlay fret numbers.

## Verification

* Theory checks now also prove all 48 suggested progressions resolve to playable chords in their key.
* The synth's real output was analyzed offline for a note, chord, scale and progression: expected pitches at expected onsets, no clipped samples, silent final sample, 8 to 62 ms to render in an unoptimized build.
* The isolated preview was driven through app-scoped accessibility actions and key events sent only to its process: arrows, Up and Down, 1 to 7, keys with focus inside the scroll pane, all copy buttons with measured frames before, during and after feedback, progression and note playback without errors, Settings unchanged.
* Toggle branches proven on the running preview: not in focus brings forward, in focus hides, hidden shows, kept on top hides without focus. The status item window reports `canBecomeKeyWindow = 0` in the live process, so a physical click cannot take focus from the panel before the toggle runs.
* Hover rendering was inspected with a temporary probe, since removed. Synthetic pointer moves do not reach AppKit tracking areas, so hover routing from a physical pointer, and how playback sounds, remain for a person to confirm.

## Published release

On 2026-09-20, version 1.2.0 (build 8) was built from tag `v1.2.0`, commit `23864b57f1ea563b9bbc2d8783f0fe230580f3b7`, exported through `git archive`. Both architectures, Developer ID signing, hardened runtime, app and DMG notarization and stapling, and Gatekeeper assessment passed.

The immutable DMG is 3,439,780 bytes, SHA-256 `3aa2cbc7371de96309a5e8b61380ae31f372ae06c3cffc70d616107285d08a73`. After publication, the exact and latest public downloads were fetched anonymously and both matched these bytes. The live feed reports 1.2.0 (8) with the matching length, and the publisher verified its pinned Ed25519 signature.

The candidate build waited at a keychain dialog: `generate_appcast` needed approval to use the Sparkle key, although `sign_update` in preflight was already allowed. It continued after approval with no rebuild. Choosing Always Allow for `generate_appcast` removes this wait.

Two publish attempts stopped before any upload because the only address DNS returned for github.com dropped most connections. Nothing was published by them. The same candidate was then published at the same tag with github.com pinned to a healthy GitHub address through environment variables for that run only. TLS verification was unchanged. No second bump, no replaced artifact.

A real Sparkle update from an installed 1.1.0 and the relaunch into 1.2.0 were not exercised.
