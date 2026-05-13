# The Sleeping Vein — Roadmap

> **Strategy.** Mechanical parity with Core Keeper first; lore-driven extensions second. Every parity phase ends in a playable vertical slice of that feature set, even if hooked up only to placeholder art and one biome.

> **How to read this.** Phases are sequenced top-to-bottom. Within a phase, tickets are roughly orderable but mostly independent; the kanban tracks per-ticket state. Phase completion is a milestone — don't start a later phase until earlier-phase critical-path tickets are Done.

> **Companion files:**
> - `kanban.html` — clickable per-ticket board (drag/drop, filters, localStorage)
> - `docs/reference/core-keeper-mechanics.md` — the parity spec
> - `docs/design/00_tile_atlas_spec.md` — grid + atlas sizes
> - `docs/design/01_asset_pipeline.md` — Gemini → Godot pipeline
> - `docs/design/02_lore_to_mechanics_mapping.md` — CK ↔ Aetherdeep names

---

## Phase 0 — Foundation (parity setup)

**Goal.** Project loads, autoloads exist, asset pipeline produces one verifiable tile, CI smoke test passes.

- 0.1 Project skeleton (`project.godot`, autoloads, folder layout) — ✅ Done
- 0.2 Godot AI image-generator plugin install + first generation smoke test — installed; smoke test pending
- 0.3 GUT unit-test framework wired (testing infrastructure) — installed; first test pending
- 0.4 SaveSystem stub → real on-disk save format (JSON or binary)
- 0.5 Palette file (`assets/palettes/sleeping_vein.gpl`) + palette-check tool (`tools/check_palette.py`)
- 0.6 Asset manifest loader (`scripts/systems/manifest_loader.gd`) → returns placeholder magenta for `status: "needed"`
- 0.7 Choose pixel font (6×8 vs 8×8) and import it
- 0.8 Camera2D pixel-snap scene template
- 0.9 Project icon (Gemini-generated final, replacing the placeholder `icon.svg`)

**Exit criterion.** Open `scenes/world/main.tscn`, see a single 16×16 tile rendered crisp at the right size, GUT test runs green, save/load round-trips an empty world.

---

## Phase 1 — Player & World Foundation

**Goal.** A player capsule walks around a 1-biome tiled world, with Y-sort'd walls and pixel-perfect camera.

- 1.1 `PlayerController` scene (CharacterBody2D + components)
- 1.2 8-directional movement + Running skill placeholder
- 1.3 `HealthComponent` + `ManaComponent` (reusable)
- 1.4 Death + respawn loop (consumes Aphelion sliver)
- 1.5 First TileMap with floor + capped wall layers (Y-sort layering per atlas spec §5)
- 1.6 Camera2D follows player; pixel-snap on
- 1.7 Day/night cycle hooked to Aphelion Beat (23s pulse)
- 1.8 Ambient light + Light2D player torch
- 1.9 Hand-of-light idle glow (lore §7.6)
- 1.10 Aphelion Beat audio cue (silent placeholder OK)
- 1.11 Hotbar UI shell (10 slots, key/wheel cycling)
- 1.12 First test biome: Root Hollows placeholder tiles (Gemini-generated)

**Exit criterion.** Stand in the Root Hollows. Walk in 8 directions. Wall behind player overlaps correctly. Camera doesn't blur. Aphelion Beat cycles. Test scene saves and loads.

---

## Phase 2 — Mining & Combat (the loop)

**Goal.** The core verbs: hit a tile, hit an enemy, collect a drop, level up.

- 2.1 Tile mining: pickaxe item, tile-tier requirement, damage formula
- 2.2 Tile drop spawning (item entity, gravity-less 2D)
- 2.3 Item pickup proximity check + inventory grow stub
- 2.4 `HitboxComponent` + `HurtboxComponent` (reusable for combat)
- 2.5 Melee swing arc primitive + damage application
- 2.6 First mob (Stone-Hopper, 16×16, simple chase AI)
- 2.7 Death + drop loot table (`.tres` resource per mob)
- 2.8 Skill system core (12 skills, XP, level, EventBus emission)
- 2.9 First skill XP source: Mining damage tile → emit `skill_xp_gained`
- 2.10 First skill XP source: Melee damage mob → emit `skill_xp_gained`
- 2.11 Damage flash + hit SFX hooks
- 2.12 First dropped-item rarity tier coloring (white / green / blue / purple / yellow)
- 2.13 Aphelion-sliver display in HUD (lore §1.7 — visible on respawn)

