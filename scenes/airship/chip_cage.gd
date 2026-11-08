class_name ChipCage
extends StaticBody3D
## Pearl Doyle's cashier's cage on the casino deck: she sells chips for team
## chitin (ChipRules) and cashes them back in at the same price; the tables
## take chips as stakes and pay winnings in your own scrap. Chips are counts on your cliff, shown on the HUD. Customers stand
## on the -Z side.

signal menu_changed

const ART := preload("res://gen/airship_props_art.gd")


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	# A bank teller's cage in mahogany and brass (gen/airship_props_art.gd):
	# marble counter, brass grille with an arched window, chip racks, a safe,
	# a cash register, a banker's lamp and a velvet rope for the queue.
	ART.cashier_booth(self)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.7, 2.9, 1.6)
	col.shape = shape
	col.position = Vector3(0, 1.45, 0.05)
	add_child(col)
	var keeper := Shopkeeper.new()
	keeper.name = "Pearl"
	keeper.position = Vector3(0.0, 0, 0.2)
	add_child(keeper)
	keeper.setup({"hat": "bowler", "facial": "none", "hair": "long", "hair_color": "ginger", "outfit": "vest",
		"neck": "bolo", "extra": "none", "paint": "white"}, Color("#7A2E3A"))
	for line: Array in [["PEARL'S CHIPS", 0.0032, 3.02, Color("#E9C46A")]]: # (no tagline under it: Logan)
		var sign := Label3D.new()
		sign.text = str(line[0])
		sign.font_size = 72
		sign.pixel_size = float(line[1])
		sign.outline_size = 14
		sign.modulate = line[3]
		sign.outline_modulate = Palette.OUTLINE
		sign.position = Vector3(0, float(line[2]), -0.86) # (on the pediment board)
		sign.rotation.y = PI
		sign.double_sided = false
		add_child(sign)
	Economy.resources_changed.connect(_on_resources)


func _exit_tree() -> void:
	if Economy.resources_changed.is_connected(_on_resources):
		Economy.resources_changed.disconnect(_on_resources)


func _on_resources(_cid: int) -> void:
	menu_changed.emit()


# ------------------------------------------------------------------ the menu screen

func interact_prompt() -> String:
	return "E: buy chips from Pearl"


func local_interact(holding: bool) -> void:
	if not holding and MenuScreen.instance != null:
		MenuScreen.instance.open(self)


func menu_title() -> String:
	return "Pearl's Cage"


func menu_tagline() -> String:
	return "Chips for the tables, paid in team %s, and cashed back in for the same. The tables pay your winnings in your own %s." % [ResNames.team(), ResNames.personal()]


func menu_items(_tab: int) -> Array:
	var cid := _cliff(multiplayer.get_unique_id())
	var pot := Economy.team_scrap()
	var out: Array = []
	for v in ChipRules.DENOMS:
		var id := ChipRules.id_of(v)
		var cost := ChipRules.price(v)
		var held := Economy.amount(cid, id)
		var buttons: Array = [[&"buy1", "Buy 1"], [&"buy5", "Buy 5"]]
		if held > 0:
			buttons.append([&"cash", "Cash Out All"])
		out.append({"id": String(id), "name": "%s Chip  ·  %d" % [ChipRules.NAMES[v], v], "icon": ChipIcon.texture(v),
				"desc": "Stakes %d at any table. You hold %d." % [v, held],
				"price": UiStyle.cost(cost, ResNames.TEAM_ID), "price_ok": pot >= cost, "disabled": "",
				"buttons": buttons})
	return out


func menu_press(id: Variant, action: StringName) -> void:
	if action == &"cash":
		if multiplayer.is_server():
			_cash(multiplayer.get_unique_id(), StringName(str(id)))
		else:
			_request_cash.rpc_id(1, StringName(str(id)))
		return
	var n := 5 if action == &"buy5" else 1
	if multiplayer.is_server():
		_buy(multiplayer.get_unique_id(), StringName(str(id)), n)
	else:
		_request_buy.rpc_id(1, StringName(str(id)), n)


@rpc("any_peer", "reliable")
func _request_cash(id: StringName) -> void:
	if multiplayer.is_server():
		_cash(multiplayer.get_remote_sender_id(), id)


## Host: every chip of `id` this rider holds back into the team pot at its price.
func _cash(peer_id: int, id: StringName) -> void:
	if not ChipRules.is_chip(id):
		return
	var cid := _cliff(peer_id)
	var n := Economy.amount(cid, id)
	if n <= 0 or not Economy.spend(cid, {id: n}):
		return
	var back := n * ChipRules.price(ChipRules.value_of(id))
	Economy.earn(cid, {ResNames.TEAM_ID: back})
	Economy.notify(peer_id, "Pearl cashes in your %d %s chips: +%s to the team pot." % [n, String(ChipRules.NAMES[ChipRules.value_of(id)]).to_lower(), UiStyle.cost(back, ResNames.TEAM_ID)])
	_ka_ching.rpc()


@rpc("any_peer", "reliable")
func _request_buy(id: StringName, n: int) -> void:
	if multiplayer.is_server():
		_buy(multiplayer.get_remote_sender_id(), id, n)


## Host: `n` chips of `id` for this rider, paid from the team pot.
func _buy(peer_id: int, id: StringName, n: int) -> void:
	if not ChipRules.is_chip(id):
		return
	var cid := _cliff(peer_id)
	var cost := ChipRules.price(ChipRules.value_of(id))
	var bought := 0
	for i in clampi(n, 1, 20):
		if not Economy.spend(cid, {ResNames.TEAM_ID: cost}):
			break
		bought += 1
	if bought == 0:
		Economy.notify(peer_id, "A %d chip costs %s." % [ChipRules.value_of(id), UiStyle.cost(cost, ResNames.TEAM_ID)])
		return
	Economy.earn(cid, {id: bought})
	_ka_ching.rpc()


@rpc("authority", "call_local", "unreliable")
func _ka_ching() -> void:
	Audio.play_at(&"coin", global_position + Vector3.UP, -4.0)


func _cliff(peer_id: int) -> int:
	return NetworkManager.cliff_of(peer_id)
