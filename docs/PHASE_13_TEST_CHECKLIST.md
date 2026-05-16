# Phase 13 — Manual Test Checklist

> Companion to `tests/unit/test_phase13_systems.gd` (63 GUT cases). This file
> covers the play-through, networking, and UI checks that can't be automated
> headlessly. A real two-machine (or two-process) test pass is the only way to
> exercise the ENet path end-to-end.

**Save format:** v11 (bumped from v10). Older saves load with empty net_system
+ phase13_helpers blocks — PvP defaults to OFF, shared XP defaults to ON, loot
mode defaults to FFA, nameplate defaults visible, no recent hosts, no chat
scrollback.

**Keys to know:**
- **Enter** — open / close chat (`toggle_chat`).
- **Tab** — place ping at cursor world position (`ping_marker`).
- **Y** — toggle the party HUD (auto-shows on any peer connect).
- **V** — push-to-talk (`voice_ptt` — stub; the binding is reserved).
- **Insert** — open the emote wheel (`emote_wheel`).

**Toggles in the lobby panel (host-side):**
- Slot colour (8 options — Aphelion gold / Emberforge red / Glasswright blue
  / Verdancy green / Auroric purple / Vesari pink / Salt salt / Pyrenkin
  orange).
- PvP enabled (off by default).
- Shared XP (on by default).
- Loot mode (FFA / Round-robin / Need-Greed).
- World password (optional; 32-bit FNV-1a hash persisted, cleartext never
  hits the save).

---

## 1. Lobby + connection (13.1, 13.18, 13.19, 13.51, 13.52)

- [ ] Open the LobbyPanel from the title-screen "Multiplayer" entry.
- [ ] Click **Host** without a password. Toast reads "Hosting on 4242."
- [ ] Confirm `NetSystem.is_host` is true and `NetSystem.is_online()` is true
  in the dev console.
- [ ] Stop hosting, then host with a password. The host's
  `world_password_hash` is non-zero in the dev console.
- [ ] On a second client, attempt to **Join** with a wrong password. The
  client sees no special error toast yet but does receive a disconnect.
- [ ] Join with the correct password. Both clients see each other in the
  Players list.
- [ ] Click **Mark Ready** on each client. The label flips to "Cancel Ready".
- [ ] Click **Start World** on the host before both are ready. Toast reads
  "Not all players are ready."
- [ ] Both clients ready, host clicks Start. Lobby closes; the world scene
  loads.

## 2. Multi-Walker spawn at Loom (13.3)

- [ ] Both Walkers spawn at the bound Loom (or world origin if no Loom has
  been bound yet) in a small ring formation — slot 0 = host position, slot 1
  offset by ~24 px on the slot-angle.
- [ ] Each Walker carries its own inventory; mining loam grants XP only to
  the active Walker if shared XP is OFF, or splits per the shared-XP code
  path when ON.

## 3. Party HUD + ping (13.25, 13.27, 13.44)

- [ ] Press **Y** — the PartyHUD (top right) toggles visibility.
- [ ] Confirm each row shows: slot colour swatch + name + HP bar + ping ms.
- [ ] Stand near a peer and press **Tab** to place a default ping. A glowing
  cyan-gold dot appears at the cursor world position; expires after 7 s.
- [ ] Place ping kinds via DevConsole / debug bind (default / danger /
  attack_here / defend_here / on_my_way) and confirm each has its own colour
  + glyph and fades over the last 20% of its lifetime.
- [ ] Spam Tab; the second ping within 1 s is rejected (cooldown).
- [ ] Disconnect one client. Their row vanishes from the PartyHUD; their
  ping records are pruned within 1 frame.

## 4. Chat + whisper + history (13.15, 13.29, 13.30, 13.37)

- [ ] Press **Enter**. The chat panel opens. Type `hi all`, press Enter.
  Other clients receive the message in white on the All channel.
- [ ] Type `/party only-the-party`. The text fires on the party channel
  (green tint).
- [ ] Type `/w 2 psst`. The message appears in the whisper channel (pink)
  for both sender + recipient peers only.
- [ ] Press **↑** in the chat input. The previous message recalls in the
  text field. Press **↓** to clear.
- [ ] Trigger an NPC dialogue (e.g. talk to Aelstren). The system channel
  prints `[NPC npc_aelstren] …`.
- [ ] Type 250 messages quickly; the scroll-back ring caps at 200.

## 5. Emote system (13.5, 13.49)

- [ ] Press **Insert**. The emote wheel opens with 5 default options (wave /
  dance / sit / point / sleep). Click "Wave".
- [ ] The local Walker plays the wave emote (3 s active state). Remote
  clients see the emote bubble + the wave animation on the peer.
- [ ] Confirm the 11-emote roster (wave / dance / sit / point / sleep /
  laugh / cry / yes / no / on_my_way / thanks) is registered in
  `Phase13Helpers.EMOTES`.

## 6. Trade (13.14, 3.39, 9.63)

- [ ] Right-click another Walker → "Trade". The TradePanel opens for both
  players.
