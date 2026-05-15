# Changelog

All notable changes to The Sleeping Vein will be recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Bump
`GameState.VERSION` whenever a release is cut.

## [Unreleased]

### Changed
- **4.6 retracted 2026-05-14** — the cardinal corridor-tunnel carving shipped
  earlier the same day was anti-parity. Core Keeper gates biome rings with
  progressively-harder walls (the parity-mechanics doc line 16 calls them
  "border zones … mob density and ore tier scale roughly with distance from
  The Core"), and the player mines their own path with tier-appropriate
  pickaxes. Pre-cleared corridors trivialised that. Removed
  `CORRIDOR_HALF_WIDTH` + `_is_corridor_tile` from `scripts/world/world_gen.gd`,
  stripped corridor checks from every placement site, and rewrote the
  `test_world_gen.test_corridor_carving_covers_world_axes` case to verify the
  Anchor plateau is now the **only** always-clear zone (7-tile circle at
  origin). Kanban ticket 4.6 flagged `[RETRACTED 2026-05-14]` with the
  `retracted` tag.

### Added
- **Phase 4 full backlog closure (2026-05-14)** — all 4.13–4.65 tickets either
  implemented or reassigned. **Zero Phase 4 backlog remains.**
  - **Reassignments** (kanban moves only): 4.27 / 4.35 / 4.36 → Phase 14
    (automation/liquids); 4.45 → Phase 15 (polish shader); 4.56 / 4.57 /
    4.58 → Phase 11 (weather lives with the Auroric / Ember / Salt biomes);
    4.65 → Phase 15 (first-run wizard is polish).
  - **Gemini MCP asset generation** — 17 new sprites generated end-to-end
    through `mcp__gemini-image__generate_image` (1024×1024 source) +
    `mcp__gemini-image__process_image` (nearest-neighbour downsample) +
    `tools/clean_alpha.ps1` (chroma-key). All flipped `status:"final"` in
    [assets/manifest.json](assets/manifest.json):
    items/`bound_compass`, `skeleton_key`, `treasure_map`, `world_scanner`,
    `anchor_portable`; structures/`mob_spawner`, `wishing_well`, `glow_shroom`,
    `locked_door`, `boss_altar`, `statue`, `lore_tablet`; tiles/`water_tile`,
    `sticky_tile`, `bridge_tile`, `trapdoor`, `scatter_decor`.
  - **WorldGen procedural extensions:** per-chunk mob budget + wall/light
    suppression (4.15/4.16/4.51); elite mob spawners scaled with biome stratum
    (4.17/4.59); carved unique rooms with treasure-chest / wishing-well /
    lore-tablet / boss-altar centerpieces (4.18/4.50); procedural lakes
    (4.20); abandoned camps with statue + chest (4.21); free-standing treasure
    chests with key-locked variants (4.23/4.25); one lore-tablet per biome
    ring (4.24); hidden-wall flag (4.29); sub-biome detection via cellular
    noise (4.44); finite world border at 1600 tiles (4.48); floor scatter
    decals (4.55); night-Beat density bonus (4.61).
  - **Player utility items:** `bound_compass` (4.14 recall to bound Loom,
    60-beat cd), `skeleton_key` (4.25, consumed by locked doors),
    `treasure_map` (4.30 places minimap marker on nearest treasure_chest),
    `world_scanner` (4.38 12-beat cd, reveals 5-chunk radius),
    `anchor_portable` (4.49 sets respawn point in place). All wired through
    `player_combat._try_consume` id-dispatch.
  - **New world systems** (autoloads): `WorldEvents` (4.32 random world
    events, 4.42 Suncrack damage event, 4.43 Hollowling-swarm intensifier);
    `CrystalRegrowth` (4.34 Clearstone tiles regrow after 16 beats in
    Glasswright Reaches only).
  - **Scene-level VFX:** `HollowlingMotes` Node2D — procedural drifting gold
    sparkles around the player; intensifies during a `hollowling_swarm`
    world event (4.43).
  - **DayNightCycle 4.46 world clock** — 24-minute dawn/day/dusk/night phase
    runs independently of the 23s Aphelion Beat; `skip_time` API consumed by
    bed sleep. `PlayerController.try_sleep_in_bed` gated by hostile-mob
    proximity (4.64) + 8-beat cooldown (4.52); waking skips 8 minutes of the
    world clock (4.63) and restores 25% HP.
  - **DeathCorpse** pings the minimap with a Tombstone marker on spawn
    (4.62). **Minimap** gained `add_marker(world_pos, label, color)` +
    `death_compass_active` toggle (4.19/4.39). **CompassToLoom** widget polls
    the toggle and retargets to the most recent Tombstone marker. **HUD**
    shows live tile + chunk coordinates under the compass (4.31).
  - **WorldGen helpers**: `is_under_roof(world_pos)` (4.33),
    `temperature_intensity_at(world_pos)` (4.47), `chunks_in_radius` and
    `nearest_treasure_chest` (feed 4.30 / 4.38 items).
  - **TileSet bump**: sources 27 (water), 28 (sticky), 29 (bridge).
  - **New input action**: `toggle_death_compass` (default J).
  - 66/66 GUT pass holds.
- **Phase 4 critical-path (2026-05-14)** — procedural Root Hollows + Glasswright
  Reaches playable. `WorldGen` rewritten:
  - 4.1 `CHUNK_TILES` bumped 32→64 for CK parity; `view_chunk_radius` lowered
    2→1 so live tile count stays bounded. `Minimap` and `FogOfWar` synced to the
    new constant.
  - 4.2 Wall placement driven by `FastNoiseLite` Perlin sampling against a
    threshold + per-chunk shuffle. Soft per-biome budget caps still apply, so
    dense biomes don't seal the player in.
  - 4.3 Ore placed via BFS-grown clusters: 2–4 seed points per chunk, each
    cluster grows 3–6 cells outward with distance-falloff probability so veins
    read as clumps rather than scattered pips.
  - 4.4 Anchor prefab clean-up: plateau clearing widened, Loom + LoamBench +
    Chest pre-placed at world origin. (The earlier "axes always corridor-clear"
    note from this entry was reversed by the 4.6 retraction — see Changed.)
  - 4.5 `LoomPanel` adds an Aphelion-sliver readout (count + %) and a
    "Set Respawn Here" button bound to the *interacted* Loom's world position.
    `GameState.respawn_point` holds the binding; `PlayerController._respawn`
    honours it on death. New signal `EventBus.respawn_point_set`.
  - 4.6 ~~Cardinal corridor carving~~ — **RETRACTED same day** (see the
    Changed section above). The corridor predicate has been removed; the
    Anchor plateau is the only always-clear zone.
  - 4.7 / 4.8 `root_hollows.tres` and `glasswright_reaches.tres` retuned for the
    bigger chunks (densities × ~4) and given `ambient_track_id` fields.
  - 4.9 `AudioBus._on_biome_changed` listens for `EventBus.biome_changed` and
    swaps the ambient stream to the entering biome's track (placeholder
    procedural drone until real audio assets land).
  - 4.10 Minimap reveal state moved into `GameState.explored_chunks`
    (`Dictionary` keyed by `"x,y"`) + `SaveSystem` bumped v3→v4 to persist
    explored chunks and the respawn point. `FogOfWar` and `Minimap` hydrate
    from this dictionary on `_ready`.
  - 4.11 Existing `CompassToLoom` widget retargets via the same
    respawn-point binding (was previously hardcoded to world origin).
  - New `EventBus` signals: `biome_changed`, `chunk_visited`,
    `respawn_point_set`.
  - New tests: `test_world_gen` (chunk constant, anchor-plateau predicate,
    hash determinism, world-to-chunk math) and `test_explored_chunks`
    (mark + idempotency + save round-trip + new-game reset). 66/66 GUT pass.
  - Phase 4 backlog (4.12–4.65) intentionally left open for Phase 4.x polish
    work (treasure rooms, weather, day/night, etc.).
