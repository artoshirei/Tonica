# Tonica Website Prompt

Use this prompt with the separate frontend web model for `artoshi.work`.

## Prompt

Build a very minimal product page for Tonica that fits the existing `artoshi.work` style.

Context:

- This is for `artoshi.work/tonica`.
- The stable download button URL should be `https://artoshi.work/tonica/download`.
- That download route will redirect to `https://github.com/artemiscosmo/Tonica/releases/latest/download/Tonica.dmg`.
- Tonica is a macOS menu bar music theory utility.
- Primary audience: musicians, producers, and songwriters who want a clean circle-of-fifths helper always available from the menu bar.

Visual direction:

- Match the current `artoshi.work` visual language, not generic SaaS.
- Use the same overall palette and typography feel as the existing site:
  - black background
  - restrained light text
  - subtle warm accent only if needed
  - `Instrument Sans` and `IBM Plex Mono`
- Reference `t3.codes` only for confidence and simplicity, not for copying layout or style.
- Keep it extremely sparse and elegant.
- No feature grid.
- No testimonials.
- No pricing.
- No startup tone.
- No busy gradients.
- No marketing fluff.

Page structure:

1. Small top area with a back link to the main site or work index.
2. Hero block with:
   - Tonica app icon
   - product name `Tonica`
   - one short description
   - primary CTA: `Download for macOS`
   - one quiet install note below the button:
     `Signed and notarized macOS app. Drag Tonica into Applications after opening the DMG.`
3. One preview image only:
   - a single screenshot of the main Tonica panel
   - large but still restrained
   - framed cleanly, no carousel, no browser chrome
4. Optional tiny footer note with platform support:
   - `macOS 14+`

Tone:

- Calm
- precise
- understated
- design-forward
- no hype

Suggested copy:

- Title: `Tonica`
- Description: `A fast circle-of-fifths companion for macOS, always one shortcut away from the menu bar.`
- CTA: `Download for macOS`

Implementation notes:

- Build this as a dedicated route for `artoshi.work/tonica`.
- Add a redirect for `artoshi.work/tonica/download` to the GitHub latest-release DMG URL.
- Make desktop and mobile both feel intentional.
- Motion should be subtle: short fade/slide entrance only.
- Keep spacing generous.
- The icon should come from Tonica’s existing app icon assets.
- Use exactly one screenshot, not multiple.

Output:

- Return the page implementation and any route/redirect changes needed for Astro on `artoshi.work`.