**Exit criterion.** Mine a tile → get loam. Hit a Stone-Hopper → it dies → drops a loambeetle. Pick it up. Skill XP gain visible. Die → respawn at Loom → sliver count decrements.

---

## Phase 3 — Inventory & Crafting

**Goal.** A real inventory and the first crafting tree branch.

- 3.1 Inventory grid UI (3×10 default, expandable)
- 3.2 Drag-and-drop between inventory cells
- 3.3 Tooltip on hover
- 3.4 Equipment slots panel (helm, chest, off-hand, neck, ring×2, bracelet, belt, pet)
- 3.5 Hotbar selection logic + held-item rendering (player sprite swap)
- 3.6 Chest container scene (placeable, savable)
- 3.7 Loam Bench placeable + UI
- 3.8 Recipe `.tres` resource format
- 3.9 Recipe unlock system (event-driven, persistent)
- 3.10 First 12 recipes: wood pick, wood sword, basic floor tile, basic wall tile, basic torch, etc.
- 3.11 Shaleseed ore → Clearstone Forge upgrade path (Tier 1)
- 3.12 Crafting skill XP source

**Exit criterion.** Open inventory. Craft a Wood Pickaxe. Place it in hotbar. Mine 3× faster. Stash extra in a chest. Reload save — chest contents persist.

---

## Phase 4 — Procedural World & Biomes 1–2

**Goal.** Procedural Root Hollows + Glasswright Reaches with biome edges, ore distribution, and the Anchor structure.

- 4.1 Chunk system (64×64 tile chunks per CK; load on player proximity)
- 4.2 Procedural floor & wall generation per biome
- 4.3 Ore vein placement (Perlin or Poisson-disk)
- 4.4 Anchor structure prefab (pre-placed; player wakes here)
- 4.5 Resonance Loom interactable (set spawn / view sliver count)
- 4.6 Biome boundary transitions (corridor tunnels)
- 4.7 Root Hollows biome data resource + ore tiers (Shaleseed)
- 4.8 Glasswright Reaches biome data resource + ore tiers (Clearstone)
- 4.9 Biome-specific ambient music swap on cross
- 4.10 Map (mini + full-screen) revealing chunks as visited
- 4.11 Compass to Loom (lore swap for "compass to Core")

**Exit criterion.** Spawn on Anchor. Walk in any direction → eventually cross into Glasswright Reaches → palette shifts → music shifts → ore tier changes.

---

## Phase 5 — First Boss & NPC arrival

**Goal.** Glaur-em fightable in the Root Hollows; Aelstren the Cartographer arrives at the Anchor on world start.

- 5.1 Boss arena prefab (rune-circle equivalent for Root Hollows)
- 5.2 Glaur-em 3-phase fight (slam → split → soft-core per lore §05)
- 5.3 Boss HP bar UI
- 5.4 Stoneslough boss-minion add (boss-only mob)
- 5.5 Boss drops: Stone-Father's Pulse, Engorged stone-shell, name fragment 1
- 5.6 Loom power-up flow: insert Stone-Father's Pulse → unlock Glasswright descent corridor
- 5.7 NPC base class + dialogue UI
- 5.8 Aelstren the Cartographer NPC (silent + map-fragment hand-off)
- 5.9 NPC arrival trigger system (boss kill → NPC spawn at Anchor)
- 5.10 NPC housing checks (8×8, door, bed) — Phase 5 stub, full rules Phase 9
- 5.11 First lore tablet placement system (collect → compendium entry)
- 5.12 Compendium UI shell (bestiary + tablets tabs)

**Exit criterion.** Defeat Glaur-em. Aelstren appears at the Anchor with no prompt. Stone-Father's Pulse inserts into the Loom. Glasswright Reaches descent corridor unlocks.

---

## Phase 6 — Combat depth: Ranged, Magic, Status Effects

**Goal.** The combat system supports all 4 weapon classes and the standard status palette.

- 6.1 Ranged weapon class: Bow + Arrow ammo
- 6.2 Ranged weapon class: Gun + Bullet ammo
- 6.3 Magic weapon class: Staff (mana cost, cooldown)
- 6.4 Summoning weapon class: Minion spawn + follow AI
- 6.5 Damage-type system (`StringName` typed: physical, fire, poison, cold, magic, summon, explosive, lightning, void)
- 6.6 Burn DoT (8.4s, 2s ticks)
- 6.7 Poison DoT + healing-reduction debuff
- 6.8 Cold / Freeze slow
- 6.9 Stun lockout
- 6.10 Resistance/weakness per mob (data-driven)
- 6.11 Crit chance + crit damage stats
- 6.12 Armor calculation (final damage formula)
- 6.13 Buff/debuff icon strip on HUD

