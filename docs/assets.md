# Artwork and previews

All artwork is bundled locally; runtime rendering never downloads assets or runs an image model.

| Files in `Sources/TypingCompanion/Resources/` | Role |
| --- | --- |
| `Mochi.png`, `Keycat.png`, `Pip Bot.png`, `Spark Keycat.png` | Original character/reference illustrations |
| `* Reference Rig.png` | Current runtime body and separate left/right paw sprite atlases |
| `* Body.png`, `* Rig.png` | Earlier source cutouts/rig variants, retained for further art editing |

Illustrations were created for this project with image generation. Native Swift rendering supplies the live keyboard geometry, counter text, surface materials and animation. Atlas regions and alpha padding are handled when sprites load; pixels are not decoded per animation frame.

The README PNGs and GIF under `docs/images/` are reproducible renders of the app’s own view, using scripted poses and illustrative totals. They contain no real user activity, private preferences or display captures. See [preview commands](implementation.md#reproducing-previews).
