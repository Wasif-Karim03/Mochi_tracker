# Typing Companion

## Purpose and stack

Local macOS typing companion. Native Swift Package with AppKit, Core Graphics listen-only event tap, Carbon Secure Input status, ImageIO wallpaper sampling. Minimum macOS 13; Swift language mode 5 under tools version 6.0. No third-party dependencies or network runtime.

## Key paths

- `Sources/CompanionCore/TypingLedger.swift`: daily aggregate accounting and estimated energy above rest.
- `Sources/TypingCompanion/`: panel, menu, settings, monitoring and rendering.
- `Sources/TypingCompanion/Resources/`: approved character cutouts and transparent body/paw sprite atlases.
- `Tests/CompanionCoreTests/`: accounting, held-key and shared keyboard-projection tests.
- `scripts/build-app.sh`: release bundle; `SIGNING_IDENTITY` chooses an existing certificate (default ad-hoc). Preserve the installed certificate identity for permission continuity. `dist/` is generated.

## Constraints

Never log, translate into text, persist or transmit key payloads. Physical key codes may be used transiently in memory for the user-requested matching paw/keycap animation; retain only currently held/briefly displayed positions, clearing on monitoring gaps. Count non-repeated key-down events only, independently of animation. Permission must be granted by the user. Do not request Screen Recording merely to improve text contrast. Keep the floating panel nonactivating. Preview uses a separate scene and must never count as typing or release a real held key. Calories require optional user weight and must remain explicitly estimated above rest; never invent a calories-per-key conversion. Preserve the four selected character identities. All four follow the supplied original character references with independently animated matching paws and full Mac key geometry: lavender Mochi, cream/gold cats, cream/mint Pip Bot. A shared two-column instrument-style counter plate sits close below the keyboard, with solid matte ivory/graphite surfaces, a fine rim, larger digits and subdued line icons. The transparent canvas is square; footer must fit at size180. Current key geometry is the user's verified US ANSI Mac layout; don't claim other layouts or media/Touch ID support.

## Verified local commands

Run from the project root: `swift test` for accounting regression tests; `bash scripts/build-app.sh` for the release bundle and signature verification. The installed app is `~/Applications/Typing Companion.app`. `bash scripts/render-previews.sh .build/previews` renders offline AppKit snapshots; append `--gif` for the scripted demo. See `docs/implementation.md` for edge-case commands. A macOS GUI session is required.

## Discovery

Hugging Face connected search failed; a brief public read-only Hub API query found no useful addition for this native UI app. No model or Hub dependency selected. See `docs/huggingface-discovery.md`.
