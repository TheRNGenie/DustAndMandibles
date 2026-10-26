class_name GunShop
extends StaticBody3D
## The gunsmith on each plateau: buy the lever-action rifle and coach shotgun, and
## upgrade any weapon (+25% damage and faster reloads per level), all for chitin.
## F picks an item, E buys it. The host checks and charges, then hands the weapon
## to the buyer's own Gun.

const SHELF: Array[Dictionary] = [
	{"kind": "buy", "id": &"lever_rifle"},
	{"kind": "buy", "id": &"coach_shotgun"},
	{"kind": "upgrade", "id": &"revolver"},
	{"kind": "upgrade", "id": &"lever_rifle"},
	{"kind": "upgrade", "id": &"coach_shotgun"},
]

## Host: what every peer owns, peer_id -> {weapon id: level}.
static var loadouts: Dictionary = {}

var cliff_id: int = 0
var _label: Label3D


func setup(cid: int) -> void:
	cliff_id = cid
	collision_layer = WorldLayout.LAYER_STRUCTURE
	var mi := MeshInstance3D.new()
	mi.mesh = ShopBuilder.gun_stall()
	mi.material_override = Materials.toon(0.025)
	add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.9, 1.8)
	col.shape = shape
	col.position = Vector3(0, 1.45, 0.05)
	add_child(col)
	var board := MeshInstance3D.new()
	board.mesh = ShopBuilder.sign_board()
	board.material_override = Materials.toon(0.02)
	board.position = Vector3(3.1, 0, -0.4)
	add_child(board)
	var keeper := Shopkeeper.new()
	keeper.position = Vector3(0.5, 0, 0.15)
	add_child(keeper)
	keeper.setup({"hat": "gambler", "facial": "walrus", "hair": "none", "hair_color": "grey", "outfit": "vest",
		"neck": "bolo", "extra": "bandolier", "paint": "white"}, Color("#4A4E58"))
	_label = ShopBuilder.sign_label()
	board.add_child(_label)
	var lines: PackedStringArray = ["GUNSMITH", "prices in chitin", ""]
	for w: StringName in [&"lever_rifle", &"coach_shotgun"]:
		lines.append("%s ... %d" % [Gun.weapon(w).display_name, Gun.weapon(w).price_chitin])
	lines.append("Upgrades ... 10, then 25")
	_label.text = "\n".join(lines)


static func reset_loadouts() -> void:
	loadouts.clear()


signal menu_changed


# ------------------------------------------------------------------ the menu screen

func interact_prompt() -> String:
	return "E: browse the gunsmith"


func local_interact(holding: bool) -> void:
	if not holding and MenuScreen.instance != null:
		MenuScreen.instance.open(self)


func menu_title() -> String:
	return "Gunsmith"


func menu_tagline() -> String:
	return "New irons and upgrades, paid in chitin. You can carry three guns; drop one with Q to make room."


func menu_tabs() -> Array:
	return ["Guns", "Upgrades"]


func menu_items(tab: int) -> Array:
	var gun := _local_gun()
	if gun == null:
		return []
	var chitin := Economy.amount(NetworkManager.cliff_of(multiplayer.get_unique_id()), &"chitin")
	var out: Array = []
	for item: Dictionary in SHELF:
		var id: StringName = item["id"]
		var w := Gun.weapon(id)
		if tab == 0 and item["kind"] == "buy":
			var why := ""
			if gun.owns(id):
				why = "Already in your holster."
			elif gun.owned.size() >= Gun.MAX_WEAPONS:
				why = "Your three weapon slots are full. Drop one first (Q)."
			out.append({"id": "buy:%s" % id, "name": w.display_name, "icon": id, "desc": w.description,
					"price": "%d chitin" % w.price_chitin, "price_ok": chitin >= w.price_chitin, "disabled": why,
					"buttons": [[&"buy", "Buy"]]})
		elif tab == 1 and item["kind"] == "upgrade":
			var level := gun.level_of(id)
			var maxed := level >= w.upgrade_costs.size()
			var why := ""
			if not gun.owns(id):
				why = "Buy it first."
			elif maxed:
				why = "Fully upgraded."
			var cost: int = 0 if maxed else int(w.upgrade_costs[level])
			out.append({"id": "upgrade:%s" % id, "name": "%s  (level %d)" % [w.display_name, level], "icon": id,
					"desc": "+25% damage and a faster reload per level.", "price": "" if maxed else "%d chitin" % cost,
					"price_ok": chitin >= cost, "disabled": why, "buttons": [[&"buy", "Upgrade"]]})
	return out


func menu_press(id: Variant, _action: StringName) -> void:
	var parts := str(id).split(":")
	if multiplayer.is_server():
		_buy(multiplayer.get_unique_id(), parts[0], StringName(parts[1]))
	else:
		_request_buy.rpc_id(1, parts[0], StringName(parts[1]))


@rpc("any_peer", "reliable")
func _request_buy(kind: String, id: StringName) -> void:
	if multiplayer.is_server():
		_buy(multiplayer.get_remote_sender_id(), kind, id)


func _buy(peer_id: int, kind: String, id: StringName) -> void:
	var w := Gun.weapon(id)
	if w == null:
		return
	if not loadouts.has(peer_id):
		loadouts[peer_id] = {&"revolver": 0}
	var owned: Dictionary = loadouts[peer_id]
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	var cost := 0
	var level := 0
	if kind == "buy":
		if owned.has(id):
			return
		if owned.size() >= Gun.MAX_WEAPONS:
			Economy.notify(peer_id, "Your three weapon slots are full. Drop one first (Q).")
			return
		cost = w.price_chitin
	else:
		if not owned.has(id) or int(owned[id]) >= w.upgrade_costs.size():
			return
		cost = w.upgrade_costs[int(owned[id])]
		level = int(owned[id]) + 1
	if not Economy.spend(payer, {&"chitin": cost}):
		Economy.notify(peer_id, "That costs %d chitin. Sell vegetables at the vendor or kill armoured bugs." % cost)
		return
	owned[id] = level
	var player := _player_of(peer_id)
	if player != null:
		player.net.grant_weapon(id, level)
	_sold.rpc()


@rpc("authority", "call_local", "unreliable")
func _sold() -> void:
	Audio.play_at(&"reload", global_position)
	menu_changed.emit()


func _player_of(peer_id: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id:
			return n as Player
	return null


func _local_gun() -> Gun:
	var p := _player_of(multiplayer.get_unique_id())
	return p.gun if p != null else null
