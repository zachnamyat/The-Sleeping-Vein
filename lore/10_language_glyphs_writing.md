# 10 — Languages and Glyphs of the Hollow

Aetherdeep features four canonical written languages and one elision-script. Each has a distinct visual form intended to be readable as "different language" at a glance, even without translation. Translation, where it occurs in-game, is partial — the Walker may piece together meaning fragment by fragment, mirroring how real archaeology surfaces lost languages.

This document is the reference for asset designers (tile murals, tablet glyphs, UI inscription elements), narrative designers (in-world signage), and accessibility designers (the translation UI).

## 10.1 Old Vesari

**Speakers (extinct):** First Vesari and Vesari Continuity.
**Setting:** Vesari Necropolis is dense with Old Vesari; tablets appear in trace amounts in every higher stratum (debris drifting outward).
**Visual character:** Flowing, curved, comma-like strokes connected by long underlines. Inscribed with chisel on stone or carved into bone. Reads right-to-left.
**Phonology hint:** Long vowels, soft consonants, frequent double-vowel diphthongs. Many words begin with "v," "th," or "ae."

**Sample vocabulary:**
- *vyrr* — the world (literally "the open palm")
- *vyrth-emar* — the open earth (the Root Hollows)
- *baeloth-thirim* — where light was shaped (the Glasswright Reaches)
- *threnos* — the place of remembered keels (Vesari Necropolis)
- *thrael-vaer* — the second sun (Drowned Aphelion)
- *aeonis* — long-lasting witness (a Sovereign, in pre-Inversion terms)
- *naer-emar* — the white that watches (Salt Wastes)
- *vyaeloth* — the cold that sings (Auroric Veil)
- *koreth-vaen* — the long hearth (Emberforge)
- *vol-emin-vol* — the green that lasts (Sunless Verdancy)

**Translation availability in-game:** The Walker can find a partial Old Vesari glossary in the Vesari Necropolis. Translation is incremental — each tablet the Walker collects adds words to the in-game translator UI. By the end of the Necropolis, ~60% of Old Vesari can be read; by mid-game ~85%; by endgame ~95%. The last 5% is plot-relevant and unlocks via specific lore items.

**Asset design note:** Each Old Vesari glyph in a mural should be drawn at minimum two strokes — never single-character. The flowing connector lines must visibly link adjacent glyphs into "words."

## 10.2 Concord Script

**Speakers (sealed):** Glasswright Concord; the Glasswright Remnant still uses it.
**Setting:** Glasswright Reaches; trace amounts in Vesari Necropolis (Concord traders).
**Visual character:** Geometric. Crystalline angular forms with internal "facets" — the glyphs look like tiny stained-glass panels. Reads top-to-bottom in columns, left-to-right between columns.
**Phonology hint:** Sharp consonants, terminal sibilants, three-syllable rhythm. Plural pronouns are grammatically obligatory in this dialect since the Suppression Wars (the Glasswrights stopped using singulars as a cultural mourning rite).

**Sample vocabulary:**
- *kerrith* — clearstone
- *kerrith-vaeon* — clearstone reach (the second stratum)
- *thirim* — light
- *fellis* — we (default plural pronoun; no singular survives)
- *moris-thirim* — light-of-mourning (a Glasswright concept of mournful light, applied to the dimming Aphelion)
- *vael-orrun* — the working / the act (a polite euphemism for the Inversion)

**Translation availability:** The Walker meets the Glasswright Remnant in Act Two and is taught Concord Script gradually through trade interactions. The Remnant teach in plural; the in-game translator UI shows the player's name in plural form when reading Concord Script ("Walker, fellis read").

**Asset design note:** Each Concord glyph has between three and seven facets. The internal facets carry phonological information; the outline carries semantic information. Asset designers should treat the outline as the "letter" and the facets as the "diacritic."

## 10.3 Pyrenkin Forge-Glyphs

**Speakers (extinct):** Pyrenkin Forgekeepers; Brindle Quench-of-Coals still reads them.
**Setting:** Emberforge Strata; rare in higher strata as Pyrenkin trade-marks.
**Visual character:** Stamp-glyphs. Each glyph is a single stamp-shape, intended to be impressed into hot iron. Glyphs are angular, modular, easy to forge. Reads left-to-right in single lines.
**Phonology hint:** Short syllables, hard consonants, glottal stops. Names tend to be two-syllable.

