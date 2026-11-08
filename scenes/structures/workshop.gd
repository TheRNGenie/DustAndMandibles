class_name Workshop
extends StaticBody3D
## The Workshop: a lean-to shed on the back of the Homestead (a house upgrade,
## bought at the ledger). Its bench combines one mount, one barrel and one load
## (parts from big bugs and bosses, CraftTable) into a crafted turret ITEM that
## goes into the cliff's stockpile; the build menu's Crafted tab places it.
## Doesn't touch repair prices.

signal menu_changed

var home: Homestead


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = _shed_mesh()
	mi.material_override = Materials.toon_house(0.02)
	add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.0, 0.8)
	col.shape = shape
	col.position = Vector3(0, 0.5, 0.35)
	add_child(col)
	# Special weapons: the crop fitting tab, with its jars on the bench (CropBench).
	var crops := CropBench.new()
	crops.name = "CropBench"
	crops.home = home
	crops.workshop = self
	crops.position = Vector3(0.45, 0.95, 0.62)
	add_child(crops)
	Economy.resources_changed.connect(_on_resources)


func _exit_tree() -> void:
	if Economy.resources_changed.is_connected(_on_resources):
		Economy.resources_changed.disconnect(_on_resources)


func _on_resources(_c: int) -> void:
	menu_changed.emit()


## Lean-to shed (open front), bench with a vise, crates of parts, a lantern.
## Local: origin on the floor at the shed's open front; +Z runs back to the house wall.
static func _shed_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DARK
	# Posts and a sloping plank roof against the house wall behind (+Z).
	for x: float in [-2.0, 2.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 1.1, -0.55)), Vector3(0.14, 2.2, 0.14), dark)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0, 2.45, 0.35)), Vector3(4.4, 0.08, 2.1), wood.darkened(0.15))
	for i in 6:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(-1.85 + i * 0.74, 2.5, 0.35)), Vector3(0.05, 0.03, 2.1), dark)
	# Plank floor.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.04, 0.35)), Vector3(4.2, 0.08, 1.9), wood.darkened(0.3))
	# Bench: top, legs, shelf.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.9, 0.4)), Vector3(1.8, 0.1, 0.75), wood.lightened(0.05))
	for x: float in [-0.8, 0.8]:
		for z: float in [0.1, 0.7]:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.45, z)), Vector3(0.08, 0.9, 0.08), dark)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.25, 0.4)), Vector3(1.7, 0.05, 0.65), dark)
	# Vise on the bench corner, a barrel and a gear lying on top.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.65, 1.02, 0.15)), Vector3(0.2, 0.14, 0.16), Palette.ROCK_B.darkened(0.4))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.1, 1.0, 0.45)), 0.05, 0.05, 0.9, 8, Color("#3E3B3A"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.6, 0.97, 0.5)), 0.13, 0.13, 0.04, 10, Color("#B8893A"))
	# Crates of parts beside the bench.
	for c: Array in [[Vector3(1.4, 0.25, 0.3), 0.5], [Vector3(1.55, 0.7, 0.35), 0.4], [Vector3(-1.45, 0.22, 0.5), 0.44]]:
		var s := float(c[1])
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.2), c[0]), Vector3(s, s, s), wood.lightened(0.1))
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.2), (c[0] as Vector3) + Vector3(0, s * 0.5 + 0.01, 0)), Vector3(s * 0.9, 0.02, s * 0.9), dark)
	# A lantern hanging off the roof beam.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(-1.2, 1.75, -0.45)), Vector3(0.16, 0.22, 0.16), Palette.GLOW_YELLOW, 0.0, null, 0.8)
	return MeshKit.finish(st)


func interact_prompt() -> String:
	return "E: open the workshop"


func local_interact(holding: bool) -> void:
	if not holding and MenuScreen.instance != null:
		MenuScreen.instance.open(self)


func menu_title() -> String:
	return "Workshop"


func menu_tagline() -> String:
	return "Combine a mount, a barrel and a load into a new turret (or, with a blueprint, hive amber and parts into an amber turret). Place it from the Crafted tab of the build menu (B). The Special Weapon tab fits your special weapon with a crop for good."


func menu_tabs() -> Array:
	return ["Craft", "Parts", "Amber", "Gear", "Special Weapon"]


