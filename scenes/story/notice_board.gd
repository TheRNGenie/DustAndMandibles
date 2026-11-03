class_name NoticeBoard
extends StaticBody3D
## Story: a little roofed noticeboard on the house's right-hand wall, with the
## chapter's telegram pinned to it. E reads it (TelegramView). It's also where
## The Survey Map's gland is mailed from (group "story_boards"). Local only.

## House space: outside the right side wall, clear of the window and the deposit box.
const SPOT := Vector3(HouseBuilder.W * 0.5 + HouseBuilder.T * 0.5 + 0.1, 0.0, -1.75)
const BOARD := Vector2(1.15, 0.95)

var director: StoryDirector


func _ready() -> void:
	add_to_group("story_boards")
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	position = SPOT
	rotation.y = PI * 0.5 # faces out of the wall (+x)
	var mi := MeshInstance3D.new()
	mi.mesh = board_mesh()
	mi.material_override = Materials.toon(0.015)
	add_child(mi)
	# The telegram, a little crooked, with a red pin.
	var paper := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.78, 0.6)
	paper.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = TelegramView.paper_texture(self, director.chapter if director != null else null)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	paper.material_override = m
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paper.position = Vector3(0.0, 1.72, 0.07)
	paper.rotation.z = deg_to_rad(-2.5)
	add_child(paper)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BOARD.x, BOARD.y, 0.25)
	col.shape = shape
	col.position = Vector3(0, 1.7, 0.05)
	add_child(col)


func interact_prompt() -> String:
	return "Noticeboard: a telegram from the Lucky Mandible\nE: read it"


func local_interact(holding: bool) -> void:
	if not holding and director != null and director.telegram != null:
		director.telegram.open()


static func board_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1889
	var y := 1.7
	# Backing planks and a frame.
	for k in 4:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y - 0.36 + k * 0.24, 0)), Vector3(BOARD.x - 0.08, 0.22, 0.05),
				Palette.WOOD.lightened(rng.randf() * 0.12), 0.01, rng)
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * BOARD.x * 0.5, y, 0.03)), Vector3(0.08, BOARD.y + 0.08, 0.08), Palette.WOOD_DARK)
	for sy: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y + sy * BOARD.y * 0.5, 0.03)), Vector3(BOARD.x + 0.08, 0.08, 0.08), Palette.WOOD_DARK)
	# A little shingle roof over it.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, y + BOARD.y * 0.5 + 0.12, 0.12)), Vector3(BOARD.x + 0.3, 0.05, 0.42), Palette.ROOF)
	# A painted header strip: "NOTICES".
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y + BOARD.y * 0.5 - 0.08, 0.06)), Vector3(BOARD.x - 0.2, 0.1, 0.01), Palette.BONE)
	# Pin.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.0, y + 0.345, 0.1)), Vector3.ONE * 0.03, 4, 6, Color("#C0392B"))
	# Old scraps of paper pinned round the edges.
	for k in 3:
		var at := Vector3(rng.randf_range(-0.45, 0.45), y + rng.randf_range(-0.38, -0.3), 0.04)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.2, 0.2)), at), Vector3(0.18, 0.12, 0.005), Color("#E9D6A8").darkened(0.1 + rng.randf() * 0.1))
	return MeshKit.finish(st)
