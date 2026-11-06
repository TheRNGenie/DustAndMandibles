extends Node
## The sound of the swarm: one low chittering rumble for all the bugs at once,
## louder the more are alive (never one sound per bug). Two looping layers of
## the skitter recording: a slowed-down rumble and a busier chitter on top,
## with loops of different lengths so the repeat is hard to hear. The bugs
## marching on the canyon floor (BugManager.floor_count, walkers included) swell
## the rumble, and past 200 of them a busy chittering wash comes in on top.

const COUNT_FOR_FULL := 300.0
const QUIET_DB := -60.0

var _layers: Array[AudioStreamPlayer] = []
var _level := 0.0
var _poll := 0.0
var _count := 0
var _march := Vector2.ZERO
var _march_now := Vector2.ZERO


func _ready() -> void:
	var src := load("res://audio/sfx/skitter.wav") as AudioStreamWAV
	if src == null:
		return
	var bus := &"Bugs" if AudioServer.get_bus_index("Bugs") >= 0 else &"Master"
	# [pitch, loudest dB]: deep rumble underneath, chitter on top.
	for layer: Array in [[0.48, -7.0], [0.82, -13.0], [1.18, -12.0]]:
		var s := src.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_PINGPONG
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate) - 1
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.bus = bus
		p.pitch_scale = float(layer[0])
		p.volume_db = QUIET_DB
		p.set_meta("max_db", float(layer[1]))
		add_child(p)
		_layers.append(p)


func _process(delta: float) -> void:
	if _layers.is_empty():
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.4
		_count = get_tree().get_nodes_in_group("bugs").size()
		var floor_bugs := BugManager.instance.floor_count() if is_instance_valid(BugManager.instance) else 0
		_count += BugManager.instance.swarm.count() if is_instance_valid(BugManager.instance) and BugManager.instance.swarm != null else 0
		_march = AmbienceMix.march_levels(floor_bugs)
	# Eases toward the target so the rumble swells as a wave pours out.
	var want := clampf(log(1.0 + float(_count)) / log(1.0 + COUNT_FOR_FULL), 0.0, 1.0)
	_level = move_toward(_level, want, delta * (0.5 if want > _level else 0.25))
	_march_now = _march_now.move_toward(_march, delta * 0.3)
	for i in _layers.size():
		var p := _layers[i]
		var lvl := _level if i < 2 else _march_now.y
		if lvl < 0.02:
			if p.playing:
				p.stop()
			continue
		if not p.playing:
			p.play(randf() * 0.5)
		var max_db := float(p.get_meta("max_db"))
		if i == 0: # the low rumble swells and deepens with the march
			max_db += 4.0 * _march_now.x
		p.volume_db = lerpf(-34.0, max_db, lvl)
		# A slow wobble so the loop never sits still.
		var pitch: float = [0.48 - 0.05 * _march_now.x, 0.82, 1.18][i]
		p.pitch_scale = pitch * (1.0 + sin(Time.get_ticks_msec() * 0.0007 * (i + 1)) * 0.04)
