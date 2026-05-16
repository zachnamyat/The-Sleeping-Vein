# Phase 10 — Manual Test Checklist

> Companion to `tests/unit/test_phase10_systems.gd` (24 GUT cases). This file
> covers play-through, environmental, and visual checks that can't be automated.

**Save format:** v8 (bumped from v7). Older saves load with an empty
`phase10_helpers` block — boss cooldowns / kill counts / quest state all start fresh.

**Toggles to know:**
- The breath meter (`scenes/ui/breath_meter.tscn`) shows automatically while the
  Walker is on a water tile or inside the Drowned Aphelion biome ring.
- TileSet sources 30..33 are the new hazard tiles (slime / acid / cobweb /
  verdant_soil). 30..32 spawn through `world_gen._paint_hazard_tiles` in their
  biome. 33 is a placeable.
- Boss arenas inherit the existing Phase 5.25 gate-lock behaviour from `boss.gd`.

---

## 1. Vesari Necropolis biome (10.1, 10.4, 10.16)

- [ ] Walk past 160 tiles from the Anchor → biome name changes to "The Vesari Necropolis".
- [ ] Floor + walls + ore use the existing Necropolis sprites (Phase 4.8 carry-over).
- [ ] Mob spawns rotate among **salt_bound_sailor**, **coral_hollow**, **tideglass_cricket**.
- [ ] Tideglass Cricket flees instead of chasing (CRITTER_FLEE behaviour).
- [ ] Salt corrosion ticks once per second: 1 hp damage + a single durability point
  decays on one random equipped item every 10s.
- [ ] Equipping any salt-resist armor (with id stored in `biome.resist_armor_id`)
  halves the damage to 1; an item with id `coral_veil` would immune the player
  but salt_corrosion uses no resist_item by default.
- [ ] When an equipped item's `current_durability` hits 0, it is unequipped and a
  toast says "Your X corroded to dust!".
- [ ] Sparse pockets of slime + acid tiles appear inside the biome (10.24/10.25).

## 2. Sunless Verdancy biome (10.2, 10.5, 10.15)

- [ ] Past 240 tiles → biome name "The Sunless Verdancy".
- [ ] Mob spawns rotate among **spore_lurk**, **vine_stalker**, **bloom_hag**.
- [ ] Verdant Hare + Glow Crane are passive critters (CRITTER_FLEE) — they don't
  attack and run from the player.
- [ ] Toxic spore hazard ticks 3 poison damage / second AND applies a 2s poison
  status (visible in StatusOverlay).
- [ ] Equipping the **Gas Mask** zeroes the damage entirely.
- [ ] Cobweb + verdant_soil tile pockets appear inside the biome (10.23/10.26).

## 3. Drowned Aphelion biome (10.3, 10.6)

- [ ] Past 320 tiles → biome name "The Drowned Aphelion".
- [ ] Mob spawns rotate among **deep_mawl**, **hollow_coral**, **wreck_wraith**.
- [ ] Lantern Squid + Brinekin flee passively.
- [ ] Entering the biome triggers the "Ghostly sailors drift past — they cannot
  see you" Echo (10.43) once per save.
- [ ] Breath meter appears in the HUD as a cyan-amber-red bar above the hotbar.

## 4. Swimming + breath (10.7, 10.8, 10.20, 10.21)

- [ ] Step onto a water tile (Phase 4 lakes) → speed drops to 55%.
- [ ] Submerged in Drowned Aphelion → ambient current nudges you in a slow,
  consistent direction (the vector flips along world position).
- [ ] Breath meter drains over 30 seconds. At 25% remaining, a toast says
  "Breath is low — surface or hold a Coral Veil!".
- [ ] At 0 breath, you take 6 damage every second labelled "Drowning!".
- [ ] Pick up a **Coral Veil** → breath drains 2.5× slower.
- [ ] Pick up **Underwater Goggles** → small extension (~17%).
- [ ] Exit water → breath restores at 6/s.

