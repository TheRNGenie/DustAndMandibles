class_name StorageChest
extends StaticBody3D
## A steamer trunk in each house. E opens it: stash weapons and anything from
## hotbar slots 4-8 (corn, prickly pears, chilies, medicine, water) to free up
## your pockets, and take them back out later. Host-authoritative; every peer
## keeps a synced copy of the contents for the menu.

signal menu_changed

const ITEMS: Array[StringName] = [&"corn", &"prickly_pear", &"chili", &"herbs", &"water", &"sarsaparilla"]
const NAMES: Dictionary = {&"corn": "Corn", &"prickly_pear": "Prickly Pear", &"chili": "Firecracker Chili",
	&"herbs": "Medicine (sage)", &"water": "Water", &"sarsaparilla": "Sarsaparilla Root"}
const MAX_WEAPONS := 6

var home: Homestead
## Stored stacks: item -> count.
var items: Dictionary = {}
## Stored weapons: weapon id -> upgrade level.
var weapons: Dictionary = {}
var _lid: Node3D
var _lid_open := 0.0
var _peek := 0.0


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var mat := Materials.toon(0.015)
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh()
	body.material_override = mat
	add_child(body)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.55, 0.3)
	add_child(_lid)
	var lid := MeshInstance3D.new()
	lid.mesh = _lid_mesh()
	lid.material_override = mat
	_lid.add_child(lid)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 0.75, 0.62)
	col.shape = shape
	col.position.y = 0.37
	add_child(col)


func _process(delta: float) -> void:
	# The lid creaks open while someone has the chest's menu up.
	_peek = maxf(_peek - delta, 0.0)
	var open := MenuScreen.instance != null and MenuScreen.instance.visible and MenuScreen.instance.provider == self
	_lid_open = move_toward(_lid_open, 1.0 if open or _peek > 0.0 else 0.0, delta * 3.0)
	var e := _lid_open * _lid_open * (3.0 - 2.0 * _lid_open)
	_lid.rotation.x = -e * 1.6


static func _body_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.28, 0)), Vector3(1.05, 0.55, 0.58), Palette.WOOD, 0.01, rng)
	for x: float in [-0.35, 0.35]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.28, 0)), Vector3(0.08, 0.57, 0.6), Palette.WOOD_DARK)
	for y: float in [0.05, 0.5]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(1.07, 0.05, 0.6), Palette.METAL.darkened(0.2))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx * 0.5, 0.28, sz * 0.27)), Vector3(0.08, 0.58, 0.08), Color("#D6A74A").darkened(0.2))
		# Rope handles on the ends.
		MeshKit.add_limb(st, Vector3(sx * 0.53, 0.32, -0.12), Vector3(sx * 0.57, 0.26, 0.0), 0.015, Color("#B8955A"), 4)
		MeshKit.add_limb(st, Vector3(sx * 0.57, 0.26, 0.0), Vector3(sx * 0.53, 0.32, 0.12), 0.015, Color("#B8955A"), 4)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.46, -0.3)), Vector3(0.12, 0.14, 0.03), Color("#D6A74A"))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.44, -0.32)), Vector3(0.02, 0.03, 0.01), 3, 6, Palette.OUTLINE)
	return MeshKit.finish(st)


## Lid in hinge space (hinge along the back top edge, lid extends toward -Z).
static func _lid_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.08, -0.3)), Vector3(1.07, 0.16, 0.6), Palette.WOOD.lightened(0.05))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.17, -0.3)), Vector3(1.0, 0.04, 0.55), Palette.WOOD_DARK)
	for x: float in [-0.35, 0.35]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.09, -0.3)), Vector3(0.08, 0.18, 0.62), Palette.WOOD_DARK)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.02, -0.6)), Vector3(0.1, 0.1, 0.03), Color("#D6A74A"))
	return MeshKit.finish(st)


# ------------------------------------------------------------------ menu

func interact_prompt() -> String:
	return "E: open the storage chest"


func local_interact(holding: bool) -> void:
	if not holding and MenuScreen.instance != null:
		MenuScreen.instance.open(self)


func menu_title() -> String:
	return "Storage Chest"


func menu_tagline() -> String:
	return "Stash weapons and anything from slots 4-8 here. %d of %d weapon spots used." % [weapons.size(), MAX_WEAPONS]


func menu_tabs() -> Array:
	return ["Store", "Take Out"]


func _player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority():
			return n as Player
	return null


