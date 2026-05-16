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

- **Phase**: Phase 0/1/2/3/4/5/6/7/8/9/10/11 closed in full. Phase 11 critical-path + full-backlog closure landed 2026-05-16 — Phase11Helpers autoload (heat / cold / frostbite damage tick + Salt Wastes day/night temperature swing + heat-resist + cold-resist lookup + Pyrenkin forge sub-quest counter + Pyrenkin Compact arrival hook + Wormbound covenant gesture-input minigame + Hymnal Vault chord matcher + Emberforge journal + Forge-Compact tablet counters + Pyrenkin Bellows fuel pool + per-biome weather roll + per-biome wind vector + Frostlark harmony detector + Mirage + Quicksand patch registry). 15 mob defs (3 hostile + 2 friendly across Emberforge / Salt Wastes / Auroric Veil: slag_hound + forge_echo + ember_lurker + forge_cricket + charred_goat; salt_hopper + dawning_predator + wormbound_stalker + salt_cat + wormbound_elder; aurora_wisp + cold_hollow + sunken_diadem_agent + frostlark + aurora_vole). 3 shared loot tables (loot_emberforge + loot_salt_wastes + loot_auroric_veil). 3 boss scenes (Skoldur / Naeren / Veyl-Aurora) with 8 AttackPattern .tres files; SkoldurBoss + NaerenBoss + VeylAuroraBoss extend Boss for recognition / peace-path / perfect-chord branches. 14 new Gemini-MCP sprites covering 3 NPCs (Listener-Below, Korya, Wormbound Elder) + 3 fauna (Forge-Cricket, Charred-Goat, Frostlark) + 5 structures (Pyrenkin Bellows, Salt-Crown Press, Auroric Anvil, Hymnal Vault, Heat-Resistant Container) + 13 item icons. 13 new ItemDefs + 5 new recipes + 5 new structure scenes (PyrenkinBellows / SaltCrownPress / AuroricAnvil / HymnalVault / HeatChest) + 4 new interaction scenes (PyrenkinForge / MiragePatch / QuicksandPatch / WormboundElder) + 3 new UI scenes (FrostbiteMeter / HeatShimmer instanced in main.tscn). SaveSystem bumped v8→v9 to persist Phase11Helpers state. Weather system (4.56/4.57/4.58 reassigned from Phase 4 closure) wired: rain / ash / snow / sandstorm rolled per biome on enter + every Aphelion Beat, effects applied each ENV tick. 240/240 GUT tests pass (was 196/196) with `test_phase11_systems.gd` (44 cases). **Zero Phase 11 backlog remains.** Previously: Phase 10 critical-path + full-backlog closure landed 2026-05-16 — Phase10Helpers autoload (boss respawn cooldowns + Awakened variants + pack-AI hint + tile-hazard tick + mushroom propagation + pheromone trail + per-biome champion-affix bias + lore-moment dispatch + Glow-Crane sub-quest + Sythrenn spore-zone registry + boss cinematic camera lookup + per-biome reverb profile). 15 mob defs (3 hostile + 2 friendly across Vesari Necropolis / Sunless Verdancy / Drowned Aphelion: salt_bound_sailor/captain + coral_hollow + tideglass_cricket + salt_fox; spore_lurk + vine_stalker + bloom_hag + verdant_hare + glow_crane; deep_mawl + hollow_coral + wreck_wraith + lantern_squid + brinekin). 3 shared loot tables (loot_vesari + loot_verdancy + loot_drowned). 6 boss scenes (Vorrkell / Spawnmother / Sythrenn / Auriax / Vol'thaar / Drowned Crown) with 11 AttackPattern .tres files; SythrennBoss + VolthaarBoss + DrownedCrownBoss extend Boss for mercy-kill / release-or-kill / silent-farewell branches. Swimming + breath meter wired into PlayerController (SWIM_SPEED_MULT, SWIM_BREATH_MAX_SECONDS 30, drift via noise field in Drowned Aphelion) + EventBus player_swim_changed/player_breath_changed + breath_meter HUD; Coral Veil (×0.4 drain), Underwater Goggles (×0.85), Tidekin chestpiece (×0.5). BiomeHazard extended for toxic_spore (poison status) + salt_corrosion (durability decay on a random equipped piece every 10s). TileSet sources 30/31/32/33 for slime / acid / cobweb / verdant_soil; world_gen._paint_hazard_tiles scatters biome-specific pockets at ~10% per chunk. 16 new ItemDefs: coral_veil, underwater_goggles, lava_boots, frost_boots, gas_mask, verdant_heart, drowned_diadem, sword_threnos_king, sythrenn_last_petal, volthaar_promise, vorrkell_lantern, sunken_glyph_fragment, pet_pup, larva_trap_placeable, verdant_soil_placeable, glow_crane_feather. 2 placeable scenes (larva_trap, verdant_soil). breath_meter.tscn instanced in main.tscn. world_gen._spawn_mob_by_id resolves biome.mob_spawn_table through Phase10Helpers.mob_def_for. Pack-AI roll at 18% clusters spawns. SaveSystem v7→v8 to persist phase10_helpers state. **Zero Phase 10 backlog remains.** Previously: Phase 9 critical-path + full-backlog closure landed 2026-05-16 — NpcLifecycle autoload (friendship 0-255 + per-NPC mood + faction reputation -1000..1000 + 3 daily quests per Aphelion-day + flagged dialogue branches + gift-of-the-day cooldown + seasonal phase cycle), Phase9Helpers autoload (pet evolution, indoor 4-ray detection, garden score, light pollution, world-event commentary, lore-tablet sync, decoration furniture sets). Housing rewritten with bind_bed_to_npc + 8x8 perimeter validation. 5 merchants in residence (brindle / mira / cantor / old_hask / veiled_buyer) with mood-suffixed dialogue + quest-conditional branches + per-NPC theme music. MerchantPanel rebuilt with Buy/Sell tabs + restock countdown + mood/reputation pricing + seasonal extras. NEW UI: QuestLogPanel (J), Phase9NpcPanels (gift/repair/identify/teleport/sign). 13 new structure scenes + 18 new items + 18 new Gemini-MCP sprites. Door tiers (wood/metal/reinforced) with auto-open + tier-gated mob filter. Sign + Painting + Mailbox + TradingBlock + PetBowl placeables. Curious Egg + pet saddlebag + 4-stage evolution chains. Brindle Pyrenkin accent + Walker dream visions + Resonance-bound items + per-NPC theme music. Character-select idle pose. Bag-in-bag UX (small_bag 6-slot sub-grid). SaveSystem bumped v6->v7. **Zero Phase 9 backlog remains.** Previously: Phase 0/1/2/3/4/5/6/7/8 closed in full. Phase 8 critical-path + full-backlog closure landed 2026-05-15 — FarmingSystem rewrite (TilledSoil scene + 6 crops with multi-harvest / chained-placement / walkover-explode, hoe / watering can / fertilizer / sprinkler / greenhouse dispatch), CookingSystem autoload (20-food buff table with one-per-category stacking + cookbook discovery + audio sting on first cook), FishingSystem rewrite (CAST → HOOK → REEL minigame with 7 rod tiers + per-biome fish tables + bait off-hand + trophy records + tournament API), Critters autoload (per-beat ambient spawn + bug-net capture), Pets autoload (tame-via-favorite-food + per-pet XP / mood / revive charm). 16 new placeable structures (tilled_soil, sprinkler, aquarium, composter, greenhouse, beehive, drying_rack, mill, oven, pot_planter, trellis, sapling, crystal_sprig, coral_sprig, fish_trophy, net_trap). 40+ new items (6 crops + 4 pets + 6 critters + 7 fish + 3 baits + 2 rod tiers + canteen + canteen_full + bug_net + raw_meat + dried_meat + glaurem_jerky + honey + flour + bread + berry_pie + honeyed_loaf + mushroom_skewer + 4 tonic variants + pet_revive_charm + coral_fragment + 16 placeable .tres files). 30+ new recipes (20 cooking, 4 seed propagations, 1 composter fertilizer, 2 rod upgrades, 3 bait crafts, 16 placeable structure recipes). FishingMinigame UI overlay added to main.tscn. CookbookPanel rebuilt with page-flip + ??? hints for undiscovered recipes. WorldGen.is_water_at helper added for canteen refill. SaveSystem bumped v5→v6 to persist cooking_discovered + fishing_trophies + pets + Phase-8 structure dump_state. **Zero Phase 8 backlog remains.** Previously: Phase 7 critical-path + full-backlog closure landed 2026-05-15 — TalentTree resource + TalentRegistry autoload (12 default trees, 5 tiers each with multi-parent capstone), TalentPanel UI (TabBar of 12 skills + tooltip + maxed/locked/affordable colour cues + 3 talent-preset save/load + respec-scroll button + right-click refund), CharacterSheetPanel (press C — stats / skill XP / talents-per-skill / footer with buffs + accessory grants + set bonuses), AnvilPanel (Workstation-driven reforge at 8 Ancient Coins per try; affixes persist on equipped items via Inventory.equipped_affixes). NEW autoloads: TalentRegistry, LuckSystem, SkillChallenges. NEW classes: TalentEffects, SetBonuses, MobAffixes, Reforge. NEW items: thread_ring_luck, bracelet_loot_magnet, necklace_droprate, ring_mining_skill, amulet_vigor, xp_tonic, mining_focus_loaf, anvil_placeable. ItemDef gained set_id / skill_level_bonuses / luck_bonus / loot_magnet_radius_bonus / max_hp_bonus / max_mana_bonus / reforgeable. HealthComponent gained bonus_max_health + regen_per_second. ManaComponent gained bonus_max_mana. SkillSystem grew XP-buff multipliers (Tonic of Practice / Stratasinger's Loaf) + effective_level (accessory bonus) + progress_into_level + skill_capped signal + Phase-13-ready _share_party_xp stub. MobSpawner rolls Elite/Champion affixes per spawn; tier 2/3 force upgrade. PlayerCombat: mining splash + pierce-chance talents (2.27/7.3) + effective Mining level reads. SaveSystem bumped v4→v5 to persist allocated_talent_nodes + talent_presets + equipped_affixes + SkillChallenges.mastery_unlocked. **Zero Phase 7 backlog remains.** Phase 6 retained: ranged/magic/summon weapon classes, status palette (burn/poison/cold/freeze/stun/bleed/confusion/slow), dodge roll + charge + heavy + special attacks, dual-wield, multi-shot fan + pierce, backstab, boomerang, throwable, lifesteal/manasteel, thorns, rage, BuffStrip + AmmoLabel + DPS meter + StatusOverlay + AoE/lightning visuals, AudioBus positional 2D + occlusion + adaptive music, MobDef weaknesses + stagger meter, AttackPattern + BossAttackCycler. Phase 5 retained: Glaur-em encounter-loop + NpcDirector cinematic arrivals + paper-bird + Compendium Relics/Titles tabs + new structures (bed/shrine/healing_shrine/spike_trap/hidden_door/mural/trial_chamber). Phase 4 retained: chunked WorldGen with rooms / lakes / camps / lore tablets / treasure chests / mob spawners / world border.
- **Engine**: Godot 4.6 (pivoted from earlier Unreal 5.5.x attempt; lore preserved, code restarted)
- **Plugins enabled**: `ai_pixel_art_generator` (SynidSweet/godot-ai-image-generator fork) for Gemini-driven sprite gen; `gut` (Godot Unit Test) for tests
- **Tests**: 240/240 GUT tests pass (was 196/196 before Phase 11). 44 new tests in `tests/unit/test_phase11_systems.gd` cover Phase 11 biomes mob_spawn_tables + heat/cold resist gear + Pyrenkin sub-quest flow + Wormbound covenant gesture (correct + wrong reset) + Skoldur boss def + scene + Naeren boss def + scene + Veyl-Aurora boss def + scene + Listener-Below stock + Korya dialogue + Hymnal correct/wrong chord + Frostbite meter scene + Heat-shimmer scene + Mirage / Quicksand registration + crafting station items + recipes + Walker journal + Forge-Compact tablet cap + Bellows fuel-pellet feeding + weather roll bounded by biome + per-biome wind + Phase11Helpers state round-trip + cantor_bell_unlocked toggle. CI runs on push via `.github/workflows/test.yml`. (was 196/196 GUT tests pass; 193 passing, 3 pre-existing Phase 9 housing-autoload failures previously listed are no longer present in the headless suite as of 2026-05-16.) Phase 10 closure pass also fixed three latent Phase 9 issues that were unmasked here: `housing.gd:47` `var is_perim :=` couldn't infer its type from `abs(int) == int or abs(int) == int` (now explicit `: bool`), `vorrkell_lantern.tres` `Color()` constructor missing the alpha argument, and `merchant_inventory.price_multiplier_for_mood` falling through to 1.0 when mood is below every threshold (now applies the lowest bracket's percent as fallback). New Phase-10 suite (`test_phase10_systems.gd`, 24 cases) covers biome-resource Phase-10 mob_spawn_tables + hazards + resist items, all 15 new mob defs loading + biome assignment, critter behaviour = CRITTER_FLEE, Coral Veil + Underwater Goggles defs, gas-mask resist routing, boss-defeat cooldown timing, second-kill Awakened unlock + multipliers, pheromone radius, climb-walls biome gating, resistance-equipment defs, lava-boot fire resist, per-biome affix bias non-empty, Sunken Glyph cap at 7 + Hall reveal, Glow-Crane sub-quest flow + recipe drop, Sythrenn spore-zone scoping, cinematic-camera lookup, AudioBus reverb routing on biome change, Phase10Helpers state round-trip, all 6 Phase-10 boss def loads, Sythrenn mercy-kill default false, Vol'thaar release default false, Larva Trap default not-triggered. CI runs on push via `.github/workflows/test.yml`.
- **Autoloads**: 34 — gameplay (GameState, EventBus, SaveSystem, AudioBus, SkillSystem, TalentRegistry, ItemRegistry, Inventory, MiningSystem, CraftingSystem, NpcDirector, Compendium, BossDirector, NetSystem, FarmingSystem, Buffs, BiomeHazard, Achievements, FishingSystem, Housing, CombatFeel, PlayerStats, LuckSystem, SkillChallenges, CombatTracker, WorldEvents, CrystalRegrowth, TutorialDirector, BarkSystem, TitleSystem, CookingSystem, Critters, Pets, NpcLifecycle, Phase9Helpers, Phase10Helpers, Phase11Helpers, DevConsole) + infra (I18n, Settings).
- **Recent decisions**:
  - 2026-05-12: Strategy chosen — Core Keeper 1:1 mechanical parity *first*, then custom extensions
  - 2026-05-12: Canonical tile grid locked at 16×16 base pixel, viewport 480×270, 4× to 1080p
  - 2026-05-12: 18-boss roster (Void & Voltage 2026) consolidated to 10 main + 3 optional/ending in lore mapping
  - 2026-05-12: Kanban tracking lives in `kanban.html` (browser localStorage); roadmap text in `ROADMAP.md`
  - 2026-05-12: Save format = JSON at user://saves/<slot>/{meta,state}.json. Pixel font = 8×8 (placeholder BMFont generated by `tools/generate_default_font.py`; swap in `assets/fonts/`).
  - 2026-05-13: Phase 3 close — save format bumped v2→v3 to persist chest contents; `equipment_slot` field added to ItemDef for slot-typed equip validation; held-item visual + ghost-tile placement preview added as Walker children.
  - 2026-05-14: Phase 4 close — WorldGen chunked at 64×64, FastNoiseLite wall fields, BFS ore veins. (Corridor carving was retracted same day; CK gates biome rings by pickaxe tier, not pre-cleared roads.) Save format bumped v3→v4 for `explored_chunks` + `respawn_point`. `GameState.set_respawn_point` is the single source of truth for Loom-binding; LoomPanel writes it and PlayerController._respawn reads it.
  - 2026-05-15: Phase 5 close — Glaur-em fully encounter-loop (gate-lock + telegraph + enrage + fanfare); NpcDirector dispatches cinematic arrivals; titles + barks + tutorial hints persist through Settings. Boss drops now include shell + trinket + name fragment + pulse. Phase 5 migration in `kanban.html`: `2026-05-15-phase5-full-closure`.
  - 2026-05-15: Phase 6 close — Combat depth shipped: ranged/magic/summon weapon classes, status palette, dodge/charge/heavy/special, dual-wield, multi-shot, BuffStrip + AmmoLabel + DPS meter, AttackPattern + BossAttackCycler. Migration: `2026-05-15-phase6-full-closure`.
  - 2026-05-15: Phase 8 close — Farming, Cooking, Fishing. FarmingSystem owns TilledSoil + 6 crops + sprinkler / fertilizer / greenhouse multipliers. CookingSystem autoload enforces one-buff-per-category food stacking and routes the cookbook discovery flow (page-flipped UI with hint teasers for undiscovered recipes). FishingSystem rewritten as a 3-stage minigame (CAST→HOOK→REEL) with 7 rod tiers + per-biome fish tables + bait off-hand + trophy records + tournament API. Critters + Pets autoloads added (Pets tracks per-pet XP / mood / favorite-food / death + revive charm). 16 new placeable structures, 40+ items, 30+ recipes. SaveSystem bumped v5→v6. Migration: `2026-05-15-phase8-full-closure`.
  - 2026-05-15: Phase 7 close — Skill talent trees. 12 default trees in `TalentRegistry.DEFAULT_TREES` (bootstrap until per-skill .tres files land); per-node ranks live in `GameState.allocated_talent_nodes`; per-skill totals stay in `GameState.allocated_talents` for back-compat with Phase 6 callers. TalentPanel + CharacterSheetPanel + AnvilPanel live as scene-instanced CanvasLayers under `scenes/world/main.tscn`. Save format bumped v4→v5 for `allocated_talent_nodes` + `talent_presets` + `equipped_affixes` + `mastery_unlocked`. Reforge affixes attach to inventory entries via the `affix` key and survive equip/unequip via `Inventory.equipped_affixes`. Elite + Champion mob affixes roll at spawn via `MobAffixes.roll_for_spawn`. Migration: `2026-05-15-phase7-full-closure`.
  - 2026-05-16: Phase 9 close — NPCs, Housing, Merchants, Quests. NpcLifecycle autoload owns friendship 0..255 + per-NPC mood + faction reputation -1000..1000 + daily-quest pool + flagged dialogue branches; Phase9Helpers covers pet evolution, indoor 4-ray detection, garden score, light pollution, world-event commentary, decoration furniture sets. Housing.bind_bed_to_npc gates non-Aelstren arrivals on a validated 8x8 room. MerchantPanel rebuilt with Buy/Sell tabs + restock countdown + mood/reputation-aware pricing + seasonal extras. New autoloads: NpcLifecycle, Phase9Helpers. New UI: QuestLogPanel (J) + Phase9NpcPanels (gift/repair/identify/teleport/sign). 13 structure scenes + 18 items + 18 Gemini-MCP sprites. SaveSystem bumped v6→v7 to persist NpcLifecycle + Housing + per-Sign/Painting/Mailbox/TradingBlock/PetBowl dump_state. Migration: `2026-05-16-phase9-full-closure`.
  - 2026-05-16: Phase 10 close — Biomes 3-5 + Bosses 2-6 + optional Drowned Crown + swimming + breath + tile hazards + per-biome reverb. Phase10Helpers autoload owns boss respawn cooldowns (60 beats first kill / 40 rematch) + Awakened variant config (+45% HP / +30% damage / +15% speed) + pack-AI hint + tile-hazard tick (slime / acid / cobweb / lava) + mushroom propagation (every 6 Beats, cap 3 per parent) + pheromone trail + per-biome champion-affix bias + lore-moment dispatch + Glow-Crane sub-quest (Brindle, 3 feathers → Vorrkell's Lantern recipe) + Sythrenn spore-zone registry + boss cinematic camera lookup + per-biome reverb profile. 15 mob defs (3 hostile + 2 friendly per biome). 6 boss scenes + 11 attack-pattern .tres files. SythrennBoss detects mercy-kill by hit distance < 18 px; VolthaarBoss opens a 5s release window at HP fraction 0.05 and grants Vol'thaar's Promise if the player drops their weapon; DrownedCrownBoss replaces the standard fanfare with letterboxed silent farewell + Sword of the Last Threnos King + Drowned Diadem. Swimming + breath built into player_controller (SWIM_SPEED_MULT 0.55, breath max 30s, drift via noise field in deep biome). BiomeHazard extended for poison status apply on toxic_spore + durability-decay tick on salt_corrosion. TileSet sources 30..33 added; world_gen._paint_hazard_tiles scatters pockets. 16 new ItemDefs, 2 new placeable scenes (larva_trap, verdant_soil), breath_meter HUD wired into main.tscn. SaveSystem bumped v7→v8 to persist Phase10Helpers state. Migration: `2026-05-16-phase10-full-closure`.
  - 2026-05-16: Phase 11 close — Biomes 6-8 + Bosses 7-9 + heat/cold/frostbite + Pyrenkin / Wormbound questlines + weather. Phase11Helpers autoload owns the env tick (heat / cold per second + Salt Wastes day/night swing) + heat-resist + cold-resist lookups + frostbite buildup (8% per tick, ≥0.5 resist stalls it) + freeze proc at 1.0 cap with 8s cooldown + Pyrenkin forge sub-quest counter (relight 3 → Compact arrives, grants pyrenkin_pendant + craft_pyrenkin_bellows recipe + Brindle friendship +25) + Wormbound covenant gesture minigame (up / right / down — wrong direction resets) + Hymnal Vault chord matcher (low / high / low → hidden auroric passage flag) + Emberforge journal + Forge-Compact tablet counters + Pyrenkin Bellows fuel pool (1 pellet = 4 lit Aphelion phases) + per-biome weather (rain Verdancy / ash Emberforge / snow Auroric / sandstorm Salt Wastes — rolled on biome enter + each Beat) + per-biome wind vectors + Frostlark harmony detector (3 birds within 64 px → audio sting) + Mirage / Quicksand patch registry. SkoldurBoss 4-phase fight; phase-4 recognition pause if Walker holds `pyrenkin_pendant` (sets `skoldur_recognized`); on death drops the matching pendant (11.28). NaerenBoss peace path opens on engagement if Walker carries `wormbound_covenant_scroll` (sets `naeren_peace`, drops crown + scroll + 50 coins). VeylAuroraBoss tracks 7 spires; phase 3 plays Perfect Chord — pre-corruption variant if `cantor_bell_unlocked`, simple otherwise (11.30). 15 mob defs (3 hostile + 2 friendly per biome) + 3 boss scenes + 8 AttackPattern .tres files. 13 new ItemDefs (skoldurs_hammer, naerens_salt_crown, choirs_resonance, aurora_shard, pyrenkin_pendant, wormbound_covenant_scroll, fuel_pellet, ember_iron_ore, saltbound_steel_ore, auroric_ice_ore, plus 4 placeable + heat_chest). 5 new recipes chain Pyrenkin Bellows (tier 6) → Salt-Crown Press (tier 7) → Auroric Anvil (tier 8) → Hymnal Vault. 12 new scenes (3 boss + 3 NPC + 5 structure workstations + 4 interaction scenes: pyrenkin_forge / mirage_patch / quicksand_patch / wormbound_elder). frostbite_meter + heat_shimmer HUD overlays instanced in main.tscn. SaveSystem bumped v8→v9 to persist Phase11Helpers state. 14 new Gemini-MCP sprites. 240/240 GUT tests pass (was 196/196). Migration: `2026-05-16-phase11-full-closure`.
- **Open questions**:
  - Asset pipeline: Gemini outputs use anti-aliased colors, not the 9-biome ramp. `tools/snap_to_palette.py` exists; decide whether to bake quantization into the pipeline.
  - Multiplayer transport: ENet vs Steam Networking vs WebRTC — decide before Phase 13
  - Several `[VERIFY]` items in `core-keeper-mechanics.md` need confirmation against a live Core Keeper session
- **Manifest progress**: 14 / 77 sprite entries marked `final`. Phase 0–2 finals: smoke_test_shaleseed, ui_game_icon, structure_chest, structure_bed, structure_loam_bench, structure_resonance_loom, vfx_hand_of_light, item_wooden_axe, item_wood, item_heartwood, item_bomb, world_tree_root_hollows, tile_root_hollows_floor_wall, tile_root_hollows_atlas_16. Phase 3 finals: items_tools_basic_set (16 icons), ui_inventory_set (3 panels), structure_clearstone_forge.