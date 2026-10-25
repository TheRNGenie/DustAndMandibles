extends Node
## Host only: plans each wave from the threat budget when the warning bell rings,
## releases it in 3-5 pulses during the wave, and ends the wave when every bug is dead.

signal wave_announced(heavy_cliff: int, west_share: float, lane_counts: Array)

var bug_manager: BugManager
var _planner: WavePlanner
var _plan: Dictionary = {}
var _pulse := 0
var _pulse_timer := 0.0
var _active := false


func _ready() -> void:
	var defs: Array[BugDef] = []
	for d: BugDef in Defs.BUGS.values():
		defs.append(d)
	_planner = WavePlanner.new(Defs.WAVE_CONFIG, defs, int(Time.get_unix_time_from_system()))
	GameState.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(p: GameState.Phase) -> void:
	if not multiplayer.is_server():
		return
	match p:
		GameState.Phase.WARNING:
			_plan = _planner.plan(GameState.wave)
			_announce.rpc(WavePlanner.heavier_cliff(float(_plan["west_share"])), float(_plan["west_share"]), _lane_counts())
		GameState.Phase.WAVE:
			if _plan.is_empty():
				_plan = _planner.plan(GameState.wave)
			_pulse = 0
			_pulse_timer = 0.0
			_active = true
		_:
			_active = false


func _process(delta: float) -> void:
	if not _active or not multiplayer.is_server() or bug_manager == null:
		return
	var pulses := int(_plan["pulses"])
	if _pulse < pulses:
		_pulse_timer -= delta
		if _pulse_timer <= 0.0:
			_release(_pulse)
			_pulse += 1
			_pulse_timer = Defs.WAVE_CONFIG.pulse_interval
	elif bug_manager.alive_count() == 0:
		_active = false
		_plan = {}
		GameState.end_wave()


func _release(pulse: int) -> void:
	for g: Dictionary in _plan["groups"]:
		if int(g["pulse"]) == pulse:
			bug_manager.spawn_group(StringName(g["bug"]), int(g["count"]), int(g["cliff"]), int(g["lane"]))


## Bugs per [cliff][lane], so the warning HUD can show the busiest lanes.
func _lane_counts() -> Array:
	var counts := [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]
	for g: Dictionary in _plan["groups"]:
		var row: Array = counts[int(g["cliff"])]
		row[int(g["lane"])] = int(row[int(g["lane"])]) + int(g["count"])
	return counts


@rpc("authority", "call_local", "reliable")
func _announce(heavy_cliff: int, west_share: float, lane_counts: Array) -> void:
	wave_announced.emit(heavy_cliff, west_share, lane_counts)
