# FocusWater App Icon Spec

## Creative direction

The icon should feel closer to Apple's health, utility, and productivity apps than to a playful Android-style app.

Core visual goals:

- Clean silhouette
- Strong legibility at small sizes
- Soft liquid-glass depth, not noisy realism
- Premium blue-water palette
- Minimal elements, ideally one bottle and one water-level cue

## Recommended concept

Use a single centered bottle as the main symbol:

- Rounded bottle silhouette
- Frosted glass body
- Bright water fill inside
- Cork only visible in the "filled" interpretation if you want to echo the product concept
- No text, no number labels, no tiny decorative bubbles

Suggested composition:

- Background: soft aqua-to-sky gradient
- Bottle: translucent white / icy glass
- Water: luminous cyan-blue gradient
- Highlight: one restrained vertical gloss streak

## What to avoid

- Too many reflections
- Tiny details that disappear below 64 px
- Dark gray muddy backgrounds
- Realistic shadows that make the icon feel heavy
- Android-style saturated outlines
- Multiple objects competing for attention

## Color direction

Recommended palette:

- Light top: `#DFF5FF`
- Mid blue: `#7CCBFF`
- Deep water blue: `#2E7DF6`
- Glass white: `rgba(255,255,255,0.78)`
- Edge highlight: `rgba(255,255,255,0.92)`

Dark-mode marketing variant if desired:

- Background top: `#0D1622`
- Background bottom: `#18324F`
- Water glow: `#62C8FF`

## Icon layout guidance

- Keep the bottle at roughly 62% to 70% of canvas height
- Keep safe padding around the silhouette
- Bias the water shape slightly upward for better small-size recognition
- Favor a single dominant read over literal UI accuracy

## Export requirements

Primary source recommendation:

- 1024 x 1024 master artwork
- Vector or very high resolution raster source

Needed outputs:

- App Store marketing icon: `1024 x 1024`
- macOS icon family through asset catalog
- iPhone/iPad icon outputs through asset catalog

## Asset catalog slots to fill

Current app icon set lives at:

- `FocusWater/Resources/Assets.xcassets/AppIcon.appiconset/`

Prepare files for these sizes:

- macOS: `16, 32, 128, 256, 512` plus `@2x`
- iOS marketing: `1024`

## Designer handoff prompt

If you want to brief a human designer or image model, use this:

"Design a premium Apple-style productivity app icon for FocusWater. Show one centered translucent glass bottle with glowing blue water inside on a soft aqua gradient background. The bottle should feel smooth, minimal, elegant, and highly legible at small sizes. Avoid text, avoid clutter, avoid cartoon styling, and avoid Android-like heavy contrast. The overall feel should be calm, polished, and modern."

## Review checklist

- Can you recognize the bottle at 32 px?
- Does it still read clearly without the cork detail?
- Does it feel native next to Apple utility apps?
- Is the center shape strong enough without extra decoration?
- Does the icon still look premium on both light and dark system backgrounds?
