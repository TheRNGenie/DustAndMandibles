class_name Campfire
extends StaticBody3D
## A campfire in front of each house with two log benches. During the build
## phase, E sits you down on the nearest free log: the view drops to a seated
## height, a harmonica loop plays if one is in audio/ (else just the crackle),
## and you heal a little over time. Move, jump or press E again to stand up.
## The fire always crackles and flickers (the crackle is synthesized live).

const HEAL_PER_SEC := 4.0
const BENCH_OUT := 1.75
const STAND_STEP := 1.0
## Optional CC0 harmonica loop: the first of these that exists is used.
const HARMONICA_PATHS := ["res://audio/music/harmonica_loop.ogg", "res://audio/music/harmonica_loop.wav",
	"res://audio/sfx/harmonica_loop.ogg", "res://audio/sfx/harmonica_loop.wav"]
const CRACKLE_RATE := 22050.0
const CRACKLE_RANGE := 22.0

var cliff_id := 0
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _t := randf() * 10.0
var _sitter: Player
var _seat := -1
var _crackle: AudioStreamPlayer3D
var _crackle_pb: AudioStreamGeneratorPlayback
var _harmonica: AudioStreamPlayer3D
var _pop_left := 0
var _pop_amp := 0.0
var _brown := 0.0
var _rng := RandomNumberGenerator.new()
var _headless := DisplayServer.get_name() == "headless"


static func spot(cliffs: CliffBuilder, cid: int) -> Vector3:
	return cliffs.plateau_point(cid, Buildable.CAMPFIRE.x, Buildable.CAMPFIRE.y)


func _ready() -> void:
	_rng.randomize()
	collision_layer = WorldLayout.LAYER_WORLD
	collision_mask = 0
	add_to_group("campfires")
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh()
	mi.material_override = Materials.toon(0.02)
	add_child(mi)
	for i in 3:
		var f := MeshInstance3D.new()
		f.mesh = _flame_mesh(i)
		f.material_override = Materials.toon(0.0)
		f.position = Vector3(cos(i * 2.1) * 0.12, 0.22, sin(i * 2.1) * 0.12)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		_flames.append(f)
	_light = OmniLight3D.new()
	_light.light_color = Color("#FF9A3C")
	_light.light_energy = 1.8
	_light.omni_range = 8.0
	_light.position = Vector3(0, 0.9, 0)
	_light.shadow_enabled = false
	add_child(_light)
	var embers := CPUParticles3D.new()
	embers.amount = 14
	embers.lifetime = 1.6
	embers.position = Vector3(0, 0.5, 0)
	embers.direction = Vector3.UP
	embers.spread = 18.0
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.4
	embers.gravity = Vector3(0, 0.2, 0)
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.0
	var em := SphereMesh.new()
	em.radius = 0.018
	em.height = 0.036
	em.radial_segments = 4
	em.rings = 2
	var em_mat := StandardMaterial3D.new()
	em_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em_mat.albedo_color = Color("#FFB347")
	em.material = em_mat
	embers.mesh = em
	add_child(embers)
	# Collision: the stone ring and the two benches.
	_box(Vector3(1.2, 0.35, 1.2), Vector3(0, 0.17, 0))
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.45, 1.9), Vector3(s * BENCH_OUT, 0.22, 0))
	_crackle = AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = CRACKLE_RATE
	gen.buffer_length = 0.25
	_crackle.stream = gen
	_crackle.unit_size = 3.0
	_crackle.max_distance = CRACKLE_RANGE
	_crackle.volume_db = -6.0
	_crackle.position = Vector3(0, 0.3, 0)
	_crackle.bus = &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"
	add_child(_crackle)
	for path: String in HARMONICA_PATHS:
		if ResourceLoader.exists(path):
			_harmonica = AudioStreamPlayer3D.new()
			var stream := load(path) as AudioStream
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			elif stream is AudioStreamWAV:
				var wav := stream as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_end = int(wav.get_length() * wav.mix_rate)
			_harmonica.stream = stream
			_harmonica.unit_size = 4.0
			_harmonica.max_distance = 30.0
			_harmonica.volume_db = -8.0
			_harmonica.position = Vector3(0, 1.0, 0)
			_harmonica.bus = _crackle.bus
			add_child(_harmonica)
			break
	if GameState.flag_value("--campfire") == "sit" and cliff_id == WorldLayout.WEST:
		# Debug (screenshots): sit the local player down here after a moment.
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			var me := _local_player()
			if me != null:
				me.global_position = global_position + Vector3(0, 0.3, 0) + global_basis.x * 2.6
				_sit(me))


