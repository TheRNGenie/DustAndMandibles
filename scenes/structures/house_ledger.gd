class_name HouseLedger
extends StaticBody3D
## A desk with an open ledger inside the Homestead. E opens the house upgrades.

signal menu_changed

const ICONS: Dictionary = {&"patch": &"hammer", &"board": &"planks", &"reinforce": &"shield", &"floor2": &"house", &"floor3": &"house"}

var home: Homestead


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	rotation.y = -PI * 0.5 # faces into the room
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(1.2, 0.08, 0.7), Palette.WOOD)
	for lx: float in [-0.52, 0.52]:
		for lz: float in [-0.28, 0.28]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(lx, 0.42, lz)), Vector3(0.08, 0.84, 0.08), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.08), Vector3(-0.17, 0.92, 0)), Vector3(0.34, 0.03, 0.46), Palette.BONE)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -0.08), Vector3(0.17, 0.92, 0)), Vector3(0.34, 0.03, 0.46), Palette.BONE)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.9, 0)), Vector3(0.7, 0.02, 0.5), Palette.TEAM_WEST.darkened(0.3))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0.45, 1.0, -0.2)), 0.04, 0.04, 0.22, 6, Palette.BONE)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.45, 1.14, -0.2)), Vector3(0.04, 0.06, 0.04), Palette.GLOW_YELLOW, 0.0, null, 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.015)
	add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.0, 0.7)
	col.shape = shape
	col.position.y = 0.5
	add_child(col)
	GameState.homestead_changed.connect(func(_c: int, _h: float, _m: float) -> void: menu_changed.emit())


func interact_prompt() -> String:
	return "E: open the homestead ledger"


func local_interact(holding: bool) -> void:
	if not holding and MenuScreen.instance != null:
		MenuScreen.instance.open(self)


func menu_title() -> String:
	return "Homestead Ledger"


func menu_tagline() -> String:
	var cid := home.cliff_id
	return "House: %d / %d HP   |   %d floor%s, %s, %s" % [int(GameState.homestead_hp[cid]), int(GameState.homestead_max[cid]),
			home.floors, "" if home.floors == 1 else "s", "boarded up" if home.boarded else "windows open",
			"reinforced" if home.reinforced else "plain walls"]


func menu_items(_tab: int) -> Array:
	var cid := home.cliff_id
	var out: Array = []
	for i in Homestead.UPGRADES.size():
		var u: Dictionary = Homestead.UPGRADES[i]
		var why := home.can_offer(u["id"])
		out.append({"id": i, "name": u["name"], "icon": ICONS.get(u["id"], &"house"), "desc": u["desc"],
				"price": Homestead.cost_text(u["cost"]), "price_ok": Economy.can_afford(cid, u["cost"]),
				"disabled": why, "buttons": [[&"buy", "Buy"]]})
	return out


func menu_press(id: Variant, _action: StringName) -> void:
	if multiplayer.is_server():
		home.buy(multiplayer.get_unique_id(), int(id))
	else:
		_request_buy.rpc_id(1, int(id))


func notify_changed() -> void:
	menu_changed.emit()


@rpc("any_peer", "reliable")
func _request_buy(index: int) -> void:
	if multiplayer.is_server():
		home.buy(multiplayer.get_remote_sender_id(), index)
