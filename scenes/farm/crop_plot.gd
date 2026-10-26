class_name CropPlot
extends StaticBody3D
## A tilled plot. Build more from the build menu (Farm plot). On an empty plot,
## F picks the seed and E plants it; E again waters it (1 water from your
## stockpile); the crop grows while watered, then E harvests into the stockpile.
## Host-authoritative; state changes are broadcast to everyone.
## Crop Weevils eat whatever is growing here.

const SYNC_INTERVAL := 2.0
## Plot size in metres (plants scale with it).
const SIZE := 3.4 # fills a 2 x 2 block of grid cells with a little gap
const PLANT_SCALE := 1.45
## Seed order for F (cycle) on an empty plot.
const SEEDS: Array[StringName] = [&"corn", &"prickly_pear", &"firecracker_chili", &"herbs"]

## The seed resource each crop needs (bought from the Oasis vendor for scrap).
const SEED_RES: Dictionary = {&"corn": &"seed_corn", &"prickly_pear": &"seed_prickly_pear",
	&"firecracker_chili": &"seed_chili", &"herbs": &"seed_herbs"}

## The seed this player has picked for empty plots (local, shared by all plots).
static var selected_seed := 0

var cliff_id: int = 0
var crop_def: CropDef
var radius: float = 0.9
var cell: Vector2i = Vector2i(-1, -1)
var build_id: StringName = &"farm_plot"
var growth := CropGrowth.new()
var _plant_mi: MeshInstance3D
var _fruit_mi: MeshInstance3D
var _sign: MeshInstance3D
var _sign_mat: StandardMaterial3D
var _sync_t := 0.0


