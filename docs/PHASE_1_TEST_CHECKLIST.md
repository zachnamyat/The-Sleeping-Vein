# Phase 1 — Manual Test Checklist

Phase 1 goal (per ROADMAP §1): A player capsule walks around a 1-biome tiled
world, with Y-sort'd walls and pixel-perfect camera.

Phase 1 exit criterion (verbatim):
> Stand in the Root Hollows. Walk in 8 directions. Wall behind player overlaps
> correctly. Camera doesn't blur. Aphelion Beat cycles. Test scene saves and loads.

Walk this top-to-bottom and tell me what fails. Section letters group by
verification gate; numbered subsections cite the ticket id in **bold**.

Pre-reqs:
- Phase 0 checklist passed (Settings, Title screen, Pause menu, GUT 21/21).
- Godot 4.6.x on PATH or `~/bin/godot[.exe]`.

---

## A. Headless smoke (must pass before anything else)

```sh
godot --headless --path . --quit-after 200
godot --headless --path . res://scenes/world/main.tscn --quit-after 200
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected:
- Both `--quit-after` calls print only the engine line + RID-leak teardown noise.
  No GDScript backtraces.
- GUT prints `21/21 passing`.

If GUT regresses, stop and tell me which test.

---

## B. Open the editor, F5 → New Game (lands in `scenes/world/main.tscn`)

### 1. Spawn + world generation (**1.1, 1.5, 1.6, 4.x**)
- Player walker appears at world origin, on a clear plateau (no walls within
  ~6 tiles). Plateau holds the Resonance Loom (centered), Loam Bench (right),
  Chest (left).
- Around the plateau, the procedural Root Hollows biome paints: brown/loam
  floor tiles + scattered capped walls + occasional shaleseed ore tiles.
- Stone-Hopper mobs may roam in nearby chunks.
- **Camera** centers on the player at zoom=2 with `position_smoothing_enabled=false`.
  Walk slowly — sprites should not shimmer or sub-pixel blur.

### 2. 8-directional movement + Running skill (**1.2**)
- WASD moves the player in 8 directions (N, NE, E, SE, S, SW, W, NW). No
  diagonal-faster bug (vector should be normalized).
- Hold-Shift sprint variant (or whatever the Running stub maps to) — speed
  should change perceptibly. See `scripts/player/player_controller.gd` for
  the actual binding if unclear.
- Wall tiles block the player; no clipping into solid tiles.

### 3. Health + Mana bars (**1.3**)
- HUD shows two horizontal bars (top-left or wherever the HUD instance puts
  them). Health bar at max (100). Mana bar at max (100) with slow regen
  (+2/sec via ManaComponent default).
- Take damage from a Stone-Hopper — health bar drops, hurtbox i-frame flicker
  briefly suppresses chain hits (0.4s default).

### 4. Day/Night cycle hooked to Aphelion Beat (**1.7**)
- World tint starts at the warm-dusk `phase_color_high = (0.78, 0.72, 0.58)`.
- Every **23s**, the `CanvasModulate` tweens to the next phase (2s tween):
  high_light → falling → low_light → rising → repeat.
- `low_light` is genuinely dark (0.28, 0.25, 0.20) — the world should read as
  a deep cave at that point.

### 5. Ambient light + Player torch (**1.8**) — **new this phase**
- A soft warm halo follows the player (~4 tiles radius). Color is yellow-orange,
  feathered edges.
- During `low_light` phase, the torch is the dominant light source. Walking
  away from the Loom into untextured darkness, only the torch illuminates
  the ground around you.
- The torch is built procedurally with a `GradientTexture2D` — no asset import
  needed. If the halo is missing entirely, the `PointLight2D` node "Torch"
  under `Player` did not import.

### 6. Aphelion Beat audio cue (**1.10**) — **new this phase**
- Every 23s when the day-night phase advances, you should hear a brief low
  tone (~0.5s, ~110Hz fundamental). Procedural placeholder built via
  `AudioStreamWAV` in `scripts/autoloads/audio_bus.gd`. Synced exactly with
  the phase tween.
- If silent: check OS volume + the Settings → Audio Master slider isn't at 0.
  The tone uses the default audio bus; not yet routed through SFX/Music buses.

### 7. Hotbar UI (**1.11**)
- Bottom-center: 10 dark slots with bronze borders. Slot 1 (leftmost) is
  highlighted with a brighter border (`selected_index = 0`).
- Slots 1–4 should already show icons from the starter inventory grant
  (wooden pickaxe, wooden sword, torch ×5, loam ×20 — see
  `world_bootstrap.gd:_grant_starting_inventory`). Stacks > 1 show count.
- **Press `1` … `9` and `0`** — selection highlight moves. Slot 10 is the `0` key.
- **Scroll wheel up/down** — selection cycles with wraparound.
- The small number badge in each slot's top-left labels the slot key (1..9, 0).

### 8. Y-sort cap occlusion (**1.5** — the "wall behind player" criterion)
- Walk **north** so a capped wall is between the camera and the player. The
  wall's top "cap" tile should draw OVER the player's head, hiding the player's
  upper body briefly.
- Walk **south** of that same wall. Player should draw over the wall.
- If the cap never occludes the player, `WallCap` Y-sort layering broke or the
  wall sprite is 16×16 instead of the expected 16×24.

### 9. Death + respawn (**1.4**)
- Let a Stone-Hopper (or fall into a hazard if any) kill the player.
- Screen fades / death sequence plays.
- Respawn occurs at the Resonance Loom (origin).
- The Aphelion-sliver counter (HUD readout, ticket 2.13 scaffolding) decrements
  by 1. The hardcoded starting value lives in `GameState`; verify it ticks.

---

## C. Save/load round-trip (exit-criterion item)

10. Pause (ESC) → **Save**. HUD shows `Saved.`.
11. Quit to Title → New Game / Continue.
12. Pause → **Load**. World restores: player position, inventory, sliver count,
    Aphelion-Beat phase index.
13. JSON files exist at `user://saves/<slot>/meta.json` + `state.json`.

