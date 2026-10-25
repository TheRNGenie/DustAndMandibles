extends Node
## Global game state: phase, wave number, phase timer.
## The host runs the clock and broadcasts each phase change with a reliable RPC;
## clients count down locally. Homestead HP and win/lose arrive in M2.

signal phase_changed(new_phase: Phase)
signal skip_votes_changed(votes: int, needed: int)

enum Phase { LOBBY, BUILD, WARNING, WAVE, GAME_OVER }

const BUILD_TIME_FIRST := 150.0
const BUILD_TIME_LAST := 90.0
const WARNING_TIME := 10.0
## Placeholder wave length until M2's bugs end the wave.
const PLACEHOLDER_WAVE_TIME := 30.0
const LAST_WAVE := 10

var phase: Phase = Phase.LOBBY
var wave: int = 0
var time_left: float = 0.0
var skip_votes: int = 0
## True while the pause menu (or another full-screen menu) is open: the local player stops.
var menu_open: bool = false
## Command-line flags (anything after `--` on the command line).
var flags: PackedStringArray = PackedStringArray()

var _voters: Dictionary = {}


func _ready() -> void:
	flags = OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--") and not flags.has(arg):
			flags.append(arg)


func has_flag(flag: String) -> bool:
	return flags.has(flag)


## Value of a `--name=value` flag, or "" if absent.
func flag_value(flag: String) -> String:
	for f: String in flags:
		if f.begins_with(flag + "="):
			return f.substr(flag.length() + 1)
	return ""


func reset() -> void:
	phase = Phase.LOBBY
	wave = 0
	time_left = 0.0
	_voters.clear()
	skip_votes = 0


func _process(delta: float) -> void:
	if phase == Phase.LOBBY or phase == Phase.GAME_OVER:
		return
	time_left = maxf(time_left - delta, 0.0)
	if multiplayer.is_server() and time_left <= 0.0:
		_advance()


# ------------------------------------------------------------------ host side

## Host only: begins wave 1's build phase.
func start_run() -> void:
	if not multiplayer.is_server():
		return
	wave = 1
	_enter(Phase.BUILD)


func build_time(w: int) -> float:
	var t := clampf(float(w - 1) / float(LAST_WAVE - 1), 0.0, 1.0)
	return lerpf(BUILD_TIME_FIRST, BUILD_TIME_LAST, t) * _time_scale()


func _time_scale() -> float:
	return 0.15 if has_flag("--fast") else 1.0


func _advance() -> void:
	match phase:
		Phase.BUILD:
			_enter(Phase.WARNING)
		Phase.WARNING:
			_enter(Phase.WAVE)
		Phase.WAVE:
			wave += 1
			_enter(Phase.BUILD)


func _enter(p: Phase) -> void:
	var duration := 0.0
	match p:
		Phase.BUILD:
			duration = build_time(wave)
		Phase.WARNING:
			duration = WARNING_TIME * maxf(_time_scale(), 0.5)
		Phase.WAVE:
			duration = PLACEHOLDER_WAVE_TIME * maxf(_time_scale(), 0.5)
	_voters.clear()
	_sync_phase.rpc(p, duration, wave)


@rpc("authority", "call_local", "reliable")
func _sync_phase(p: int, duration: float, w: int) -> void:
	wave = w
	time_left = duration
	phase = p as Phase
	skip_votes = 0
	skip_votes_changed.emit(0, _needed_votes())
	phase_changed.emit(phase)


## Any player: vote to skip the rest of the build phase ("Ready").
func vote_skip() -> void:
	if phase != Phase.BUILD:
		return
	if multiplayer.is_server():
		_add_vote(1)
	else:
		_request_vote.rpc_id(1)


## Debug: skip straight to the next phase.
func debug_skip() -> void:
	if multiplayer.is_server():
		_advance()
	else:
		_request_debug_skip.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_vote() -> void:
	if multiplayer.is_server():
		_add_vote(multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func _request_debug_skip() -> void:
	if multiplayer.is_server() and has_flag("--debug"):
		_advance()


func _add_vote(id: int) -> void:
	if phase != Phase.BUILD:
		return
	_voters[id] = true
	_sync_votes.rpc(_voters.size())
	if _voters.size() >= _needed_votes():
		_advance()


@rpc("authority", "call_local", "reliable")
func _sync_votes(votes: int) -> void:
	skip_votes = votes
	skip_votes_changed.emit(votes, _needed_votes())


func _needed_votes() -> int:
	return maxi(NetworkManager.players.size(), 1)
