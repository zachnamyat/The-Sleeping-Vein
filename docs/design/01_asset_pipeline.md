# 01 — Asset Pipeline (Gemini → Godot)

> Companion to [00_tile_atlas_spec.md](00_tile_atlas_spec.md). That doc says **what sizes** to generate. This doc says **how to generate, post-process, and register** them.

The only tool that authors art for The Sleeping Vein is **Google Gemini 2.5 Flash Image (a.k.a. Nano Banana)**, accessed via the Anthropic / Claude image-gen MCP. After generation, every sprite is post-processed through ImageMagick to chroma-key the magenta background to transparency.

---

## 1. Pipeline overview

```
Gemini prompt  →  raw PNG (1024x1024 with #FF00FF bg)
                                   ↓
                                   ↓  sharp/Pillow (via gemini-image MCP)
                                   ↓     - crop to specific frame/grid cell
                                   ↓     - resize nearest-neighbor to target size
                                   ↓     - initial chroma-key (loose)
                                   ↓
                       processed PNG (target size, alpha-keyed)
                                   ↓
                                   ↓  tools/clean_alpha.ps1 (ImageMagick)
                                   ↓     - re-chroma-key with multi-shade fuzz
                                   ↓     - skip if already alpha-clean
                                   ↓
                       final PNG  →  assets/sprites/<category>/<id>.png
                                   ↓
                                   ↓  manifest.json entry (status: "final")
                                   ↓
                       in-game via res:// path
```

---

## 2. Generation (Gemini)

Every art request goes through six stages. Skipping any stage = the asset gets kicked back to `raw/`.

### Stage 1 — Spec

Open the relevant design doc in `docs/design/` (or create one). Fill in for every needed asset:

- **id** (snake_case, used as filename and manifest key)
- **target pixel size** (must match a row in `00_tile_atlas_spec.md` §1)
- **frame count** (for animated sprites)
- **lore reference** (path + anchor into `lore/`)
- **palette** (global or biome ramp from `00_tile_atlas_spec.md` §6)
- **prompt** (full text — see Stage 2)

### Stage 2 — Prompt

Prompts live as text files in `prompts/<category>/<asset_id>.txt`. **Never** inline prompts in Godot scenes or `.gd` code.

Required blocks: `SUBJECT`, `STYLE`, `COMPOSITION`, `SIZE`, `PALETTE`, `LORE`, `ANTI-PROMPT`.

For multi-frame strips append `ANIMATION:`. For tile sheets append `ROW LAYOUT:` per `prompts/tiles/_BIOME_ATLAS_TEMPLATE.txt`.

**Background color contract:** every prompt requests `#FF00FF` magenta as the background. In practice Gemini generates a *range* of magentas (pure `#FF00FF` down through `#E84080`/`#FB2D83` shades depending on per-image variation). The post-process pipeline (Stage 3) handles all of these.

### Stage 3 — Post-process

The Anthropic / Claude image-gen MCP's `process_image` tool handles the first pass:

```jsonc
{
  "imagePath": "assets/raw/category/asset_v1.png",
  "crop": { "left": X, "top": Y, "width": W, "height": H },
  "resize": { "width": TX, "height": TY },
  "removeBackground": { "color": "#FF00FF", "tolerance": 70 },
  "filename": "asset",
  "outputDir": "assets/sprites/category"
}
```

Then a SECOND pass via `tools/clean_alpha.ps1` (PowerShell + ImageMagick) catches any magenta the first pass missed:

```powershell
.\tools\clean_alpha.ps1                          # process every PNG under assets/sprites/
.\tools\clean_alpha.ps1 -Path src.png            # one file in place
.\tools\clean_alpha.ps1 -Path src.png -Dst d.png # one file, separate dst
.\tools\clean_alpha.ps1 -Dry                     # report only
```

How `clean_alpha.ps1` works:
1. For each PNG, samples the top-left and bottom-right corner pixels via `magick -format "%[pixel:p{X,Y}]"`.
2. If neither corner is "near magenta" (R>200, G<100, B>100) it skips the file — it's already clean.
3. Otherwise runs `magick -fuzz 22% -transparent` against five known magenta variants (`#FF00FF`, `#E84080`, `#FB2D83`, `#FF1493`, `#C70066`) in sequence. The `-fuzz 22%` is a proper color-distance threshold with anti-alias handling, far cleaner than a flat per-channel chroma-key.

### Stage 4 — Frame slicing (sprite strips only)

For animation strips, after the chroma-key step verify each frame is exactly `<frame_px>` wide and the strip is `<frame_px × frame_count>` wide.

### Stage 5 — Register

Append to `assets/manifest.json`. Status flow: `needed` → `draft` (raw saved, not finalized) → `final`. Layout per file:

```jsonc
{
  "id": "tile_root_hollows_floor",
  "path": "assets/sprites/tiles/root_hollows_atlas_16.png",
  "size": [256, 256],
  "frames": 1,
  "category": "tile",
  "biome": "root_hollows",
  "lore_ref": "lore/04_biomes.md#stratum-1--the-root-hollows",
  "source_prompt": "prompts/tiles/root_hollows_atlas.txt",
  "raw_versions": [
    "assets/raw/tiles/root_hollows_atlas_v1.png",
    "assets/raw/tiles/root_hollows_atlas_v3.png"
  ],
  "chosen_version": "v3",
  "status": "final",
  "notes": ""
}
```

