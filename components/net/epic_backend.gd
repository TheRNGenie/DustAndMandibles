extends OnlineBackend
## Epic Online Services (via the EOSG plugin, addons/epic-online-services-godot).
## This file holds EVERY EOS call in the game; delete it and the addon folder to
## remove Epic (see the notes in online_backend.gd).
##
##   Login: anonymous EOS Connect with a Device ID. Players need no Epic account;
##          the SDK makes an id for this PC the first time.
##   Host:  an EOSGMultiplayerPeer server on SOCKET, then an EOS lobby (max
##          players = the map's) holding the invite code and the game version.
##   Join:  search lobbies for the code, join the lobby, then connect P2P to its
##          owner. EOS P2P punches through NATs and falls back to Epic's relay
##          servers, so it works behind any router with no port forwarding.
##
## No class_name, and the plugin is only reached through Engine.get_singleton
## and ClassDB: this script compiles (and the game runs on DirectBackend) when
## the plugin or its DLLs are missing.
##
## Credentials (Epic Developer Portal > your product > Product Settings):
##   release builds: res://eos_release.cfg, written by .github/workflows/release.yml
##                   from the repository secrets EOS_PRODUCT_ID, EOS_SANDBOX_ID,
##                   EOS_DEPLOYMENT_ID, EOS_CLIENT_ID, EOS_CLIENT_SECRET.
##   development:    res://eos_credentials.txt ("Product ID: ..." lines, gitignored).
##   tests:          --eoscreds=<path to either format>.

const RELEASE_CFG := "res://eos_release.cfg"
const DEV_TXT := "res://eos_credentials.txt"
const KEYS := ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]
## The P2P socket both sides open (letters and digits, at most 32).
const SOCKET := "DustAndMandibles"
const BUCKET := "dust"
const ATTR_CODE := "CODE"
const ATTR_VERSION := "VERSION"
const TIMEOUT_SEC := 20.0

# EOS values used here (EOS_EResult and enums; names as in the plugin's eos.gd).
const R_SUCCESS := 0
const R_INVALID_USER := 3
const R_ALREADY_CONFIGURED := 15
const R_DUPLICATE_NOT_ALLOWED := 24
const CREDENTIAL_DEVICEID := 10
const PERMISSION_PUBLIC := 0
const PERMISSION_INVITE_ONLY := 2
const ATTR_PUBLIC := 0
const COMPARE_EQUAL := 0
const RELAY_ALLOW := 1
const RELAY_FORCE := 2
const RTC_MANUAL_JOIN := 1
const FLAG_NO_OVERLAYS := 0x2 | 0x4 # DisableOverlay | DisableSocialOverlay

var _ieos: Object
var _creds: Dictionary = {}
var _state := "" # "", "logging_in", "ready", "failed"
var _platform := false
var _user_id := ""
var _lobby_id := ""
var _code := ""
var _owner := false
var _lobby_error := ""
## Bumped on every host/join/leave so late callbacks from an old lobby are ignored.
var _session := 0


## Options for an IEOS call: EOSG reads each field with Object.get(), so any
## RefCounted answering those names works. Every field EOSG reads is given.
class Opts extends RefCounted:
	var d: Dictionary

	func _init(fields: Dictionary) -> void:
		d = fields

	func _get(property: StringName) -> Variant:
		return d.get(String(property))


func _init() -> void:
	name = "EpicBackend"
	if Engine.has_singleton("IEOS") and ClassDB.class_exists("EOSGMultiplayerPeer"):
		_ieos = Engine.get_singleton("IEOS")


func configure() -> void:
	_creds = load_credentials(flag_value("--eoscreds"))


func backend_name() -> String:
	return "Epic"


func is_available() -> bool:
	return _ieos != null and not _creds.is_empty()


func unavailable_reason() -> String:
	if _ieos == null:
		return "Epic online is off (its plugin isn't loaded), so invites are direct connections."
	if _creds.is_empty():
		return "Epic online is off (no credentials in this build), so invites are direct connections."
	return ""


func is_ready() -> bool:
	return _state == "ready"


func is_signing_in() -> bool:
	return _state == "logging_in"


func _process(_delta: float) -> void:
	if _platform:
		_ieos.call("tick")


func _exit_tree() -> void:
	leave()
	if _platform:
		_platform = false
		_ieos.call("platform_interface_release")
		_ieos.call("platform_interface_shutdown")


# ------------------------------------------------------------------ login

