class_name ScaffoldNode
extends StaticBody3D
## A timber scaffold frame on a turret-line cell, 1-3 storeys tall. It goes up
## round a turret, not under it: the first turret stands on the ground inside
## the bottom storey; each storey above has a plank floor for one more turret
## (turret_height). Build another scaffold on the same spot to add a storey.
## Turrets higher up get 5 more degrees of look-down per level. Hold E on the
## scaffold to repair its most damaged turret from the ground; X takes down the top storey.

const LEVEL_HEIGHT := 3.0
const SIZE := 2.0


## The bottom storey's plank deck: the first turret stands on it, a step off the
## ground inside the frame. Just high enough to see over the lip down the far
## wall (from the ground, the lip hides a third of the climbers).
const DECK := 1.0


## How high above the cell a turret at this stack level stands: level 1 is the
## deck inside the bottom storey, level 2 the floor one storey up, and so on
## (level 0 is a bare-ground turret with no scaffold).
static func turret_height(level: int) -> float:
	return 0.0 if level <= 0 else DECK + LEVEL_HEIGHT * (level - 1)


## Height of the whole frame with n storeys.
static func frame_height(n: int) -> float:
	return DECK + LEVEL_HEIGHT * n

var cliff_id: int = 0
var cell: Vector2i = Vector2i(-1, -1)
var build_id: StringName = &"scaffold"
var radius: float = 1.0
## Replicated: how many levels tall.
var levels: int = 1:
	set(v):
		# A level coming down splinters apart (every peer sees the new count).
		if is_inside_tree() and v < levels and is_instance_valid(VfxPool.instance):
			VfxPool.instance.splinters(global_position + Vector3.UP * LEVEL_HEIGHT * (float(v) + 0.5), 1.0)
		levels = v
		if is_node_ready(): # set during spawn: _ready() builds it
			_rebuild()
## Host only: levels someone paid for (free levels under turrets refund nothing).
var paid_levels: int = 0

var _mi: MeshInstance3D
var _ladder: Area3D


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
	add_to_group("scaffolds") # story "keep" chapters count these
	Materials.paint_live(self, Materials.RUSTIC, Materials.MAP_TIMBER) # painted wood, iron, rock (assets/rustic)
	_rebuild()


## Taken down for good (not the whole world closing): splinters where it stood.
func _exit_tree() -> void:
	_drop_ladder()
	if is_queued_for_deletion() and is_instance_valid(VfxPool.instance) and VfxPool.instance.is_inside_tree():
		VfxPool.instance.splinters(global_position + Vector3.UP * LEVEL_HEIGHT * 0.5, 1.0)


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
	_drop_ladder()
	# The four corner posts (the turrets inside the frame have their own).
	var h := POST_INSET
	for x: float in [-h, h]:
		for z: float in [-h, h]:
			var col := CollisionShape3D.new()
			var post := BoxShape3D.new()
			post.size = Vector3(0.17, frame_height(levels), 0.17)
			col.shape = post
			col.position = Vector3(x, frame_height(levels) * 0.5, z)
			add_child(col)
	# Every storey's plank deck is solid: you can stand on it and walk round the turret.
	for k in levels:
		var deck := CollisionShape3D.new()
		var plank := BoxShape3D.new()
		plank.size = Vector3(2.0 * h + 0.12, 0.12, 2.0 * h + 0.12)
		deck.shape = plank
		deck.position = Vector3(0, DECK + LEVEL_HEIGHT * k - 0.06, 0)
		add_child(deck)
		# Upper storeys: the side hand rails hold you in (the back stays open for
		# the ladder, the front for the turret's field of fire).
		if k >= 1:
			for sx: float in [-h, h]:
				var rail := CollisionShape3D.new()
				var rb := BoxShape3D.new()
				rb.size = Vector3(0.12, 1.1, 2.0 * h)
				rail.shape = rb
				rail.position = Vector3(sx, DECK + LEVEL_HEIGHT * k + 0.55, 0)
				add_child(rail)
	_build_ladder()


## The ladder up the back: walk into it and climb (forward/back), step off
## forward onto the top deck. Same as the house tower's ladder.
func _build_ladder() -> void:
	_ladder = Area3D.new()
	_ladder.name = "Ladder"
	_ladder.collision_layer = 0
	_ladder.collision_mask = 0xFFFF
	var top := ladder_top(levels)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Tall enough that the climb tops out (Player caps it a metre over the deck)
	# while you're still on the ladder, so the step-off push lands you on the deck.
	box.size = Vector3(0.9, top + 1.0, 1.3)
	col.shape = box
	col.position = Vector3(0, (top + 1.0) * 0.5, POST_INSET + 0.45)
	_ladder.add_child(col)
	add_child(_ladder)
	var lad := _ladder
	_ladder.body_entered.connect(func(b: Node3D) -> void:
		if b is Player and not lad.has_meta("gone"):
			(b as Player).ladder_count += 1
			# Player tops the climb out a metre over ladder_top_y: aim that just
			# over the deck, so stepping off drops you onto the planks, not past them.
			(b as Player).ladder_top_y = global_position.y + ladder_top(levels) - 0.8)
	_ladder.body_exited.connect(func(b: Node3D) -> void:
		if b is Player and not lad.has_meta("gone"):
			(b as Player).ladder_count = maxi((b as Player).ladder_count - 1, 0))


## Lets go of anyone on the ladder (it's being rebuilt or torn down) and removes it.
func _drop_ladder() -> void:
	if _ladder == null:
		return
	_ladder.set_meta("gone", true)
	if _ladder.is_inside_tree():
		for b in _ladder.get_overlapping_bodies():
			if b is Player:
				(b as Player).ladder_count = maxi((b as Player).ladder_count - 1, 0)
	_ladder.queue_free()
	_ladder = null


