# Avatar assets

Drop your cyberpunk-girl avatar here. The app picks files up by exact filename.

## Option A — Static + procedural reactions (simplest)

A single still image. The app applies SwiftUI animations on top (scale pulse on click, rotate-bounce on new notification).

```
Avatar/khan-avatar.png            // 256×256 px, transparent PNG
```

Use an AI image generator with this prompt:

> A cute cyberpunk girl avatar mascot, neon pink and cyan accents, holographic visor, tech-wear hoodie, glowing earrings, three-quarter portrait, transparent background, sticker style, sharp vector lines, glowing edges, K-pop / Vocaloid aesthetic, 256×256 square crop, head and shoulders.

Run that through Midjourney / Nano Banana / SDXL / DALL-E — pick the best, ask for a transparent-background PNG, drop it here.

## Option B — Sprite sheet (more reactive)

Multiple frames per state. App scrubs through frames on state changes.

```
Avatar/khan-avatar-idle-1.png     // looped breathing, 4–8 frames
Avatar/khan-avatar-idle-2.png
Avatar/khan-avatar-idle-3.png
...
Avatar/khan-avatar-click-1.png    // wave / blink, 4–6 frames played once
Avatar/khan-avatar-click-2.png
...
Avatar/khan-avatar-notify-1.png   // surprised pop, 4–6 frames
...
```

## Option C — Lottie animation (smoothest)

A single Lottie JSON per state. Best quality, requires Lottie SDK.

```
Avatar/khan-avatar-idle.json
Avatar/khan-avatar-click.json
Avatar/khan-avatar-notify.json
```

Sources:
- lottiefiles.com — search "cyber girl" / "anime mascot"
- Generate via Rive (https://rive.app) — interactive state machine, perfect for this
- Commission on Fiverr / Upwork (~$30–80 per state)

To enable Lottie: add `lottie-ios` SPM dep to KhanMacChrome, switch `AnchorAvatarView` to use `LottieView` (one-line change).

## Current default

If no asset is found, the app falls back to a procedural neon-glyph avatar (stylized "K" with cyan glow). The state-reaction animations still apply.