**Sample vocabulary:**
- *koreth* — hearth, by extension home
- *vaen* — long
- *brindle* — coal-quench (also a personal name; coincidence intended in-lore)
- *skoldur* — forge-master (a title that became Skoldur's proper name)
- *karom* — strike (the verb for forging; also for combat)
- *karom-vaen* — long strike (a Pyrenkin term for a sustained combat engagement)

**Translation availability:** Brindle, if at the Anchor, will translate stamps the Walker brings to her. There is no UI translator — Brindle is the translator. This is a deliberate design: it gives Brindle gameplay weight and reflects the Hollow's "language is people, not data" tone.

**Asset design note:** Forge-Glyphs are *single shape*. Each glyph should be drawable in one continuous chisel-stroke and should look the same impressed in iron as it does carved in stone.

## 10.4 Hymnal Sheet-Glyphs

**Speakers (extinct):** Aphelion Wardens (pre-Fall).
**Setting:** Hymnal Vaults in the Auroric Veil and Final Spiral. A scattered handful in the Glasswright Reaches (Glasswright-Warden cultural exchange during the Bright Aeon).
**Visual character:** Musical notation. Each glyph carries pitch, duration, and resonance-weight information. Looks like a hybrid of pre-Inversion musical notation and Concord Script (the Wardens borrowed Concord geometric forms for their notation). Reads left-to-right on staff-like lines.
**Phonology hint:** Not a spoken language. Hymnal glyphs are musical instructions, not phonological.

**Sample vocabulary:**
- *vaen-thirim* — long-light (a hymnal motif representing Aphelion-as-blessing)
- *moris-vaen-thirim* — long-light-of-mourning (the central motif of the Bright Aeon Hymn)
- *koreth-thirim* — hearth-light (a domestic motif used in everyday small-hymns)

**Translation availability:** The Walker collects Hymnal Sheet-Glyphs and brings them to the Cantor of Five Bells, who can play them on his bell-types. Playing a Hymn-glyph is a gameplay action; the Walker hears the music. This is the *only* way Hymnal Sheet-Glyphs convey meaning — they are heard, not read.

**Asset design note:** Hymnal Sheet-Glyphs are inherently musical; the audio team carries equal weight with visual designers on these assets. Each glyph should have both a visual file and an audio file. The visual is the score; the audio is the performance.

## 10.5 The Elision-Script

**Speakers:** Vael-Iorrion (the elided figure). Possibly the Listeners-Below.
**Setting:** A small number of tablets across all strata, deliberately scratched-out to hide their content. The Walker can recover the original glyphs by close examination of the gouge-patterns and the surrounding context.
**Visual character:** None displayable. The Elision-Script is, by definition, *the absence of glyphs*. Where it exists, there is only a scratched void. The recovery process involves identifying which glyphs once stood in that void.

**Translation availability:** The Walker recovers Elision-Script by piecing together un-scratched fragments across the game — a meta-puzzle that spans Acts Three through Seven. The final piece allows the Walker to spell *Vael-Iorrion* in Old Vesari, unlocking the final-act narrative gate.

**Lore note:** The Elision was performed by Vael-Iorrion themselves, after the Inversion, in an act of self-erasure. The cult that became the Sunken Diadem honored the elision; the Glasswright Remnant has not been able to undo it without help. The Walker's role in piecing together the Elided Name is the *one act* the Aphelion could not perform on its own — Vael-Iorrion's name needed an external witness to be re-spoken, and the Walker is that witness. This is the deep lore-engine of the entire game.

**Asset design note:** Elision-Script appears as deliberate gouge-marks on Vesari and Diadem tablets. The gouge-marks should be visually distinct from natural weathering — sharp, recent, and intentional. The recovery UI overlays the original glyph in a faint outline when the Walker has gathered enough surrounding context.

## 10.6 Language usage table

| Stratum | Old Vesari | Concord | Forge-Glyph | Hymnal | Elision |
|---------|------------|---------|-------------|--------|---------|
| 1 — Root Hollows | trace | trace | rare | none | none |
| 2 — Reaches | rare | dense | rare | rare | trace |
| 3 — Necropolis | dense | trace | trace | trace | dense |
| 4 — Verdancy | trace | trace | none | trace | rare |
| 5 — Drowned | dense | trace | none | none | dense |
| 6 — Emberforge | rare | trace | dense | none | rare |
| 7 — Salt Wastes | rare | none | none | none | trace |
| 8 — Auroric Veil | rare | trace | none | dense | trace |
| 9 — Final Spiral | dense | dense | rare | dense | dense |

## 10.7 NPC speech-style note

NPCs at the Anchor speak in English-equivalent (the game's player-facing language), but their *idioms* and *grammatical quirks* should reflect their cultural background:

- **Lattice Survivors:** double-negatives ("not unkind"), evasive, lots of small euphemisms.
- **Glasswright Remnant:** obligatory plurals ("we crafted that for you"), formal, slow-paced.
- **Pyrenkin descendants (Brindle):** short sentences, frequent oaths in Forge-Glyph names, blunt.
- **Wormbound:** very long pauses, hummed half-words, never use a pronoun for the speaker.
- **Listeners-Below:** riddles, rhetorical questions, never directly answer.

This is the responsibility of dialogue writers; the lore is a constraint, not a script.
