# 02 — Lore-to-Mechanics Mapping

> **Decision.** Mechanically, The Sleeping Vein is Core Keeper. Narratively, it is AETHERDEEP: The Sunken Aeon (the lore bible in `lore/`). This document maps the two onto each other so that, when an engineer asks "is this mechanic in the game?", the answer is yes-with-a-different-name, or yes-extended, or no-because-we-cut-it.

---

## 0. Mapping principles

1. **Mechanics are inherited.** Core Keeper's systems are well-tuned; we duplicate behavior before we change it.
2. **Names are replaced.** Every Core Keeper proper noun maps to an Aetherdeep equivalent. The Core → the Resonance Loom. Glurch → Glaur-em. Etc.
3. **Tier ladders align 1:1.** Our 9 strata map to Core Keeper's 9-biome ring. Our 9 material tiers map to Copper → Solarite. The progression curve is the same shape.
4. **Bosses are recontextualized, not renamed at random.** Some Core Keeper bosses split, merge, or relocate to fit the seven-act story spine.
5. **The Anchor = "your base."** Not a literal Core Keeper Core; it's the player's home plateau, with the Resonance Loom as the central spawn structure (the "Core-like" object). The Aphelion is a *different* object — the dying sun visible at the world's center.
6. **Mortality model differs from Core Keeper.** In CK, you respawn at a bed. In Aetherdeep, you respawn at the Loom and consume an Aphelion sliver. Implementation is the same loop; the on-screen flavor is different.

---

## 1. World architecture map

| Core Keeper | Aetherdeep / The Sleeping Vein | Notes |
|-------------|-------------------------------|-------|
| The Core | The Resonance Loom | Single spawn structure on the Anchor plateau. Visually a half-buried pre-Inversion construct. |
| World origin | The Anchor | Player wakes here; NPCs settle here; build base here. |
| Biome rings | Strata (concentric inward) | Same shape but lore says player descends inward, not outward. UI compass points "down/in" instead of "out." |
| Border zones | Tunnel transitions | Soft mob density falloff, plus 1-2 short lore corridors per boundary. |
| Slime trail | Hollowling motes drift | Visual flavor for the "infection spreading" rune-paths. |
| Boss rune circles | Sovereign arenas / Vesari ritual circles / Diadem altars | Each biome's lore dictates the arena flavor. |

## 2. Biome map (9 strata)

| Strata (lore) | Position | Core Keeper analog | Mapping notes |
|---------------|----------|--------------------|---------------|
| **1. The Root Hollows** | Outermost | The Undergrounds (Dirt) | Tutorial. Mostly empty. Anchor sits here. |
| **2. The Glasswright Reaches** | 2nd | Clay Caves + Larva Hive | Crystal-and-pale-clay aesthetic; sub-biome = the sealed Quiet Forge. |
| **3. The Vesari Necropolis** | 3rd | Forgotten Ruins | Stone tablets, salt-bound undead (Vesari fossils), Hall of First Names. |
| **4. The Sunless Verdancy** | 4th | Azeos' Wilderness | Verdant biome with poison mechanics, mid-boss + boss structure. |
| **5. The Drowned Aphelion** | 5th | Sunken Sea | Underwater swim mechanic, optional Atlantean-equivalent boss (Drowned Crown). |
| **6. The Emberforge Strata** | 6th | Molten Quarry (sub) + Desert (boss flavor merged in) | Magma/heat mechanic, Pyrenkin forge architecture. |
| **7. The Salt Wastes of Dawning** | 7th | Desert of Beginnings | Day/night temperature swing instead of fixed heat; Wormbound choice unique to us. |
| **8. The Auroric Veil** | 8th | Shimmering Frontier | Cold mechanic, aurora-storm collective boss (Veyl-Aurora = analog of Hydras). |
| **9. The Final Spiral** | Innermost | The Passage + Breaker's Reach | Sunken Diadem stronghold. Multi-boss endgame culminates in the Aphelion choice. |

## 3. Boss map

We have **10 main + 3 optional / endgame** bosses; Core Keeper has **18**. Some Sovereign fights consolidate two CK bosses into a single multi-phase encounter to match the seven-act emotional spine.

