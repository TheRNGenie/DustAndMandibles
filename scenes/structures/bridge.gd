class_name RopeBridge
extends Node3D
## Rope drawbridge across the canyon, in two halves that meet in the middle.
## Lowered during the build phase so players can visit each other; both halves
## haul up at the warning bell so nobody can camp the other side during a wave.
## Driven locally on every peer from the replicated phase, so it needs no sync.

const BRIDGE_Z := -17.0
const WIDTH := 2.4
const SAG := 0.7
const RAISED_ANGLE := deg_to_rad(80.0)
const RAISE_SPEED := deg_to_rad(30.0) # radians per second

var _halves: Array[AnimatableBody3D] = []
var _target_angle := 0.0
var _angle := 0.0


func setup(cliffs: CliffBuilder) -> void:
	for cid in 2:
		var pivot := cliffs.plateau_point(cid, 0.3, BRIDGE_Z)
		pivot.y = WorldLayout.CLIFF_HEIGHT
		var length := absf(pivot.x)
		var half := AnimatableBody3D.new()
		half.name = "Half%d" % cid
		half.sync_to_physics = false
		half.position = pivot
		half.rotation.y = WorldLayout.facing_canyon_yaw(cid)
		add_child(half)
		var mi := MeshInstance3D.new()
		mi.mesh = _half_mesh(length, 900 + cid)
		mi.material_override = Materials.toon()
		half.add_child(mi)
		_add_collision(half, length)
		_halves.append(half)
		# Anchor posts on the cliff top.
		var posts := MeshInstance3D.new()
		posts.mesh = _anchor_mesh()
		posts.material_override = Materials.toon()
		posts.position = cliffs.plateau_point(cid, 0.8, BRIDGE_Z)
		posts.rotation.y = WorldLayout.facing_canyon_yaw(cid)
		add_child(posts)
	GameState.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(GameState.phase)
	_angle = _target_angle
	_apply()


func _on_phase_changed(p: GameState.Phase) -> void:
	var lowered := p == GameState.Phase.BUILD or p == GameState.Phase.LOBBY
	_target_angle = 0.0 if lowered else RAISED_ANGLE


func is_lowered() -> bool:
	return _angle < 0.01


func _physics_process(delta: float) -> void:
	if is_equal_approx(_angle, _target_angle):
		return
	_angle = move_toward(_angle, _target_angle, RAISE_SPEED * delta)
	_apply()


func _apply() -> void:
	for half in _halves:
		half.rotation.x = _angle


## Deck height offset at distance t (0 at the cliff, 1 at the middle).
static func sag_at(t: float) -> float:
	return -SAG * sin(t * PI * 0.5)


func _add_collision(half: AnimatableBody3D, length: float) -> void:
	var segments := 6
	for i in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a := Vector3(0, sag_at(t0), -t0 * length)
		var b := Vector3(0, sag_at(t1), -t1 * length)
		var mid := (a + b) * 0.5
		var seg_len := a.distance_to(b)
		var basis := Basis.looking_at((b - a).normalized(), Vector3.UP)
		for part in 3:
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			var offset := Vector3.ZERO
			if part == 0:
				shape.size = Vector3(WIDTH, 0.2, seg_len + 0.05)
				offset = Vector3(0, -0.1, 0)
			else:
				# Low side rails so it's hard to fall off by accident.
				shape.size = Vector3(0.15, 1.0, seg_len + 0.05)
				offset = Vector3((WIDTH * 0.5 + 0.05) * (-1.0 if part == 1 else 1.0), 0.5, 0)
			col.shape = shape
			col.transform = Transform3D(basis, mid + basis * offset)
			half.add_child(col)


static func _half_mesh(length: float, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := MeshKit.begin()
	var plank_w := 0.32
	var n := int(length / (plank_w + 0.06))
	for i in n:
		var t := (float(i) + 0.5) / n
		var z := -t * length
		var y := sag_at(t) - 0.06
		var b := Basis(Vector3.UP, rng.randf_range(-0.04, 0.04))
		var shade := Palette.WOOD if i % 3 else Palette.WOOD.lightened(0.08)
		MeshKit.add_box(st, Transform3D(b, Vector3(rng.randf_range(-0.05, 0.05), y, z)),
				Vector3(WIDTH + rng.randf_range(-0.1, 0.1), 0.08, plank_w), shade, 0.015, rng)
	# Rope rails and the hanging ropes down to the planks.
	for side: float in [-1.0, 1.0]:
		var x := side * (WIDTH * 0.5 + 0.05)
		var steps := 12
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var a := Vector3(x, sag_at(t0) * 0.8 + 1.0, -t0 * length)
			var c := Vector3(x, sag_at(t1) * 0.8 + 1.0, -t1 * length)
			MeshKit.add_limb(st, a, c, 0.03, Palette.BONE.darkened(0.25), 5)
			MeshKit.add_limb(st, a, Vector3(x, sag_at(t0) - 0.05, -t0 * length), 0.015, Palette.BONE.darkened(0.35), 4)
	return MeshKit.finish(st)


static func _anchor_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	for side: float in [-1.0, 1.0]:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(side * (WIDTH * 0.5 + 0.2), 0.9, 0)), 0.14, 0.12, 1.8, 8, Palette.WOOD)
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(side * (WIDTH * 0.5 + 0.2), 1.0, 0)), 0.16, 0.16, 0.12, 8, Palette.BONE.darkened(0.25))
	return MeshKit.finish(st)
