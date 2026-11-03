class_name StoryCargo
extends StaticBody3D
## A Story fetch item (StoryDirector): the pump valve crate the airship drops
## under a parachute, or the Queen Spider's gland. E picks it up; it rides
## along on the carrier's back (others see it there; you see a small one bob
## at the bottom of your view) until it reaches a well or a noticeboard. The
## host decides who carries it; this node only shows it.

const FALL_TIME := 4.5

var kind := "valve"
var title := "Pump Valve"
var director: StoryDirector
var _body: Node3D
var _chute: Node3D
var _beacon: MeshInstance3D
var _col: CollisionShape3D
var _carried := false
var _mine := false
var _t := 0.0
var _falling := false


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	_body = Node3D.new()
	add_child(_body)
	var mi := MeshInstance3D.new()
	mi.mesh = gland_mesh() if kind == "gland" else valve_crate_mesh()
	mi.material_override = Materials.toon(0.02)
	_body.add_child(mi)
	_col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 1.1, 1.3)
	_col.shape = shape
	_col.position.y = 0.55
	add_child(_col)
	# A tall column of light so it can be found from across the map.
	_beacon = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.32
	cyl.height = 30.0
	cyl.radial_segments = 10
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beacon.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(Palette.ACID_GREEN if kind == "gland" else Palette.GLOW_YELLOW, 0.22)
	_beacon.material_override = bm
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.position.y = 15.0
	add_child(_beacon)


func fall_from(from: Vector3, landed: Callable) -> void:
	var to := global_position
	global_position = from
	_falling = true
	_beacon.visible = false
	_chute = MeshInstance3D.new()
	(_chute as MeshInstance3D).mesh = parachute_mesh()
	(_chute as MeshInstance3D).material_override = Materials.toon(0.02)
	_body.add_child(_chute)
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, FALL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_falling = false
		_beacon.visible = not _carried
		if _chute != null:
			var c := _chute
			_chute = null
			var t2 := create_tween()
			t2.tween_property(c, "scale", Vector3(1.4, 0.05, 1.4), 0.6)
			t2.tween_callback(c.queue_free)
		Audio.play_ui(&"build", -4.0)
		landed.call())


func _process(delta: float) -> void:
	_t += delta
	if _falling:
		_body.rotation.z = sin(_t * 1.7) * 0.12
		_body.rotation.x = cos(_t * 1.3) * 0.08
	elif not _carried:
		_body.rotation = Vector3.ZERO
		if kind == "gland":
			var s := 1.0 + sin(_t * 2.6) * 0.06 # it is, regrettably, still thinking
			_body.scale = Vector3(s, 1.0 / s, s)


func set_carried(on: bool, mine: bool) -> void:
	_carried = on
	_mine = mine and on
	_col.disabled = on
	_beacon.visible = not on
	_body.visible = not _mine
	if not on:
		_body.position = Vector3.ZERO
		_body.scale = Vector3.ONE


## Rides on the carrier's back (seen by everyone else).
func carry_at(p: Player) -> void:
	global_position = p.global_position + p.global_basis.z * 0.45 + Vector3.UP * 1.0
	_body.global_rotation = Vector3(0, p.global_rotation.y, 0)
	_body.scale = Vector3.ONE * 0.65


func delivered() -> void:
	_col.disabled = true
	_beacon.visible = false
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(queue_free)


func interact_prompt() -> String:
	if _carried or _falling:
		return ""
	return "%s\nE: pick it up" % title


func local_interact(holding: bool) -> void:
	if not holding and director != null and not _carried:
		director.request_pickup()


# ------------------------------------------------------------------ meshes