func login() -> void:
	if _state == "logging_in" or _state == "ready":
		return
	_state = "logging_in"
	last_error = ""
	status_changed.emit()
	var err := await _login()
	_state = "ready" if err == "" else "failed"
	last_error = err
	print("[net] Epic: %s" % ("logged in as %s" % _user_id if err == "" else "login failed: " + err))
	status_changed.emit()


## "" on success, else what went wrong.
func _login() -> String:
	if not _platform:
		var r := int(_ieos.call("platform_interface_initialize", Opts.new({
			"product_name": "Dust & Mandibles", "product_version": game_version})))
		if r != R_SUCCESS and r != R_ALREADY_CONFIGURED:
			return "the EOS SDK didn't start (%d)" % r
		var ok := bool(_ieos.call("platform_interface_create", Opts.new({
			"product_id": _creds["product_id"], "sandbox_id": _creds["sandbox_id"],
			"deployment_id": _creds["deployment_id"], "client_id": _creds["client_id"],
			"client_secret": _creds["client_secret"], "encryption_key": "",
			"flags": FLAG_NO_OVERLAYS, "is_server": false, "override_country_code": "",
			"override_locale_code": "", "tick_budget_in_milliseconds": 0,
			"task_network_timeout_seconds": null,
			"cache_directory": ProjectSettings.globalize_path("user://eosg-cache" + ("-2" if flags.has("--eosnewdevice") else "")),
			"rtc_options": Opts.new({"background_mode": null})})))
		if not ok:
			return "the EOS platform couldn't be created (check the credentials)"
		_platform = true
		_ieos.connect("connect_interface_auth_expiration", _on_auth_expiring)
	# --eosnewdevice (tests: a second copy on the same PC): drop this PC's Device ID
	# and make a fresh one, so the two copies are two different anonymous players.
	if flags.has("--eosnewdevice"):
		_ieos.call("connect_interface_delete_device_id", Opts.new({"client_data": null}))
		await _wait("connect_interface_delete_device_id_callback")
	# A Device ID: an anonymous account for this PC (already there after the first run).
	_ieos.call("connect_interface_create_device_id", Opts.new({
		"device_model": "%s %s" % [OS.get_name(), OS.get_model_name()], "client_data": null}))
	var dev: Variant = await _wait("connect_interface_create_device_id_callback")
	if dev == null:
		return "Epic's servers didn't answer (no internet?)"
	var dr := int((dev as Dictionary)["result_code"])
	if dr != R_SUCCESS and dr != R_DUPLICATE_NOT_ALLOWED:
		return "couldn't make a device id (%s)" % _result_words(dr)
	var res: Variant = await _connect_login()
	if res == null:
		return "Epic's servers didn't answer (no internet?)"
	var data := res as Dictionary
	if int(data["result_code"]) == R_INVALID_USER:
		# First run on this PC: make the anonymous user, then log in again (the
		# plugin's P2P layer starts on a successful login).
		_ieos.call("connect_interface_create_user", Opts.new({
			"continuance_token": data["continuance_token"], "client_data": null}))
		var made: Variant = await _wait("connect_interface_create_user_callback")
		if made == null or int((made as Dictionary)["result_code"]) != R_SUCCESS:
			return "couldn't create the anonymous user (%s)" % ("timeout" if made == null else _result_words(int((made as Dictionary)["result_code"])))
		res = await _connect_login()
		if res == null:
			return "Epic's servers didn't answer (no internet?)"
		data = res as Dictionary
	if int(data["result_code"]) != R_SUCCESS:
		return "login was refused (%s)" % _result_words(int(data["result_code"]))
	_user_id = str(data["local_user_id"])
	# Relays: used when a direct path can't be punched. --eosrelay (tests) forces
	# them, so two copies on one PC still go through Epic's relay servers.
	_ieos.call("p2p_interface_set_relay_control", RELAY_FORCE if flags.has("--eosrelay") else RELAY_ALLOW)
	return ""


## A few EOS_EResult codes in words; the rest as "EOS error N".
static func _result_words(code: int) -> String:
	match code:
		1:
			return "no connection to Epic"
		2:
			return "Epic rejected the credentials"
		27:
			return "Epic timed out"
		1015:
			return "Epic doesn't know this client id"
	return "EOS error %d" % code


