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

Full spec lives at [docs/design/01_asset_pipeline.md](../docs/design/01_asset_pipeline.md). This is the operational quick-reference for what we actually run.

### Step 1 — Spec the asset
Open the relevant feature doc under `/docs/design/`. Each asset needs: `id`, target pixel size, frame count, lore ref, palette notes, prompt path (`prompts/<category>/<id>.txt`).

### Step 2 — Generate via Gemini MCP
Use `mcp__gemini-image__generate_image`. Save raw to `assets/raw/<category>/<id>_v<N>.png`. Prompt **must** request `#FF00FF` magenta background with ~8px of padding on all four sides at final pixel size. For single structures: request "A SINGLE structure CENTERED in the image with magenta padding on all four sides. NO grid, NO labels."

### Step 3 — Downsample (crop + nearest-neighbor resize)
Use `mcp__gemini-image__process_image` (sharp under the hood — nearest-neighbor resize, deterministic, free). Two-step in a single call:

```jsonc
{
  "imagePath": "assets/raw/<cat>/<id>_v<N>.png",
  "crop":   { "left": L, "top": T, "width": W, "height": H },  // square, contains structure + small magenta margin
  "resize": { "width": TARGET, "height": TARGET },             // final px (16/24/32/48/64...)
  "filename": "<id>",
  "outputDir": "assets/sprites/<category>"
}
```

**Crop math** — what L/T/W/H to use:

1. `Read` the raw PNG to see where the structure actually sits. Gemini outputs at 1024×1024 by default.
2. Find a square region that contains the full structure with 1-3% of the source as breathing room on each side (so ~10-20px at 1024 source).
3. The crop must be **square** (W == H), otherwise the resize warps the sprite.
4. Reference points used in past work: a 1024² source with a centered structure → crop `(left:100, top:80, width:824, height:824)` gave correct 48×48 output for resonance_loom.

If the crop is too tight, the structure clips at edges. If too loose, the structure shrinks below the target size. When unsure, prefer slightly loose — the magenta margin is removed in step 5.

### Step 4 — Promote to canonical path
`mcp__gemini-image__process_image` auto-versions to `<id>-v2.png` if the canonical file already exists. Rename the new output over the canonical filename:

```powershell
mv "assets/sprites/<cat>/<id>-v2.png" "assets/sprites/<cat>/<id>.png"
```

### Step 5 — Chroma-key + binary alpha threshold
Run `tools/clean_alpha.ps1` (PowerShell + ImageMagick). This is the **only** chroma-key path we use — sharp's `removeBackground` is unreliable across Gemini's bg-color variance. The PS script:

1. Samples the corners; skips the file if it's already alpha-clean.
2. Runs `magick -fuzz 22% -transparent` against five known magenta variants (`#FF00FF`, `#E84080`, `#FB2D83`, `#FF1493`, `#C70066`).
3. Thresholds alpha to binary (`-threshold 30%`) — pixel art demands fully-opaque or fully-transparent pixels, never partial alpha at edges.

```powershell
# single file (typical after promoting one asset):
powershell -ExecutionPolicy Bypass -File tools\clean_alpha.ps1 -Path "absolute\path\to\<id>.png"

# batch every PNG under assets/sprites/:
powershell -ExecutionPolicy Bypass -File tools\clean_alpha.ps1
```

### Step 6 — Update manifest
Edit `assets/manifest.json`. Set `status: "final"`, record `raw_versions` and `chosen_version`, leave a `notes:` line if there's a non-obvious reason for the chosen version.

```jsonc
{
  "id": "structure_resonance_loom",
  "path": "assets/sprites/structures/resonance_loom.png",
  "size": [48, 48],
  "category": "structure",
  "lore_ref": "lore/01_cosmology_and_universe.md",
  "source_prompt": "prompts/structures/structures_anchor_base.txt",
  "raw_versions": ["assets/raw/structures/resonance_loom_solo_v1.png"],
  "chosen_version": "solo_v1",
  "ticket": "4.5",
  "status": "final",
  "notes": "Regenerated as dedicated single-asset image after grid-cropped version clipped."
}
```

### Step 7 — Force Godot reimport (when overwriting an existing asset)
**Critical gotcha**: Godot caches imports at `.godot/imported/<filename>.png-<hash>.ctex` + matching `.md5`. Overwriting the source PNG does NOT invalidate the cache unless something triggers a reimport scan. `godot --headless --quit-after N` does NOT scan — only `--import` does.

```powershell
# 1. Delete the stale cache files
rm ".godot/imported/<filename>.png-*.ctex" ".godot/imported/<filename>.png-*.md5"

# 2. Force a reimport
& "<godot-path>" --headless --path "<project-root>" --import
```