- **Placement commit (2026-05-13 follow-up)** — `player_combat._resolve_place`
  spawns the placeable's matching scene at the snapped grid cell when the
  player left-clicks while holding a placeable. Workstations (loam_bench,
  clearstone_forge, furnace, sawmill, cooking_pot) instantiate their full
  scene; decorative placeables (torch, glow_tube) spawn as a sprite +
  PointLight2D via `_build_decor_placement`. Range-validated against the same
  48 px radius as the PlaceablePreview ghost. The 2.48 ticket previously
  shipped only the visual ghost; this completes the click-to-place loop.
- **Phase 3 extended-closure (2026-05-13)** — every Phase 3 ticket is now either
  done or reassigned to its natural phase. Zero Phase 3 backlog remains.
  - 20 implemented this session: 3.15 last-used-container tracking; 3.17
    equipped-comparison overlay in tooltip; 3.19 sequential crafting queue
    (Ctrl-click queues 5×); 3.28 Furnace placeable + scene + smelting recipe
    cascade (shaleseed_ingot, bottle_empty unlock on placement); 3.30 Sawmill
    placeable + scene + plank recipe; 3.32 workstation adjacency-detection
    (open one bench, see recipes from every adjacent station within 48 px);
    3.33 auto-equip-best-armor button; 3.42 cancel-from-queue button on every
    queued recipe; 3.43 middle-click slot lock with extra-thick gold border,
    locked slots refuse swap/sort/drop; 3.44 double-click an armor piece to
    equip-swap into its target slot; 3.46 `ItemDef.two_handed` field + bow
    marked true + tooltip displays "Two-handed (locks off-hand)"; 3.51 Q swaps
    active hotbar with saved layout (Shift+Q saves); 3.53 ConfirmationDialog
    for trash discards above threshold; 3.57 station_tier_upgrade Resonance
    Coupler item + recipe (3 ingot + 1 aphelion fragment); 3.58 bottle_empty
    glass container + furnace recipe; 3.61 set-bonus tooltip preview shows
    Shaleseed (n/4) + 2pc/4pc bonus rules; 3.66 sort_storage_recency by
    latest acquisition; 3.71 craft_complete SFX cue; 3.85 aphelion_fragment
    cross-tier reagent ItemDef + lore_text; 3.86 glow_tube combo placeable
    (torch + bottle).
  - 33 reassigned to natural phases via `seedTickets.phase` field — affixes/
    reforging/salvage/enchant/durability/star-rating to Phase 16 extensions;
    set bonuses/anvil/luck stat to Phase 7 talents; tannery to Phase 8 life
    sim; bag-in-bag to Phase 9 (Mira); bucket+liquid placement to Phase 14
    automation; cosmetics + worn visuals to Phase 15 polish; soulbound items
    to Phase 13 multiplayer; recipe scrolls + boss trinkets to Phase 5;
    place-multiple + crystal cluster to Phase 4; new weapon classes + dual
    wield + reload anim to Phase 6 combat depth.
  - 3 closed as duplicates of already-shipped work — 3.48 trinket slot
    (necklace/ring_1/ring_2/bracelet exist), 3.49 belt slot (already in
    EQUIPMENT_SLOTS), 3.84 reach/range stat in tooltip (shipped earlier).
  - 8 new ItemDef resources: furnace_placeable, sawmill_placeable, plank,
    shaleseed_ingot, bottle_empty, aphelion_fragment, glow_tube,
    station_tier_upgrade. 7 new recipes for them. 2 new station scenes
    (furnace.tscn, sawmill.tscn).
  - `Inventory` extended with `last_used_container`, `locked_slots`,
    `_acquired_seq` counter, `toggle_lock`, `is_locked`, `auto_equip_best`,
    `sort_storage_recency`. `Workstation` adds `nearby_station_ids` +
    `add_to_group("workstation")` so `CraftingPanel.open_for_adjacent` can
    pull recipes from every station within 48 px.
  - `ItemDef` adds `two_handed: bool` field.
  - 7 new GUT tests across lock toggle, auto-equip, recency sort. 57/57 pass.
