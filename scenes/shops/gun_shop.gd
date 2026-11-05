class_name GunShop
extends StaticBody3D
## The gunsmith on each plateau: buy the lever-action rifle and coach shotgun, and
## upgrade any weapon (+25% damage and faster reloads per level), all for chitin.
## F picks an item, E buys it. The host checks and charges, then hands the weapon
## to the buyer's own Gun.

const SHELF: Array[Dictionary] = [
	{"kind": "buy", "id": &"lever_rifle"},
	{"kind": "buy", "id": &"coach_shotgun"},
	{"kind": "buy", "id": &"blunderbuss"},
	{"kind": "buy", "id": &"crank_gatling"},
	{"kind": "buy", "id": &"elephant_gun"},
	{"kind": "buy", "id": &"dino_rifle"},
	{"kind": "buy", "id": &"derringer_pair"},
	{"kind": "buy", "id": &"pepperbox"},
	{"kind": "buy", "id": &"salt_shotgun"},
	{"kind": "buy", "id": &"harpoon_pistol"},
	{"kind": "buy", "id": &"bee_smoker"},
	{"kind": "buy", "id": &"flare_gun"},
	{"kind": "buy", "id": &"punt_gun"},
	{"kind": "buy", "id": &"telescope_rifle"},
	{"kind": "upgrade", "id": &"revolver"},
	{"kind": "upgrade", "id": &"lever_rifle"},
	{"kind": "upgrade", "id": &"coach_shotgun"},
	{"kind": "upgrade", "id": &"blunderbuss"},
	{"kind": "upgrade", "id": &"crank_gatling"},
	{"kind": "upgrade", "id": &"elephant_gun"},
	{"kind": "upgrade", "id": &"dino_rifle"},
	{"kind": "upgrade", "id": &"derringer_pair"},
	{"kind": "upgrade", "id": &"pepperbox"},
	{"kind": "upgrade", "id": &"salt_shotgun"},
	{"kind": "upgrade", "id": &"harpoon_pistol"},
	{"kind": "upgrade", "id": &"bee_smoker"},
	{"kind": "upgrade", "id": &"flare_gun"},
	{"kind": "upgrade", "id": &"punt_gun"},
	{"kind": "upgrade", "id": &"telescope_rifle"},
	{"kind": "mods", "id": &"revolver"},
	{"kind": "mods", "id": &"lever_rifle"},
	{"kind": "mods", "id": &"coach_shotgun"},
	{"kind": "mods", "id": &"blunderbuss"},
	{"kind": "mods", "id": &"crank_gatling"},
	{"kind": "mods", "id": &"elephant_gun"},
	{"kind": "mods", "id": &"dino_rifle"},
	{"kind": "mods", "id": &"derringer_pair"},
	{"kind": "mods", "id": &"pepperbox"},
	{"kind": "mods", "id": &"salt_shotgun"},
	{"kind": "mods", "id": &"harpoon_pistol"},
	{"kind": "mods", "id": &"bee_smoker"},
	{"kind": "mods", "id": &"flare_gun"},
	{"kind": "mods", "id": &"punt_gun"},
	{"kind": "mods", "id": &"telescope_rifle"},
]

## Host: what every peer owns, peer_id -> {weapon id: level}.
static var loadouts: Dictionary = {}
## Host: each peer's whip (WeaponMods code); everyone always has one.
static var whips: Dictionary = {}
## Host: each peer's grapple dynamite (WeaponMods code under DynamiteRules.ID;
## 0 = no Powder Satchel yet).
static var dynamite: Dictionary = {}

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
	# No price board in the world: the prices live in the shop screen (Logan's call).
	board.visible = false
	var lines: PackedStringArray = ["GUNSMITH", "prices in " + ResNames.personal(), ""]
	for w: StringName in [&"lever_rifle", &"coach_shotgun", &"blunderbuss", &"crank_gatling", &"elephant_gun"]:
		lines.append("%s ... %d" % [Gun.weapon(w).display_name, Gun.weapon(w).price_chitin])
	lines.append("Upgrades ... from " + UiStyle.cost(10, ResNames.PERSONAL_ID))
	_label.text = "\n".join(lines)


static func reset_loadouts() -> void:
	loadouts.clear()
	whips.clear()
	dynamite.clear()


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
	return "New irons and upgrades, paid in your own %s. You can carry three guns; drop one with Q to make room." % ResNames.personal()


func menu_tabs() -> Array:
	return ["Guns", "Upgrades", "Workshop Mods"]


