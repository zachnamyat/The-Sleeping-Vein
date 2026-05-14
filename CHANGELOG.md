# Changelog

All notable changes to The Sleeping Vein will be recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Bump
`GameState.VERSION` whenever a release is cut.

## [Unreleased]

### Added
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