func _exit_tree() -> void:
	# Stop feeding the generator before it goes away (quitting mid-crackle).
	if _crackle != null:
		_crackle.stop()
	_crackle_pb = null
	if _sitter != null and is_instance_valid(_sitter):
		_sitter.seated = false
	_sitter = null


func _box(size: Vector3, at: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = at
	add_child(col)


# ------------------------------------------------------------------ interaction

func interact_prompt() -> String:
	if _sitter != null:
		return "Resting by the fire\nE: stand up"
	if GameState.phase != GameState.Phase.BUILD:
		return "Campfire\nRest here between waves"
	return "Campfire\nE: sit and rest a spell"


func local_interact(holding: bool) -> void:
	if holding:
		return
	var me := _local_player()
	if me == null:
		return
	if _sitter == me:
		_stand()
	elif _sitter == null and GameState.phase == GameState.Phase.BUILD and not me.is_downed():
		_sit(me)


func _local_player() -> Player:
	var world := get_tree().current_scene
	if world != null and world.has_method("local_player"):
		return world.call("local_player") as Player
	return null


## Local seat transform for bench i (0 = left, 1 = right), facing the fire.
func _seat_global(i: int) -> Transform3D:
	var s := -1.0 if i == 0 else 1.0
	var local := Vector3(s * (BENCH_OUT + 0.05), 0.02, 0)
	var at := global_transform * local
	var to_fire := (global_position - at)
	to_fire.y = 0.0
	return Transform3D(Basis.looking_at(to_fire.normalized(), Vector3.UP), at)


func _sit(p: Player) -> void:
	# The nearer of the two logs.
	var a := _seat_global(0).origin.distance_to(p.global_position)
	var b := _seat_global(1).origin.distance_to(p.global_position)
	_seat = 0 if a <= b else 1
	_sitter = p
	p.seated = true
	var xf := _seat_global(_seat)
	p.global_position = xf.origin
	p.rotation.y = xf.basis.get_euler().y
	p.head.rotation.x = -0.15
	if _harmonica != null:
		_harmonica.play()
	Audio.play_at(&"rustle", xf.origin + Vector3.UP, -8.0)


func _stand() -> void:
	if _sitter != null and is_instance_valid(_sitter):
		_sitter.seated = false
		var away := _sitter.global_position - global_position
		away.y = 0.0
		_sitter.global_position += away.normalized() * STAND_STEP * 0.4 + Vector3.UP * 0.1
	_sitter = null
	_seat = -1
	if _harmonica != null:
		_harmonica.stop()


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	_t += delta
	var flick := 0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0) + _rng.randf_range(-0.05, 0.05)
	_light.light_energy = 1.8 * flick
	for i in _flames.size():
		var f := _flames[i]
		var k := 1.0 + 0.22 * sin(_t * (9.0 + i * 2.3) + i) + 0.1 * sin(_t * 23.0 + i * 4.0)
		f.scale = Vector3(1.0 / sqrt(k), k, 1.0 / sqrt(k))
		f.rotation.y = _t * (0.6 + i * 0.3)
	if _sitter != null:
		_update_sitter(delta)
	_feed_crackle()


