# Phase 12 — Manual Test Checklist

> Companion to `tests/unit/test_phase12_systems.gd` (42 GUT cases). This file
> covers play-through, environmental, and visual checks that can't be automated.

**Save format:** v10 (bumped from v9). Older saves load with an empty
`phase12_helpers` block — Mote Tide cooldown, Vacancy appearance, Elision
fragments, manifesto reads, Loom's Twin discovery, ending selection, all
final-act flags start fresh. NG+ cycle counter is now persisted explicitly.

**Toggles to know:**
- Manifesto reader UI (`scenes/ui/manifesto_reader_panel.tscn`) opens on
  proximity to a Diadem-Manifesto plate. Esc closes.
- Endings UI (`scenes/ui/endings_panel.tscn`) opens 1.5 s after the Diadem-
  Bearer is defeated. Three buttons: A Restore, B Break, C Become. Become is
  disabled until all six gating conditions are met.
- Credits + run-stats UI (`scenes/ui/credits_panel.tscn`) opens automatically
  when the player presses **N** in the EndingsPanel.
- Diadem Reliquary station is `station_id = diadem_reliquary`. Recipes filter
  to it; convert-recipes consume one Aphelion Shard per batch.
- The Aphelion bullet-hell fight (12.10) is gated behind the Break ending —
  the chamber door only opens after that ending commit.

---

## 1. Final Spiral biome (12.1, 12.16, 12.22)

- [ ] Walk past 640 tiles from the Anchor → biome name "The Final Spiral".
- [ ] Mob spawns rotate among **diadem_reader**, **diadem_censer**,
  **diadem_warden**, **pure_hollowling_mote**.
- [ ] Diadem-Censer ranged-attacks at ~140 px distance (mob_class CASTER).
- [ ] Diadem-Warden absorbs more knockback than other mobs (knockback_resistance
  0.7); falls slower in stagger.
- [ ] Pure Hollowling Mote moves visibly faster (78 px/s) than other mobs and
  takes 50% bonus from fire and lightning.
- [ ] Walking further into the Final Spiral (~1280 tiles+) noticeably increases
  the per-chunk mob budget (density curve caps at 3× at extreme range).
- [ ] Every 2 Aphelion Beats a wave of 3-4 Diadem agents spawns around the
  Walker (12.22). Confirm via debug overlay or by counting mobs per beat.

## 2. Mote Tide event (12.3)

- [ ] Stand in the Final Spiral for 6 Aphelion Beats → toast "Mote Tide rising
  — the light churns." + audio sting.
- [ ] 8 Pure Hollowling Motes spawn in a ring around the Walker at ~120 px.
- [ ] After 24 s, the tide ends silently (`mote_tide_ended`); remaining motes
  persist until killed.
- [ ] Cooldown resets so the next tide is 6 more beats away.
- [ ] Leaving the Final Spiral cancels the tide-spawn check entirely (no
  spawns in other biomes).

## 3. Vacancy follower (12.4, 12.29)

- [ ] Reaching the final corridor (last manifesto plate area) causes one
  Vacancy to spawn nearby.
- [ ] Vacancy follows the Walker at ~64 px standoff distance.
- [ ] Walking through the Vacancy causes no contact damage.
- [ ] Striking the Vacancy: the attack does not kill it (it has 9999 HP and
  ~100% resistance across the board).
- [ ] On Diadem-Bearer engagement, the Vacancy fades over 0.6 s and queue_frees.
- [ ] `Phase12Helpers.vacancy_encounter_completed` is true afterwards (DevConsole
  check).

## 4. Elision-Script puzzle (12.5, 12.30)

- [ ] Four Elision tablets scatter through the Final Spiral. Collecting each
  removes it from the world and adds an `elision_script_fragment` to inventory.
- [ ] After the 4th pickup: toast reads "The name forms: VAEL-IOR-RI-ON".
- [ ] `elided_name_vael_iorrion` unlocks in the Compendium (Tablets tab).
- [ ] `Phase12Helpers.elided_name_revealed` is true; `collected_relics`
  ["elided_name"] is true.
- [ ] Picking up a 5th fragment (via DevConsole) does NOT increment the counter
  beyond 4.

