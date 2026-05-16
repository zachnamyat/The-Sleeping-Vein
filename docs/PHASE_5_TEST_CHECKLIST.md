# Phase 5 — Manual Test Checklist

Phase 5 goal (per ROADMAP §5): Glaur-em fightable in the Root Hollows; Aelstren the Cartographer arrives at the Anchor on world start; supporting boss-encounter, NPC, compendium, and onboarding backlog (5.13–5.40 + Phase 5 migrations 2.34 / 3.40 / 3.70 / 3.72).

Phase 5 exit criterion (verbatim):
> Defeat Glaur-em. Aelstren appears at the Anchor with no prompt. Stone-Father's Pulse inserts into the Loom. Glasswright Reaches descent corridor unlocks.

Walk this top-to-bottom and report anything that fails. Section letters group by verification gate; numbered subsections cite the ticket id in **bold**.

**Pre-reqs:**
- Phase 0/1/2/3/4 checklists passed.
- Godot 4.6.x on PATH (`godot --version` returns 4.6.*).
- The Phase 4 sprite set is imported (Phase 5 reuses them; the Glaur-em + Stoneslough + Aelstren + Brindle sprites are pre-existing).
- The three new autoloads — `TutorialDirector`, `BarkSystem`, `TitleSystem` — appear in `project.godot` `[autoload]` section.

---

## A. Headless smoke (must pass before anything else)

```sh
godot --headless --path . --import
godot --headless --path . "res://scenes/world/main.tscn" --quit-after 5
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected:
- `--import` finishes without `SCRIPT ERROR` or `Parse Error` lines (RID-leak teardown noise and the pre-existing `gut_loader.gd:35` Nil-bool warning are OK).
- The 5-second boot of `main.tscn` returns to the prompt with no GDScript backtrace.
- GUT prints **74/74 passing** (Phase 4 left 66; Phase 5 added `test_phase5_systems` with 8 cases — first-kill compendium, title system × 2, bark fallback, recipe-scroll × 2, arena gate, boss drops).

---

## B. Phase 5 critical-path (5.1–5.12)

### 5.1 — Boss arena prefab + rune circle
1. Walk roughly 40 tiles east of the Anchor (Glaur-em's spawn at distance_tiles=40, angle=90°).
2. As you approach within ~64 tiles, the BossArena rune circle (procedural translucent gold ring + 8 cardinal glyph dots + 4 inner glyph dots) draws on the floor under the boss.
3. **Expected:** the ring radius scales with the boss sprite size (≥ 6 tiles).

### 5.2 — Glaur-em 3-phase fight
1. Approach the Glaur-em arena. Detection radius (`mob_def.detection_radius`) triggers `boss_engaged`.
2. Phase 0: Glaur-em chases. Contact damage = `mob_def.contact_damage`.
3. Drop HP to 50% → `phase_advanced(1)` fires. Contact damage bumps; speed multiplier rises by 20%.
4. Drop HP to 20% → `phase_advanced(2)` fires. Damage bumps again; speed multiplier hits 1.4×.
5. **Expected:** the phase advances at exactly the HP fractions in `phase_thresholds = [1.0, 0.5, 0.2]`.

### 5.3 — Boss HP bar UI
1. On `boss_engaged`, the top-of-screen HP bar appears and tracks `mob_def.display_name`.
2. The bar's `value` follows `HealthComponent.current_health`.
3. On phase advance, the "PHASE N" label updates to `PHASE 2`, then `PHASE 3`.
4. **Expected:** HP bar disappears when Glaur-em dies (verifies the BossHpBar `_on_died` listener).

### 5.4 — Stoneslough boss-minion add
1. Engage Glaur-em. Wait for the phase-1 transition (HP ≤ 50%).
2. Stoneslough minions begin spawning around Glaur-em every `minion_spawn_period = 5.0s`, up to `minion_max_alive = 3`.
3. Minions chase the player independently.
4. **Expected:** minions are loaded from `res://resources/mobs/stoneslough.tres` and use the Stone-Hopper scene as their visual base.

