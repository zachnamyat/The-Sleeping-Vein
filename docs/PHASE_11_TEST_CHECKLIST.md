# Phase 11 — Manual Test Checklist

> Companion to `tests/unit/test_phase11_systems.gd` (44 GUT cases). This file
> covers play-through, environmental, and visual checks that can't be automated.

**Save format:** v9 (bumped from v8). Older saves load with an empty
`phase11_helpers` block — frostbite, Pyrenkin sub-quest progress, Wormbound
covenant state, Hymnal chord state, journal + tablet counters all start fresh.

**Toggles to know:**
- Frostbite meter (`scenes/ui/frostbite_meter.tscn`) appears automatically while
  the Walker is in a cold zone (Auroric Veil or Salt Wastes night).
- Heat-shimmer overlay (`scenes/ui/heat_shimmer.tscn`) appears while the Walker
  is in an Emberforge heat zone (or Salt Wastes day).
- Pyrenkin Bellows requires a `fuel_pellet` to operate. Burns through one pellet
  every 4 Aphelion Beats.
- Hymnal Vault chord is hotbar_1 = low, hotbar_2 = high. Correct sequence:
  low → high → low.
- Wormbound elder gesture: WASD up → right → down (no left).

---

## 1. Emberforge biome (11.1, 11.4, 11.17)

- [ ] Walk past 400 tiles from the Anchor → biome name changes to "The Emberforge Strata".
- [ ] Mob spawns rotate among **slag_hound**, **forge_echo**, **ember_lurker**,
  **forge_cricket**, **charred_goat**.
- [ ] Forge-Cricket + Charred Goat flee from the Walker (CRITTER_FLEE behaviour,
  contact_damage 0).
- [ ] Ambient heat hazard ticks 4 fire damage / second.
- [ ] Equipping **Ember-Iron Chestpiece** halves the tick to 2 (status_resists
  fire 0.4 on the chestpiece + 0.0 default = ~40% reduction).
- [ ] Holding **Skoldur's Hammer** in inventory adds another 50% reduction, so
  total combined damage is reduced to 1 per tick (cap at 0.95 resist).
- [ ] Heat-shimmer overlay visibly fades in over 0.5–1 s when entering the biome,
  with a warm amber tint + subtle vertical ripple band.
- [ ] Heat-shimmer fades out smoothly when leaving the biome.

## 2. Salt Wastes biome (11.2, 11.6, 11.19)

- [ ] Past 480 tiles → biome name "The Salt Wastes of Dawning".
- [ ] Mob spawns rotate among **salt_hopper**, **dawning_predator**,
  **wormbound_stalker**, **salt_cat**, **wormbound_elder** (rare).
- [ ] Salt-Cat is a passive critter (CRITTER_FLEE).
- [ ] **Day** (AudioBus.is_day() == true, Aphelion phases 0–1): hazard ticks
  fire damage. Toast reads "Dawning Heat — N fire".
- [ ] **Night** (Aphelion phases 2–3): hazard ticks cold damage AND frostbite
  meter rises. Toast reads "Dawning Chill — N cold".
- [ ] Mirage patches (translucent pale rect, 32×32) sprinkle through the biome.
  Walking onto one fires a "A mirage shimmers ahead. The salt lies." toast.
- [ ] Quicksand patches (darker brown rect) apply a 50% slow + 1 dmg/s on
  contact.
- [ ] Wormbound Elder appears at one location in the biome (one-time scatter).
  Walking adjacent prompts the gesture minigame.

## 3. Auroric Veil biome (11.3, 11.5, 11.18, 11.27)

- [ ] Past 560 tiles → biome name "The Auroric Veil".
- [ ] Mob spawns rotate among **aurora_wisp**, **cold_hollow**,
  **sunken_diadem_agent**, **frostlark**, **aurora_vole**.
- [ ] Frostlark + Aurora-Vole flee from the Walker.
- [ ] **Sunken Diadem Agent** is hostile (mortal humanoid, weakness to
  explosive damage type) — distinct from Hollowling-infected mobs.
