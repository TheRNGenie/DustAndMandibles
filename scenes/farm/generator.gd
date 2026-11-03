class_name Generator
extends StaticBody3D
## A homestead's generator (Waterworks): a little engine on a skid with a big
## circuit-breaker lever. Throwing your lever (E here) is how you ready up; once
## every human's is thrown the engines crank up during the countdown, the pump
## jack at the well (MechWell, belted to this engine) runs and the wave comes. The levers drop back and the
## engines sputter out when the wave is over. Sound: a recorded engine (CC0, see
## audio/CREDITS.txt): a coughing start, a chugging loop, a sputter off.

static var _by_cliff: Dictionary = {}

const RUN_SOUND := "res://audio/sfx/generator_run.wav"
## Lever angle round its pivot: up (off) and thrown down (on).
const LEVER_OFF := -0.45
const LEVER_ON := 2.35

var cliff_id := 0
var style: StringName = &"timber"

var _body: Node3D
var _flywheel: Node3D
var _lever: Node3D
var _lamp_mat: StandardMaterial3D
var _puffs: Array[MeshInstance3D] = []
var _puff_t: Array[float] = []
var _run_player: AudioStreamPlayer3D
var _shot_player: AudioStreamPlayer3D
var _running := false
var _first := true
var _spin := 0.0
var _clock := 0.0


static func of(cid: int) -> Generator:
	var g: Variant = _by_cliff.get(cid)
	return g as Generator if g != null and is_instance_valid(g) else null


func _ready() -> void:
	add_to_group("generators")
	_by_cliff[cliff_id] = self
	collision_layer = WorldLayout.LAYER_WORLD
	_build()
	_lever.rotation.x = LEVER_OFF


func _exit_tree() -> void:
	if _by_cliff.get(cliff_id) == self:
		_by_cliff.erase(cliff_id)


func _build() -> void:
	var mat := Materials.toon()
	_body = Node3D.new()
	_body.name = "Engine"
	add_child(_body)
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = WaterworksBuilder.generator_body(700 + cliff_id)
	body_mi.material_override = mat
	_body.add_child(body_mi)
	_flywheel = MeshInstance3D.new()
	(_flywheel as MeshInstance3D).mesh = WaterworksBuilder.flywheel()
	(_flywheel as MeshInstance3D).material_override = mat
	_flywheel.position = Vector3(0.56, 0.55, 0.25)
	_body.add_child(_flywheel)
	# The breaker on its post, at the generator's front-left, facing the yard.
	var box := MeshInstance3D.new()
	box.mesh = WaterworksBuilder.breaker_box(710 + cliff_id)
	box.material_override = mat
	box.position = Vector3(-0.95, 0, 0.75)
	add_child(box)
	_lever = Node3D.new()
	_lever.name = "Lever"
	_lever.position = box.position + Vector3(0.2, 1.3, 0.24)
	add_child(_lever)
	var handle := MeshInstance3D.new()
	handle.mesh = WaterworksBuilder.lever_handle()
	handle.material_override = mat
	handle.scale = Vector3.ONE * 1.25
	_lever.add_child(handle)
	# A lamp on the breaker box: red off, amber thrown, green running.
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	lamp.mesh = sphere
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.material_override = _lamp_mat
	lamp.position = box.position + Vector3(-0.15, 1.82, 0.08)
	add_child(lamp)
	# Exhaust puffs (a few spheres recycled up the stack).
	var puff_mat := StandardMaterial3D.new()
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mat.albedo_color = Color(0.25, 0.22, 0.2, 0.5)
	for i in 4:
		var p := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.12
		s.height = 0.24
		s.radial_segments = 8
		s.rings = 4
		p.mesh = s
		p.material_override = puff_mat
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visible = false
		add_child(p)
		_puffs.append(p)
		_puff_t.append(float(i) / 4.0)
	# Collision: the engine and the breaker post (both stop players; E aims at either).
	for shape: Array in [[Vector3(1.15, 1.25, 1.95), Vector3(0, 0.62, 0)], [Vector3(0.7, 1.9, 0.4), box.position + Vector3(0, 0.95, 0.05)]]:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = shape[0]
		col.shape = bs
		col.position = shape[1]
		add_child(col)
	# Sound: 3D, loud up close, gone across the yard.
	_run_player = _player(-7.0)
	_shot_player = _player(-3.0)
	var run := load(RUN_SOUND) as AudioStreamWAV if ResourceLoader.exists(RUN_SOUND) else null
	if run != null:
		run = run.duplicate() as AudioStreamWAV
		run.loop_mode = AudioStreamWAV.LOOP_FORWARD
		run.loop_begin = 0
		run.loop_end = int(run.get_length() * run.mix_rate)
		_run_player.stream = run