**Exit criterion.** Swap weapons. Apply burn to a Stone-Hopper → sees DoT ticks. Cold-slow a Mossback. Crit hits show distinct number color.

---

## Phase 7 — Skills full talent trees

**Goal.** All 12 skills have functioning talent trees with passive bonuses.

- 7.1 Talent tree data format (`.tres`)
- 7.2 Talent UI screen (per-skill tab)
- 7.3 Mining talents (Stratabreaking)
- 7.4 Running, Melee, Ranged, Vitality talents
- 7.5 Crafting, Gardening, Fishing, Cooking talents
- 7.6 Magic, Summoning, Explosives talents
- 7.7 Talent-point allocation + respec consumable item

**Exit criterion.** Hit Mining 5 → talent prompt. Allocate "+2% mining speed". Mine a tile → speed visibly increases. Buy a respec scroll, reset, re-allocate.

---

## Phase 8 — Farming, Cooking, Fishing

**Goal.** The three life-sim verbs.

- 8.1 Hoe → till soil interaction
- 8.2 Watering Can → moisture state on soil tile
- 8.3 Seed planting; growth-stage tile transitions; ~10 min real-time growth
- 8.4 First 6 crops: Pale Cap, Memory Root, Bloat Oat (Verdancy preview), Heart Berry, etc.
- 8.5 Cooking Pot station + 2-ingredient recipe discovery
- 8.6 First 20 cooking recipes with food buffs
- 8.7 Food buff stacking rules (1 of each type)
- 8.8 Cookbook UI (discovered recipes)
- 8.9 Fishing rod tiers (Wood / Copper / Iron at first)
- 8.10 Fishing minigame (click-to-hook, hold-to-reel)
- 8.11 Bait off-hand slot logic
- 8.12 Fish list per biome (data-driven; populates as biomes ship)
- 8.13 Sprinkler automation (Iron+) — toggle waterer over a tile radius

**Exit criterion.** Plant 4 Bloat Oat. Water once. Wait 10 min. Harvest 4-5 (Gardening talent works). Cook a Bloat Loaf. Eat it. Get the +X% buff. Catch a Pale Cave Guppy.

---

## Phase 9 — NPCs, Housing, Merchants

**Goal.** The Anchor becomes a base with up to 6 NPCs in residence, each with a working shop.

- 9.1 NPC housing detection (8×8 max, wood door, bed)
- 9.2 Bed item: placeable, single-NPC binding
- 9.3 Merchant UI (buy/sell tabs)
- 9.4 Ancient Coin currency (drop from bosses + chests)
- 9.5 Brindle Quench-of-Coals: smith merchant + smelt-recipe vendor
- 9.6 Mira-no-Last-Name: storage clerk (chest-bag upgrades)
- 9.7 The Cantor of Five Bells: musician + Sovereign-Name song progress tracker
- 9.8 Old Hask: fishing merchant + Drowned Aphelion lore
- 9.9 The Veiled Buyer: random-spawn high-price NPC
- 9.10 Inventory restock timer (30-45 min)
- 9.11 NPC pathfinding around the Anchor (walk between sleeping at bed and shop)
- 9.12 NPC dialogue tree format (`.tres` or JSON)

**Exit criterion.** Build 5 huts at the Anchor. Each NPC moves in. Buy a recipe from Brindle. Sell unwanted ore. Hask hints at the Drowned Aphelion.

---

## Phase 10 — Biomes 3–5 + Bosses 2–6

**Goal.** The Vesari Necropolis, Sunless Verdancy, and Drowned Aphelion are playable, including all their bosses.

- 10.1 Vesari Necropolis biome data + tiles
- 10.2 Sunless Verdancy biome data + tiles
- 10.3 Drowned Aphelion biome data + tiles
- 10.4 Salt-Bound Sailor mob (Resonance Echo)
- 10.5 Spore-Lurk + Vine-Stalker + Bloom-Hag (Verdancy mobs)
- 10.6 Deep-Mawl + Hollow Coral + Wreck-Wraith (Drowned mobs)
- 10.7 Swimming mechanic (Drowned Aphelion)
- 10.8 Underwater breath meter / Coral Veil item
- 10.9 Vorr'kell boss (Tunnel Wyrm)
- 10.10 Spawnmother boss
- 10.11 Sythrenn boss (mid-Verdancy) with mercy-kill variant
- 10.12 Auriax boss (Verdancy major)
- 10.13 Vol'thaar boss with speech + release-or-kill choice
- 10.14 Drowned Crown optional boss
- 10.15 Toxic spore environmental hazard (Verdancy)
- 10.16 Salt-corrosion gear-wear environmental effect (Necropolis)