- [ ] Ambient cold hazard ticks 5 cold damage / second.
- [ ] Frostbite meter visibly rises (~8% per tick) while uncloaked. Once it caps
  at 1.0, the Walker freezes for 2 seconds (freeze status) and the meter resets.
- [ ] Auroric-Ice Chestpiece halves cold damage AND halts frostbite buildup at
  ≥0.5 cold-resist.
- [ ] Choir's Resonance in inventory adds 25% cold resist.
- [ ] Walking near 3 Frostlarks simultaneously within 64 px triggers a
  "Three Frostlarks sing in harmony." toast + an `audio_bus.frostlark_harmony`
  SFX (11.15).
- [ ] Hymnal Vault scatter spawn (one in the world). Standing in range,
  pressing 1 → 2 → 1 reveals "The Hymnal Vault opens a hidden auroric passage."
  toast (11.27).

## 4. Heat-resistance + Cold-resistance gear (11.7, 11.23)

- [ ] Craft **Ember-Iron Chestpiece** at the Clearstone Forge (recipe carries
  forward from earlier phases). Equipping it stores `fire` 0.4 in its resist
  table.
- [ ] Craft **Auroric-Ice Chestpiece**. Equipping it stores `cold` 0.5.
- [ ] Place a **Heat-Resistant Container** (heat_chest_placeable) in
  Emberforge. Verify it shows up via `chest` group + `heat_chest` group tag.
- [ ] Open the container — same UI as a regular chest.

## 5. Pyrenkin forge sub-quest (11.8, 11.14, 11.31, 11.32)

- [ ] Three **Pyrenkin Forge** scatter spawns appear inside the Emberforge ring
  (forge_index 0, 1, 2 — one per chunk diagonal mod 3).
- [ ] Standing next to a cold forge with a **fuel_pellet** in inventory and
  pressing E consumes the pellet and lights the forge (modulate goes from
  grey to white). Toast confirms "Forge N of 3 catches."
- [ ] Re-pressing E on a lit forge does nothing.
- [ ] Lighting all three forges triggers the Pyrenkin Compact arrival:
  - [ ] Brindle toast plays: "My people heard the forges from a stratum away."
  - [ ] `pyrenkin_pendant` is added to inventory.
  - [ ] `craft_pyrenkin_bellows` is unlocked in the recipe panel.
  - [ ] Brindle friendship bumps by +25.
- [ ] Collect 5 Forge-Compact tablets (test via DevConsole if no spawn yet —
  `Phase11Helpers.collect_forge_compact_tablet()`). After the fifth:
  - [ ] Compendium entries `tablet_forge_compact_1..5` are unlocked.
  - [ ] Brindle friendship bumps by another +40.
- [ ] Collect Emberforge journal tablet via
  `Phase11Helpers.collect_emberforge_journal()`. Toast plays the journal line.
  Compendium entry `tablet_ef_09` unlocks.
- [ ] Pyrenkin Bellows scene workstation: standing next to it with no fuel
  shows "The bellows is cold." If you have a pellet, pressing E consumes it
  and opens the crafting panel.

## 6. Wormbound encounter (11.9, 11.26, 11.29)

- [ ] Approach the **Wormbound Elder** in the Salt Wastes. Toast plays
  "The elder waits. (WASD: up, right, down)".
- [ ] Press move_up (default W): silent acknowledgement (no toast).
- [ ] Press move_right (default D): silent acknowledgement.
- [ ] Press move_down (default S): success toast — "The Wormbound elder
  presses a sealed scroll into your hand." Inventory gains a
  `wormbound_covenant_scroll`.
- [ ] Wrong direction (e.g. move_left) anywhere in the sequence resets the
  index back to 0 + plays "The elder shakes their head. Start again."

## 7. Skoldur boss (11.10, 11.28)

- [ ] Skoldur scene loads with the 96×96 sprite. Boss arena gates lock on
  first engagement (Phase 5.25 carry-over).
- [ ] Without `pyrenkin_pendant` equipped, on phase-4 entry: toast plays
  "Skoldur stops mid-swing. Then continues." After 2.5 s the fight resumes.