## A banded crate with a big brass valve wheel bolted on top.
static func valve_crate_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var wood := Palette.WOOD.lightened(0.08)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.38, 0)), Vector3(0.95, 0.76, 0.95), wood)
	for y: float in [0.12, 0.64]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(0.99, 0.08, 0.99), Palette.WOOD_DARK)
	for x: float in [-0.44, 0.44]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.38, 0)), Vector3(0.08, 0.78, 0.99), Palette.WOOD_DARK)
	# Stencil: a red cross on the side.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.38, -0.48)), Vector3(0.36, 0.08, 0.01), Color("#B8352A"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.38, -0.48)), Vector3(0.08, 0.36, 0.01), Color("#B8352A"))
	# The valve: a stem and a spoked brass wheel.
	var brass := Color("#D9A83A")
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.88, 0)), 0.09, 0.09, 0.26, 10, Palette.METAL)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.82, 0)), 0.2, 0.2, 0.1, 12, Palette.METAL.darkened(0.2))
	var rim := 0.36
	for k in 16:
		var a := TAU * k / 16.0
		var b := TAU * (k + 1) / 16.0
		var pa := Vector3(cos(a) * rim, 1.02, sin(a) * rim)
		var pb := Vector3(cos(b) * rim, 1.02, sin(b) * rim)
		MeshKit.add_limb(st, pa, pb, 0.035, brass, 6)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		MeshKit.add_limb(st, Vector3(0, 1.02, 0), Vector3(cos(a) * rim, 1.02, sin(a) * rim), 0.025, brass, 5)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 1.02, 0)), 0.07, 0.07, 0.07, 8, brass)
	return MeshKit.finish(st)


## A fat, faintly glowing gland in a tangle of web.
static func gland_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 711
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.42, 0)), Vector3(0.42, 0.36, 0.34), 8, 12, Color("#7E4A8C"), 0.04, rng, 0.25)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.12, 0.5, -0.18)), Vector3(0.16, 0.13, 0.12), 5, 8, Palette.ACID_GREEN, 0.0, null, 0.7)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.16, 0.36, -0.2)), Vector3(0.11, 0.09, 0.09), 5, 8, Palette.ACID_GREEN, 0.0, null, 0.6)
	# Veins.
	for k in 6:
		var a := TAU * k / 6.0 + rng.randf() * 0.4
		var p0 := Vector3(cos(a) * 0.3, 0.6, sin(a) * 0.26)
		var p1 := Vector3(cos(a + 0.5) * 0.4, 0.3, sin(a + 0.5) * 0.32)
		MeshKit.add_limb(st, p0, p1, 0.022, Color("#4A2556"), 4)
	# Web strands to the ground.
	for k in 5:
		var a := TAU * k / 5.0
		MeshKit.add_limb(st, Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.25), Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.55), 0.012, Palette.BONE, 4)
	return MeshKit.finish(st)


## A striped canvas parachute on lines, above the crate.
static func parachute_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var top := 3.2
	var r := 1.9
	var segs := 12
	for k in segs:
		var a := TAU * k / segs
		var b := TAU * (k + 1) / segs
		var col := MeshKit.vcol(Color("#F2E3C2") if k % 2 == 0 else Color("#B8352A"))
		var pa := Vector3(cos(a) * r, top - 0.7, sin(a) * r)
		var pb := Vector3(cos(b) * r, top - 0.7, sin(b) * r)
		var ma := Vector3(cos(a) * r * 0.62, top - 0.08, sin(a) * r * 0.62)
		var mb := Vector3(cos(b) * r * 0.62, top - 0.08, sin(b) * r * 0.62)
		var apex := Vector3(0, top + 0.12, 0)
		var out := ((pa + pb) * 0.5 + Vector3.UP * 0.8).normalized()
		MeshKit.quad(st, pa, pb, mb, ma, out, col)
		MeshKit.quad(st, pa, pb, mb, ma, -out, col)
		MeshKit.tri(st, ma, mb, apex, Vector3.UP, Vector3.UP, Vector3.UP, col, Vector3.UP)
		MeshKit.tri(st, ma, mb, apex, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, col, Vector3.DOWN)
		if k % 3 == 0:
			MeshKit.add_limb(st, pa, Vector3(cos(a) * 0.4, 0.95, sin(a) * 0.4), 0.012, Palette.OUTLINE, 3)
	return MeshKit.finish(st)
