extends Node
## Host/join, peer ids, cliff assignment and the lobby roster.
## This is the only script that knows the transport is ENet, so it can be
## swapped for WebRTC or Steam later without touching gameplay code.

signal players_changed
signal connected_to_host
signal connection_failed(reason: String)
signal server_closed
signal player_left(peer_id: int)

const DEFAULT_PORT := 24565
const DEFAULT_ADDRESS := "127.0.0.1"
const MAX_PLAYERS := 2
const WORLD_SCENE := "res://scenes/world.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

## peer_id -> {"name": String, "cliff": int, "ready": bool}. Owned by the host, mirrored on clients.
var players: Dictionary = {}
## CPU teammate quality: -1 off, 0 Low, 1 Medium, 2 High. Host sets it in the
## lobby; a CPU fills the empty cliff when there's room (see has_cpu).
var cpu_quality := -1
const CPU_QUALITY_NAMES := ["Low", "Medium", "High"]
var local_name: String = "Rancher"
var _peer: ENetMultiplayerPeer
var _started := false
var _port: int = DEFAULT_PORT
var _address: String = DEFAULT_ADDRESS
## Set by join_from_menu(); the main menu joins it on load.
var pending_join: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return _peer != null


func host(port: int = DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	# Debug/test launches: if the port is taken (another test or game is running),
	# try the next few so parallel automated runs don't hang on the menu.
	if err != OK and GameState.has_flag("--debug") and not GameState.has_flag("--host"):
		for i in range(1, 32):
			peer = ENetMultiplayerPeer.new()
			err = peer.create_server(port + i, MAX_PLAYERS - 1)
			if err == OK:
				print("[net] port %d busy, hosting on %d" % [port, port + i])
				port += i
				break
	if err != OK:
		return err
	_peer = peer
	_port = port
	multiplayer.multiplayer_peer = peer
	players = {1: {"name": local_name, "cliff": WorldLayout.WEST, "ready": false}}
	players_changed.emit()
	return OK


func join(address: String = DEFAULT_ADDRESS, port: int = DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_peer = peer
	_port = port
	_address = address
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_started = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	players_changed.emit()


## "IP:port" a friend can paste to join this game (LAN address of this PC).
func invite_code() -> String:
	if is_online() and not multiplayer.is_server():
		return "%s:%d" % [_address, _port] # a client shares the host's address
	return "%s:%d" % [local_ip(), _port]


## Best-guess LAN IPv4 address of this machine.
func local_ip() -> String:
	var fallback := DEFAULT_ADDRESS
	for addr: String in IP.get_local_addresses():
		if addr.contains(":") or addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
		fallback = addr
	return fallback


## Parses "IP:port" or a bare IP. Returns {} if it isn't usable.
func parse_invite(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {}
	var address := t
	var port := DEFAULT_PORT
	var colon := t.rfind(":")
	if colon > 0:
		address = t.substr(0, colon)
		port = int(t.substr(colon + 1))
	if port <= 0 or port > 65535 or not (address.is_valid_ip_address() or address.contains(".")):
		return {}
	return {"address": address, "port": port}


## Leaves the current game, returns to the menu and joins another one from there.
func join_from_menu(address: String, port: int) -> void:
	leave()
	pending_join = {"address": address, "port": port}
	get_tree().change_scene_to_file(MENU_SCENE)


func local_id() -> int:
	return multiplayer.get_unique_id()


## Is there a CPU teammate this run (quality set and a free slot for it)?
func has_cpu() -> bool:
	return cpu_quality >= 0 and players.size() < MAX_PLAYERS


## The cliff the CPU teammate takes: whichever no human is on.
func cpu_cliff() -> int:
	for id: int in players:
		return WorldLayout.other_cliff(cliff_of(id))
	return WorldLayout.EAST


## Host: set the CPU teammate's quality (-1 = none) and tell everyone.
func set_cpu(quality: int) -> void:
	if not multiplayer.is_server():
		return
	cpu_quality = clampi(quality, -1, 2)
	_sync_cpu.rpc(cpu_quality)
	players_changed.emit()


@rpc("authority", "reliable")
func _sync_cpu(q: int) -> void:
	cpu_quality = q
	players_changed.emit()


func cliff_of(peer_id: int) -> int:
	if players.has(peer_id):
		return int((players[peer_id] as Dictionary)["cliff"])
	return WorldLayout.WEST


## Round-trip time to the host (clients) or to the other player (host), in ms.
func get_ping_ms() -> int:
	if _peer == null:
		return 0
	var target := 1
	if multiplayer.is_server():
		for id: int in players:
			if id != 1:
				target = id
	var p := _peer.get_peer(target)
	if p == null:
		return 0
	return int(p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


func set_ready(value: bool) -> void:
	if multiplayer.is_server():
		_apply_ready(1, value)
	else:
		_request_ready.rpc_id(1, value)


func all_ready() -> bool:
	if players.is_empty():
		return false
	for id: int in players:
		if not bool((players[id] as Dictionary)["ready"]):
			return false
	return true


# ------------------------------------------------------------------ host side

func _on_peer_connected(_id: int) -> void:
	pass # The client registers itself with its name.


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.has(id):
		players.erase(id)
		_broadcast()
	player_left.emit(id)


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= MAX_PLAYERS:
		_peer.disconnect_peer(id)
		return
	players[id] = {"name": player_name.strip_edges().left(16), "cliff": WorldLayout.EAST, "ready": false}
	_broadcast()


@rpc("any_peer", "reliable")
func _request_ready(value: bool) -> void:
	if multiplayer.is_server():
		_apply_ready(multiplayer.get_remote_sender_id(), value)


func _apply_ready(id: int, value: bool) -> void:
	if not players.has(id):
		return
	(players[id] as Dictionary)["ready"] = value
	_broadcast()
	if all_ready() and players.size() == MAX_PLAYERS:
		start_game()


## Host only: starts the run with whoever is in the lobby (also used for solo testing).
func start_game() -> void:
	if not multiplayer.is_server() or _started:
		return
	_started = true
	if _peer != null:
		_peer.refuse_new_connections = true
	_start_game.rpc()


func _broadcast() -> void:
	_sync_players.rpc(players)
	_sync_cpu.rpc(cpu_quality)
	players_changed.emit()


@rpc("authority", "reliable")
func _sync_players(roster: Dictionary) -> void:
	players = roster
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file.call_deferred(WORLD_SCENE)


# ------------------------------------------------------------------ client side

func _on_connected_to_server() -> void:
	_register.rpc_id(1, local_name)
	connected_to_host.emit()


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("Could not reach the host.")


func _on_server_disconnected() -> void:
	leave()
	server_closed.emit()
