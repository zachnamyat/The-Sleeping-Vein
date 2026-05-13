# 00 — Tile & Atlas Spec

> **Why this doc exists.** All Gemini-generated tiles must drop into Godot **without rescaling, hand-cleanup, or misalignment**. That requires every asset to obey one canonical pixel grid. This document is that grid.
>
> If you skip this doc, every tilemap will fight you forever. Read it before generating a single asset.

---

## 1. The canonical grid

**Base tile = 16 × 16 pixels.** Non-negotiable.

Everything is measured in **base tiles (`bt`)** or **base pixels (`bp`)**. `1 bt = 16 bp`.

| Asset class | Pixel size | bt size | Notes |
|-------------|-----------|---------|-------|
| Floor tile | 16 × 16 | 1×1 | Top-down flat. Tiles autotile, so edges must be biome-internal (no overhang). |
| Wall (capped) tile | 16 × 24 | 1×1.5 | The bottom 16×16 is the wall footprint; the top 16×8 is the **cap silhouette** (the "3/4 lean"). When rendered, the cap overlaps the floor tile *above* on the screen, creating the slight perspective. |
| Wall (no cap, for inner / occluded tiles) | 16 × 16 | 1×1 | Used in deep-wall interiors; only the outermost wall row has caps. |
| Item icon (inventory) | 16 × 16 | 1×1 | Single 16-px sprite, centered with 1-px padding. |
| Item drop sprite (on the ground) | 16 × 16 | 1×1 | Same source as the icon. May be a separate frame for shimmer. |
| Player character | 16 × 24 | 1×1.5 | Standing height; **feet at row 23** (bottom-aligned). |
| Small mob | 16 × 16 | 1×1 | Stoneslough, Loambeetle. |
| Medium mob | 24 × 24 | 1.5×1.5 | Salt-Foxes, Vine-Stalker, most stratum mid-tier. |
| Large mob | 32 × 32 | 2×2 | Cracked One, Bloom-Hag. |
| Mini-boss / champion | 48 × 48 | 3×3 | Drowned Crown, Sythrenn pre-bloom. |
| Boss | 64 × 64 | 4×4 | Standard Sovereign size. |
| Mega-boss | 96 × 96 | 6×6 | Auriax, Skoldur, Diadem-Bearer arenas. |
| Decoration small | 16 × 16 | 1×1 | Toys, cups, signs. |
| Decoration medium | 32 × 32 | 2×2 | Lanterns, urns, statues. |
| Decoration large | 48 × 48 or 64 × 64 | 3×3 or 4×4 | Murals, big furniture, broken machines. |
| UI panel | multiple of 8 | — | All UI rounds to 8-px grid. |
| Font glyph | 6 × 8 or 8 × 8 | — | Pixel font; choose one before content scales. |

### Pre-export rule

When you generate at high res in Gemini (1024×1024), the source must be **cleanly divisible by 64**. That way the nearest-neighbor downsample to 16-bp is integer-exact:

- Floor / item / small mob source = 1024×1024 → downsample 64× → 16×16
- Wall capped source = 1024×1536 → downsample 64× → 16×24
- Medium mob source = 1536×1536 → downsample 64× → 24×24
- Large mob source = 2048×2048 → downsample 64× → 32×32
- Boss source = 4096×4096 → downsample 64× → 64×64

Gemini's "Nano Banana" 2.5 Flash Image normally outputs 1024×1024 by default; you may need to compose multi-tile sheets at higher res, or generate single 1024 outputs and stack them.

---

## 2. Atlas (tilesheet) layout

A **single biome tile atlas** is a 256 × 256-px PNG containing **256 tiles** at 16-bp each, arranged as a 16×16 grid.

```
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
| 0| 1| 2| 3| 4| 5| 6| 7| 8| 9|10|11|12|13|14|15|
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|16|17| ...                                  |31|
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
                       ...
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|240|...                                    |255|
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
```

### Row reservations (canonical)

Each biome atlas uses the **same row layout** so swapping atlases at biome boundaries is automatic.