func _cliff() -> int:
	return Economy.payer_cliff(multiplayer.get_unique_id(), home.cliff_id if home != null else 0)


func menu_items(tab: int) -> Array:
	var cid := _cliff()
	var out: Array = []
	if tab == 4:
		return (get_node("CropBench") as CropBench).menu_items()
	if tab == 2:
		return _amber_items(cid)
	if tab == 3:
		return _gear_items(cid)
	if tab == 1:
		for key: StringName in CraftTable.part_keys():
			var n := Economy.amount(cid, key)
			var part_icon: Variant = IconStudio.craft_part(MenuScreen.instance, key) if MenuScreen.instance != null else &"hammer"
			out.append({"id": "", "name": CraftTable.part_name(key), "icon": part_icon,
					"desc": CraftTable.part_desc(key), "price": "", "price_ok": true, "note": UiStyle.held(n),
					"disabled": "" if n > 0 else "None yet: big bugs and bosses drop parts.", "buttons": []})
		return out
	for id: StringName in CraftTable.all_designs():
		var recipe := CraftTable.recipe(id)
		if not Economy.can_afford(cid, recipe):
			continue
		var d := CraftTable.def_for(id)
		var icon: Variant = IconStudio.turret(MenuScreen.instance, id, Palette.team_color(cid)) if MenuScreen.instance != null else CraftTable.model_of(id)
		out.append({"id": String(id), "name": d.display_name, "icon": icon,
				"desc": "%s\n%s" % [d.stat_line(), d.role], "price": "3 Parts", "price_ok": true,
				"disabled": "", "buttons": [[&"craft", "Craft"]]})
	if out.is_empty():
		out.append({"id": "", "name": "No Full Set of Parts", "icon": &"hammer",
				"desc": "You need one mount, one barrel and one load. Big bugs and bosses drop them; see the Parts tab.",
				"price": "", "price_ok": true, "disabled": "Nothing to craft yet.", "buttons": []})
	return out


## Gear: the Zipline Anchor (ZipRules), your own scrap and a little team chitin.
func _gear_items(cid: int) -> Array:
	var recipe := ZipRules.recipe(Brand.zip_cost_mult(multiplayer.get_unique_id()))
	return [{"id": "gear:%s" % ZipRules.ITEM, "name": "Zipline Anchor", "icon": &"grapple",
			"desc": "Fire it into rock up to %d m away (%s): a rope strings back to where you stood for %d s. E near a rope rides it, either way. Up to %d of yours at once.
You have %d." % [
				int(ZipRules.RANGE), KeyHints.key_for("deploy_zip"), int(ZipRules.LIFE), ZipRules.MAX_PER_RIDER, Economy.amount(cid, ZipRules.ITEM)],
			"price": "%s + %s" % [UiStyle.cost(int(recipe[ResNames.PERSONAL_ID]), ResNames.PERSONAL_ID), UiStyle.cost(int(recipe[ResNames.TEAM_ID]), ResNames.TEAM_ID)],
			"price_ok": Economy.can_afford(cid, recipe), "disabled": "", "buttons": [[&"craft", "Make 1"]]}]


## Hive amber turrets (AmberRules): blueprint, recipe, and the one-each rule.
func _amber_items(cid: int) -> Array:
	var out: Array = []
	for id: StringName in AmberRules.IDS:
		var d := Defs.turret(id)
		var recipe := AmberRules.recipe(id)
		var need: PackedStringArray = []
		for k: StringName in recipe:
			if k == AmberRules.ITEM:
				continue
			var have := Economy.amount(cid, k)
			need.append("%s%s" % [CraftTable.part_name(k), "" if have > 0 else " (missing)"])
		var why := Amber.craft_block(id)
		if why == "" and not Economy.can_afford(cid, recipe):
			why = "You need %d hive amber and: %s." % [AmberRules.amber_cost(id), ", ".join(need)]
		var icon: Variant = IconStudio.turret(MenuScreen.instance, id, Palette.team_color(cid)) if MenuScreen.instance != null else &"amber"
		out.append({"id": String(id), "name": d.display_name, "icon": icon,
				"desc": "%s
%s
Parts: %s" % [d.stat_line(), d.role, ", ".join(need)],
				"price": UiStyle.cost(AmberRules.amber_cost(id), "amber"), "price_ok": Economy.amount(cid, AmberRules.ITEM) >= AmberRules.amber_cost(id),
				"disabled": why, "buttons": [[&"craft", "Craft"]]})
	return out


