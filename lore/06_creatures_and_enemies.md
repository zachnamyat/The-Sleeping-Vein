# 06 — Creatures and Enemies

The Hollow's fauna fall into four categories:

1. **Pre-Inversion stock** — animals descended from creatures that lived on Vyrr's original surface, folded into the Hollow and adapted to the new environment.
2. **Hollow-native** — creatures that emerged after the Inversion, born from interactions between the Resonance Field and pre-Inversion fauna or matter.
3. **Hollowling-infected** — any creature from category 1 or 2 currently inhabited by Hollowling parasites. Most hostile creatures the player fights are in this category.
4. **Resonance Echoes** — manifestations of the Resonance Field given enough substance to interact with the player. Not "alive" in the conventional sense.

This document is a representative — not exhaustive — catalog. Each stratum will have ~10-15 creature types in final asset count; this document establishes the species archetypes and per-stratum families. Per-asset designers should treat this as the canonical bestiary skeleton.

## 6.1 General principles

**Visual identification of infection.** A Hollowling-infected creature shows three reliable visual markers: (1) gold-veined skin patterns, (2) too-still or jittering movement, (3) eye-glow at the Aphelion Beat. These markers must be readable at 16-pixel sprite scale.

**Behavioral pattern.** Infected creatures hunt with an unnatural focus. They will follow the Walker past their original territory edges, and they will ignore non-Walker prey to attack the Walker. This is canonically because the Hollowlings are *drawn* to Walker-resonance.

**Friendly fauna.** Roughly 30% of fauna are non-hostile and serve as either crafting-material sources (huntable, but only attack if attacked) or as ambient life. The Verdancy and Drowned Aphelion have the highest proportions of friendly fauna.

## 6.2 Per-stratum bestiary

### Stratum 1 — Root Hollows

**Hostile (infected):**
- *Stone-Hopper* — small infected lizard-equivalents that scurry along walls. Quick. Low HP. Spawn in groups.
- *Mossback* — sluggish infected mound-creatures. High HP, low damage. Wall-of-flesh.
- *Cracked One* — infected Lattice Survivor (rare and disturbing — once a person, now a Hollowling vessel). Mid HP, mid damage. Appears in Lattice ruins.

**Friendly:**
- *Loambeetle* — large slow beetle that produces *loam-wax* (crafting material). Will not attack unless attacked. Produces wax on a Beat cycle.
- *Pale Fox* — a small surface-stock canid-equivalent, descended from pre-Inversion foxes. Skittish. Will follow the Walker briefly. Cannot be tamed at this stratum but is the precursor to a tameable pet acquired later.

**Resonance Echo:**
- *The Listener* — a single rare apparition that appears once, in a specific Lattice ruin, and silently watches the Walker. Cannot be attacked. Disappears if approached. Foreshadows the Listeners-Below.

### Stratum 2 — Glasswright Reaches

**Hostile (infected):**
- *Glassglint* — infected crystal-skink. Reflects ranged attacks. Encourages melee.
- *Concord Wraith* — infected former Glasswright. Slow, ranged, casts soft pulse attacks.
- *Chime-Stalker* — infected predator-equivalent. Makes a faint chime when it hunts; audible cue for player.

**Friendly:**
- *Singing Moth* — produces wing-dust used in resonant powders. Harmless. Sings on the Beat.
- *Veinglass Spider* — large, slow, non-aggressive crystal-spider equivalent. Drops veinglass when destroyed but does not need to be killed for progress.

### Stratum 3 — Vesari Necropolis

**Hostile (Resonance Echo / Hollowling-infected):**
- *Salt-Bound Sailor* — Resonance Echo animating a Vesari fossil. Slow, formal in movement. Drops a "ship-bone" each kill.
- *Salt-Bound Captain* — rare, larger Salt-Bound. Carries an Echo-sword.
- *Coral-Hollow* — Spawnmother-spawned Hollowling vessel. Spider-like, fast.

**Friendly:**
- *Tideglass Cricket* — drops Necropolis-specific crafting reagents. Sings before dawn-equivalent.
- *Salt-Foxes* — feral descendants of the Lattice's Pale Foxes who migrated down. Skittish; can be befriended through repeated feeding.

### Stratum 4 — Sunless Verdancy

**Hostile (infected):**
- *Spore-Lurk* — infected fungus-creature. Releases poison clouds.
- *Vine-Stalker* — infected mid-size predator-equivalent. Camouflaged.
- *Bloom-Hag* — infected larger flora-creature. Stationary, ranged.

**Friendly:**
- *Verdant Hare* — small, common, ambient. Drops nothing but visually populates the biome.
- *Glow-Crane* — long-legged bird-equivalent that walks slowly through the Verdancy. Will not flee from the Walker. Drops *crane-feathers* if hunted, but Brindle Quench-of-Coals has a small subquest if the Walker has refrained from killing one (you can recognize tracked-feather inventory).

### Stratum 5 — Drowned Aphelion

**Hostile (infected):**
- *Deep-Mawl* — infected predator-fish-equivalent. Fast, lunging.
- *Hollow Coral* — infected Spawnmother-coral that has spread to this stratum. Stationary, ranged.
- *Wreck-Wraith* — Resonance Echo of a drowned Vesari sailor. Underwater.