func _connect_login() -> Variant:
	_ieos.call("connect_interface_login", Opts.new({
		"credentials": Opts.new({"type": CREDENTIAL_DEVICEID, "token": ""}),
		"user_login_info": Opts.new({"display_name": player_name.left(32), "nsa_id_token": ""}),
		"client_data": null}))
	return await _wait("connect_interface_login_callback")


## The Device ID login lasts about an hour; EOS warns before it runs out.
func _on_auth_expiring(_data: Dictionary) -> void:
	var res: Variant = await _connect_login()
	if res == null or int((res as Dictionary)["result_code"]) != R_SUCCESS:
		push_warning("[net] Epic: couldn't refresh the login")


## Waits for one IEOS callback signal; its Dictionary, or null after TIMEOUT_SEC.
func _wait(signal_name: String) -> Variant:
	var box: Array = [null, false]
	var on := func(data: Dictionary) -> void:
		box[0] = data
		box[1] = true
	var sig := Signal(_ieos, signal_name)
	sig.connect(on, CONNECT_ONE_SHOT)
	var until := Time.get_ticks_msec() + int(TIMEOUT_SEC * 1000.0)
	while not bool(box[1]) and Time.get_ticks_msec() < until and is_inside_tree():
		await get_tree().process_frame
	if not bool(box[1]) and sig.is_connected(on):
		sig.disconnect(on)
	return box[0]


# ------------------------------------------------------------------ host

func host(max_players: int, attrs: Dictionary) -> MultiplayerPeer:
	leave()
	if not is_ready():
		last_error = "Epic online isn't signed in (%s)." % (last_error if last_error != "" else "still signing in")
		return null
	var peer := ClassDB.instantiate("EOSGMultiplayerPeer") as MultiplayerPeer
	var err := int(peer.call("create_server", SOCKET))
	if err != OK:
		last_error = "Couldn't open the Epic P2P socket (error %d)." % err
		return null
	_owner = true
	_lobby_error = ""
	_log_connections(peer)
	_create_lobby(max_players, attrs, _session)
	return peer


func _create_lobby(max_players: int, attrs: Dictionary, session: int) -> void:
	_ieos.call("lobby_interface_create_lobby", Opts.new({
		"local_user_id": _user_id, "bucket_id": BUCKET, "lobby_id": "",
		"max_lobby_members": max_players, "permission_level": PERMISSION_PUBLIC,
		"presence_enabled": false, "allow_invites": false, "disable_host_migration": true,
		"enable_rtc_room": false, "crossplay_opt_out": false, "local_rtc_options": null,
		"rtc_room_join_action_type": RTC_MANUAL_JOIN, "enable_join_by_id": false,
		"rejoin_after_kick_requires_invite": false, "allowed_platform_ids": [],
		"client_data": null}))
	var made: Variant = await _wait("lobby_interface_create_lobby_callback")
	if made != null and int((made as Dictionary)["result_code"]) == R_SUCCESS and session != _session:
		_destroy_lobby(str((made as Dictionary)["lobby_id"])) # left while it was being made
		return
	if session != _session:
		return
	if made == null or int((made as Dictionary)["result_code"]) != R_SUCCESS:
		_fail_lobby("the online lobby couldn't be created (%s)" % ("timeout" if made == null else str((made as Dictionary)["result_code"])))
		return
	_lobby_id = str((made as Dictionary)["lobby_id"])
	var code := InviteCode.make_lobby_code()
	var all := attrs.duplicate()
	all[ATTR_CODE] = code
	all[ATTR_VERSION] = game_version
	var add_all := func(m: Object) -> void:
		for key: String in all:
			if key != "port":
				m.call("add_attribute", key.to_upper(), all[key], ATTR_PUBLIC)
	var r := await _modify_lobby(add_all, session)
	if session != _session:
		return
	if r != R_SUCCESS:
		_fail_lobby("the invite code couldn't be stored on the lobby (%d)" % r)
		return
	_code = code
	print("[net] Epic lobby %s, invite %s" % [_lobby_id, _code])
	status_changed.emit()


func _fail_lobby(why: String) -> void:
	_lobby_error = why
	push_warning("[net] Epic: " + why)
	status_changed.emit()
	lobby_failed.emit(why)


