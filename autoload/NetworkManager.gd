extends Node
## Host/join, peer ids, cliff assignment, the map and the lobby roster.
## How players find each other and which MultiplayerPeer carries the game is
## up to an OnlineBackend (components/net/): DirectBackend (ENet, UPnP, IP
## invite codes; always there) or the online backend (EpicBackend now, Steam
## later). Gameplay code never sees which one is in use.

signal players_changed
signal connected_to_host
signal connection_failed(reason: String)
signal server_closed
signal player_left(peer_id: int)
## The host's invite changed (the router opened up, the online lobby got its code...).
signal invite_changed
## A new round-trip measurement came in (ping_note() changed).
signal ping_changed

const DEFAULT_PORT := DirectBackend.DEFAULT_PORT
const DEFAULT_ADDRESS := DirectBackend.DEFAULT_ADDRESS
## The most players any map holds (each map's own limit: max_players()).
const MAX_PLAYERS := 4
const WORLD_SCENE := "res://scenes/world.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
## An online join that hasn't connected by then gives up.
const ONLINE_JOIN_TIMEOUT_SEC := 30.0
## How often each link is pinged (host <-> each client) for get_ping_ms().
const PING_INTERVAL_SEC := 1.0

## peer_id -> {"name": String, "cliff": int, "ready": bool}. Owned by the host, mirrored on clients.
var players: Dictionary = {}
## The map the host picked (MapDef id). Mirrored on clients; the world builds it.
var map_id: StringName = MapDef.CANYON
## CPU teammate quality: -1 off, 0 Low, 1 Medium, 2 High. Host sets it in the
## lobby; CPUs fill every empty cliff when there's room (see has_cpu).
var cpu_quality := -1
## Endless (host): the wave a new run starts at (the lobby slider, EndlessStart).
var start_wave := 1
## Solo (main menu: Story/Endless > Solo): hosted directly, nobody can join,
## and the lobby starts as soon as you ready up.
var solo := false
const CPU_QUALITY_NAMES := ["Low", "Medium", "High"]
var local_name: String = "Rancher"
var _peer: MultiplayerPeer
var _started := false
## Set by join_from_menu(); the main menu joins it on load.
var pending_join: Dictionary = {}
## Always there: ENet + UPnP + IP invite codes.
var direct: DirectBackend
## Epic now, Steam later; null when it's missing or unusable (then Direct only).
var online: OnlineBackend
## Which of the two carries the current game.
var _backend: OnlineBackend
## Why online invites are off, for the lobby ("" when they're on).
var _offline_note := ""
## Why the last join or host failed, in words for the player.
var last_error := ""
## Bumped by leave(), so an online join still searching knows it was abandoned.
var _join_ticket := 0
var _host_port := DEFAULT_PORT
## Measured round trips: peer id -> ms (host: each client; client: {1: host}).
var _rtt: Dictionary = {}
var _ping_wait := 0.0
var _pongs := 0
## Shown by the main menu when it opens (e.g. "The host left the game.").
var menu_message := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	direct = DirectBackend.new()
	direct.name = "DirectBackend"
	var flags := _launch_flags()
	direct.flags = flags
	add_child(direct)
	direct.status_changed.connect(invite_changed.emit)
	var why: Array[String] = []
	online = OnlineBackend.create_online(why, flags)
	_offline_note = why[0] if not why.is_empty() else ""
	direct.fallback_note = _offline_note
	if online != null:
		online.game_version = game_version()
		online.player_name = local_name
		add_child(online)
		online.status_changed.connect(invite_changed.emit)
		online.lobby_failed.connect(_on_lobby_failed)
		online.login() # signs in in the background; hosting falls back to Direct until it's ready
	print("[net] backends: Direct%s" % (" + " + online.backend_name() if online != null else " only" + (" (%s)" % _offline_note if _offline_note != "" else "")))


## The launch flags, built like GameState.flags (whose _ready runs after ours).
static func _launch_flags() -> PackedStringArray:
	var flags := OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--") and not flags.has(arg):
			flags.append(arg)
	# Scripts (the unit tests: -s res://tests/run_tests.gd) never go online.
	if (OS.get_cmdline_args().has("-s") or OS.get_cmdline_args().has("--script")) and not flags.has("--direct"):
		flags.append("--direct")
	return flags


## The build's version ("dev" when run from the editor). Online lobbies only
## match the same version; release.yml stamps the tag into the project.
static func game_version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return v if v != "" else "dev"


func is_online() -> bool:
	return _peer != null


## Is the online backend still signing in? (Hosting now would fall back to Direct.)
func online_signing_in() -> bool:
	return online != null and online.is_signing_in()


## Waits (up to `seconds`) for the online backend to finish signing in.
func wait_for_online(seconds: float = 15.0) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while online_signing_in() and Time.get_ticks_msec() < until:
		await get_tree().process_frame


