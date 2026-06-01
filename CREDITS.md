# Credits & Asset Licenses

Third-party assets bundled with the demo, with their sources and licenses.

## Fonts

- **Nunito** — `assets/fonts/Nunito.ttf`
  - Source: [Google Fonts](https://github.com/google/fonts/tree/main/ofl/nunito)
  - License: SIL Open Font License 1.1 (OFL)
  - Used as the project's default UI / body font.

- **Silkscreen** — `assets/fonts/Silkscreen.ttf`
  - Source: [Google Fonts](https://github.com/google/fonts/tree/main/ofl/silkscreen)
  - License: SIL Open Font License 1.1 (OFL)
  - Used for the pixel-art-style game title and screen headers.

## Audio

- **"Chester"** (piano) — `assets/audio/ambient_piano.ogg`
  - Source: [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Chester.ogg)
  - License: Public Domain
  - Used as the looping ambient background track.

## Pixel art

- **Backgrounds, alter portraits, and autumn leaves** — `assets/art/*.png`
  - Original assets, generated procedurally by `tools/gen_pixel_art.gd` (Godot
    `Image` API). Re-run `godot --headless res://tools/gen_pixel_art.tscn` to
    regenerate. No external license — original to this project.

---

Panels and HUD elements are styled with Godot `StyleBoxFlat`. Pixel-art textures use
nearest-neighbour filtering (`texture_filter = Nearest`) for crisp scaling.