### 5.5 — Glaur-em drops: Pulse + Shell + Fragment + Trinket
1. Kill Glaur-em.
2. Four drops spawn around the corpse with slight scatter:
   - 1× **Stone-Father's Pulse** (`stone_fathers_pulse`)
   - 1× **Sovereign Name-Fragment** (`sovereign_name_fragment_1`)
   - 4× **Engorged Stone-Shell** (`engorged_stone_shell`) — new material, can stack to 16
   - 1× **Bound-Stone Trinket** (`glaurem_trinket`) — necklace-slot equip, +2 armor
3. **Expected:** all four IDs resolve in ItemRegistry (no "missing icon" magenta placeholders for the four IDs themselves; icons may be `null` until art is generated).

### 5.6 — Loom power-up flow → unlock descent corridor
1. Pick up the `stone_fathers_pulse`. Return to the Loom.
2. Press **E** to open `LoomPanel`. The relic list shows `Stone-Father's Pulse  (in pouch)` with an `Insert` button.
3. Click `Insert`. Toast: `The Loom drinks the Stone-Father's Pulse. Stratum 2 unlocks.`
4. `GameState.collected_relics[&"stone_fathers_pulse"] = true`.
5. **Expected:** the Insert button disappears; the row now reads `[INSERTED]` in green.

### 5.7 — NPC base class + dialogue UI
1. Approach an NPC. The `[E] Talk` Label floats above their head (the `InteractPrompt` Label child).
2. Press **E**. `DialoguePanel` opens, shows the NPC's name + entry-node text.
3. Click a response. Either jumps to the next node or closes the dialogue.
4. Walk out of the InteractArea radius. The dialogue closes automatically.

### 5.8 — Aelstren the Cartographer
1. On **New Game**, Aelstren spawns at `(-32, 32)` relative to the Anchor.
2. Talk to her. The dialogue (`resources/dialogues/aelstren_arrival.tres`) plays through two nodes — the silent map-fragment hand-off + the corruption-tendril gesture.
3. Walker is mute — responses are gestures (`(touch the scroll)`, `(silently nod)`).
4. **Expected:** dialogue tree reads correctly with no `null` text.

### 5.9 — NPC arrival trigger (boss kill → spawn)
1. After Glaur-em dies, `EventBus.boss_defeated.emit(&"boss_glaurem")` fires.
2. `NpcDirector._on_boss_defeated` calls `_spawn_npc_if_needed(&"npc_brindle")` on the next frame.
3. Brindle the smith spawns at `(32, 48)` near the Anchor.
4. Alternative trigger: mining first `shaleseed` (any biome) also triggers Brindle's arrival — the faster of the two paths wins.

### 5.10 — NPC housing stub
1. Build a 5×5 room of wall + floor tiles next to a placed bed (Phase 9 will use this; today the check is just exposed via API).
2. From the remote inspector or DevConsole: `Housing.validate_room(bed.global_position, ...)` returns `{ "valid": true, "floors": ≥16, "walls": ≥4 }`.
3. **Expected:** rooms with <16 floor tiles return `too_few_floor_tiles`; <4 wall tiles return `no_walls_enclosing`.

### 5.11 — Tablet placement + compendium entry
1. Walk to the +X axis at the mid-radius of any biome ring. A pre-placed `lore_tablet` waits there (one per biome per session, Phase 4.24).
2. Approach: toast `[E] Read tablet`.
3. Press **E**: toast `Lore unlocked: tablet_<biome>_ring`. The entry is added to `GameState.unlocked_compendium`.
4. Press **E** again: toast `The tablet hums — you have already heard its name.` (Idempotent.)

### 5.12 — Compendium UI shell
1. Press **J** anywhere in the world. The Compendium panel opens with a page-flip SFX.
2. Four tabs are visible (left → right): **Bestiary**, **Tablets**, **Relics**, **Titles**.
3. Click each tab. The list rebuilds with entries filtered by the prefix (`bestiary_*`, `tablet_*`, `item_*`, `title_*`).
4. Press **J** again or **Esc** to close.