- [ ] With `pyrenkin_pendant` in inventory, phase-4 plays the recognition
  toast "Skoldur: \"You came back.\"" and sets
  `GameState.collected_relics.skoldur_recognized`.
- [ ] On death, **two** items drop: Skoldur's Hammer (standard pulse drop) and
  Pyrenkin Pendant (11.28). The pendant drop fires
  "The twin pendant comes loose from his breastplate." toast.
- [ ] Ember-Iron Ore stack of 10 + Ancient Coins also drop.

## 8. Naeren boss (11.11)

- [ ] Naeren scene loads with the 64×64 sprite.
- [ ] **Combat path** — engage without the scroll. Boss runs a 2-phase fight,
  drops Naeren's Salt-Crown on death.
- [ ] **Peace path** — engage with `wormbound_covenant_scroll` in inventory.
  Toast plays "Naeren: \"The covenant holds. Walk past.\"". Naeren
  immediately disappears, drops:
  - [ ] `naerens_salt_crown` (1)
  - [ ] `wormbound_covenant_scroll` (1 — returned in copy form)
  - [ ] `ancient_coin` ×50
- [ ] `GameState.collected_relics.naeren_peace` flag set on peace path.

## 9. Veyl-Aurora boss (11.12, 11.30)

- [ ] Veyl-Aurora scene loads. `spires_remaining` initializes to 7.
- [ ] On phase 2 (HP ≤ 60%), `break_spire` fires and the toast reads
  "Spire N falls silent."
- [ ] On phase 3 (HP ≤ 10%), `_play_perfect_chord` fires once:
  - [ ] If `GameState.collected_relics.cantor_bell_unlocked` is **false**
    (default), AudioBus plays `veyl_perfect_chord_simple`.
  - [ ] If it's **true** (player has chimed the Cantor's bell), AudioBus plays
    `veyl_perfect_chord` (the full pre-corruption variant).
  - [ ] Letterbox dips in for 0.6 s.
  - [ ] Toast plays "A perfect chord. The Veil holds its breath."
- [ ] On death, 7 Aurora-Shards drop in a ring around the body (one per spire).

## 10. Listener-Below NPC (11.13)

- [ ] Listener-Below scene loads in the Auroric Veil. (Spawned at world start
  inside Anchor for testing — or via DevConsole if not yet placed.)
- [ ] Press E to talk: dialogue lines stay terse + masked.
- [ ] (browse their wares) → MerchantPanel opens with:
  - [ ] aurora_shard at 65 coins
  - [ ] recipe_scroll at 120 coins
  - [ ] respec_scroll at 220 coins
  - [ ] xp_tonic at 90 coins
  - [ ] auroric_ice_ore at 40 coins
- [ ] Buy prices on sovereign_name_fragment_7..9 are 200 each.

## 11. Korya the Returned (11.25)

- [ ] Korya scene loads (placement up to QA — spawned via DevConsole if not on
  the world map yet).
- [ ] Press E to talk: opening line "I knew the road you walk. I left it
  behind. There is a kindness in stopping. You will not believe me yet."
- [ ] Ask "(who they were)" → never confirms. Response: "I will not say.
  The Aphelion has the right to forget us, and I will not undo that for
  vanity."
- [ ] Ask "(why they stopped)" → "Because the slivers are not unlimited..."
- [ ] No merchant inventory; no shop opens.

## 12. Hymnal Vault chord (11.27)

- [ ] Hymnal Vault scatter spawns in the Auroric Veil (one in the world).
- [ ] Standing next to it shows "[1] low / [2] high — Hymnal Vault" toast.
- [ ] Press 1 → 2 → 1 in order: success toast + `hymnal_chord_played` flag.
- [ ] Wrong chord (e.g. 1 → 1 → 1): no unlock, can keep trying.

## 13. Frostlark harmony singing (11.15) + Singing-Frost (11.34)

- [ ] Stand still in the Auroric Veil and wait for ≥3 frostlarks to wander
  within 64 px. Per-tick scan emits the harmony toast + `frostlark_harmony`
  audio sting.
- [ ] Walking away drops the count under 3, the active flag goes false; the
  toast re-fires next time 3 birds are nearby (one-time check is acceptable
  per scan).