### Stage 6 — Import & verify

1. Move the final PNG into its `assets/sprites/<category>/` location.
2. In Godot, the import will trigger automatically. Verify:
   - **Filter** = `Nearest`
   - **Mipmaps** = `Off`
   - **Fix Alpha Border** = `On`
3. For sprite strips: wrap the texture in a `SpriteFrames` resource at `resources/sprites/<asset_id>.tres`.
4. Reference in code via `preload()` of the `.tres`, not the raw PNG, to keep import settings centralized.

---

## 3. Per-asset folder convention

```
assets/
├── raw/                              <- Gemini outputs, before post-process
│   ├── tiles/
│   ├── player/
│   ├── enemies/
│   ├── items/
│   ├── ui/
│   └── vfx/
├── sprites/                          <- final, in-game ready
│   ├── tiles/<biome_id>_atlas_*.png
│   ├── player/walker_<state>.png
│   ├── enemies/<biome_id>/<mob_id>.png
│   ├── items/<tier>/<item_id>.png
│   ├── ui/<element_id>.png
│   └── vfx/<effect_id>.png
├── audio/
├── fonts/
└── manifest.json
```

The `assets/raw/` folder is `.gdignore`-d so Godot doesn't try to import the working files.

---

## 4. Versioning & iteration

- All Gemini outputs go to `raw/` with a `_vN` suffix.
- Keep every version that wasn't immediately broken — they're cheap and useful for A/B comparison.
- The "chosen" version is recorded in the manifest. If we change our minds, swap the chosen version, regenerate the final, and bump a `revision` counter in the manifest.
- Never delete a `_vN` raw file without checking it's not the `chosen_version`.

---

## 5. Why the two-stage chroma-key

Earlier in the project we used a single sharp/Pillow chroma-key pass with various `tolerance` values (25 / 70 / 90 / 100). That was fragile:

- **tolerance ≤ 30** missed Gemini's actual non-pure-magenta backgrounds, leaving visible pink rectangles around sprites.
- **tolerance ≥ 90** caught warm skin tones and red wood-grain, making sprites semi-transparent in the body.
- **tolerance 70** turned out to be the sweet spot for *most* generations — but not robustly across the whole library, because Gemini's per-image bg color drifts.

ImageMagick's `-fuzz` operates in a proper color-distance space and handles anti-aliased edges correctly, which is why `clean_alpha.ps1` re-runs it against five known bg variants instead of guessing one tolerance.

The choice of **ImageMagick over LibreSprite/Aseprite scripting:** LibreSprite's batch CLI scripting API exposes only `app.open()` returning a sprite handle with `.close` — no pixel manipulation. Aseprite ($20) has a richer Lua API but isn't installed. ImageMagick is free, MIT-licensed, ~30 MB, and the `-fuzz N% -transparent` operation is the same one used by every CDN/web image pipeline in production. It is the right tool.

---

## 6. Cost & rate-limit budget

Gemini 2.5 Flash Image is metered. Rough budget (price as of plan check, **[VERIFY]**):

- ~$0.04 per image, 1024×1024, single polish pass.
- 2304 tile atlas cells, generated in batches of 47-tile sheets: ~50 batches × $0.04 = ~$2.
- Per-biome individual tiles (mobs, decos, items): ~150 per biome × 9 biomes = 1350 × $0.04 = ~$54.
- Bosses (10 main + sub-bosses, 6 frames each animation × 4 anims): ~240 frames × $0.04 = ~$10.
- UI, VFX, fonts, audio waveform art: ~$10.

**Order-of-magnitude target: ~$100–$200 of Gemini credits for the full art pass.** Cheaper if you're disciplined about prompt iteration and reuse `raw/` versions.

Rate-limits: respect Gemini's default RPM.

---

## 7. The "Gemini can't draw it" escape hatch

Some sprites Gemini will fight you on — particularly tightly-constrained autotile sheets, complex multi-frame animations, and very tiny 16×16 items with high detail. For these:

1. Generate the **silhouette / pose** in Gemini (less constrained).
2. Hand-pixel the final 16×16 in **Aseprite** using Gemini's output as reference.

This is a fallback, not the default. Track these assets in the manifest with `status: "hybrid"` and `notes: "Gemini silhouette + Aseprite pass"` so we can revisit them once Gemini improves.

If hybrid count grows past ~5% of total assets, escalate — the prompt/template strategy is failing.

---

## 8. Lore enforcement

Every asset has a `lore_ref` field pointing into `lore/`. Before generating:

1. Read the lore section the asset references.
2. Make sure the prompt language uses **canonical names and visual hints** from that section.
3. Never invent new lore in a prompt. If the lore section is silent on a detail (e.g. "what does a Pale Cap mushroom look like?"), surface the gap as an open question (`docs/design/_open_questions.md`) instead of inventing it.

Gemini will happily make up details. Our job is to constrain it to canon.
