extends Node

## Phase 13 multiplayer skeleton. Host/join via ENet. Authority model: host
## owns world state, clients send input and receive replicated positions.
## Phase 13 MVP: connection + player spawn at Loom. Full sync of mining, chests,
## bosses comes later.

const DEFAULT_PORT: int = 4242
const MAX_PLAYERS: int = 8

signal hosted(port: int)
signal joined(host: String, port: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed
signal disconnected

var is_host: bool = false
var is_client: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_world(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_client = false
	hosted.emit(port)
	return OK


func join_world(host: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_client = true
	joined.emit(host, port)
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	is_client = false


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)


func _on_connection_failed() -> void:
	is_client = false
	connection_failed.emit()


func _on_server_disconnected() -> void:
	is_host = false
	is_client = false
	disconnected.emit()
