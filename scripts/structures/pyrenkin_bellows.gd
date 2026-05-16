extends Workstation
class_name PyrenkinBellows

## Phase 11.21 — Tier-6 Emberforge crafting station. Subclass of Workstation.
## On interact, if the bellows isn't lit, attempts to feed a Pyrenkin Cricket
## fuel-pellet (11.32). Once lit, opens the crafting panel with the bellows
## recipe list.

func _ready() -> void:
	station_id = &"pyrenkin_bellows"
	display_name = "Pyrenkin Bellows"
	super._ready()
	add_to_group("pyrenkin_bellows")


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if event.is_action_pressed("interact"):
		# 11.32 — auto-feed a pellet if not lit.
		if Phase11Helpers and not Phase11Helpers.bellows_is_lit():
			if not Phase11Helpers.bellows_feed_pellet():
				EventBus.ui_toast.emit("The bellows is cold. Feed it a fuel-pellet.", 2.0)
				return
		super._unhandled_input(event)
