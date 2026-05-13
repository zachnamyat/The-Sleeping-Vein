#!/usr/bin/env python3
"""Ticket 0.10 — batch wrapper for the AI image-generator plugin REST endpoint.

Reads `assets/manifest.json`, finds entries with `status: "needed"` whose
`source_prompt` exists on disk, and POSTs each prompt to a locally-running
Godot editor with the `ai_pixel_art_generator` plugin's REST server enabled.
The plugin saves the raw output under `assets/raw/<category>/`. We never
mark anything `final` here — that's a manual review step (per
docs/design/01_asset_pipeline.md Stages 4–6).

Usage:
    # Dry run: list every entry that would be generated.
    python tools/batch_generate.py --dry-run

    # Generate everything currently 'needed':
    python tools/batch_generate.py

    # Filter to a single phase, biome, or category:
    python tools/batch_generate.py --phase 0
    python tools/batch_generate.py --biome root_hollows
    python tools/batch_generate.py --category enemy

    # Generate just a few by id:
    python tools/batch_generate.py --id smoke_test_shaleseed --id ui_game_icon

    # Override REST endpoint (default http://127.0.0.1:8765/generate):
    python tools/batch_generate.py --endpoint http://127.0.0.1:8765/generate

The plugin endpoint is configured in the AI image-generator dock.
If the endpoint is offline this tool exits non-zero with a clear message.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Iterable
from urllib import request, error

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "assets" / "manifest.json"
DEFAULT_ENDPOINT = "http://127.0.0.1:8765/generate"


def load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def filter_entries(
    entries: list[dict],
    phase: int | None,
    biome: str | None,
    category: str | None,
    ids: list[str],
    include_done: bool,
) -> list[dict]:
    out: list[dict] = []
    id_set = set(ids)
    for e in entries:
        if id_set and e.get("id") not in id_set:
            continue
        if not include_done and e.get("status", "needed") == "final":
            continue
        if biome is not None and e.get("biome") != biome:
            continue
        if category is not None and e.get("category") != category:
            continue
        if phase is not None:
            ticket = str(e.get("ticket", ""))
            phase_num: int | None = None
            for token in ticket.replace("+", " ").split():
                if "." in token:
                    head = token.split(".")[0]
                    if head.isdigit():
                        phase_num = int(head)
                        break
                elif token.startswith("phase") and token[5:].isdigit():
                    phase_num = int(token[5:])
                    break
            if phase_num != phase:
                continue
        out.append(e)
    return out


def call_endpoint(endpoint: str, payload: dict, timeout: float) -> tuple[int, str]:
    body = json.dumps(payload).encode("utf-8")
    req = request.Request(endpoint, data=body, method="POST",
                          headers={"Content-Type": "application/json"})
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            return (resp.status, resp.read().decode("utf-8", errors="replace"))
    except error.HTTPError as e:
        return (e.code, e.read().decode("utf-8", errors="replace"))
    except error.URLError as e:
        return (0, f"URLError: {e.reason}")
    except OSError as e:
        return (0, f"OSError: {e}")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Batch-drive the AI image-generator plugin's REST endpoint.")
    ap.add_argument("--endpoint", default=DEFAULT_ENDPOINT,
                    help=f"REST POST endpoint (default {DEFAULT_ENDPOINT})")
    ap.add_argument("--phase", type=int, default=None, help="Only generate entries whose ticket is in this phase number")
    ap.add_argument("--biome", default=None, help="Only generate entries for this biome")
    ap.add_argument("--category", default=None, help="Only generate entries with this category (tile, enemy, npc, ...)")
    ap.add_argument("--id", action="append", default=[], help="Restrict to one or more manifest ids (repeatable)")
    ap.add_argument("--include-done", action="store_true", help="Also include entries already marked 'final'")
    ap.add_argument("--dry-run", action="store_true", help="List planned calls but make no requests")
    ap.add_argument("--delay", type=float, default=1.5, help="Seconds to sleep between calls (rate-limit guard)")
    ap.add_argument("--timeout", type=float, default=120.0, help="Per-request timeout in seconds")
    args = ap.parse_args(argv)

    manifest = load_manifest()
    entries = manifest.get("assets", [])
    targets = filter_entries(entries, args.phase, args.biome, args.category, args.id, args.include_done)

    if not targets:
        print("batch_generate: no manifest entries match the given filters.")
        return 0

    print(f"batch_generate: {len(targets)} entries planned (endpoint {args.endpoint}, dry_run={args.dry_run})")
    failures = 0
    for i, entry in enumerate(targets, 1):
        ent_id = entry.get("id", "?")
        prompt_rel = entry.get("source_prompt")
        if not prompt_rel:
            print(f"  [{i}/{len(targets)}] SKIP {ent_id}: no source_prompt in manifest")
            continue
        prompt_path = (REPO_ROOT / prompt_rel).resolve()
        if not prompt_path.exists():
            print(f"  [{i}/{len(targets)}] SKIP {ent_id}: prompt file missing at {prompt_rel}")
            failures += 1
            continue
        prompt_text = prompt_path.read_text(encoding="utf-8")
        payload = {
            "id": ent_id,
            "prompt": prompt_text,
            "out_dir": "assets/raw/" + (entry.get("category", "misc") or "misc"),
            "size": entry.get("size"),
            "frames": entry.get("frames"),
            "biome": entry.get("biome"),
            "ticket": entry.get("ticket"),
        }
        if args.dry_run:
            print(f"  [{i}/{len(targets)}] DRY-RUN {ent_id} ({prompt_rel}, size={payload['size']})")
            continue
        status, body = call_endpoint(args.endpoint, payload, args.timeout)
        if status == 200:
            print(f"  [{i}/{len(targets)}] OK   {ent_id}")
        else:
            failures += 1
            print(f"  [{i}/{len(targets)}] FAIL {ent_id}: status={status} body={body[:200]}")
        time.sleep(args.delay)

    if failures:
        print(f"batch_generate: {failures} failures")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
