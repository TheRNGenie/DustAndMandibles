class_name HouseLedger
extends StaticBody3D
## A desk with an open ledger inside the Homestead. F picks an upgrade, E buys it.

static var selected := 0

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
	# Open book and a candle.
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
	var sign := Label3D.new()
	sign.text = "HOMESTEAD LEDGER"
	sign.font_size = 28
	sign.outline_size = 8
	sign.modulate = Palette.GLOW_YELLOW
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.5, 0)
	sign.pixel_size = 0.004
	add_child(sign)


func cycle_option() -> void:
	selected = (selected + 1) % Homestead.UPGRADES.size()


func interact_prompt() -> String:
	var u: Dictionary = Homestead.UPGRADES[selected]
	var why := home.can_offer(u["id"])
	var head := "Ledger: %s - %s\n%s" % [u["name"], Homestead.cost_text(u["cost"]), u["desc"]]
	if why != "":
		return head + "\n(%s)   F: next upgrade" % why
	return head + "\nE: buy   F: next upgrade"


func local_interact(holding: bool) -> void:
	if holding:
		return
	if multiplayer.is_server():
		home.buy(multiplayer.get_unique_id(), selected)
	else:
		_request_buy.rpc_id(1, selected)


@rpc("any_peer", "reliable")
func _request_buy(index: int) -> void:
	if multiplayer.is_server():
		home.buy(multiplayer.get_remote_sender_id(), index)
