class_name ScaffoldNode
extends StaticBody3D
## A wooden scaffold tower on a turret-line cell, 1-3 levels tall. Build another
## scaffold on the same spot to add a level. Each level's platform holds a turret
## (plus one on the ground inside the frame), and turrets higher up get 5 more
## degrees of look-down per level. Hold E on the scaffold to repair its most
## damaged turret from the ground; X takes down the top level.

const LEVEL_HEIGHT := 3.0
const SIZE := 1.9

var cliff_id: int = 0
var cell: Vector2i = Vector2i(-1, -1)
var build_id: StringName = &"scaffold"
var radius: float = 1.0
## Replicated: how many levels tall.
var levels: int = 1:
	set(v):
		levels = v
		if is_inside_tree():
			_rebuild()

var _mi: MeshInstance3D


func setup(cid: int, c: Vector2i, pos: Vector3) -> void:
	cliff_id = cid
	cell = c
	position = pos
	rotation.y = WorldLayout.facing_canyon_yaw(cid)
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	_mi = MeshInstance3D.new()
	_mi.material_override = Materials.toon(0.02)
	add_child(_mi)
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:levels"))
	cfg.property_set_spawn(NodePath(".:levels"), true)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 0.25
	add_child(sync)


func _ready() -> void:
	_rebuild()


## Host: change the height.
func set_levels(n: int) -> void:
	levels = clampi(n, 1, BuildManager.MAX_SCAFFOLD)


func _rebuild() -> void:
	if _mi == null:
		return
	_mi.mesh = mesh_for(levels)
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	# Four corner posts plus a thin platform per level (turrets stand on these;
	# the ground slot stays open inside the frame).
	var h := 0.5 * SIZE - 0.08
	for x: float in [-h, h]:
		for z: float in [-h, h]:
			var col := CollisionShape3D.new()
			var post := BoxShape3D.new()
			post.size = Vector3(0.16, LEVEL_HEIGHT * levels, 0.16)
			col.shape = post
			col.position = Vector3(x, LEVEL_HEIGHT * levels * 0.5, z)
			add_child(col)


static func mesh_for(n: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 333
	var st := MeshKit.begin()
	var h := 0.5 * SIZE - 0.08
	var top := LEVEL_HEIGHT * n
	for x: float in [-h, h]:
		for z: float in [-h, h]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, top * 0.5, z)), Vector3(0.14, top, 0.14), Palette.WOOD, 0.02, rng)
	for level in n:
		var y := LEVEL_HEIGHT * (level + 1)
		# Platform planks.
		for i in 5:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.72 + i * 0.36, y - 0.06, 0)), Vector3(0.32, 0.08, SIZE), Palette.WOOD_DARK, 0.015, rng)
		# Cross braces on two sides.
		for side: float in [-h, h]:
			var a := Vector3(-h, y - LEVEL_HEIGHT + 0.2, side)
			var b := Vector3(h, y - 0.2, side)
			MeshKit.add_limb(st, a, b, 0.04, Palette.WOOD_DARK, 5)
		# Ladder rungs on the back.
		for r in 6:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y - LEVEL_HEIGHT + 0.4 + r * 0.45, h + 0.1)), Vector3(0.5, 0.05, 0.05), Palette.WOOD)
	return MeshKit.finish(st)


func interact_prompt() -> String:
	var bm := BuildManager.instance
	var damaged := 0
	for t in bm.turrets_on(cliff_id, cell):
		if t.needs_repair():
			damaged += 1
	var text := "Scaffold: %d level%s, %d turret%s on it" % [levels, "" if levels == 1 else "s",
			bm.turrets_on(cliff_id, cell).size(), "" if bm.turrets_on(cliff_id, cell).size() == 1 else "s"]
	if damaged > 0:
		text += "\nHold E: repair its turrets (%d damaged)" % damaged
	if levels < BuildManager.MAX_SCAFFOLD:
		text += "\nBuild another scaffold here to add a level"
	return text


func local_interact(_holding: bool) -> void:
	BuildManager.instance.repair_node(self)
