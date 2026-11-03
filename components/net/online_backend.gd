class_name OnlineBackend
extends Node
## How players find each other and which MultiplayerPeer carries the game.
## NetworkManager talks only to this interface; gameplay code (RPCs, spawners,
## roster, map pick, CPU teammates, Continue) never sees a backend.
##
## Backends:
##   DirectBackend  (components/net/direct_backend.gd) ENet + UPnP + DUST-XXXXX-XXXXX
##                  codes (the host's IP and port). Always there; the fallback.
##   EpicBackend    (components/net/epic_backend.gd) Epic Online Services: anonymous
##                  Device ID login (no Epic account), an EOS lobby holding a
##                  DUST-XXXXXX code, and EOS P2P (NAT punch-through, else Epic's
##                  relay) as the MultiplayerPeer. Every EOS call lives in that file.
##
## ---------------------------------------------------------------- removing Epic
## Delete: addons/epic-online-services-godot/, components/net/epic_backend.gd,
## and the "Write the Epic credentials" step in .github/workflows/release.yml
## (plus the EOS_* repository secrets and the *.dll lines in that workflow).
## Nothing else references them: create_online() finds no backend file and the
## game runs on DirectBackend, exactly as before Epic was added.
##
## ---------------------------------------------------------------- adding Steam
## Write components/net/steam_backend.gd extending OnlineBackend (e.g. GodotSteam
## lobbies + SteamMultiplayerPeer) and point ONLINE_BACKEND below at it. It must:
##   backend_name()        "Steam" (shown in notes and logs)
##   is_available()        the plugin/singleton is loaded and Steam is running
##   unavailable_reason()  one line for the lobby when it isn't
##   login()               coroutine: Steam.steamInit(); set _ready and emit
##                         status_changed (Steam needs no separate login)
##   host(max, attrs)      Steam.createLobby(LOBBY_FRIENDS_ONLY or PUBLIC, max);
##                         return a SteamMultiplayerPeer from create_host(0) at
##                         once; when the lobby exists, setLobbyData("code",
##                         InviteCode.make_lobby_code()) and each attrs key, then
##                         emit status_changed so the lobby shows the code
##   join(code)            coroutine: addRequestLobbyListStringFilter("code", code,
##                         EQUAL) + requestLobbyList(); joinLobby(); the owner is
##                         getLobbyOwner(); return SteamMultiplayerPeer
##                         .create_client(owner, 0), or null with last_error set
##   leave()               leaveLobby(); forget the code
##   set_max_players(n)    setLobbyMemberLimit(n)
##   set_joinable(open)    setLobbyJoinable(open)
##   invite_code()/invite_note()/owns_code(text)/ping_ms() as documented below
##   emit lobby_failed(reason) when the lobby can't be made (NetworkManager then
##   hosts directly instead) and status_changed whenever the code/note changes
## (Steam friends can also join from the overlay: answer join_requested by
## calling NetworkManager.join_code() with that lobby's "code" data.)

## Emitted when the backend becomes ready or fails, or the invite code changes.
signal status_changed
## Host: the peer is up but the lobby/code couldn't be made, so nobody can find
## the game. NetworkManager answers by hosting on DirectBackend instead.
signal lobby_failed(reason: String)

## Which online backend to try first (any OnlineBackend script). Change this to
## a Steam backend later; delete the file to run on DirectBackend alone.
const ONLINE_BACKEND := "res://components/net/epic_backend.gd"

## The last failure, in words for the player ("" when none).
var last_error := ""
## Set by NetworkManager (backends never reach into autoloads): the launch's
## user flags (GameState.flags), this build's version and the player's name.
var flags := PackedStringArray()
var game_version := "dev"
var player_name := "Rancher"
var _ready_flag := false


## The online backend (Epic now, Steam later) if its file, plugin and settings
## are all present, else null. `why` gets one line saying why not.
static func create_online(why: Array[String], launch_flags: PackedStringArray) -> OnlineBackend:
	if launch_flags.has("--direct") or (launch_flags.has("--debug") and not launch_flags.has("--epic")):
		why.append("Online lobbies are off for this launch (--direct / --debug; add --epic to test them).")
		return null
	if not ResourceLoader.exists(ONLINE_BACKEND):
		return null # removed: Direct only, no note needed
	var script := load(ONLINE_BACKEND) as GDScript
	if script == null or not script.can_instantiate():
		why.append("Online lobbies unavailable (backend failed to load).")
		return null
	var b := script.new() as OnlineBackend
	if b != null:
		b.flags = launch_flags
		b.configure()
	if b == null or not b.is_available():
		if b != null:
			why.append(b.unavailable_reason())
			b.free()
		return null
	return b


## Called once after `flags` is set, before is_available(): read settings here.
func configure() -> void:
	pass


## A launch flag's value ("--name=value" -> "value"), "" if absent.
func flag_value(flag: String) -> String:
	for f: String in flags:
		if f.begins_with(flag + "="):
			return f.substr(flag.length() + 1)
	return ""


## "Direct", "Epic", "Steam"...
func backend_name() -> String:
	return "None"


## Can this backend run here at all (plugin loaded, settings found)?
func is_available() -> bool:
	return false


## Why it can't, in one line for the lobby ("" when it can).
func unavailable_reason() -> String:
	return ""


## Signs in (coroutine; safe to call without awaiting). Sets is_ready() and
## emits status_changed either way; last_error says why it failed.
func login() -> void:
	_ready_flag = is_available()
	status_changed.emit()


## Signed in and able to host or join right now.
func is_ready() -> bool:
	return _ready_flag


## Still signing in (the menu waits a moment before hosting).
func is_signing_in() -> bool:
	return false


## Host a game: returns a server MultiplayerPeer (this machine is peer 1) or
## null with last_error set. The invite code may arrive later (status_changed).
## attrs: extra settings, e.g. {"port": 24565} for Direct, {"version": "1"}.
func host(_max_players: int, _attrs: Dictionary) -> MultiplayerPeer:
	last_error = "Not supported."
	return null


## Join the game behind an invite code (coroutine): a client MultiplayerPeer
## that is connecting (multiplayer.connected_to_server fires when it's in), or
## null with last_error set.
func join(_code: String) -> MultiplayerPeer:
	last_error = "Not supported."
	return null


## Leave/close the lobby (the peer itself is closed by NetworkManager).
func leave() -> void:
	pass


## Host: the map changed, so the lobby holds this many players now.
func set_max_players(_n: int) -> void:
	pass


## Host: the run started (false) or the lobby reopened (true).
func set_joinable(_open: bool) -> void:
	pass


## The code to send to a friend ("" until the lobby exists).
func invite_code() -> String:
	return ""


## One line under the code: where it works, or what's happening.
func invite_note() -> String:
	return ""


## Is this typed text one of this backend's codes?
func owns_code(_text: String) -> bool:
	return false


## Round-trip time to `peer_id` in ms (0 when unknown).
func ping_ms(_peer: MultiplayerPeer, _peer_id: int) -> int:
	return 0
