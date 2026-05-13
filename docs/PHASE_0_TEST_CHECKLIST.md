# Phase 0 — Manual Test Checklist

Walk this top-to-bottom and tell me what fails. Numbered to match the kanban
ticket ids so we can mark each `done` or back to `ready` after the sweep.

Pre-reqs:
- Godot 4.6.x installed and on PATH (or `~/bin/godot[.exe]`).
- Python 3 with Pillow (already used by `tools/check_palette.py`).

---

## A. Headless smoke (must already pass; re-confirm)

```sh
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
godot --headless --path . --quit-after 5
godot --headless --path . res://scenes/world/main.tscn --quit-after 5
```

Expected:
- `--import` finishes without GDScript errors (the `GutLogo.tscn` UID warning is benign).
- GUT prints `21/21 passing`.
- Both `--quit-after` calls print only the engine version line and the standard
  RID-leak teardown noise. No GDScript backtraces.

If any of these regress, stop and tell me which.

---

## B. Visual smoke (open Godot editor, F5)

The project's main scene is `scenes/ui/title_screen.tscn`.

1. **Title screen renders.**
   - Aphelion-themed circular game icon at top (ticket **0.9**).
   - "The Sleeping Vein" header in cream gold.
   - Subtitle: `AETHERDEEP — The Sunken Aeon`.
   - Five buttons: Start (Single Player), Host Multiplayer, Host IP textbox,
     Join Host, **Settings**, Quit.
   - Text uses the new **8×8 BMFont** (ticket **0.7**) — pixel-crisp, monospaced.
     If text looks anti-aliased / smooth, the font binding broke.

2. **Settings opens from the title** (tickets **0.12 + 0.13 + 0.14**).
   - Click `Settings`. Panel appears with three tabs: Display | Audio | Controls.
   - Display: Window Mode dropdown (Windowed / Fullscreen / Borderless),
     Resolution dropdown (5 options), V-Sync checkbox.
   - Audio: 4 rows (Master / Music / SFX / Ambient) — each is a label + slider + `%` readout.
   - Controls: scrollable list of 20 actions (move, attack, hotbar 1–10, etc.).
     Each row has a button labeled with the current key. Click a button →
     it changes to "press any key…" → press a key → it rebinds and updates.
   - "Reset Defaults" restores everything (audio levels, window mode, keys).
   - "Close" hides the panel; ESC also closes it.
   - Any setting change persists: close + relaunch the project, settings should
     stick (saved to `user://settings.json`).
   - Tab content fills the panel area (Audio rows visible, Controls list fills with
     a vertical scrollbar when the action list overflows).

3. **Start (Single Player)** loads `scenes/world/main.tscn` without errors.
   - Anchor area visible: Resonance Loom (centered, 48×48), Loam Bench
     (right of Loom), Chest (left of Loom). All three sprites are the
     finalized placeholders.
   - Player walker sprite is a small standing figure (placeholder — only the
     `_idle_down_frame0` PNG exists; full 40-frame sheet is still `needed`).
   - **WASD** moves the player. **Mouse-1** swings — you should see a
     short cream-yellow arc-shaped flash on the side the cursor is on
     (`SwingArc` VFX, 180ms). The arc fires whether or not the swing connects.
     **E** interacts; **I** opens inventory; **M** toggles a centered fullscreen
     map (zooms 2× into the corner minimap, dims the rest of the screen).
     Press M again to collapse back to the corner widget.

4. **Pause menu** (ticket **0.11**).
   - Press ESC mid-game. Pause panel appears.
   - Six buttons: Resume, Save, Load, **Settings**, Quit to Title, Quit Game.
   - Save → status reads `Saved.`. Load → `Loaded.`.
   - Settings → opens the same panel as on the title screen.

5. **Pixel-perfect rendering** (ticket **0.8**).
   - Move slowly. Sprites should NOT shimmer/blur. Walls should align cleanly
     to the 16-pixel grid. If you see sub-pixel shimmer, the camera lost
     `position_smoothing_enabled = false` somewhere.

