extends Node
## Host/join, peer ids, cliff assignment, the map and the lobby roster.
## This is the only script that knows the transport is ENet, so it can be
## swapped for WebRTC or Steam later without touching gameplay code.

signal players_changed
signal connected_to_host
signal connection_failed(reason: String)
signal server_closed
signal player_left(peer_id: int)
## The host's invite changed (the router opened up, or didn't).
signal invite_changed

const DEFAULT_PORT := 24565
const DEFAULT_ADDRESS := "127.0.0.1"
## The most players any map holds (each map's own limit: max_players()).
const MAX_PLAYERS := 4
const WORLD_SCENE := "res://scenes/world.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

## peer_id -> {"name": String, "cliff": int, "ready": bool}. Owned by the host, mirrored on clients.
var players: Dictionary = {}
## The map the host picked (MapDef id). Mirrored on clients; the world builds it.
var map_id: StringName = MapDef.CANYON
## CPU teammate quality: -1 off, 0 Low, 1 Medium, 2 High. Host sets it in the
## lobby; CPUs fill every empty cliff when there's room (see has_cpu).
var cpu_quality := -1
const CPU_QUALITY_NAMES := ["Low", "Medium", "High"]
var local_name: String = "Rancher"
var _peer: ENetMultiplayerPeer
var _started := false
var _port: int = DEFAULT_PORT
var _address: String = DEFAULT_ADDRESS
## Set by join_from_menu(); the main menu joins it on load.
var pending_join: Dictionary = {}
## Invites over the internet: when hosting, the router is asked (UPnP) to open
## the game's port, and its public address goes into the invite code.
## "" = not tried yet / working, "open" = the internet can reach us, "lan" = same network only.
var upnp_state := ""
var public_ip := ""
var _upnp: UPNP
var _upnp_thread: Thread
var _upnp_port := 0


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
	if GameState.has_flag("--debug") and GameState.flag_value("--port") != "":
		port = int(GameState.flag_value("--port")) # Crewed: debug two-window tests on a port of their own
	var peer := ENetMultiplayerPeer.new()
	var flag_map := StringName(GameState.flag_value("--map").to_lower())
	if MapDef.IDS.has(flag_map):
		map_id = flag_map
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
	players = {1: {"name": local_name, "cliff": 0, "ready": false}}
	players_changed.emit()
	_open_router(port)
	return OK


## How many players the chosen map holds (one per cliff).
func max_players() -> int:
	return MapDef.players_of(map_id)


## Host: pick the map (anyone who no longer fits stays connected but the
## extra players are moved onto the free cliffs; a smaller map refuses if full).
func set_map(id: StringName) -> bool:
	if not multiplayer.is_server() or not MapDef.IDS.has(id):
		return false
	if players.size() > MapDef.players_of(id):
		return false
	map_id = id
	# Everyone keeps their cliff if it still exists, else takes the first free one.
	var taken := {}
	var ids := players.keys()
	ids.sort()
	for pid: int in ids:
		var c := int((players[pid] as Dictionary)["cliff"])
		if c < max_players() and not taken.has(c):
			taken[c] = true
		else:
			(players[pid] as Dictionary)["cliff"] = -1
	for pid: int in ids:
		if int((players[pid] as Dictionary)["cliff"]) < 0:
			var c := _free_cliff(taken)
			(players[pid] as Dictionary)["cliff"] = c
			taken[c] = true
	_broadcast()
	return true


func _free_cliff(taken: Dictionary) -> int:
	for c in max_players():
		if not taken.has(c):
			return c
	return 0


@rpc("authority", "reliable")
func _sync_map(id: String) -> void:
	map_id = StringName(id)
	players_changed.emit()


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
	_close_router()
	if _peer != null:
		_peer.close()
	_peer = null
	_started = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	players_changed.emit()


## The code a friend types to join this game (DUST-XXXXX-XXXXX): the router's
## public address when it let us open the port, else this PC's LAN address.
func invite_code() -> String:
	if is_online() and not multiplayer.is_server():
		return InviteCode.encode(_address, _port) # a client shares the host's address
	var ip := public_ip if upnp_state == "open" and public_ip != "" else local_ip()
	var code := InviteCode.encode(ip, _port)
	return code if code != "" else "%s:%d" % [ip, _port]