---

## C. Phase 5 boss-encounter polish (5.17, 5.18, 5.25, 5.26, 5.28, 5.29, 5.30, 5.38, 5.39)

### 5.17 — Boss respawn at altar
1. After defeating Glaur-em, find a `boss_altar` (deep-stratum procedural room).
2. Approach: toast `[E] Re-summon boss_glaurem`.
3. Press **E** with ≥1 `aphelion_fragment`. Fragment consumed. Glaur-em respawns at the altar position.
4. **Expected:** `BossDirector.respawn_boss(&"boss_glaurem", altar.global_position)` succeeds; the `_spawned[boss_id]` flag clears so further altar uses keep working.

### 5.18 — Boss music swap
1. Engage Glaur-em. The ambient music halts; `AudioBus.play_music(&"boss_glaurem_theme")` kicks in.
2. On death, `AudioBus.stop_music()` is called; biome ambient resumes via `EventBus.biome_changed` re-emit (next chunk walk).
3. **Expected:** placeholder procedural tone changes pitch/timbre at the moment of `boss_engaged`. Real audio replaces in Phase 15.

### 5.25 — Boss-arena gate-lock
1. Engage Glaur-em. The BossArena emits `gate_locked` and draws an extra pulsing gold ring at radius × 1.04.
2. Toast: `The runes seal. Walk through, or fall here.` SFX `boss_gate_seal`.
3. Walk outward past the seal. The arena's `_physics_process` repels you inward by ~4 px per frame while you straddle the ring edge.
4. Kill Glaur-em. `gate_unlocked` fires. SFX `boss_gate_open`. The pulsing ring disappears; the player can leave.

### 5.26 — Boss intro voice / sting
1. The frame `_engaged` flips to `true`, `AudioBus.play_sfx(&"boss_intro_sting")` plays once.
2. **Expected:** this fires before the boss starts chasing — the timing is `_on_first_engaged()` inside the same physics frame the detection radius triggers.

### 5.28 — Boss attack telegraph
1. While engaged, a red ring (the `BossTelegraph` child Node2D) flashes every `telegraph_period_seconds = 4.5s`.
2. Each flash: alpha 0 → 1 in 0.05s, then fade to 0 over 0.7s. Procedural draw (no asset).
3. **Expected:** the ring radius matches `telegraph_radius_px = 36`. (Damage is still applied via the ContactHitbox, not the telegraph itself — the visual is a warning.)

### 5.29 — Boss enrage timer
1. Engage Glaur-em and run away for 240 seconds (4 minutes).
2. Toast: `ENRAGED — Glaur-em the Stone-Father draws on the Beat itself.`
3. Sprite tints between bright red and soft red on a loop (`Color(1.6, 0.5, 0.5)` ↔ `Color(1.0, 0.7, 0.7)`).
4. Speed multiplier rises to `enrage_speed_multiplier = 1.6×`, damage to `enrage_damage_multiplier = 2.0×`.
5. **Expected:** `EventBus.screen_pulse_requested.emit(0.4, 0.6)` fires once on enrage; AudioBus plays `boss_enrage`.

### 5.30 — Boss-defeat fanfare
1. Kill Glaur-em.
2. `AudioBus.play_sfx(&"boss_defeat_fanfare")` — single sting.
3. `EventBus.camera_shake_requested.emit(5.0, 1.2)` — 1.2s shake.
4. `EventBus.screen_pulse_requested.emit(0.6, 0.9)` — gold pulse.
5. `EventBus.hit_pause_requested.emit(0.2)` — engine-time freeze for 0.2s.

