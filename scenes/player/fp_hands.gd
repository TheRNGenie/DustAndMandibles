class_name FpHands
extends Node3D
## Your own hands in first person when you use something: the gun dips out of
## view and both hands come up to do the job, with the thing they're holding:
## a seed to plant, the bucket to tip, a crop pulled out of the ground, scrap
## dug out of the heap, a card, a pair of dice, a coin for the shopkeeper, a
## hammer... Each move is a little function of t (0..1) giving both hands'
## positions and turns in camera space (front is -Z), the prop, and how far
## the view tips down to look at the work. Same move names as DummyActions.

var gun: Gun
var _right: Node3D
var _left: Node3D
var _prop_r: MeshInstance3D
var _prop_l: MeshInstance3D
var _fly: MeshInstance3D
var _stream: MeshInstance3D
var _mat: Material
var _r_mi: MeshInstance3D
var _l_mi: MeshInstance3D
var action: StringName = &""
var t := 0.0
var _dur := 1.0
var _prop_id: StringName = &""
## How far the camera tips down (radians), read by Player.
var dip := 0.0
var _props: Dictionary = {}
## Debug screenshots: hold the move at this point (0..1); -1 plays normally.
var freeze := -1.0
## The thing being used, in camera space (where the hand reaches to).
var _target := Vector3(0.1, -0.25, -0.5)
## Every hands-on move is short and snappy in first person.
const DUR_FP := 0.75


func _ready() -> void:
	_mat = Materials.toon(0.004)
	_right = _limb()
	_left = _limb()
	_r_mi = _right.get_child(0) as MeshInstance3D
	_l_mi = _left.get_child(0) as MeshInstance3D
	_prop_r = _prop_node(_right)
	_prop_l = _prop_node(_left)
	_fly = MeshInstance3D.new()
	_fly.material_override = _mat
	_fly.top_level = true
	_fly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fly)
	_stream = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.02
	cyl.height = 0.6
	cyl.radial_segments = 8
	_stream.mesh = cyl
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.55, 0.8, 1.0, 0.7)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stream.material_override = wm
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stream)
	refresh(Settings.look)
	visible = false


func _limb() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var mi := MeshInstance3D.new()
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


