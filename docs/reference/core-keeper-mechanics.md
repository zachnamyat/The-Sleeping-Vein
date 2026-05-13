# Core Keeper Mechanics — Parity Reference

> **Purpose.** This document is the consolidated mechanical spec for Core Keeper as of the **Void & Voltage** update (Feb 2026, version 1.2.x). The Sleeping Vein targets 1-to-1 functional parity with these systems before layering any custom features.
>
> **Provenance.** Compiled 2026-05-12 from: Core Keeper wiki (`corekeeper.atma.gg` and `core-keeper.fandom.com`), XGamingServer boss tracker, BisectHosting NPC guide, TechRaptor / The Gamer / PC Gamer guides, and Steam community guides. **Items marked [VERIFY]** were not confirmed against a primary source and should be sanity-checked when implemented.

---

## 0. World architecture

- **Grid:** Tile-based 2D top-down with a subtle 3/4 lean (walls have a small "lift" — floors render flat, walls have a 1-tile-tall capped silhouette). Movement is **free 8-directional**, not grid-locked.
- **Chunk grid:** 64×64 tiles per chunk. **[VERIFY exact figure — search-derived]**
- **Spawn cells:** 16×16 tile cells used for mob spawn budgeting. **[VERIFY]**
- **The Core:** Fixed spawn structure at world origin (`0, 0`). The player wakes here. Three boss-drop items are inserted to "power up" The Core, which is the gate to the mid-game biomes.
- **World size options:** Small / Medium / Large (and Custom). Worlds are *finite* — bounded biome rings around The Core, not infinite.
- **Border zones:** Neutral transitional bands between biomes; mob density and ore tier scale roughly with distance from The Core.

## 1. Player

### 1.1 Vitals
- **Health (HP)** — Vitality skill governs the cap.
- **Mana** **[VERIFY name — may be "Mana" or implicit in Magic equipment]** — required for staves.
- **Hunger / Food bar** — depletes over time; running on empty starts HP drain.
- **Buff stacks** — food, potions, talents, equipment.

### 1.2 Movement
- WASD + mouse aim. Roll/dodge is a craftable / shopped consumable, not a default verb. **[VERIFY: no native dodge]**
- Sprint via Running skill talents.
- Swimming unlocked in Sunken Sea biome via specific gear.

### 1.3 Hands / hotbar
- 10-slot hotbar (`1`–`0` keys). Mouse-wheel cycles slot.
- Two equippable item paradigms:
  - Tool / weapon held in main hand
  - Off-hand slot (shield / lantern / bait)

## 2. Inventory & equipment

- **Inventory grid**: starts at ~3 rows × 10 columns, expandable via Bag Expansions crafted from each Workbench tier.
- **Equipment slots** (canonical):
  - Helmet, Chest, Pants/Legs **[VERIFY: separate or one body slot]**
  - Off-hand
  - Necklace
  - Ring × 2
  - Bracelet **[VERIFY]**
  - Belt **[VERIFY]**
  - Pet slot (Curious Egg-hatched pet)
- **Sets:** 56 named armor sets + 30 miscellaneous pieces. Sets typically give a +damage% bonus when 2+ pieces equipped (e.g. Hunter, Ranger, Scarlet).
- **Backpacks / bags:** Extra-bag items occupy inventory slots and contain their own sub-inventories.

## 3. Combat & damage

### 3.1 Damage types
Confirmed from skills + status pages:
- **Physical** (melee, range)
- **Magic**
- **Summon** (a subclass of magic — damage from minions)
- **Explosives**
- **Fire / Burn** (DoT, ticks every 2s, ~8.4s duration / 4 ticks)
- **Poison** (DoT + reduces healing received by 75% for 15s)
- **Cold / Freeze** **[VERIFY]**
- **Lightning** (introduced in Void & Voltage) **[VERIFY]**

### 3.2 Damage formula (working model)
`final = base_damage × (1 + sum of %damage modifiers) × (1 + crit_bonus if crit) - target.armor_reduction`

- Crit chance and crit damage are independent stats found on rings, accessories, set bonuses.
- Armor reduces incoming physical damage by a flat / percentage hybrid. **[VERIFY formula]**
- Many bosses have damage caps per hit to discourage one-shot exploits.

