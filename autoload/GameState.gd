extends Node
## Global game state: phase, wave number, phase timer, Homestead health, win/lose.
## The host runs the clock and broadcasts every change with reliable RPCs;
## clients count down locally. A wave ends when WaveDirector says every bug is dead.

signal phase_changed(new_phase: Phase)
signal skip_votes_changed(votes: int, needed: int)
## Everyone readied: the wave rides in after a short countdown (-1 = no countdown).
signal ready_countdown_changed(seconds: float)
signal homestead_changed(cliff_id: int, hp: float, max_hp: float)
signal game_over(won: bool, reason: String)

enum Phase { LOBBY, BUILD, WARNING, WAVE, GAME_OVER }

var phase: Phase = Phase.LOBBY
var wave: int = 0
var time_left: float = 0.0
var skip_votes: int = 0
## Seconds until the wave comes once everyone has readied; -1 while not counting.
var ready_countdown: float = -1.0
const READY_COUNTDOWN := 5.0
var homestead_hp: Array[float] = [0.0, 0.0]
## Max HP per Homestead (reinforcing the house raises it).
var homestead_max: Array[float] = [0.0, 0.0]
## Raining right now (rain catchers fill fast). Follows the weather.
var storm := false
## This wave's weather (Weather.Kind). Rolled at the warning bell, cleared after the wave.
var weather: int = Weather.Kind.CLEAR
signal weather_changed(kind: int)
var won := false
## Past the last wave by choice: waves keep coming (and growing) with no end.
var endless := false
var end_reason := ""
## True while the pause menu (or another full-screen menu) is open: the local player stops.
var menu_open: bool = false
## Debug: Homesteads take no damage.
var god_mode: bool = false
## The tutorial run (main menu > Tutorial): a gentle scripted solo game that is
## never saved and never pays Notches. Not cleared by reset() (start_run calls
## it); the main menu clears it.
var tutorial := false
## Command-line flags (anything after `--` on the command line).
var flags: PackedStringArray = PackedStringArray()

var _voters: Dictionary = {}

# ---- Waterworks: every cliff's generator lever (see Waterworks) ----
## Every peer: each cliff's lever, thrown or not (the host decides and syncs).
signal levers_changed
var levers: Array[bool] = []
## Host: CPU teammates' levers (cliff -> true once thrown this build phase).
var cpu_levers: Dictionary = {}


func _ready() -> void:
	flags = OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--") and not flags.has(arg):
			flags.append(arg)


func has_flag(flag: String) -> bool:
	return flags.has(flag)


## Debug cheats are on: launched with --debug, or Debug mode ticked in Settings.
## In multiplayer the host's setting decides, since cheats run on the host.
func debug_enabled() -> bool:
	return flags.has("--debug") or Settings.debug_mode


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
	ready_countdown = -1.0
	won = false
	endless = false
	storm = false
	weather = Weather.Kind.CLEAR
	end_reason = ""
	god_mode = false
	var hp := config().homestead_hp
	homestead_hp.clear()
	homestead_max.clear()
	for cid in WorldLayout.cliff_count(): # Maps: one Homestead per cliff
		homestead_hp.append(hp)
		homestead_max.append(hp)
	cpu_levers.clear()
	levers.clear()
	for cid in WorldLayout.cliff_count():
		levers.append(false)


func is_solo() -> bool:
	# A CPU teammate makes it a two-sided game: you build for its cliff, it for yours.
	return NetworkManager.players.size() <= 1 and not NetworkManager.has_cpu()


func _process(delta: float) -> void:
	if phase == Phase.LOBBY or phase == Phase.GAME_OVER or phase == Phase.WAVE:
		return
	if phase == Phase.BUILD and ready_countdown >= 0.0:
		ready_countdown = maxf(ready_countdown - delta, 0.0)
		if multiplayer.is_server() and ready_countdown <= 0.0:
			ready_countdown = -1.0
			_advance()
		return
	# The build phase has no clock: it lasts until everyone has readied up (G).
	# Automated runs (--fast) keep a timer so they can play themselves.
	if phase == Phase.BUILD and not has_flag("--fast"):
		return
	time_left = maxf(time_left - delta, 0.0)
	if multiplayer.is_server() and time_left <= 0.0:
		_advance()


# ------------------------------------------------------------------ host side

## Host only: begins wave 1's build phase (or `first_wave`'s, resuming a saved run).
func start_run(first_wave: int = 1) -> void: # [Foundation hook] first_wave for Continue last run
	if not multiplayer.is_server():
		return
	reset()
	Economy.reset()
	GunShop.reset_loadouts()
	_sync_homesteads_reliable.rpc(homestead_hp, homestead_max)
	wave = maxi(first_wave, 1)
	if first_wave <= 1 and has_flag("--debug") and flag_value("--startwave") != "":
		wave = clampi(int(flag_value("--startwave")), 1, 999)
		endless = wave > config().last_wave
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
	if wave >= config().last_wave and not endless:
		_finish.rpc(true, "You held the canyon for %d waves!" % wave)
		return
	wave += 1
	_enter(Phase.BUILD)


