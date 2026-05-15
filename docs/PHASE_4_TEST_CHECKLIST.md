# Phase 4 — Manual Test Checklist

Phase 4 goal (per ROADMAP §4): A procedural Root Hollows + Glasswright Reaches with biome edges, ore distribution, the Anchor structure, and the supporting world-feature backlog (4.13–4.64).

Phase 4 exit criterion (verbatim):
> Spawn on Anchor. Walk in any direction → eventually cross into Glasswright
> Reaches → palette shifts → music shifts → ore tier changes.

Walk this top-to-bottom and report anything that fails. Section letters group by verification gate; numbered subsections cite the ticket id in **bold**.

**Pre-reqs:**
- Phase 0/1/2/3 checklists passed.
- Godot 4.6.x on PATH (`godot --version` returns 4.6.*).
- The 17 Gemini-generated sprites are imported (running `--import` once should be enough; the `.godot/imported/*.ctex` files for `bound_compass`, `skeleton_key`, `treasure_map`, `world_scanner`, `anchor_portable`, `mob_spawner`, `wishing_well`, `glow_shroom`, `locked_door`, `boss_altar`, `statue`, `lore_tablet`, `water_tile`, `sticky_tile`, `bridge_tile`, `trapdoor`, `scatter_decor`, `crystal_cluster` exist).

---

## A. Headless smoke (must pass before anything else)