## 14. Pyrenkin Bellows + Salt-Crown Press + Auroric Anvil (11.20–22)

- [ ] Craft Pyrenkin Bellows at the Clearstone Forge: 16 ember_iron_ore + 4
  fuel_pellet + 4 heartwood. Place it.
- [ ] Craft Salt-Crown Press at the Pyrenkin Bellows: 16 saltbound_steel_ore
  + 4 ember_iron_ore. Place it.
- [ ] Craft Auroric Anvil at the Salt-Crown Press: 16 auroric_ice_ore + 6
  aurora_shard + 8 saltbound_steel_ore. Place it.
- [ ] Craft Hymnal Vault at the Auroric Anvil: 8 auroric_ice_ore + 4
  aurora_shard. Place it.
- [ ] Craft Heat-Resistant Container at the Pyrenkin Bellows: 8 ember_iron_ore
  + 4 heartwood. Place it.

## 15. Weather system (4.56, 4.57, 4.58)

- [ ] Enter Emberforge → weather rolls between `clear` and `ash`.
- [ ] Enter Auroric Veil → weather rolls between `clear` and `snow`. Snow
  increases frostbite buildup by 30% per tick.
- [ ] Enter Salt Wastes → weather rolls between `clear` and `sandstorm`.
  Sandstorm applies a 15% slow + 1 dmg/s.
- [ ] Enter Sunless Verdancy → weather rolls between `clear` and `rain`. Rain
  is visual only at this stage.
- [ ] At every Aphelion Beat the weather re-rolls per biome.
- [ ] `Phase11Helpers.wind_vector_for_biome` returns a non-zero vector for
  every known biome (consumable by projectile drift hooks in future polish).

## 16. Save / Load round-trip (v8 → v9)

- [ ] Make progress: relight 2 forges, gather 2 forge_compact tablets, raise
  frostbite to 0.55, play a partial Hymnal chord (low, high), feed bellows
  3 pellets, get a partial Wormbound gesture.
- [ ] Save the game. Quit. Relaunch. Load.
- [ ] Verify all of the above persist:
  - [ ] `Phase11Helpers.pyrenkin_forges_relit == 2`
  - [ ] `Phase11Helpers.forge_compact_tablets_collected == 2`
  - [ ] `Phase11Helpers.frostbite_level ≈ 0.55`
  - [ ] `Phase11Helpers.hymnal_last_chord_played == [low, high]`
  - [ ] `Phase11Helpers.bellows_lit_phases_remaining == 12` (3 × 4)
  - [ ] `Phase11Helpers.wormbound_gesture_index` matches save value
  - [ ] Current weather + biome restore correctly.
- [ ] Older v8 save loads with an empty `phase11_helpers` block — no crash,
  all Phase 11 state starts fresh.

## 17. Visual / audio polish nits

- [ ] Heat-shimmer alpha never exceeds the configured 0.18.
- [ ] Frostbite meter pulses the screen at each 25% milestone (0.25 / 0.5 / 0.75 / 1.0).
- [ ] All Phase 11 sprites display crisp (Nearest filtering, no anti-alias).
- [ ] All Phase 11 boss music ids fall through the AudioBus placeholder pool
  cleanly (no MissingResource errors).

---

## Known gaps (not blocking Phase 11 closure)

- Listener-Below + Korya don't have dedicated multi-frame SpriteFrames yet
  (current sprite is a single 24×24 portrait). Phase 15 polish target.
- Forge-Cricket / Charred Goat / Frostlark use the same fauna sprite per biome
  for now; Phase 15 polish will give them distinct walk-cycles.
- Phase 11 boss audio (skoldur_voice, naeren_voice, veyl_perfect_chord, etc.)
  routes through the AudioBus placeholder tone generator — Phase 15 polish
  will swap in real samples.
- World_gen scatter for Wormbound Elder + Hymnal Vault is gated on the chunk
  random roll; QA may need to seed-explore to find them in a fresh world.
  DevConsole `Phase11Helpers` hooks are exposed for direct test triggers.