### 3.3 Weapon classes (~70 weapons total)
- **Melee (33):** Swords (broad arc, mid-speed), Daggers (fast, low base, crit-leaning), Spears (longer reach, slower).
- **Range (23):** Bows (consume arrows from off-hand / inventory), Guns / Muskets (consume bullets, higher fire-rate).
- **Magic (10):** Staves — projectile or AoE; mana / cooldown gated.
- **Summon (6):** Summons minions; minion count and damage scale with Summoning skill.

## 4. Mining

- Pickaxes have a **mining tier** (numeric). Each ore tile has a **required tier** to break. Below tier = no progress.
- Mining damage = pickaxe base + Mining skill level (+1 per level, cap 100).
- Mining XP per tile broken; harder tiles give more XP.
- Pickaxe drops include floor/wall tiles (for building) and ore.

## 5. Crafting & workbenches

### 5.1 Tier ladder (8 main + Pandorium)
1. **Basic Workbench** — wood tools, basic furniture, the next tier prerequisite.
2. **Copper Workbench** — copper tools, Wood Fishing Rod, Bag Expansion, Small Lantern.
3. **Tin Workbench** — Clay Caves tier.
4. **Iron Workbench** — Forgotten Ruins tier.
5. **Scarlet Workbench** — Azeos' Wilderness tier.
6. **Octarine Workbench** — Sunken Sea tier (Sunken Sea Update).
7. **Galaxite Workbench** — Desert of Beginnings tier.
8. **Solarite Workbench** — Shimmering Frontier tier.
9. **Pandorium** items — endgame; no Pandorium workbench (items crafted at Solarite or via Reliquary-equivalent). **[VERIFY]**

### 5.2 Adjacent crafting stations (per tier)
Each workbench also unlocks adjacent stations like: Anvil, Furnace, Sawmill, Loom, Drying Rack, Bait Workbench, Cooking Pot, Carpenter's Table, Tannery, Pottery Wheel **[VERIFY full list]**, plus the **Ancient Hologram Pod** (Spirit Merchant station, unlocked after Hive Mother).

### 5.3 The Core (central machine)
- Player-tier upgrade station — inserts boss-key items.
- Activates Glurch-Eye-equivalent slots: insert **Glurch Eye** + **Ghorm's Horn** + **Stolen Crystal Heart** (Malugaz) → unlocks Azeos' Wilderness, Forgotten Ruins, Sunken Sea outer biomes.
- Acts as the world's permanent respawn point.

## 6. Biomes (current canonical list)

| # | Biome | Sub-biomes | Tier | Boss(es) | Required gear |
|---|-------|------------|------|----------|----------------|
| 0 | The Undergrounds (Dirt) | — | Start | Glurch, Ghorm | None |
| 1 | Clay Caves | Larva Hive | Tin | Hive Mother | Copper / Tin |
| 2 | Forgotten Ruins | — | Iron | Malugaz, Ivy | Iron |
| 3 | Azeos' Wilderness | — | Scarlet | Azeos, Druidra | Scarlet |
| 4 | Sunken Sea | Coral, Trenches | Octarine | Morpha, Omoroth, Atlantean Worm (opt.) | Octarine + swim gear |
| 5 | Desert of Beginnings | Molten Quarry, Oasis | Galaxite | Igneous, Ra-Akar, Pyrdra | Heat resist + Galaxite |
| 6 | Shimmering Frontier | — | Solarite | Crydra, Druidra, Pyrdra, Nimruza | Cold resist + Solarite |
| 7 | The Passage | — | Pandorium | Core Commander, Urschleim | Solarite |
| 8 | Breaker's Reach | — | Endgame | S.A.H.A.B.A.R, Oblidra the Void Lord | Pandorium + Void & Voltage gear |

## 7. Bosses (18 total — Void & Voltage 2026)

### 7.1 Order with summons & gating

