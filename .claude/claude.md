# Project: The Sleeping Vein

A 2D top-down survival/mining/exploration game inspired by Core Keeper, built in Godot 4 with GDScript. Working lore title: **AETHERDEEP — The Sunken Aeon** (see `lore/`).

**Strategy:** Mechanical 1:1 parity with Core Keeper *first*, then layer the user's custom extensions. See `docs/design/02_lore_to_mechanics_mapping.md` for the rename table, and `ROADMAP.md` / `kanban.html` for the phased plan.

## Tech Stack

- **Engine**: Godot 4.x (LTS)
- **Language**: GDScript (default). Only reach for C# if profiling proves we need it.
- **Art style**: Core Keeper-inspired pixel art. 16x16 base tile, ~16-24px characters, top-down with a slight 3/4 lean, rich saturated palette, dynamic lighting.
- **Source control**: Git, monorepo (game code + assets in the same repo).

## Read Before Acting

- `lore/` (numbered .md files, README in `lore/README.md`) is the source of truth for world, factions, biomes, characters, items, and tone. Read the relevant file before writing dialogue, naming things, designing enemies/biomes, or writing item descriptions.
- `docs/reference/core-keeper-mechanics.md` is the parity spec — what mechanic to implement and how it should behave. Items marked `[VERIFY]` need a confirmation pass.
- `docs/design/00_tile_atlas_spec.md` is the **non-negotiable** pixel-grid contract. 16×16 base tile; everything is a multiple. Read it before generating, importing, or composing any sprite.
- `docs/design/01_asset_pipeline.md` is the Gemini → Godot workflow. Follow it for every asset.
- `docs/design/02_lore_to_mechanics_mapping.md` is the rename table (Core Keeper proper noun ↔ Aetherdeep proper noun).
- `assets/manifest.json` tracks every asset, its source prompt, and its lore reference. Read it before referencing sprites in scenes. If an asset is missing, flag it with `status: "needed"` instead of inventing a path.
- Never invent lore inline. Flag gaps in plain text in your response so we update the bible together.

## Project Layout

```
/
├── CLAUDE.md
├── lore_bible.md
├── project.godot
├── scenes/
│   ├── player/
│   ├── world/         # biomes, tilemaps, world generation
│   ├── enemies/
│   ├── items/
│   ├── ui/
│   └── vfx/
├── scripts/
│   ├── autoloads/     # GameState, EventBus, SaveSystem
│   ├── player/
│   ├── world/
│   ├── enemies/
│   ├── systems/       # crafting, inventory, combat math, save
│   └── ui/
├── resources/         # .tres data: items, recipes, biomes, mob defs
├── assets/
│   ├── sprites/
│   │   ├── tiles/
│   │   ├── player/
│   │   ├── enemies/
│   │   ├── items/
│   │   ├── ui/
│   │   └── vfx/
│   ├── audio/
│   ├── fonts/
│   ├── raw/           # high-res Gemini outputs BEFORE pixel-down
│   └── manifest.json  # asset registry
└── docs/
    └── design/        # one .md per feature spec
```

## Godot Project Settings (Pixel-Perfect)

These must stay set. If you change them, ask first.

- `Rendering > Textures > Default Texture Filter` = **Nearest**
- `Rendering > 2D > Snap > Snap 2D Transforms to Pixel` = **On**
- `Rendering > 2D > Snap > Snap 2D Vertices to Pixel` = **On**
- `Display > Window > Stretch > Mode` = **canvas_items** (or **viewport** for stricter pixel-perfect)
- `Display > Window > Stretch > Aspect` = **keep**
- Base viewport: **480x270** (scales cleanly to 1920x1080)
- Camera2D: `position_smoothing_enabled = false` for pixel snapping during gameplay

## Coding Conventions

