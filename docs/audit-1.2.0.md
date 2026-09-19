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