| Rows | Purpose |
|------|---------|
| 0    | Floor variants (8 base + 8 wear / debris variants) |
| 1    | Auto-tile transition mask (47-tile Wang set, row 1+2) |
| 2    | (continued auto-tile) |
| 3    | Wall **caps** (the 16×8 top half — pair with row 4) |
| 4    | Wall **base** (the 16×16 bottom half) |
| 5    | Ore tiles (8 visible sub-stages × 2 ore types) |
| 6    | Decoration tiles small (16×16) |
| 7    | Decoration tiles small — biome-specific |
| 8    | Liquid: surface (water / lava / slime / acid) |
| 9    | Liquid: edge transitions |
| 10   | Hazard / trap tiles (spikes, vents, glyphs) |
| 11   | Mural fragments (8 tiles per mural × 2 murals max per atlas) |
| 12   | Furniture & door 16×16 components |
| 13   | Built-by-player tile variants (placed by hand vs natural) |
| 14   | VFX overlay tiles (light glow halos, dust motes) |
| 15   | Reserved — engine debug grid |

Tiles bigger than 16×16 (32×32 decorations, etc.) live in **separate atlases per size class**, NOT this 16×16 sheet. Don't try to pack mixed-size sprites — Godot's TileSet works best when one atlas = one cell size.

### Atlas naming convention

