# Phase 8 — Farming, Cooking, Fishing: Manual Test Checklist

> Use this checklist to sign off on Phase 8 visually + interactively. The
> 140/140 GUT suite (`test_phase8_systems.gd` + earlier suites) covers the
> data tables, recipe math, save round-trip, and pet flow; this document walks
> the in-engine flows that the unit tests can't reach. Step through every
> section in order on a fresh world; tick each line as you go. Anything that
> doesn't behave should be filed as a Phase-8 follow-up ticket and the
> corresponding kanban entry reopened.

---

## 0 — Setup (do once)

- [ ] Open `scenes/world/main.tscn` and run it.
- [ ] Confirm there are **no script-load errors** in the Output dock (especially
      around new autoloads `CookingSystem`, `Critters`, `Pets`).
- [ ] Open the dev console (`~`) and verify autoloads resolve:
      `print(CookingSystem.FOOD_BUFFS.size())` should print `20`.
- [ ] `print(FarmingSystem.SEED_MAP.size())` should print `6`.
- [ ] `print(FishingSystem.ROD_DATA.size())` should print `7`.

## 1 — Farming critical path (8.1, 8.2, 8.3, 8.4, 8.7-extra)

> Quickest setup: console
> `Inventory.try_add(&"hoe", 1); Inventory.try_add(&"watering_can", 1);
>  Inventory.try_add(&"pale_cap_seed", 5); Inventory.try_add(&"bloat_oat_seed", 3)`.