**Exit criterion.** Walk a path from Anchor through 5 biomes. Beat 5 bosses. Make the Vol'thaar choice. See the Verdancy die after Auriax. Get the Drowned Crown's sword if you find him.

---

## Phase 11 — Biomes 6–8 + Bosses 7–9

**Goal.** Emberforge, Salt Wastes, Auroric Veil playable.

- 11.1 Emberforge biome data + tiles
- 11.2 Salt Wastes biome data + tiles
- 11.3 Auroric Veil biome data + tiles
- 11.4 Heat-damage mechanic (Emberforge)
- 11.5 Cold-damage mechanic (Auroric Veil)
- 11.6 Day/night temperature swing (Salt Wastes, hooked to Aphelion Beat phase)
- 11.7 Heat-resistance & cold-resistance armor stats
- 11.8 Pyrenkin forge sub-quest chain (reactivate forges)
- 11.9 Wormbound encounter system (non-hostile + ritual peace)
- 11.10 Skoldur boss with "You came back" recognition
- 11.11 Naeren boss with peaceful-path alternative
- 11.12 Veyl-Aurora 7-spire boss
- 11.13 Listeners-Below first appearance + trade

**Exit criterion.** Survive Emberforge heat. Make Wormbound peace OR fight Naeren. Hear Veyl-Aurora's collapsing chord. Korya appears at least once.

---

## Phase 12 — Endgame: Final Spiral + 3 Endings

**Goal.** Stratum 9 playable, Diadem-Bearer fight, all 3 endings selectable.

- 12.1 Final Spiral biome data + tiles
- 12.2 Diadem-Reader / Censer / Warden mobs (Sunken Diadem)
- 12.3 Pure Hollowling Mote rare mob + Mote Tide event
- 12.4 Vacancy creature follower encounter
- 12.5 Elision-Script recovery puzzle (lore §10.5)
- 12.6 Diadem manifestos corridor (readable wall texts)
- 12.7 Resonance Loom's Twin discovery
- 12.8 Diadem-Bearer boss (4 phases + Readers as adds)
- 12.9 Ending A (Restore) sequence
- 12.10 Ending B (Break) sequence + optional Aphelion fight
- 12.11 Ending C (Become) sequence + unlock conditions
- 12.12 Endgame credits + scoring screen
- 12.13 New Game+ option

**Exit criterion.** Reach the Aphelion's chamber. See three physical paths. Pick one. Credits roll. Save flagged as completed.

---

## Phase 13 — Multiplayer

**Goal.** 1-8 player co-op, shared world, separate inventories.

