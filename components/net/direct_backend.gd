class_name DirectBackend
extends OnlineBackend
## Direct connections: ENet on a UDP port, the router opened by UPnP when it
## allows it, and invite codes that are the host's address (InviteCode,
## DUST-XXXXX-XXXXX). Needs no service or account; works on a LAN, over a VPN,
## or over the internet when the host's router could be opened. Always
## available, so it is the fallback when no online backend is.

const DEFAULT_PORT := 24565
const DEFAULT_ADDRESS := "127.0.0.1"

## Shown under the invite when an online backend was wanted but isn't usable.
var fallback_note := ""
## Invites over the internet: when hosting, the router is asked (UPnP) to open
## the game's port, and its public address goes into the invite code.
## "" = not tried yet / working, "open" = the internet can reach us, "lan" = same network only.
var upnp_state := ""
var public_ip := ""
var _hosting := false
var _client := false
var _port: int = DEFAULT_PORT
var _address: String = DEFAULT_ADDRESS
var _upnp: UPNP
var _upnp_thread: Thread
var _upnp_port := 0
var _upnp_gen := 0 # bumped on every open/close: a discovery from before is stale
var _upnp_jobs: Array[Thread] = [] # router clean-ups running off the main thread


func backend_name() -> String:
	return "Direct"


func is_available() -> bool:
	return true


func is_ready() -> bool:
	return true


## Hosts on attrs["port"] (or the next free one of the 31 above it).
func host(max_players: int, attrs: Dictionary) -> MultiplayerPeer:
	leave()
	var port := int(attrs.get("port", DEFAULT_PORT))
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players - 1)
	# If the port is taken (another copy of the game, or something else on this
	# PC), try the next few: the invite code carries whichever port we got.
	if err != OK:
		for i in range(1, 32):
			peer = ENetMultiplayerPeer.new()
			err = peer.create_server(port + i, max_players - 1)
			if err == OK:
				print("[net] port %d busy, hosting on %d" % [port, port + i])
				port += i
				break
	if err != OK:
		last_error = "Could not host on port %d (error %d)." % [port, err]
		return null
	_hosting = true
	_port = port
	_open_router(port)
	return peer


## Joins a direct code, "IP:port" or a bare IP (default port).
func join(code: String) -> MultiplayerPeer:
	var parsed := parse(code)
	if parsed.is_empty():
		last_error = "That doesn't look like an invite code."
		return null
	return join_address(str(parsed["address"]), int(parsed["port"]))


func join_address(address: String, port: int) -> MultiplayerPeer:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		last_error = "Could not start connecting (error %d)." % err
		return null
	_port = port
	_address = address
	_client = true
	return peer


func leave() -> void:
	_close_router()
	_hosting = false
	_client = false


func owns_code(text: String) -> bool:
	return not parse(text).is_empty()


## The code a friend types to join this game (DUST-XXXXX-XXXXX): the router's
## public address when it let us open the port, else this PC's LAN address.
func invite_code() -> String:
	if _client:
		return InviteCode.encode(_address, _port) # a client shares the host's address
	var ip := public_ip if upnp_state == "open" and public_ip != "" else local_ip()
	var code := InviteCode.encode(ip, _port)
	return code if code != "" else "%s:%d" % [ip, _port]


## One line on where the invite works, for the lobby and the Social tab.
func invite_note() -> String:
	var note := _where_note()
	return note + ("\n" + fallback_note if fallback_note != "" else "")


func _where_note() -> String:
	if _client:
		return "The code of the game you're in."
	match upnp_state:
		"open":
			return "Works over the internet. Send it to your friend; they type it into Join."
		"lan":
			return "Same network only: your router didn't open port %d by itself. Forward UDP %d, or both use Tailscale / Radmin VPN and join by its IP." % [_port, _port]
	return "Opening your router for internet play..."


func ping_ms(peer: MultiplayerPeer, peer_id: int) -> int:
	var enet := peer as ENetMultiplayerPeer
	if enet == null:
		return 0
	var p := enet.get_peer(peer_id)
	if p == null:
		return 0
	return int(p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))


## Parses a direct code, "IP:port" or a bare IP. Returns {} if it isn't usable.
static func parse(text: String) -> Dictionary:
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


## Best-guess LAN IPv4 address of this machine.
static func local_ip() -> String:
	var fallback := DEFAULT_ADDRESS
	for addr: String in IP.get_local_addresses():
		if addr.contains(":") or addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
		fallback = addr
	return fallback


# ------------------------------------------------------------------ UPnP (host)

## Ask the router to forward our port (on a thread: discovery takes a second or two).
func _open_router(port: int) -> void:
	_close_router()
	upnp_state = ""
	public_ip = ""
	status_changed.emit()
	if flags.has("--debug") or flags.has("--noupnp"):
		upnp_state = "lan" # tests and automated runs never touch the router
		status_changed.emit()
		return
	_upnp_port = port
	_upnp_gen += 1
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port, _upnp_gen))


func _upnp_work(port: int, gen: int) -> void:
	var u := UPNP.new()
	var ip := ""
	var ok := false
	if u.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS \
			and u.get_gateway() != null and u.get_gateway().is_valid_gateway():
		ok = u.add_port_mapping(port, port, "Dust & Mandibles", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
		ip = u.query_external_address()
	# A router behind the provider's own NAT reports a private address: no good for invites.
	if ip == "" or _private(ip):
		ok = false
	_upnp_done.call_deferred(u, ok, ip, gen, port)


static func _private(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return true
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or a == 127 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31) \
			or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)


func _upnp_done(u: UPNP, ok: bool, ip: String, gen: int, port: int) -> void:
	_reap_jobs()
	if gen != _upnp_gen or not _hosting:
		if ok: # we stopped hosting while it worked: take the mapping down again
			_in_background(func() -> void: u.delete_port_mapping(port, "UDP"))
		return
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish() # it has just finished (this was its last call)
		_upnp_thread = null
	_upnp = u if ok else null
	upnp_state = "open" if ok else "lan"
	public_ip = ip if ok else ""
	print("[net] invite: %s (%s)" % [invite_code(), upnp_state])
	status_changed.emit()


## Never waits on the router here: leaving or re-hosting used to block the game
## for 2 to 4 s while UPnP discovery finished or the mapping came down.
func _close_router() -> void:
	_upnp_gen += 1 # a discovery still running cleans up after itself (_upnp_done)
	if _upnp_thread != null:
		_upnp_jobs.append(_upnp_thread) # joined once it ends
		_upnp_thread = null
	if _upnp != null:
		var u := _upnp
		var port := _upnp_port
		_in_background(func() -> void: u.delete_port_mapping(port, "UDP"))
		_upnp = null
	upnp_state = ""
	public_ip = ""


func _in_background(job: Callable) -> void:
	_reap_jobs()
	var t := Thread.new()
	t.start(job)
	_upnp_jobs.append(t)


func _reap_jobs() -> void:
	for t: Thread in _upnp_jobs.duplicate():
		if not t.is_alive():
			t.wait_to_finish()
			_upnp_jobs.erase(t)


func _exit_tree() -> void:
	_close_router()
	for t: Thread in _upnp_jobs: # quitting: let the router clean-up finish
		t.wait_to_finish()
	_upnp_jobs.clear()