Then verify the new `.ctex` mtime is current. **Skip this step on first-time imports** (when the canonical file didn't exist before) — Godot's first-launch scan picks those up automatically.

### Step 8 — Wire into scenes / code
Reference via `res://assets/sprites/<category>/<id>.png` in `.tscn` files, or `preload()` the wrapped `.tres` resource. Always confirm `Filter = Nearest` on the texture import (default in project settings).

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

- **Phase**: Phase 0/1/2/3/4 closed in full. Phase 4 critical-path + full-backlog closure landed 2026-05-14. WorldGen now does noise-based walls, BFS ore veins, procedural rooms / lakes / camps / lore tablets / treasure chests / mob spawners / sub-biome detection / world border. (Ticket 4.6 corridor carving was retracted same day — anti-parity, removed from code; only the 7-tile Anchor plateau stays always clear.) 17 new Gemini-MCP sprites flipped status:"final". New autoloads: WorldEvents (4.32/4.42/4.43 scheduler), CrystalRegrowth (4.34 Reaches ore regrowth). LoomPanel, Minimap, Compass, HUD all extended for set-spawn, marker pings, death-compass, and live coord readout. Bed sleep gated by hostiles + cooldown + 24-min skip_time. SaveSystem v4 persists explored_chunks + respawn_point. **Zero Phase 4 backlog remains.**
- **Engine**: Godot 4.6 (pivoted from earlier Unreal 5.5.x attempt; lore preserved, code restarted)
- **Plugins enabled**: `ai_pixel_art_generator` (SynidSweet/godot-ai-image-generator fork) for Gemini-driven sprite gen; `gut` (Godot Unit Test) for tests
- **Tests**: 66/66 GUT tests pass (combat math, health, manifest loader, skill xp, save system, inventory, loot table, crafting flow, equipment validation, chest persistence, stack split + sort, world-gen determinism + corridor predicate, explored-chunks save round-trip). CI runs on push via `.github/workflows/test.yml`.
- **Autoloads**: 20 — gameplay (GameState, EventBus, SaveSystem, AudioBus, SkillSystem, ItemRegistry, Inventory, MiningSystem, CraftingSystem, NpcDirector, Compendium, BossDirector, NetSystem, FarmingSystem, Buffs, BiomeHazard, Achievements, FishingSystem, Housing, CombatFeel) + infra (I18n, Settings).
- **Recent decisions**:
  - 2026-05-12: Strategy chosen — Core Keeper 1:1 mechanical parity *first*, then custom extensions
  - 2026-05-12: Canonical tile grid locked at 16×16 base pixel, viewport 480×270, 4× to 1080p
  - 2026-05-12: 18-boss roster (Void & Voltage 2026) consolidated to 10 main + 3 optional/ending in lore mapping
  - 2026-05-12: Kanban tracking lives in `kanban.html` (browser localStorage); roadmap text in `ROADMAP.md`
  - 2026-05-12: Save format = JSON at user://saves/<slot>/{meta,state}.json. Pixel font = 8×8 (placeholder BMFont generated by `tools/generate_default_font.py`; swap in `assets/fonts/`).
  - 2026-05-13: Phase 3 close — save format bumped v2→v3 to persist chest contents; `equipment_slot` field added to ItemDef for slot-typed equip validation; held-item visual + ghost-tile placement preview added as Walker children.
  - 2026-05-14: Phase 4 close — WorldGen chunked at 64×64, FastNoiseLite wall fields, BFS ore veins. (Corridor carving was retracted same day; CK gates biome rings by pickaxe tier, not pre-cleared roads.) Save format bumped v3→v4 for `explored_chunks` + `respawn_point`. `GameState.set_respawn_point` is the single source of truth for Loom-binding; LoomPanel writes it and PlayerController._respawn reads it.
- **Open questions**:
  - Asset pipeline: Gemini outputs use anti-aliased colors, not the 9-biome ramp. `tools/snap_to_palette.py` exists; decide whether to bake quantization into the pipeline.
  - Multiplayer transport: ENet vs Steam Networking vs WebRTC — decide before Phase 13
  - Several `[VERIFY]` items in `core-keeper-mechanics.md` need confirmation against a live Core Keeper session
- **Manifest progress**: 14 / 77 sprite entries marked `final`. Phase 0–2 finals: smoke_test_shaleseed, ui_game_icon, structure_chest, structure_bed, structure_loam_bench, structure_resonance_loom, vfx_hand_of_light, item_wooden_axe, item_wood, item_heartwood, item_bomb, world_tree_root_hollows, tile_root_hollows_floor_wall, tile_root_hollows_atlas_16. Phase 3 finals: items_tools_basic_set (16 icons), ui_inventory_set (3 panels), structure_clearstone_forge.