## Applies `edit` (called with an EOSGLobbyModification) to our lobby; the result code.
func _modify_lobby(edit: Callable, session: int) -> int:
	if _lobby_id == "":
		return -1
	var got: Dictionary = _ieos.call("lobby_interface_update_lobby_modification", Opts.new({
		"local_user_id": _user_id, "lobby_id": _lobby_id}))
	if int(got.get("result_code", -1)) != R_SUCCESS or got.get("lobby_modification") == null:
		return int(got.get("result_code", -1))
	var m: Object = got["lobby_modification"]
	edit.call(m)
	_ieos.call("lobby_interface_update_lobby", Opts.new({"lobby_modification": m, "client_data": null}))
	var done: Variant = await _wait("lobby_interface_update_lobby_callback")
	if session != _session:
		return -1
	return -2 if done == null else int((done as Dictionary)["result_code"])


func set_max_players(n: int) -> void:
	if _owner and _lobby_id != "":
		_modify_lobby(func(m: Object) -> void: m.call("set_max_members", n), _session)


func set_joinable(open: bool) -> void:
	if _owner and _lobby_id != "":
		var level := PERMISSION_PUBLIC if open else PERMISSION_INVITE_ONLY
		_modify_lobby(func(m: Object) -> void: m.call("set_permission_level", level), _session)


# ------------------------------------------------------------------ join

func owns_code(text: String) -> bool:
	return InviteCode.is_lobby_code(text)


func join(code: String) -> MultiplayerPeer:
	leave()
	var session := _session
	var want := InviteCode.normalize_lobby_code(code)
	if want == "":
		last_error = "That doesn't look like an invite code."
		return null
	if _state != "ready":
		if _state != "logging_in":
			login() # failed earlier (no internet?): try again now
		var until := Time.get_ticks_msec() + int(TIMEOUT_SEC * 1000.0)
		while _state == "logging_in" and Time.get_ticks_msec() < until and is_inside_tree():
			await get_tree().process_frame
		if session != _session:
			return null
	if not is_ready():
		last_error = "Online invites need Epic online, which couldn't sign in (%s)." % (last_error if last_error != "" else "timed out")
		return null
	var made: Dictionary = _ieos.call("lobby_interface_create_lobby_search", Opts.new({"max_results": 5}))
	var search: Object = made.get("lobby_search")
	if search == null:
		last_error = "Couldn't search for the game (%s)." % str(made.get("result_code", "?"))
		return null
	search.call("set_parameter", ATTR_CODE, want, COMPARE_EQUAL)
	search.call("find", _user_id)
	var found: Variant = await _wait("lobby_search_find_callback")
	if session != _session:
		return null
	if found == null:
		last_error = "Epic's servers didn't answer. Check your internet and try again."
		return null
	if int((found as Dictionary)["result_code"]) != R_SUCCESS or int(search.call("get_search_result_count")) == 0:
		last_error = "No game with code %s. Check the code, or ask your friend to host again." % want
		return null
	var details: Object = (search.call("copy_search_result_by_index", 0) as Dictionary).get("lobby_details")
	if details == null:
		last_error = "Couldn't read that game's lobby."
		return null
	var ver := _attr(details, ATTR_VERSION)
	if ver != game_version:
		last_error = "That game runs version %s and you have %s. Both of you need the same version." % [ver, game_version]
		return null
	_ieos.call("lobby_interface_join_lobby", Opts.new({
		"local_user_id": _user_id, "lobby_details": details, "presence_enabled": false,
		"local_rtc_options": null, "rtc_room_join_action_type": RTC_MANUAL_JOIN, "client_data": null}))
	var joined: Variant = await _wait("lobby_interface_join_lobby_callback")
	if session != _session:
		if joined != null and int((joined as Dictionary)["result_code"]) == R_SUCCESS:
			_leave_lobby(str((joined as Dictionary)["lobby_id"]))
		return null
	if joined == null or int((joined as Dictionary)["result_code"]) != R_SUCCESS:
		last_error = "Couldn't join that game (it may be full or already started)."
		return null
	_lobby_id = str((joined as Dictionary)["lobby_id"])
	_code = want
	var owner_id := str(details.call("get_lobby_owner"))
	var peer := ClassDB.instantiate("EOSGMultiplayerPeer") as MultiplayerPeer
	var err := int(peer.call("create_client", SOCKET, owner_id))
	if err != OK:
		leave()
		last_error = "Couldn't open the Epic P2P connection (error %d)." % err
		return null
	_log_connections(peer)
	return peer


## Logs how each P2P link was made: punched through directly or via Epic's relay.
static func _log_connections(peer: MultiplayerPeer) -> void:
	peer.connect("peer_connection_established", func(d: Dictionary) -> void:
		var how := ["no connection", "direct", "relayed"]
		var t := int(d.get("network_type", 0))
		print("[net] Epic P2P link to %s: %s" % [str(d.get("remote_user_id", "?")).left(8), how[t] if t >= 0 and t < 3 else str(t)]))


