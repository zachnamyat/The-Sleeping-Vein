# Phase 7 — Skill Talent Trees: Manual Test Checklist

> Use this checklist to sign off on Phase 7 visually + interactively. The 113/113
> GUT suite (`test_phase7_systems.gd` + earlier suites) covers the math; this
> document walks the in-engine flows that the unit tests can't reach. Step
> through every section in order on a fresh world; tick each line as you go.
> Anything that doesn't behave should be filed as a Phase-7 follow-up ticket
> and the corresponding kanban entry reopened.

---

## 0 — Setup (do once)

- [ ] Open `scenes/world/main.tscn` and run it.
- [ ] Confirm there are **no script-load errors** in the Output dock (especially
      around new autoloads `TalentRegistry`, `LuckSystem`, `SkillChallenges`).
- [ ] Open the dev console (`~`) and verify autoloads resolve:
      `print(TalentRegistry.all_trees().size())` should print `12`.
- [ ] `print(SetBonuses.SETS.keys())` should print at least three set ids.
- [ ] `print(LuckSystem.current_luck())` should print `0.0` on a fresh start.

## 1 — Talent tree data & panel (7.1, 7.2, 7.13, 7.17, 7.18)

- [ ] Press **K** — TalentPanel opens.
- [ ] Header shows `Unallocated points: 0 • Total earned: 0 • Luck: 0`.
- [ ] Tab bar contains 12 tabs labelled with lore names (Stratabreaking, Walking,
      Hand-Strike, Hand-Throw, Anchoring, Form-Making, Tending, Listening, Hearth,
      Resonance, Calling, Bursting).
- [ ] Each tab shows a 5-tier × 3-column grid of buttons.
- [ ] XP bar above the grid reads the active skill's `Lv N (into / span xp to next)`.
- [ ] Hover any node → tooltip lists name + description + `effect_id × effect_value`.
- [ ] Locked nodes (prerequisites not met) render grey + disabled. Tier-1 base
      nodes (no prereqs) render white at 0 points; green when allocatable.

## 2 — Allocation, prerequisites, and capstones (7.3–7.7, 7.13)

> Quickest way to farm 20+ talent points: console
> `for s in SkillSystem.ALL_SKILLS: SkillSystem.add_xp(s, 10000)`.

- [ ] After level-up: HUD toast `<Skill> reaches Lv N • +1 talent point`,
      camera pulse, and `skill_level_up` SFX play.
- [ ] Open TalentPanel — header updates `Unallocated points: N`.
- [ ] Click the Mining `Hammer Hand` node — rank goes `(0/5) → (1/5)`,
      `Unallocated points` decrements, header `Total earned` stays the same.
- [ ] Tier-2 nodes (Quick Swing / Strata-pierce) become allocatable (green) once
      Hammer Hand has ≥1 rank.
- [ ] Try clicking the Mining capstone (Stratabreaker) before tier-4 nodes are
      ranked → toast `Prerequisite not met.`, no point spent.
- [ ] Allocate Hammer Hand → Quick Swing → Patient Eye → Resonant Strike →
      Strata-pierce. Now the capstone unlocks. Click → rank becomes 1/1,
      button turns gold and disables.

## 3 — Right-click refund + Respec Scroll (7.7)

- [ ] Right-click any allocated node → rank decrements by 1, point returned to
      pool; right-click again refunds the next rank.
- [ ] Right-clicking an unallocated node does nothing.
- [ ] Add a Respec Scroll: `Inventory.try_add(&"respec_scroll", 1)`.
- [ ] Click the footer button `Respec all (consume Respec Scroll)` → scroll
      consumed, every allocation refunded into the pool, toast
      `Talents refunded.`
- [ ] Try the button with 0 scrolls in inventory → toast `Respec Scroll required.`

## 4 — Talent presets (7.16)

- [ ] Allocate 4-5 points across Mining only.
- [ ] Click `S1` in the preset bar → toast `Preset 1 saved.`; `L1` button now
      reads `L1 (Npt)`.
