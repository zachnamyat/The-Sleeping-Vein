# Phase 2 — Manual Test Checklist

Phase 2 goal (per ROADMAP §2): The core verbs — hit a tile, hit an enemy, collect
a drop, level up.

Phase 2 exit criterion (verbatim):
> Mine a tile → get loam. Hit a Stone-Hopper → it dies → drops a loambeetle.
> Pick it up. Skill XP gain visible. Die → respawn at Loom → sliver count decrements.

Walk this top-to-bottom and tell me what fails. Section letters group by
verification gate; numbered subsections cite the ticket id in **bold**.

Pre-reqs:
- Phase 0 + Phase 1 checklists passed.
- Godot 4.6.x on PATH (`godot --version` returns 4.6.*).

---

## A. Headless smoke (must pass before anything else)

```sh
godot --headless --path . --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected:
- The `--quit` call exits cleanly. Engine line + RID-leak teardown noise is OK;
  any GDScript backtrace is not.
- GUT prints **34/34 passing** (Phase 0 had 21; Phase 2 added loot, inventory,
  and mining-formula tests).

If GUT regresses, stop and paste the failing test name.

---

## B. F5 → New Game (lands in `scenes/world/main.tscn`)

### 1. Mining a tile (**2.1, 2.9**)
- Hotbar slot 1 holds a Wooden Pickaxe (granted by `world_bootstrap.gd`).
- Walk up to a shaleseed ore tile (warm-gold flecked sprite) in the Root Hollows.
- Left-click on the tile. The Swing Arc (small gold semicircle) plays.
- Each click chips the tile (`_tile_health` decrements by pickaxe damage). The
  tile breaks after ~3-4 swings on a fresh pickaxe (base 4 + Mining skill level
  + Mining talent bonus).
- When the tile breaks: cell clears, a Shaleseed Ore item drops, and the
  Mining skill toast shows progress.
- If you try to mine a higher-tier tile with the wood pick (e.g. a Clearstone
  tile in the next biome later), an HUD toast reads `Pickaxe too weak (tier 1,
  need 2)`.

### 2. Tile drop entity (**2.2, 2.12**)
- The dropped item pops up in a small arc (POP_RANGE = 12 px), then sits.
- After ~0.35s pop ends; if the player is within `MAGNET_RADIUS = 36px`, the
  drop streaks toward the player.
- **Rarity tint** — drops are tinted by their ItemDef.rarity:
  - white (0) — shaleseed, loam, loambeetle
  - green (1) — shaleseed_pickaxe, shaleseed_sword, small_healing_potion
  - blue (2) — clearstone_forge_placeable, memory_root
  - purple (3) — ember_iron_chestpiece, respec_scroll
  - gold (4) — stone_fathers_pulse, sovereign_name_fragment_1
  These drops only appear when their source content is reachable; for Phase 2
  the easiest test is to verify shaleseed reads as untinted white.

### 3. Item pickup (**2.3**)
- Walk into the dropped item. It vanishes; HUD toast reads `+1 Shaleseed Ore`.
- `EventBus.item_picked_up` fires; `EventBus.inventory_changed` fires.
- Press `I` (inventory) — Shaleseed Ore appears in the first available slot,
  stack count visible.

### 4. Melee combat (**2.4, 2.5, 2.10**)
- Swap to the Wooden Sword (hotbar slot 2 by default, or scroll wheel).
- Approach a Stone-Hopper. Left-click. SwingArc plays.
- Hopper takes damage (HP bar overhead isn't shown for mobs — that's a Phase 5
  boss feature; observe via repeated hits killing the mob in ~4 swings).
- On every successful hit: Melee skill XP increments (HUD `skill_melee → Lv N`
  toast appears at level boundaries).
- HitboxComponent + HurtboxComponent enforce `i_frames_seconds = 0.4` on the
  player — when a hopper touches you, you flicker red for 0.4s before the next
  hit lands.

### 5. Stone-Hopper chase AI (**2.6**)
- Approach a Stone-Hopper within `detection_radius = 96 px`. It begins chasing.
- Move out of range — it stops.
- The hopper's `ContactHitbox` ticks damage every 0.5s while in contact
  (`repeat_interval` on HitboxComponent), gated by the player's hurtbox i-frames.

### 6. Mob death + loot drop (**2.7**)
- Kill a Stone-Hopper. It despawns, `EventBus.entity_killed` fires.
- Loot per `resources/mobs/stone_hopper_loot.tres`:
  - **Guaranteed**: 1-2 Loambeetle
  - **Weighted (max_rolls=1)**: 4× weight Loam (1-3), 1× weight Shaleseed
- Drop sprites appear at the hopper's death position with the pop-up animation.
- Walk over them to pick up. Both `item_picked_up` toasts appear.

### 7. Damage flash + hit SFX (**2.11**)
- Hit a Stone-Hopper. The mob sprite flashes near-white (`DamageFlash` component,
  flash_seconds = 0.08).
- A procedural "hit_mob" tone plays on each connect.
- Take damage yourself — the player sprite flickers red (handled inline by
  `player_controller._on_damaged`).
- Break an ore tile — a "tile_broken" tone plays. Each non-breaking swing plays
  a softer "tile_chunk" tone.

### 8. Skill XP visible (**2.8, 2.9, 2.10**)
- After breaking ~3 ore tiles, the HUD skill toast reads
  `Mining → Lv 1`. Threshold is 100 XP; each tile gives `3 * tier` XP.
- Stone-Hopper kill grants Melee XP per `mob_def.xp_value = 5`.
- Per-hit Melee XP (1 per connect, via `_on_hit_landed`) plus the kill bonus.
- Open the talent panel (`K` if bound, else via the pause menu) — confirm the
  unallocated talent point count incremented by 1 per skill level.

### 9. Death → respawn → sliver decrement (**2.13, 1.4, 1.7**)
- Let a hopper kill you. Death screen appears.
- After ~1.5s the player respawns at `_respawn_position` (the Anchor at origin).
- HUD top-right **Slivers** label decrements by 1 (`GameState.consume_sliver()`
  fires `EventBus.aphelion_dimmed`).
- `Slivers: 69999` (or `Slivers: 70000` if you've never died).

---

## C. Save/load round-trip

10. Pause (ESC) → **Save**. Mining XP and inventory persist.
11. Quit to Title → Continue → world reloads.
12. Skill levels, inventory, and sliver count match the pre-save state.

---

## D. GUT coverage (automated)

New Phase 2 tests added this session:
- `test_combat_math.gd::test_mining_damage_helper_adds_talent_bonus` —
  `CombatMath.mining_damage` returns `pickaxe_base + mining_level + 2 * talent_pts`.
- `test_loot_table.gd` (5 tests) — guaranteed always drops, weighted picks one
  per roll, seeded determinism, count-range respected, empty table returns [].
- `test_inventory.gd` (7 tests) — empty add, stack, max_stack respect, partial
  remove, over-remove returns actual, inventory_changed signal, hotbar lookup.

---

## How to report results

Walk top-to-bottom. For each fail:
- Quote the section number (e.g. `B.4 melee XP didn't fire`).
- Paste the visible error / screenshot if any.
- Note your Godot version.

Phase 2 is **green** when sections **A**, **B.1–B.9**, **C**, and **D** all pass.
