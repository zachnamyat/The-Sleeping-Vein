# The Sleeping Vein

A 2D top-down survival / mining / exploration game with deep crafting, 9 strata to descend, 10 boss encounters with moral weight, and a seven-act story-spine of folded geography and a dying sun. Working lore title **AETHERDEEP — The Sunken Aeon**.

Built in **Godot 4.6** with **GDScript**. 1-8 player co-op. Pixel art generated through Gemini 2.5 Flash Image via the [godot-ai-image-generator](https://github.com/SynidSweet/godot-ai-image-generator) plugin (installed as `ai_pixel_art_generator`).

## Strategy

**Mechanical parity with Core Keeper first, custom extensions second.** Core Keeper is the reference for every system (combat, mining, crafting, skills, automation). The narrative layer is the original *Aetherdeep* lore in `lore/`. Once parity is solid, custom features layer on top.

## Where to look

| File / dir | What it is |
|------------|-----------|
| [`ROADMAP.md`](ROADMAP.md) | The 17-phase plan with exit criteria per phase |
| [`kanban.html`](kanban.html) | Live kanban board (open in a browser; data saves to your localStorage) |
| [`lore/`](lore/) | The lore bible — 11 numbered docs + README |
| [`docs/reference/core-keeper-mechanics.md`](docs/reference/core-keeper-mechanics.md) | The parity spec for what to build |
| [`docs/design/00_tile_atlas_spec.md`](docs/design/00_tile_atlas_spec.md) | Pixel grid + atlas + palette + camera contract |
| [`docs/design/01_asset_pipeline.md`](docs/design/01_asset_pipeline.md) | Gemini → Godot art workflow |
| [`docs/design/02_lore_to_mechanics_mapping.md`](docs/design/02_lore_to_mechanics_mapping.md) | Core Keeper ↔ Aetherdeep rename table |
| [`assets/manifest.json`](assets/manifest.json) | Asset registry — every sprite, status, lore-ref |
| [`.claude/claude.md`](.claude/claude.md) | Working agreement / project rules for Claude Code |

## Status

**Phase 0 — Foundation.** Project skeleton (autoloads, folder structure, project settings, gitignore, manifest, kanban, roadmap, reference docs) is in place. Next: Gemini smoke-test, palette tooling, save format, first pixel font.

See [`kanban.html`](kanban.html) for ticket-level state and [`ROADMAP.md`](ROADMAP.md) for the phased plan.

## Pixel-perfect settings (do not change without asking)

- Texture filter: **Nearest**
- Snap 2D Transforms / Vertices to Pixel: **On**
- Stretch mode: **canvas_items**
- Viewport: **480 × 270**, window scales 4× to 1920 × 1080
- Camera2D `position_smoothing_enabled = false` during gameplay
- Base tile: **16 × 16 px** — every asset is a multiple

See [`docs/design/00_tile_atlas_spec.md`](docs/design/00_tile_atlas_spec.md) for the full grid spec.