- [ ] Allocate a different build (move points to Vitality).
- [ ] Click `L1` → toast `Talent preset 1 loaded.`; Mining returns to the
      saved snapshot, Vitality drops to 0.
- [ ] Save preset 2 with the current build, then `L2` — confirm the
      load/save cycle round-trips.
- [ ] Save → quit to title → load slot → reopen TalentPanel → presets persist.

## 5 — XP buffs (7.8)

- [ ] `Inventory.try_add(&"xp_tonic", 1)` then put it on the hotbar, RMB to drink.
- [ ] Header BuffStrip shows `xp_boost` icon with countdown.
- [ ] Mine a tile → toast XP gained is **125% of base** (compare with no buff).
- [ ] Add `mining_focus_loaf` → mine again → XP is **150%** of base (or 187%
      if the Tonic is also active).
- [ ] Buff expires after the listed duration; subsequent XP gains return to base.

## 6 — Character sheet (7.14, 7.17, 7.18)

- [ ] Press **C** — CharacterSheetPanel opens.
- [ ] Left column lists Armor, Crit chance/dmg, Lifesteal, Manasteel, Thorns,
      KB resist, Cooldown reduction, Mining speed, Mining pierce, Max-HP bonus,
      Max-mana bonus, Regen/sec, Luck, Pickup radius.
- [ ] Middle column lists all 12 skills with `Lv N (+bonus) into/span` (the
      `+bonus` shows when an accessory bumps effective level).
- [ ] Right column shows allocated points per skill + `★capstone` marker if
      tier-5 is taken.
- [ ] Footer: `Buffs: …`, `Accessory skills: …`, `Set bonuses: …` lines
      populate as items / buffs are equipped/applied.
- [ ] Closing the inventory or pressing Esc closes the sheet.

## 7 — Accessory skill bonus (7.11)

- [ ] `Inventory.try_add(&"ring_mining_skill", 1)` and equip in ring slot 2.
- [ ] Character sheet should now show Mining `Lv N (+5)`.
- [ ] Mine a Loam tile → damage formula uses **effective_level**
      (verify by hitting a wall and seeing increased damage numbers).
- [ ] Unequip the ring → effective level returns to base.

## 8 — Luck stat + Loot magnet + drop-rate (7.19, 2.22, 3.83)

- [ ] Equip `thread_ring_luck` (+15 Luck) and `necklace_droprate` (+30 Luck);
      character sheet should show `Luck 45`.
- [ ] Kill a Stone-Hopper without Luck → 0-2 drops.
- [ ] Kill another with Luck 45 → noticeable extra rolls (1-3 bonus picks per
      `LuckSystem.LUCK_PER_BONUS_DROP = 25`).
- [ ] Equip `bracelet_loot_magnet` (+150% pickup radius).
- [ ] Drop an item next to you, walk away → drops pull in from much wider
      radius (~90 px vs 36 px baseline).

## 9 — Set bonuses (3.20)

- [ ] Console-spawn 2 Ember Iron pieces (e.g. `Inventory.try_add(&"ember_iron_chestpiece", 1)`)
      and equip both (use additional gear if necessary to fill slots).
- [ ] Character sheet footer should now list `Set bonuses: Ember Iron (2/4)`.
- [ ] Stats reflect +4 armor + 10 max-HP.
- [ ] Equipping a third piece (e.g. helmet) adds crit chance bonus (+5%).
- [ ] Equipping a fourth piece adds +20% crit damage; tier-5 bonus is shown
      in tooltip preview if hovered.

## 10 — Anvil reforge (3.29)

- [ ] Place an anvil: `Inventory.try_add(&"anvil_placeable", 1)` and place via
      LMB while the anvil is hotbarred.
- [ ] Walk up to the anvil and press **E** → AnvilPanel opens.
- [ ] Without `ancient_coin` in inventory → list shows `No reforgeable
      items, or not enough coins.`
