class_name WeaponPickup
extends StaticBody3D
## A weapon lying on the ground, slowly spinning. E picks it up (keeps its upgrades).

var weapon_id: StringName = &""
## Set instead of weapon_id for a dropped crop / medicine / water.
var item_id: StringName = &""
var level: int = 0
var _mi: MeshInstance3D
var _t := 0.0


func setup(id: StringName, lvl: int, pos: Vector3) -> void:
	weapon_id = id
	level = lvl
	position = pos
	collision_layer = WorldLayout.LAYER_TRAP
	collision_mask = 0
	_mi = MeshInstance3D.new()
	var model := GunModels.whole(id, 0.01)
	if model != null:
		_mi.add_child(model)
	else:
		_mi.mesh = WeaponBuilder.gun(id)
	_mi.material_override = Materials.toon(0.01)
	_mi.scale = Vector3.ONE * 2.2
	add_child(_mi)
	var glow := OmniLight3D.new()
	glow.light_color = Palette.GLOW_YELLOW
	glow.light_energy = 0.8
	glow.omni_range = 2.0
	add_child(glow)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	add_child(col)


func setup_item(item: StringName, pos: Vector3) -> void:
	item_id = item
	position = pos
	collision_layer = WorldLayout.LAYER_TRAP
	collision_mask = 0
	_mi = MeshInstance3D.new()
	var model := GunModels.make({&"water": &"bucket"}.get(item, &"_"), "body", 0.0, true)
	if model != null:
		_mi.add_child(model)
	else:
		_mi.mesh = WeaponBuilder.held_item(item)
	_mi.material_override = Materials.toon(0.01)
	_mi.scale = Vector3.ONE * 1.8
	add_child(_mi)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	add_child(col)


func _process(delta: float) -> void:
	_t += delta
	_mi.rotation.y = _t * 1.5
	_mi.position.y = sin(_t * 2.0) * 0.08


func interact_prompt() -> String:
	if item_id != &"":
		return "E: pick up %s" % String(Hotbar.NAMES.get(item_id, String(item_id))).to_lower()
	var w := Gun.weapon(weapon_id)
	return "E: pick up %s%s" % [w.display_name, (" (level %d)" % level) if level > 0 else ""]


func local_interact(holding: bool) -> void:
	if holding:
		return
	if multiplayer.is_server():
		PickupManager.instance.try_pick_up(multiplayer.get_unique_id(), self)
	else:
		_request_pick_up.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_pick_up() -> void:
	if multiplayer.is_server():
		PickupManager.instance.try_pick_up(multiplayer.get_remote_sender_id(), self)