- **Phase 3 closure (2026-05-13)** — inventory, crafting, equipment, chest persistence.
  - 20 finalized sprites via Gemini MCP + `tools/process_phase3_assets.py`:
    16 tool/armor/potion icons (wooden_pickaxe / wooden_sword / torch / loam_floor /
    loam_wall / hoe / watering_can / cooking_pot / shaleseed_pickaxe / shaleseed_sword /
    shaleseed_helmet / shaleseed_chest / shaleseed_legs / shaleseed_boots /
    small_healing_potion / small_mana_potion), three UI panel sprites
    (inventory_grid_panel 176×64, equipment_slots_panel 112×48, tooltip_frame 128×80),
    and the structure_clearstone_forge 32×32 sprite. Manifest entries flipped to
    `final` with raw_versions + chosen_version recorded.
  - `EquipmentPanel` / `EquipmentSlotUI` UI with humanoid silhouette layout, per-slot
    type validation on drop, right-click unequip, and hover tooltips. `ItemDef.equipment_slot`
    field added; armor pieces declare their target slot.
  - `HeldItemVisual` Node2D attached to Player renders the active hotbar item's icon
    next to the Walker; auto-flips on facing change (ticket 3.5 + 2.36).
  - `PlaceablePreview` Node2D shows a 16-grid-snapped ghost tile while holding a
    placeable item, green when inside placement range, red when not (ticket 2.48).
  - Chest persistence: `Chest.dump_state`/`restore_state` + unique_id keying;
    `SaveSystem` schema v3 stores a `chests` array; `world_bootstrap` applies
    `consume_pending_chests()` after Load. New `ChestPanel` UI with deposit/withdraw
    drag-drop, L-click take-all, R-click take-one.
  - `CraftingPanel` polish: multi-craft (shift-click crafts max affordable),
    favorites toggle with persisted star markers, search filter, recipe-unlock
    toast, per-recipe input-status colorization, station-aware recipe filtering.
  - Inventory parity-audit extras: stack split via shift-drag (3.35), drag-to-ground
    via right-click + 0.6s pickup-immunity window (3.50), trash slot with confirmation
    threshold (3.25), live search box dimming non-matches (3.60), sort buttons for
    rarity / name / type that leave the hotbar row untouched (3.26/3.45), Loot All
    button magnets every ItemDrop within 64 px (3.14), Quick Stack button deposits
    matching items into the nearest chest (3.13).
  - Tooltip: name color reflects rarity (3.67), `lore_text` excerpt for relics
    (3.59), and additional stat rows (axe tier, mana restore, reach, equipment slot).
  - Inventory slot border tinted by item rarity (3.67 visualisation).
  - Save format bumped v2 → v3 with `chests` field. Older saves load with empty
    chests on first session and re-save at v3.
  - New ItemDef resources: `shaleseed_legs.tres`, `shaleseed_boots.tres`,
    `loam_floor.tres`, `loam_wall.tres`. All four armor pieces declare
    `equipment_slot` + matching icons.
  - 29 new GUT tests across crafting flow, recipe unlock cascade, equipment
    validation, chest deposit/withdraw/persist round-trip, stack split, sort.
    50/50 GUT pass.
- Phase 0 close-out: `.editorconfig`, GitHub PR + issue templates, CHANGELOG, version
  constant, i18n string-table scaffold, GitHub Actions GUT runner, pre-commit GDScript
  syntax hook, `tools/snap_to_palette.py` and `tools/batch_generate.py`, settings panel
  (display / audio / controls) wired into pause menu + title screen, default 8×8 pixel
  font dropped into theme.
- `tools/check_palette.py` Manhattan-tolerance palette conformance checker (ticket 0.5).
- 5 finalized sprites: smoke_test_shaleseed, ui_game_icon, structure_chest, structure_bed,
  structure_loam_bench (manifest catch-up to kanban migrations).

### Changed
- `Inventory.EQUIPMENT_SLOTS` extended with `boots` (11 slots total).
- Manifest: `structure_workbenches_set` no longer covers `loam_bench` *or*
  `clearstone_forge` (both split into their own `final` entries). 14 of 77 manifest
  assets are now `final`.

## [0.0.1] — Project skeleton

Initial scaffolding, Phase 0–14 stubs, lore canon (11 lore/*.md files), kanban (~870
seed tickets), AAP-64 + 9-biome-ramp palette.