func _player(db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"
	p.unit_size = 4.0
	p.max_distance = 55.0
	p.volume_db = db
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	p.position = Vector3(0, 0.9, 0)
	add_child(p)
	return p


func _process(delta: float) -> void:
	_clock += delta
	var thrown := GameState.lever_thrown(cliff_id)
	_lever.rotation.x = move_toward(_lever.rotation.x, LEVER_ON if thrown else LEVER_OFF, delta * 9.0)
	var running := GameState.pumps_on()
	if running != _running:
		_set_running(running)
	_lamp_mat.albedo_color = Color("#5BE05B") if running else (Color("#FFB23C") if thrown else Color("#E0483C"))
	_lamp_mat.emission = _lamp_mat.albedo_color
	_lamp_mat.emission_energy_multiplier = 1.6 if running else 0.8
	# Running: the flywheel spins, the engine shudders, smoke puffs.
	_spin = move_toward(_spin, 14.0 if running else 0.0, delta * (6.0 if running else 4.0))
	_flywheel.rotation.x += _spin * delta
	var shake := 0.012 * (_spin / 14.0)
	_body.position = Vector3(sin(_clock * 61.0) * shake, absf(sin(_clock * 47.0)) * shake, cos(_clock * 53.0) * shake * 0.5)
	for i in _puffs.size():
		var p := _puffs[i]
		if _spin < 1.0:
			p.visible = false
			continue
		_puff_t[i] = fmod(_puff_t[i] + delta * 0.9, 1.0)
		var t := _puff_t[i]
		p.visible = true
		p.position = _body.position + Vector3(-0.35, 2.2 + t * 1.6, -0.45 - t * 0.4)
		p.scale = Vector3.ONE * lerpf(0.6, 2.4, t)
		p.transparency = t


func _set_running(on: bool) -> void:
	_running = on
	if _first:
		# Joining or loading mid-run: no cough, just the engine as it is.
		_first = false
		if on and _run_player.stream != null:
			_run_player.play()
		return
	if on:
		_play_shot(&"generator_start")
		if _run_player.stream != null:
			get_tree().create_timer(2.2, false).timeout.connect(func() -> void:
				if _running and is_inside_tree():
					_run_player.play())
	else:
		_run_player.stop()
		_play_shot(&"generator_stop")


func _play_shot(sound: StringName) -> void:
	var path := "res://audio/sfx/%s.wav" % sound
	if not ResourceLoader.exists(path):
		return
	_shot_player.stream = load(path)
	_shot_player.play()


# ------------------------------------------------------------------ the lever

## Is this the local player's own generator? (Solo, with nobody else on the map,
## every unclaimed cliff's generator is yours too.)
func is_mine() -> bool:
	var me := _local_cliff()
	if me == cliff_id:
		return true
	if NetworkManager.is_online() and NetworkManager.cliff_held(cliff_id):
		return false
	return GameState.is_solo() or (not NetworkManager.is_online())


func interact_prompt() -> String:
	var thrown := GameState.lever_thrown(cliff_id)
	var title := "Generator"
	if GameState.phase != GameState.Phase.BUILD:
		return "%s  -  running, the pumps are on" % title if GameState.pumps_on() else title
	if not is_mine():
		var who := Hud.owner_name(cliff_id)
		return "%s's generator  -  lever %s" % [who, "thrown" if thrown else "up"]
	if GameState.ready_countdown >= 0.0:
		return "%s  -  cranking up, the wave's coming\nE: pull your lever back (not yet)" % title
	if thrown:
		return "%s  -  your lever's thrown, waiting on the others\nE: pull your lever back" % title
	return "%s  -  throw your lever when you're ready for the wave\nE: throw your lever" % title


func local_interact(holding: bool) -> void:
	if holding or GameState.phase != GameState.Phase.BUILD or not is_mine():
		return
	GameState.toggle_ready()
	Audio.play_at(&"slot_lever", _lever.global_position, -2.0, 0.7)


func _local_cliff() -> int:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority() and n is Player:
			return (n as Player).cliff_id
	return 0
