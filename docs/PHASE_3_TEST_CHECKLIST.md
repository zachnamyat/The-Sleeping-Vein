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
- GUT prints **50/50 passing** (Phase 2 had 34; Phase 3 added test_crafting,
  test_equipment, test_chest, test_inventory_phase3 — 16 new tests).

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

## I. Workbench preview / placeable ghost-tile (2.48)

28. **2.48** — Select a stack of loam_floor or torches in your hotbar (they're
    Phase 3.10 placeables). A **half-opacity ghost-tile of the item icon**
    appears at the mouse cursor, snapped to the 16×16 grid. Move the mouse
    farther than 3 tiles away — the ghost tints red. Inside 3 tiles — green.
    (Actual placement commit comes Phase 4 — for now the ghost is purely
    visual.)

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

## What's deferred

These tickets are explicitly **out of scope** for Phase 3 and tracked for
later phases:
- 3.17 / 3.20 / 3.21–3.24 / 3.40 / 3.43 / 3.44 / 3.46–3.49 — affix system,
  set bonuses, reforging, recipe-scrolls, dual-wield, two-handed rule. Phase 6
  (Combat Depth) or Phase 7 (Talents) absorbs these.
- 3.27 / 3.34 / 3.35–3.39 / 3.61–3.86 — bag-in-bag, liquid containers, item
  dyeing, wardrobe, durability, new weapon classes. Phase 15 polish or Phase
  16 extensions.
- 3.51 — hotbar swap-sets. Tracked, low priority.

The 14 main-path tickets (3.1–3.12) and 14 high-value parity-audit extras
(2.36, 2.48, 3.13, 3.14, 3.16, 3.18, 3.25, 3.26, 3.35, 3.45, 3.50, 3.52,
3.59, 3.60, 3.67) are all shipped.