| # | Boss | Biome | Summon item / trigger | Drops | Gates |
|---|------|-------|-----------------------|-------|-------|
| 1 | Glurch the Abominous Mass | Dirt | Slime rune (auto-spawned) → re-summon: Giant Slime Summoning Idol | Glurch Eye, Slime Oil, Glurch Chest, Melting Crystal Ring | Powers Core (slot 1) |
| 2 | Ghorm the Devourer | Dirt | Patrols on circular rune track → re-summon: Ghorm Summoning Idol | Ghorm's Horn, Mysterious Idol → Caveling Merchant | Powers Core (slot 2) |
| 3 | The Hive Mother | Larva Hive (Clay) | Spawns in Hive arena → re-summon: Hive Mother Summoning Idol | Unlocks Ancient Hologram Pod → Spirit Merchant | Unlocks Spirit Merchant |
| 4 | Malugaz the Corrupted | Forgotten Ruins | Caveling Shaman boss; spawned by crafting Crystal Skull from 10 Blue Crystal Shards (dropped by Cavelings) at his altar | Stolen Crystal Heart | Powers Core (slot 3) |
| 5 | Azeos the Sky Titan | Azeos' Wilderness | Fixed arena ~600 tiles from Core | Soul of Azeos, Pile of Chum → Fishing Merchant | Awakened Azeos / Titan progression |
| 6 | Ivy the Poisonous Mass | Forgotten Ruins (deep) | Fixed arena, poison pools approach | (poison-tier drops) | Progression |
| 7 | Morpha the Aquatic Mass | Sunken Sea | Fixed arena ~700 tiles from Core | (Octarine-tier drops) | Progression |
| 8 | Omoroth the Sea Titan | Sunken Sea | Soul-of-Azeos required to unlock | Soul of Omoroth (~91k HP) | Titan progression |
| 9 | Igneous the Molten Mass | Molten Quarry | Sub-biome encounter | (Galaxite-tier drops) | Progression |
| 10 | Ra-Akar the Sand Titan | Desert of Beginnings | Place **Thumper** in arena ~600 tiles from Core | Soul of Ra-Akar (~161k HP) | Titan progression |
| 11 | Crydra (Ice Hydra) | Shimmering Frontier | Fixed arena | Solarite drops | Hydra progression |
| 12 | Druidra (Wild Hydra) | Shimmering Frontier | Fixed arena | Solarite drops | Hydra progression |
| 13 | Pyrdra (Fire Hydra) | Shimmering Frontier | Fixed arena | Solarite drops | Hydra progression |
| 14 | Nimruza (Void Hydra) | Shimmering Frontier | Fixed arena (~228k HP) | Brood Void Neuron | Unlocks The Passage |
| 15 | Core Commander | The Passage | Fixed arena (~465k HP) | Pandorium drops | Endgame |
| 16 | Urschleim | The Passage | Fixed arena | Pandorium drops | Endgame |
| 17 | **S.A.H.A.B.A.R** | Breaker's Reach | Summoned via **Profane Override** | Void & Voltage drops | Endgame |
| 18 | **Oblidra the Void Lord** | Breaker's Reach | Summoned via **Wind Organ of Void** | Final endgame drops | Final |

Optional / variant bosses:
- **Atlantean Worm** — Sunken Sea, summoned with Bait Pillar.
- **Awakened Azeos** — alternative version of Azeos.

### 7.2 Common boss anatomy
- Spawn arena (designated rune-circle terrain) with ambient hostile minions.
- 2–4 attack patterns plus a "rage" / pattern shift at low HP.
- Drops: a tier-defining material chest piece OR a story-key item, plus a re-summon idol available from the relevant NPC merchant after first kill.

## 8. NPC merchants

Each merchant requires (with exceptions): an **8×8-max room**, **wood door**, **bed**, **at least 1 empty floor tile**, and the player ≥30 tiles away when the NPC spawns.

| NPC | Summon item | Source | Notable sells |
|-----|-------------|--------|----------------|
| Bearded (Slime) Merchant | Slime Oil (housing) | Glurch | Curious Egg, Scrap Parts, Fiber, Copper/Tin/Iron/Gold Ore, Larva Meat |
| Caveling Merchant | Mysterious Idol (housing) | Ghorm | Caveling Bread, Flintlock Musket, Boss Summoning Idols, Mechanical Part, Rune Parchment, Empty Crystal |
| Spirit Merchant | Ancient Hologram Pod (no room needed) | Hive Mother | Crafting recipes / unique items |
| Fishing Merchant | Pile of Chum (housing) | Azeos | Cave Guppy, Dagger Fin, Azure Feather Fish, Green/Red/Purple Bait, Sea Foam Ring, Neptune Necklace |
| Seasonal Merchant | Seasonal Calendar (housing) | Carpenter's Table craft (5 Wood + 8 Fiber) | Anniversary Cake, Party Hats, Event Workbenches, Helperling |
| Brave Merchant | Nuclear Battery Idol (housing) | Alien Tech Chest in Shimmering Frontier | Endgame items |
| Cloaked Merchant | Spawns rarely near Core | Random world event | Sells the early summoning idols |