## 5. Vorr'kell boss (10.9)

- [ ] Spawn the boss via the BossAltar (Phase 4.50). Three-phase fight:
  1. Tunneling (slam telegraphs at 40px radius)
  2. Segmented lash (slam patterns more frequent)
  3. Singing (ranged_arc only, faster cooldown)
- [ ] Drops: Stone-Father's Pulse equivalent ("clearstone_resonator" pulse) +
  **Vorr'kell's Lantern** + name_fragment_2 + trinket + Ancient Coins.
- [ ] On first kill: Vorr'kell entry appears in Phase10Helpers.kill_counts = 1
  (no Awakened yet).
- [ ] Defeat enables boss cooldown of 60 beats. Resummon attempt within cooldown
  fails until Phase10Helpers.boss_cooldowns goes to 0.

## 6. Spawnmother boss (10.10)

- [ ] Stationary boss; HP bar reads "The Spawnmother of Carrion Hollows".
- [ ] Spawns Coral Hollow minions every 4.5s up to 4 alive.
- [ ] Drops **Coral Veil** as the pulse-replacement item.

## 7. Sythrenn — mercy-kill alt (10.11)

- [ ] At phase 3 (HP ≤ 20%), the first hit landed within 18px of the boss
  centre flags `mercy_killed = true` (toast: "You strike the inner bloom — a mercy kill.").
- [ ] Mercy kill drops **Verdant Heart** + **Sythrenn's Last Petal** + fragment
  + trinket + Ancient Coins; sets `GameState.collected_relics[&"sythrenn_mercy_killed"] = true`.