- [ ] Drag a stack of wood into the self-offer slots. The partner sees it
  appear on the partner-offer column.
- [ ] Attempt to drag a soulbound item (e.g. brindle_pendant). The toast
  reads "That item is soul-bound. It cannot leave you." and the slot stays
  empty.
- [ ] Same test with a resonance-bound item (e.g. small_fishhook,
  map_fragment) — same rejection.
- [ ] Both click **Lock**, then both click **Confirm**. The items swap
  inventories and the toast reads "Trade complete."
- [ ] Click **Cancel** mid-trade — both offers vanish, no items lost.

## 7. PvP toggle (13.13)

- [ ] In the lobby, enable PvP. Confirm `GameState.net_pvp_enabled` flips
  true.
- [ ] In-world, attack another Walker. With PvP on, the hit registers; with
  PvP off, the swing whiffs.

## 8. Loot rules (13.22, 13.40)

- [ ] Switch lobby loot mode to **Round-robin**.
- [ ] Kill a mob. Confirm only the mob's killer can pick up the drop during
  the 3 s ownership window.
- [ ] After 3 s, anyone can pick it up.
- [ ] Switch to **FFA**. Anyone can immediately pick up any drop.
- [ ] Switch to **Need-Greed**. Drops appear with a roll prompt before any
  pickup is allowed.

## 9. Boss HP scaling (13.10)

- [ ] Solo-spawn Glaur-em. HP = mob_def.max_health × 1.0.
- [ ] Connect a second client and respawn Glaur-em. New HP =
  mob_def.max_health × 1.4.
- [ ] At 8 connected players, HP = mob_def.max_health × 3.0 (cap).
- [ ] Confirm `NetSystem.boss_hp_multiplier()` returns the expected value at
  each player count.

## 10. Resurrection altar (13.24)

- [ ] Craft the Resurrection Altar (Auroric Anvil; 2 Aphelion Shards + 4
  Diadem Gold Plate + 6 Auroric Ice Ore). Place it near the Anchor.
- [ ] Let a party member die. They enter `awaiting_respawn` with a 6 s
  countdown.
- [ ] Interact with the Altar (E). The panel lists the dead peer. Click
  **Revive**. The peer's timer collapses to 0.1 s and they respawn on the
  spot.
- [ ] Toast reads "Revival pulse sent."

## 11. Spectator + respawn countdown (13.23, 13.38)

- [ ] Die in a party of two. The SpectatorCam HUD appears at the top of the
  screen showing "Spectating: <peer name>" + "Respawn in 6.0s" countdown.
- [ ] Press **D / →** to cycle to the next live peer.
- [ ] When the timer drains, the Walker respawns at the Loom and the cam
  closes.

## 12. Off-screen tracking arrows (13.26)

- [ ] In a 2-player party, walk far from your partner. A coloured arrow
  appears at the viewport edge pointing in their direction, with their name
  + distance label.
- [ ] As they re-enter the viewport, the arrow disappears.

## 13. NPC density bonus (13.6)

- [ ] In a 2-player party, confirm `Phase13Helpers.bonus_npc_slots()` =
  **1**. The Anchor can host one extra NPC (the Veiled Buyer can roll one
  extra appearance, etc.).
- [ ] In a 5-player party, `bonus_npc_slots()` = **4** (cap).

## 14. Resonance-pulse hand flicker (13.4, 13.36, 13.49)

- [ ] Stand within 96 px of another Walker. Both Walkers' hand-of-light
  auras gain a slow 1.4 s flicker animation (lore §7.6).
- [ ] Step beyond 96 px — the flicker stops.

## 15. Player nameplate (1.23, 13.36)

- [ ] Confirm each Walker has a nameplate above their head showing slot
  colour + name.
- [ ] Press **F** (or use Settings → Multiplayer → "Show nameplates" toggle)
  to disable nameplates. Both local and remote nameplates hide.
- [ ] On Walker death, the dying Walker's nameplate flickers for 2 s
  (lore §7.10 shared death-flicker).

## 16. Mid-session join + snapshot (13.41)

- [ ] Host a world solo. Defeat Glaur-em. Continue exploring.
- [ ] Have a second client join mid-game. They receive the
  `joined_mid_session` snapshot containing the host's slivers, defeated
  bosses, day phase, toggles, and state hash.
- [ ] Confirm the new client sees Glaur-em's arena as "defeated" (no boss
  spawn) and inherits the host's PvP / shared-XP / loot-mode settings.

## 17. Desync detection (13.43)

- [ ] In a 2-player party, force a state divergence via DevConsole
  (`GameState.aphelion_slivers_remaining = 0` on one client only).
- [ ] On the next `compute_state_hash` tick, the hashes differ;
  `desync_detected` fires on both sides with `(local_hash, remote_hash)`.
- [ ] The recovery path requests a fresh snapshot from the host (manual
  trigger via DevConsole stub for now).

## 18. Server logs viewer (13.34)

- [ ] Open the dev console on the host and call
  `get_tree().get_nodes_in_group("server_logs_viewer")[0].open()`.
