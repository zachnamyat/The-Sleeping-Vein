# Phase 6 — Combat Depth: Manual Test Checklist

> Use this checklist to sign off on Phase 6 visually + interactively. The 90/90 GUT
> suite (`test_phase6_combat.gd` + earlier suites) covers the math; this document
> walks the in-engine flows that the unit tests can't reach. Step through every
> section in order on a fresh world; tick each line as you go. Anything that
> doesn't behave should be filed as a Phase-6 follow-up ticket and the
> corresponding kanban entry reopened.

---

## 0 — Setup (do once)

- [ ] Open `scenes/world/main.tscn` and run it.
- [ ] Confirm there are **no script-load errors** in the Output dock (especially
      around new autoloads `PlayerStats`, `CombatTracker`).
- [ ] Open the dev console (`~`) and verify autoloads resolve:
      `print(PlayerStats.crit_chance())` should return roughly `0.05`.
- [ ] In the Settings panel toggle `show_dps` ON so the DPS meter is visible.
- [ ] In the Settings panel verify `show_mob_hp` defaults to ON.

---

## 1 — Weapon classes & special attacks (6.1–6.4, 6.14, 6.16, 6.18, 6.24–6.27, 6.31, 6.36, 6.45, 3.47, 3.75–3.80)

> Spawn the test items via the dev console: `Inventory.try_add(&"<id>", 1)` for
> weapons; ammo: `Inventory.try_add(&"arrow_wood", 50)`, `Inventory.try_add(&"bolt_iron", 50)`,
> `Inventory.try_add(&"throwing_knife", 25)`.

- [ ] **Bow (existing)** — fires 1 arrow per click; arrow consumed; out-of-ammo toast on empty.
- [ ] **`bow_multishot` (3.54)** — every click fires 3 arrows in a 12° fan; only 1 ammo consumed per click.
- [ ] **`bow_pierce` (3.55)** — single arrow passes through up to 3 mobs in line.
- [ ] **`crossbow` (6.36)** — slower cycle, pierces 1 target, requires `bolt_iron`.
- [ ] **`heavy_crossbow` (6.36 + 3.78)** — even slower; charge while holding LMB; release for up to 2.5× damage; pierces 2 targets.
- [ ] **Gun (existing 6.2)** — straight-line bullet, faster than arrow.
- [ ] **`staff` (6.3)** — costs 8 mana per cast; out-of-mana toast when empty.
- [ ] **`wand` (3.79)** — 3 mana per cast, fast cycle, returns 5% mana on hit.
- [ ] **`tome` (3.80)** — 6 mana per cast; killing a mob refunds 8 mana; passive `+1.0/s` mana regen visible on HUD.
- [ ] **`summon_focus` (6.4)** — costs 12 mana, spawns a 30-second tinted minion that follows the player.
- [ ] **`whip` (6.24)** — special attack (RMB) yanks the first mob within 56 px toward you; on-hit bleed has ~20% chance.
- [ ] **`boomerang_throw` via `throwing_axe` (3.75 + 6.25)** — flies out, returns to player after 0.4 s, no inventory consumption.
- [ ] **`spear` (6.26)** — RMB special is a long-reach thrust; charging extends damage.
- [ ] **`throwing_knife` (6.27)** — consumed on use; stacks to 50; small bleed chance on hit.
- [ ] **`rapier` (3.76)** — fast 0.28 s swings, +5% crit chance bonus.
- [ ] **`greatsword` (3.77 + 6.45)** — slow 0.95 s swings; RMB triggers whirlwind 360° spin; heavy-attack flag fills mob stagger meter quickly.
- [ ] **Dual wield (3.47)** — equip a one-handed melee in off-hand AND hold a one-hander; alternating swings; off-hand swing damage is 60% of main hand.

## 2 — Status effects (6.6, 6.7, 6.8, 6.9, 6.19, 6.22, 6.30, 6.50–6.53)

> Quickest reproductions: console `_get_player().get_node("StatusEffects").apply(&"<id>", 6.0, null)`.

- [ ] **Burn** — orange flame jitter overlay above head; damage ticks every ~0.5 s.
- [ ] **Poison** — green bubble specks; HP drops; healing potions restore noticeably less while active.
- [ ] **Cold** — frost-blue flecks; movement halved.
- [ ] **Freeze** — translucent ice cube; player can't move OR attack.
- [ ] **Stun** — gold stars circle head; player frozen briefly.
- [ ] **Bleed** — red drips fall; per-tick damage scales with max HP (~0.5%).
- [ ] **Confusion** — `?` glyphs orbit head; WASD inputs flip (W→down, etc.).
- [ ] **Slow** — generic 65% speed cap; stacks multiplicatively with cold (test by applying both — about 32% speed).
- [ ] **`cleanse_tonic` consumable** — apply 3 statuses, drink the tonic → BuffStrip empties immediately.