## Hosts a game: on the online backend when it's signed in, else directly on
## `port` (the lobby note says why). Returns OK or an error (see last_error).
func host(port: int = DEFAULT_PORT) -> Error:
	leave()
	if GameState.has_flag("--debug") and GameState.flag_value("--port") != "":
		port = int(GameState.flag_value("--port")) # Crewed: debug two-window tests on a port of their own
	var flag_map := StringName(GameState.flag_value("--map").to_lower())
	if MapDef.IDS.has(flag_map):
		map_id = flag_map
	_host_port = port
	var peer: MultiplayerPeer = null
	direct.fallback_note = _offline_note
	if solo:
		direct.fallback_note = ""
	elif online != null and not wants_online():
		direct.fallback_note = "Direct game (Host via: Direct). Pick Online in the menu for an Epic lobby."
	elif online != null:
		online.player_name = local_name
		if online.is_ready():
			peer = online.host(max_players(), {"port": port})
			if peer != null:
				_backend = online
		if peer == null:
			var why := online.last_error if online.last_error != "" else "still signing in"
			direct.fallback_note = "%s online isn't available (%s), so this invite is a direct connection." % [online.backend_name(), why.trim_suffix(".")]
			print("[net] hosting directly: " + direct.fallback_note)
			online.login() # retry in the background (no-op while it's still signing in)
	if peer == null:
		peer = direct.host(MAX_PLAYERS, {"port": port})
		if peer == null:
			last_error = direct.last_error
			return ERR_CANT_CREATE
		_backend = direct
	_peer = peer
	multiplayer.multiplayer_peer = peer
	if solo:
		peer.refuse_new_connections = true # a solo game: no riders join
	players = {1: {"name": local_name, "cliff": 0, "ready": false}}
	players_changed.emit()
	invite_changed.emit()
	return OK


## The online lobby couldn't be made: nobody could find this game, so host it
## directly instead (only while the host is still alone in the lobby).
func _on_lobby_failed(reason: String) -> void:
	if _backend != online or not is_online() or not multiplayer.is_server() or _started or players.size() > 1:
		return
	online.leave()
	_peer.close()
	var peer := direct.host(MAX_PLAYERS, {"port": _host_port})
	if peer == null:
		leave()
		connection_failed.emit("The online lobby failed (%s) and hosting directly failed too." % reason)
		return
	direct.fallback_note = "The %s lobby failed (%s), so this invite is a direct connection." % [online.backend_name(), reason]
	print("[net] hosting directly: " + direct.fallback_note)
	_backend = direct
	_peer = peer
	multiplayer.multiplayer_peer = peer
	players_changed.emit()
	invite_changed.emit()


## Does Host Game make an online lobby? The menu's Online / Direct pick
## (Settings.host_online); --epic launches always go online.
func wants_online() -> bool:
	return online != null and (Settings.host_online or GameState.has_flag("--epic"))


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
	if _backend != null:
		_backend.set_max_players(max_players()) # the online lobby holds the new map's count
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
	var peer := direct.join_address(address, port)
	if peer == null:
		last_error = direct.last_error
		return ERR_CANT_CONNECT
	_backend = direct
	_peer = peer
	multiplayer.multiplayer_peer = peer
	return OK


## Joins an online invite (DUST-XXXXXX, InviteCode.is_lobby_code). Returns at
## once; connected_to_host or connection_failed(reason) follows. An error here
## means it couldn't even start (see last_error).
func join_code(code: String) -> Error:
	leave()
	if online == null or not online.owns_code(code):
		last_error = ("That's an online invite, but online play is off in this copy of the game. " + _offline_note).strip_edges()
		return ERR_UNAVAILABLE
	online.player_name = local_name
	_join_online(code, _join_ticket)
	return OK


func _join_online(code: String, ticket: int) -> void:
	var peer := await online.join(code)
	if ticket != _join_ticket: # left (or joined something else) meanwhile
		if peer != null:
			peer.close()
		return
	if peer == null:
		print("[net] online join failed: " + online.last_error)
		connection_failed.emit(online.last_error)
		return
	_backend = online
	_peer = peer
	multiplayer.multiplayer_peer = peer
	await get_tree().create_timer(ONLINE_JOIN_TIMEOUT_SEC).timeout
	if ticket == _join_ticket and _peer == peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		leave()
		connection_failed.emit("Found the game but couldn't reach the host. Try again in a moment.")


func leave() -> void:
	_join_ticket += 1
	direct.leave()
	if online != null:
		online.leave()
	_backend = null
	if _peer != null:
		# Closed a frame later: leave() often runs inside the peer's own signal
		# (server_disconnected, connection_failed...), and freeing an Epic P2P peer
		# while it is still polling crashed the game. The lambda keeps it alive.
		var old := _peer
		(func() -> void: old.close()).call_deferred()
	_peer = null
	_started = false
	_rtt.clear()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	players_changed.emit()


## The code a friend types to join this game: DUST-XXXXX-XXXXX for a direct
## game (the host's address), DUST-XXXXXX for an online lobby.
func invite_code() -> String:
	var code := (_backend if _backend != null else direct).invite_code()
	return code if code != "" else "..."


## Is this game on the online backend (an Epic lobby) rather than direct?
func in_online_lobby() -> bool:
	return _backend != null and _backend == online


