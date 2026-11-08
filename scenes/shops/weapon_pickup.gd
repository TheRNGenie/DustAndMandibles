class_name WeaponPickup
extends StaticBody3D
## A weapon lying on the ground, slowly spinning. E picks it up (keeps its upgrades).

var weapon_id: StringName = &""
## Set instead of weapon_id for a dropped crop / medicine / water.
var item_id: StringName = &""
var level: int = 0
## A universal heavy's [crop, shots] as it was dropped (HeavyAmmo; empty otherwise).
var heavy_load: Array = []
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


## A dropped universal heavy keeps its crop: its ring glows with it on the ground.
func set_heavy_load(l: Array) -> void:
	heavy_load = l
	if _mi != null and _mi.get_child_count() > 0 and UniHeavies.has(weapon_id):
		UniHeavies.show_trim(_mi.get_child(0), WeaponMods.level(level)) # its upgrade trim
		if l.size() < 2 or int(l[1]) <= 0:
			UniHeavies.tint(_mi.get_child(0), &"") # empty: a dark ring
	if l.size() >= 2 and int(l[1]) > 0 and _mi != null and _mi.get_child_count() > 0:
		UniHeavies.tint(_mi.get_child(0), StringName(l[0]))


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
	if w.crop_ammo:
		var loaded := heavy_load.size() >= 2 and int(heavy_load[1]) > 0
		return "E: pick up %s (%s)" % [w.display_name, ("%d %s shots" % [int(heavy_load[1]), CropEffects.short_name(StringName(heavy_load[0])).to_lower()]) if loaded else "empty"]
	return "E: pick up %s%s" % [w.display_name, (" (level %d)" % WeaponMods.level(level)) if WeaponMods.level(level) > 0 else ""] # the code also holds mods and the Dino glass


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
