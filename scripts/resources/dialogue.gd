extends Resource
class_name DialogueTree

## Data-driven dialogue. Tree of nodes addressed by id. Each node has speaker text,
## and optional responses. A "response" jumps to another node (or ends the tree).
## NPC class loads a DialogueTree resource and plays through it.
##
## Phase 9 expansions:
##   9.12 / 9.21 — Branching with mood-based aliasing. If the NPC's current mood
##                  category is "happy" or "sad", and the tree defines
##                  "{base_id}_happy" / "{base_id}_sad", that override wins.
##   9.12       — Responses may carry a `require_flag` / `forbid_flag` /
##                  `require_friendship` (int >= n) — DialoguePanel filters them.
##   9.45       — `event_flag`: visible only when NpcLifecycle.get_flag is set
##                  (for reaction-to-world-events dialogue, e.g. Wormbound peace).
##   9.21       — Each node can declare `set_flag: <name>` / `add_friendship: N`
##                  effects that fire when the node is shown.

@export var nodes: Dictionary = {}   ## { node_id (String) -> { "speaker", "text", "responses": [ { "label", "goto" } ] } }
@export var entry_node_id: String = "start"


func get_node_data(id: String) -> Dictionary:
	return nodes.get(id, {})


## Phase 9.12 / 9.21 — resolve a node id given mood category. If a mood-suffixed
## variant exists, use it; otherwise fall back to the base id.
func resolve_node(id: String, mood_category: String) -> Dictionary:
	if mood_category != "" and mood_category != "neutral":
		var aliased := "%s_%s" % [id, mood_category]
		if nodes.has(aliased):
			return nodes[aliased]
	return nodes.get(id, {})
