extends Node
## Global game state: phase, wave number, phase timer, Homestead health, win/lose.
## The host runs the clock and broadcasts every change with reliable RPCs;
## clients count down locally. A wave ends when WaveDirector says every bug is dead.

signal phase_changed(new_phase: Phase)
signal skip_votes_changed(votes: int, needed: int)
signal homestead_changed(cliff_id: int, hp: float, max_hp: float)
signal game_over(won: bool, reason: String)

enum Phase { LOBBY, BUILD, WARNING, WAVE, GAME_OVER }

var phase: Phase = Phase.LOBBY
var wave: int = 0
var time_left: float = 0.0
var skip_votes: int = 0
var homestead_hp: Array[float] = [0.0, 0.0]
## Max HP per Homestead (reinforcing the house raises it).
var homestead_max: Array[float] = [0.0, 0.0]
## This build phase is a storm: rain catchers fill fast.
var storm := false
var won := false
var end_reason := ""
## True while the pause menu (or another full-screen menu) is open: the local player stops.
var menu_open: bool = false
## Debug: Homesteads take no damage.
var god_mode: bool = false
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


func config() -> WaveConfig:
	return Defs.WAVE_CONFIG


func reset() -> void:
	phase = Phase.LOBBY
	wave = 0
	time_left = 0.0
	_voters.clear()
	skip_votes = 0
	won = false
	storm = false
	end_reason = ""
	god_mode = false
	var hp := config().homestead_hp
	homestead_hp = [hp, hp]
	homestead_max = [hp, hp]


func is_solo() -> bool:
	return NetworkManager.players.size() <= 1


func _process(delta: float) -> void:
	if phase == Phase.LOBBY or phase == Phase.GAME_OVER or phase == Phase.WAVE:
		return
	time_left = maxf(time_left - delta, 0.0)
	if multiplayer.is_server() and time_left <= 0.0:
		_advance()


# ------------------------------------------------------------------ host side

## Host only: begins wave 1's build phase.
func start_run() -> void:
	if not multiplayer.is_server():
		return
	reset()
	Economy.reset()
	GunShop.reset_loadouts()
	_sync_homesteads.rpc(homestead_hp[0], homestead_hp[1], homestead_max[0], homestead_max[1])
	wave = 1
	if has_flag("--debug") and flag_value("--startwave") != "":
		wave = clampi(int(flag_value("--startwave")), 1, config().last_wave)
	_enter(Phase.BUILD)


func _time_scale() -> float:
	return 0.15 if has_flag("--fast") else 1.0


## How fast crops grow and wells fill (faster with --fast so tests see results).
func growth_scale() -> float:
	return 1.0 / _time_scale()


func _advance() -> void:
	match phase:
		Phase.BUILD:
			_enter(Phase.WARNING)
		Phase.WARNING:
			_enter(Phase.WAVE)
		Phase.WAVE:
			end_wave()


## Host: WaveDirector calls this once every bug of the wave is dead.
func end_wave() -> void:
	if not multiplayer.is_server() or phase != Phase.WAVE:
		return
	if wave >= config().last_wave:
		_finish.rpc(true, "You held the canyon for %d waves!" % wave)
		return
	wave += 1
	_enter(Phase.BUILD)


func _enter(p: Phase) -> void:
	var duration := 0.0
	match p:
		Phase.BUILD:
			duration = config().build_time(wave) * _time_scale()
		Phase.WARNING:
			duration = config().warning_time * maxf(_time_scale(), 0.5)
	_voters.clear()
	var is_storm := p == Phase.BUILD and wave >= 2 and randf() < 0.3
	if p != Phase.BUILD:
		is_storm = storm
	_sync_phase.rpc(p, duration, wave, is_storm)


@rpc("authority", "call_local", "reliable")
func _sync_phase(p: int, duration: float, w: int, is_storm: bool) -> void:
	wave = w
	storm = is_storm
	time_left = duration
	phase = p as Phase
	skip_votes = 0
	skip_votes_changed.emit(0, _needed_votes())
	phase_changed.emit(phase)


## Host: damage to a Homestead. Losing either one loses the run (shared fate).
func damage_homestead(cliff_id: int, amount: float) -> void:
	if not multiplayer.is_server() or phase == Phase.GAME_OVER or god_mode:
		return
	homestead_hp[cliff_id] = maxf(homestead_hp[cliff_id] - amount, 0.0)
	_sync_homesteads.rpc(homestead_hp[0], homestead_hp[1], homestead_max[0], homestead_max[1])
	if homestead_hp[cliff_id] <= 0.0:
		var side := "west" if cliff_id == WorldLayout.WEST else "east"
		_finish.rpc(false, "The %s Homestead fell on wave %d." % [side, wave])


@rpc("authority", "call_local", "unreliable_ordered")
func _sync_homesteads(west: float, east: float, west_max: float, east_max: float) -> void:
	homestead_hp = [west, east]
	homestead_max = [west_max, east_max]
	for cid in 2:
		homestead_changed.emit(cid, homestead_hp[cid], homestead_max[cid])


## Host: raise a Homestead's max HP (the extra is added to its current HP too).
func raise_homestead_max(cliff_id: int, extra: float) -> void:
	if not multiplayer.is_server():
		return
	homestead_max[cliff_id] += extra
	homestead_hp[cliff_id] += extra
	_sync_homesteads.rpc(homestead_hp[0], homestead_hp[1], homestead_max[0], homestead_max[1])


## Host: patch a Homestead up (never past its max).
func heal_homestead(cliff_id: int, amount: float) -> void:
	if not multiplayer.is_server() or phase == Phase.GAME_OVER:
		return
	homestead_hp[cliff_id] = minf(homestead_hp[cliff_id] + amount, homestead_max[cliff_id])
	_sync_homesteads.rpc(homestead_hp[0], homestead_hp[1], homestead_max[0], homestead_max[1])


@rpc("authority", "call_local", "reliable")
func _finish(did_win: bool, reason: String) -> void:
	won = did_win
	end_reason = reason
	phase = Phase.GAME_OVER
	phase_changed.emit(phase)
	game_over.emit(did_win, reason)


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
