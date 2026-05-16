extends Node

## Phase 15 — Steam / EOS integration stub.
## We cannot link Steamworks at this stage (no SDK shipped with the repo), so
## this is a thin facade that mirrors the API surface and writes through to
## local state. When the user wires Steamworks (e.g. via the godotsteam plugin
## or the EOS SDK), each method below is one swap-out away from real RPCs.
##
## Tickets covered (all as stubs that DO emit signals + persist locally):
##   15.12 — Cloud save (Steam Cloud / EOS)
##   15.13 — Steam Workshop / mod.io integration scaffold
##   15.27 — Steam Trading Cards / Achievement images (path registry)
##   15.32 — Steam Achievements API hookup + sync
##   15.50 — Beta branch opt-in
##   15.64 — Steam Anti-Cheat / sanity-check hooks
##   15.73 — Steam Deck verified UI scaling + input pass
##   15.32 wiring: when set_achievements_enabled(false) the unlock() turns into a no-op
##         (used by Hard mode + cheat detection).
##   15.13 also exposes a tiny ModSystem.fetch_remote_listings bridge so the mod
##         manager UI can browse mod.io without touching ModSystem internals.

const TRADING_CARD_DIR: String = "res://assets/sprites/steam/cards/"
const ACHIEVEMENT_ICON_DIR: String = "res://assets/sprites/steam/achievements/"

signal cloud_uploaded(slot_name: String, bytes: int)
signal cloud_downloaded(slot_name: String, bytes: int)
signal cloud_conflict(slot_name: String)
signal achievement_unlocked_remote(id: StringName)
signal beta_branch_changed(active: bool)
signal anti_cheat_violation(reason: String)
signal steam_deck_layout_changed(active: bool)
signal workshop_subscribed(mod_id: String)
signal workshop_unsubscribed(mod_id: String)


## Whether achievements are gated by Steam (default true). When false, every
## unlock() is a no-op. Cheat-detection + Hard+ difficulty can flip this.
var achievements_enabled: bool = true
var on_beta_branch: bool = false
var steam_deck_layout_active: bool = false
var steam_initialized: bool = false   # set true if godotsteam is wired

# Local mirror of subscribed Workshop / mod.io mod ids.
var subscribed_workshop_mods: Array[String] = []
# Local mirror of remote-card progression (for the trading-card UI).
var trading_cards_collected: Dictionary = {}   # card_id -> bool


func _ready() -> void:
	# Detect if a real godotsteam autoload exists; we don't require it.
	steam_initialized = Engine.has_singleton("Steam")
	# Best-effort Steam-Deck detection — Steamworks would tell us, but we
	# fall back to env-variable sniffing in case the user is on a Deck without
	# the SDK linked.
	if not steam_initialized:
		var sd_env: String = OS.get_environment("SteamDeck")
		steam_deck_layout_active = (sd_env == "1")


# ---------- Cloud save (15.12) ----------

## Upload the named save slot to Steam Cloud / EOS. Stub: writes a marker
## under user://cloud_sync/<slot>.json so we can verify a round-trip.
func cloud_upload(slot_name: String) -> bool:
	if Phase15Helpers:
		Phase15Helpers.cloud_mark_syncing()
	var marker_dir: String = "user://cloud_sync/"
	DirAccess.make_dir_recursive_absolute(marker_dir)
	var file := FileAccess.open(marker_dir + slot_name + ".json", FileAccess.WRITE)
	if file == null:
		if Phase15Helpers:
			Phase15Helpers.cloud_mark_offline()
		return false
	file.store_string(JSON.stringify({
		"slot": slot_name,
		"uploaded_unix": Time.get_unix_time_from_system(),
		"engine_version": Engine.get_version_info(),
	}, "\t"))
	file.close()
	cloud_uploaded.emit(slot_name, 0)
	if Phase15Helpers:
		Phase15Helpers.cloud_mark_synced()
	return true


func cloud_download(slot_name: String) -> Dictionary:
	var marker: String = "user://cloud_sync/" + slot_name + ".json"
	if not FileAccess.file_exists(marker):
		return {}
	var file := FileAccess.open(marker, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	cloud_downloaded.emit(slot_name, text.length())
	return json.data


func cloud_resolve_conflict(slot_name: String, keep_local: bool) -> void:
	if keep_local:
		cloud_upload(slot_name)
	else:
		# In a real wire-up we'd download remote and overwrite local. Stub: just
		# emit and signal.
		cloud_downloaded.emit(slot_name, 0)


# ---------- Achievements (15.32) ----------

func set_achievements_enabled(active: bool) -> void:
	achievements_enabled = active


func unlock_achievement(id: StringName) -> bool:
	if not achievements_enabled:
		return false
	if Phase15Helpers and not Phase15Helpers.achievements_enabled():
		return false
	# In a wired build, this is one call to Steam.set_achievement(id).
	achievement_unlocked_remote.emit(id)
	return true


func clear_all_achievements() -> void:
	# Stub: only used by integration tests.
	pass


# ---------- Beta branch (15.50) ----------

func set_beta_branch(active: bool) -> void:
	on_beta_branch = active
	if Phase15Helpers:
		Phase15Helpers.on_beta_branch = active
	beta_branch_changed.emit(active)


# ---------- Anti-cheat (15.64) ----------

## Sanity-check hook called from key write paths (talent allocation, recipe
## unlock, save load). Returns true if the action passes; emits a violation
## signal otherwise. In a wired build, callers can hard-fail save uploads.
func sanity_check(label: String, payload_size: int) -> bool:
	# Flag oversized payloads as suspicious.
	if payload_size > 8 * 1024 * 1024:
		anti_cheat_violation.emit("oversized payload: %s" % label)
		return false
	return true


# ---------- Steam Deck UI scaling (15.73) ----------

func set_steam_deck_layout(active: bool) -> void:
	steam_deck_layout_active = active
	steam_deck_layout_changed.emit(active)


# ---------- Workshop / mod.io scaffold (15.13) ----------

## Stub: kicks ModSystem to fetch listings. ModSystem's fetch_remote_listings
## returns the listing count (async-ish), not the rows themselves; the actual
## row data is read off ModSystem state. Returning a row count is enough for
## the UI to know whether to retry.
func fetch_workshop_listings() -> int:
	if ModSystem and ModSystem.has_method("fetch_remote_listings"):
		return int(ModSystem.fetch_remote_listings())
	return 0


func subscribe_workshop(mod_id: String) -> bool:
	if mod_id in subscribed_workshop_mods:
		return false
	subscribed_workshop_mods.append(mod_id)
	workshop_subscribed.emit(mod_id)
	return true


func unsubscribe_workshop(mod_id: String) -> bool:
	if mod_id not in subscribed_workshop_mods:
		return false
	subscribed_workshop_mods.erase(mod_id)
	workshop_unsubscribed.emit(mod_id)
	return true


# ---------- Trading cards (15.27) ----------

func grant_trading_card(card_id: StringName) -> bool:
	if trading_cards_collected.get(card_id, false):
		return false
	trading_cards_collected[card_id] = true
	return true


func trading_card_path(card_id: StringName) -> String:
	return TRADING_CARD_DIR + String(card_id) + ".png"


func achievement_icon_path(ach_id: StringName) -> String:
	return ACHIEVEMENT_ICON_DIR + String(ach_id) + ".png"