func menu_items(tab: int) -> Array:
	var out: Array = []
	var p := _player()
	if p == null:
		return out
	var cid := p.cliff_id
	if tab == 0:
		for id: StringName in p.gun.slots:
			if id == &"":
				continue
			var lvl := p.gun.level_of(id)
			var fitted := WeaponMods.names(id, p.gun.code_of(id))
			out.append({"id": "w:" + String(id), "name": Gun.weapon(id).display_name + (" +%d" % lvl if lvl > 0 else ""), "icon": id,
					"desc": "In your weapon slots." + (" Mods: %s." % fitted if fitted != "" else ""), "price": "", "price_ok": true,
					"disabled": "" if weapons.size() < MAX_WEAPONS else "The chest's weapon rack is full.",
					"buttons": [[&"store", "Store"]]})
		for item: StringName in ITEMS:
			var have := Economy.amount(cid, item)
			out.append({"id": "i:" + String(item), "name": NAMES[item], "icon": item, "desc": "You carry %d." % have,
					"price": "", "price_ok": true, "disabled": "" if have > 0 else "You aren't carrying any.",
					"buttons": [[&"store1", "Store 1"], [&"storeall", "Store all"]]})
	else:
		for id: StringName in weapons:
			var lvl := WeaponMods.level(int(weapons[id]))
			var fitted := WeaponMods.names(id, int(weapons[id]))
			out.append({"id": "w:" + String(id), "name": Gun.weapon(id).display_name + (" +%d" % lvl if lvl > 0 else ""), "icon": id,
					"desc": "Stored in the chest." + (" Mods: %s." % fitted if fitted != "" else ""), "price": "", "price_ok": true, "disabled": "",
					"buttons": [[&"take", "Take"]]})
		for item: StringName in ITEMS:
			var n := int(items.get(item, 0))
			if n <= 0:
				continue
			out.append({"id": "i:" + String(item), "name": NAMES[item], "icon": item, "desc": "%d in the chest." % n,
					"price": "", "price_ok": true, "disabled": "", "buttons": [[&"take1", "Take 1"], [&"takeall", "Take all"]]})
		if out.is_empty():
			out.append({"id": "", "name": "The chest is empty", "icon": &"planks", "desc": "Store something from the other tab.",
					"price": "", "price_ok": true, "disabled": "Nothing stored yet.", "buttons": []})
	return out


func menu_press(id: Variant, action: StringName) -> void:
	var key := str(id)
	if key == "":
		return
	var p := _player()
	if p == null:
		return
	_peek = 0.8
	var kind := key.substr(0, 1)
	var what := StringName(key.substr(2))
	if kind == "w" and action == &"store":
		# Take it out of your hands here, then let the host file it.
		var level := p.gun.code_of(what)
		p.gun.remove_weapon(what)
		_send(&"store_weapon", what, level)
	elif kind == "w" and action == &"take":
		_send(&"take_weapon", what, 0)
	elif kind == "i":
		var n := 1
		if action == &"storeall":
			n = maxi(Economy.amount(p.cliff_id, what), 1)
		elif action == &"takeall":
			n = maxi(int(items.get(what, 0)), 1)
		_send(&"store_item" if action.begins_with("store") else &"take_item", what, n)


func _send(op: StringName, what: StringName, n: int) -> void:
	if multiplayer.is_server():
		_host(multiplayer.get_unique_id(), op, what, n)
	else:
		_request.rpc_id(1, op, what, n)


@rpc("any_peer", "reliable")
func _request(op: StringName, what: StringName, n: int) -> void:
	if multiplayer.is_server():
		_host(multiplayer.get_remote_sender_id(), op, what, n)


## Host: apply one chest action for `peer_id`.
func _host(peer_id: int, op: StringName, what: StringName, n: int) -> void:
	# The shared deposit box holds crops and supplies only, never weapons.
	if (op == &"store_weapon" or op == &"take_weapon") and self is DepositBox:
		return
	var cid := Economy.payer_cliff(peer_id, home.cliff_id)
	if not GunShop.loadouts.has(peer_id):
		GunShop.loadouts[peer_id] = {&"revolver": 0}
	var owned: Dictionary = GunShop.loadouts[peer_id]
	match op:
		&"store_weapon":
			if owned.has(what):
				owned.erase(what)
			weapons[what] = n
		&"take_weapon":
			if not weapons.has(what):
				return
			if owned.has(what):
				Economy.notify(peer_id, "You already carry a %s." % Gun.weapon(what).display_name)
				return
			if owned.size() >= Gun.MAX_WEAPONS:
				Economy.notify(peer_id, "Your three weapon slots are full. Store or drop one first.")
				return
			var level := int(weapons[what])
			weapons.erase(what)
			owned[what] = level
			if peer_id == multiplayer.get_unique_id():
				_give_weapon(what, level)
			else:
				_give_weapon.rpc_id(peer_id, what, level)
		&"store_item":
			n = mini(n, Economy.amount(cid, what))
			if n <= 0 or not Economy.spend(cid, {what: n}):
				return
			items[what] = int(items.get(what, 0)) + n
		&"take_item":
			n = mini(n, int(items.get(what, 0)))
			if n <= 0:
				return
			items[what] = int(items[what]) - n
			Economy.earn(cid, {what: n})
	_sync.rpc(items, weapons)


@rpc("authority", "reliable")
func _give_weapon(id: StringName, level: int) -> void:
	var p := _player()
	if p != null:
		p.gun.grant(id, level)
		p.gun.equip(id)


@rpc("authority", "call_local", "reliable")
func _sync(new_items: Dictionary, new_weapons: Dictionary) -> void:
	items = new_items
	weapons = new_weapons
	_peek = 0.8
	Audio.play_at(&"equip", global_position, -8.0)
	menu_changed.emit()