### 5.38 — Pre-boss tactical-prep panel
1. Walk toward Glaur-em. When within `PREP_PANEL_RADIUS_TILES = 18` (≈288 px) of the boss spawn, but **before** the detection radius engages the fight, the `BossPrepPanel` pops up.
2. Panel shows: `Glaur-em the Stone-Father`, `Weapon: Stone-cleaving melee weapon (Shaleseed Sword or better)`, `Armor: Stoneproof helmet recommended`, `Tip: Vigil shrine offering before approach`.
3. Press **Esc** or click `Understood (Esc)`. Panel closes; doesn't reopen this session for this boss.
4. **Expected:** if you've already defeated this boss, the panel doesn't reopen.

### 5.39 — Boss intro voice-over text crawl
1. On `boss_engaged`, the `BossIntroCrawl` CanvasLayer fades in over 0.6s at the bottom of the screen.
2. For Glaur-em: `He grew and grew, and the stone tried to hold him.`
3. Holds for 4s, then fades out over 1s.
4. **Expected:** distinct crawl text for each boss id (see `CRAWL_LINES` constant in `scripts/ui/boss_intro_crawl.gd`).

---

## D. Phase 5 NPC / world flavor (5.20, 5.32, 5.33, 5.34, 5.35, 5.36, 5.37)

### 5.20 — NPC arrival cinematic-toast
1. Trigger an NPC arrival (Aelstren on New Game, or Brindle on Glaur-em kill / first shaleseed).
2. `EventBus.letterbox_requested.emit(true, 0.25)` — soft dip.
3. `EventBus.screen_pulse_requested.emit(0.18, 0.45)` — gentle pulse.
4. `AudioBus.play_sfx(&"npc_arrival")` — sting.
5. Toast: `<Name> has arrived.` (3.5s).
6. After 1.2s, `EventBus.letterbox_requested.emit(false, 0.4)` — return to gameplay.

### 5.32 — Aelstren paper-bird memorial
1. On Glaur-em's defeat, a paper-bird Node2D spawns at the Aelstren NPC position and flutters toward the boss-arena center over 4 seconds along a slight arc.
2. The bird's body flaps with `sin(_flap_t * 9.0) * 4.0` wing offset.
3. On arrival at the target, it tweens `modulate:a` to 0 over 0.5s, then frees itself.
4. **Expected:** if Aelstren hasn't arrived yet (impossible in normal play but a Brindle-first-shaleseed race condition would do it), the bird falls back to spawning at the Loom.

### 5.33 — Glaur-em floor-carving on defeat
1. After Glaur-em's death, a `GlauremCarving` Node2D pins to the death position with `z_index = -2`.
2. Carving renders 12 small gold dots in a 14-px ring plus a central diamond glyph.
3. Walk onto the carving: toast `—— thank you for the quiet ——` for 3.5s.
4. **Expected:** the carving persists for the session (queue_free is **not** called); reload from save would un-spawn it (acceptable MVP behaviour — Phase 15 will persist via SaveSystem).

### 5.34 — NPC reaction barks
1. Have Aelstren + Brindle both arrived at the Anchor.
2. Kill Glaur-em.
3. ~1.5s after the kill: toast `Aelstren bows her head. "Quiet at last."`
4. ~4.5s after the kill: toast `Brindle grins. "The stone yields. Now we forge."`
5. **Expected:** if only one NPC has arrived, only that NPC's bark fires. Unknown bosses fall through to the `_generic` line per NPC.

### 5.35 — Pre-fight murals
1. Craft a `mural_placeable` at the Clearstone Forge (1 loam_wall + 1 glow_tube).
2. Place it via left-click in the corridor approaching the Glaur-em arena.
3. Walk past it: toast `The Stone-Father slept. Then he could not stop growing.` (4s).
4. **Expected:** the Mural is purely flavor; no buff applied.

### 5.36 — First-NPC warm-up sequence
1. New Game. Aelstren arrives.
2. In addition to the standard cinematic toast (5.20), a **paper-bird** flutters from the Loom (`scenes/structures/resonance_loom.tscn`, group `loom`) toward Aelstren's spawn point.
3. **Expected:** subsequent NPC arrivals (Brindle, etc.) do **not** trigger an additional paper-bird. The check is `GameState.arrived_npcs.size() == 1` at the moment of spawn — first arrival only.

