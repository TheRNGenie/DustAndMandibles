class_name Ambience
extends Node3D
## The canyon's sound bed, all from real CC0 recordings (audio/CREDITS.txt), all on
## the Ambience bus (which feeds SFX, so the SFX slider covers it):
##   - the swarm: per cliff wall, two emitters (one per half of the wall) that sit
##     where that half's climbers are, a far chorus that swells with how many climb
##     and a close clicking skitter that comes in as they near the top;
##   - wind: a soft bed, stronger at the plateau edge, up high and in windy weather
##     or dust storms, with gusts blowing in from upwind;
##   - the airship: now and then a timber creak somewhere along its hull.
## Counted from BugManager.climbers_on() a few times a second; per frame only a
## dozen players ease their volume and position.

const UPDATE := 0.25
const BED := "res://audio/sfx/amb_chitter_bed.ogg"
const NEAR := "res://audio/sfx/amb_chitter_near.ogg"
const WIND := "res://audio/sfx/amb_wind.ogg"
const GUST := "res://audio/sfx/amb_wind_gust.ogg"
const SILENT_DB := AmbienceMix.SILENT_DB
const WIND_DB := AmbienceMix.WIND_DB
const GUST_DB := -19.0

var bugs: BugManager
var airship: Node3D

var _emit: Array = [] # per cliff: [left half, right half], each {bed, near, pos, bed_db, near_db, pitch}
var _t := 0.0
var _wind: AudioStreamPlayer
var _gust: AudioStreamPlayer3D
var _wind_db := SILENT_DB
var _gust_amt := 0.0
var _gust_goal := 0.0
var _gust_t := 0.0
var _edge := 0.0
var _creak: AudioStreamPlayer3D
var _creak_t := 6.0
var _creaks: Array[AudioStream] = []
var _rng := RandomNumberGenerator.new()
var _log := false
var _log_t := 0.0


func _ready() -> void:
	_rng.randomize()
	_log = "--audiolog" in OS.get_cmdline_user_args()
	var bed := _loop(BED)
	var near := _loop(NEAR)
	if bed != null and near != null:
		for c in WorldLayout.cliff_count():
			var halves := []
			for h in 2:
				var e := {
					"bed": _player3d(bed, 18.0, 150.0),
					"near": _player3d(near, 10.0, 90.0),
					"pos": Vector3.ZERO, "bed_db": SILENT_DB, "near_db": SILENT_DB, "pitch": 1.0, "placed": false,
				}
				halves.append(e)
			_emit.append(halves)
	var wind := _loop(WIND)
	if wind != null:
		_wind = AudioStreamPlayer.new()
		_wind.bus = &"Ambience"
		_wind.stream = wind
		_wind.volume_db = SILENT_DB
		add_child(_wind)
		_wind.play()
	var gust := _loop(GUST)
	if gust != null:
		_gust = _player3d(gust, 30.0, 200.0)
		_gust.play()
	for k in range(1, 7):
		var path := "res://audio/sfx/airship_creak%s.ogg" % ("" if k == 1 else "__%d" % k)
		if ResourceLoader.exists(path):
			_creaks.append(load(path))
	if not _creaks.is_empty():
		_creak = _player3d(null, 7.0, 130.0)


func _loop(path: String) -> AudioStreamOggVorbis:
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStreamOggVorbis
	if s != null:
		s.loop = true
	return s


func _player3d(stream: AudioStream, unit: float, max_dist: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"Ambience"
	p.stream = stream
	p.unit_size = unit
	p.max_distance = max_dist
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.volume_db = SILENT_DB
	p.max_db = 0.0
	add_child(p)
	return p


## Counted on a physics tick: climbers_on() is shared per tick with the turrets'
## targeting, so this usually reuses their sort instead of walking every bug again.
func _physics_process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = UPDATE
		var t0 := Time.get_ticks_usec()
		_count_swarm()
		_aim_wind()
		if CpuProf.on:
			CpuProf.add(&"p:ambience", Time.get_ticks_usec() - t0)
		_log_t -= UPDATE
		if _log and _log_t <= 0.0:
			_log_t = 2.0
			_print_levels()
	var k := clampf(delta * 2.0, 0.0, 1.0)
	for halves: Array in _emit:
		for e: Dictionary in halves:
			_ease(e["bed"], e["bed_db"], e["pitch"], e["pos"], k)
			_ease(e["near"], e["near_db"], e["pitch"], e["pos"], k)
	if _wind != null:
		_wind.volume_db = lerpf(_wind.volume_db, _wind_db, clampf(delta, 0.0, 1.0))
	if _gust != null:
		_gust_t -= delta
		if _gust_t <= 0.0:
			var w := GameState.weather
			var windy := w == Weather.Kind.WINDY or w == Weather.Kind.DUST_STORM
			_gust_t = _rng.randf_range(2.5, 7.0) if windy else _rng.randf_range(4.0, 10.0)
			_gust_goal = _rng.randf_range(0.4, 1.0) if _rng.randf() < (0.7 if windy else 0.4) else 0.0
		_gust_amt = lerpf(_gust_amt, _gust_goal, clampf(delta * 0.6, 0.0, 1.0))
		_gust.volume_db = maxf(_wind_db - WIND_DB + GUST_DB + linear_to_db(maxf(_gust_amt, 0.001)), SILENT_DB)
	if _creak != null and airship != null and airship.is_inside_tree():
		_creak_t -= delta
		if _creak_t <= 0.0:
			_creak_t = _rng.randf_range(5.0, 13.0) * (0.6 if _gust_amt > 0.5 else 1.0)
			_creak.global_position = airship.global_position + Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-2, 3), _rng.randf_range(-12, 12))
			_creak.stream = _creaks[_rng.randi() % _creaks.size()]
			_creak.volume_db = _rng.randf_range(-12.0, -6.0)
			_creak.pitch_scale = _rng.randf_range(0.85, 1.05)
			_creak.play()
			if _log:
				print("[ambience] airship creak at %s %.0f dB" % [str(_creak.global_position.snapped(Vector3.ONE)), _creak.volume_db])


