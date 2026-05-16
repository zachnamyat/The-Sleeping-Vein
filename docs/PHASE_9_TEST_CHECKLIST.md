# Phase 9 — Manual Test Checklist

> Companion to `tests/unit/test_phase9_systems.gd` (23 GUT cases). This file
> covers the play-through and visual checks that can't be automated.

**Save format:** v7 (bumped from v6). Older saves load with empty
`npc_lifecycle` / `housing` blocks.

**Toggles to know:**
- `L` — open quest log (new `open_quest_log` action)
- Press `E` on a Bed to sleep (Phase 5.13 retained) — has a 25% chance to play a Dream Vision
- Click the **[ BUY ] / [ SELL ]** labels in MerchantPanel to swap tabs (9.3)

---

## 1. NPC arrival + housing (9.1, 9.2)

- [ ] Spawn a fresh world. Aelstren appears at the Anchor automatically.
- [ ] Place a Bed (item `bed_placeable`) inside a wide-open area with no walls. Expect toast "Bed placed but no NPC room yet (need walls + door)."
- [ ] Build an 8×8 walled room with a door + bed. On bed placement, Brindle moves in (priority 1).
- [ ] Build a second valid room → Mira moves in. Third → Cantor. Fourth → Old Hask.
- [ ] Verify each NPC's home_bed_pos points at the bed in their room (they wander back to it during the long-night phase).

## 2. Merchant UI tabs + restock (9.3, 9.10, 9.30, 9.57)

- [ ] Talk to Brindle → choose `(browse her wares)`. MerchantPanel opens.
- [ ] Click **[ SELL ]** label → switches to the player's sellable items.
- [ ] Click **[ BUY ]** → switches back.
- [ ] Title shows `Brindle Quench-of-Coals — Trade (restock in NNm)` and the countdown decreases on re-open.
- [ ] Wait > 30 in-game min (or rebind `restock_minutes = 0` in the .tres) → stock refills.
- [ ] Once mood ≥ 80, prices drop by ~10%; once mood ≤ 20, prices rise ~10%.
- [ ] Enter the `phase_long_night` (cycle a couple of daily resets) → Brindle's seasonal stock adds `combat_tonic`.

## 3. Ancient Coin currency (9.4)

- [ ] HUD shows `Coins: 0` in the top-right.
- [ ] Defeat Glaur-em → ~40–65 Ancient Coins drop alongside the usual relics.
- [ ] Open a treasure chest → 8–20 coins guaranteed (continued from Phase 4.23).
- [ ] Sell an item in MerchantPanel → coin count updates immediately.

## 4. The 5 merchants (9.5–9.9)

- [ ] **Brindle** — tools, weapons, anvil_placeable, repair service. Quest-conditional dialogue.
- [ ] **Mira** — bag_expansion_1/2, anchor_portable, treasure_map, world_scanner; offers identify service.
- [ ] **Cantor** — lantern → oil_lamp → ward_lantern + recipe_scroll; offers teleport service to the Anchor Loom.
- [ ] **Old Hask** — rod tiers + bait + canteen; gives a free fishhook gift after friendship 40 + dialogue path.
- [ ] **Veiled Buyer** — buy-only (no sell items). Variable-price jitter (re-rolls on each open).

## 5. NPC pathfinding (9.11, 9.20)

- [ ] Brindle wanders within a 12 px box of her shop_pos roughly every 6–8 s.
- [ ] Force `NpcLifecycle.seasonal_phase = &"phase_long_night"` in DevConsole → Brindle/Mira/Hask walk back to their bound bed.

## 6. Dialogue branches + mood + barks (9.12, 9.21, 9.42, 9.45)

- [ ] Set `NpcLifecycle.npc_mood[&"npc_brindle"] = 80` → her opening line changes to the happy variant.
- [ ] Set to 20 → sad variant.
- [ ] After Glaur-em kill, all arrived NPCs surface a comment in sequence (Phase9Helpers.broadcast_world_event_comment).
- [ ] After 5/25/100 player deaths, the Cantor surfaces a specific death-count line (9.52).

## 7. Player-built signs/paintings (9.13, 9.48)

- [ ] Place `sign_post_placeable`. Press E → an inline text field appears; type "Here lies Loambeetle" → submit.
- [ ] Walk away. Re-approach → the sign re-shows the same text.
- [ ] Place `painting_placeable` → proximity toast surfaces the painting's caption.
- [ ] Save → reload → both texts persist.

