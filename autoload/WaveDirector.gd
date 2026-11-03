extends Node
## Host only: plans each wave when the build phase starts (so players can see
## what's coming), releases it pulse by pulse on the wave's own schedule (its
## shape: steady stream, one rush, two pushes...), and ends the wave when every
## bug is dead. Also tallies kills per (bug type, kill method) and unlocks
## kill-method variants once a type keeps dying the same way.

const KillMethod := preload("res://scenes/bugs/kill_method.gd")
const KillTally := preload("res://scenes/bugs/kill_tally.gd")

signal wave_announced(heavy_cliff: int, west_share: float, lane_counts: Array)
## The coming wave's bug mix ([[bug id, count], ...], most first), sent while building.
signal wave_previewed(mix: Array)
## Host and clients: a kill-method variant just showed up for the first time this run.
signal variant_unlocked(variant_id: StringName)

## The last preview, for HUDs that open after it was sent.
var preview: Array = []
## The coming wave's shape (WavePlanner.STEADY, RUSH, ...), sent with the preview.
var preview_shape: StringName = &""

var bug_manager: BugManager
var tally := KillTally.new()
var _planner: WavePlanner
var _plan: Dictionary = {}
var _pulse := 0
var _clock := 0.0
var _active := false
var _last_wave := 0
## Boss ids met this run, oldest first (BossRotation never repeats one early).
var boss_seen: Array = []


func _ready() -> void:
	var defs: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		defs.append(Defs.bug(id))
	_planner = WavePlanner.new(Defs.WAVE_CONFIG, defs, int(Time.get_unix_time_from_system()))
	tally.threshold = Defs.WAVE_CONFIG.variant_kills
	# Testing: --variantkills=N makes variants show up after N kills.
	if GameState.flag_value("--variantkills") != "":
		tally.threshold = maxi(int(GameState.flag_value("--variantkills")), 1)
	GameState.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(p: GameState.Phase) -> void:
	if not multiplayer.is_server():
		return
	match p:
		GameState.Phase.LOBBY:
			tally.reset()
			boss_seen.clear()
			_last_wave = 0
		GameState.Phase.BUILD:
			# A new run (wave count went back): forget last run's kills.
			if GameState.wave <= 1 or GameState.wave < _last_wave:
				tally.reset()
				boss_seen.clear()
			_last_wave = GameState.wave
			# Plan the coming wave now, so both players can see what's coming while they build.
			_plan = _make_plan()
			_preview.rpc(_mix(), _plan["shape"])
		GameState.Phase.WARNING:
			if _plan.is_empty():
				_plan = _make_plan()
			_weather_bosses()
			var extra := Weather.extra_bugs(GameState.weather)
			if extra > 0.0:
				# Blood moon: fold part of a second wave's worth of bugs into this one
				# (never a second boss).
				var more: Array = (_make_plan()["groups"] as Array).filter(func(g: Dictionary) -> bool:
					return Defs.bug(StringName(g["bug"])).behavior != BugDef.Behavior.BOSS)
				var groups: Array = _plan["groups"]
				for i in int(more.size() * extra):
					var g: Dictionary = more[i]
					g["pulse"] = int(g["pulse"]) % int(_plan["pulses"])
					groups.append(g)
			# Maps: on bigger maps the share sent is the heaviest cliff's own.
			var shares: Array = _plan.get("shares", [])
			if shares.size() > 2:
				var hc := WavePlanner.heaviest(shares)
				_announce.rpc(hc, float(shares[maxi(hc, 0)]), _lane_counts())
			else:
				_announce.rpc(WavePlanner.heavier_cliff(float(_plan["west_share"])), float(_plan["west_share"]), _lane_counts())
		GameState.Phase.WAVE:
			if _plan.is_empty():
				_plan = _make_plan()
			_pulse = 0
			_clock = 0.0
			_active = true
			for id: StringName in _plan_bosses():
				boss_seen.append(id)
		_:
			_active = false


func _make_plan() -> Dictionary:
	_planner.variants = tally.unlocked
	_planner.boss_seen = boss_seen
	_planner.cliff_count = WorldLayout.cliff_count() # Maps: this run's map
	_planner.weights = _live_weights()
	return _planner.plan(GameState.wave)


## The bosses in the current plan (ids, in group order).
func _plan_bosses() -> Array[StringName]:
	var out: Array[StringName] = []
	if _plan.is_empty():
		return out
	for g: Dictionary in _plan["groups"]:
		if Defs.bug(StringName(g["bug"])).behavior == BugDef.Behavior.BOSS:
			out.append(StringName(g["bug"]))
	return out


## Host, read by GameState's weather roll: is the Mirage Mantis due this wave?
func mantis_due() -> bool:
	return multiplayer.is_server() and _plan_bosses().has(BossRotation.MANTIS)


