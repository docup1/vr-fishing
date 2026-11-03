# dddpix PixelArt Renderer

`PixelArtRenderer` is a Godot addon that renders selected 3D scene content through a low-resolution pixel animation pipeline.

## Install

### Godot Asset Store

1. Open your existing Godot project.
2. Open the Godot Asset Store when using Godot 4.7+ or the store website.
3. Search for `dddpix PixelArt Renderer`.
4. Download and install the addon.
5. Enable `dddpix PixelArt Renderer` in `Project > Project Settings > Plugins`.

For Godot 4.5 and 4.6 projects, use the addon-only ZIP while the Asset Store integration rolls out.

### Addon-only ZIP

1. Download the addon-only release ZIP.
2. Extract it into your project so the files land at `addons/pixel_art_renderer`.
3. Enable `dddpix PixelArt Renderer` in `Project > Project Settings > Plugins`.

Do not copy this repository's `project.godot` into an existing project. Production projects only need the addon folder.

## Wrap An Existing Scene

1. Open a scene in your project.
2. Select the 3D world, camera, and light nodes that should be pixel-rendered.
3. Run `Project > Tools > dddpix > Wrap Selection With PixelArtRenderer`.
4. Choose a preset on the new `PixelArtRenderer` node.

The selected nodes move under:

```text
PixelArtRenderer
└─ PixelSubViewport
   └─ ViewportRoot
```

Leave UI nodes outside `PixelArtRenderer` to keep them crisp.

## Manual Setup

1. Add a `PixelArtRenderer` node to a scene.
2. Expand `PixelSubViewport`.
3. Add 3D content, a `Camera3D`, and lights under `ViewportRoot`.
4. Pick one of the built-in presets:
   - `clean_pixel.tres`
   - `dithered_retro.tres`
   - `strong_outline.tres`
5. Run the scene.

## MVP Limits

- The wrap action targets `Node3D` content.
- No automatic whole-project migration.
- No object or layer bypass.
- No depth-aware outline.
- No video import.
- No sprite sheet export.
- No palette editor.