If reload spawns you at origin with a fresh inventory, the save round-trip is
broken.

---

## D. Gemini-driven assets — shipped 2026-05-13

All three Phase 1 Gemini assets generated via the `mcp__gemini-image__generate_image`
MCP, downsampled with `tools/process_phase1_assets.py`, palette-snapped via
`tools/snap_to_palette.py`, and flipped to `status: "final"` in the manifest.

| Ticket | Asset | Status |
|--------|-------|--------|
| **1.5** placeholder atlas | `assets/sprites/tiles/root_hollows_floor_wall.png` (32×48; 3 floor + 3 wall tiles) | final |
| **1.9** hand-of-light glow VFX | `assets/sprites/vfx/hand_of_light.png` (48×8, 6 frames); SpriteFrames wrapper at `resources/sprites/vfx_hand_of_light.tres` (idle_glow, 12fps, looping) | final |
| **1.12** Root Hollows atlas | `assets/sprites/tiles/root_hollows_atlas_16.png` (256×256, 16×16-cell grid) | final |

**To verify:** open the three files in any image viewer or in the Godot editor's
FileSystem dock. The atlas should read as a 16-row grid of warm-earth tile
variants. The floor/wall placeholder shows 3 stacked rows (floor / cap / wall
base). The hand-of-light is a 48×8 strip of six small gold orbs with magenta
keyed out.