func setup(cid: int) -> void:
	cliff_id = cid
	collision_layer = WorldLayout.LAYER_WORLD
	var soil := MeshInstance3D.new()
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(SIZE, 0.18, SIZE), Palette.DIRT_DARK)
	for i in 3:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.8 + i * 0.8, 0.19, 0)), Vector3(0.45, 0.07, SIZE - 0.3), Palette.DIRT_DARK.darkened(0.2))
	# Low wooden border.
	for side: float in [-1.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(side * SIZE * 0.5, 0.12, 0)), Vector3(0.08, 0.24, SIZE), Palette.WOOD)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.12, side * SIZE * 0.5)), Vector3(SIZE, 0.24, 0.08), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(SIZE * 0.5 + 0.1, 0.45, SIZE * 0.5 - 0.2)), Vector3(0.06, 0.7, 0.06), Palette.WOOD)
	soil.mesh = MeshKit.finish(st)
	soil.material_override = Materials.toon(0.02)
	add_child(soil)
	# Little sign showing what's planted (its colour changes with the crop).
	_sign = MeshInstance3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(0.05, 0.25, 0.4)
	_sign.mesh = board
	_sign_mat = StandardMaterial3D.new()
	_sign_mat.albedo_color = Palette.BONE
	_sign.material_override = _sign_mat
	_sign.position = Vector3(SIZE * 0.5 + 0.1, 0.8, SIZE * 0.5 - 0.2)
	add_child(_sign)
	_plant_mi = MeshInstance3D.new()
	_plant_mi.mesh = _plant_mesh()
	_plant_mi.material_override = Materials.toon(0.015)
	_plant_mi.position.y = 0.2
	_plant_mi.set_meta("base_scale", PLANT_SCALE)
	add_child(_plant_mi)
	_fruit_mi = MeshInstance3D.new()
	_fruit_mi.material_override = Materials.toon(0.015)
	_fruit_mi.position.y = 0.2
	_fruit_mi.scale = Vector3.ONE * PLANT_SCALE
	add_child(_fruit_mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(SIZE, 0.3, SIZE)
	col.shape = shape
	col.position.y = 0.15
	add_child(col)
	add_to_group("crops")
	_refresh_visual()


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var before := growth.stage
	growth.tick(delta * GameState.growth_scale())
	_sync_t -= delta
	if growth.stage != before or (growth.stage == CropGrowth.Stage.GROWING and _sync_t <= 0.0):
		_sync_t = SYNC_INTERVAL
		_broadcast()


func has_crop() -> bool:
	return growth.stage != CropGrowth.Stage.EMPTY


static func seed_def() -> CropDef:
	return Defs.crop(SEEDS[selected_seed % SEEDS.size()])


func cycle_option() -> void:
	if growth.stage == CropGrowth.Stage.EMPTY:
		selected_seed = (selected_seed + 1) % SEEDS.size()


func interact_prompt() -> String:
	if growth.stage == CropGrowth.Stage.EMPTY:
		var have := Economy.amount(_local_cliff(), SEED_RES[seed_def().id])
		return "E: plant %s (%d seeds left)   F: change seed\nBuy more seeds at the Oasis vendor" % [seed_def().display_name, have]
	var n := crop_def.display_name
	match growth.stage:
		CropGrowth.Stage.PLANTED:
			return "%s seedling - E: water it (%d water)" % [n, crop_def.water_cost]
		CropGrowth.Stage.GROWING:
			return "%s growing: %d%%" % [n, int(growth.fraction() * 100.0)]
		_:
			return "E: harvest %s" % n


func local_interact(_holding: bool) -> void:
	var seed_id := SEEDS[selected_seed % SEEDS.size()]
	if multiplayer.is_server():
		_use(multiplayer.get_unique_id(), seed_id)
	else:
		_request_use.rpc_id(1, seed_id)


@rpc("any_peer", "reliable")
func _request_use(seed_id: StringName) -> void:
	if multiplayer.is_server():
		_use(multiplayer.get_remote_sender_id(), seed_id)


func _use(peer_id: int, seed_id: StringName) -> void:
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	match growth.stage:
		CropGrowth.Stage.EMPTY:
			var def := Defs.crop(seed_id)
			if def == null:
				return
			if not Economy.spend(payer, {SEED_RES[seed_id]: 1}):
				Economy.notify(peer_id, "No %s seeds. Buy them at the Oasis vendor for scrap." % def.display_name.to_lower())
				return
			crop_def = def
			growth.plant(def)
		CropGrowth.Stage.PLANTED:
			if Economy.spend(payer, {&"water": crop_def.water_cost}):
				growth.water()
				_fx.rpc(&"pluck")
			else:
				Economy.notify(peer_id, "No water left. Fix the well or build a rain catcher.")
		CropGrowth.Stage.RIPE:
			Economy.earn(payer, growth.harvest())
			_fx.rpc(&"coin")
	_broadcast()


## Host: a Crop Weevil ate the crop.
func eaten() -> void:
	if multiplayer.is_server() and has_crop():
		growth.clear()
		_broadcast()


func _local_cliff() -> int:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority():
			return (n as Player).cliff_id if not GameState.is_solo() else cliff_id
	return cliff_id


func _broadcast() -> void:
	var cid: StringName = crop_def.id if crop_def != null else &""
	_sync.rpc(cid, growth.stage, growth.progress, growth.watered)


@rpc("authority", "call_local", "reliable")
func _sync(crop_id: StringName, stage: int, progress: float, watered: bool) -> void:
	if crop_id != &"" and (crop_def == null or crop_def.id != crop_id):
		crop_def = Defs.crop(crop_id)
		_fruit_mi.mesh = _fruit_mesh(crop_def.color)
	growth.crop = crop_def
	growth.stage = stage as CropGrowth.Stage
	growth.progress = progress
	growth.watered = watered
	_refresh_visual()


@rpc("authority", "call_local", "unreliable")
func _fx(sound: StringName) -> void:
	Audio.play_at(sound, global_position)


func _refresh_visual() -> void:
	var empty := growth.stage == CropGrowth.Stage.EMPTY
	var f := 0.0 if empty else growth.fraction()
	_plant_mi.visible = not empty
	_plant_mi.scale = Vector3.ONE * lerpf(0.25, 1.0, f) * PLANT_SCALE
	_fruit_mi.visible = growth.stage == CropGrowth.Stage.RIPE
	_sign_mat.albedo_color = Palette.BONE if empty or crop_def == null else crop_def.color


static func _plant_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	for i in 3:
		var x := -0.55 + i * 0.55
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(x, 0.4, 0)), 0.05, 0.03, 0.8, 5, Palette.CACTUS)
		for side: float in [-1.0, 1.0]:
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.BACK, side * 0.6), Vector3(x + side * 0.12, 0.45, 0)), Vector3(0.14, 0.04, 0.08), 3, 6, Palette.CACTUS_DARK)
	return MeshKit.finish(st)


static func _fruit_mesh(color: Color) -> ArrayMesh:
	var st := MeshKit.begin()
	for i in 3:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.55 + i * 0.55, 0.75, 0.05)), Vector3(0.1, 0.16, 0.1), 4, 6, color, 0.0, null, 0.25)
	return MeshKit.finish(st)
