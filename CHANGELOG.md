# Changelog

All notable changes to The Sleeping Vein will be recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Bump
`GameState.VERSION` whenever a release is cut.

## [Unreleased]

### Added
- Phase 0 close-out: `.editorconfig`, GitHub PR + issue templates, CHANGELOG, version
  constant, i18n string-table scaffold, GitHub Actions GUT runner, pre-commit GDScript
  syntax hook, `tools/snap_to_palette.py` and `tools/batch_generate.py`, settings panel
  (display / audio / controls) wired into pause menu + title screen, default 8×8 pixel
  font dropped into theme.
- `tools/check_palette.py` Manhattan-tolerance palette conformance checker (ticket 0.5).
- 5 finalized sprites: smoke_test_shaleseed, ui_game_icon, structure_chest, structure_bed,
  structure_loam_bench (manifest catch-up to kanban migrations).

### Changed
- Manifest: `structure_workbenches_set` no longer covers `loam_bench` (split into its own
  entry). 6 of 76 manifest assets are now `final`.

## [0.0.1] — Project skeleton

Initial scaffolding, Phase 0–14 stubs, lore canon (11 lore/*.md files), kanban (~870
seed tickets), AAP-64 + 9-biome-ramp palette.
