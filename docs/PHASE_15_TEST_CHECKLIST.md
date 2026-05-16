# Phase 15 — Polish & Parity Gap Closure: Manual Test Checklist

> **Scope**: Verify every Phase 15 system end-to-end in a running build. The 60 GUT tests in `tests/unit/test_phase15_systems.gd` already cover the autoload logic; this checklist walks the *player-facing* paths.
>
> **Build under test**: `0.1.x-dev` after Phase 15 closure (2026-05-17). SaveSystem version: **13**.
>
> **Pre-flight**: Start in a fresh world (delete `user://saves/` if you want a clean slate). The first-run wizard will surface — that's expected.

---

## 0. First-Run Wizard (15.10 / 15.75 / 4.65)

- [ ] On first launch of a fresh user data dir, **First-Run Wizard** appears front-and-center.
- [ ] Page 1 ("Welcome, Walker") shows + Back button is disabled.
- [ ] Page 2 ("Display & Language") — Language OptionButton lists 10 locales; auto-detected locale is pre-selected.
- [ ] Page 2 — Window-mode OptionButton applies on selection (Windowed / Fullscreen / Borderless).
- [ ] Page 3 ("Accessibility") — Text scale, Colorblind mode, Subtitles, Aim assist, Reduce flashes pickers/checkboxes present and changing them persists via Settings.
- [ ] Pressing **Finish** dismisses the wizard and writes `first_run.completed = true`.
- [ ] Restart the game — wizard does **not** appear again.

## 1. World Settings (15.5 / 15.38 / 15.39 / 15.34)

- [ ] Title screen → New World opens `WorldSettingsPanel`.
- [ ] World size OptionButton (Small / Normal / Large / Huge) applies to `Phase15Helpers.world_size_mult` (0.5 / 1.0 / 1.5 / 2.5).
- [ ] Difficulty preset (Casual / Normal / Hard / Hard+) applies player_damage_mult / mob_hp_mult correctly:
  - [ ] Casual: player damage > 1.0, mob HP < 1.0.
  - [ ] Hard+: player damage < 1.0, mob HP ≥ 2.0.
- [ ] Hardcore checkbox flips `Phase15Helpers.hardcore_active` and emits the signal.
- [ ] Creative-mode checkbox flips `Phase15Helpers.creative_mode`.
- [ ] Starting Kit OptionButton (Bare Hands / Explorer / Crafter / Warrior / Farmer) sets `Phase15Helpers.starting_kit_id`.

## 2. Accessibility (15.10 / 15.17 / 15.18 / 15.59 / 15.60 / 15.61 / 15.62 / 15.63)

- [ ] AccessibilitySettingsPanel surfaces every flag.
- [ ] Colorblind mode (off / protanopia / deuteranopia / tritanopia / achromatopsia) — verify each remap; achromatopsia returns greyscale.
- [ ] Text scale (5 presets from 0.8× to 2.0×) clamps to (0.5, 3.0) and persists.
- [ ] High contrast applies the `contrast_boost` to UI colors.
- [ ] Aim assist toggle: with it ON and a mob nearby, `AccessibilityManager.nearest_enemy_for_aim()` returns the mob; with it OFF, returns null.
- [ ] Pause-on-focus-loss: Alt-Tab → game pauses; bring window back → stays paused (user must unpause manually).
- [ ] One-handed preset toggle flips the flag.
- [ ] Subtitles toggle — emit a test subtitle via `AccessibilityManager.emit_subtitle("test")`; it appears in the SubtitleOverlay bottom-center, hides after ~4 s.
- [ ] Reduce screen shake — combat hits don't shake.
- [ ] Reduce flashes (photosensitive_safe) — boss telegraphs render at lower flash intensity.
- [ ] Per-action hold-vs-toggle: flip `sprint` to toggle, verify Sprint key now toggles instead of holds.

## 3. Bestiary (15.3)

- [ ] Press **K** (or trigger via DevConsole `toggle_bestiary`) — `BestiaryPanel` opens.
- [ ] No entries yet → "(no entries yet — defeat enemies to record them)".
- [ ] Kill a Stone-Hopper → re-open: "Stone Hopper" entry appears.
- [ ] First entry shows Class only; after 3 kills, weaknesses + base HP + base damage reveal.
- [ ] Lore blurb (if mob def has one) renders.

## 4. Logbook (15.16)

- [ ] LogbookPanel opens from the pause menu or via direct test.
- [ ] Defeat a boss → entry "Sovereign Quieted" auto-added with date.
- [ ] NPC arrival → entry "An Arrival" auto-added.
- [ ] Manually call `LogbookPanel.add_entry(&"quest", "Title", "Body")` → row appears.

## 5. Run History + World Stats + Damage Breakdown (15.40 / 15.47 / 15.48)