func _update_sitter(delta: float) -> void:
	if not is_instance_valid(_sitter):
		_sitter = null
		return
	var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3
	if moving or Input.is_action_just_pressed("jump") or GameState.phase != GameState.Phase.BUILD or _sitter.is_downed():
		_stand()
		return
	_sitter.global_position = _seat_global(_seat).origin
	var v := _sitter.vitals
	if v != null and v.hp < PlayerVitals.MAX_HP:
		v.hp = minf(v.hp + HEAL_PER_SEC * delta, PlayerVitals.MAX_HP)
		v.health_changed.emit(v.hp, PlayerVitals.MAX_HP)


## Fills the crackle stream: a faint low rumble with random pops and snaps.
## Only while someone's listening nearby.
func _feed_crackle() -> void:
	if _headless:
		return
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(global_position) < CRACKLE_RANGE
	if not near:
		if _crackle.playing:
			_crackle.stop()
			_crackle_pb = null
		return
	if not _crackle.playing:
		_crackle.play()
		_crackle_pb = _crackle.get_stream_playback() as AudioStreamGeneratorPlayback
	if _crackle_pb == null:
		return
	var n := _crackle_pb.get_frames_available()
	for i in n:
		_brown = clampf(_brown * 0.995 + _rng.randf_range(-1.0, 1.0) * 0.02, -0.3, 0.3)
		var s := _brown * 0.25
		if _pop_left <= 0 and _rng.randf() < 0.0009:
			_pop_left = _rng.randi_range(40, 260)
			_pop_amp = _rng.randf_range(0.15, 0.7) if _rng.randf() < 0.85 else 0.95
		if _pop_left > 0:
			_pop_left -= 1
			s += _rng.randf_range(-1.0, 1.0) * _pop_amp
			_pop_amp *= 0.975
		_crackle_pb.push_frame(Vector2(s, s))


# ------------------------------------------------------------------ meshes

static func _mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Stone ring.
	for i in 11:
		var a := TAU * i / 11.0
		var r := 0.58
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, 0.09, sin(a) * r)),
				Vector3(0.16, 0.12, 0.13) * rng.randf_range(0.85, 1.2), 3, 6, Palette.ROCK_C.darkened(rng.randf_range(0.0, 0.3)))
	# Ash bed and charred logs in a tepee.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.02, 0)), 0.5, 0.45, 0.04, 10, Color("#3A3330"))
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var foot := Vector3(cos(a) * 0.42, 0.05, sin(a) * 0.42)
		MeshKit.add_limb(st, foot, Vector3(0, 0.62, 0), 0.06, Palette.WOOD_DARK.darkened(0.35), 6)
	# Two log benches, one either side.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * BENCH_OUT, 0.24, 0)), 0.24, 0.24, 1.8, 9, Palette.WOOD)
		for e: float in [-0.9, 0.9]:
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * BENCH_OUT, 0.24, e)), 0.2, 0.2, 0.02, 9, Palette.WOOD.lightened(0.25))
	# A coffee pot warming on a stone, and a tin cup.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.55, 0.3, 0.35)), 0.09, 0.07, 0.2, 8, Color("#5C6A73"))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.55, 0.43, 0.35)), 0.04, 0.02, 0.06, 8, Color("#5C6A73"))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(s_cup(), 0.5, 0.6)), 0.05, 0.05, 0.08, 8, Color("#8C949C"))
	return MeshKit.finish(st)


static func s_cup() -> float:
	return -BENCH_OUT


static func _flame_mesh(i: int) -> ArrayMesh:
	var st := MeshKit.begin()
	var h := 0.75 - i * 0.12
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, h * 0.5, 0)), 0.2 - i * 0.03, 0.0, h, 7, Color("#FF7A1A"), false, 1.0)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, h * 0.4, 0)), 0.11 - i * 0.02, 0.0, h * 0.75, 7, Color("#FFD34A"), false, 1.0)
	return MeshKit.finish(st)
