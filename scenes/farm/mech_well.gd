class_name MechWell
extends WaterSource
## The homestead's well (Waterworks): a walking-beam pump jack belted to the
## yard's generator (WellJackBuilder builds it, one design per cliff). It works
## from the start. While the generator runs (GameState.pumps_on) the bull wheel
## turns, the beam rocks, the horsehead heaves the rod and water gushes from the
## spout into the trough on every up-stroke; when the levers drop it coasts to a
## stop. Its trough is a WaterSource: E fills your bucket from it any time. It
## only fills while pumping (PUMP_RATE); once the trough is full the same pump
## fills the water tower instead (WaterTower).

## Seconds per unit of water in the trough: standing, and while the generator pumps.
const IDLE_RATE := 8.0
const PUMP_RATE := 2.5
## Crank speed while running (rad/s, about one stroke every two seconds).
const RUN_SPEED := 3.1

## Screenshots only (--mapcam=well:N:run): pump as if the generator ran.
static var force_run := false
## Story (Dry Season): every pump valve has cracked; no well pumps until a new
## valve is fitted (StoryDirector sets it on every peer).
static var valve_broken := false

var style: StringName = &"timber"
## Jack-local spots set by the dressing: the drive pulley at the generator, the
## end of the engine's crankshaft the tumbling rod reaches, and the ground there.
var drive_at := Vector3(0.7, 0.75, 2.6)
var engine_at := Vector3(1.4, 0.55, 3.3)
var drive_ground := 0.0

var _beam: Node3D
var _crank: Node3D
var _pitman: Node3D
var _rod: Node3D
var _drive: Node3D
var _tumbler: Node3D
var _stream: MeshInstance3D
var _water: MeshInstance3D
var _water_info: Dictionary = {}
var _pivot := Vector3.ZERO
var _phi := 0.0
var _speed := 0.0


const AI_BASE := "res://assets/yard/jack_base.glb"
const AI_BEAM := "res://assets/yard/jack_beam.glb"
## The AI jack's beam bearing in its own frame, the tilt it was modelled at, and
## the beam's scale (its horsehead face then lands over the polished rod, the
## bridle hanging below it as the builder beam's did), measured from the model.
const AI_PIVOT := Vector3(0.0, 2.12, 0.0)
const AI_BEAM_TILT := -0.255
const AI_BEAM_SCALE := 0.9
const AI_BEAM_LIFT := 0.12


func _ready() -> void:
	Materials.paint_live(self, Materials.RUSTIC, Materials.MAP_YARD) # painted wood, iron, rock (assets/rustic)
	super()
	display_name = "Well"
	rates = Vector2(IDLE_RATE, IDLE_RATE)
	overflows_to_tower = true # a full trough runs over into the water tower
	collision_layer = WorldLayout.LAYER_WORLD
	_build()
	_pose()


func _build() -> void:
	var mat := Materials.toon()
	var info := WellJackBuilder.frame(style, 400 + cliff_id)
	_water_info = info["water"]
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = info["mesh"]
	frame.material_override = mat
	add_child(frame)
	for s: Array in info["shapes"]:
		var col := CollisionShape3D.new()
		col.shape = s[0]
		col.transform = s[1]
		add_child(col)
	_pivot = Vector3(0, WellJackBuilder.pivot_y(style), 0)
	_beam = _part("Beam", WellJackBuilder.beam(style, 410 + cliff_id), mat)
	_beam.position = _pivot
	_crank = _part("Crank", WellJackBuilder.crank(style), mat)
	_crank.position = WellJackBuilder.CRANK
	_pitman = _part("Pitman", WellJackBuilder.pitman(style), mat)
	_rod = _part("Rod", WellJackBuilder.rod(), mat)
	# The drive at the generator: stand, pulley, belt, tumbling rod to the engine.
	var stand := _part("DriveStand", WellJackBuilder.drive_stand(style, drive_at, drive_ground), mat)
	stand.position = Vector3.ZERO
	_drive = _part("Drive", WellJackBuilder.drive_pulley(), mat)
	_drive.position = drive_at
	var belt := _part("Belt", WellJackBuilder.belt(drive_at), Materials.toon(0.0))
	(belt as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tumbler = _part("Tumbler", WellJackBuilder.tumbler(), mat)
	# The AI-made jack (assets/yard): its stand in place of the builder frame (the
	# trough and casing stay as built), its walking beam riding the animated beam
	# node; crank, pitman, rod and drive stay as built and keep moving.
	if AiModels.exists(AI_BASE) and AiModels.exists(AI_BEAM):
		frame.visible = false
		_part("TroughCasing", WellJackBuilder.trough_casing(style, 400 + cliff_id), mat)
		var s := _pivot.y / AI_PIVOT.y
		var jack_stand := AiModels.instance(AI_BASE, 0.015)
		jack_stand.name = "StandAI"
		jack_stand.transform = Transform3D(Basis.from_scale(Vector3.ONE * s), _pivot - AI_PIVOT * s)
		add_child(jack_stand)
		# The beam, levelled and centred on its bearing, rides the animated beam node.
		var beam_ai := AiModels.instance(AI_BEAM, 0.015)
		beam_ai.name = "BeamAI"
		var level := Transform3D(Basis(Vector3.RIGHT, AI_BEAM_TILT).scaled(Vector3.ONE * AI_BEAM_SCALE), Vector3(0, AI_BEAM_LIFT, 0))
		beam_ai.transform = level * Transform3D(Basis(), -AI_PIVOT)
		_beam.add_child(beam_ai)
		(_beam as MeshInstance3D).mesh = null
	# Water: the stream from the spout, and the level in the trough.
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(WaterworksBuilder.WATER.lightened(0.25), 0.75)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.1
	water_mat.metallic_specular = 0.8
	_stream = MeshInstance3D.new()
	_stream.name = "Stream"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.06
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	_stream.mesh = cyl
	_stream.material_override = water_mat
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stream.visible = false
	add_child(_stream)
	_water = MeshInstance3D.new()
	_water.name = "TroughWater"
	var size: Vector3 = _water_info.get("size", Vector3(1.6, 0, 0.6))
	if bool(_water_info.get("round", false)):
		var disc := CylinderMesh.new()
		disc.top_radius = size.x
		disc.bottom_radius = size.x
		disc.height = 0.02
		disc.radial_segments = 18
		disc.rings = 1
		_water.mesh = disc
	else:
		var box := BoxMesh.new()
		box.size = Vector3(size.x, 0.02, size.z)
		_water.mesh = box
	var surface_mat := water_mat.duplicate() as StandardMaterial3D
	surface_mat.albedo_color = Color(WaterworksBuilder.WATER, 0.85)
	_water.material_override = surface_mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)