- 13.1 Network sync architecture decision (ENet vs Steam Networking vs WebRTC)
- 13.2 Authority model (host-driven; bosses authoritative on host)
- 13.3 Multi-Walker spawn at single Loom
- 13.4 Resonance-pulse multiplayer flicker (lore §7.6 cosmetic)
- 13.5 Chat (text emote per lore — Walkers can't speak)
- 13.6 Multi-player NPC count (Anchor density gentle reward)
- 13.7 Shared chest sync
- 13.8 Player join / drop saves
- 13.9 Cross-platform / dedicated server stub
- 13.10 Boss scaling per player count

**Exit criterion.** Two clients connect to one host. Both wake at the Loom. Both can mine, both can fight, drop sync works. One can die without breaking the world.

---

## Phase 14 — Automation & Electricity

**Goal.** Conveyor belts, drills, robotic arms, power.

- 14.1 Conveyor belt placeable + direction
- 14.2 Drill tile mining automation (tier-gated)
- 14.3 Robotic arm item-pickup-and-place
- 14.4 Power source: Aphelion-tap (Void & Voltage parity)
- 14.5 Wire system + circuit propagation
- 14.6 Sensor / pressure-plate / button triggers
- 14.7 Logic gates (AND / OR / NOT / NAND etc.)
- 14.8 Storage container piping
- 14.9 Auto-farms (sprinkler + harvester)
- 14.10 Auto-furnaces / auto-smelters

**Exit criterion.** Build a closed-loop auto-farm: plant → grow → drill or robot-arm harvest → conveyor → chest → cooking pot input → output chest. Player just watches.

---

## Phase 15 — Polish & Parity Gap Closure

**Goal.** Visit every [VERIFY] in `docs/reference/core-keeper-mechanics.md` and either confirm or correct.

- 15.1 Run a full content audit vs the parity reference doc
- 15.2 Close [VERIFY] items one by one (test against CK or accept documented value)
- 15.3 Bestiary screen full implementation
- 15.4 Achievement system (all categories)
- 15.5 World-settings UI (size, difficulty, casual/hard, creative, hardcore)
- 15.6 Seasonal event content (Halloween / Winter / Anniversary)
- 15.7 Sound design pass (per-biome ambient, combat hits, UI)
- 15.8 Performance pass (chunk pooling, sprite batching, lighting cost)
- 15.9 Localization scaffolding (Old Vesari "language" already conceptual)
- 15.10 Accessibility pass (colorblind palette toggles, text size, key remap)

**Exit criterion.** Mechanical-parity-complete demo build. Could plausibly be released as a "Core Keeper-like with original lore."

---

## Phase 16 — Custom Extensions (the user's vision)

**Goal.** Now begin layering features Core Keeper doesn't have. **Scoping per ticket; no auto-acceptance.** Each extension goes through a design doc in `docs/design/extensions/` before being kanban-promoted.

Currently planned extensions (from kickoff conversation and lore implications):

- 16.1 Aphelion-sliver finite mortality budget (lore §1.7) + late-game NPC commentary
- 16.2 Sovereign-Naming sidequest + Cantor's Compass payoff
- 16.3 Resonance Echo system (60+ placed ghost-scenes per lore §11.5)
- 16.4 Aphelion Hymn assembly mini-quest
- 16.5 Three-ending branching consequences (already in Phase 12 framework; here we expand the C-ending Become consequences)
- 16.6 Wormbound covenant + alt-Naeren encounter
- 16.7 Vol'thaar's Promise summon item
- 16.8 Vacancy creature companion mechanic
- 16.9 The Listeners-Below face-reveal Echo
- 16.10 Sythrenn's Last Petal living memorial
- 16.11 Per-player gold-thread visible cosmetic (lore §7.7)
- 16.12 Diadem-Bearer's pre-Diadem name reveal (Mira's brother thread)
- 16.13 Cantor's Five Bells music puzzle
- 16.14 *[USER-PROVIDED EXTENSIONS — open slot for what the user wants to add]*

**Exit criterion.** Each accepted extension has its own design doc, kanban tickets, exit criterion, and lands behind a clean feature flag if it could be cut at release.

---

## Cross-cutting concerns (every phase)

- **Tests.** Every system has GUT unit tests in `tests/`. Combat math, save round-trip, recipe resolution, skill XP calc, talent application.
- **Save compat.** Bump `meta.save_version` whenever a save-affecting change ships. Write migration scripts in `scripts/systems/save_migrations/`.
- **Data-driven.** No hardcoded item lists. Every item, recipe, mob, biome is a `.tres` resource.
- **Lore enforcement.** Read `lore/` before writing dialogue or naming an item. Flag gaps in `docs/design/_open_questions.md`.
- **No new dependencies** without the user's OK. We currently use Godot 4.6, GDScript, GUT, and the AI image-generator plugin. Period.

---

## Estimated effort (rough order of magnitude)

| Phase | Approx scope | Notes |
|-------|--------------|-------|
| 0 | 1–2 weeks | Infrastructure |
| 1 | 2-3 weeks | Player + world basics |
| 2 | 2-3 weeks | Combat + mining loop |
| 3 | 2-3 weeks | Inventory + first crafting tree |
| 4 | 2 weeks | Procedural world + biomes 1–2 |
| 5 | 2 weeks | First boss + NPC framework |
| 6 | 2-3 weeks | Combat depth |
| 7 | 2 weeks | Skill talents |
| 8 | 3 weeks | Life-sim verbs |
| 9 | 2 weeks | NPC depth |
| 10 | 4-5 weeks | 3 biomes + 5 bosses |
| 11 | 3-4 weeks | 3 biomes + 3 bosses |
| 12 | 3-4 weeks | Endgame + endings |
| 13 | 3-4 weeks | Multiplayer |
| 14 | 3-4 weeks | Automation |
| 15 | 2-3 weeks | Polish |
| 16 | open-ended | Extensions |

Total parity scope: **roughly 40–55 dev-weeks of focused single-developer time** before extension work begins. Multi-developer or with substantial co-author / agent help, much less wall-clock.