---

## C. Tooling (run from repo root)

6. **Palette checker** (ticket **0.5**).
   ```sh
   python tools/check_palette.py --list-palette
   python tools/check_palette.py assets/sprites/structures/loam_bench.png --tolerance 64
   python tools/check_palette.py assets/sprites/structures/chest.png --tolerance 0
   ```
   - First prints the 9 biome ramps + universal colors.
   - Loam bench at tolerance=64 prints `OK ... palette-clean`.
   - Chest at tolerance=0 prints a `FAIL ... 100.0%` (this is the known
     palette-drift finding; saved to memory).

7. **Palette snapper** (companion, ticket 0.5b — my pick).
   ```sh
   python tools/snap_to_palette.py assets/sprites/structures/chest.png --suffix _snapped --report
   ```
   - Should write `assets/sprites/structures/chest_snapped.png` and print a
     remap table. Open the snapped image — colors are quantized to the biome
     ramps; outline preserved.

8. **Batch generator dry-run** (ticket **0.10**).
   ```sh
   python tools/batch_generate.py --dry-run
   python tools/batch_generate.py --dry-run --phase 1
   ```
   - First lists every `needed` manifest entry. Second filters to Phase 1 tickets
     only. (Live mode requires the Godot editor open with the AI image-generator
     plugin's REST endpoint enabled; not part of this checklist.)

9. **Pre-commit hook** (ticket **0.19**).
   ```sh
   git config core.hooksPath tools/git-hooks
   # introduce a syntax error in any .gd file, stage it, commit:
   git add scripts/autoloads/game_state.gd
   git commit -m "test"
   # restore: git restore --staged scripts/autoloads/game_state.gd ; git checkout -- scripts/autoloads/game_state.gd
   ```
   - With the hook installed, an intentionally broken `.gd` blocks the commit
     with a parse-error message. Removing the syntax error lets the commit go through.

10. **Build pipeline** (ticket **0.16**, previously closed).
    ```sh
    pwsh tools/export.ps1 win
    ```
    - Requires Godot export templates installed and a `Windows Desktop` preset
      defined in the project. Will likely complain if presets aren't created
      yet — that's expected; report what it actually says.

---

## D. CI (no local steps; verify after first `git push`)

11. **GitHub Actions GUT runner** (ticket **0.15**).
    - First push to `main` (or `master`) triggers `.github/workflows/test.yml`.
    - Action downloads Godot 4.6.2 headless, runs `--import`, runs GUT.
    - Action page at `https://github.com/<you>/the-sleeping-vein/actions`
      should show `tests` green. If it fails on download URL, the pinned
      Godot version may have moved — bump `GODOT_VERSION` in the workflow.

---

## E. Infrastructure files (visual / textual review only)

12. **CHANGELOG, version, templates** (tickets **0.17 + 0.20**).
    - `CHANGELOG.md` describes the unreleased Phase 0 close-out.
    - `GameState.VERSION` constant is `"0.1.0-dev"`.
    - `.editorconfig` exists at repo root.
    - `.github/PULL_REQUEST_TEMPLATE.md` and
      `.github/ISSUE_TEMPLATE/bug_report.md` + `feature_request.md` exist.

13. **i18n string table** (ticket **0.18**).
    - `assets/i18n/en.json` exists with seeded keys (title.*, pause.*, settings.*, etc.).
    - From any GDScript: `I18n.t("pause.saved")` should return `"Saved."`.
    - To add a new locale (e.g. Vesari per lore §10): drop
      `assets/i18n/vesari.json` with the same keys and call `I18n.set_locale("vesari")`.

---

## How to report results

Walk the checklist top to bottom. For anything that fails:
- Quote the section number (e.g. `B.2 Settings panel`).
- Paste the visible error / screenshot if there is one.
- Note your Godot version (`godot --version`).

I'll update kanban entries from `done` back to `ready` for whatever needs fixing.