## 8. Doors (9.14, 9.38)

- [ ] Place `door_wood_placeable` → auto-opens for player and weak mobs.
- [ ] Place `door_metal_placeable` → auto-opens for player; mobs are blocked.
- [ ] Place `door_reinforced_placeable` → does not auto-open; press E to manually toggle (visual modulate is the cue).

## 9. Pet feeding + saddlebag + Curious Egg + evolution (9.15, 9.22, 9.23, 9.31)

- [ ] Place `pet_bowl_placeable`. Select food in hotbar → press E → "Deposited 1 X" toast.
- [ ] Wait for daily reset → the active pet eats one stack and either gains XP (favorite) or low XP (neutral).
- [ ] Wait an empty-bowl day → pet's mood drops by 5.
- [ ] Tame `pet_pale_fox`. Use `Pets.add_xp(&"pet_pale_fox", 9999)` → toast "Pale_fox evolves into Pale_fox_swift!" and the equipment slot swaps.
- [ ] Curious Egg used near torch / forge / anvil / shrine → hatches into a random tamed pet.

## 10. NPC mood/friendship + gift-giving + reputation (9.16, 9.19, 9.57, 9.60, 9.61)

- [ ] Open dialogue with Brindle → `(offer a gift)`. Pick `shaleseed` (favorite) → friendship rises by ~24, mood +15.
- [ ] Try a second gift the same day → "They've already accepted a gift today."
- [ ] Reach friendship 120 with Brindle → `brindle_pendant` auto-arrives in inventory (Phase 9.50). One-shot.
- [ ] Reach friendship 90 with Hask → `small_fishhook` auto-arrives.
- [ ] Use DevConsole to bump faction reputation. Open Brindle's shop → prices visibly shift.

## 11. Quest log + daily reset (9.17, 9.18)

- [ ] Press `L` → QuestLogPanel shows three daily quests, day index, season.
- [ ] Mine 15 shaleseed → "Mine 15 Shaleseed" ticks to (15/15) and +30 coins are added.
- [ ] After an Aphelion day passes (24 real min OR force-tick via DevConsole) → daily quests reroll, seasonal phase advances.

## 12. Decoration sets + wallpaper variants (9.24, 9.25)

- [ ] Place 2+ items from the Aetherdeep-court set (carpet + painting + banner + window_block).
  - `Phase9Helpers.decor_set_bonuses_near(player.global_position)` should return `{ set_aetherdeep_court: N }` where N >= 2.
- [ ] Swap wallpaper variant by placing `wallpaper_cream_placeable` over an existing wallpaper square; floor texture updates.

## 13. Light brightness + light pollution (9.26, 9.41)

- [ ] Place 5 torches within a 64-px square of an NPC's bed.
- [ ] After their next room-scan tick (12 s), their mood ticks down (light pollution counted ≥ 4).
- [ ] Remove 3 torches → mood ticks back up next scan.

## 14. NPC services (9.27, 9.28, 9.29, 9.30)

- [ ] Brindle's `(repair my gear)` → choose a durability-tracked item → cost shown as `missing × 1c` (Brindle's fee).
- [ ] Mira's `(identify an item)` → only equipment with an unidentified affix is shown. Pay 12c to reveal.
- [ ] Cantor's `(travel)` → "To the Anchor Loom (12c)" teleports the player.
- [ ] Step into `phase_long_night` → seasonal extras appear in each merchant's stock.

## 15. Wandering Veiled Buyer + negotiation (9.32, 9.58)

- [ ] On a 4%-per-minute roll, the Veiled Buyer arrives at the Anchor.
- [ ] Open her stock — prices have a 0.75–1.40× jitter applied (re-rolled on each open).
- [ ] At day rollover, she despawns.

## 16. Window blocks, carpet, banner, fence, pillar (9.33–9.37)

- [ ] Each placeable spawns with the right collision profile (fence/pillar/window_block block movement; carpet/banner do not).
- [ ] Window_block belongs to group `wall_blocking` so Housing.validate_room counts it as a wall.

## 17. Indoor/outdoor + Garden score (9.39, 9.40)

- [ ] `Phase9Helpers.is_player_indoors(player)` returns true inside a walled room.
- [ ] `Phase9Helpers.garden_score_near(pos)` returns the count of distinct crop types within 96 px.

