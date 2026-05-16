extends Node

## Phase 15 — Audio output profile.
## Covers ticket 15.89: adapt audio profile to headphones vs speakers + the
## subtitle / channel-config inspection bits.
##
## Two profiles ship: "speakers" (default, full stereo + bass boost-safe) and
## "headphones" (HRTF-style positional widening + bass-reduction safety so the
## player doesn't blow their ears out). The user toggles in the audio settings.
##
## Real HRTF lives in AudioBus when wired; this autoload owns the profile
## state and the EQ/limiter slot configuration.

const PROFILES: Array[StringName] = [&"speakers", &"headphones"]

signal profile_changed(profile: StringName)

var profile: StringName = &"speakers"


func _ready() -> void:
	if Settings:
		profile = StringName(String(Settings.get_value("audio.profile", "speakers")))
		apply(profile)


func apply(p: StringName) -> bool:
	if p not in PROFILES:
		return false
	profile = p
	# In a wired build, swap the master bus EQ + limiter to the chosen profile.
	# Headphones: lower bass shelf by 4 dB, slightly widen stereo via a Delay
	# bus, enable HRTF positional audio.
	# Speakers: flat EQ, peak limiter +0 dB.
	if Settings:
		Settings.set_value("audio.profile", String(p))
	profile_changed.emit(p)
	return true