**Friendly:**
- *Lantern Squid* — slow, large, non-hostile. Provides light source in dark trenches.
- *Brinekin* — small fish-equivalents that follow the Walker briefly. Drop nothing. Population-ambient only.

### Stratum 6 — Emberforge Strata

**Hostile (infected):**
- *Slag-Hound* — infected forge-animal. Fast, melee, leaves burning ground.
- *Forge-Echo* — Resonance Echo of a Pyrenkin smith. Wields ghost-hammer.
- *Ember-Lurker* — infected ground-dweller. Burrows and ambushes.

**Friendly:**
- *Forge-Cricket* — heat-resistant insect. Produces fuel-pellets.
- *Charred Goat* — surviving Pyrenkin domesticated stock. Wild now, skittish. Befriendable through feeding.

### Stratum 7 — Salt Wastes of Dawning

**Hostile (infected):**
- *Salt-Hopper* — infected long-legged jumper. Long range, slow turning.
- *Dawning Predator* — large, infected, surface-burrower (sand-shark-equivalent).
- *Wormbound Stalker* — a Wormbound who has refused symbiosis and fallen instead to Hollowling infection. Tragic enemy type. Always solo. Slow.

**Friendly:**
- *The Wormbound themselves* — non-hostile unless attacked. Detailed in [03_factions_and_civilizations.md](03_factions_and_civilizations.md) §3.2.3.
- *Salt-Cat* — small, common, ambient. Skittish.

### Stratum 8 — Auroric Veil

**Hostile (Resonance Echo / infected):**
- *Aurora-Wisp* — Resonance Echo. Floats. Ranged.
- *Cold Hollow* — infected ice-creature. Slow but heavy-hitting.
- *Sunken Diadem agent* — first appearances of the cult's foot soldiers. Mortal humans in golden masks. Use sword and Aphelion-shard projectiles.

**Friendly:**
- *Frostlark* — small bird-equivalent. Sings on the Beat in three-part harmony with two unseen companions (a clue: the Choir of seven is fragmented across the biome).
- *Aurora-Vole* — small ambient burrower.

### Stratum 9 — Final Spiral

**Hostile:**
- *Diadem-Reader* — Sunken Diadem mid-rank operative. Several named subtypes (First, Second, Third, etc.).
- *Diadem-Censer* — ranged Diadem support unit. Heals other Diadem agents.
- *Diadem-Warden* — heavy Diadem unit. Slow, armored.
- *Pure Hollowling Mote* — a free Hollowling not yet anchored to a host. Rare, fast, soft, dangerous in numbers.
- *Vacancy* — extremely rare. A Resonance Echo of someone whose name has been elided. Encountered once, in the final corridor. Cannot be reliably attacked. Will not harm the Walker. Will silently follow.

**Friendly:**
- None canonical. The Final Spiral is sterile.

## 6.3 Hollowling biology (technical note)

For systems designers: Hollowling-infected creatures should be visually distinct from base creatures via a single shader overlay (gold vein highlights, eye-glow on Beat). The base creature sprite is preserved in the Lattice Survivors' bestiary tablets (a lore-justified compendium UI element). Hollowling motes themselves are tiny, soft, slow particles when free, and should never appear without context (i.e., they always emerge from a Suncrack, a corrupted source, or a defeated infected creature).

## 6.4 Tameable companion roster

The Walker can befriend up to four ambient creatures across the game, who follow the Walker passively and provide minor utility:

| Species (after sufficient befriending) | Stratum first met | Utility |
|--|--|--|
| Pale Fox (matures to Lattice Fox) | Root Hollows | Highlights nearby ore veins |
| Singing Moth | Glasswright Reaches | Slow Aphelion-Beat-synced soft light source |
| Glow-Crane (if not hunted) | Sunless Verdancy | Reveals environmental Echoes when nearby |
| Charred Goat (if befriended) | Emberforge | Carries an extra small inventory |

These companions are non-combat and are a soft cozy-game feature in keeping with the "cozy-meets-funereal" tone defined in the README.

## 6.5 Boss-only minions (referenced in 05)

The bosses in document 05 summon specific minion types that do not appear in normal encounters:

- *Glaur-em's Stoneslough* (Boss 1)
- *Vorr'kell's Crystal Larvae* (Boss 2)
- *Spawnmother's Carrion Hatchlings* (Boss 3)
- *Sythrenn's Bloomling* (Boss 4)
- *Auriax's Wither-Roots* (Boss 5)
- *Vol'thaar's Tentacle-Echoes* (Boss 6)
- *Skoldur's Hammer-Shades* (Boss 7)
- *Naeren's Salt-Splinters* (Boss 8, standard path only)
- *Veyl-Aurora's Spire-Voice* (Boss 9, encountered as the spire bodies)
- *Drowned Crown's Drowned Subjects* (Boss 10)
- *Diadem-Bearer's Readers* (Boss 11; First, Second, Third)
- *Aphelion light-pattern entities* (Boss 12)

Each is sprite-distinct from the boss and from base bestiary creatures.