- [ ] `RunHistoryPanel` shows "(no runs yet)" on a fresh world.
- [ ] After a run completes via `Phase15Helpers.close_current_run(&"complete")`, the row appears with date / duration / deaths / bosses / difficulty / outcome.
- [ ] Buffer caps at 16 runs (older drop off the front).
- [ ] `WorldStatisticsPanel` shows 14 counters + NG+ cycles; counters update live as you mine / kill / pick up.
- [ ] `DamageBreakdownPanel` auto-shows on `boss_defeated`; auto-hides after 8 s; numbers (damage_dealt / hits_taken / dodges / crits / highest_single_hit / dps_peak / dps_avg / duration) populate.

## 6. Cosmetics: Dye + Wardrobe + Visual Layers (3.36 / 3.37 / 3.62-3.65 / 3.68 / 3.69)

- [ ] Press **U** → `WardrobePanel` opens with **Dye** / **Outfits** / **Visuals** tabs.
- [ ] Dye tab — every layer (helmet / chest / legs / boots / back / off_hand / cosmetic_hat / cape / backpack / pet_collar) has a `ColorPickerButton` + Reset.
- [ ] Apply a red dye → the layer's modulate updates on the player.
- [ ] Outfits tab — save current visuals to slot 1, reload → visuals revert.
- [ ] Visuals tab — toggling a layer's visibility hides/shows the rendered visual.

## 7. Photo Mode (15.22)

- [ ] Press **F11** (or `photo` console command) → PhotoMode toggles, game pauses, panel appears top-right.
- [ ] Filter picker: cycle through None / Sepia / Bw / Aurora / Aphelion / Final — visible tint changes.
- [ ] Show-HUD checkbox toggles the HUD.
- [ ] Capture → file written to `user://photos/tsv_<ts>.png`. Filter is applied on save.
- [ ] Achievement `ach_first_photo` unlocks after first capture.

## 8. Debug Overlay (15.25 / 15.53 / 15.54 / 15.55 / 15.81)

- [ ] **F3** → F3 overlay shows: FPS / draws / prims / mem / pos / tile / chunk.
- [ ] **F4** → Free-cam toggle (signal-only by default; wire-up to camera handled in scene).
- [ ] **F5** → Wireframe toggle.
- [ ] **F6** → Perf graph (120-sample rolling FPS line + 60Hz baseline + 30Hz red baseline).

## 9. Game Modes (15.28 / 15.29 / 15.30 / 15.31)

- [ ] DevConsole `speedrun start` → `SpeedrunTimerHUD` top-left lights up; `speedrun split a` appends a row.
- [ ] `speedrun stop` → toast shows total seconds.
- [ ] `bossrush start` → `boss_rush_progress` 0/11.
- [ ] Defeat a boss → progress increments + signal fires.
- [ ] `endless start` → `endless_floor = 1`; `endless descend` → floor 2 + hp_mult/loot_mult scale up.
- [ ] `daily` → deterministic seed for today.
- [ ] `weekly` → deterministic seed for week.

## 10. Achievements Extended (15.4 / 15.14 / 15.15 / 15.41-15.46)

- [ ] AchievementToast (top-right) pops when any achievement unlocks.
- [ ] Visit all 9 biomes → `ach_visit_all_biomes` unlocks.
- [ ] Defeat 500 mobs → `ach_kill_500_mobs` unlocks (or use DevConsole).
- [ ] Combo hit 50× → `ach_combo_50` unlocks.
- [ ] Hidden achievements (`ach_easter_dev_credits`, `ach_easter_all`) show "???" until unlocked.
- [ ] Save an outfit → `ach_save_first_outfit`.
- [ ] Login 7 days in a row → `ach_login_streak_7`.

## 11. Easter Eggs (15.57)

- [ ] DevConsole `egg egg_dev_credits` → toast + `ach_easter_dev_credits` (hidden) reveals.
- [ ] Re-running the same egg id is a no-op.
- [ ] Each biome has one registered egg (9 total).

## 12. Seasonal Events (15.6 / 15.58)

- [ ] Set system date inside the Halloween window (Oct 25 – Nov 7) → `SeasonalBanner` shows "Hollow Tide".
- [ ] Set system date inside the Winter window (Dec 18 – Jan 7 *with wrap*) → "Lantern Days".
- [ ] Anniversary (May 9 – May 19) → "Anniversary".
- [ ] Outside all windows → banner hidden.

## 13. Tutorial / First-Boss / Login Reward (15.49 / 15.68)

- [ ] `maybe_grant_tutorial_reward()` fires once per save; second call is no-op.
- [ ] First boss kill triggers `first_boss_reward_granted` exactly once (only for `boss_glaurem`).
- [ ] Login on a new day → `login_streak_days` bumps; `consume_streak_reward` returns `min(7, days) × 10` coins.