## 5. Manifesto corridor + reader (12.6, 12.14, 12.23, 12.36)

- [ ] Walking the descent corridor encounters 8 wall-mounted manifesto plates.
- [ ] Stepping next to any plate opens the ManifestoReaderPanel showing the
  inscription.
- [ ] Prev / Next buttons navigate among previously-read plates (read-only).
- [ ] Progress label updates "Read: N / 8".
- [ ] Manifesto VIII (last plate) shows the unsigned text on first read.
- [ ] After reading the **bearer_child_tablet** (12.32), re-opening manifesto
  VIII appends "Forgive me. — Joren-of-the-Lattice" inline (12.36).
- [ ] Esc closes the panel and returns control to the Walker.

## 6. Resonance Loom's Twin (12.7)

- [ ] One LoomTwin scene placed mid-Final-Spiral. Sprite renders darker and
  more desaturated than the canonical Resonance Loom.
- [ ] Walking adjacent fires "Pre-Inversion construction. The Loom is the
  elided figure's. So are you." toast (one-shot).
- [ ] Letterbox briefly engages then releases.
- [ ] `Phase12Helpers.loom_twin_discovered` and `collected_relics["loom_twin"]`
  both flip true.
- [ ] Compendium gains entry `loom_twin_discovery`.

## 7. Diadem-Bearer boss (12.8, 12.26, 12.36, 12.37)

- [ ] Engaging the Bearer triggers boss intro + arena lock-in + boss music swap
  to `boss_diadem_bearer_theme`.
- [ ] **Phase 1** (100% → 66%): sword arcs + Aphelion-shard projectile volley.
  AttackCycler steps through `db_sword_arc`, `db_shard_volley`, `db_dash_cut`.
- [ ] **Phase 2** (66% → 33%): on entry, Bearer summons First & Second Reader
  adds. Toast "First Reader, Second Reader — to me." The 3v1 is harder than
  Phase 1.
- [ ] **Phase 3** (33% → 5%): adds clear; Bearer fights solo, faster (movement
  speed scales with current_phase).
- [ ] **Phase 4** (5% → 0%): self-shatter cinematic plays:
  - [ ] Bearer kneels (velocity = 0; sprite modulate dims).
  - [ ] Letterbox engages.
  - [ ] Toast plays 3 lines spaced 3 s apart:
    - "You are a tool. I was a tool. We are the same."
    - "The light is a cage. The cage is the kindness."
    - "Choose better than I did."
  - [ ] After the third line + 2.4 s pause, the Bearer self-shatters — screen
    pulse + camera shake + letterbox release.
  - [ ] The Walker never lands the killing blow (hurtbox disabled during kneel).
- [ ] Drops world-spawn: **Shattered Diadem**, **Bearer's pre-Diadem name**,
  Diadem-gold ingots × 5, **Bearer's Sword**, Aphelion shards × 3, ancient
  coins.
- [ ] If the player has read the Bearer child tablet (12.32) AND has Mira
  friendship ≥ 80, the Mira-Bearer sibling scene plays via Phase12Helpers.
  try_play_mira_sibling_scene (12.37).
- [ ] EndingsPanel auto-opens 1.5 s after the death event.

## 8. Aphelion bullet-hell (12.10, 12.27)

- [ ] Pre-requisite: commit the **Break** ending in the EndingsPanel.
- [ ] A new door opens in the chamber's far wall. Walk through to enter the
  Aphelion encounter.
- [ ] Boss renders as a featureless gold sphere (the `aphelion.png` 64×64
  sprite, no body).
- [ ] AttackCycler walks `aphelion_phase1` then `aphelion_phase2` patterns:
  light spirals, radiant bursts, cone sweeps.
- [ ] `aphelion_resistance` decays at 0.012 per 0.5 s tick while engaged;
  health bar fills down as the resistance drops.
- [ ] After ~40 s of survival, resistance hits zero → Sphere "cracks":
  letterbox engages, "I am sorry. I tried." toast appears (12.27).
- [ ] 5 Aphelion Shards drop as world entities + Sovereign Name Fragment XII.
- [ ] Phase12Helpers.aphelion_apology_revealed_flag = true;
  `collected_relics["aphelion_apology"]` = true.

## 9. Endings A / B / C (12.9-12.11, 12.17, 12.18)