### 5.37 — NPC interaction prompt
1. Walk into Aelstren's or Brindle's `InteractArea` radius.
2. A `[E] Talk` Label floats above the NPC at offset `Vector2(0, -28)` to `Vector2(16, -18)` from origin.
3. Walk out of range: the label hides.
4. **Expected:** the prompt visibility cleanly toggles on `body_entered` / `body_exited`. Reads with the `Aphelion gold` accent color (`Color(0.95, 0.84, 0.5)`).

---

## E. Phase 5 utility structures (5.13, 5.14, 5.21, 5.22, 5.23, 5.31)

### 5.13 — Sleep-in-bed
1. Craft a `bed_placeable` at the Loam Bench (8 loam + 4 wood).
2. Place it on an open floor tile.
3. Walk onto it: toast `[E] Rest`. Press **E**.
4. **Expected:** 
   - Respawn point binds to the bed position (`GameState.set_respawn_point(global_position)`).
   - The player's `try_sleep_in_bed` fires.
   - If a hostile is within 200 px: toast `Too dangerous to rest here.` — no sleep.
   - Otherwise: letterbox 1.5s, then `DayNightCycle.skip_time(480)` advances 8 minutes of world clock; HP restores 25%.
5. Try **E** again within 8 beats: toast `You're not tired enough yet.`

### 5.14 — Worship shrine (phase-dependent blessing)
1. Craft a `shrine_placeable` at the Clearstone Forge (4 shaleseed_ingot + 1 aphelion_fragment).
2. Place it. Walk over: toast `[E] Offer to the shrine`.
3. Press **E**:
   - Aphelion phase 0 (early morning) → toast `Shrine grants: Vigil`. `Buffs.apply(&"buff_vigil", 90.0)`.
   - Phase 1 (midday) → `Hearth`.
   - Phase 2 (evening) → `Resolve`.
   - Phase 3 (deep night) → `Mote`.
4. Press **E** again within 4 beats: toast `The shrine waits. Return after a few Beats.`

### 5.21 — Spike trap
1. Craft a `spike_trap_placeable` at the Loam Bench (4 shaleseed + 2 wood).
2. Place it.
3. After a 0.2s arm delay, walk onto it. You take 8 damage of `physical` type. Camera shakes briefly (0.6 intensity, 0.12s).
4. Wait 0.6s cooldown, walk on again: hits again.
5. **Expected:** also hits mobs that wander over. Owner team is `&"world"` — the trap will hit *any* hurtbox with a non-`&"world"` team.

### 5.22 — Healing-tile shrine
1. Craft a `healing_shrine_placeable` at the Clearstone Forge (3 glow_tube + 2 shaleseed_ingot).
2. Place it. Stand on it. With `current_health < max_health`, the shrine heals 3 HP every 0.6s, consuming 1 charge per tick. Starts with 30 charges.
3. When `charges_remaining` hits 0, the sprite dims to `Color(0.5, 0.5, 0.55, 0.6)` and toast `The shrine's thread has unraveled.` appears.
4. Stand on the dim shrine: toast `[E] Restock shrine (1 glow_tube)`.
5. Press **E** with ≥1 `glow_tube`: consumes 1 glow_tube, restores to 30 charges; modulate back to white; toast `Thread restored. Shrine ready.`

### 5.23 — Hidden door
1. Craft a `hidden_door_placeable` at the Sawmill (1 loam_wall + 3 wood).
2. Place it. Look at the wall sprite (a wall-tinted Sprite2D) — the StaticBody2D under it blocks movement.
3. Walk within 24 px of it (the RevealArea radius).
4. **Expected:** over 0.5s, the wall sprite fades to 0 alpha while a passage sprite fades to 0.85. The StaticBody2D's `collision_layer` clears to 0 — now passable. Toast `The wall sighs and opens.` AudioBus plays `hidden_door_reveal`.
5. The reveal is one-way for the session; walking out of range doesn't re-close it.