func menu_items(tab: int) -> Array:
	var gun := _local_gun()
	if gun == null:
		return []
	var chitin := Economy.amount(NetworkManager.cliff_of(multiplayer.get_unique_id()), &"chitin")
	var out: Array = []
	for item: Dictionary in SHELF:
		var id: StringName = item["id"]
		var w := Gun.weapon(id)
		if id == &"dino_rifle" and not Perks.has_secret(multiplayer.get_unique_id(), &"weapon", id) and not gun.owns(id):
			continue # secret: only once its code has been entered
		if tab == 0 and item["kind"] == "buy":
			var why := ""
			if gun.owns(id):
				why = "Already in your holster."
			elif gun.owned.size() >= Gun.MAX_WEAPONS:
				why = "Your three weapon slots are full. Drop one first (Q)."
			out.append({"id": "buy:%s" % id, "name": w.display_name, "icon": id, "desc": "%s
%s" % [w.description, w.stat_line()],
					"price": UiStyle.cost(w.price_chitin, "chitin"), "price_ok": chitin >= w.price_chitin, "disabled": why,
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
			out.append({"id": "upgrade:%s" % id, "name": "%s  ·  Level %d" % [w.display_name, level], "icon": id,
					"desc": _upgrade_desc(w), "price": "" if maxed else UiStyle.cost(cost, "chitin"),
					"price_ok": chitin >= cost, "disabled": why, "buttons": [[&"buy", "Upgrade"]]})
		elif tab == 2 and item["kind"] == "mods":
			# Only guns you carry, so the list stays short.
			if not gun.owns(id):
				continue
			var code := gun.code_of(id)
			var mods := WeaponMods.list(id)
			for i in mods.size():
				var m: Dictionary = mods[i]
				var fitted := WeaponMods.has_mod(code, i)
				out.append({"id": "mod:%s:%d" % [id, i], "name": "%s: %s" % [w.display_name, m["name"]], "icon": id,
						"desc": str(m["desc"]), "price": "" if fitted else UiStyle.cost(int(m["cost"]), "chitin"),
						"price_ok": chitin >= int(m["cost"]), "disabled": "Fitted." if fitted else "",
						"buttons": [[&"buy", "Fit it"]]})
	var p := _player_of(multiplayer.get_unique_id())
	if p != null and p.whip != null:
		var wc := p.whip.code
		if tab == 1:
			var lvl := WeaponMods.level(wc)
			var maxed := lvl >= WeaponMods.WHIP_LEVEL_COSTS.size()
			var cost: int = 0 if maxed else WeaponMods.WHIP_LEVEL_COSTS[lvl]
			out.append({"id": "upgrade:whip", "name": "Bullwhip  ·  Level %d" % lvl, "icon": &"planks",
					"desc": "+25% lash damage per level.", "price": "" if maxed else UiStyle.cost(cost, "chitin"),
					"price_ok": chitin >= cost, "disabled": "Fully upgraded." if maxed else "", "buttons": [[&"buy", "Upgrade"]]})
			var gold_why := ""
			if WeaponMods.is_golden(wc):
				gold_why = "It already shines."
			elif not WeaponMods.can_gild(wc):
				gold_why = "Max the whip's level and fit all three workshop mods first."
			out.append({"id": "gild:whip", "name": "The Golden Whip", "icon": &"planks",
					"desc": "Gild the whole lash in gold: +60% damage, 15% more reach, lashes 20% quicker. The gunsmith's masterpiece.",
					"price": "" if WeaponMods.is_golden(wc) else UiStyle.cost(WeaponMods.GOLDEN_COST, "chitin"),
					"price_ok": chitin >= WeaponMods.GOLDEN_COST, "disabled": gold_why, "buttons": [[&"buy", "Gild it"]]})
		elif tab == 2:
			var mods := WeaponMods.list(&"whip")
			for i in mods.size():
				var m: Dictionary = mods[i]
				var fitted := WeaponMods.has_mod(wc, i)
				out.append({"id": "mod:whip:%d" % i, "name": "Bullwhip: %s" % m["name"], "icon": &"planks",
						"desc": str(m["desc"]), "price": "" if fitted else UiStyle.cost(int(m["cost"]), "chitin"),
						"price_ok": chitin >= int(m["cost"]), "disabled": "Fitted." if fitted else "", "buttons": [[&"buy", "Fit it"]]})
	if p != null and p.dynamite != null:
		# The Powder Satchel heads the Upgrades (it's new, and not a gun); its mods follow the rest.
		var dyn := _dynamite_items(tab, p.dynamite.code, chitin)
		out = dyn + out if tab == 1 else out + dyn
	if tab == 2 and out.is_empty():
		out.append({"id": "", "name": "Nothing to work on", "icon": &"hammer", "desc": "Mods are fitted to the guns you carry.",
				"price": "", "price_ok": true, "disabled": "Buy a gun first.", "buttons": []})
	return Perks.discount_menu(out, &"gunsmiths_friend", NetworkManager.cliff_of(multiplayer.get_unique_id())) # Perk: Gunsmith's Friend


## The grapple's dynamite: the Powder Satchel (Upgrades), then its three mods.
static func _dynamite_items(tab: int, c: int, chitin: int) -> Array:
	var out: Array = []
	var owned := DynamiteRules.unlocked(c)
	if tab == 1:
		out.append({"id": "upgrade:%s" % DynamiteRules.ID, "name": "Grapple Hook  ·  Powder Satchel", "icon": &"grapple",
				"desc": "A satchel of dynamite on your belt and a match strip down the launcher. With the grapple out, R raises a bundle, R again strikes it and lobs it at your sights: %d damage in %s m, %d bundles carried, one back every %d s up top. It's the loudest thing in the canyon." % [
					int(DynamiteRules.DAMAGE), str(DynamiteRules.RADIUS), DynamiteRules.MAX_BUNDLES, int(DynamiteRules.RESTOCK_SECS)],
				"price": "" if owned else UiStyle.cost(DynamiteRules.SATCHEL_COST, "chitin"),
				"price_ok": chitin >= DynamiteRules.SATCHEL_COST, "disabled": "On your belt." if owned else "", "buttons": [[&"buy", "Buy"]]})
	elif tab == 2 and owned:
		var mods := WeaponMods.list(DynamiteRules.ID)
		for i in mods.size():
			var m: Dictionary = mods[i]
			var fitted := WeaponMods.has_mod(c, i)
			out.append({"id": "mod:%s:%d" % [DynamiteRules.ID, i], "name": "Dynamite: %s" % m["name"], "icon": &"grapple",
					"desc": str(m["desc"]), "price": "" if fitted else UiStyle.cost(int(m["cost"]), "chitin"),
					"price_ok": chitin >= int(m["cost"]), "disabled": "Fitted." if fitted else "", "buttons": [[&"buy", "Fit it"]]})
	return out


## What one level does for this gun (the smoker does no damage: it smokes longer).
static func _upgrade_desc(w: WeaponDef) -> String:
	if w.special == &"smoke":
		return "Smoke keeps bugs drowsy %s s longer and the fuel refills 25%% faster per level." % str(GunRules.SMOKE_TIME_PER_LEVEL)
	return "+25% damage and a 15% faster reload per level."


func menu_press(id: Variant, _action: StringName) -> void:
	var parts := str(id).split(":")
	if parts.size() < 2:
		return
	var slot := int(parts[2]) if parts.size() > 2 else -1
	if multiplayer.is_server():
		_buy(multiplayer.get_unique_id(), parts[0], StringName(parts[1]), slot)
	else:
		_request_buy.rpc_id(1, parts[0], StringName(parts[1]), slot)


@rpc("any_peer", "reliable")
func _request_buy(kind: String, id: StringName, slot: int = -1) -> void:
	if multiplayer.is_server():
		_buy(multiplayer.get_remote_sender_id(), kind, id, slot)


func _buy(peer_id: int, kind: String, id: StringName, slot: int = -1) -> void:
	if id == &"whip":
		_buy_whip(peer_id, kind, slot)
		return
	if id == DynamiteRules.ID:
		_buy_dynamite(peer_id, kind, slot)
		return
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
		if id == &"dino_rifle" and not Perks.has_secret(peer_id, &"weapon", id):
			return
		cost = w.price_chitin
		if id == &"dino_rifle":
			level = DinoGlass.with_variant(0, DinoGlass.roll()) # every glass is tied on differently
	elif kind == "mod":
		var mods := WeaponMods.list(id)
		if not owned.has(id) or slot < 0 or slot >= mods.size() or WeaponMods.has_mod(int(owned[id]), slot):
			return
		cost = int(mods[slot]["cost"])
		level = WeaponMods.with_mod(int(owned[id]), slot)
	else:
		var lvl := WeaponMods.level(int(owned[id])) if owned.has(id) else 99
		if lvl >= w.upgrade_costs.size():
			return
		cost = w.upgrade_costs[lvl]
		level = int(owned[id]) + 1 # bumps the level bits, keeps the mods
	cost = Perks.discount(peer_id, &"gunsmiths_friend", cost) # Perk: Gunsmith's Friend
	if not Economy.spend(payer, {&"chitin": cost}):
		Economy.notify(peer_id, "That costs %s. Salvage the junk heap by your house each build phase, or sell chilies at the market." % UiStyle.cost(cost, ResNames.PERSONAL_ID))
		return
	owned[id] = level
	var player := _player_of(peer_id)
	if player != null:
		player.net.grant_weapon(id, level)
	if kind == "buy" and id == &"dino_rifle":
		var fit := DinoGlass.get_fit(level)
		Economy.notify(peer_id, "Your glass: %s. %s" % [fit["name"], fit["blurb"]])
	_sold.rpc()


@rpc("authority", "call_local", "unreliable")
func _sold() -> void:
	Audio.play_at(&"register", global_position, -2.0)
	menu_changed.emit()


func _player_of(peer_id: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id:
			return n as Player
	return null


func _local_gun() -> Gun:
	var p := _player_of(multiplayer.get_unique_id())
	return p.gun if p != null else null


## Host: a whip level or mod.
func _buy_whip(peer_id: int, kind: String, slot: int) -> void:
	var c := int(whips.get(peer_id, 0))
	var cost := 0
	var next := c
	if kind == "gild":
		if not WeaponMods.can_gild(c):
			return
		cost = WeaponMods.GOLDEN_COST
		next = c | WeaponMods.GOLDEN_BIT
	elif kind == "mod":
		var mods := WeaponMods.list(&"whip")
		if slot < 0 or slot >= mods.size() or WeaponMods.has_mod(c, slot):
			return
		cost = int(mods[slot]["cost"])
		next = WeaponMods.with_mod(c, slot)
	else:
		var lvl := WeaponMods.level(c)
		if lvl >= WeaponMods.WHIP_LEVEL_COSTS.size():
			return
		cost = WeaponMods.WHIP_LEVEL_COSTS[lvl]
		next = c + 1
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	cost = Perks.discount(peer_id, &"gunsmiths_friend", cost) # Perk: Gunsmith's Friend
	if not Economy.spend(payer, {&"chitin": cost}):
		Economy.notify(peer_id, "That costs %s." % UiStyle.cost(cost, ResNames.PERSONAL_ID))
		return
	whips[peer_id] = next
	if peer_id == multiplayer.get_unique_id():
		_set_whip(next)
	else:
		_set_whip.rpc_id(peer_id, next)
	if kind == "gild":
		Economy.notify(peer_id, "The gunsmith hands you THE GOLDEN WHIP.")
	else:
		Economy.notify(peer_id, "Bullwhip: %s." % ("level %d" % WeaponMods.level(next) if kind != "mod" else WeaponMods.names(&"whip", next & ~c)))
	_sold.rpc()


## Host: the Powder Satchel, or one of the dynamite's workshop mods.
func _buy_dynamite(peer_id: int, kind: String, slot: int) -> void:
	var c := int(dynamite.get(peer_id, 0))
	var cost := 0
	var next := c
	if kind == "mod":
		var mods := WeaponMods.list(DynamiteRules.ID)
		if not DynamiteRules.unlocked(c) or slot < 0 or slot >= mods.size() or WeaponMods.has_mod(c, slot):
			return
		cost = int(mods[slot]["cost"])
		next = WeaponMods.with_mod(c, slot)
	else:
		if DynamiteRules.unlocked(c):
			return
		cost = DynamiteRules.SATCHEL_COST
		next = c | 1
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	cost = Perks.discount(peer_id, &"gunsmiths_friend", cost) # Perk: Gunsmith's Friend
	if not Economy.spend(payer, {&"chitin": cost}):
		Economy.notify(peer_id, "That costs %s." % UiStyle.cost(cost, ResNames.PERSONAL_ID))
		return
	var player := _player_of(peer_id)
	if player != null and player.dynamite != null:
		player.dynamite.grant(next) # record, the owner's code, a full satchel the first time
	else:
		dynamite[peer_id] = next
	if kind == "mod":
		Economy.notify(peer_id, "Dynamite: %s." % WeaponMods.names(DynamiteRules.ID, next & ~c))
	else:
		Economy.notify(peer_id, "A Powder Satchel on your belt and a match strip on the launcher. Grapple out (%s), then R, R." % KeyHints.key_for("select_10"))
	_sold.rpc()


@rpc("authority", "reliable")
func _set_whip(c: int) -> void:
	var p := _player_of(multiplayer.get_unique_id())
	if p != null and p.whip != null:
		p.whip.code = c
	menu_changed.emit()