## One line on where the invite works, for the lobby and the Social tab.
func invite_note() -> String:
	if is_online() and not multiplayer.is_server():
		return "The code of the game you're in."
	match upnp_state:
		"open":
			return "Works over the internet. Send it to your friend; they type it into Join."
		"lan":
			return "Same network only: your router didn't open port %d by itself. Forward UDP %d, or both use Tailscale / Radmin VPN and join by its IP." % [_port, _port]
	return "Opening your router for internet play..."


# ------------------------------------------------------------------ UPnP (host)

## Ask the router to forward our port (on a thread: discovery takes a second or two).
func _open_router(port: int) -> void:
	_close_router()
	upnp_state = ""
	public_ip = ""
	invite_changed.emit()
	if GameState.has_flag("--debug") or GameState.has_flag("--noupnp"):
		upnp_state = "lan" # tests and automated runs never touch the router
		invite_changed.emit()
		return
	_upnp_port = port
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(port: int) -> void:
	var u := UPNP.new()
	var ip := ""
	var ok := false
	if u.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS 			and u.get_gateway() != null and u.get_gateway().is_valid_gateway():
		ok = u.add_port_mapping(port, port, "Dust & Mandibles", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
		ip = u.query_external_address()
	# A router behind the provider's own NAT reports a private address: no good for invites.
	if ip == "" or _private(ip):
		ok = false
	_upnp_done.call_deferred(u, ok, ip)


static func _private(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return true
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or a == 127 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31) 			or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)


func _upnp_done(u: UPNP, ok: bool, ip: String) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if not is_online() or not multiplayer.is_server():
		if ok:
			u.delete_port_mapping(_upnp_port, "UDP") # we stopped hosting while it worked
		return
	_upnp = u if ok else null
	upnp_state = "open" if ok else "lan"
	public_ip = ip if ok else ""
	print("[net] invite: %s (%s)" % [invite_code(), upnp_state])
	invite_changed.emit()


func _close_router() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp != null:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null
	upnp_state = ""
	public_ip = ""


func _exit_tree() -> void:
	_close_router()


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


## Parses an invite code, "IP:port" or a bare IP. Returns {} if it isn't usable.
func parse_invite(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t == "":
		return {}
	var coded := InviteCode.decode(t)
	if not coded.is_empty():
		return coded
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
	return cpu_quality >= 0 and players.size() < max_players()


## Every cliff no human is on (the CPU teammates take these).
func cpu_cliffs() -> Array[int]:
	var taken := {}
	for id: int in players:
		taken[cliff_of(id)] = true
	var out: Array[int] = []
	for c in max_players():
		if not taken.has(c):
			out.append(c)
	return out


## Does a human or a CPU teammate hold cliff `cid` this run?
func cliff_held(cid: int) -> bool:
	for id: int in players:
		if cliff_of(id) == cid:
			return true
	return has_cpu() and cpu_cliffs().has(cid)


## The first cliff a CPU teammate takes.
func cpu_cliff() -> int:
	var free := cpu_cliffs()
	return free[0] if not free.is_empty() else WorldLayout.EAST


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
	return 0


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
	if players.size() >= max_players():
		_peer.disconnect_peer(id)
		return
	var taken := {}
	for pid: int in players:
		taken[cliff_of(pid)] = true
	players[id] = {"name": player_name.strip_edges().left(16), "cliff": _free_cliff(taken), "ready": false}
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
	# Tests: --players=N starts once N players are ready (CPUs fill the rest).
	var need := max_players()
	if GameState.flag_value("--players") != "":
		need = clampi(int(GameState.flag_value("--players")), 1, max_players())
	if all_ready() and players.size() >= need:
		start_game()


## Host only: starts the run with whoever is in the lobby (also used for solo testing).
func start_game() -> void:
	if not multiplayer.is_server() or _started:
		return
	_started = true
	if _peer != null:
		_peer.refuse_new_connections = true
	_start_game.rpc(String(map_id))


func _broadcast() -> void:
	_sync_map.rpc(String(map_id))
	_sync_players.rpc(players)
	_sync_cpu.rpc(cpu_quality)
	players_changed.emit()


@rpc("authority", "reliable")
func _sync_players(roster: Dictionary) -> void:
	players = roster
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start_game(id: String = "canyon") -> void:
	map_id = StringName(id)
	MapDef.select(map_id)
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
