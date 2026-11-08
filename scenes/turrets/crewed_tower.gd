class_name CrewedTower
extends StaticBody3D
## The crewed-gun tower: the timber frame a second crewed gun stands on, over the
## first one in the crewed spot at the middle of the lip (Buildable.CREWED_CELL).
## It's part of the upper gun (CrewedTurret, stack level UPPER_LEVEL): four
## posts round the lower gun's 2 x 2 footprint, open to the canyon so the lower
## gun still sees out, bracing on the sides and back, a plank deck the upper gun
## stands on, and a ladder up the back. E on any of it at ground level takes the
## upper gun's seat, so you never have to climb up first.

## The upper gun stands on the same level as the third of three stacked turrets.
const UPPER_LEVEL := 3
## Half the footprint (2 x 2 cells of 2 m), plus a little for the posts.
const HALF := 2.15

var gun: CrewedTurret


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var h := ScaffoldNode.turret_height(UPPER_LEVEL)
	# The frame hangs down from the upper gun's feet to the ground.
	var mi := MeshInstance3D.new()
	mi.mesh = _frame_mesh(h)
	mi.material_override = Materials.toon(0.02)
	mi.position.y = -h
	add_child(mi)
	# Collision: the four posts, the deck under the upper gun, and the ladder.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(Vector3(sx * HALF, -h * 0.5, sz * HALF), Vector3(0.3, h, 0.3))
	_box(Vector3(0, -0.12, 0.2), Vector3(HALF * 2.0 + 0.3, 0.24, HALF * 2.0 + 0.7))
	_box(Vector3(0, -h * 0.5, HALF + 0.35), Vector3(0.9, h, 0.25))


func _box(at: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = at
	add_child(col)


func interact_prompt() -> String:
	if gun == null or not is_instance_valid(gun):
		return ""
	return "%s (up top)\nE: climb up and take the seat" % gun.def.display_name


func local_interact(holding: bool) -> void:
	if gun != null and is_instance_valid(gun):
		gun.local_interact(holding)


## The frame, local to the ground under the upper gun (+Z is the back, away from
## the canyon; the canyon side is left open).
static func _frame_mesh(h: float) -> ArrayMesh:
	var st := MeshKit.begin()
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DARK
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * HALF, h * 0.5, sz * HALF)), Vector3(0.26, h, 0.26), dark)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * HALF, 0.12, sz * HALF)), Vector3(0.5, 0.24, 0.5), Color("#7A7268")) # stone footing
	# Rails round the frame at two heights, and the deck's rim.
	for y: float in [h * 0.36, h * 0.7, h - 0.12]:
		for s: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(s * HALF, y, 0)), Vector3(0.16, 0.2, HALF * 2.0), wood)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, HALF)), Vector3(HALF * 2.0, 0.2, 0.16), wood)
		if y > h * 0.9:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, -HALF)), Vector3(HALF * 2.0, 0.2, 0.16), wood)
	# X bracing on the sides and the back (never across the canyon side).
	for k in 2:
		var y0 := h * (0.36 if k == 1 else 0.0) + 0.2
		var y1 := h * (0.7 if k == 1 else 0.36)
		for s: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(s * HALF, y0, -HALF), Vector3(s * HALF, y1, HALF), 0.07, dark, 5)
			MeshKit.add_limb(st, Vector3(s * HALF, y0, HALF), Vector3(s * HALF, y1, -HALF), 0.07, dark, 5)
		MeshKit.add_limb(st, Vector3(-HALF, y0, HALF), Vector3(HALF, y1, HALF), 0.07, dark, 5)
		MeshKit.add_limb(st, Vector3(HALF, y0, HALF), Vector3(-HALF, y1, HALF), 0.07, dark, 5)
	# The deck: planks across, a little deeper than the footprint at the back.
	for i in 12:
		var z := -HALF + 0.18 + i * (HALF * 2.0 + 0.4) / 12.0
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, h - 0.06, z)), Vector3(HALF * 2.0 + 0.3, 0.1, 0.34), wood if i % 2 else wood.darkened(0.08))
	# A ladder up the back.
	for s: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(s * 0.36, h * 0.5, HALF + 0.35)), Vector3(0.09, h, 0.09), dark)
	var rungs := int(h / 0.4)
	for i in rungs:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.35 + i * 0.4, HALF + 0.35)), Vector3(0.72, 0.06, 0.07), wood)
	return MeshKit.finish(st)