| # | Lore boss | Stratum | Core Keeper analog | Encounter shape |
|---|-----------|---------|---------------------|------------------|
| 1 | Glaur-em the Engorged Stone-Father | Root Hollows | Glurch + Ghorm merged | 3 phases: slow slam → split → soft core. Single fight; absorbs Ghorm's "key item for Loom" role. |
| — | (Spawnmother — see #3) | — | Hive Mother | We move Hive Mother flavor into the Vesari Necropolis, see #3. |
| 2 | Vorr'kell the Tunnel Wyrm | Glasswright Reaches | Malugaz (Corrupted) | Tunneling phase + crystal-song phase. Drops Lantern. |
| 3 | Spawnmother of Carrion Hollows | Vesari Necropolis | Hive Mother (relocated) + Ivy add | Stationary swarm boss. Coral motif instead of larva. Drops Coral Veil. |
| 4 | Sythrenn the Toxic Bloom | Sunless Verdancy (mid) | Ivy the Poisonous Mass | Mid-biome boss. Has mercy-kill variant unique to us. |
| 5 | Auriax the Verdant Tyrant | Sunless Verdancy (boss) | Azeos the Sky Titan | 4-phase tree-form boss; soul-key Verdant Heart powers the Loom for stratum 6 descent. |
| 6 | Vol'thaar the Tide Sovereign | Drowned Aphelion | Omoroth + Morpha merged | Underwater 4-phase. Speaks. Has release/kill choice unique to us. |
| 6a | The Drowned Crown (optional) | Drowned Aphelion | Atlantean Worm | Optional pure-ghost fight. Replaces CK's Bait Pillar with a Vesari Sword-Pact item. |
| 7 | Skoldur the Forge-Forsaken | Emberforge | Igneous + Ra-Akar combined into single forge-king | Magma humanoid with hammer. Three-phase + recognition speech. |
| 8 | Naeren the Wandering Salt-Crown | Salt Wastes | (No direct CK analog) | Ours: split-fight or ritual-of-peace via Wormbound. Lore-original encounter. |
| 9 | Veyl-Aurora, the Singing Choir | Auroric Veil | Crydra + Druidra + Pyrdra + Nimruza (4 Hydras condensed) | Collective spire boss; 7 spires instead of 4 hydras, harmony-themed mechanics. |
| 10 | The Diadem-Bearer | Final Spiral | Core Commander + S.A.H.A.B.A.R merged | Mortal antagonist, 4 phases with Readers as adds. |
| 10a | The Aphelion (optional, ending B only) | Final Spiral | Oblidra the Void Lord | Bullet-hell / pattern-precision; only fought if player chooses to break the seal. |

### Boss-count gap
Core Keeper has 18 bosses; we have 10 main + 2 optional + 1 ending-locked = 13. The extra Core Keeper bosses (the four Hydras, Urschleim, the early-trio doubling, S.A.H.A.B.A.R) consolidate into multi-phase encounters in our roster. **This is intentional and supports the seven-act spine.** Don't pad our roster to hit 18 — instead, let our consolidated fights be longer and more story-loaded.

## 4. Material / tier map

| Tier | Our material | Core Keeper analog | Source stratum |
|------|--------------|---------------------|----------------|
| 0 | (Bare-hand resonance) | — | — |
| 1 | Shaleseed | Copper | Root Hollows |
| 2 | Clearstone | Tin | Glasswright Reaches |
| 3 | Saltbound iron | Iron | Vesari Necropolis |
| 4 | Heartwood + Spore-iron | Scarlet | Sunless Verdancy |
| 5 | Tideglass | Octarine | Drowned Aphelion |
| 6 | Ember-iron | Galaxite (partial) | Emberforge |
| 7 | Saltbound steel | Galaxite (sand-tier) / Solarite (early) | Salt Wastes |
| 8 | Auroric ice | Solarite | Auroric Veil |
| 9 | Diadem-gold | Pandorium / Void-tier (Void & Voltage) | Final Spiral |

The progression curve matches Core Keeper's. The damage / HP / armor numerical jumps per tier are inherited from the CK formulas (see `core-keeper-mechanics.md` §3.2). Lore re-skins the names; the math is identical.

## 5. Crafting station map

| Tier | Our station | CK analog |
|------|-------------|-----------|
| 0 | Loam Bench | Basic Workbench |
| 1 | Clearstone Forge | Copper Workbench |
| 2 | Saltbound Anvil | Tin Workbench |
| 3 | Verdant Cradle | Iron Workbench |
| 4 | Tideglass Loom | Scarlet Workbench |
| 5 | Pyrenkin Bellows | Octarine Workbench |
| 6 | Salt-Crown Press | Galaxite Workbench |
| 7 | Auroric Anvil | Solarite Workbench |
| 8 | Diadem Reliquary | Pandorium-tier station (CK has no Pandorium bench) |

Adjacent stations (cooking pot, anvil, sawmill, drying rack, bait workbench, carpenter's table) keep their CK names *or* take a thin lore re-skin if they ship to the player visibly (e.g. cooking pot is just "Cookpot" — no need to re-name everyday objects).

## 6. NPC map

Core Keeper has 6-7 merchants; our lore has many more named NPCs. Mapping:

| Aetherdeep NPC | CK merchant analog | Notes |
|----------------|---------------------|-------|
| Aelstren the Cartographer | (No CK direct — maps to the Cloaked Merchant / early-NPC slot) | First NPC arrival; provides map. |
| Brindle Quench-of-Coals | Smithing-tier merchant (extends Caveling Merchant) | Smith; arrives after first resonant ingot. |
| Mira-no-Last-Name | Storage / chest-organizing NPC | Storage clerk. Has the late-game emotional reveal. |
| The Cantor of Five Bells | Seasonal Merchant analog + lore-quest giver | Musician; assembles Sovereign-name song. |
| Old Hask | Fishing Merchant | Drowned Aphelion fisherman. |
| The Veiled Buyer | Cloaked Merchant (random spawn) | Variable-price buyer. |
| Korya the Returned | (No CK analog — unique to us) | Ambiguous previous-Walker NPC. |
| The Glasswright Remnant (collective) | Spirit Merchant (sealed) analog | Multi-NPC enclave behind Quiet Forge gate. |
| The Sunken Diadem agents | Hostile NPCs (Caveling shamans etc. analog) | Enemy mortals, not merchants. |
| Listeners-Below | (No CK direct analog) | Endgame masked traders. |
| Wormbound elders | (No CK direct analog) | Choice-encounter NPCs. |

Where Core Keeper has a generic merchant role we don't fill (e.g. seasonal events), we either implement it 1:1 (Seasonal Merchant ships) or substitute a lore-equivalent (the Cantor handles seasonal Aphelion festivals).

## 7. Skill map

Core Keeper's 12 skills map 1:1. We do not change skill names internally (`skill_mining`, `skill_melee`, etc. as `StringName` ids), but the UI labels are re-flavored:

| `StringName` | UI label (lore) | CK name |
|--------------|------------------|---------|
| `skill_mining` | Stratabreaking | Mining |
| `skill_running` | Walking | Running |
| `skill_melee` | Hand-Strike | Melee Combat |
| `skill_ranged` | Hand-Throw | Range Combat |
| `skill_vitality` | Anchoring | Vitality |
| `skill_crafting` | Form-Making | Crafting |
| `skill_gardening` | Tending | Gardening |
| `skill_fishing` | Listening | Fishing |
| `skill_cooking` | Hearth | Cooking |
| `skill_magic` | Resonance | Magic |
| `skill_summoning` | Calling | Summoning |
| `skill_explosives` | Bursting | Explosives |

Talent tree shapes match Core Keeper as closely as we can confirm. Where CK talents reference proper nouns (Stun Shot, Charging In), we keep the *effect* and re-name the talent in lore terms.

## 8. Item / relic map

Core Keeper's named relics map to our **Key Relics** roster in `lore/09_relics_artifacts_progression.md`. Quick map:

| Aetherdeep relic | CK analog | Function |
|-------------------|-----------|----------|
| Stone-Father's Pulse | Glurch Eye / Ghorm's Horn | First Loom power-up. |
| Vorr'kell's Lantern | Stolen Crystal Heart | Second Loom power-up. |
| Coral Veil | Coral Bow / sea-passage item | Underwater traversal. |
| Verdant Heart | Soul of Azeos | First "Soul" / Titan-equivalent. |
| Tide-Heart | Soul of Omoroth | Sea-Titan analog. |
| Skoldur's Hammer | Soul of Ra-Akar | Sand-Titan analog. |
| Choir's Resonance | Brood Void Neuron | Hydra-collective analog. |
| Shattered Diadem | Profane Override / endgame summon item | The ending key. |

## 9. Mechanic alignment summary

The implementation order in `ROADMAP.md` follows Core Keeper's mechanical ladder. The lore informs:

- Visual / palette / asset choices.
- NPC and dialogue content.
- Quest / objective text.
- Boss-fight beats and arena themes.
- World event scripting (Aphelion Beat, Hollowling outbreaks, Sovereign-name fragments).
- The seven-act narrative spine that gates content at specific boss kills.

Lore does *not* override:

- Damage / HP / armor / drop-rate math.
- Skill XP curves.
- Tile size, atlas layout, palette structure.
- Multiplayer architecture (1-8 player Core Keeper-equivalent).

If a lore decision conflicts with a mechanical baseline, **the mechanic wins** during parity phase. Once parity is complete (Phase 11 milestone), lore-driven mechanical extensions begin — but those are scoped explicitly per ticket.

## 10. Custom-feature staging

Per the project decision: **parity first, extensions second**. Mechanical extensions the user wants to add later (per the kickoff conversation) are scoped into Phase 12+ tickets in the kanban. Examples already implied by lore:

- The **Aphelion-sliver mortality cost** (lore §1.7) is *not* in Core Keeper. Implement as a parity-extension tracked in Phase 12.
- The **Sovereign-Naming sidequest** (lore §05) is *not* in CK. Phase 12.
- The **Resonance Echo / Listener** ghost-witness encounters (lore §11) — Phase 12.
- The **Wormbound peace option** and any other moral-choice forks — Phase 12.
- The **three endings (Restore / Break / Become)** — Phase 13 (endgame branch).

The kanban tracks these as `extension` tag tickets so they can be filtered separately from `parity` tickets.