func _enter(p: Phase) -> void:
	var duration := 0.0
	match p:
		Phase.BUILD:
			duration = config().build_time(wave) * _time_scale()
			if Airship.visits(wave):
				duration += 60.0 * _time_scale() # the casino ship's reprieve
		Phase.WARNING:
			# Waterworks: the pumps come on, the ground rumbles, then the bugs come.
			duration = Waterworks.warning_time(_time_scale())
	_voters.clear()
	var w := weather
	if p == Phase.WARNING:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		w = Weather.roll(rng, Weather.is_night(12.0 + 6.0 * float(maxi(wave - 1, 0))))
		# Boss: the Mirage Mantis only hunts in dust storms; when she's due, the dust often comes with her.
		var wd := get_node_or_null("/root/WaveDirector")
		if wd != null and bool(wd.call("mantis_due")) and rng.randf() < BossRotation.MANTIS_DUST_CHANCE:
			w = Weather.Kind.DUST_STORM
		if wave <= 1:
			w = Weather.Kind.CLEAR # the first wave is always plain weather
		if flag_value("--weather") != "":
			w = clampi(int(flag_value("--weather")), 0, Weather.Kind.BLOOD_MOON)
	elif p == Phase.BUILD or p == Phase.LOBBY:
		w = Weather.Kind.CLEAR
	_sync_phase.rpc(p, duration, wave, w)
	# Waterworks: the levers drop when a build phase starts; the wave runs with
	# every generator going (a timed --fast run throws them for you).
	if p == Phase.BUILD:
		cpu_levers.clear()
	elif p == Phase.WARNING or p == Phase.WAVE:
		for cid in WorldLayout.cliff_count():
			cpu_levers[cid] = true
	_push_levers()
	if p == Phase.WARNING:
		_ground_rumble.rpc(Waterworks.rumble_time(_time_scale()))


## Every peer: the pumps are on and the ground rumbles (sound, a light shake,
## dust out of every tunnel); the host's warning clock brings the bugs after it.
@rpc("authority", "call_local", "reliable")
func _ground_rumble(seconds: float) -> void:
	var scene := get_tree().current_scene
	if scene != null:
		# Loaded here, not named: the autoload must not pull the world's scripts in.
		load("res://scenes/farm/ground_rumble.gd").call("play", scene, seconds)


@rpc("authority", "call_local", "reliable")
func _sync_phase(p: int, duration: float, w: int, kind: int) -> void:
	wave = w
	var changed := kind != weather
	weather = kind
	storm = Weather.is_rain(kind)
	if changed:
		weather_changed.emit(kind)
	time_left = duration
	phase = p as Phase
	skip_votes = 0
	ready_countdown = -1.0
	_local_ready = false
	skip_votes_changed.emit(0, _needed_votes())
	ready_countdown_changed.emit(-1.0)
	phase_changed.emit(phase)


## Degrees F right now (time of day plus weather).
func temperature() -> float:
	var hour := DayCycle.instance.hour() if DayCycle.instance != null else 12.0
	return Weather.temperature(hour, weather)


## Host: damage to a Homestead. Losing either one loses the run (shared fate).
func damage_homestead(cliff_id: int, amount: float) -> void:
	if not multiplayer.is_server() or phase == Phase.GAME_OVER or god_mode:
		return
	homestead_hp[cliff_id] = maxf(homestead_hp[cliff_id] - amount, 0.0)
	_sync_homesteads.rpc(homestead_hp, homestead_max)
	if homestead_hp[cliff_id] <= 0.0:
		var side := WorldLayout.map().name_of(cliff_id) # Maps: "West Cliff", "North Butte"...
		_finish.rpc(false, "The %s Homestead fell on wave %d." % [side, wave])


@rpc("authority", "call_local", "unreliable")
func _sync_homesteads(hp: Array, mx: Array) -> void: # Maps: one entry per cliff
	homestead_hp.assign(hp)
	homestead_max.assign(mx)
	for cid in homestead_hp.size():
		homestead_changed.emit(cid, homestead_hp[cid], homestead_max[cid])


# One-shot changes (run start, upgrades, repairs) must arrive: a dropped packet
# would leave the partner's HUD on stale (or 0/0) house HP until the next hit.
@rpc("authority", "call_local", "reliable")
func _sync_homesteads_reliable(hp: Array, mx: Array) -> void:
	_sync_homesteads(hp, mx)


## Host: raise a Homestead's max HP (the extra is added to its current HP too).
func raise_homestead_max(cliff_id: int, extra: float) -> void:
	if not multiplayer.is_server():
		return
	homestead_max[cliff_id] += extra
	homestead_hp[cliff_id] += extra
	_sync_homesteads_reliable.rpc(homestead_hp, homestead_max)


## Host: patch a Homestead up (never past its max).
func heal_homestead(cliff_id: int, amount: float) -> void:
	if not multiplayer.is_server() or phase == Phase.GAME_OVER:
		return
	homestead_hp[cliff_id] = minf(homestead_hp[cliff_id] + amount, homestead_max[cliff_id])
	_sync_homesteads_reliable.rpc(homestead_hp, homestead_max)