## One line on where the invite works, for the lobby and the Social tab.
func invite_note() -> String:
	return (_backend if _backend != null else direct).invite_note()


## Best-guess LAN IPv4 address of this machine.
func local_ip() -> String:
	return DirectBackend.local_ip()


## Parses a direct invite code, "IP:port" or a bare IP. Returns {} if it isn't usable.
## (Online invites are InviteCode.is_lobby_code(); join those with join_code().)
func parse_invite(text: String) -> Dictionary:
	return DirectBackend.parse(text)


## Leaves the current game, returns to the menu and joins another one from there.
## `address` may also be an online invite (DUST-XXXXXX).
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
	return ping_to(target)


## Round trip to one peer in ms (0 = not known yet): the transport's own figure
## when it has one (ENet), else our own ping RPCs (Epic P2P has none).
func ping_to(peer_id: int) -> int:
	if _peer == null or peer_id == multiplayer.get_unique_id():
		return 0
	if multiplayer.is_server() and not multiplayer.get_peers().has(peer_id):
		return 0 # not connected (e.g. a CPU teammate's roster slot): don't ask the transport
	var own := _backend.ping_ms(_peer, peer_id) if _backend != null else 0
	return own if own > 0 else int(_rtt.get(peer_id, 0))


## "  -  42 ms" for a lobby roster row ("" when there's nothing to show): the
## host sees each partner's ping, a partner sees their own ping to the host.
func ping_note(peer_id: int) -> String:
	if not is_online():
		return ""
	var ms := 0
	if multiplayer.is_server():
		ms = ping_to(peer_id)
	elif peer_id == multiplayer.get_unique_id():
		ms = ping_to(1)
	return "  -  %d ms" % ms if ms > 0 else ""


func _process(delta: float) -> void:
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_ping_wait -= delta
	if _ping_wait > 0.0:
		return
	_ping_wait = PING_INTERVAL_SEC
	var now := Time.get_ticks_msec()
	if multiplayer.is_server():
		for id: int in players:
			if id != 1:
				_ping.rpc_id(id, now)
	elif players.has(multiplayer.get_unique_id()):
		_ping.rpc_id(1, now)


@rpc("any_peer", "unreliable")
func _ping(sent_ms: int) -> void:
	_pong.rpc_id(multiplayer.get_remote_sender_id(), sent_ms)


@rpc("any_peer", "unreliable")
func _pong(sent_ms: int) -> void:
	var ms := Time.get_ticks_msec() - sent_ms
	if ms < 0 or ms > 30000:
		return
	var id := multiplayer.get_remote_sender_id()
	var old := int(_rtt.get(id, 0))
	_rtt[id] = ms if old <= 0 else roundi(lerpf(old, ms, 0.3)) # smoothed
	_pongs += 1
	if _pongs % 15 == 1 and OS.get_cmdline_user_args().has("--netlog"):
		print("[net] ping to peer %d: %d ms (get_ping_ms %d)" % [id, int(_rtt[id]), get_ping_ms()])
	ping_changed.emit()


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

func _on_peer_connected(id: int) -> void:
	_netlog("peer %d connected (I am %d)" % [id, multiplayer.get_unique_id()]) # the client registers itself with its name


## --netlog: one line about the connection's life.
func _netlog(text: String) -> void:
	if GameState.has_flag("--netlog"):
		print("[net] %s" % text)


func _on_peer_disconnected(id: int) -> void:
	_netlog("peer %d disconnected (was %s)" % [id, "a player" if players.has(id) else "not registered"])
	_rtt.erase(id)
	if multiplayer.is_server() and players.has(id):
		players.erase(id)
		_broadcast()
	player_left.emit(id)


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	# Story: a chapter lobby seats up to four (the chapter moves to a bigger map to fit them).
	if players.size() >= (MAX_PLAYERS if Story.active() else max_players()):
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
	if solo:
		need = 1 # solo: readying up rides out
	if all_ready() and players.size() >= need:
		start_game()


## Host only: starts the run with whoever is in the lobby (also used for solo testing).
func start_game() -> void:
	if not multiplayer.is_server() or _started:
		return
	_started = true
	if _peer != null:
		_peer.refuse_new_connections = true
	if _backend != null:
		_backend.set_joinable(false) # the online lobby stops showing up in searches
	Story.fit_map() # Story: the chapter's map, or a bigger one for a bigger posse
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
	LoadTimes.begin("world")
	map_id = StringName(id)
	MapDef.select(map_id)
	SceneFade.go(WORLD_SCENE) # fade to black, then load the world


# ------------------------------------------------------------------ client side

func _on_connected_to_server() -> void:
	_netlog("connected to the host as peer %d" % multiplayer.get_unique_id())
	_register.rpc_id(1, local_name)
	connected_to_host.emit()


func _on_connection_failed() -> void:
	_netlog("connection to the host failed")
	leave()
	connection_failed.emit("Could not reach the host.")


func _on_server_disconnected() -> void:
	leave()
	menu_message = "The host left the game, or the connection to them dropped."
	print("[net] lost the host: back to the menu")
	server_closed.emit()