- [ ] Hotbar the Hoe → click the floor → a brown `TilledSoil` tile appears,
      toast `Planted.` does NOT fire (that's seeds). Tile darkens slightly.
- [ ] Hotbar the Pale Cap Spore → click on the soil → toast `Planted.`,
      `PlantedCrop` appears as a small green dot.
- [ ] Hotbar the Watering Can → click on the soil → toast says soil is watered;
      crop sprite turns cyan, growth doubles.
- [ ] Wait ~30s (50% of base 60s with watering) — crop scales up + turns golden
      = mature. Walk over → harvest (`Pale Cap` enters inventory).
- [ ] Plant a `bloat_oat_seed` next. After harvest, the crop should **not**
      despawn — it goes back to stage 2 and re-matures (8.19 multi-harvest).
- [ ] Plant a `bomb_pepper_seed`. Step on it BEFORE maturity — it still
      explodes for ~22 dmg to mobs / 8 dmg to player (8.45).
- [ ] Plant a `glow_cap_seed`, water it, harvest at maturity. A glow mushroom
      replaces it (8.46).
- [ ] Plant a `heart_berry_seed`. After harvest it should regrow (multi-harvest)
      and the cropped berries restore 14 HP each (8.47).

## 2 — Fertilizer + Greenhouse (8.31, 8.17)

- [ ] `Inventory.try_add(&"fertilizer", 5)` and use on a tilled-soil tile —
      tile tint shifts to a warm brown, the toast does not need to say anything
      explicit but the crop on it should grow 1.5× faster.
- [ ] `Inventory.try_add(&"greenhouse_placeable", 1)` and place near tilled soil.
      Crops within 64 px grow 1.6× faster (compounds with fertilizer).

## 3 — Sprinkler automation (8.13)

- [ ] `Inventory.try_add(&"sprinkler_placeable", 1)`, place inside a row of 6
      tilled-soil tiles.
- [ ] Wait one Aphelion Beat — every tile in radius is moist; planted crops
      gain the watered modifier.
- [ ] After ~6 beats with no manual watering, tiles dry out again unless the
      sprinkler is in range.

## 4 — Cooking pot + first 20 recipes (8.5, 8.6, 8.8)

> Build the pot first: `Inventory.try_add(&"cooking_pot_placeable", 1)` and place
> it. Walk up and press **E** to open the crafting panel filtered for it.

- [ ] CraftingPanel opens with `cooking_pot` station selected; lists at least
      18 cooking recipes (the rest live on Oven / Drying Rack / Composter).
- [ ] Craft `Pale Cap Stew` — toast `Discovered: Pale Cap Stew` plays + a sting.
      Cookbook (B) marks it discovered.
- [ ] Craft `Bloat Loaf` (needs 3 Bloat Oat) — same discovery flow.
- [ ] Craft `Fish Stew` (needs cave_guppy + memory_root) — discovery flow.
- [ ] Craft `Pepper Chili` (needs 2 bomb_pepper + 1 memory_root) — discovery flow.
- [ ] Build a Mill + Oven (recipes unlock when you build a Clearstone Forge),
      grind oats to flour, then bake Bread + Berry Pie + Mining Focus Loaf at
      the Oven.

## 5 — Food buff stacking (8.7)

- [ ] Eat `Pale Cap Stew` (category `hp`) → BuffStrip shows `buff_well_fed`.
- [ ] Eat `Bloat Loaf` (category `hp`) → `buff_well_fed` should disappear,
      replaced by `buff_oat_strength`. Same category → exclusive.
- [ ] Eat `Memory Root Broth` (category `mana`) — coexists with the hp buff.
- [ ] Eat `Heart Berry Jam` (category `regen`) — coexists with the others.
- [ ] Total simultaneously-active buffs: 3 (hp + mana + regen).

## 6 — Cookbook UI (8.8, 8.28)

- [ ] Press **B** — Cookbook opens.
- [ ] Page header: `Hearth Cookbook [B] page 1/N ←/→`.
- [ ] Undiscovered recipes render as `??? (undiscovered)` with `Hint: includes
      <first ingredient>`.
- [ ] Press **→** or **D** to flip to page 2 — listing shifts.
- [ ] Discovery count footer reads `Discovered N of M`.

## 7 — Fishing minigame (8.9, 8.10, 8.11, 8.12)

> Hotbar a `fishing_rod_wood`. Bait off-hand: `Inventory.try_add(&"bait_basic", 5)`
> then `Inventory.equip(&"off_hand", &"bait_basic")`.

- [ ] Click while holding the rod → FishingMinigame overlay appears, label
      reads `Cast — wait for bite`, bar fills over 5 seconds.
- [ ] At the bite, label flips to `BITE! Click to hook` and bar turns orange.
      Click within ~1.2s.
- [ ] Reel stage: label `Reel — hold inside the bar`. Hold attack_primary while
      the green target bar wobbles; keep your bar near the target.
- [ ] Within ~3.5s the green bar fills → `Caught!` and a fish enters inventory.
- [ ] Missing the click during BITE → toast `Bite missed.`, no fish.
- [ ] Cast with `bait_glow` equipped → catches lean rarer (run 5 times to feel
      the bias).
- [ ] Use `fishing_rod_iron` (`Inventory.try_add(&"fishing_rod_iron", 1)`) — cast
      takes 3s, hook window tightens.
- [ ] Cast in 4 different biomes by walking → the fish you reel in differs
      (Root Hollows yields cave_guppy/root_bream/glow_eel; Glasswright yields
      tide_perch/glass_pike; Necropolis yields vesari_eel; Drowned yields
      deep_pike/drowned_pearl).

## 8 — Fishing trophy mount + tournament (8.36, 8.37)

- [ ] Catch ~5 cave_guppies. Place a `fish_trophy_placeable` and set
      `displayed_fish = &"cave_guppy"`.
- [ ] Press E next to it — toast shows `Heaviest cave_guppy: NNNg`.
- [ ] Console: `FishingSystem.start_tournament(60.0)` → tournament toast.
- [ ] Catch a fish during the tournament; verify `FishingSystem.tournament_score`
      grew.

## 9 — Aquarium (8.14)

- [ ] Place `aquarium_placeable`. Press E with `cave_guppy` hotbarred → toast
      `Added to aquarium.` (1 of 4).
- [ ] Repeat with up to 4 different fish.
- [ ] Press E with nothing held → toast lists every fish inside.

## 10 — Composter + Drying Rack + Mill + Oven (8.16, 8.23, 8.29, 8.30, 8.35, 8.40)

- [ ] Place a Composter. Walk up + press E → CraftingPanel filters to `composter`
      and shows the `Loam Fertilizer` recipe.
- [ ] Place a Drying Rack. Open it → `Dried Meat`, `Glaur-em Jerky`.
- [ ] Place a Mill (requires Clearstone Forge). Open → `Flour`.
- [ ] Place an Oven. Open → `Bread`, `Berry Pie`, `Honeyed Loaf`,
      `Stratasinger's Loaf`.

## 11 — Beekeeping (8.18, 8.39)

- [ ] Place `beehive_placeable` near a planted Heart Berry / Pale Cap / Glow Cap.
- [ ] Wait ~8 beats (~3 min) — every 8 beats, `stored_honey` increments.
- [ ] Press E at the hive — toast `Harvested honey.`, count adds to inventory.
- [ ] Use 1 honey + 1 bread at the Oven → `Honeyed Loaf` (buff +10% movespeed).

## 12 — Pot Planter + Trellis (8.22, 8.32)

- [ ] Place a `pot_planter_placeable` indoors. Plant any seed on it — soil stays
      moist permanently (no drying out).
- [ ] Place a `trellis_placeable`. Try to plant `pale_cap_seed` → toast
      `Trellis only accepts vine crops.`. Plant `bloat_oat_seed` instead → ok.

## 13 — Sapling + Crystal/Coral Sprig (8.33, 8.34)

- [ ] Place a `sapling_placeable` on an open floor tile. Wait ~24 beats
      (~9 min) — sapling sprite scales up; on the 24th beat, replaced by a Tree
      scene (axe-fellable for wood).
- [ ] In Glasswright Reaches, place a `crystal_sprig` → matures into a
      Crystal Cluster after 32 beats. Outside Glasswright, the timer triples.
- [ ] In Drowned Aphelion, place a `coral_sprig` → matures into a coral pickup;
      walk over to collect 1-3 `coral_fragment`.

## 14 — Net Trap (8.21)

- [ ] Place `net_trap_placeable` near a water tile. Wait ~12 beats.
- [ ] Walk up and press E — toast `Collected N fish.` with a small tier-1/2 haul.

## 15 — Bug Net + critters (8.15)

- [ ] Hotbar `bug_net`. Wait a few beats — small drifting `critter` nodes spawn
      near the player in their current biome.
- [ ] Swing the bug net (click) at one — caught critter enters inventory as
      `critter_glow_moth` (or whatever species the biome assigned).
- [ ] Swing with no critter in range → no catch, but a `net_swing` placeholder
      tone plays.

## 16 — Canteen + water source (8.24)

- [ ] Hotbar an empty `canteen`. Press RMB on dry land — toast `Stand next to
      water.`
- [ ] Walk onto a procedurally-generated lake (Phase 4.20 spawns them) and
      RMB the canteen → toast `Canteen filled.`, item swaps to `canteen_full`.
- [ ] RMB the full canteen → 16 HP restored + Burn status cleared, item swaps
      back to empty.

## 17 — Pets (8.25, 8.41, 8.49, 8.50)

- [ ] Console: `Pets.tame(&"pet_pale_fox", &"heart_berry")` → toast
      `Tamed: Pale Fox`. Pet item appears in inventory.
- [ ] `Inventory.equip(&"pet", &"pet_pale_fox")`. Kill a Stone-Hopper → pet XP
      ticks up by 1.
- [ ] `Pets.feed(&"pet_pale_fox", &"heart_berry")` (favorite) → +3 XP.
- [ ] `Pets.feed(&"pet_pale_fox", &"pale_cap")` (neutral) → +1 XP.
- [ ] Console: `Pets.mark_dead(&"pet_pale_fox")` → toast collapse warning.
- [ ] Without a Revive Charm: `Pets.try_revive(&"pet_pale_fox")` → toast
      `Pet Revive Charm required.`
- [ ] `Inventory.try_add(&"pet_revive_charm", 1)` then revive → pet alive again.

## 18 — Save round-trip (v5 → v6)

- [ ] Cook 4 different foods (mark them discovered).
- [ ] Catch 3 fish so `FishingSystem.trophies` has 3 entries.
- [ ] Tame a Pet and feed it twice.
- [ ] Plant 4 crops, water 2, fertilize 1 with `fertilizer`.
- [ ] Save the game.
- [ ] Quit to title; reload the slot.
- [ ] Cookbook shows the 4 discovered recipes.
- [ ] `FishingSystem.trophies.size()` returns 3.
- [ ] `Pets.pets[&"pet_pale_fox"]` has the saved xp/level/mood.

## 19 — Recipe-unlock sting (8.38)

- [ ] Craft a brand-new recipe at the Cooking Pot you haven't made before →
      `cook_discovery` SFX plays, toast `Discovered: <name>` appears.
- [ ] Craft the same recipe again → no sting, no toast (already discovered).

## 20 — Misc Phase 8 polish

- [ ] Eat a `Glaur-em Jerky` post-Glaur-em — receives `buff_stoneblood` (hp
      category) for 6 minutes.
- [ ] Build a Composter, craft `Loam Fertilizer` from 2 loambeetle + 1 loam.
- [ ] Build a Mill + Oven and craft `Stratasinger's Loaf` (8.27 fuel
      consumption is a Phase 15 polish bullet; for now the loaf cooks free).
- [ ] Bait Crafting (8.20): craft `bait_glow` from glow_cap + loambeetle at the
      Loam Bench.

---

## Sign-off

- [ ] **All 140 GUT tests pass headlessly** (`godot --headless --path . -s
      addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`).
- [ ] **All 20 sections above ticked.**
- [ ] Phase 8 in `kanban.html` shows 0 backlog tickets after the
      `2026-05-15-phase8-full-closure` migration runs.
- [ ] Manual sign-off recorded in `ROADMAP.md` Phase 8 exit-criterion line.