## Host, once the weather is known: the Mantis only hunts in dust storms (a
## stand-in takes her place otherwise), and a dust-storm boss wave brings her.
func _weather_bosses() -> void:
	var bosses := _plan_bosses()
	if bosses.is_empty():
		return
	var swapped := BossRotation.apply_weather(_planner._seed, GameState.wave, _planner.bug_defs, boss_seen, bosses,
			GameState.weather == Weather.Kind.DUST_STORM)
	if swapped == bosses:
		return
	var k := 0
	for g: Dictionary in _plan["groups"]:
		if Defs.bug(StringName(g["bug"])).behavior == BugDef.Behavior.BOSS and k < swapped.size():
			g["bug"] = swapped[k]
			k += 1
	_preview.rpc(_mix(), _plan["shape"])


func _process(delta: float) -> void:
	if not _active or not multiplayer.is_server() or bug_manager == null:
		return
	var times: Array = _plan["pulse_times"]
	_clock += delta
	while _pulse < times.size() and _clock >= float(times[_pulse]):
		_release(_pulse)
		_pulse += 1
	if _pulse >= times.size() and bug_manager.alive_count() == 0 and bug_manager.pending_count() == 0:
		_active = false
		_plan = {}
		GameState.end_wave()


func _release(pulse: int) -> void:
	if GameState.has_flag("--netlog"):
		print("[wave] %s: releasing pulse %d of %d, %d groups planned" % [_plan["shape"], pulse, int(_plan["pulses"]), (_plan["groups"] as Array).size()])
	for g: Dictionary in _plan["groups"]:
		if int(g["pulse"]) == pulse:
			if GameState.has_flag("--netlog") and String(g["bug"]).contains("@"):
				print("[wave]   variant group: %d x %s" % [int(g["count"]), Defs.bug(StringName(g["bug"])).display_name])
			bug_manager.spawn_group(StringName(g["bug"]), int(g["count"]), int(g["cliff"]), int(g["lane"]))


## Host: BugManager reports every kill; enough kills of one type the same way
## unlocks its variant for the coming waves.
func note_kill(def: BugDef, source: String) -> void:
	var v := tally.note(def, KillMethod.of(source))
	if v != &"":
		if GameState.has_flag("--netlog"):
			print("[wave] variant unlocked: %s (%d kills by %s)" % [v, tally.count(def.base_id(), KillMethod.of(source)), KillMethod.of(source)])
		_variant_unlocked.rpc(v)


## Maps: the map's spawn weights, minus any cliff nobody holds (a lobby that
## started short without CPU teammates). Solo play holds every cliff.
func _live_weights() -> Array[float]:
	var w := WorldLayout.map().spawn_weights()
	if GameState.is_solo() or not NetworkManager.is_online():
		return w
	var total := 0.0
	for cid in w.size():
		if not NetworkManager.cliff_held(cid):
			w[cid] = 0.0
		total += w[cid]
	if total <= 0.0:
		return WorldLayout.map().spawn_weights()
	for cid in w.size():
		w[cid] /= total
	return w


## Bugs per [cliff][lane], so the warning HUD can show the busiest lanes.
func _lane_counts() -> Array:
	var counts := []
	for cid in WorldLayout.cliff_count(): # Maps: one row per cliff
		counts.append([0, 0, 0, 0, 0])
	for g: Dictionary in _plan["groups"]:
		var row: Array = counts[int(g["cliff"])]
		row[int(g["lane"])] = int(row[int(g["lane"])]) + int(g["count"])
	return counts


## Bugs per type in the plan: kill-method variants first (so the HUD never hides
## them under "+N more"), then most numerous first.
func _mix() -> Array:
	return mix_of(_plan["groups"])


static func mix_of(groups: Array) -> Array:
	var by: Dictionary = {}
	for g: Dictionary in groups:
		by[String(g["bug"])] = int(by.get(String(g["bug"]), 0)) + int(g["count"])
	var out: Array = []
	for id: String in by:
		out.append([id, by[id]])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var va := String(a[0]).contains("@")
		var vb := String(b[0]).contains("@")
		if va != vb:
			return va
		return int(a[1]) > int(b[1]))
	return out


## Host: re-sends the preview to a player who just joined.
func send_preview_to(peer: int) -> void:
	if multiplayer.is_server() and not preview.is_empty():
		_preview.rpc_id(peer, preview, preview_shape)


@rpc("authority", "call_local", "reliable")
func _preview(mix: Array, shape: StringName) -> void:
	preview = mix
	preview_shape = shape
	wave_previewed.emit(mix)


@rpc("authority", "call_local", "reliable")
func _announce(heavy_cliff: int, west_share: float, lane_counts: Array) -> void:
	wave_announced.emit(heavy_cliff, west_share, lane_counts)


@rpc("authority", "call_local", "reliable")
func _variant_unlocked(variant_id: StringName) -> void:
	variant_unlocked.emit(variant_id)
	var d := Defs.bug(variant_id)
	if d == null or bug_manager == null:
		return
	var base := Defs.bug(d.variant_of)
	var method := String(variant_id).get_slice("@", 1)
	# One line in the kill feed (every peer adds its own copy).
	bug_manager.bug_killed.emit("The %ss are adapting to %s: %ss are coming. %s" % [
			base.display_name, KillMethod.WORDS.get(StringName(method), method), d.display_name, d.counter], -1, "", -2, {})
