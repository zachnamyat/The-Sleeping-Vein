# Modding SDK — The Sleeping Vein

> Ticket 14.44 — Modding SDK docs + sample mod scaffold.
> Companion to the in-game Mod Manager Panel (ticket 14.31) and the
> `ModSystem` autoload at `scripts/systems/mod_system.gd`.

## Goals

1. Drop a mod folder into `user://mods/<your_mod_id>/` and have the game pick
   it up at next launch.
2. Override or extend existing items, recipes, mobs, and biomes without
   recompiling anything.
3. Conflicts are detected at load time and surfaced in the manager UI; you
   never have to dig through logs.
4. Hot-reload of data resources in dev mode so you can iterate without
   restarting the game.

## Folder layout

```
user://mods/<mod_id>/
├── manifest.json
├── items/          # ItemDef .tres
├── recipes/        # Recipe .tres
├── mobs/           # MobDef .tres
├── biomes/         # Biome .tres
└── (scenes/)       # Optional .tscn overrides — rare; flagged as conflicts.
```

## manifest.json

```jsonc
{
  "id": "my_mod_id",
  "version": "0.2.0",
  "author": "you",
  "requires_game_version": "0.1.0",
  "conflicts": ["another_mod"],
  "load_after": ["base_mod"],
  "description": "Adds three new Emberforge weapons and rebalances melee crits."
}
```

* `id` is the folder name and the immutable identifier. snake_case only.
* `version` is the mod's own semver.
* `requires_game_version` uses major.minor semantics: a mod marked
  `"0.1.0"` works on any `0.1.x` build with minor ≥ 0.
* `conflicts` lists mod ids that are known-incompatible. The manager will
  warn but not auto-disable.
* `load_after` lists mods that must be loaded before this one. Used by the
  conflict resolver in `ModSystem._detect_conflicts`.

## Override semantics

When two mods both define an ItemDef with the same `id`, the **later** entry
in load_order wins. ItemRegistry's `register(def)` stores the new instance
in its `_defs` dictionary; subsequent `get_def(id)` calls return the modded
def. The same applies to recipes via `CraftingSystem.register(recipe)`.

ModSystem records every override as a conflict entry keyed by
`"<kind>.<id>"`. The manager UI lists each conflicting mod pair so the
player can decide whether to accept or disable one of the mods.

## Sample-mod scaffold

`ModSystem.generate_sample_mod(target_path)` writes a starter mod (manifest
+ one example ItemDef) to the chosen path. From the in-game dev console:

```
mods.generate user://mods/my_first_mod
```

This creates:

```
my_first_mod/
├── manifest.json     (id: example_mod, version 0.1.0)
└── items/
    └── example_modded_item.tres
```

Edit, reload, and you're done.

## API surface

All mod-facing API lives on the `ModSystem` autoload:

| Method | What it does |
| --- | --- |
| `scan_mods() -> int` | Re-scan `user://mods/` for new mod folders. |
| `enable_mod(id) -> bool` | Mark a mod as enabled for the next load. |
| `disable_mod(id) -> bool` | Mark a mod as disabled. |
| `load_enabled_mods() -> int` | Load every enabled mod in `load_order`. |
| `unload_mods()` | Tear down the current set (best-effort). |
| `set_load_order(ids)` | Pass an `Array[StringName]` in desired order. |
| `hot_reload() -> int` | Dev-only: force-reload every previously-loaded .tres. |
| `generate_sample_mod(path) -> bool` | Write a starter scaffold. |
| `fetch_remote_listings(term)` | Mod browser stub (ticket 14.43). |
| `is_loaded(id) -> bool` | True if this mod is currently active. |
| `conflict_keys() -> Array` | Conflict keys recorded on the last load. |

Mods can subscribe to these signals:

* `mod_discovered(id, manifest)` — fired during `scan_mods`.
* `mod_loaded(id, version)` — fired once per successful load.
* `mod_unloaded(id)` — fired on `unload_mods`.
* `mod_conflict(a, b, key)` — fired during conflict detection.
* `mod_version_mismatch(id, required, actual)` — semver mismatch.
* `mods_hot_reloaded(count)` — dev-only hot-reload signal.

## Compatibility version tags (ticket 14.34)

A mod's `requires_game_version` is parsed at load time:

```gdscript
ModSystem._is_version_compatible("0.1.0", "0.2.5")  # → true (same major, newer minor)
ModSystem._is_version_compatible("0.3.0", "0.2.5")  # → false (older minor than required)
ModSystem._is_version_compatible("1.0.0", "0.9.0")  # → false (different major)
```

A mismatch emits `mod_version_mismatch` and the mod is skipped for the
session.

## Hot reload (ticket 14.35)

In dev mode (`DevConsole` enabled), running `mods.reload` calls
`ModSystem.hot_reload()`. Every previously-loaded `.tres` is re-read via
`ResourceLoader.CACHE_MODE_REPLACE`, so newly-saved edits land instantly.
Items already in inventory keep their old `ItemDef` reference until next
pickup; recipes update immediately.

## Mod-browser scaffold (ticket 14.43)

`ModSystem.fetch_remote_listings(term)` is a stub for the eventual mod.io
integration. For now it emits one synthetic listing (`remote_demo_pack`)
through `mod_browser_listing_received`. The data model is real; the network
layer lands in Phase 16+ once the user has a real account flow in place.

## Multiplayer note (Phase 13 cross-cut)

Mods are LOAD-time only — they bake into the world's content tables before
the first frame. In a multiplayer session every peer must load the same
mod set in the same order. The lobby UI's ready-check (ticket 13.52) does
NOT yet enforce mod-list parity; that's tracked under Phase 14.31 as a
follow-up to the manager UI.