- [ ] `Inventory.try_add(&"ancient_coin", 50)` and `Inventory.try_add(&"bow", 1)`.
- [ ] Re-open the panel → the bow row appears with a `Reforge` button.
- [ ] Click `Reforge` → 8 coins deducted, affix label changes to e.g. `[Keen]`,
      toast `Reforged: Keen`.
- [ ] Equip the reforged bow → stats reflect the affix (Keen: +8% crit chance;
      Brutal: +30% crit damage; etc.) — verify on character sheet.
- [ ] Save → quit → reload → equipped reforge affix persists.

## 11 — Charge-mine / area-mine talent (2.27, 7.3)

- [ ] Allocate Mining `Resonant Strike` (tier 4) — splash radius grows by 8 px.
- [ ] Mine a tile in a wall cluster → adjacent cardinal tiles (N/S/E/W) also
      take damage (visible cracks).
- [ ] Allocate to rank 2 → splash also touches diagonal neighbours.
- [ ] Allocate Mining `Strata-pierce` ranks → some swings break the next tile
      in line of fire (random chance based on rank).

## 12 — Elite + Champion mobs (2.32, 2.33, 2.47)

- [ ] Use a tier-2 mob_spawner: in console, place one with `tier = 2`. Every
      spawn rolls **at least Elite**.
- [ ] Elite mob: tinted gold-ish (1.1, 0.9, 0.65); has Affix-name behaviour
      (Swift = faster, Brutal = more dmg, etc.); ~60% larger HP pool than
      base; drops 1 extra random loot roll.
- [ ] Tier-3 spawner forces Champion: tinted red, "Affix1 Affix2 Champion"
      label floats above head; drops 2 extra random rolls + guaranteed
      2-5 Ancient Coins.
- [ ] Confirm the loot-table extras include rarer items at higher Luck (the
      `apply_luck` pass bumps bonus rolls).

## 13 — Skill challenges (7.15)

- [ ] Console: `SkillChallenges.start_challenge(&"skill_mining")` → toast
      `Challenge: Stratabreaking Sprint started.`
- [ ] Within 30s, mine 10 tiles → toast `Challenge complete: +1 talent point.`
- [ ] Trying to start a second challenge while one is running → toast
      `A challenge is already running.`
- [ ] Wait out a challenge without meeting the goal → toast `Challenge failed.`,
      no talent point gained.

## 14 — Level-100 mastery (7.10, 7.20)

- [ ] Force-cap Mining via console: `SkillSystem._level[&"skill_mining"] = 99;
      SkillSystem.add_xp(&"skill_mining", 100000)` until level shows 100.
- [ ] On the 100 → toast `Mining MASTERED. Cosmetic unlocked.`
      + `sovereign_fanfare` SFX.
- [ ] `SkillChallenges.mastery_unlocked[&"skill_mining"]` is true.
- [ ] Save → reload → the mastery flag persists in
      `GameState.unlocked_compendium["mastery_skill_mining"]`.

## 15 — Save round-trip (v4 → v5)

- [ ] Allocate 6+ talents across 3 trees; save preset 0.
- [ ] Save the game.
- [ ] Quit to title; reload the slot.
- [ ] TalentPanel shows the exact allocation; preset 0 still has the snapshot.
- [ ] CharacterSheet stat aggregates match pre-save values.
- [ ] AnvilPanel reforges on equipped items survived.

## 16 — Multiplayer XP-share stub (7.12)

> Real multiplayer lands in Phase 13; this is the stub.

- [ ] `NetSystem.is_party_active()` returns `false` in single-player.
- [ ] Killing a mob in single-player does NOT emit a duplicate
      `skill_xp_gained` event (no double XP).

---

## Sign-off

- [ ] **All 113 GUT tests pass headlessly** (`godot --headless --path . -s
      addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`).
- [ ] **All 16 sections above ticked.**
- [ ] Phase 7 in `kanban.html` shows 0 backlog tickets after the
      `2026-05-15-phase7-full-closure` migration runs.
- [ ] Manual sign-off recorded in `ROADMAP.md` Phase 7 exit-criterion line.
