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

## E. Extended parity-audit tickets (closed 2026-05-13)

### E.1 Axe + Tree felling (**2.14, 2.15**)
- Hotbar slot 3 holds a Wooden Axe at spawn.
- A ring of 8 trees surrounds the Anchor at ~96px radius.
- Swap to the axe. Left-click a tree: each swing emits `swing_axe` SFX and chips a crack overlay; tree drops in 7-8 swings.
- On fell: tree rotates + fades, drops 1-4 Wood plus a 25% chance of 1 Heartwood.
- Try the **sword** on a tree — it does 0 damage (trees resist physical 100%). Only the axe (damage_type = &"axe") gets through.
- The axe also works against mobs (no axe resistance) as a regular melee weapon.

### E.2 Bombs (**2.17**)
- Hotbar slot 4 holds 3 Bombs at spawn.
- Click to lob — bomb arcs toward the cursor, lands, 1.5s fuse with flickering spark, then explodes.
- Explosion: camera shake + screen pulse + `bomb_explode` SFX, expanding ring VFX.
- Hurtboxes within 32px take 35 explosive damage (most mobs die in one).
- Tiles within ~1 cell take 40 mining damage — useful for chunking through weak walls.
- Explosives skill XP +2 per throw.

### E.3 Death corpse + reclaim (**2.16**)
- Die with non-starter items in inventory (e.g. Loambeetle, Shaleseed).
- A pulsing purple-gold rune marker appears at the death position.
- Respawn at the Loom (starter pickaxe/sword/axe/torch retained).
- Walk back to the corpse — `corpse_reclaim` SFX + "Stash reclaimed." toast — all stashed items restored.
- Starter tools (`wooden_pickaxe`, `wooden_sword`, `wooden_axe`, `torch`) stay in inventory; only the surplus drops.

### E.4 Damage numbers + crits (**2.20, 2.29**)
- Every hit (player → mob OR mob → player) spawns a white floating number that rises and fades over 0.75s.
- Roll on each player melee swing for a crit (base 5% from `CombatMath.player_crit_chance`). Crits render larger and warm-gold.
- A crit also triggers screen pulse + camera shake.
- Each Melee talent point in Phase 7 increments the crit chance.

### E.5 Tile damage states (**2.23**)
- Hit an ore tile partially (don't break it). A faint crack overlay appears, and the cracks visibly shake on each swing.
- Crack density scales with damage taken (more hits = more cracks).
- On tile break, overlay self-destroys; on full HP refresh, overlay also clears.

### E.6 Mob behavior depth (**2.18, 2.19, 2.21, 2.28, 2.31**)
- **Aggro range** (2.19): Stone-Hopper only chases if you enter `detection_radius = 96px`. Outside that, it stays idle.
- **Hysteresis de-aggro** (2.28): once aggro'd, the hopper holds target until you exceed `1.5 × detection_radius` (~144px). No flicker at the edge.
- **Leash** (2.19/2.28): if you drag a hopper > `leash_radius = 160px` from its spawn, it drops aggro and walks home.
- **Critter flee** (2.18): mobs whose `behavior` is `CRITTER_FLEE` run AWAY from the player. No critter mob ships in Phase 2 art, but the field is wired.
- **Mob class** (2.31): every MobDef now has a `mob_class` (MELEE / RANGED / CASTER / TANK / CRITTER). Stone-Hopper is MELEE. Used by future AI selection + UI tooltips.
- **Death animation** (2.21): mob fades to 0 alpha and scales 1.2× over 0.4s before despawn; collider disabled at death so the player can walk through.

### E.7 Audio palette (**2.25, 2.41**)
- **Tool SFX**: pickaxe / axe / magic / ranged / summon / melee each produce a distinct swing tone via `_play_tool_sfx`.
- **Pickup SFX**: rarity-keyed — common (white) / uncommon (green) / rare (blue) / epic (purple) / legendary (gold). You'll hear the bump in tone when picking up a Heartwood (rarity 1) vs Loam (rarity 0).

### E.8 Reach per weapon (**2.45**)
- Hit the SwingHitbox position now uses `ItemDef.melee_range_pixels` instead of a fixed `swing_offset`. Wood Sword + Wood Axe both report 18 in their .tres. Editing the .tres in Godot live-changes reach without a code change.

### E.9 Fall-damage RFC (**2.50**)
- Decided: **no fall damage**. The Sleeping Vein is a flat 2D top-down world with no Z-axis. Ticket closed by decision, not code.

---

## How to report results

Walk top-to-bottom. For each fail:
- Quote the section number (e.g. `B.4 melee XP didn't fire`, `E.3 corpse not reclaiming`).
- Paste the visible error / screenshot if any.
- Note your Godot version.

Phase 2 is **green** when sections **A**, **B.1–B.9**, **C**, **D**, and **E.1–E.9** all pass.