### 5.31 — Trial chamber
1. Place a `trial_chamber.tscn` instance (no item form yet — instance via remote inspector or future Phase 5 craft scroll).
2. Walk onto its 14-px radius. The trial starts:
   - Toast `Trial begins. Three waves.`
   - Wave 1: 3 Stone-Hoppers spawn in a circle 36 px out.
   - Wait `wave_delay_seconds = 1.5s` after the last is killed.
   - Wave 2: 4 mobs. Wave 3: 5 mobs.
3. After wave 3 clears:
   - Toast `Trial passed. The chamber yields its prize.`
   - A `TreasureChest` instance spawns at the trial center with `unique_id = "trial_reward_<instance_id>"`.
4. **Expected:** the trial scene tracks per-mob death via `_alive` array filter; chest spawn fires once.

---

## F. Onboarding + opening (5.15, 5.16, 5.19, 5.40)

### 5.15 — Tutorial hint flow
1. **Delete** the local Settings file (`user://settings.cfg` or similar) to simulate a fresh user.
2. New Game. After 0.1s, toast: `Tip: WASD to walk. The Loom behind you is your anchor.` (the `first_step` hint).
3. Mine your first wall (mining XP tick). Eventually the `first_mine` hint fires once `EventBus.first_tile_mined` triggers (no-op today; the trigger string lives in the table but no in-engine emit exists yet — manual emit via console works).
4. Kill your first Stone-Hopper: toast `Tip: Drops glow. Walk over them. Each kill teaches a skill.`
5. Hints are one-shot per save; `Settings.set_value("tutorial_seen", {...})` persists.

### 5.16 — Compendium first-encounter trigger
1. Kill a Stone-Hopper for the **first** time in a save.
2. Toast: `Compendium: Stone Hopper recorded.`
3. Kill another: no toast (already unlocked).
4. Pick up a `stone_fathers_pulse` (KEY-type item) for the first time.
5. Toast: `Compendium: Stone-Father's Pulse acquired.`
6. **Expected:** the Compendium panel's Bestiary tab now lists `Stone Hopper`; the Relics tab lists `Stone fathers pulse`.

### 5.19 — Hunter's Crown title
1. Kill Glaur-em — the first Sovereign.
2. The `TitleSystem._on_boss_defeated` listener fires: `Hunter's Crown` added to `TitleSystem.titles_earned`; `equipped_title` set.
3. A `hunters_crown` item drops into your inventory (`Inventory.try_add(&"hunters_crown", 1)`).
4. Toast: `Title earned: Hunter's Crown.`
5. The Compendium **Titles** tab now lists `Hunter's Crown`.
6. **Expected:** killing the same boss again doesn't duplicate the title. Killing a *different* boss (e.g., Vorr'kell) earns a new title (`Tunnel-Walker`).

### 5.40 — Game-open opening sequence
1. Delete the local Settings (`opening_sequence_seen=false`) to reset.
2. New Game. The world is hidden behind a black `ColorRect` for the first ~7 seconds.
3. Sequence (≈9s total):
   - 0.6s: pause on black + `AudioBus.play_sfx(&"loom_hum")`.
   - 1.0s: `AETHERDEEP` title fades in.
   - 0.6s: pause.
   - 1.0s: `— The Sunken Aeon —` subtitle fades in.
   - 1.4s: hold.
   - Aphelion-beat sting + `screen_pulse_requested(0.6, 0.5)`.
   - 1.0s: hold.
   - Toast `Aelstren waits at the Anchor.`
   - 1.4s: hold.
   - 1.0s: black + text fade out.
4. Pressing **Esc**, **Space**, or **E** at any time skips immediately and runs `_finish`.
5. `_finish` fires the `first_step` tutorial hint via `TutorialDirector.fire_named`.
6. **Expected:** the sequence persists `opening_sequence_seen=true` in Settings — second New Game doesn't play it.

---

## G. Migration tickets (2.34, 3.40, 3.70, 3.72)