- [ ] The panel shows all server log entries since hosting — peer joins,
  disconnects, kicks, password failures.
- [ ] On a client, attempting to open the viewer prints "Logs are host-only."

## 19. Kick / ban (13.20)

- [ ] As host, kick a peer via DevConsole: `NetSystem.kick_peer(2)`. The
  peer is disconnected; their profile is removed.
- [ ] As host, ban a peer: `NetSystem.ban_peer(2, "test")`. The peer is
  kicked + their peer_id added to `banned_peer_ids`. If they reconnect with
  the same peer_id, they're auto-kicked.

## 20. Steam / cross-platform stubs (13.17, 13.28, 13.32, 13.35)

- [ ] In the dev console, call `NetSystem.steam_lobby_create_stub("test", 8)`.
  Returns a fake record with lobby_id + vendor=STEAM.
- [ ] `NetSystem.set_rich_presence_stub("Hosting Sleeping Vein")` appends a
  server-log entry.
- [ ] `NetSystem.cross_platform_join_stub(NetSystem.Vendor.STEAM, "lobby_test")`
  returns `ERR_UNAVAILABLE` (not implemented for MVP; the API contract is in
  place for a future vendor SDK).

## 21. LAN discovery + server browser (13.18, 13.33)

- [ ] Open the ServerBrowser. If GameState.net_recent_hosts is empty, the
  list shows "No recent hosts. Use Direct IP in the Lobby."
- [ ] Save a host into Settings (`Settings.set_value("net/recent_hosts",
  [{"ip":"127.0.0.1","port":4242}])`) and refresh. The list populates.
- [ ] Click Join. The world dialogue closes and the join flow runs.

## 22. Soulbound items skip death drop (9.63)

- [ ] Equip a brindle_pendant (resonance-bound). Die in PvP.
- [ ] Confirm the pendant is NOT in the death corpse drop pile; it stays in
  the Walker's inventory after respawn.

## 23. Synced lore-tablet read (9.55)

- [ ] In a 2-player party, one Walker reads a Diadem Manifesto. The other
  Walker's HUD shows the toast "A tablet rings far away. Someone is reading."
- [ ] The compendium unlock fires for both Walkers' save slots.

## 24. Shared XP toggle (7.12, 13.39, 13.50)

- [ ] Lobby toggle: Shared XP ON. Mining a tile grants XP to all party
  members at half magnitude (via `SkillSystem._share_party_xp`).
- [ ] Lobby toggle: Shared XP OFF. Mining only grants XP to the mining
  Walker.

## 25. Gamepad cursor + glyphs (13.45, 13.46)

- [ ] Plug in a controller. Move the right stick. The on-screen gold
  reticle activates.
- [ ] Tap any keyboard key. The reticle deactivates.
- [ ] Switch the glyph set in Settings → Controls → Glyph Set (xbox /
  playstation / switch / generic). Confirm `Phase13Helpers.gamepad_glyphs`
  persists across save reloads.

## 26. Voice PTT stub (13.16)

- [ ] Press and hold **V**. `Phase13Helpers.voice_ptt_active` flips true.
- [ ] Release. It flips false. (No audio capture yet; the binding is
  reserved for a future voice plugin.)

## 27. Synced boss-cutscene moment (13.42)

- [ ] Defeat Glaur-em in a 2-player party. Both clients receive the
  letterbox + line + AudioBus sting at the same Beat. NPC arrival cinematic
  plays for both.

## 28. World password persistence (13.19)

- [ ] Host with password "test". Quit and re-launch.
- [ ] Reload the save. `GameState.net_world_password_hash` matches the
  pre-quit hash (verified by hashing "test" again).
- [ ] Verify cleartext "test" never appears in the save file (search the
  `state.json` for the string).

## 29. Networked VFX broadcast (13.48)

- [ ] Kill a mob in a 2-player party. Both clients see the death
  particle + damage-number floating text (already wired through EventBus +
  `Phase13Helpers.broadcast_vfx`).

## 30. SaveSystem v11 round-trip

- [ ] Quit the world. Restart Godot. Reload the save.
- [ ] Confirm:
  - `SaveSystem.SAVE_VERSION` is `11`.
  - `GameState.net_pvp_enabled` / `net_shared_xp_enabled` / `net_loot_mode`
    / `net_nameplate_visible` survive the round-trip.
  - `NetSystem.player_profiles` (if any were stored) re-parse correctly,
    with colours back as `Color` and `portrait` back as `StringName`.
  - `Phase13Helpers.chat_history` (last session's messages) survive.

## 31. Asset sanity

- [ ] All 13 Phase 13 sprites load in the editor — `assets/sprites/items/
  resurrection_altar_placeable.png` + the 12 ui sprites.
- [ ] Each sprite's manifest entry has `status: "final"`.
- [ ] No `null` Sprite2D textures appear in the new structure scene
  (Resurrection Altar).

## 32. CI

- [ ] `tests/unit/test_phase13_systems.gd` is picked up by `.gutconfig.json`
  and runs in the CI pipeline.
- [ ] The CI step reports 345/345 passing tests after Phase 13 closure.