## 3 — Combat stats & gear (6.10, 6.11, 6.12, 6.17, 6.28, 6.29, 6.32, 6.33, 6.40, 6.41, 6.55, 6.56)

- [ ] Equip `bone_shield` → armor bar shows +4 armor; KB resist +20%.
- [ ] Equip `lantern_offhand` → mana regen up by 0.5/s on the HUD readout.
- [ ] Hold RMB while shield equipped → block icon (parry window) active; incoming hit damage halved.
- [ ] Console: `Inventory.equipment[&"ring_1"] = &"glaurem_trinket"; PlayerStats.recompute()` → confirm crit chance change visible (printf `PlayerStats.crit_chance()`).
- [ ] Mining with the wooden pickaxe at Crafting talent level 0 vs 4 → cooldown ratio drops by ~20% at 4 points.
- [ ] Equip an item with `mining_pierce` set → swing a wall and check that the next tile in-line gets damaged too.

## 4 — Boss attack patterns (6.48)

- [ ] Spawn Glaur-em via dev console / boss-altar → red AoE telegraph rings appear ~0.85–1.1 s before each slam.
- [ ] Bring Glaur-em to ≤50% HP → cycler swaps from `glaurem_phase1` to `glaurem_phase2` (notice double-slam pattern).
- [ ] Confirm boss music kicks in on engagement (Phase 5 carry-over) and clears on death.

## 5 — HUD / UX (6.13, 6.42, 6.49, 6.57, 2.30, 2.40, 2.46)

- [ ] BuffStrip below the mana bar shows new icons + `Ns` countdown for every active status / food buff.
- [ ] AmmoLabel directly above the hotbar reads `Wooden Arrow × N` while a bow is selected and updates as ammo is consumed.
- [ ] DPS Meter (bottom-right) updates to reflect actual DPS; turn `show_dps` OFF in Settings → label disappears.
- [ ] Mob HP bar shows above each mob when damaged; vanishes when full HP.
- [ ] Bomb throws spawn a translucent orange ring at the impact point ~0.7 s before exploding (2.30 telegraph).
- [ ] Damage numbers carry the type colour (e.g., orange for burn, green for poison) — verify by hitting with magic vs physical weapons.

## 6 — Movement / dodging (6.23, 6.34)

- [ ] `Space` triggers a dodge roll in the current input direction (or facing if idle); roll grants ~0.32 s of i-frames; cooldown 1 s.
- [ ] During the dodge: a hostile contact attempt does NOT damage the player.
- [ ] Hold attack_primary while moving with a `greatsword` equipped → speed visibly drops to ~45%.
- [ ] Hold attack_primary while moving with `rapier` → speed barely drops (≥85%).

## 7 — Audio + lighting (2.42, 2.49, 6.59, 6.60, 6.61)

- [ ] Damage a mob with magic-type weapon → distinct hit-magic SFX cue; physical weapon plays a different cue.
- [ ] Stand near a mob, walk far away, hit it from across the screen → SFX is quieter / muffled (occlusion drop).
- [ ] Engage 2-3 mobs at once → adaptive layered music swells as combat intensity rises; stops swelling once the encounter ends.
- [ ] Place a `lantern` → wider warm cone than torch. Place an `oil_lamp` → wider still. Place a `ward_lantern` → bright blue cone.

## 8 — Combat depth visuals (6.20, 6.51–6.54)

- [ ] Hit a target with a lightning-typed projectile → chain arc visual jitters between the primary target and a nearby second mob (LightningArc draw).
- [ ] Apply confusion to the player → `?` glyphs orbit overhead and inputs flip.
- [ ] Apply freeze → translucent ice cube renders over the player; movement disabled.
- [ ] Apply bleed → red drip particles fall down the body.
- [ ] Apply burn → orange flame jitter pulses around the head.

## 9 — Reload / ammo flow (3.81, 3.82, 6.57)

- [ ] Fire `crossbow` → cooldown extends by `reload_seconds * 0.5` after each shot (visibly slower than bow).
- [ ] AmmoLabel decrements by exactly 1 per shot; switching weapons updates the label to show the new ammo type / count.

## 10 — Save round-trip

- [ ] Save the game with statuses applied + buff strip populated + DPS meter on.
- [ ] Reload the slot → core systems initialize correctly (status effects clear on load is acceptable; the persistent items remain in inventory).

---

## Sign-off

- [ ] **All 90 GUT tests pass headlessly** (CI green + local `godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`).
- [ ] **All sections above ticked.**
- [ ] Phase 6 in `kanban.html` shows 0 backlog tickets after the `2026-05-15-phase6-full-closure` migration runs.
- [ ] Manual sign-off recorded in `ROADMAP.md` Phase 6 exit-criterion line.