### 2.34 — Mob scan / photograph
1. Craft a `photograph` at the Clearstone Forge (2 glow_tube + 1 aphelion_fragment). Or pick one from a treasure chest (8% per chest).
2. Equip it in the hotbar; left-click toward a Stone-Hopper within ~120 px.
3. Toast: `Compendium: Stone Hopper photographed.` (or `Captured Stone Hopper — already known.` if previously logged).
4. `EventBus.skill_xp_gained.emit(&"skill_explorer", 8)` fires.
5. **Expected:** click without a target → `No mob in frame.` Aiming behind the cursor's forward dir doesn't register.

### 3.40 — Recipe scroll
1. Right-click while holding a `recipe_scroll` (consumable).
2. The scroll consumes itself.
3. If at least one recipe in `ROLLABLE_RECIPE_IDS` is still unrevealed: toast `Recipe learned: <pretty_id>`. The recipe id is added to `GameState.unlocked_recipes`; `EventBus.recipe_unlocked` fires.
4. If everything is known: toast `You already know every recipe this scroll could teach.` The scroll is **refunded** (`Inventory.try_add(&"recipe_scroll", 1)`).

### 3.70 — Boss-unique trinket drop
1. Kill Glaur-em. Verify the `glaurem_trinket` drops (alongside the other three items).
2. Right-click in inventory → Equip. The trinket binds to the `necklace` slot.
3. **Expected:** Inventory.equipment_slot_for(`glaurem_trinket`) returns `&"necklace"`. The `+2 armor` reflects on the player.

### 3.72 — Recipe-scroll chest drops
1. Open a non-locked treasure chest. 22% chance the rolled loot includes 1–2 `recipe_scroll` items.
2. Open a **key-locked** chest. The chance bumps to 45%.
3. **Expected:** the loot rolls also include the existing items (shaleseed_ingot, ancient_coin, aphelion_fragment, glow_tube, occasional bound_compass / world_scanner, occasional photograph at 8%).

---

## H. Regression sanity (must not break)

1. Mining a wall still rewards Loam + Mining XP (Phase 2).
2. Hitting a Stone-Hopper still rewards Melee XP and drops loot (Phase 2).
3. Crafting at the Loam Bench still works (Phase 3).
4. Chest open/deposit/withdraw still works (Phase 3).
5. Save/Load round-trip preserves Inventory + Skills + Equipment + explored chunks + respawn point (Phase 3/4).
6. The 7-tile Anchor plateau still spawns clear; biome ring crossing still triggers `EventBus.biome_changed` and `AudioBus._on_biome_changed` ambient swap (Phase 4).
7. Bound Compass / World Scanner / Treasure Map / Anchor Portable consumables still fire their effects via `player_combat._try_consume` id-dispatch (Phase 4).

---

## I. Known scope deferrals (do **not** test for Phase 5)

These tickets were intentionally MVP-scoped or deferred:

- **5.27 mob unique vocalization** — `mob_def.vocal_sfx_id` placeholder exists but no per-species SFX is authored yet. Procedural tone via `AudioBus._build_placeholder_tone` is the placeholder.
- **5.18 / 5.26 / 5.30 / 5.32 audio assets** — boss music, intro sting, fanfare, paper-bird audio currently all route through AudioBus placeholder tones. Replaced with real audio in Phase 15.
- **5.31 trial-chamber item craft** — no item form yet; the scene exists and works when instantiated by code or remote inspector. Item form lands with Phase 5.x polish.
- **5.33 carving persistence across reload** — the carving spawns on death but doesn't survive a save/load round-trip. Persistence lands with Phase 15.
- **5.40 ambient first-beat hum** — opening sequence uses a placeholder `loom_hum` sting. Real audio in Phase 15.

---

## J. Sign-off

Phase 5 is considered passed when **every section A–H** has a green check or a logged ticket. Anything in **I** is intentionally out-of-scope.

Report failures with:
1. Section letter + number.
2. Expected vs observed.
3. Repro steps (seed + chunk coord if procedural).