func _print_levels() -> void:
	var parts: PackedStringArray = []
	for c in _emit.size():
		for h in 2:
			var e: Dictionary = _emit[c][h]
			var bed := e["bed"] as AudioStreamPlayer3D
			var near := e["near"] as AudioStreamPlayer3D
			parts.append("c%d%s bed %.0f near %.0f%s" % [c, "LR"[h], bed.volume_db, near.volume_db, "" if bed.playing else " (off)"])
	print("[ambience] %s | wind %.0f dB edge %.2f gust %.2f" % [", ".join(parts), _wind_db, _edge, _gust_amt])


func _ease(p: AudioStreamPlayer3D, db: float, pitch: float, pos: Vector3, k: float) -> void:
	if db <= SILENT_DB + 1.0 and p.volume_db <= SILENT_DB + 3.0:
		if p.playing:
			p.stop()
		p.volume_db = SILENT_DB
		return
	if not p.playing:
		p.global_position = pos
		p.play(_rng.randf() * maxf(p.stream.get_length() - 0.1, 0.0))
	p.volume_db = lerpf(p.volume_db, db, k)
	p.pitch_scale = lerpf(p.pitch_scale, pitch, k)
	p.global_position = p.global_position.lerp(pos, k)


## Each wall half's climbers: how many, how high, and where they are.
func _count_swarm() -> void:
	if bugs == null or not is_instance_valid(bugs):
		return
	var top := WorldLayout.CLIFF_HEIGHT
	for c in _emit.size():
		var list := bugs.climbers_on(c)
		var load_h := [0.0, 0.0]
		var high := [0.0, 0.0]
		var n := [0, 0]
		var ys := [0.0, 0.0]
		var zs := [0.0, 0.0]
		for b in list:
			if not is_instance_valid(b) or not b.is_alive():
				continue
			var h := 0 if b.lane_z < 0.0 else 1
			var y := clampf(b.climb_y / top, 0.0, 1.0)
			n[h] += 1
			load_h[h] += 0.3 + 0.7 * y
			high[h] += y * y
			ys[h] += b.climb_y
			zs[h] += b.lane_z
		for h in 2:
			var e: Dictionary = _emit[c][h]
			if n[h] == 0:
				e["bed_db"] = SILENT_DB
				e["near_db"] = SILENT_DB
				continue
			# Where this half's climbers are on average (one face lookup, not one per bug).
			var mean: Vector3 = e["pos"]
			if Bug.cliffs != null:
				mean = Bug.cliffs.face_point(c, ys[h] / float(n[h]), zs[h] / float(n[h]))
			if not e["placed"] or (e["bed"] as AudioStreamPlayer3D).volume_db <= SILENT_DB + 3.0:
				(e["bed"] as AudioStreamPlayer3D).global_position = mean
				(e["near"] as AudioStreamPlayer3D).global_position = mean
				e["placed"] = true
			e["pos"] = mean
			var s := AmbienceMix.swarm_levels(n[h], load_h[h], high[h] / float(n[h]))
			e["bed_db"] = s.x
			e["near_db"] = s.y
			e["pitch"] = s.z


## Wind: stronger near a plateau's lip, up high, and in rough weather.
func _aim_wind() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var lip := INF
	for c in WorldLayout.cliff_count():
		var at := WorldLayout.plateau_to_world(c, 0.0, p.z, p.y)
		lip = minf(lip, Vector2(at.x - p.x, at.z - p.z).length())
	_edge = clampf(1.0 - (lip - 3.0) / 18.0, 0.0, 1.0)
	var height := clampf((p.y - WorldLayout.CLIFF_HEIGHT - 8.0) / 60.0, 0.0, 1.0)
	_wind_db = AmbienceMix.wind_db(GameState.weather, _edge, height)
	if _gust != null:
		_gust.global_position = p + Vector3(0, 4, -WeatherFx.wind_sign() * 22.0)