These are Phase 1 placeholders — the prompts produced acceptable but not
polished pixel art (Gemini doesn't enforce strict pixel-grid alignment).
A future polish pass can regenerate any of them via the same pipeline.

---

## E. Phase 1 polish sweep (1.13 – 1.51) — implemented this session

All 39 enrichment tickets closed in migration `2026-05-13-phase1-polish`.
Walk these top-to-bottom; report failures with the section letter + ticket id.

### E.1 Combat feel
- **1.21 knockback** — Spawn a Stone-Hopper, let it hit you. You should slide
  back ~1 tile on impact. Bigger damage → bigger slide.
- **1.22 camera shake** — On any hit (you or mob), camera jitters briefly.
  Big hits (≥20 damage) shake harder + longer.
- **1.25 hit-pause** — Big hits cause a ~60ms time-freeze across the world
  before resuming. Subtle but readable.

### E.2 Audio callsites
- **1.24 footstep** — Walking emits a short tone every ~0.32s. Stops when idle.
- **1.42 button SFX** — Hover and click any button in title screen, pause,
  settings — each emits a distinct procedural tone (hover lower than click).
- **1.43 inventory SFX** — Press `I` to toggle inventory; panel-open and
  panel-close tones play.
- **1.44 page-flip SFX** — Open cookbook (`B`) or compendium (`J`) — page-flip
  tone plays on open.
- **1.48 title music** — Title screen plays a low procedural drone (two-voice
  detuned sine). Loops forever. Volume = `Master * -6 dB`.

### E.3 VFX
- **1.13 fog of war** — Chunks the player hasn't been near render dark gray
  overlay (alpha 0.78). Walks into them → they clear. Walks away → stay
  cleared (memory-only; no LOS yet).
- **1.26 pickup sparkle** — `PickupSparkle.spawn(pos, parent)` callable when
  rare items drop (Phase 2 wires the trigger; Phase 1 just ships the FX).
- **1.40 screen pulse** — Every 23s on Aphelion Beat, the screen briefly
  flashes warm-gold at 7% alpha. Synced with the beat audio cue (1.10).

### E.4 HUD additions
- **1.15 time-of-day label** — Top-right shows the current Aphelion phase
  name ("High Light", "Falling", "Low Light", "Rising"). Updates every 23s.
- **1.27 stamina bar** — Green bar below mana. Hold `Shift` while moving to
  sprint (1.5× speed); bar drains. Stops sprinting → bar regens after 0.5s delay.
- **1.29 regen-rate readout** — Small label `+N/s` mirrors player mana regen
  (until a Vitality-passive health regen ships).
- **1.32 HUD scale + opacity** — Settings → Game tab → drag sliders.
  HUD live-updates scale/opacity.
- **1.50 HUD show/hide** — Press `F1`. HUD vanishes. Press again — returns.

### E.5 UI screens
- **1.14 / 1.49 death screen** — Die. A black-overlaid panel reads
  "You Died", shows current sliver count, and offers Retry / Load / Quit-to-Title.
- **1.18 world creation** — From Title → Start (Single Player), the World
  Creation panel opens (after Character Creation). Form: name, seed, size
  (Small/Standard/Vast), difficulty (Casual/Standard/Hard/Hardcore).
  Click "Create + Wake" → main.tscn loads with chosen seed.
- **1.19 save-slot select** — Title → "Load Game" → lists save slots under
  `user://saves/`. Each row has Load + Delete. Slots show `vN · timestamp`.
  Empty state reads "(no saves yet)".
- **1.20 loading screen** — `LoadingScreen.show_with_tip()` / `update_progress()`
  / `hide_screen()` accessible from any script. Renders progress bar + a
  random tip from `FALLBACK_TIPS` (or `I18n.t("loading_tips")` if defined).
- **1.51 letterbox** — `EventBus.letterbox_requested.emit(true, 0.6)` slides
  black bars in from top and bottom over 0.6s. `false` slides them back out.

### E.6 Settings extensions
- **1.31 tooltip delay** — Settings → Game tab → "Tooltip Delay" dropdown
  (Instant / 0.5s / 1s). Hover an inventory item → tooltip appears after delay.
- **1.47 accent color** — Settings → Game tab → "Accent Color" → ColorPicker.
  Player hand-glow halo recolors live (visible behind torch).

### E.7 Misc functional
- **1.23 nameplate** — Label "Walker" above player sprite head. Visible in
  main.tscn. Replaces with character_name when 1.16 is used.
- **1.30 aim cursor** — Mouse cursor swaps to CURSOR_CROSS in-game (cleared
  back to ARROW on title-screen scene change).
- **1.33 animated title bg** — Title screen background ColorRect breathes
  between (0.03,0.02,0.02) and (0.07,0.05,0.04) over a ~14s sin cycle.
- **1.45 auto-pause on focus loss** — Alt-Tab away from the game → pause
  menu opens automatically.

### E.8 Sprite-dependent scaffolds (functional placeholders)
These ship as code-only scaffolds; visual fidelity arrives with the Walker
sprite rig.

- **1.16 character creation** — Title → Start → opens character panel.
  Fields: name, template (1 option), hair (3), skin (4), outfit (3),
  accent color. Confirm hands off to World Creation (1.18). Persists into
  GameState properties (character_name, character_hair, etc.).
- **1.34 sit on chair** — `PlayerController.try_sit()` toggles `is_sitting`
  state. While sitting, movement input is gated; sprite tints purple-grey as
  a placeholder for a future sit pose.
- **1.35 sleep in bed** — `PlayerController.try_sleep_in_bed()` triggers
  letterbox + sets `is_sleeping=true` for 1.5s. Real fade-to-black flow
  replaces this when the Bed interactable lands.
- **1.36 eat/drink animation** — `PlayerController.play_eat_animation()`
  bounces sprite scale 1.08/0.96/1.0 over 240ms. Hook from consumable use.
- **1.37 emote wheel** — Scene `EmoteWheel` at `UI/EmoteWheel`. 5-slot radial
  with text labels (Wave / Dance / Sit / Point / Sleep). `open()` / `close()`.
  Emits `emote_chosen(emote_id)`.
- **1.39 water splash** — `WaterSplash.spawn(pos, parent)` static method
  spawns a blue CPUParticles burst. Phase 10 wires the water-tile trigger.
- **1.41 blink/breath idle** — Player sprite modulate alpha bobs 1.0 ↔ 0.9
  on a 3.2s loop (no breath if no sprite). Real frames replace this.

---

## How to report results

Walk top-to-bottom. For each fail:
- Quote the section number (e.g. `B.5 torch halo missing`).
- Paste the visible error / screenshot if any.
- Note your Godot version (`godot --version`).

Phase 1 is **green** when sections **A**, **B.1–B.9**, and **C** all pass.
Items in section **D** can land later via the Gemini addon dock without
re-gating phase completion.