func menu_press(id: Variant, _action: StringName) -> void:
	if CropBench.handles(id):
		(get_node("CropBench") as CropBench).menu_press(id, _action)
		return
	if str(id).begins_with("gear:"):
		if multiplayer.is_server():
			_make_gear(multiplayer.get_unique_id())
		else:
			_request_gear.rpc_id(1)
		return
	var design := StringName(str(id))
	if AmberRules.is_amber(design):
		if multiplayer.is_server():
			_craft(multiplayer.get_unique_id(), design)
		else:
			_request_craft.rpc_id(1, String(design))
		return
	if not CraftTable.is_craft(design):
		return
	if multiplayer.is_server():
		_craft(multiplayer.get_unique_id(), design)
	else:
		_request_craft.rpc_id(1, String(design))


@rpc("any_peer", "reliable")
func _request_gear() -> void:
	if multiplayer.is_server():
		_make_gear(multiplayer.get_remote_sender_id())


## Host: one Zipline Anchor for this rider.
func _make_gear(peer_id: int) -> void:
	if home == null:
		return
	if not GameState.is_solo() and NetworkManager.cliff_of(peer_id) != home.cliff_id:
		Economy.notify(peer_id, "That's your partner's workshop. Use your own.")
		return
	var cid := Economy.payer_cliff(peer_id, home.cliff_id)
	var recipe := ZipRules.recipe(Brand.zip_cost_mult(peer_id))
	if not Economy.spend(cid, recipe):
		Economy.notify(peer_id, "A Zipline Anchor takes %s and %s." % [UiStyle.cost(int(recipe[ResNames.PERSONAL_ID]), ResNames.PERSONAL_ID), UiStyle.cost(int(recipe[ResNames.TEAM_ID]), ResNames.TEAM_ID)])
		return
	Economy.earn(cid, {ZipRules.ITEM: 1})
	Economy.notify(peer_id, "A Zipline Anchor, ready. Fire it with %s." % KeyHints.key_for("deploy_zip"))
	_crafted_fx.rpc()


@rpc("any_peer", "reliable")
func _request_craft(design: String) -> void:
	if multiplayer.is_server():
		_craft(multiplayer.get_remote_sender_id(), StringName(design))


## Host: use up the three parts, add one crafted turret item.
func _craft(peer_id: int, design: StringName) -> void:
	if home == null or (CraftTable.parse(design).is_empty() and not AmberRules.is_amber(design)):
		return
	if not GameState.is_solo() and NetworkManager.cliff_of(peer_id) != home.cliff_id:
		Economy.notify(peer_id, "That's your partner's workshop. Use your own.")
		return
	var cid := Economy.payer_cliff(peer_id, home.cliff_id)
	if AmberRules.is_amber(design):
		# Hive amber turrets: blueprint known, none fielded by the team, amber and parts.
		var why := Amber.craft_block(design)
		if why != "":
			Economy.notify(peer_id, why)
			return
		if not Economy.spend(cid, AmberRules.recipe(design)):
			Economy.notify(peer_id, "You need %d hive amber and the parts for the %s." % [AmberRules.amber_cost(design), AmberRules.name_of(design)])
			return
		Economy.earn(cid, {design: 1})
		Economy.notify(peer_id, "The %s is ready. Place it from the Crafted tab (B): the team fields only one." % AmberRules.name_of(design))
		_crafted_fx.rpc()
		return
	if not Economy.spend(cid, CraftTable.recipe(design)):
		Economy.notify(peer_id, "You're missing a part for that.")
		return
	Economy.earn(cid, {design: 1})
	Economy.notify(peer_id, "Crafted a %s. Place it from the Crafted tab (B)." % CraftTable.name_of(design))
	_crafted_fx.rpc()


@rpc("authority", "call_local", "unreliable")
func _crafted_fx() -> void:
	Audio.play_at(&"build", global_position + Vector3.UP)