NPC inventory **restocks every 30–45 minutes** real time. **[VERIFY exact figure]**

## 9. Skills (12 total)

All skills cap at level **100**. XP comes from performing that activity.

| Skill | XP source | Per-level effect | Cap effect |
|-------|-----------|------------------|-----------|
| Mining | Breaking ore tiles | +1 mining damage | +100 |
| Running | Movement (sprinting?) | +0.1% move speed | +10% |
| Melee Combat | Melee weapon hits | +0.5% melee damage | +50% |
| Range Combat | Bow / gun hits | (talent-driven: Charging In, Stun Shot, Focused Accuracy) | varies |
| Vitality | Taking damage / regen | +HP cap (and Summoning sub-talent gives +0.5% minion damage) **[VERIFY]** | varies |
| Crafting | Crafting items | (talent-driven; chance for free item, bonus durability, etc.) **[VERIFY]** | varies |
| Gardening | Harvesting plants | +0.4% extra harvest | +40% |
| Fishing | Successful catches | +1 fishing power | +100 |
| Cooking | Cooking food at pot | +0.2% double-cook chance | +20% |
| Magic | Staff hits | +0.5% magic damage | +50% |
| Summoning | Minion hits | +0.5% minion damage | +50% |
| Explosives | Bomb / explosive hits | +1% explosive damage | +100% |

Each skill has a **talent tree** with branching nodes unlocked at levels 5, 10, 15, 25, 35, 50, 75, 100 **[VERIFY breakpoints]**. Talents are passive bonuses.

## 10. Farming / Gardening

- Tools: **Hoe** (till soil), **Watering Can** (water tilled soil), **Seed** (plant).
- Seeds plant in the same soil they're found in: Bloat Oat → Dirt/Turf/Grass; Heart Berry → Grass; etc.
- Water once; plant grows over ~10 real-time minutes.
- Crops include: Bloat Oat, Bomb Pepper, Carrock, Glow Tulip, Heart Berry, Pewpaya, Puffungi, Pinegrapple, plus biome variants (Bloomtail, Pinegrass, etc.). **[VERIFY full list]**
- **Sprinklers** automate watering (Iron-tier+). **[VERIFY]**
- Fertilizer **[VERIFY presence]**.

## 11. Cooking

- **Cooking Pot** workstation.
- Recipes are **combinations of 2 ingredients**; the game discovers them as you cook.
- Most recipes yield buffs (food buff stacks 1 of each type at a time).
- Food buff duration ~10 min; cookbook tracks every discovered recipe.

## 12. Fishing

- **Fishing Rods** mirror Workbench tiers: Wood → Copper → Iron → Scarlet → Octarine → Galaxite → Solarite (+ Pandorium-tier likely Void & Voltage). Galaxite Rod = **+286 fishing power**.
- **Bait** in off-hand: Green / Red / Purple (rarer outcomes).
- Fish biome-specific; rarities Common → Uncommon → Rare → Epic → Legendary.
- Catch = pole timing minigame (click to set hook, hold to reel).
- Many fish double as cooking ingredients.

## 13. Building

- Player-placed: floor tiles, wall tiles, doors (wood door for housing), beds, torches, painting/canvas decorations, chairs, signs, banners.
- Walls **block enemy spawns** within a radius (key for safe-base design).
- "Habitable room" detection: enclosed by walls + door + bed.

## 14. Automation (mid-late game)

- **Conveyor Belts** — directional item transport.
- **Drills** — auto-mine the tile in front of them (tier-gated).
- **Robotic Arms** — pick up and place items between containers / conveyors.
- **Sensors / Triggers** — actuators for circuitry. **[VERIFY: full circuit DSL]**
- **Power** — wire-based, introduced in Void & Voltage update (electricity, hence the name). **[VERIFY]**

## 15. Status effects