func _part(n: String, mesh: Mesh, mat: Material) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	var on := (GameState.pumps_on() or force_run) and not valve_broken
	rates = Vector2(PUMP_RATE, PUMP_RATE)
	if on:
		super(delta) # water only comes while the pump runs (Logan: pump and rain are the only sources)
	_speed = move_toward(_speed, RUN_SPEED if on else 0.0, delta * (1.2 if on else 0.9))
	if _speed > 0.0:
		_phi = fmod(_phi + _speed * delta, TAU)
	_pose()


## Sets every moving part from the crank angle.
func _pose() -> void:
	if _beam == null:
		return
	var c := WellJackBuilder.CRANK
	var pin := c + Vector3(0, cos(_phi), sin(_phi)) * WellJackBuilder.CRANK_R
	var grab := WellJackBuilder.BEAM_GRAB
	var theta := -asin(clampf((pin.y - c.y) / grab.z, -1.0, 1.0))
	_beam.rotation.x = theta
	_crank.rotation.x = _phi
	var attach := _pivot + Basis(Vector3.RIGHT, theta) * grab
	_pitman.transform = _span(pin, attach, 0.0)
	_rod.position = Vector3(0, _pivot.y - 0.75 + WellJackBuilder.ARM * theta, -WellJackBuilder.ARM - 0.05)
	_drive.rotation.x = _phi * WellJackBuilder.BULL_R / WellJackBuilder.DRIVE_R
	_tumbler.transform = _span(drive_at + Vector3(0.44, 0, 0), engine_at, _drive.rotation.x)
	# Water: a gush on the up-stroke (the rod rising), the trough's level.
	var running := _speed > RUN_SPEED * 0.3
	var push := maxf(0.0, sin(_phi)) if running else 0.0
	var spout := WellJackBuilder.SPOUT + Vector3(0, -0.06, -0.02)
	var level := lerpf(WellJackBuilder.WATER_LOW, WellJackBuilder.WATER_HIGH, clampf(float(stored) / float(maxi(capacity, 1)), 0.0, 1.0))
	_stream.visible = running and push > 0.05
	if _stream.visible:
		var fall := maxf(spout.y - level, 0.05)
		var w := lerpf(0.35, 1.0, push)
		_stream.scale = Vector3(w, fall, w)
		_stream.position = Vector3(spout.x, spout.y - fall * 0.5, spout.z)
	_water.visible = stored > 0
	_water.position = Vector3(0, level, WellJackBuilder.TROUGH_Z)


## A transform that carries a unit +Y part from a to b, spun `spin` round its length.
static func _span(a: Vector3, b: Vector3, spin: float) -> Transform3D:
	var d := b - a
	var y := d.normalized()
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Transform3D(Basis(x, d, z) * Basis(Vector3.UP, spin), a)


func interact_prompt() -> String:
	var line := super()
	if valve_broken:
		return line + "\nThe pump valve's cracked: no water till a new one's fitted"
	if stored >= capacity:
		line += "
Trough's full: the pump's sending water up to the tower"
	if GameState.pumps_on():
		return line + "\nThe generator's pumping it"
	return line + "\nOnly fills while the generator runs"