- [ ] EndingsPanel opens after Diadem-Bearer defeat with:
  - [ ] Title "The Aphelion's chamber. Three paths."
  - [ ] Subtitle in italics.
  - [ ] Three buttons: A Restore / B Break / C Become.
  - [ ] **Ending C validator panel** lists six conditions:
    - 9 Sovereign threads gathered (N/9)
    - Wormbound peace path completed
    - Vol'thaar's Promise honoured
    - Sythrenn mercy-kill performed
    - The elided name pieced together
    - The Resonance Loom's Twin discovered
  - [ ] Each met condition shows [✓] in green; unmet shows [ ] in red.
  - [ ] Become button is disabled when any condition is unmet.
  - [ ] History line shows previously taken endings (e.g. "Carved in the
    chamber wall: [Restore]") — empty on first run.
  - [ ] Sovereign Naming preview shows "Sovereign threads gathered: N / 9.
    The Cantor's Compass remains unstrung." (or "...sings" when granted).
- [ ] **A Restore**: clicking shows the full Restore epilogue text + "New
  Game+ unlocked. Press N to begin a new cycle." `selected_ending` =
  `ending_restore`. `unlocked_compendium[ending_restore] = true`.
- [ ] **B Break**: shows Break epilogue + the translated Aphelion apology
  inline + "A door opens at the chamber's far wall. The Aphelion waits."
  toast. `unlock_aphelion_door` recipe flag flips.
- [ ] **C Become**: only clickable when all six unlocks are met; shows Become
  epilogue text + NG+ prompt.
- [ ] After any choice, all three buttons are disabled (commit is one-shot).
- [ ] Pressing **N** opens the CreditsPanel.

## 10. Credits + run-stats (12.12, 12.13)

- [ ] Credits panel header shows the ending title ("Ending A — Restore", etc).
- [ ] Stats section lists:
  - Bosses defeated (count of `defeated_bosses`).
  - Compendium entries unlocked.
  - Titles earned (subset of compendium entries beginning with `title_`).
  - Sovereign threads: N / 9.
  - Slivers spent: APHELION_STARTING_SLIVERS − slivers_remaining.
  - Endings taken (this slot): N / 3.
  - NG+ cycle: N.
- [ ] Credits text lists the team + tech (Godot 4.6, Gemini MCP, Claude).
- [ ] Pressing **Continue** unpauses the tree and the EndingsPanel finishes
  the NG+ scene transition. `GameState.start_new_game_plus` is called,
  bumping `ng_plus_cycles` by 1 and clearing relics + defeated_bosses but
  preserving sovereign_threads + compendium.

## 11. Diadem Reliquary station + recipes (12.19, 12.20, 12.21)

- [ ] Craft **Diadem Reliquary** at the Auroric Anvil (8 Diadem-gold ore + 3
  Aphelion shards + 12 auroric_ice_ore + 12 ember_iron_ore). The output is
  one `diadem_reliquary_placeable` item.
- [ ] Placing the Reliquary spawns a 32×32 cathedral-furnace sprite at the
  cursor location. Approaching opens its workstation crafting filter.
- [ ] Recipes available at the Reliquary station:
  - smelt_diadem_gold_ingot (3 ore + 1 shard → 1 ingot)
  - craft_diadem_gold_plate (6 ingot + 2 shard + 4 auroric_ice_ore → 1 chest)
  - convert_auroric_to_diadem (4 auroric_ice_ore + 1 shard → 1 diadem_gold_ore)
  - convert_saltbound_to_diadem (4 saltbound_steel_ore + 1 shard → 1
    diadem_gold_ore)
- [ ] Each conversion increments `Phase12Helpers.reliquary_conversions_performed`.
- [ ] DevConsole `Phase12Helpers.reliquary_convert(&"auroric_ice_ore",
  &"diadem_gold_ore", 5)` produces 5 ore when inputs are sufficient and
  returns the actual count produced (clamped by available inputs).

## 12. Listeners-Below mask reveal (12.28)

- [ ] One ListenerBelowFinal NPC scatter in the Final Spiral. Approaching
  triggers the encounter (one-shot per save).
- [ ] Approach phase: NPC steps toward the Walker (~1 s tween).
- [ ] Reveal phase (after 1.6 s): NPC modulates pale-blue + audio sting; toast
  "The Listener removes her mask. Her face is yours."
- [ ] Linger (4.5 s) then fade-out (1 s) → queue_free.
- [ ] `listener_mask_revealed_flag = true` (compendium entry +
  collected_relics).
- [ ] Re-entering the area after the encounter does not re-trigger it.

## 13. Hall of First Names (12.24)

- [ ] One HallOfFirstNames tablet in the Final Spiral.
- [ ] Reading it before the elided name is revealed shows "The tablet's
  surface ripples. You cannot read it yet." toast.
- [ ] Reading after the elided name is revealed shows "\"A lamp before the
  lamp.\" Before the Aphelion, there was something else." toast (one-shot).
- [ ] `Phase12Helpers.lamp_before_lamp_revealed = true`;
  `collected_relics["lamp_before_lamp"]` = true.

## 14. Bearer child memory tablet (12.32)

- [ ] One BearerChildTablet placed in the Final Spiral approach corridor.
- [ ] Pressing E reads it: toast "Tablet: \"My brother's name was
  Joren-of-the-Lattice...\""
- [ ] `Phase12Helpers.bearer_child_tablet_read = true`. Compendium gains
  `bearer_child_memory`.
- [ ] Subsequent reads of manifesto VIII now show the signed line (see Section 5).

## 15. Final-act NPC commentary (12.31)

- [ ] Reduce Aphelion slivers below 1000 (via DevConsole or by dying many
  times). First crossing of the threshold triggers final-act commentary.
- [ ] Each arrived NPC (Aelstren / Brindle / Mira / Cantor / Hask) gets one
  unique toast line spaced ~2.5 s apart.
- [ ] Sample line for Mira: "I dreamed about my brother again. He was wearing
  gold. He was smiling. I don't want to go back to sleep."
- [ ] Re-crossing the threshold (after restoring slivers and dropping back
  down) does NOT replay the commentary (`_final_act_fired` is one-shot).

## 16. Compendium completion reward (12.33)

- [ ] Unlock enough compendium entries to push the total past 40 (Bestiary
  + Tablets + Relics + Titles combined).
- [ ] On the 40th-or-later unlock, `Phase12Helpers.try_grant_compendium_reward`
  fires.
- [ ] `cantors_compass` item is added to inventory; `collected_relics
  ["cantor_compass"]` is true.
- [ ] Subsequent unlocks do NOT re-grant the reward (idempotent flag).

## 17. NG+ persistence (12.13, 12.15, 12.34)

- [ ] Take Ending A. Save. Load. Take Ending B (via NG+). Save. Load.
- [ ] Both `ending_restore` and `ending_break` show in EndingsPanel history
  "Carved in the chamber wall: [Restore] [Break]".
- [ ] Sovereign threads do not reset across NG+; defeated_bosses + relics do.
- [ ] `ng_plus_cycles` increments by one per NG+.

## 18. Walker silent epilogue (12.38)

- [ ] After choosing any ending, the credits panel shows a one-line epilogue
  flavor matched to the ending.
- [ ] `Phase12Helpers.walker_epilogue_emote_played` flips true after the
  per-ending text renders.

## 19. Save round-trip (12.34 + save v9 → v10)

- [ ] Take Ending A. Verify SaveSystem.SAVE_VERSION = 10.
- [ ] Trigger a Mote Tide. Save mid-tide.
- [ ] Load → `mote_tide_active` field is restored false (tide cleanup happens
  on save). `endings_taken_history` retains `ending_restore`.
- [ ] Pre-existing v9 save loads with a fresh `phase12_helpers` block; no
  errors in the console.

## 20. Footstep echo shader (12.25)

- [ ] Entering the Final Spiral sets `Phase12Helpers.footstep_echo_active`
  true; leaving sets it false.
- [ ] Audio listener picks up the flag and applies the delayed-echo profile
  (the actual shader is a placeholder hook for Phase 15 polish).

---

**Expected total: 282 GUT tests pass (was 240 before Phase 12).** If any
section fails, capture the failing step and the corresponding GUT test name.
Phase11Helpers and Phase10Helpers remain unchanged (no regressions expected).
