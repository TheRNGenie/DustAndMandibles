class_name CropWorkbench
extends StaticBody3D
## The ammo workbench in the root cellar (playtest fixes, Nov 2026): E opens its
## menu (AmmoBenchMenu), which turns the crops you carry (PlayerCarry) into
## turret ammo sacks for the cellar's bins, HarvestRules.SACKS_PER_CROP (3) a
## crop, as far as the bin has room. The host checks and makes the trade.
## A plank table with a burlap sack, a scoop and a twine spool on it.

signal changed

var cellar: RootCellar


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh()
	mi.material_override = Materials.toon_house(0.015)
	add_child(mi)
	var sack := MeshInstance3D.new()
	sack.mesh = AmmoSackBuilder.sack(&"")
	sack.material_override = Materials.toon(0.008)
	sack.scale = Vector3.ONE * 0.55
	sack.position = Vector3(0.35, 0.86, 0.05)
	sack.rotation.y = -0.4
	add_child(sack)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 0.9, 0.7)
	col.shape = box
	col.position = Vector3(0, 0.45, 0)
	add_child(col)
	Economy.resources_changed.connect(func(_c: int) -> void: changed.emit())


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority() and not bool(n.get("bot")):
			return n as Player
	return null


func interact_prompt() -> String:
	return "E: Ammo workbench (turn the crops you carry into turret sacks, %d a crop)" % HarvestRules.SACKS_PER_CROP


func local_interact(holding: bool) -> void:
	if holding or MenuScreen.instance == null:
		return
	var p := _local_player()
	if p != null and p.carry != null and not p.carry.changed.is_connected(_on_carry):
		p.carry.changed.connect(_on_carry)
	MenuScreen.instance.open(AmmoBenchMenu.new(self))


func _on_carry() -> void:
	changed.emit()


# ------------------------------------------------------------------ AmmoBenchMenu's calls

func cliff_id() -> int:
	return cellar.home.cliff_id if cellar != null and cellar.home != null else 0


## Crops of kind `c` you carry.
func raw_of(c: StringName) -> int:
	var p := _local_player()
	return p.carry.amount(c) if p != null and p.carry != null else 0


## Sacks of `c` in this cellar's bin.
func sacks_of(c: StringName) -> int:
	var crop := Defs.crop(c)
	return Economy.amount(cliff_id(), crop.load_item) if crop != null and crop.load_item != &"" else 0


func sack_cap() -> int:
	return AmmoStore.cap(cliff_id())


## Turn `n` of the crops you carry into sacks (the host checks).
func request_convert(c: StringName, n: int) -> void:
	if multiplayer.is_server():
		_host_convert(multiplayer.get_unique_id(), c, n)
	else:
		_request_convert.rpc_id(1, c, n)


@rpc("any_peer", "reliable")
func _request_convert(c: StringName, n: int) -> void:
	if multiplayer.is_server():
		_host_convert(multiplayer.get_remote_sender_id(), c, n)


## Host: as many of the `n` crops as you carry and the bin has room for become
## sacks, SACKS_PER_CROP each.
func _host_convert(peer_id: int, c: StringName, n: int) -> void:
	if cellar != null and not cellar.may_use(peer_id):
		return
	var crop := Defs.crop(c)
	var carry := PlayerCarry.of(get_tree(), peer_id)
	if crop == null or crop.load_item == &"" or carry == null:
		return
	var k := HarvestRules.convertible(n, carry.amount(c), AmmoStore.room(cliff_id(), crop.load_item))
	if k <= 0:
		Economy.notify(peer_id, "The %s bin is full." % crop.display_name.to_lower() if carry.amount(c) > 0
				else "You aren't carrying any %s." % crop.display_name.to_lower())
		return
	if not carry.take(c, k):
		return
	Economy.earn(cliff_id(), {crop.load_item: k * HarvestRules.SACKS_PER_CROP})
	Economy.notify(peer_id, "+%d %s ammo sacks (%d in the bin)." % [k * HarvestRules.SACKS_PER_CROP, crop.display_name.to_lower(),
			Economy.amount(cliff_id(), crop.load_item)])
	_worked.rpc()


@rpc("authority", "call_local", "reliable")
func _worked() -> void:
	Audio.play_at(&"rustle", global_position + Vector3.UP, -2.0, 0.9)


## A sturdy plank table: thick top, four legs, a stretcher, a scoop and a twine spool.
static func _mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DARK
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.84, 0)), Vector3(1.45, 0.07, 0.66), wood)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.64, 0.4, sz * 0.26)), Vector3(0.08, 0.8, 0.08), dark)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.64, 0.18, 0)), Vector3(0.06, 0.06, 0.52), dark)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.18, 0)), Vector3(1.28, 0.06, 0.06), dark)
	# A tin scoop and a twine spool.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.5), Vector3(-0.3, 0.91, 0.1)), Vector3(0.22, 0.06, 0.14), Color("#9A9AA0"))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.5), Vector3(-0.47, 0.9, 0.2)), Vector3(0.14, 0.03, 0.04), dark)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.05, 0.92, -0.18)), 0.06, 0.06, 0.1, 10, AmmoSackBuilder.TWINE)
	return MeshKit.finish(st)
