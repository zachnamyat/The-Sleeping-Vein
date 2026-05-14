# Phase 3 — Manual Test Checklist

Phase 3 goal (per ROADMAP §3): A real inventory and the first crafting tree branch.

Phase 3 exit criterion (verbatim):
> Open inventory. Craft a Wood Pickaxe. Place it in hotbar. Mine 3× faster. Stash
> extra in a chest. Reload save — chest contents persist.

Walk this top-to-bottom and tell me what fails. Section letters group by
verification gate; numbered subsections cite the ticket id in **bold**.

Pre-reqs:
- Phase 0, Phase 1, Phase 2 checklists passed.
- Godot 4.6.x on PATH (`godot --version` returns 4.6.*).

---

## A. Headless smoke (must pass before anything else)

```sh
godot --headless --path . --quit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected:
- The `--quit` call exits cleanly. Engine line + RID-leak teardown noise is OK;
  any GDScript backtrace is not.
- GUT prints **57/57 passing** (Phase 2 had 34; Phase 3 closure added
  test_crafting, test_equipment, test_chest, test_inventory_phase3 for 23 new
  tests; the extended-closure pass added 4 more — lock toggle, auto-equip,
  recency sort, and split confirmation).

If either fails, fix before continuing — UI tests below depend on the world loading.

---

## B. Inventory grid + drag-drop + tooltip (3.1 / 3.2 / 3.3)

1. **3.1** — Launch the game (`godot --path .`). Press `I` or `Tab`. The
   Walker's Pouch panel opens with a **3 row × 10 column grid** of 20-pixel
   slots. Starter items (wooden pickaxe, sword, axe, bombs, torches, loam) are
   visible in the hotbar row.
2. **3.2** — Click and drag the wooden pickaxe to slot 9 (rightmost hotbar
   slot). It swaps with whatever was there. Drag it back. The cursor preview
   shows a half-opacity 16×16 icon.
3. **3.3** — Hover the wooden sword. Tooltip appears within 0–1s (delay
   honored from Settings). Tooltip shows the name in **rarity color** (white for
   common), description, "Damage: 6", and "Reach: 16 px".
4. **3.50** — Right-click the loam stack in your inventory. The stack drops 1
   loam onto the ground in front of the Walker; the icon falls slightly with a
   pop animation, then waits ~0.6s before the player can pick it up.
5. **3.35** — Shift-drag a stack of loam to an empty slot. The stack splits
   roughly in half. Shift-drag a partial onto another loam stack — the two
   merge up to max_stack.
6. **3.60** — Type "loam" in the search box at the top of the inventory.
   Matching slots stay full opacity; misses dim. Clear with the × button.

## C. Sort, Quick Stack, Loot All, Trash (3.13 / 3.14 / 3.25 / 3.26 / 3.45)

7. **3.26 / 3.45** — Click "Sort R" while several items occupy storage rows.
   Items reorder by rarity (high to low). Hotbar row is **not** reshuffled.
   Click "Sort A" — alphabetical. Click "Type" — groups by material/tool/weapon.
8. **3.13** — Walk to the pre-placed anchor chest (west of spawn). Open the
   inventory and click "Quick Stack". Any item types already in the chest get
   deposited from your inventory (starter slots excluded). Toast confirms count
   moved.
9. **3.14** — Drop a few items by right-clicking them in inventory. Walk
   nearby (within 64 px). Click "Loot All" — all dropped items magnet into the
   Walker. Toast shows count picked up.
10. **3.25** — Drag a stack onto the **red X** trash slot in the bottom-right
    of the inventory panel. Stacks > 2 trigger a delete-confirmation toast (no
    modal yet — Phase 15 polish).

## D. Equipment slots panel (3.4)

11. **3.4** — A "Worn" subpanel sits to the right of the inventory grid with 11
    slots in a humanoid silhouette (helm top, off_hand/chest/ring_1 mid, bracelet/
    legs/ring_2 below, belt/boots/pet bottom).
12. Stand next to the loam bench (east of spawn) and press `E`. Craft a
    shaleseed helmet… you can't yet without shaleseed ore. Use the dev console
    in-game or place a fresh save with `Inventory.try_add("shaleseed_helmet", 1)`.
    Once it's in your inventory, drag it onto the **helmet** slot — it equips.
13. Try to drag the shaleseed_helmet onto the boots slot — **rejected**, slot
    only accepts head-typed items.
14. Right-click the equipped helmet — it returns to the first free inventory
    slot.

## E. Hotbar selection + held-item visual (3.5 / 2.36)

15. **3.5** — Press `1` through `0`. The selected hotbar slot's gold border
    moves accordingly. Mouse-wheel up/down also cycles.
16. **2.36** — When you select a slot containing an item with an icon (e.g.
    wooden pickaxe, torch), a small floating sprite appears beside the Walker.
    Move left — the sprite flips and follows. Select an empty slot — the held
    visual disappears.

## F. Chest + persistence (3.6)

17. Walk to the anchor chest and press `E`. The Chest panel opens with a 3×6
    grid. Drag items in from your inventory — they deposit. L-click a chest slot
    to withdraw the full stack; R-click to withdraw one.
18. Drop 3 loam into the chest. Save the game from the pause menu. Close the
    game. Reopen. Load the save. Walk back to the chest. The 3 loam should
    still be there.
19. (Edge case) Run `SaveSystem.save_to_slot("test_slot")` from a debug shell,
    delete the chest entity (`get_tree().get_nodes_in_group("chest")[0].queue_free()`),
    then reload — the chest blob in the save is dropped (no matching
    `unique_id`), no crash.

## G. Workstations + recipes (3.7 / 3.8 / 3.9 / 3.10 / 3.11)

20. **3.7** — Walk to the loam bench (east of spawn). Press `E`. The Crafting
    panel opens titled "Station: Loam Bench". The recipe list shows: wooden
    pickaxe, wooden sword, torch, basic floor, basic wall, hoe, watering can,
    cooking pot, bow, arrows, healing potion, mana potion, clearstone forge
    (the placeable), respec scroll, fishing rod, ember/auroric chest pieces.
21. **3.8 / 3.10** — Verify each recipe has inputs/outputs by hovering. Most
    require `loam` x6 / `wood` x3 / etc.
22. With 6 loam in inventory, click **Craft** on Wooden Pickaxe — it consumes
    6 loam, gives 1 pickaxe, toast says "Crafted Wooden Pickaxe", and a small
    Crafting XP message appears in the HUD (Phase 2 toast pipeline).
23. **3.18** — Pick up enough loam for ~5 pickaxes. **Shift-click Craft** on
    the wooden pickaxe row. All 5 craft in one click. Toast says "Crafted
    Wooden Pickaxe x5".
24. **3.16** — Click the `.` star button next to a recipe — it flips to `*`.
    Toggle "Faves" — list shrinks to favorites. Toggle off.
25. **3.9** — Pick up your first shaleseed ore (mine it from the world). Open
    the loam bench — the shaleseed pickaxe/sword/helmet/chest recipes are now
    listed. Confirm by hovering — they require shaleseed + loam.
26. **3.11** — Craft a Clearstone Forge placeable. Drop it on the ground (use
    the placeable preview ghost — see section H below). Press `E` next to it.
    The Crafting panel reopens titled "Station: Clearstone Forge"; shaleseed
    tier-1 gear recipes are accessible.

## H. Crafting skill XP (3.12)

27. **3.12** — Open the talents/skills panel (Phase 7 UI; press `K`).
    Crafting starts at level 0. Craft 20 items. Crafting XP rises; on hitting
    the level threshold you see "Crafting -> Lv 1" toast and gain 1 talent
    point.

## I. Workbench preview + placement commit (2.48 + Phase 3 commit)

28. **2.48** — Select a stack of loam_floor or torches in your hotbar (they're
    Phase 3.10 placeables). A **half-opacity ghost-tile of the item icon**
    appears at the mouse cursor, snapped to the 16×16 grid. Move the mouse
    farther than 3 tiles away — the ghost tints red. Inside 3 tiles — green.
28b. **Place commit** — With a placeable selected (torch, glow_tube, loam_floor,
    loam_wall, loam_bench_placeable, clearstone_forge_placeable, furnace_placeable,
    sawmill_placeable, cooking_pot_placeable), **left-click** while the ghost
    is GREEN. The item spawns at the snapped grid cell, the held stack
    decrements by 1, and a `place_item` SFX cue plays. Click while the ghost
    is RED — toast says "Too far to place." and the click is rejected.
    - Workstations (loam_bench, clearstone_forge, furnace, sawmill, cooking_pot,
      chest) instantiate their full scene with collision + interaction shape.
    - Decorative placeables (torch, glow_tube) spawn as a sprite + PointLight2D
      at the placement spot — torches glow warm gold, glow_tubes cyan.
    - Tile placeables (loam_floor, loam_wall) currently spawn a flat sprite
      decoration; Phase 4 will commit them as TileMapLayer cells.

## J. Drag-to-equipment + slot-typed validation cross-check (3.4 again)

29. With a shaleseed_legs in your inventory, drag it onto the chest slot — it
    **rejects** (chest slot only accepts chestpieces). Drag it onto the legs
    slot — it equips. The armor value (4) contributes to your damage reduction
    (HealthComponent.armor reads Inventory.equipment, Phase 6 polish).

## K. Save round-trip (cross-cutting)

30. Save → quit → relaunch → load. Verify:
    - Hotbar selection index restored.
    - Inventory slots (incl. equipment) restored.
    - All chest contents (including ones the player placed) restored.
    - Crafting unlocked-recipes restored (any recipes you unlocked via
      first-pickup or item-crafted events stay unlocked).

---

## L. Extended-closure features (2026-05-13 Phase 3 second pass)

These cover the 20 parity-audit tickets shipped after the initial Phase 3
closure migration. They build on the same world; no special setup needed.

### L1. Slot lock + recency sort + auto-equip (3.43 / 3.66 / 3.33)

31. **3.43** — Hover any inventory slot containing an item. **Middle-click**.
    The slot border turns gold and gets thicker. Try to drag the locked stack
    elsewhere — `Inventory.swap` refuses. Try to drop it via right-click — drop
    refuses. Try the Sort R / Sort A / Sort Type / Recent buttons — the locked
    slot stays put while everything else reflows. Middle-click again to
    unlock.
32. **3.66** — Pick up several items in a known order: loam first, shaleseed
    second, heartwood last. Click **Recent** in the inventory panel. The newest
    pickup (heartwood) lands in the first storage row, then shaleseed, then
    loam. Hotbar untouched.
33. **3.33** — With a shaleseed_helmet/chest/legs/boots in your inventory and
    nothing equipped, click **Auto-Equip** (button at bottom-left of inventory).
    Toast says "Equipped 4 pieces." Open the equipment panel — all four shaleseed
    slots populated. If you already had a higher-armor helm equipped, that
    slot is **not** downgraded.

### L2. Auto-deposit + last-used container (3.15)

34. **3.15** — Open the anchor chest. Drop 3 loam in. Close the chest. Walk
    to a different chest (place a second one if needed by crafting it from the
    Loam Bench... or skip if there's only one). Open inventory → Quick Stack.
    The deposit prefers the **most recently opened** chest if it's still in
    range, falling back to the nearest. Toast confirms which container received
    the deposit.

### L3. Crafting queue + cancel (3.19 / 3.42)

35. **3.19** — Stand at the Loam Bench. Pick up 30+ loam. **Ctrl-click** the
    Wooden Pickaxe Craft button. Toast: "Queued 5x Wooden Pickaxe". A "Queue:"
    strip appears at the top of the recipe list with `Wooden Pickaxe x5 X`.
    Wait ~2 seconds — pickaxes drain into your inventory one per ~0.4 s.
36. **3.42** — While 3 are still queued, click the queue chip (the
    `Wooden Pickaxe x3 X` button). Toast: "Removed from queue." Remaining
    crafts stop immediately. No materials were reserved up front, so nothing
    refunds.

### L4. Workstation adjacency (3.32) + new stations (3.28 / 3.30 / 3.57)

37. **3.30** — At the Loam Bench, craft a **Sawmill** (8 wood). Drop it next
    to the bench (within 48 px). Press `E` on the Sawmill — the panel title
    reads "Stations: Sawmill (+1 nearby)". The recipe list now includes
    **both** the Sawmill's plank-cutting recipe and all loam_bench recipes.
38. **3.28** — Craft a **Furnace** (12 loam + 4 wood) at the Loam Bench. Place
    it adjacent. Walking up to the Furnace shows "Stations: Furnace (+2 nearby)"
    and the menu now adds shaleseed_ingot and bottle_empty (auto-unlocked on
    Furnace placement). Smelt 4 shaleseed → 2 ingots.
39. **3.57** — At the Clearstone Forge, craft a **Resonance Coupler**
    (3 ingots + 1 aphelion_fragment). Item appears in inventory. Future ticket:
    consume on a station to bump its tier (placement system Phase 4).

### L5. Equipped-comparison + set-bonus tooltip (3.17 / 3.61)

40. **3.17** — Equip a shaleseed_chest (armor 5). Hover an unequipped piece
    that goes in the same slot (e.g. `ember_iron_chestpiece` if you can spawn
    one with `Inventory.try_add(&"ember_iron_chestpiece", 1)`). The tooltip
    appends a line: `vs equipped: +13 armor`.
41. **3.61** — Hover any shaleseed armor piece (helm/chest/legs/boots). The
    tooltip shows: `Set: Shaleseed (n/4)` and the 2pc / 4pc bonus rules
    (mining speed / loot drops). Equip 2 pieces — the (2) bonus row shows
    active count. Equip 4 — both bonus rows.

### L6. Two-handed weapon rule (3.46)

42. **3.46** — Hover a Wooden Bow in your inventory. Tooltip ends with
    `Two-handed (locks off-hand)`. (Actual off-hand auto-clear when equipped
    is Phase 6 combat-depth scope; the field + tooltip cue ship now.)

### L7. Hotbar swap-sets (3.51)

43. **3.51** — Arrange your hotbar however you like. **Shift+Q** — toast:
    "Hotbar layout saved." Move all your hotbar items somewhere else
    (different items in different slots). Press **Q** alone — toast: "Swapped
    hotbar layouts." The original arrangement is restored, and pressing Q
    again swaps back.

### L8. Discard ConfirmationDialog (3.53)

44. **3.53** — Drop a stack of 5+ loam onto the trash slot (red X bottom-
    right). A modal pops up: "Discard 5 Loam?" with **Discard** / **Keep**
    buttons. Click Keep — nothing happens. Drag again, click Discard — toast
    confirms, stack vanishes.

### L9. Double-click compare-and-replace (3.44)

45. **3.44** — With nothing in the helmet slot, double-click a shaleseed_helmet
    in your inventory. It instantly equips. Pull a second helmet into
    inventory and double-click — the second one swaps in, the first returns
    to inventory.

### L10. Craft-complete SFX (3.71)

46. **3.71** — Each successful craft fires a `craft_complete` SFX cue
    (procedurally generated until real audio is authored). Multi-craft (Shift)
    plays a single cue regardless of count, queue ticks each play one cue per
    iter.

### L11. Items-as-reagents (3.85 / 3.86 / 3.58)

47. **3.85** — `aphelion_fragment` exists as an ItemDef with rarity 3 (purple)
    and a lore_text excerpt visible in the tooltip. Required reagent for the
    Resonance Coupler recipe.
48. **3.86** — Craft a Glow Tube (1 torch + 1 bottle, at the Loam Bench). The
    item is a placeable; the placement preview ghost-tile (Phase 2.48)
    confirms it.
49. **3.58** — `bottle_empty` is craftable at the Furnace from 1 shaleseed
    (yields 2 bottles). Stackable up to 50.

### L12. Hover order + hint label

50. The bottom of the inventory panel shows the hint:
    `Shift+drag=split  Right-click=drop  I/Tab=close`. Verify that all four
    listed gestures still work after the extended-closure pass touched the
    slot UI.

---

## What's deferred

After the extended-closure pass, **zero Phase 3 backlog tickets remain in the
kanban**. Out-of-scope work that originally lived as Phase 3 tickets has been
reassigned to its natural phase via the `seedTickets.phase` field:

- **Phase 4** (procedural world): 3.41 place-multiple drag-tool, 3.73
  crystal-cluster resource.
- **Phase 5** (first boss + lore tablets): 3.40 recipe-scroll drops, 3.70
  boss-unique trinket drops, 3.72 recipe-scroll chest drops.
- **Phase 6** (combat depth): 3.47 dual-wield, 3.54 multi-shot affix, 3.55
  pierce affix, 3.75–3.80 new weapon classes (throwing axe, rapier, greatsword,
  heavy crossbow, wand, tome), 3.81 reload anim, 3.82 auto-reload.
- **Phase 7** (talents): 3.20 set-bonus system, 3.29 anvil station, 3.83 luck
  stat.
- **Phase 8** (life-sim): 3.31 tannery.
- **Phase 9** (NPCs): 3.27 bag-in-bag UX (Mira merchant clerk).
- **Phase 13** (multiplayer): 3.39 soulbound items.
- **Phase 14** (automation): 3.34 bucket, 3.35 place liquid as tile.
- **Phase 15** (polish): 3.36 dyeing, 3.37 wardrobe, 3.62–3.65 worn visuals
  (helmet/cape/off-hand/backpack), 3.68 cosmetic hat, 3.69 pet collar.
- **Phase 16** (extensions): 3.21–3.24 affixes/reforge/salvage/enchant, 3.38
  star-rating, 3.56 stat re-roll, 3.74 tool durability.

Duplicate-closed (already shipped under different ticket ids): 3.48 trinket
slot (covered by necklace/ring_1/ring_2/bracelet), 3.49 belt slot (already in
EQUIPMENT_SLOTS), 3.84 reach in tooltip (shipped in initial closure).

The 12 main-path tickets (3.1–3.12), 14 quality-of-life extras (2.36, 2.48,
3.13, 3.14, 3.16, 3.18, 3.25, 3.26, 3.45, 3.50, 3.52, 3.59, 3.60, 3.67), and
20 extended-closure features (3.15, 3.17, 3.19, 3.28, 3.30, 3.32, 3.33, 3.42,
3.43, 3.44, 3.46, 3.51, 3.53, 3.57, 3.58, 3.61, 3.66, 3.71, 3.85, 3.86) plus
2.35 stack split are all shipped.
