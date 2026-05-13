extends Resource
class_name DialogueTree

## Data-driven dialogue. Tree of nodes addressed by id. Each node has speaker text,
## and optional responses. A "response" jumps to another node (or ends the tree).
## NPC class loads a DialogueTree resource and plays through it.

@export var nodes: Dictionary = {}   ## { node_id (String) -> { "speaker", "text", "responses": [ { "label", "goto" } ] } }
@export var entry_node_id: String = "start"


func get_node_data(id: String) -> Dictionary:
	return nodes.get(id, {})