- `snake_case` for files, functions, variables
- `PascalCase` for classes (`class_name PlayerController`) and nodes
- `SCREAMING_SNAKE_CASE` for constants
- Type hints everywhere: `func damage(amount: int) -> void:`
- Prefer signals over direct node references (decoupling)
- Prefer composition (child nodes) over inheritance depth
- Autoloads for cross-scene globals only: `GameState`, `EventBus`, `SaveSystem`, `AudioBus`
- Comment the *why*, not the *what*

## Architecture Principles

- **Data-driven**: items, recipes, biomes, and mob definitions live as `.tres` resources in `/resources`. Code reads data; it does not hardcode lists.
- **Event bus**: global signals fire through the `EventBus` autoload. Subscribers connect on `_ready`.
- **Scene = entity, child nodes = components**: keep entity scripts thin; put behavior in component nodes (HealthComponent, HitboxComponent, StateMachine, etc.).
- **Systems folder**: combat math, save logic, crafting resolution live in `/scripts/systems` and are imported, not duplicated.

## Asset Pipeline (How Gemini Output Gets Into The Game)

1. Feature scoped in `/docs/design/<feature>.md`. Include the asset list.
2. For each asset, write a spec: name, target pixel dimensions, frame count, lore reference, palette notes.
3. Generate in Gemini 2.5 Flash Image at high res (1024x1024). Save to `assets/raw/<category>/`.
4. In Aseprite (or via Pillow script), downsample with **nearest-neighbor** to target size (e.g. 16x16, 32x32). Clean stray pixels and reduce to project palette.
5. Save the final sprite to `assets/sprites/<category>/<name>.png`.
6. Add an entry to `assets/manifest.json`:
   ```json
   {
     "id": "enemy_sunken_priest",
     "path": "assets/sprites/enemies/sunken_priest.png",
     "size": [32, 32],
     "frames": 4,
     "lore_ref": "lore_bible.md#sunken-order",
     "source_prompt": "prompts/enemies/sunken_priest.txt",
     "status": "final"
   }
   ```
7. Import into Godot. Verify `Filter = Nearest` on the texture import.
8. Reference in code via `const` or `preload()`.

## Do

- Ask before architectural changes that cross system boundaries.
- Write a spec in `/docs/design/` for any feature touching more than two scenes.
- Use Godot 4 idioms (Tween nodes, `Callable`-based signals, typed arrays).
- Run the project to verify changes when possible.
- Flag missing assets in the manifest with `status: "needed"` instead of inventing paths.

## Don't

- Don't add new dependencies or plugins without checking.
- Don't invent lore — read `lore_bible.md`.
- Don't write C# unless explicitly asked.
- Don't bypass the manifest. Every asset gets registered.
- Don't change pixel-perfect project settings without asking.

## Current Status

- **Phase**: Phase 0 — Foundation (project skeleton up; first Gemini smoke-test, save format, and palette tooling next)
- **Engine**: Godot 4.6 (pivoted from earlier Unreal 5.5.x attempt; lore preserved, code restarted)
- **Plugins enabled**: `ai_pixel_art_generator` (SynidSweet/godot-ai-image-generator fork) for Gemini-driven sprite gen; `gut` (Godot Unit Test) for tests
- **Recent decisions**:
  - 2026-05-12: Strategy chosen — Core Keeper 1:1 mechanical parity *first*, then custom extensions
  - 2026-05-12: Canonical tile grid locked at 16×16 base pixel, viewport 480×270, 4× to 1080p
  - 2026-05-12: 18-boss roster (Void & Voltage 2026) consolidated to 10 main + 3 optional/ending in lore mapping
  - 2026-05-12: Kanban tracking lives in `kanban.html` (browser localStorage); roadmap text in `ROADMAP.md`
- **Open questions**:
  - Save format: JSON (readable, larger) vs binary `ConfigFile`/`FileAccess` (faster, opaque)?
  - Pixel font: 6×8 vs 8×8 vs both?
  - Multiplayer transport: ENet vs Steam Networking vs WebRTC — decide before Phase 13
  - Several `[VERIFY]` items in `core-keeper-mechanics.md` need confirmation against a live Core Keeper session