`assets/sprites/tiles/<biome_id>_atlas_16.png` (16-bp sheet)
`assets/sprites/tiles/<biome_id>_atlas_32.png` (32-bp sheet, if needed)
`assets/sprites/tiles/<biome_id>_atlas_walls.png` (16×24 capped walls, if a wall variant doesn't fit in the row reservation)

`<biome_id>` values: `root_hollows`, `glasswright_reaches`, `vesari_necropolis`, `sunless_verdancy`, `drowned_aphelion`, `emberforge`, `salt_wastes`, `auroric_veil`, `final_spiral`. (Match the directory names exactly.)

---

## 3. The 47-tile autotile (Wang) set

For floor → wall edge blending we use Godot 4's **Terrain** feature, which natively supports the standard 47-tile Wang set. The 47 tiles cover every combination of "this tile is/isn't connected to neighbor N" for N ∈ {top, right, bottom, left, top-right, bottom-right, bottom-left, top-left}.

Generate the 47-tile block as a single Gemini composition rather than 47 separate generations — it's more visually coherent. Reserve rows 1+2 of the atlas for this. Suggested compositional prompt:

> *"A 16×16 pixel-art autotile sheet for floor → wall transitions in the [BIOME NAME] biome. 47 distinct tiles arranged in a [LAYOUT]. Each tile is exactly 16×16 pixels with hard pixel edges and nearest-neighbor scaling. Use only the [PALETTE NAME] palette. Floor color is [HEX], wall color is [HEX]. Tiles are top-down 2D, no perspective."*

(Full per-biome prompt boilerplate lives in `prompts/tiles/<biome_id>_atlas.txt` — see [01_asset_pipeline.md](01_asset_pipeline.md).)

---

## 4. Camera & in-engine display

- **Base viewport: 480 × 270 px** = 30 × ~17 tiles visible at zoom 1×.
- **Window output: 1920 × 1080 px** = clean 4× integer scale (`canvas_items` stretch, `keep` aspect).
- Camera2D `position_smoothing_enabled = false` during gameplay so the player stays pixel-snapped.
- The 3/4 lean is *visual only* — collisions are perfectly top-down. Wall caps are drawn as a separate `Y-sorted` layer above the floor.

---

## 5. Layering / Y-sort

The 3/4 perspective is faked by Y-sort. Layer order (back to front):

1. `Floor` layer — TileMapLayer with floor tiles (no Y-sort, just paints background).
2. `FloorDeco` layer — placed decorations *on the floor* (rugs, puddles, salt streaks).
3. `WallBase` layer — TileMapLayer Y-sorted; the bottom 16 px of wall (occludes player when they're below it).
4. `Entity` layer — Player, mobs, droppable items. Y-sorted.
5. `WallCap` layer — TileMapLayer with cap tiles, Y-sorted ABOVE entities so an entity walking behind a wall is overlapped by the cap top.
6. `Lighting` layer — CanvasModulate + Light2D occluders. Multiply blend.
7. `UI` layer — CanvasLayer (no Y-sort).

This is the **only** layering scheme we use. Don't invent variations per biome.

---

## 6. Color palette

We target a **64-color global palette** (AAP-64 as a starting point), with a per-biome **6-color accent ramp** that overlays into AAP-64 slots 56–61 (so 58 colors remain shared).

| Biome | Accent hex ramp (darkest → brightest) |
|-------|----------------------------------------|
| Root Hollows | `#1c130d` `#3a2a1c` `#6b5036` `#a4854f` `#d4a857` `#f0d27d` |
| Glasswright Reaches | `#0e1626` `#1c2c4a` `#3d5b8a` `#6e8fc4` `#a5c2e8` `#dfeefb` |
| Vesari Necropolis | `#161616` `#2a2e34` `#4a5159` `#7d8492` `#b2b9c3` `#e8ecf0` |
| Sunless Verdancy | `#0c1a0f` `#1f4022` `#3e7a3b` `#7bbf64` `#c0e08a` `#f3f6c2` |
| Drowned Aphelion | `#03101a` `#0a2640` `#15527a` `#2c8fb8` `#6cd3e1` `#cdf7f3` |
| Emberforge | `#1a0808` `#3d150b` `#7a2814` `#c44a1d` `#f08a2e` `#f8d167` |
| Salt Wastes | `#1f1c1a` `#4a443f` `#857d72` `#bdb5a8` `#e3dccf` `#fdfbf0` |
| Auroric Veil | `#0a1224` `#1c1c4e` `#3a35a0` `#7062d7` `#c7a8ee` `#f0e0ff` |
| Final Spiral | `#1a1407` `#3e2e0e` `#6e521a` `#a87f24` `#dab14a` `#f8e088` |

The plugin (`godot-ai-image-generator`) supports **palette conformance**; use the per-biome ramp as the constraint when generating biome-specific tiles. The 58 shared AAP-64 entries handle skin, blood, glow, default UI, etc.

A full machine-readable palette file lives at `assets/palettes/sleeping_vein.gpl` (TODO once palette is finalized — Phase 0.5 ticket).

---

## 7. Animation frames

| Entity class | Frame count (minimum) | FPS | Notes |
|--------------|----------------------|-----|-------|
| Player idle | 4 | 8 | Per direction (4 dirs = 16 frames total). |
| Player walk | 6 | 12 | Per direction. |
| Player attack swing | 4 | 16 | Per weapon class, per direction. |
| Small mob walk | 4 | 8 | 2 directions (auto-flip horizontally). |
| Boss attack | 6–10 | 12 | Per attack pattern. |
| Ore mining hit FX | 3 | 24 | Generic, reused per ore. |
| Door open | 3 | 12 | — |
| Aphelion Beat pulse (ambient FX) | 6 | sync to 23s cycle | global VFX |

Each animation frame is a separate 16×16 (or larger) cell in a horizontal strip. Sprite strips are imported as `SpriteFrames` resources.

**Strip layout:** all frames left-to-right in a single horizontal PNG: `<entity>_<anim>.png` at `bp × frame_count`. Example: a 6-frame 16×16 walk = 96 × 16 PNG.

---

## 8. The "no upscale" rule

**Never** scale a sprite up at runtime via `scale = Vector2(2, 2)` for visual reasons. If you need a bigger sprite, generate it at the bigger source size. Runtime scaling kills pixel alignment.

Acceptable runtime scaling: **whole-viewport integer scale** (handled by the project Stretch mode), or scale `0.0 → 1.0` for tween/pop effects on a sprite that's about to be released. Anything else is a bug.

---

## 9. Pre-import checklist (per asset)

Before importing a generated PNG into Godot, verify:

- [ ] Dimensions match the canonical size in §1 exactly.
- [ ] No anti-aliasing on edges (`Filter = Nearest` in import settings — set globally in project, but spot-check).
- [ ] Palette matches biome / global palette (run `tools/check_palette.py` — TODO Phase 0.5).
- [ ] Frame count and strip arrangement match §7.
- [ ] An entry exists in `assets/manifest.json` with `status: "final"`.

If any item fails, the file goes back to `assets/raw/` and is regenerated.

---

## 10. Open questions / future work

- **Lighting masks.** Do we need per-tile light-blocker masks for shadow casting? (Likely yes for caps; investigate after Phase 1.) — Phase 4 ticket
- **Normal maps.** Core Keeper uses subtle normal-mapped lighting on tiles. We may or may not — defer to Phase 6.
- **Outline shader.** Mob outline on hover / damage flash — Phase 2 ticket.
- **Pixel font.** Choose 6×8 vs 8×8 by end of Phase 0.