func _prop_node(parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Rebuild the hands for a new outfit.
func refresh(look: Dictionary) -> void:
	_r_mi.mesh = hand_mesh(look, 1.0)
	_l_mi.mesh = hand_mesh(look, -1.0)


## A hand reaching forward (palm down, fingers curled) with its forearm running
## back toward you. Origin at the middle of the hand. side = 1 right, -1 left.
static func hand_mesh(look: Dictionary, side: float) -> ArrayMesh:
	look = DummyLook.clean(look)
	var st := MeshKit.begin()
	WeaponBuilder.fist(st, Vector3.ZERO, Vector3(side, 0, 0), Vector3(0, 1, 0.2), DummyLook.paint(look), side > 0.0)
	# A long forearm, so its far end is always out of view below the screen.
	WeaponBuilder.sleeve(st, Vector3(side * 0.005, -0.01, 0.05), Vector3(side * 0.16, -0.42, 0.5), look)
	return MeshKit.finish(st)


func play(id: StringName, prop: StringName = &"", target: Vector3 = Vector3(0.1, -0.25, -0.5)) -> void:
	if not DummyActions.has(id) or id == &"wardrobe":
		return
	action = id
	_prop_id = prop
	_target = target
	t = 0.0
	_dur = DUR_FP * (1.25 if id in [&"pump", &"slots", &"water", &"ledger"] else 1.0)
	visible = true
	_fly.visible = false
	_prop_r.mesh = null
	_prop_l.mesh = null
	if gun != null:
		gun.set_lowered(true)


func is_playing() -> bool:
	return action != &""


func _process(delta: float) -> void:
	if action == &"":
		dip = move_toward(dip, 0.0, delta * 2.0)
		return
	t += delta / _dur
	if freeze >= 0.0:
		t = freeze
	if t >= 1.0:
		action = &""
		visible = false
		_stream.visible = false
		_fly.visible = false
		if gun != null:
			gun.set_lowered(false)
		return
	var w := minf(smoothstep(0.0, 0.2, t), 1.0 - smoothstep(0.8, 1.0, t))
	var low := Vector3.ZERO
	_stream.visible = false
	var p := _pose(action, t, delta)
	_right.transform = Transform3D(Basis.from_euler(p[1]), (p[0] as Vector3) + low)
	_left.transform = Transform3D(Basis.from_euler(p[3]), (p[2] as Vector3) + low)
	_left.visible = bool(p[4])
	dip = lerpf(dip, float(p[5]) * w, clampf(delta * 10.0, 0.0, 1.0))


# Rest spots for the hands in camera space.
const R0 := Vector3(0.17, -0.24, -0.42)
const L0 := Vector3(-0.17, -0.24, -0.42)


## Where the hand goes: the point under the crosshair, kept within arm's reach
## (camera space).
func _reach_point() -> Vector3:
	return Vector3(clampf(_target.x, -0.04, 0.2), clampf(_target.y, -0.36, -0.1), clampf(_target.z, -0.6, -0.46))


const REST_LOW := Vector3(0.22, -0.45, -0.26)


## [right pos, right rot, left pos, left rot, left visible, view dip].
## Every move is the same shape: the right hand reaches out to the thing under
## your crosshair (0-35%), does the job right there (35-65%), and drops back out
## of view with whatever it took (65-100%).
func _pose(id: StringName, tt: float, _delta: float) -> Array:
	var life := Time.get_ticks_msec() * 0.001
	var reach := smoothstep(0.0, 0.35, tt)
	var back := smoothstep(0.68, 1.0, tt)
	var a := clampf((tt - 0.35) / 0.33, 0.0, 1.0) # progress of the job itself
	var at := _reach_point()
	var hand := REST_LOW.lerp(at, reach)
	# Reaching down tips the hand down; reaching up tips it up.
	# Fingers forward and a little down, knuckles up: a hand reaching to take hold.
	var rot := Vector3(0.3 + 0.3 * clampf(-at.y - 0.15, 0.0, 0.3), 0.2, 0.15)
	var off := Vector3.ZERO
	var left := false
	var l_off := Vector3(-0.2, 0.0, 0.02)
	var take := &""
	match id:
		&"harvest", &"loot":
			# Grip, a couple of tugs, then a yank back with it.
			var tug := sin(a * PI * 4.0) * 0.012 * (1.0 - smoothstep(0.6, 0.8, a))
			off = Vector3(0, tug + 0.07 * smoothstep(0.7, 1.0, a), tug + 0.1 * smoothstep(0.7, 1.0, a))
			take = (&"crop" if id == &"harvest" else &"chitin") if a > 0.75 else &""
		&"salvage":
			off = Vector3(sin(a * PI * 6.0) * 0.02, -absf(sin(a * PI * 3.0)) * 0.03 + 0.06 * smoothstep(0.75, 1.0, a), 0.08 * smoothstep(0.75, 1.0, a))
			take = &"scrap" if a > 0.75 else &""
		&"plant":
			# Two pokes into the soil with the seed, then a pat.
			off = Vector3(0, -absf(sin(a * PI * 3.0)) * 0.05, 0)
			take = &"seed" if a < 0.5 else &""
			rot.x -= 0.4 * reach
		&"water":
			rot.z += 1.0 * sin(a * PI)
			take = &"water"
			if a > 0.15 and a < 0.85:
				_stream.visible = true
				var mouth := _right.to_global(Vector3(-0.09, 0.03, 0.0))
				_stream.global_transform = Transform3D(Basis(), mouth + Vector3(0, -0.3, 0))
		&"pump":
			off = Vector3(0, -0.07 * (sin(a * PI * 4.0) * 0.5 + 0.5), 0)
			left = true
		&"chest":
			off = Vector3(0, 0.14 * smoothstep(0.2, 0.9, a), 0.03 * a)
			rot.x += 0.6 * smoothstep(0.2, 0.9, a)
			left = true
		&"ledger":
			# Pencil scribbling over the open book.
			off = Vector3(sin(life * 9.0) * 0.025, sin(life * 21.0) * 0.006, 0)
			take = &"pencil"
			left = true
			l_off = Vector3(-0.14, -0.04, 0.03)
		&"buy":
			off = Vector3(0, 0.02, -0.04 * sin(a * PI))
			take = &"coin" if a < 0.6 else &""
		&"pickup", &"zip":
			off = Vector3(0, 0.0, 0.08 * smoothstep(0.5, 1.0, a))
		&"hammer":
			var blow := absf(sin(a * PI * 2.0))
			off = Vector3(0, 0.08 * blow, 0.03 * blow)
			rot.x += 1.1 * blow - 0.3
			take = &"hammer"
		&"slots":
			off = Vector3(0, 0.12 * (1.0 - smoothstep(0.3, 0.7, a)) - 0.08 * smoothstep(0.3, 0.7, a), 0)
		&"cards":
			off = Vector3(-0.05 * sin(a * PI), 0, -0.05 * sin(a * PI))
			take = &"card" if a < 0.5 else &""
			if a >= 0.5:
				_fly_prop(&"card", at, clampf((a - 0.5) * 3.0, 0.0, 1.0), Vector3(-0.05, -0.15, -0.3))
		&"dice":
			off = Vector3(sin(life * 38.0) * 0.015 * (1.0 - a), 0, 0)
			take = &"dice" if a < 0.6 else &""
			if a >= 0.6:
				_fly_prop(&"dice", at, clampf((a - 0.6) * 3.0, 0.0, 1.0), Vector3(0, -0.25, -0.6))
		&"roulette":
			off = Vector3(0.12 - 0.24 * smoothstep(0.1, 0.9, a), 0, 0)
	_set_prop(_prop_r, take, take)
	var r_pos := (hand + off * (1.0 - back)).lerp(REST_LOW, back)
	var l_pos := (hand + l_off).lerp(REST_LOW * Vector3(-1, 1, 1), back)
	if id == &"ledger":
		_set_prop(_prop_l, &"ledger", &"ledger")
	var dip_amt := clampf(-at.y * 0.35, 0.0, 0.16)
	return [r_pos, rot, l_pos, Vector3(rot.x, -0.15, -0.1), left, dip_amt]


func _set_prop(mi: MeshInstance3D, id: StringName, _kind: StringName) -> void:
	if id == &"":
		mi.mesh = null
		return
	mi.mesh = prop_mesh(id)
	mi.position = Vector3(0, 0.035, -0.02) if id == &"ledger" else Vector3(0, -0.01, -0.035)


## A prop leaving the hand: starts at `from`, travels `travel` with a little arc
## (both in camera space).
func _fly_prop(id: StringName, from: Vector3, k: float, travel: Vector3) -> void:
	if not _fly.visible:
		_fly.visible = true
		_fly.mesh = prop_mesh(id)
	var cam := get_parent() as Node3D
	var local := from + travel * k + Vector3(0, sin(k * PI) * 0.08, 0)
	_fly.global_transform = Transform3D(cam.global_basis * Basis.from_euler(Vector3(k * 6.0, k * 4.0, 0)), cam.to_global(local))


func prop_mesh(id: StringName) -> Mesh:
	if _props.has(id):
		return _props[id]
	var st := MeshKit.begin()
	match id:
		&"seed":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.008, 0.006, 0.011), 4, 8, Color("#8A6A3A"))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.012, 0.002, 0.004)), Vector3(0.006, 0.005, 0.008), 4, 8, Color("#6E5230"))
		&"water":
			_props[id] = WeaponBuilder.held_item(&"water")
			return _props[id]
		&"crop":
			# A pulled plant: roots with dirt, a stalk and leaves.
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, -0.05, 0)), Vector3(0.03, 0.025, 0.03), 4, 8, Color("#5A3A22"))
			for k in 4:
				var a := TAU * k / 4.0
				MeshKit.tube(st, [Vector3(0, -0.05, 0), Vector3(cos(a) * 0.015, -0.08, sin(a) * 0.015), Vector3(cos(a) * 0.02, -0.1, sin(a) * 0.02)], [0.004, 0.003, 0.001], 4, Color("#C8A878"))
			MeshKit.tube(st, [Vector3(0, -0.03, 0), Vector3(0, 0.04, 0), Vector3(0.01, 0.1, 0)], [0.008, 0.007, 0.005], 6, Color("#4E8A3A"))
			for k in 5:
				var a := TAU * k / 5.0
				var base := Vector3(0, 0.02 + k * 0.018, 0)
				MeshKit.tube(st, [base, base + Vector3(cos(a) * 0.04, 0.02, sin(a) * 0.04), base + Vector3(cos(a) * 0.07, 0.0, sin(a) * 0.07)], [0.01, 0.014, 0.002], 5, Color("#6FB04A") if k % 2 == 0 else Color("#58983C"))
		&"scrap":
			# A bent gear and a bolt.
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.035, 0.035, 0.01, 10, Color("#8A8A90"))
			for k in 10:
				var a := TAU * k / 10.0
				MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 0.04, sin(a) * 0.04, 0)), Vector3(0.012, 0.01, 0.01), Color("#7A7A80"))
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.01, 0.01, 0.014, 8, Color("#B87A4A"))
		&"chitin":
			MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.05, 0.012, 0.04), 5, 10, Color("#5A4A7A"))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.006, 0)), Vector3(0.04, 0.008, 0.03), 4, 10, Color("#7A6AA0"))
		&"card":
			MeshKit.add_box(st, Transform3D(), Vector3(0.045, 0.002, 0.065), Color("#F4F0E6"))
			MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.0015, 0)), Vector3(0.008, 0.001, 0.01), 3, 6, Color("#C23A2C"))
		&"cards":
			for k in 5:
				var b := Basis(Vector3.UP, (k - 2) * 0.22)
				MeshKit.add_box(st, Transform3D(b, b * Vector3(0, k * 0.001, -0.02)), Vector3(0.045, 0.002, 0.065), Color("#F4F0E6") if k % 2 == 0 else Color("#ECE6D6"))
				MeshKit.add_ellipsoid(st, Transform3D(b, b * Vector3(0, k * 0.001 + 0.0015, -0.04)), Vector3(0.006, 0.001, 0.008), 3, 6, Color("#1E1E22") if k % 2 == 0 else Color("#C23A2C"))
		&"dice":
			for k in 2:
				var c := Vector3(k * 0.024 - 0.012, 0, 0)
				MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, k * 0.5), c), Vector3.ONE * 0.02, Color("#F4F0E6"))
				for d in 3:
					MeshKit.add_ellipsoid(st, Transform3D(Basis(), c + Vector3((d - 1) * 0.005, 0.0105, (d - 1) * 0.005)), Vector3(0.002, 0.001, 0.002), 3, 6, Color("#1E1E22"))
		&"coin":
			MeshKit.add_cylinder(st, Transform3D(), 0.016, 0.016, 0.003, 14, Color("#E8C04A"))
			MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.0018, 0)), 0.011, 0.011, 0.001, 14, Color("#C89A2A"))
		&"ledger":
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.1), Vector3(-0.03, 0, -0.04)), Vector3(0.1, 0.008, 0.13), Color("#F0E6CC"))
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.1), Vector3(0.07, 0, -0.04)), Vector3(0.1, 0.008, 0.13), Color("#F0E6CC"))
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.02, -0.006, -0.04)), Vector3(0.22, 0.006, 0.14), Color("#6A2A22"))
			for k in 5:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.03, 0.005, -0.08 + k * 0.018)), Vector3(0.07, 0.001, 0.002), Color("#6A5A4A"))
		&"pencil":
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.02)), 0.004, 0.004, 0.09, 6, Color("#D8A830"))
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.07)), 0.0, 0.004, 0.014, 6, Color("#3A2A1A"))
		&"hammer":
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.05)), 0.008, 0.009, 0.2, 8, Palette.WOOD)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, -0.15)), Vector3(0.09, 0.03, 0.03), Color("#5A5A62"))
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.05, 0, -0.15)), Vector3(0.015, 0.034, 0.034), Color("#7A7A82"))
	_props[id] = MeshKit.finish(st)
	return _props[id]