static func _attr(details: Object, key: String) -> String:
	var got: Dictionary = details.call("copy_attribute_by_key", key)
	var a: Variant = got.get("attribute")
	if a == null or not (a as Dictionary).has("data") or (a as Dictionary)["data"] == null:
		return ""
	return str(((a as Dictionary)["data"] as Dictionary).get("value", ""))


# ------------------------------------------------------------------ leave

func leave() -> void:
	_session += 1
	if _lobby_id != "":
		if _owner:
			_destroy_lobby(_lobby_id)
		else:
			_leave_lobby(_lobby_id)
	_lobby_id = ""
	_code = ""
	_owner = false
	_lobby_error = ""


func _destroy_lobby(id: String) -> void:
	_ieos.call("lobby_interface_destroy_lobby", Opts.new({"local_user_id": _user_id, "lobby_id": id, "client_data": null}))


func _leave_lobby(id: String) -> void:
	_ieos.call("lobby_interface_leave_lobby", Opts.new({"local_user_id": _user_id, "lobby_id": id, "client_data": null}))


# ------------------------------------------------------------------ invite

func invite_code() -> String:
	return _code


func invite_note() -> String:
	if not _owner:
		return "The code of the game you're in."
	if _lobby_error != "":
		return "Online lobby failed: %s." % _lobby_error
	if _code == "":
		return "Making your online lobby..."
	return "Works from anywhere, no router setup (Epic Online Services). Send it to your friend; they type it into Join."


# ------------------------------------------------------------------ credentials

## {product_id, sandbox_id, deployment_id, client_id, client_secret}, or {} if
## any is missing. `path` overrides the usual places (tests).
static func load_credentials(path: String = "") -> Dictionary:
	var paths: Array[String] = [RELEASE_CFG, DEV_TXT]
	if path != "":
		paths = [path]
	for p in paths:
		if not FileAccess.file_exists(p):
			continue
		var got := _parse_cfg(p) if p.ends_with(".cfg") else parse_credentials(FileAccess.get_file_as_string(p))
		if not got.is_empty():
			return got
	return {}


static func _parse_cfg(p: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(p) != OK:
		return {}
	var out := {}
	for k: String in KEYS:
		out[k] = str(cfg.get_value("eos", k, "")).strip_edges()
	return _complete(out)


## Reads the credentials however they were written down:
##   "Product ID: abc" / "client_secret=xyz" / "Client Secret  xyz" lines, or
##   a raw copy-paste from the Epic portal, where a label line ("Product ID",
##   "Sandbox type<TAB>Sandbox ID"...) is followed by name lines with spaces and
##   then the id on a line of its own; or five bare lines in KEYS order.
## Label names ignore case, spaces, dashes and underscores.
static func parse_credentials(text: String) -> Dictionary:
	var out := {}
	var bare: Array[String] = []
	var pending := "" # a label seen whose id is on a later line
	var labelled := false
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var norm := line.to_lower().replace("_", " ").replace("-", " ")
		var label := ""
		var after := -1
		for k: String in KEYS:
			var i := norm.rfind(k.replace("_", " "))
			if i >= 0 and i + k.length() > after:
				label = k
				after = i + k.length()
		if label != "":
			labelled = true
			var rest := line.substr(after).strip_edges().trim_prefix(":").trim_prefix("=").strip_edges()
			var value := _first_token(rest)
			if value != "":
				out[label] = value
				pending = ""
			else:
				pending = label
			continue
		# Not a label: an id line (one long token) fills the pending label.
		var token := _first_token(line)
		if pending != "" and token == line and token.length() >= 16:
			if not out.has(pending):
				out[pending] = token
			pending = ""
		elif not labelled:
			bare.append(line)
	if out.is_empty() and bare.size() == KEYS.size():
		for i in KEYS.size():
			out[KEYS[i]] = bare[i]
	return _complete(out)


static func _first_token(s: String) -> String:
	var parts := s.replace("\t", " ").split(" ", false)
	return parts[0].trim_prefix("\"").trim_suffix("\"") if parts.size() > 0 else ""


static func _complete(d: Dictionary) -> Dictionary:
	for k: String in KEYS:
		if str(d.get(k, "")) == "":
			return {}
	return d