## Local height of the deck the ladder delivers you to (the top storey's).
static func ladder_top(n: int) -> float:
	return DECK + LEVEL_HEIGHT * maxi(n - 1, 0)


static func mesh_for(n: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 333
	var st := MeshKit.begin()
	var h := POST_INSET
	var top := frame_height(n)
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DARK
	var lash := Color("#C9A66B")
	var corners: Array[Vector2] = [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	# Corner posts (squared timbers, the full height), each on a flat footing stone.
	for c in corners:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(c.x, top * 0.5, c.y)), Vector3(0.17, top + 0.1, 0.17), wood, 0.015, rng)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, rng.randf() * 0.6), Vector3(c.x, 0.04, c.y)), Vector3(0.36, 0.1, 0.36), Palette.ROCK_C.darkened(0.15), 0.02, rng)
	# Mudsills round the foot, and short braces under the bottom deck (the crib).
	_side_beams(st, rng, 0.14, 0.12, dark, true)
	for sx: float in [-h, h]:
		_beam(st, Vector3(sx, 0.2, -h), Vector3(sx, DECK - 0.2, -h * 0.2), 0.09, wood)
		_beam(st, Vector3(sx, 0.2, h), Vector3(sx, DECK - 0.2, h * 0.2), 0.09, wood)
	for k in n:
		var y0 := DECK + LEVEL_HEIGHT * k
		var y1 := y0 + LEVEL_HEIGHT
		# Girts: a ring of beams at the head of every storey.
		_side_beams(st, rng, y1 - 0.08, 0.15, dark, true)
		# Bracing: one diagonal per storey on each side and the back, zig-zagging
		# up the frame; short knee braces in the open front's top corners.
		var flip := 1.0 if k % 2 == 0 else -1.0
		for sx: float in [-h, h]:
			_beam(st, Vector3(sx, y0 + 0.2, -h * flip), Vector3(sx, y1 - 0.2, h * flip), 0.1, wood)
		_beam(st, Vector3(-h * flip, y0 + 0.2, h), Vector3(h * flip, y1 - 0.2, h), 0.1, wood)
		for sx: float in [-h, h]:
			_beam(st, Vector3(sx, y1 - 0.75, -h), Vector3(sx * 0.45, y1 - 0.12, -h), 0.09, wood)
		# Rope lashings where the girts meet the posts.
		for c in corners:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(c.x, y1 - 0.08, c.y)), Vector3(0.21, 0.07, 0.21), lash, 0.01, rng)
		# A plank floor for the turret on this storey, on two joists (upper
		# storeys also get a hand rail round the sides and back).
		for sz: float in [-0.55, 0.55]:
			_beam(st, Vector3(-h, y0 - 0.16, sz), Vector3(h, y0 - 0.16, sz), 0.12, dark)
		for i in 6:
			var x := -h + 0.12 + i * (2.0 * h - 0.24) / 5.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.02, 0.02)), Vector3(x, y0 - 0.05, 0)),
					Vector3(0.29, 0.06, 2.0 * h + 0.12), dark.lightened(rng.randf_range(0.0, 0.08)), 0.01, rng)
		if k >= 1:
			_side_beams(st, rng, y0 + 1.0, 0.08, wood, false)
	# Ladder up the back: to the deck, or on up to the upper floors.
	var z := h + 0.14
	top = ladder_top(n) + 1.0
	for sx: float in [-0.24, 0.24]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, top * 0.5, z)), Vector3(0.07, top, 0.07), wood, 0.01, rng)
	var r := 0.35
	while r < top - 0.2:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, r, z)), Vector3(0.5, 0.05, 0.05), wood)
		r += 0.42
	return MeshKit.finish(st)


## Distance from the middle of the cell to the middle of each corner post.
const POST_INSET := 0.5 * SIZE - 0.09


## Horizontal beams between the corner posts at height y: sides and back, and
## the front too when `front` is set.
static func _side_beams(st: SurfaceTool, _rng: RandomNumberGenerator, y: float, w: float, color: Color, front: bool) -> void:
	var h := POST_INSET
	_beam(st, Vector3(-h, y, -h), Vector3(-h, y, h), w, color)
	_beam(st, Vector3(h, y, -h), Vector3(h, y, h), w, color)
	_beam(st, Vector3(-h, y, h), Vector3(h, y, h), w, color)
	if front:
		_beam(st, Vector3(-h, y, -h), Vector3(h, y, -h), w, color)


## A squared timber from a to b, w thick.
static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, color: Color) -> void:
	var d := b - a
	MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y(d.normalized()), (a + b) * 0.5), Vector3(w, d.length() + w * 0.5, w), color)


func interact_prompt() -> String:
	var bm := BuildManager.instance
	var damaged := 0
	for t in bm.turrets_on(cliff_id, cell):
		if t.needs_repair():
			damaged += 1
	var text := "Scaffold: %d storey%s, %d turret%s in it" % [levels, "" if levels == 1 else "s",
			bm.turrets_on(cliff_id, cell).size(), "" if bm.turrets_on(cliff_id, cell).size() == 1 else "s"]
	if damaged > 0:
		text += "\nHold E: repair its turrets (%d damaged)" % damaged
	if levels < BuildManager.MAX_SCAFFOLD:
		text += "\nBuild another scaffold here to add a storey"
	return text


func local_interact(_holding: bool) -> void:
	BuildManager.instance.repair_node(self)