## 18. Mailbox + Trading block (9.46, 9.47)

- [ ] Place a mailbox. Call `mailbox.deliver(&"loam", 5, "Walker A")` from another peer's instance (single-player: call directly via DevConsole).
- [ ] Press E on the mailbox → toast "Mailbox: +5 loam from Walker A" and inventory grows.
- [ ] Place a trading_block. Set offer via `trading_block.set_offer(&"loam", 5, 10)` → walking up shows "[E] Buy 5 loam (10c)" → pressing E exchanges coins.

## 19. Ceremony pact + Pyrenkin accent (9.49, 9.64)

- [ ] With Brindle friendship ≥ 140, dialogue reveals `(pledge a forge-oath)` → completing it sets flag `brindle_pact_made`.
- [ ] Open Brindle's `(ask about her accent)` → `(yes — speak in Pyrenkin)` sets `brindle_pyrenkin_accent`. All Brindle dialogue is now run through the replacement table (th' / yer / smelt-pit / etc).
- [ ] `(no — speak Walker-tongue)` clears it.

## 20. NPC-specific gifts + sidequests (9.50–9.53, 9.59)

- [ ] At friendship 120 Brindle → `brindle_pendant` arrives.
- [ ] At friendship 90 Hask → `small_fishhook` arrives.
- [ ] Friendship 80 unlocks Mira's family-name reveal branch (sets `mira_family_revealed`).
- [ ] Aelstren's "fragment quest" path sets `aelstren_map_received`; a `map_fragment` is granted.

## 21. Wormbound peace + Synced lore-tablet (9.54, 9.55)

- [ ] Call `BarkSystem.broadcast_wormbound_peace()` from DevConsole → flag `wormbound_peace_made` set; Mira's `after_wormbound_peace` branch is now reachable.
- [ ] Call `Phase9Helpers.broadcast_lore_tablet(&"tablet_x", "Walker A")` → all peers receive a toast and the entry unlocks.

## 22. Character-select idle pose (9.56)

- [ ] On the title screen, open `CharacterCreationPanel`. The "Idle Pose" dropdown has 5 entries.
- [ ] Confirm → `GameState.character_idle_pose` persists, `Settings.idle_pose` written.

## 23. Walker dream-vision + Resonance-bound + Theme music (9.62, 9.63, 9.65)

- [ ] Sleep in a Bed → ~25% chance to play a dream-vision (5 fragments rotate). Each consumes 1 Aphelion sliver.
- [ ] Die with `brindle_pendant` in inventory → it is NOT in the DeathCorpse stash.
- [ ] Walk within 64 px of a merchant → AudioBus crossfades to that merchant's theme. Walk away → ambient returns.

## 24. Bag-in-bag UX (3.27)

- [ ] Acquire `small_bag` (DevConsole). Activate via consume action → toast "Bag opened.".
- [ ] `Inventory.open_bag_index` is set to that slot; sub-grid of 6 slots is accessible.
- [ ] Add 6 stacks → 7th call to `bag_try_add` for a different item ID is rejected (bag full).
- [ ] Save → reload → bag contents persist.

---

## Save round-trip

- [ ] After completing several Phase 9 actions, save to a new slot.
- [ ] Reload. Verify:
  - Merchant restock times preserved (they're per-instance runtime, so they reset on world reload — expected).
  - Friendship per NPC, mood, faction reputation, seasonal_phase, day_index restored.
  - Beds still bound to NPCs.
  - Sign text, painting captions, mailbox inbox, trading block offers, pet bowl food stacks preserved.

## Edge cases

- [ ] Open the Phase 9 panel while another modal is open (Inventory + MerchantPanel) → Phase 9 panel overlays correctly (z = 75 between merchant z = 80 and other UI).
- [ ] Gift an item the NPC neither favors nor hates — they accept it as a "good" gift only if rarity ≥ 2; otherwise neutral (+4).
- [ ] Save a world with v6 meta → loading should succeed with a `save_version` warning; Phase 9 state will be empty.
- [ ] Quit & relaunch with no save → all NPCs except Aelstren stay pending until a bed is placed.

---

If everything in this checklist passes, Phase 9 is complete. The next phase
(10) begins biomes 3–5 and bosses 2–6.