```sh
godot --headless --path . --import
godot --headless --path . "res://scenes/world/main.tscn" --quit-after 5
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected:
- `--import` finishes without `SCRIPT ERROR` or `Parse Error` lines (RID-leak teardown noise at the very end is OK).
- The 5-second boot of `main.tscn` returns to the prompt with no GDScript backtrace.
- GUT prints **66/66 passing** (Phase 3 left 57; Phase 4 critical-path added `test_world_gen` (4) + `test_explored_chunks` (4) + earlier extended-closure expansions, landing at 66).

---

## B. Phase 4 critical-path (4.1–4.11)

### 4.1 — Chunk system at 64×64 tiles
1. Open `main.tscn` and walk east in a straight line.
2. The HUD coord readout (top-right, under the compass) should tick `(0,0) → (1,0) → (2,0) …` as you cross 64-tile boundaries.
3. **Expected:** new chunks generate one chunk ahead of you smoothly; no visible stutter on chunk boundaries.

### 4.2 / 4.3 — Noise walls + BFS ore veins
1. Stand near the Anchor and scan in a 60-tile radius.
2. Walls form clumpy cave shapes (not uniformly scattered specks).
3. Shaleseed ore appears in 2–4 small clusters per chunk; each cluster is contiguous, not isolated dots.

### 4.4 — Anchor structure prefab
1. New Game spawns on the Anchor plateau at (0,0).
2. The Resonance Loom, starter chest, and Loam Bench are pre-placed and visible in the same screen as the spawn.

### 4.5 — Resonance Loom set-spawn + slivers readout
1. Walk to the Loom and press **E**.
2. Panel shows `Aphelion Slivers: 70000 (100%)` and a `Set Respawn Here` button.
3. Click `Set Respawn Here`. Button changes to `Respawn Bound (Here)` (disabled).
4. Walk 20 tiles east and die (e.g., let a Stone-Hopper finish you).
5. **Expected:** you respawn at the Loom, not at the death point.

### 4.6 — [RETRACTED 2026-05-14] Biome boundary corridor tunnels
The earlier implementation carved permanent ±1 corridors along the world X/Y
axes, but that's **anti-parity** — Core Keeper gates biome rings with
progressively-harder walls (the player needs a Shaleseed Pickaxe to cross
into the Glasswright Reaches, etc.). Pre-cleared corridors trivialise the
progression. The corridor predicate has been removed from WorldGen. The
**only** always-clear zone is now the 7-tile Anchor plateau at world origin.

**What to verify instead:**
1. Walk east from the Anchor. Walls block your path within ~10 tiles.
2. You must mine walls with your pickaxe to advance.
3. Once you reach the Glasswright Reaches boundary (~80 tiles), the walls
   there require a tier-2 pickaxe — true CK-style progression gate.

### 4.7 / 4.8 — Biome ring transition
1. Walk east from Anchor. Around tile-x ≈ 80 you cross from Root Hollows (warm tan floor) to Glasswright Reaches (cool blue floor).
2. Floor tiles change. Ore tiles change to Clearstone (pale cyan).
3. Wall sprites change to the Glasswright variant.

### 4.9 — Biome ambient music swap
1. Same walk-east traversal. As you cross the boundary, the ambient music swaps from `ambient_root_hollows` to `ambient_glasswright_reaches`.
2. **Expected:** placeholder procedural pad changes pitch/timbre. Real audio replaces these in Phase 15.

### 4.10 — Map (mini + full-screen) with chunk reveal
1. Walk in any direction. Minimap (top-right) fills in chunk dots colored to match the biome accent.
2. Press **M** to toggle full-screen. Backdrop dims, minimap scales 2.5×.
3. Press **M** again to collapse back to the corner.
4. Save the game (pause menu → Save). Quit. Reopen. Load.
5. **Expected:** previously revealed chunks are still on the map.

### 4.11 — Compass to Loom
1. Top-right compass widget points an arrow toward (0,0) from anywhere in the world.
2. Distance label `N tiles to Loom` matches the actual distance.

---

## C. Phase 4 full-backlog features (4.12–4.64)

### 4.12 — Minimap fog of war
1. From a fresh New Game, look at the map: only chunks you've walked into are colored. Unexplored chunks are dark.

### 4.13 — Glow Tube already shipped in Phase 3; teleporter network is Phase 4.x.
1. Verified the existing `glow_tube` sprite renders on a placed tube; no regression.

### 4.14 — Bound Compass recall
1. Craft / cheat a `bound_compass` into your inventory.
2. Walk 100 tiles away from the Loom.
3. Right-click while holding the `bound_compass`.
4. **Expected:** you teleport to your bound respawn point. Cooldown engaged (60 beats ≈ ~23 minutes). Right-clicking again before cooldown shows "Compass still drowsing."

### 4.15 / 4.16 / 4.51 / 4.61 — Bounded mob spawning
1. Wall yourself into a 3×3 floor box (place 8 wall tiles around a center floor). No mobs should spawn inside the box.
2. Light a torch in an open area. The 80px torch radius around it should be mob-free.
3. Wait for night-Beat phase (Phase 0/1 = day, 2/3 = night per `AudioBus.is_day()`); mob density visibly rises while you're outside the safe zones.

### 4.17 / 4.59 — Mob spawner objects with elite tiers
1. Walk far enough to find a `mob_spawner` (rare; ~2.5% per chunk, scaled by biome stratum).
2. Stand within 12 tiles. Mobs spawn from it every 4 seconds, up to 3 alive at once.
3. Mine the spawner (it has 80–160 HP depending on tier). When destroyed it stops spawning and shows a toast.

### 4.18 / 4.50 — Procedural unique rooms
1. Explore. Roughly 4% of chunks contain a roughly-circular cleared room with a chest / wishing well / lore tablet / boss altar in the center.
2. Sub-biome pockets (see 4.44) bias toward treasure chests.

### 4.19 — Map markers
1. After dying, your minimap shows a purple Tombstone triangle at the death spot.
2. After using a `treasure_map`, a gold Treasure triangle appears at the nearest treasure_chest.

### 4.20 — Procedural lakes
1. Some chunks (~6%) contain a small water tile cluster — visible as deep navy tiles surrounded by floor.
2. Lakes never overlap the Anchor plateau.

### 4.21 — Abandoned camps
1. Roughly 5% of chunks past radius 24 contain a paired Statue + Chest "camp."
2. Statues show an "Abandoned camp." toast on approach.

### 4.22 — World-gen seed determinism
1. Note a chunk's wall arrangement and ore positions.
2. Save, quit, reload. Walk back to the same chunk.
3. **Expected:** identical wall + ore layout (deterministic per `world_seed`).

### 4.23 / 4.25 — Treasure chests + Skeleton-Key locking
1. Find a stand-alone treasure chest past radius 32. Interact: 25% chance it's locked.
2. If locked, the chest reports `Locked. Find a Skeleton Key.`
3. Acquire a `skeleton_key` (Wishing Well roll or other source). Right-click while holding it isn't the use-path; interact with the chest directly — it consumes 1 key and pops open.
4. On open, the chest deposits its rolled rare loot table (ingot, ancient_coin, aphelion_fragment, glow_tube; small chance bound_compass / world_scanner).

### 4.24 — Lore tablet anchors
1. Each biome ring has one Lore Tablet placed along the +X axis at the mid-radius.
2. Interact with E: unlocks a `tablet_<biome>_ring` compendium entry.

### 4.26 — Bridge tile placement
1. Find or craft a `bridge_tile`.
2. Hold left-click and drag across a water tile cluster.
3. **Expected:** bridge tiles deposit along the drag path (see 3.41), one per tile, consuming from inventory.

### 4.28 — Trapdoor
1. Find or place a `trapdoor_placeable` (16×16 hatch).
2. Walk onto it. It triggers and drops a single `loambeetle` to your inventory, then frees itself.

### 4.29 — Hidden walls
1. While mining walls in a wall-dense area, occasionally a mined wall reveals an unobstructed path that wasn't visible from the surface. (~6% of generated walls are flagged hidden.)

### 4.30 — Treasure map item
1. Right-click while holding a `treasure_map`. Marker appears on minimap at the nearest treasure chest within world.
2. The map is consumed.

### 4.31 — Coordinate HUD display
1. Top-right HUD shows `@ <tile_x>,<tile_y>  (<chunk_x>,<chunk_y>)` and updates every 0.25s as you move.

### 4.32 / 4.42 / 4.43 — Random world events
1. Stand still for ~5 minutes. Eventually one of three events fires:
   - **wandering_trader** → toast "A trader has arrived at the Anchor."
   - **suncrack** → toast "Suncrack — the Aphelion bleeds light." Slivers drop by 50 immediately; screen flashes red.
   - **hollowling_swarm** → toast "The Hollowling motes thicken." HollowlingMotes intensify around the player for ~4 beats.
2. Suncrack chance rises as the Aphelion dims (slivers fall below 50%).

### 4.33 — Roof / overhead detection
1. Build a wall ceiling over yourself (4 tiles north of player).
2. WorldGen.is_under_roof returns true. Verifiable via remote-inspector or future Buffs hook.

### 4.34 — Crystal regrowth (Glasswright Reaches)
1. In the Glasswright Reaches, mine a Clearstone ore tile.
2. Walk away from the tile (don't stand on it).
3. Wait 16 Aphelion Beats (~6 minutes).
4. **Expected:** the Clearstone tile regrows. Same biome-locked behaviour; other biomes don't regrow.

### 3.41 — Place-multiple drag-tool
1. Hold a stack of `bridge_tile` or `sticky_tile` in the hotbar.
2. Hold **left mouse button** and sweep the cursor across multiple 16-grid tiles within the placement radius.
3. **Expected:** one tile is placed per unique grid cell touched; the stack count drops by the number of tiles laid. Release the button to stop.

### 4.37 — Player-built statues
1. Pick up a `statue_placeable` item (currently from boss kill grant — placeholder until Phase 5 ships boss loot; can be cheat-granted via console).
2. Place via left-click. The statue sprite appears with the inscription toast on approach.

### 4.38 — World scanner
1. Right-click while holding a `world_scanner`.
2. **Expected:** all chunks within a 5-chunk radius are revealed on the minimap. Cooldown engaged (12 beats).

### 4.39 — Death compass mode
1. Press **J** to toggle. Toast: `Compass: Death` / `Compass: Loom`.
2. In Death mode, the compass arrow points to the last Tombstone marker (purple). The distance label reads `N tiles to grave`.

### 4.40 — Wishing well
1. Find a placed wishing well (procedural). Interact with **E**.
2. If you have 1 `ancient_coin`, it's consumed and a random reward from the table appears in your inventory.
3. The well silences itself until the next Aphelion Beat phase.

### 4.41 — Sticky tile
1. Place a `sticky_tile` via left-click or drag.
2. (Slow gameplay effect is reserved for Phase 11 weather hookup — the tile renders correctly today; gameplay slow lands later.)

### 4.44 — Sub-biome detection
1. In the Glasswright Reaches, walk until you hit a "Quiet Forge" pocket — visible as a denser cluster of crystal clusters and a higher chance of a treasure_chest in carved rooms.
2. WorldGen.sub_biome_at(coord, biome.id) returns `&"quiet_forge"` for these tiles.

### 4.46 — 24-min world clock
1. From New Game, watch the world clock phase progress: `dawn` → `day` → `dusk` → `night` over 24 real-time minutes.
2. World clock is independent of the 23s Aphelion Beat — you can be in Beat phase `low_light` while the world clock says `day`.

### 4.47 — Heat/cold gradient
1. Walk into the Vesari Necropolis (salt_corrosion hazard) or Emberforge.
2. WorldGen.temperature_intensity_at returns 0..1 — 0 at the biome's inner edge, 1 at the outer edge. (Visualisation reserved for Phase 11 polish; the API works today.)

### 4.48 — World border
1. Walk in any direction for ~1600 tiles (long sprint).
2. **Expected:** chunks past radius 1600 are painted solid walls. The world feels bounded.

### 4.49 — Anchor portable item
1. Get an `anchor_portable` into your inventory.
2. Walk 50 tiles from the Loom. Right-click while holding the anchor.
3. **Expected:** `GameState.respawn_point` updates to your current spot. Anchor is consumed. Die — you respawn at the new anchor point.

### 4.52 / 4.63 / 4.64 — Bed sleep
1. Build/place a bed (Phase 5 ships the real bed scene; today only `try_sleep_in_bed` is invokable).
2. With a hostile mob within 200 px, sleep is blocked with toast "Too dangerous to rest here."
3. After sleeping, screen letterboxes for 1.5s, then 8 minutes of world-clock time advance (dawn→day if you slept at dawn). HP regenerates 25% on wake.
4. Try to sleep again within 8 beats — blocked with "You're not tired enough yet."

### 4.53 — Glow Shroom planting
1. Plant a `glow_shroom_seed` on a floor tile.
2. **Expected:** scenes/structures/glow_shroom.tscn instantiates with a cyan PointLight2D. The shroom is registered in the "light_source" group so it suppresses mob spawns within 80 px (verifies 4.51 too).

### 4.54 — Boss altar
1. Defeat a placeholder boss (you can simulate by calling `GameState.mark_boss_defeated(&"glaur_em")` from the remote inspector).
2. Find a boss_altar (placed in deep-stratum rooms by 4.18).
3. Interact: it accepts 1 `aphelion_fragment` and re-summons the boss.

### 4.55 — Floor scatter decorations
1. Chunks contain 0–3 small scatter_decor decals (bone fragments + pebbles) placed on the floor. Purely cosmetic.

### 4.60 — Locked dungeon doors
1. Find a `locked_door` (placed inside procedural rooms).
2. Interact without a key: "Locked. You feel a keyhole."
3. Interact with a `skeleton_key` in inventory: the door consumes 1 key and opens (becomes passable + dims sprite). Stays open for the session.

### 4.62 — Player tombstone marker
1. Die.
2. Minimap shows a purple Tombstone triangle at the death position.
3. Reclaim the stash by walking onto it — the marker disappears.

### 3.73 — Glasswright crystal cluster (multi-tile resource)
1. In the Glasswright Reaches, find a `crystal_cluster` (32×32 pale-cyan crystal shards on a basalt base; ~10% per chunk).
2. Hit it with a Clearstone-tier pickaxe.
3. **Expected:** Each hit chips off one shard, dropping 1–3 Clearstone + 2 Mining XP. The sprite scales down with each break. After 4 shards (each ~12 HP) the cluster destroys itself with a break_crystal SFX.

---

## D. Persistence + save format v4

### SaveSystem v3 → v4
1. New Game. Walk in any direction (chunks visit). Plant your respawn at the Loom. Die once.
2. Save. Quit. Reload.
3. **Expected:** 
   - Minimap retains explored chunks (4.10).
   - GameState.respawn_point retained (4.5).
   - Tombstone marker survives if you saved before reclaiming.
   - Chest contents persist (Phase 3 v3 still works).
   - Older v1/v2/v3 saves load with empty explored_chunks and respawn_point=(0,0) — fresh map, fresh anchor.

---

## E. Regression sanity (must not break)

1. Mining a wall still rewards Loam + Mining XP (Phase 2).
2. Hitting a Stone-Hopper still rewards Melee XP and drops loot (Phase 2).
3. Crafting at the Loam Bench still works (Phase 3).
4. Chest open/deposit/withdraw still works (Phase 3).
5. Save/Load round-trip preserves Inventory + Skills + Equipment (Phase 3).

---

## F. Known scope deferrals (do **not** test for Phase 4)

These tickets were reassigned out of Phase 4 — don't flag them missing:
- **Phase 14**: 4.27 liquid pumping, 4.35 liquid mixing rules, 4.36 tile-conversion rules.
- **Phase 15**: 4.45 biome-blending shader, 4.65 first-run wizard.
- **Phase 11**: 4.56 weather effects, 4.57 weather affects gameplay, 4.58 wind direction.

These remain placeholders pending later phases:
- 4.13 teleporter network (sprite ships now; teleport network is Phase 4.x polish).
- 4.41 sticky-tile gameplay slow (tile + placement ship now; slow-mob effect lands with Phase 11 weather work).
- 4.47 per-tile temperature visuals (API exposed; rendering ships with Phase 11).

---

## G. Sign-off

Phase 4 is considered passed when **every section A–E** has a green check or a logged ticket. Anything in **F** is intentionally out-of-scope.

Report failures with:
1. Section letter + number.
2. Expected vs observed.
3. Repro steps (seed + chunk coord if procedural).