| Status | Source | Effect | Duration |
|--------|--------|--------|----------|
| Burn | Fire weapons, hot tiles, magma | Damage every 2s | 8.4s (4 ticks) |
| Poison | Toxic enemies / weapons | DoT + −75% healing received | 15s |
| Cold / Freeze | Frigid biomes, frost weapons | Slow movement, eventual HP drain | **[VERIFY]** |
| Bleed | Some swords / accessories | DoT, scales with target max HP | **[VERIFY]** |
| Stun | Stun Shot talent, bombs | No actions | short |
| Confusion | Caveling shamans **[VERIFY]** | Reversed inputs | short |
| Buffs | Food, potions, talents, equipment | Various +%damage / +regen / +speed | 5–10 min for food |

## 16. Pet system

- **Curious Egg** purchased from Bearded Merchant → hatch via warmth (place near torches in walled room).
- Pets follow the player, have their own HP, and provide minor buffs / DPS.
- Multiple pet species (Slime pup, Caveling pup, etc.). Pets unlock from boss drops too.

## 17. Multiplayer

- 1-8 players co-op.
- Shared world, separate inventories.
- Host-driven (one player hosts, others join via Steam/Galaxy invite / dedicated server / cross-platform on 1.0+).
- No PvP.
- Bosses scale slightly with player count **[VERIFY scaling]**.

## 18. World settings / modes

- Difficulty toggles: **Casual / Normal / Hard / Hard-mode-with-modifiers** **[VERIFY exact set]**.
- **Creative mode** — no death, no resource cost.
- **Hardcore** — permadeath toggle. **[VERIFY]**
- Seed input on world create.
- World size: Small / Medium / Large (changes the radius of each biome ring).

## 19. UI / HUD elements

- HUD top-left: HP, hunger, buffs.
- HUD top-right: minimap, compass to The Core.
- HUD bottom: 10-slot hotbar with selected slot indicator.
- Inventory key (`Tab` / `I`): grid + equipment + sub-bags.
- Map key (`M`): full-screen world map with discovered chunks revealed.
- Compendium / Bestiary key **[VERIFY]**: tracks defeated enemies, recipes, fish caught, achievements.

## 20. Achievements

Categories (Core Keeper Steam): Boss kills (one per boss), exploration (biome reached), crafting milestones (tier reached), skill milestones (skill 100), fishing collection, cooking collection, pet collection, completionist.

---

## Parity verification checklist

When implementing The Sleeping Vein, every system above must be reproducible in our codebase. Items marked **[VERIFY]** require a return pass to either:
1. Confirm via a fresh wiki fetch when permissions allow, or
2. Confirm against a live Core Keeper session, or
3. Accept the closest documented value and proceed.

Until verified, treat any [VERIFY] number as a placeholder — name the constant in code so it can be changed centrally.

---

## Sources

- [Core Keeper Wiki (atma.gg) — Progression Guide](https://corekeeper.atma.gg/en/Progression_guide_for_items_and_bosses)
- [Core Keeper Wiki (atma.gg) — Bosses](https://corekeeper.atma.gg/en/Bosses)
- [Core Keeper Wiki (atma.gg) — Biomes](https://corekeeper.atma.gg/en/Biomes)
- [Core Keeper Wiki (fandom) — Skills](https://core-keeper.fandom.com/wiki/Skills)
- [Core Keeper Wiki (fandom) — Crafting](https://core-keeper.fandom.com/wiki/Crafting)
- [Core Keeper Wiki (fandom) — Workbenches](https://core-keeper.fandom.com/wiki/Workbenches)
- [Core Keeper Wiki (fandom) — Status Effects](https://core-keeper.fandom.com/wiki/Status_Effects)
- [XGamingServer — Boss Tracker (Void & Voltage 2026)](https://xgamingserver.com/tools/core-keeper/bosses)
- [BisectHosting — NPC Guide](https://www.bisecthosting.com/blog/core-keeper-npc-list-summon-items-inventory)
- [TheGamer — Boss Order Guide](https://www.thegamer.com/core-keeper-every-boss-complete-order/)
- [PCGamer — Boss Guide](https://www.pcgamer.com/core-keeper-bosses-guide/)
- [GrindNStrat — NPC Merchant Guide 2026 (v1.2)](https://grindnstrat.com/core-keeper-npc-merchant-guide/)
