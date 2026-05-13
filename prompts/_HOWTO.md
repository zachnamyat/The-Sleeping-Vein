# Prompt Files — How To Use This Directory

Audience: **Google Antigravity** (and any future agent) that picks up an "art"-tagged kanban ticket and is expected to generate the listed assets autonomously.

This directory holds the **canonical Gemini prompts** for every Gemini-generated asset in The Sleeping Vein. One asset → one `.txt` file. The kanban ticket's `desc` field tells you which prompt file to use; this file tells you what to do with it.

---

## 1. Pre-flight (read once per session)

Before generating anything, load these three docs into context:

1. `lore/README.md` — index of the canonical lore. Each prompt's `LORE:` block already references the relevant section, but read the section it points to before you generate.
2. `docs/design/00_tile_atlas_spec.md` — canonical pixel sizes, row layouts, and the per-biome palette ramps.
3. `docs/design/01_asset_pipeline.md` — the six-stage workflow (Spec → Prompt → Generate → Post-process → Register → Import).

If any field in a prompt file disagrees with these specs, the spec wins. Flag the conflict in the response before regenerating.

## 2. One ticket = one or more assets

A kanban ticket's `desc` lists the assets it owns and points to one prompt file per asset (sometimes one file produces multiple assets — e.g. a biome atlas is one PNG covering 256 tiles).

For each asset in a ticket:

1. **Read** the prompt file referenced in the ticket.
2. **Generate** via `gemini-2.5-flash-image` at the source resolution noted in the prompt (default 1024×1024, larger for some atlases — the prompt file states this). Polish passes: 1 unless the prompt says "hero — 2 passes".
3. **Save raw** to `assets/raw/<category>/<id>_v1.png`. If you regenerate, increment to `_v2`, `_v3`, etc. — never overwrite.
4. **Post-process** per `docs/design/01_asset_pipeline.md` Stage 4:
   - Key out the magenta background (`#FF00FF` → transparent).
   - Trim/center to the canonical bounding box.
   - Downsample (nearest-neighbor) from source to final size — 64× for most assets.
   - Verify palette: every non-transparent pixel must match the biome ramp or AAP-64 shared colors.
5. **Save final** to `assets/sprites/<category>/<id>.png`.
6. **Update the manifest** (`assets/manifest.json`): find the entry with this `id` (it already exists with `status: "needed"`), and update:
   - `status` → `"final"`
   - `raw_versions` → list of the `_vN` files you kept
   - `chosen_version` → the `vN` that became the final
   - `notes` → anything worth flagging (e.g. "Gemini struggled with autotile alignment; chose v3 after 2 retries")

## 3. Prompt file format

Every prompt file follows the template in `docs/design/01_asset_pipeline.md` §Stage 2. The blocks are:

- `SUBJECT:` — what the asset is, in canonical lore terms
- `STYLE:` — the pixel-art style boilerplate (identical across all prompts)
- `COMPOSITION:` — framing, padding, background color
- `SIZE:` — source resolution + downsample ratio + final size
- `PALETTE:` — restricted color list (hex values)
- `LORE:` — 2–3 sentences of canonical lore, with a link back to `lore/`
- `ANTI-PROMPT:` — what to suppress

Sprite strips and tile sheets get extra blocks: `ANIMATION:` (for strips) or `AUTOTILE:` / `ROW LAYOUT:` (for atlases).

**Don't paraphrase prompts before sending them to Gemini.** Paste the file verbatim. If you think a prompt is wrong, fix the file and commit it — don't silently rephrase.

## 4. What NOT to do

- ❌ Don't invent lore. If a prompt feels under-specified, read the linked lore section. If it's truly silent, add an entry to `docs/design/_open_questions.md` (create the file if missing) and surface the gap in your reply.
- ❌ Don't generate assets that don't have a corresponding `"needed"` entry in `assets/manifest.json` and a prompt file in this directory. If the kanban ticket asks for something un-prompted, write the prompt file first, get user sign-off, then generate.
- ❌ Don't bypass the palette restriction. Out-of-palette pixels are a hard fail in the import checklist.
- ❌ Don't overwrite `_vN` raw files. Keep history.

## 5. Conventions for new prompts (if you have to write one)

If the kanban ticket points to a prompt file that doesn't exist yet, draft it before generating:

```
SUBJECT: <one-sentence subject in canonical lore terms>
STYLE: 16-bit pixel art, top-down 2D with a slight 3/4 lean. Hard pixel edges, nearest-neighbor scaling, no anti-aliasing, no gradient ramps, no soft shadows. Inspired visually by Core Keeper / Stardew Valley / Songs of Conquest pixel-art density.
COMPOSITION: Subject centered with 1 pixel of padding. Solid magenta background (#FF00FF) which we will key out.
SIZE: Output <SOURCE>×<SOURCE>. Downsample 64× nearest-neighbor to <TARGET>×<TARGET>.
PALETTE: Restrict to <PALETTE_NAME> (<hex hex hex hex hex hex>) plus pure black (#000000) and pure magenta (#FF00FF) for background only.
LORE: <2–3 sentence brief, with a link to lore/<file>.md#<anchor>>
ANTI-PROMPT: photorealism, soft shadows, blur, anti-aliasing, gradient skies, sub-pixel detail, watermark, signature, text, frame, border.
```

For animation strips, append the `ANIMATION:` block from `docs/design/01_asset_pipeline.md`. For tile atlases, copy the `ROW LAYOUT:` block from `prompts/tiles/_BIOME_ATLAS_TEMPLATE.txt`.

---

If anything in this file is unclear or contradicts the codebase, prefer the codebase and update this file in the same change.
