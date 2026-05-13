<!-- Ticket 0.20 — PR template -->

## Summary

<!-- One or two sentences. Link the kanban ticket id (e.g. #5.2) and any lore refs. -->

## What changed

- 

## How to test

<!-- Concrete steps. If a ticket exit criterion exists in ROADMAP.md, restate it here. -->
- [ ] 
- [ ] 

## Asset / lore impact

- [ ] No new assets, OR new entries added to `assets/manifest.json` with `status: "needed"`/`"final"` and a `source_prompt` path.
- [ ] No new lore invented inline. (If lore was extended, the relevant `lore/*.md` file is updated in the same PR.)

## Save compatibility

- [ ] Save format unchanged, OR `SaveSystem.SAVE_VERSION` bumped + migration added under `scripts/systems/save_migrations/`.

## Tests

- [ ] `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit` passes locally.