- [ ] Hit landed outside 18px flags `mercy_killed = false` ("You strike the
  outer body — Sythrenn dies hard.") and drops the standard loot table.
- [ ] During phase 2, three spore-spread zones rotate around the boss
  (Phase10Helpers.sythrenn_spore_zones), applying poison if the Walker stands
  within 48px of any zone.

## 8. Auriax boss (10.12, 10.41)

- [ ] Mega-boss (96×96). Four-phase fight; phase 2/3 switch to AURIAX_PHASE2
  (faster, magic-element pulses + falling petals).
- [ ] Drops the **Verdant Heart** as the second Loom power-up + name_fragment_5
  + trinket + Ancient Coins.
- [ ] Bigger defeat shake (intensity 8, duration 2s).
- [ ] 200 beats after defeat: "The named tree falls silent" toast (10.36 dying
  forest event); 30 beats later: "One sprig of Verdancy still grows from the
  ash" (10.47 mercy moment).

## 9. Vol'thaar — release-or-kill (10.13)

- [ ] At HP fraction 0.05, the boss freezes; toast:
  "Vol'thaar: \"I asked for the long quiet.\" — drop your weapon to release."
- [ ] Within 5 seconds: switch off the weapon (cycle hotbar to a non-weapon
  slot). The boss dissolves; toast "Vol'thaar dissolves into the dark.";
  drops **Vol'thaar's Promise** (necklace).
- [ ] Keep the weapon equipped for the full 5s → window closes, boss resumes
  in phase-2 lullaby attack pattern.
- [ ] `GameState.collected_relics[&"volthaar_released"] = true` after a
  successful release.

## 10. Drowned Crown — optional boss (10.14)

- [ ] Optional encounter; deep Drowned Aphelion only.
- [ ] On defeat, instead of a fanfare: letterbox fade, toast
  "The Drowned Crown lays down the sword and walks into the deep."
- [ ] Drops **Drowned Diadem** (vanity helm) + **Sword of the Last Threnos
  King** (tier-6, lifesteal_fraction 0.08, two_handed) + 3 coral_fragment.

## 11. Boss cooldown + Awakened variants (10.17, 10.18)

- [ ] Open DevConsole, run `print(Phase10Helpers.cooldown_remaining_beats(&"boss_vorrkell"))`
  immediately after the kill → ≥ 60.
- [ ] Wait the equivalent beats (or run `Phase10Helpers.boss_cooldowns[&"boss_vorrkell"] = 0`
  then `Phase10Helpers.boss_respawn_ready.emit(&"boss_vorrkell")`).
- [ ] Defeat a second time → `Phase10Helpers.awakened_available[&"boss_vorrkell"] = true`,
  toast "Awakened variant available: boss_vorrkell".
- [ ] Phase10Helpers.awakened_config(&"boss_vorrkell") returns hp_mult 1.45,
  damage_mult 1.30, speed_mult 1.15.

## 12. Pack AI (10.19)

- [ ] Walk into a new chunk in Vesari/Verdancy/Drowned biomes ~5 times. ≥ 1
  in 5 chunks should spawn 2-4 mobs of the same id within 3 tiles of each
  other (the pack-pick path in `world_gen._spawn_mobs`).

## 13. Tile hazards (10.24, 10.25, 10.26)

- [ ] Step on a slime tile → brief slow (0.4 magnitude, 0.6s) + sideways drift.
- [ ] Step on an acid tile → 4 poison damage every 0.5s while standing on it.
- [ ] Step on a cobweb tile → 75% speed for 1s.
- [ ] EventBus emits `player_entered_hazard_tile` + `player_exited_hazard_tile`
  with the tile kind StringName.

## 14. Verdant Soil + Vines + Mushroom Propagation (10.23, 10.27, 10.28)

- [ ] Place a Verdant Soil tile inside Verdancy. The scene group is
  `verdant_soil`; growth_factor() returns 1.5.
- [ ] `Phase10Helpers.can_climb_walls_here(player_pos)` returns true only when
  the player is in Sunless Verdancy.
- [ ] Place a glow_shroom inside Verdancy. After 6 Aphelion beats, an
  adjacent tile sometimes hosts a new glow_shroom (30% chance per parent,
  cap 3 per parent).

## 15. Equipment defs (10.29, 10.30, 10.31, 10.32)

- [ ] All four items appear in ItemRegistry: underwater_goggles, lava_boots,
  frost_boots, gas_mask.
- [ ] Equip lava_boots → fire-resist 25%; stepping on a lava tile (source 34)
  no longer takes damage.
- [ ] Frost_boots → cold-resist 25%.
- [ ] Gas_mask → poison-resist 50% + immune to toxic_spore hazard tick.

## 16. Pheromone trail (10.33)

- [ ] Damage a Coral Hollow → call `Phase10Helpers.emit_pheromone(pos, &"vesari_necropolis")`.
- [ ] Other Coral Hollows within 96px should aggro for free (the
  pheromone_present helper returns true).

## 17. Per-biome champion-affix bias (10.34)

- [ ] `Phase10Helpers.biome_affix_bias(&"vesari_necropolis")` returns
  `[&"affix_armored", &"affix_brittle"]`.
- [ ] `Phase10Helpers.biome_affix_bias(&"sunless_verdancy")` returns
  `[&"affix_venomous", &"affix_swift"]`.

## 18. Boss-arena music + cinematic camera (10.35, 10.49)

- [ ] Engaging Auriax fires `AudioBus.play_music(&"boss_auriax_theme")`.
- [ ] At Auriax phase 2: BOSS_PHASE_CAMERA returns `{ shake: 8.0, zoom: 1.5,
  letterbox: true }`.
- [ ] `Phase10Helpers.cinematic_camera_for(&"boss_glaurem", 0)` returns `{}`
  (no Phase-10 config for Glaur-em).

## 19. Lore moments (10.36–10.43)

- [ ] Defeat Auriax → 200 beats later, `verdancy_named_tree_death` lore moment
  fires once.
- [ ] Enter Verdancy after Auriax defeat → `laughing_child_echo` lore moment
  fires once.
- [ ] Enter Drowned Aphelion → `underwater_echo_sailors` lore moment fires once.
- [ ] Approach the Spawnmother's threshold once → `spawnmother_toy` lore moment
  surfaces a one-shot toast.
- [ ] Find a Sythrenn pacifist mural (Phase 5.35 retained) inside Verdancy →
  one of three `sythrenn_pacifist_mural_1/2/3` fires (one per visit).

## 20. Sunken Glyph collection (10.42)

- [ ] Pick up 7 Sunken Glyph Fragments. Counter caps at 7.
- [ ] Collecting the 7th fires `hall_of_first_names_unlocked` lore moment with
  a 23-second timer ("The names rise.").

## 21. Larva Trap + Pup pet (10.44, 10.45)

- [ ] Place a Larva Trap. When a hostile mob enters, 60% slow applies to all
  mobs within 64px for 8 seconds; the trap self-destructs after 0.5s.
- [ ] Trigger state persists in dump_state. Reloading a saved trap
  re-instantiates the destroyed state.
- [ ] After Spawnmother defeat or kill cluster in Verdancy → 5% drop chance
  of `pet_pup` item (open Inventory to verify the equipment_slot is `pet`).

## 22. Glow-Crane sub-quest (10.46)

- [ ] Brindle dialogue unlocks: `Phase10Helpers.unlock_glow_crane_quest()`
  → quest_state becomes `active`.
- [ ] Hunt 3 Glow-Cranes → each drops 1 `glow_crane_feather`.
- [ ] `Phase10Helpers.deliver_glow_crane_feathers(3)` returns true; quest
  becomes `done`, Brindle gives `recipe_scroll` + `vorrkell_lantern`.

## 23. Per-biome reverb (10.50)

- [ ] Cross into Drowned Aphelion → `AudioBus.current_reverb_profile`
  becomes `{ wet_db: 1.8, room_size: 0.85 }`.
- [ ] Cross into Sunless Verdancy → `{ wet_db: 0.4, room_size: 0.30 }`.
- [ ] Cross back to Root Hollows → no profile registered for it (Phase 10
  table only covers the new biomes).

## 24. Persistence + save format v8

- [ ] Trigger several Phase 10 effects: kill Vorr'kell, collect 3 Sunken Glyphs,
  start Glow-Crane quest, advance Verdancy age 50 beats.
- [ ] Save the world. `user://saves/<slot>/state.json` has a `phase10_helpers`
  block containing boss_cooldowns, kill_counts, awakened_available,
  lore_moments_fired, verdancy_age_beats, sunken_glyph_fragments_collected,
  glow_crane_quest_state, glow_crane_feathers_delivered, beat_counter.
- [ ] Reload the world. Phase10Helpers.dump_state() matches the saved values.

## 25. Sprites + assets

- [ ] `assets/sprites/enemies/{vesari_necropolis,sunless_verdancy,drowned_aphelion}/`
  each contain the 4 split-cell sprites generated this pass plus the
  pre-existing salt_bound_sailor / spore_lurk / deep_mawl.
- [ ] `assets/sprites/items/` contains the 16 Phase 10 icons (coral_veil…
  glow_crane_feather).
- [ ] `assets/sprites/tiles/` contains tile_slime, tile_acid, tile_cobweb,
  tile_verdant_soil at 16×16.
- [ ] `assets/sprites/vfx/` contains env_toxic_spore (64×16, 4-frame) and
  env_salt_corrosion (64×16, 4-frame).

## 26. GUT tests

- [ ] Run GUT: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gconfig=res://.gutconfig.json -gexit`.
- [ ] Pass count is 28 in `test_phase10_systems.gd`; 196/196 overall pass.
  The Phase 9 housing-autoload tests pass too now after fixing the
  inferred-type bug at `housing.gd:47`, the `Color()` arg-count error in
  `vorrkell_lantern.tres`, and the `price_multiplier_for_mood` fallthrough
  in `merchant_inventory.gd`.
