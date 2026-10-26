class_name CropPlot
extends StaticBody3D
## One tilled plot in a Homestead's crop field. E plants, E again waters (1 water
## from your stockpile), the crop grows while watered, then E harvests into the
## stockpile. Host-authoritative; state changes are broadcast to everyone.
## Crop Weevils eat whatever is growing here.

const SYNC_INTERVAL := 2.0

var cliff_id: int = 0
var crop_def: CropDef
var radius: float = 0.9
var growth := CropGrowth.new()
var _plant_mi: MeshInstance3D
var _fruit_mi: MeshInstance3D
var _sync_t := 0.0


func setup(cid: int, def: CropDef) -> void:
	cliff_id = cid
	crop_def = def
	collision_layer = WorldLayout.LAYER_WORLD
	var soil := MeshInstance3D.new()
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(1.7, 0.18, 1.7), Palette.DIRT_DARK)
	for i in 3:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.55 + i * 0.55, 0.19, 0)), Vector3(0.3, 0.06, 1.5), Palette.DIRT_DARK.darkened(0.2))
	# Little sign in the crop's colour so you can tell the rows apart.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.95, 0.45, 0.7)), Vector3(0.06, 0.7, 0.06), Palette.WOOD)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.95, 0.8, 0.7)), Vector3(0.05, 0.25, 0.4), def.color)
	soil.mesh = MeshKit.finish(st)
	soil.material_override = Materials.toon(0.02)
	add_child(soil)
	_plant_mi = MeshInstance3D.new()
	_plant_mi.mesh = _plant_mesh()
	_plant_mi.material_override = Materials.toon(0.015)
	_plant_mi.position.y = 0.2
	add_child(_plant_mi)
	_fruit_mi = MeshInstance3D.new()
	_fruit_mi.mesh = _fruit_mesh(def.color)
	_fruit_mi.material_override = Materials.toon(0.015)
	_fruit_mi.position.y = 0.2
	add_child(_fruit_mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 0.3, 1.7)
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


func interact_prompt() -> String:
	var n := crop_def.display_name
	match growth.stage:
		CropGrowth.Stage.EMPTY:
			return "E: plant %s" % n
		CropGrowth.Stage.PLANTED:
			return "%s seedling - E: water it (%d water)" % [n, crop_def.water_cost]
		CropGrowth.Stage.GROWING:
			return "%s growing: %d%%" % [n, int(growth.fraction() * 100.0)]
		_:
			return "E: harvest %s" % n


func local_interact(_holding: bool) -> void:
	if multiplayer.is_server():
		_use(multiplayer.get_unique_id())
	else:
		_request_use.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_use() -> void:
	if multiplayer.is_server():
		_use(multiplayer.get_remote_sender_id())


func _use(peer_id: int) -> void:
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	match growth.stage:
		CropGrowth.Stage.EMPTY:
			growth.plant(crop_def)
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


func _broadcast() -> void:
	_sync.rpc(growth.stage, growth.progress, growth.watered)


@rpc("authority", "call_local", "reliable")
func _sync(stage: int, progress: float, watered: bool) -> void:
	if growth.crop == null:
		growth.crop = crop_def
	growth.stage = stage as CropGrowth.Stage
	growth.progress = progress
	growth.watered = watered
	_refresh_visual()


@rpc("authority", "call_local", "unreliable")
func _fx(sound: StringName) -> void:
	Audio.play_at(sound, global_position)


func _refresh_visual() -> void:
	var f := growth.fraction() if growth.stage != CropGrowth.Stage.EMPTY else 0.0
	_plant_mi.visible = growth.stage != CropGrowth.Stage.EMPTY
	_plant_mi.scale = Vector3.ONE * lerpf(0.25, 1.0, f)
	_fruit_mi.visible = growth.stage == CropGrowth.Stage.RIPE


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