@rpc("authority", "call_local", "reliable")
func _finish(did_win: bool, reason: String) -> void:
	won = did_win
	end_reason = reason
	phase = Phase.GAME_OVER
	phase_changed.emit(phase)
	game_over.emit(did_win, reason)


## Host: after the win screen, keep the waves coming past the last one (endless).
func continue_endless() -> void:
	if not multiplayer.is_server() or phase != Phase.GAME_OVER or not won:
		return
	_set_endless.rpc()
	wave += 1
	_enter(Phase.BUILD)


@rpc("authority", "call_local", "reliable")
func _set_endless() -> void:
	endless = true
	won = false
	end_reason = ""


## Any player: vote to skip the rest of the build phase ("Ready").
func vote_skip() -> void:
	if phase != Phase.BUILD:
		return
	if multiplayer.is_server():
		_add_vote(1)
	else:
		_local_ready = true
		_request_vote.rpc_id(1)


## The ready key (G): ready up, or take it back (also cancels a running countdown).
func toggle_ready() -> void:
	if phase != Phase.BUILD:
		return
	if multiplayer.is_server():
		_toggle_vote(1)
	else:
		_local_ready = not _local_ready
		_request_toggle.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_toggle() -> void:
	if multiplayer.is_server():
		_toggle_vote(multiplayer.get_remote_sender_id())


func _toggle_vote(id: int) -> void:
	if phase != Phase.BUILD:
		return
	if _voters.has(id):
		_voters.erase(id)
		_sync_votes.rpc(_voters.size())
		if ready_countdown >= 0.0:
			_sync_countdown.rpc(-1.0)
			# Waterworks: called off: the CPUs' levers go back up with it.
			cpu_levers.clear()
		_push_levers()
	else:
		_add_vote(id)


## True when this peer has readied (host knows; clients track their own press).
func is_ready_local() -> bool:
	return _voters.has(multiplayer.get_unique_id()) if multiplayer.is_server() else _local_ready


var _local_ready := false


@rpc("authority", "call_local", "reliable")
func _sync_countdown(seconds: float) -> void:
	ready_countdown = seconds
	ready_countdown_changed.emit(seconds)


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
	if multiplayer.is_server() and debug_enabled():
		_advance()


func _add_vote(id: int) -> void:
	if phase != Phase.BUILD:
		return
	if _voters.has(id):
		return
	_voters[id] = true
	_sync_votes.rpc(_voters.size())
	if _voters.size() >= _needed_votes() and ready_countdown < 0.0:
		# Everyone's ready: a short countdown anyone can call off with the ready key
		# (Waterworks: by pulling their lever back). CPU teammates throw theirs now.
		for cid: int in (NetworkManager.cpu_cliffs() if NetworkManager.has_cpu() else []):
			cpu_levers[cid] = true
		_sync_countdown.rpc(READY_COUNTDOWN * _time_scale())
	_push_levers()


# ------------------------------------------------------------------ Waterworks levers

## Is cliff `cid`'s generator lever thrown? (every peer)
func lever_thrown(cid: int) -> bool:
	return cid >= 0 and cid < levers.size() and levers[cid]


## Are the generators running (and the well pumps on)? (every peer)
func pumps_on() -> bool:
	return Waterworks.pumps_on(phase, ready_countdown)


## Host: a CPU teammate throws (or pulls back) its lever.
func throw_cpu_lever(cid: int, on: bool = true) -> void:
	if not multiplayer.is_server() or phase != Phase.BUILD:
		return
	if on:
		cpu_levers[cid] = true
	else:
		cpu_levers.erase(cid)
	_push_levers()


## Host: work out every cliff's lever from who has readied and tell everyone.
func _push_levers() -> void:
	if not multiplayer.is_server():
		return
	var cliff_of := {}
	var held := {}
	for id: int in NetworkManager.players:
		cliff_of[id] = NetworkManager.cliff_of(id)
		held[NetworkManager.cliff_of(id)] = true
	if NetworkManager.has_cpu():
		for cid: int in NetworkManager.cpu_cliffs():
			held[cid] = true
	if NetworkManager.players.is_empty():
		cliff_of[1] = 0 # offline / solo test runs: the local player stands on cliff 0
		held[0] = true
	var all_ready := _voters.size() >= _needed_votes()
	_sync_levers.rpc(Waterworks.levers(WorldLayout.cliff_count(), _voters.keys(), cliff_of, cpu_levers, all_ready, held))


@rpc("authority", "call_local", "reliable")
func _sync_levers(states: Array) -> void:
	levers.assign(states)
	levers_changed.emit()


@rpc("authority", "call_local", "reliable")
func _sync_votes(votes: int) -> void:
	skip_votes = votes
	skip_votes_changed.emit(votes, _needed_votes())


func _needed_votes() -> int:
	return maxi(NetworkManager.players.size(), 1)
