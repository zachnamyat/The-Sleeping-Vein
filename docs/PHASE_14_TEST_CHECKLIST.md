# Phase 14 — Manual Test Checklist

> Companion to the automated 51-case GUT suite at `tests/unit/test_phase14_systems.gd`.
> Run through this list once before signing off the Phase 14 closure.
>
> Automated path: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` should report **396/396 passing**.

## 0. Setup

- [ ] Launch the project from `scenes/ui/title_screen.tscn`.
- [ ] Start a new world (or load a Phase 13 save — SaveSystem v11 should migrate to v12 on first save).
- [ ] Open the dev console (~) and run `i conveyor_placeable 50; i wire_placeable 50; i aphelion_tap_placeable 4; i power_storage_cell_placeable 2; i drill_placeable 4; i robotic_arm_placeable 4; i bucket_empty 4` to seed inventory for manual testing.

## 1. Power graph (14.4 / 14.13 / 14.14)

- [ ] Place an Aphelion-Tap → confirm a faint gold glow + four ring sprites.
- [ ] Place a Wire next to the tap → confirm dark grey colour.
- [ ] Place a Drill at the other end of the wire run, on the same `wire_group` → drill sprite shows.
- [ ] Wait for an Aphelion Beat → wires flicker to warm-gold, drill begins mining the adjacent tile.
- [ ] Place a second Drill on the same tap → after the next Beat the second drill also mines.
- [ ] Place six Drills on a single Tap (50W supply / 6×5W demand = 30W → still fine) → all mine.
- [ ] Place twelve Drills on the same Tap (60W demand > 50W) → some idle; wires tint **red** on overload.
- [ ] Place a Power Storage Cell on the same wire run → after a Beat of surplus, charge fraction > 0. Deactivate the tap (demolish + replace) → battery covers demand for a few Beats then runs out.

## 2. Wire + logic gates (14.5 / 14.7 / 14.36)

- [ ] Pressure Plate → Logic Gate AND with a Button → Door. Step on the plate AND press the button: door opens. Only one signal: door stays closed.
- [ ] Sensor (proximity) → Logic Gate NOT → Lamp. Walk near sensor: lamp goes dark. Walk away: lamp lights.
- [ ] Two Sensors → XOR → Trap. Both off: trap inert. Exactly one on: trap fires. Both on: trap inert.
- [ ] Signal Transmitter on freq 7 + Signal Receiver on freq 7 in another room → button on the transmit side fires the receiver across the wall.
- [ ] Signal Receiver on freq 13 + Transmitter on freq 7 → no response.

## 3. Timer block (14.15)

- [ ] Button → Timer Block (delay 3) → Door. Press the button: door stays closed for ~3 Aphelion Beats, then opens for one Beat, then closes.
- [ ] Hold the button (signal stays high): timer fires once per rising edge, not repeatedly.

## 4. Conveyors + splitter + merger + filter (14.1 / 14.11 / 14.16)

- [ ] Conveyor pointing right + drop an item on it → item slides right.
- [ ] Rotate a Conveyor 90° at placement (R key, if bound) → direction follows.
- [ ] Item Filter set to whitelist `shaleseed_ingot` on a Conveyor → only shaleseed_ingot slides; clearstone_ingot stops.
- [ ] Splitter mid-conveyor with two outputs → alternate items go to each side.
- [ ] Merger combines two conveyor streams into one output.

## 5. Hopper + storage piping + auto-furnace (14.8 / 14.10 / 14.18)

- [ ] Hopper above a chest → items dropped near it route into the chest.
- [ ] Storage Pipe between two chests + filter `shaleseed_ingot` → only shaleseed_ingot flows per Beat.
- [ ] Auto-Furnace input from chest A, output to chest B → drop `shaleseed` in A, wait, `shaleseed_ingot` appears in B.
- [ ] Auto-Smelter input from chest with ingots → plates appear in output chest.

## 6. Robotic arm (14.3)

- [ ] Robotic Arm with source-offset (-1, 0) and target-offset (1, 0) → every 2 Beats, one item moves from the left tile to the right tile.
- [ ] Cut power: arm stops.

## 7. Auto-cooking pot + auto-fishing rig (14.37 / 14.38)

- [ ] Auto Cooking Pot input chest holds bloat_oat → after 8 Beats one bloat_loaf appears in the output chest.
- [ ] Auto Fishing Rig with 5× `bait_basic` stocked → after 12 Beats a fish appears in the output chest; bait_basic count drops by 1.

## 8. Mob farm (14.19)

- [ ] Place Mob Farm Block at the center of a 4-tile kill-zone. Lure a Stone-Hopper into the zone and kill it. Loot drops at the block, not at the death position.
- [ ] Kill a mob outside the zone: drops remain at the death position.

## 9. Liquids + buckets (3.34 / 3.35 / 4.35 / 4.36 / 14.24)

- [ ] Empty Bucket near a water tile → secondary-click (RMB) fills it. Inventory entry becomes `bucket_full_water`.
- [ ] Full water bucket → RMB at cursor → water tile placed in front of the player. Bucket reverts to empty.
- [ ] Lava bucket: place a lava tile + adjacent water tile → tiles merge into `tile_stone_obsidian`.
- [ ] Acid bucket: place acid + water → `tile_acid_diluted`.
- [ ] Lava tile + mob walks in → mob takes 12 fire damage.

## 10. Painting + wallpaper + pattern stamp (14.21 / 14.23 / 14.41 / 14.42)

- [ ] Paint Brush + cursor on a floor tile → tile tints with a palette color. Iterate through the 8 colors with a hotkey.
- [ ] Pattern Stamp on a floor tile → 3×3 area paints with the chosen pattern (checker / stripes / diamond).
- [ ] Wallpaper Roll on a placed wall tile → wall texture swaps to the cream pattern (visual only).

## 11. Grid snap + rotation + demolition + blueprint (14.27 / 14.28 / 14.29 / 14.40)

- [ ] Place-Grid Toggle item → RMB toggles snap on/off. Conveyor placement aligns to / ignores the 16-grid.
- [ ] Demolition Mallet → swing at a placed Conveyor → it disappears; player gains 1× conveyor_placeable refund (50% of cost).
- [ ] Blueprint Tool → save the layout of a 4×4 cluster → paste the blueprint elsewhere → identical layout instantiates.

## 12. Auctioneer + mailbox economy (14.30)

- [ ] Place Auctioneer Node → press E → panel opens with Sell + Browse tabs.
- [ ] Sell tab: list 5× shaleseed_ingot for 12 coins. Listing appears in Browse tab on another peer's auctioneer.
- [ ] Browse tab: click Buy on the listing → coins debit, items credit to the buyer.

## 13. Glass + fence gate (14.25 / 14.26)

- [ ] Glass Block: mob projectiles cannot pass through; sight lines from sensors do.
- [ ] Fence Gate: closed → blocks pathing. Press E → opens; stays open 8s, then auto-closes.

## 14. Wireless relay + multiblock detection (14.20 / 14.22 / 14.36)

- [ ] Wireless Relay on freq 9 broadcasting to a relay on freq 9 across 200 tiles → button on side A triggers door on side B.
- [ ] Place 3+ different workstations within a 96-px radius → `Phase14Helpers.score_multiblock(pos)` returns ≥ 3 (visible in debug overlay).

## 15. Mod manager + SDK (14.31 / 14.32 / 14.33 / 14.34 / 14.35 / 14.43 / 14.44)

- [ ] Drop the bundled sample mod into `user://mods/example_mod/` (via `ModSystem.generate_sample_mod`).
- [ ] Open the Mod Manager panel → discovered mods list includes `example_mod`.
- [ ] Enable the mod, restart world: `ModSystem.is_loaded("example_mod")` returns true; `example_modded_item` appears in ItemRegistry.
- [ ] Drop a second mod that overrides the same item id → manager UI shows a conflict warning.
- [ ] Edit the mod's .tres on disk → run `ModSystem.hot_reload()` → the change applies live in dev mode.
- [ ] Set a mod manifest's `requires_game_version` to a future version → version-mismatch warning fires + mod skipped.
- [ ] Click "Browse mod.io" → at least one stub listing appears (`remote_demo_pack`).

## 16. Persistence (SaveSystem v11 → v12)

- [ ] Save the world. Confirm `state.json` contains `phase14_helpers` + `mod_system` blocks.
- [ ] Build an automation factory. Quit. Reload. Power graph, wire signals, tile paint, blueprints, conveyor filters, and active auctioneer listings survive.
- [ ] Load a Phase 13 v11 save → SaveSystem emits the version warning but loads cleanly. Add a Phase 14 placeable, save again → meta.save_version flips to 12.

## 17. Automated suite

- [ ] `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` reports **396/396 passing**, **0 failing**.
- [ ] `test_phase14_systems.gd` contributes 51 cases; sub-categories: power graph, wire graph, logic gates, timers, liquids, painting, grid snap, blueprints, conveyors, splitters, storage pipes, robotic arms, auto-cookers, auto-fishing rigs, mob farms, auctioneer, wireless, dump/restore, ModSystem, ItemDef/recipe loads, sprite loads, scene loads.

## Sign-off

Tester: ___________________________
Date: ___________________________
Notes: ___________________________