## 14. Localization (15.9 / 15.72 / 15.74 / 15.75)

- [ ] LocalizationManager auto-detects locale on first launch (from `OS.get_locale()`).
- [ ] `apply_locale(&"vesari")` triggers RTL layout via `apply_rtl_to_control`.
- [ ] `apply_locale(&"klingon")` returns false (unsupported).
- [ ] `note_missing_key("test.missing")` appears in the missing-keys audit log.
- [ ] CSV export round-trips key/en/locale triplets; CSV import writes back to `assets/i18n/<locale>.json` (or `user://i18n/` if res:// is read-only).

## 15. Performance (15.8 / 15.19 / 15.20 / 15.76 - 15.81 / 15.90)

- [ ] DevConsole `perf low` → applies Low preset (lod_distance 1, max_lights 8, particles 0.3).
- [ ] `perf potato` → applies Potato (lod 1, max_lights 4, particles 0.0).
- [ ] `verify_texture_batching()` returns a `{distinct_materials, draw_calls_estimated, ok}` report.
- [ ] `should_cull_sprite_at` returns true for off-screen positions.
- [ ] `should_cull_light_at` returns true past `lod_distance_chunks × 64 × 16 + radius`.
- [ ] `mob_ai_tick_divisor` returns 1/2/4 as distance grows.
- [ ] `can_load_more_chunks` rejects past the memory budget.

## 16. Save Backup (15.23 / 15.24 / 15.36 / 15.37 / 15.51 / 15.52)

- [ ] Autosave fires every `autosave_interval_seconds` (default 300; clamps 30-3600).
- [ ] Three slots rotate: autosave_0 (newest) → autosave_1 → autosave_2; the 4th oldest is deleted.
- [ ] Thumbnail saved to `user://saves/<slot>/thumb.png` (160 × 90 PNG).
- [ ] `extended_meta(slot)` returns playtime / deaths / bosses / world seed.
- [ ] Corrupt the state.json of a slot → `verify_slot` reports `ok=false`, `auto_recover` copies the newest backup over the slot.
- [ ] `migrate_state(state, 11, 13)` adds `phase14_helpers`, `phase15_helpers`, `cosmetics` defaults.

## 17. Network Polish (15.65 / 15.66 / 15.67 / 15.69)

- [ ] `NetPolish.toggle_bandwidth_meter()` shows the BandwidthMeterHUD; rates update every 1 s.
- [ ] Peer disconnect triggers a `peer_grace_started` signal (30 s default). Reconnect within window → `resolve_grace`.
- [ ] Past the deadline → `peer_grace_expired`.
- [ ] FriendListPanel renders registered friends; toggling online state flips status.
- [ ] DevConsole `copy_seed` copies `GameState.world_seed` to the clipboard.

## 18. Crash + Bug Report + Telemetry (15.21 / 15.82 / 15.83 / 15.91)

- [ ] DevConsole `report_bug "Player got stuck"` → `BugReportPanel` saves a JSON + screenshot to `user://bug_reports/`.
- [ ] Telemetry opt-in toggle persists via Settings (`telemetry.opt_in`).
- [ ] `flush_telemetry` writes batched events to `user://telemetry_rollup.json`.
- [ ] `record_crash("stack", "error")` writes a JSON to `user://crash_reports/`.
- [ ] ReplaySystem: `start_recording` + `stop_recording` writes JSON with `world_seed` + `frames` array.

## 19. Steam Integration (15.12 / 15.13 / 15.27 / 15.32 / 15.50 / 15.64 / 15.73)

- [ ] `SteamIntegration.cloud_upload("slot")` writes a marker; `cloud_download` reads it back.
- [ ] `set_achievements_enabled(false)` → `unlock_achievement` returns false.
- [ ] `set_beta_branch(true)` → `on_beta_branch` true.
- [ ] `sanity_check("payload", 99MB)` returns false (anti-cheat oversize).
- [ ] `subscribe_workshop("mod_a")` is idempotent.
- [ ] Trading card paths resolve to `assets/sprites/steam/cards/<id>.png`.

## 20. Cheat Detection (15.35)

- [ ] Fresh run → `Phase15Helpers.achievements_enabled()` returns true.
- [ ] Open DevConsole (F1 or `) once → `console_was_used = true`; `achievements_enabled()` returns false.
- [ ] Persists for the rest of the run.

## 21. NG+ Inheritance (15.94)

- [ ] After Phase 12 ending → `GameState.start_new_game_plus()` resets boss/recipe/sliver state.
- [ ] `Phase15Helpers.is_ng_plus_carry_over(&"sovereign_threads")` returns true.
- [ ] Override `set_ng_plus_carry_override(&"defeated_bosses", true)` → carry-over flips.

## 22. Combo Counter + Death Recap + Stagger Anim (2.26 / 2.38 / 2.39)

- [ ] Combo counter HUD appears at hit ≥ 2; color tiers: gold ≥10, orange ≥25, red ≥50.
- [ ] Combo decays after 3 s without a hit.
- [ ] On player death, `DeathRecapPanel` shows "you have fallen" + last damage source + slivers remaining + run playtime + deaths + combo high.
- [ ] Heavy hits on a Mob with `staggered` signal play the `MobStaggerAnim` (shake + red tint, 0.25 s).

## 23. Ore Particles + Pickup Magnet (2.24 / 2.37)

- [ ] Mining a tile spawns `OreExtractParticles` with per-ore color (shaleseed=grey, clearstone=cyan, ember_iron=orange, etc.).
- [ ] Walking near an ItemDrop triggers `PickupMagnet`: drop tweens toward player along an accelerating curve (not snap).
- [ ] Loot magnet bracelet (Phase 7) expands the radius.

## 24. Mob Death SFX (2.43)

- [ ] Killing a melee mob plays `mob_death_melee.ogg`.
- [ ] Killing a ranged mob plays `mob_death_ranged.ogg`.
- [ ] Killing a Boss does NOT play the per-class sound (boss has its own defeat fanfare).

## 25. Biome Blend Shader (4.45)

- [ ] Crossing into a new biome triggers `BiomeBlendShader._on_biome_changed` → screen pulse + toast "Entered <biome>".

## 26. DevConsole Phase 15 Commands

For each, verify the command runs without error and produces the documented effect:

- [ ] `difficulty <preset>` switches `Phase15Helpers.difficulty_preset`.
- [ ] `hardcore [on|off]` toggles hardcore.
- [ ] `speedrun start|split|stop` drives `GameModes`.
- [ ] `bossrush start|next` drives `GameModes`.
- [ ] `endless start|descend` drives `GameModes`.
- [ ] `egg <egg_id>` discovers an egg.
- [ ] `photo [filter]` toggles PhotoMode + sets filter.
- [ ] `perf <preset>` applies PerfManager preset.
- [ ] `f3` toggles DebugOverlay F3.
- [ ] `netmeter` toggles NetPolish bandwidth meter.
- [ ] `copy_seed` copies world seed to clipboard.
- [ ] `locale <code>` calls LocalizationManager.apply_locale.
- [ ] `recover <slot>` calls SaveBackup.auto_recover.
- [ ] `backup_now` triggers SaveBackup.perform_autosave.
- [ ] `report_bug <desc>` writes a bug JSON + screenshot.
- [ ] `daily` / `weekly` start the challenge mode.

## 27. SaveSystem v13 Round-Trip

- [ ] Set difficulty Hard, hardcore on, discover an egg, dye chest blue, save outfit 2.
- [ ] `SaveSystem.save_to_slot("test")`.
- [ ] Restart the world / reset state.
- [ ] `SaveSystem.load_from_slot("test")`.
- [ ] Difficulty = Hard, hardcore = true, egg recorded, dye matches, outfit 2 label matches.
- [ ] `SaveSystem.SAVE_VERSION == 13`.

## 28. Audio Profile (15.89)

- [ ] DevConsole or settings: switch to **Headphones** profile → `AudioProfile.profile` updates and signal fires.
- [ ] Switch back to **Speakers**.
- [ ] `apply(&"nonsense")` returns false.

---

## Automated Tests

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_phase15_systems.gd -gexit
```

Expected: **458/458 tests passing** (was 396/396 before Phase 15; 60 new cases in `test_phase15_systems.gd`).

## Open Items / Deferrals

The five Phase 15 asset polish meta-tickets (15.97 - 15.101) are **deferred to content-freeze week (15.92)** as documented per-asset rework: re-arting the 9 biome tile atlases, every item icon, every structure sprite, every mob+boss sprite, and the VFX/UI/font review pass. The skeleton for the work lives in `tools/process_phase*_assets.py`. None of these block playable parity; the game ships with the Phase-1-onward placeholder art.

10 polish-pass Gemini sprites *did* land this phase (achievement badge, photo mode icon, wardrobe icon, logbook icon, speedrun icon, accessibility icon, dye-pot icon, bug-report icon, Hunter's Crown medallion, Steam trading card) — see `assets/manifest.json` entries 'ui_ach_badge_walker' through 'steam_trading_card_walker'.

---

## Sign-off

When every box above is checked, Phase 15 is complete and the build is **mechanical-parity-complete**. Sign and date below before opening the kanban for Phase 16.

- Build version: ____________________
- Tester:        ____________________
- Date:          ____________________
