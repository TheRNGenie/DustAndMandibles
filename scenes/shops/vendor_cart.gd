class_name VendorCart
extends StaticBody3D
## The produce vendor in the airship market. Chilies sell for chitin (for turret and
## weapon upgrades), other vegetables sell for scrap, and seeds cost scrap. F picks a line, E sells or buys one,
## hold E to repeat. Vegetable prices drop as you sell (down to -50%) and climb
## back while you don't (up to +50%); the sign shows today's prices.

const ITEMS: Array[StringName] = [&"corn", &"prickly_pear", &"chili", &"herbs", &"egg", &"specimen"]
const NAMES: Dictionary = {&"corn": "Corn", &"prickly_pear": "Prickly Pear", &"chili": "Firecracker Chili", &"herbs": "Sage Herbs",
	&"egg": "Nest Egg", &"specimen": "Specimen Jar"}
const SYNC_INTERVAL := 1.5
## Seeds for sale: seed resource -> [name, crop id]. Price = MarketPrices.seed_price.
const SEEDS: Dictionary = {&"seed_corn": ["Corn Seeds", &"corn"], &"seed_prickly_pear": ["Prickly Pear Seeds", &"prickly_pear"],
	&"seed_chili": ["Chili Seeds", &"firecracker_chili"], &"seed_herbs": ["Herb Seeds", &"herbs"],
	&"seed_sarsaparilla": ["Sarsaparilla Seeds", &"sarsaparilla"],
	&"seed_cotton": ["Cotton Seeds", &"cotton"], &"seed_sulfur_root": ["Sulfur Root Seeds", &"sulfur_root"],
	&"seed_barrel_cactus": ["Barrel Cactus Seeds", &"barrel_cactus"], &"seed_tumbleweed": ["Tumbleweed Seeds", &"tumbleweed_vine"]}


static func seed_cost(seed_res: StringName) -> int:
	return MarketPrices.seed_price(Defs.crop((SEEDS[seed_res] as Array)[1]))

static var selected := 0

var cliff_id: int = 0
var market := MarketPrices.new()
## Fractional earnings owed to each cliff, per currency (paid out in whole units).
var _credit: Dictionary = {}
var _prices: Dictionary = {}
var _label: Label3D
var _sync_t := 0.0


func setup(cid: int) -> void:
	cliff_id = cid
	collision_layer = WorldLayout.LAYER_STRUCTURE
	var mi := MeshInstance3D.new()
	mi.mesh = ShopBuilder.vendor_cart()
	mi.material_override = Materials.toon(0.025)
	add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 1.6, 1.8)
	col.shape = shape
	col.position.y = 0.8
	add_child(col)
	var board := MeshInstance3D.new()
	board.mesh = ShopBuilder.sign_board()
	board.material_override = Materials.toon(0.02)
	board.position = Vector3(-3.0, 0, -0.3)
	add_child(board)
	var keeper := Shopkeeper.new()
	keeper.position = Vector3(1.85, 0, -0.7)
	add_child(keeper)
	keeper.setup({"hat": "sombrero", "facial": "horseshoe", "hair": "long", "hair_color": "black", "outfit": "poncho",
		"neck": "bandana", "extra": "spurs", "paint": "orange"}, Color("#3E6A5A"))
	# A rack of seed packets on the counter.
	var rack := MeshInstance3D.new()
	rack.mesh = CropBuilder.packet_rack()
	rack.material_override = Materials.toon(0.006)
	rack.position = Vector3(0.75, 1.62, -0.55)
	rack.rotation.y = PI
	rack.scale = Vector3.ONE * 1.8
	add_child(rack)
	_label = ShopBuilder.sign_label()
	board.add_child(_label)
	# No price board in the world: the prices live in the shop screen (Logan's call).
	board.visible = false
	for k: StringName in ITEMS:
		_prices[k] = market.price(k)
	_refresh_sign()


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	market.tick(delta)
	_sync_t -= delta
	# Not before the run starts: clients still loading have no Vendor to hear it.
	if _sync_t <= 0.0 and GameState.phase != GameState.Phase.LOBBY:
		_sync_t = SYNC_INTERVAL
		var p: Dictionary = {}
		for k: StringName in ITEMS:
			p[k] = market.price(k)
		_sync_prices.rpc(p)


@rpc("authority", "call_local", "unreliable")
func _sync_prices(prices: Dictionary) -> void:
	_prices = prices
	_refresh_sign()
	menu_changed.emit()


func _refresh_sign() -> void:
	var lines: PackedStringArray = ["PRODUCE BOUGHT", ""]
	for k: StringName in ITEMS:
		var p := float(_prices.get(k, 0.0))
		var base := float(MarketPrices.BASE[k])
		var trend := "  (high!)" if p > base * 1.15 else ("  (low)" if p < base * 0.85 else "")
		lines.append("%s ... %s%s" % [NAMES[k], _price_text(k, p), trend])
	lines.append("")
	lines.append("SEEDS SOLD (team %s)" % ResNames.team())
	for s: StringName in SEEDS:
		lines.append("%s ... %d" % [str((SEEDS[s] as Array)[0]), seed_cost(s)])
	_label.text = "\n".join(lines)


signal menu_changed


# ------------------------------------------------------------------ the menu screen

func interact_prompt() -> String:
	return "E: trade with the produce vendor"


func local_interact(holding: bool) -> void:
	if not holding and MenuScreen.instance != null:
		MenuScreen.instance.open(self)


func menu_title() -> String:
	return "Produce & Seeds"


func menu_tagline() -> String:
	return StyleCombo.streak_note() + "Chilies and specimen jars sell for your own scrap, other produce and nest eggs for team chitin (prices drop as you sell and recover over time). Seeds cost team chitin."


static func _price_text(item: StringName, p: float) -> String:
	if MarketPrices.currency(item) == &"chitin":
		return UiStyle.cost(snappedf(p, 0.1), "chitin")
	return UiStyle.cost(roundf(p), "scrap")


func menu_tabs() -> Array:
	return ["Sell Produce", "Buy Seeds"]


func menu_items(tab: int) -> Array:
	var cid := _local_cliff()
	var out: Array = []
	if tab == 0:
		for k: StringName in ITEMS:
			var have := Economy.amount(cid, k)
			var p := float(_prices.get(k, 0.0))
			var base := float(MarketPrices.BASE[k])
			var trend := " Paying well right now." if p > base * 1.15 else (" Flooded: the price is low." if p < base * 0.85 else "")
			# Selling isn't about affording: the price never gets the "can't afford" cross.
			var icon: Variant = k
			if SitePlan.NEW_ITEMS.has(k) and MenuScreen.instance != null:
				icon = IconStudio.site_loot(MenuScreen.instance, &"egg" if k == SitePlan.NEST_EGG else &"specimen")
			out.append({"id": k, "name": NAMES[k], "icon": icon, "desc": "You have %d.%s" % [have, trend],
					"price": _price_text(k, p) + " Each", "price_ok": true,
					"disabled": "" if have > 0 else "Nothing to sell yet.", "disabled_kind": "info",
					"buttons": [[&"sell1", "Sell 1"], [&"sellall", "Sell all"]]})
	else:
		for s: StringName in SEEDS:
			var info: Array = SEEDS[s]
			var cost := seed_cost(s)
			var crop_id: StringName = info[1]
			var icon: Variant = IconStudio.seed_packet(MenuScreen.instance, crop_id) if MenuScreen.instance != null else null
			out.append({"id": s, "name": str(info[0]), "icon": icon, "desc": "Plant on a farm plot. You have %d." % Economy.amount(cid, s),
					"price": UiStyle.cost(cost, "scrap"), "price_ok": Economy.amount(cid, &"scrap") >= cost,
					"buttons": [[&"buy1", "Buy 1"], [&"buy5", "Buy 5"]]})
	return out


func menu_press(id: Variant, action: StringName) -> void:
	var count := 1
	match action:
		&"sellall":
			count = maxi(Economy.amount(_local_cliff(), StringName(str(id))), 1)
		&"buy5":
			count = 5
	if multiplayer.is_server():
		_trade(multiplayer.get_unique_id(), StringName(str(id)), count)
	else:
		_request_trade.rpc_id(1, StringName(str(id)), count)


@rpc("any_peer", "reliable")
func _request_trade(item: StringName, count: int) -> void:
	if multiplayer.is_server():
		_trade(multiplayer.get_remote_sender_id(), item, count)


func _trade(peer_id: int, item: StringName, count: int) -> void:
	for i in clampi(count, 1, 99):
		if not _sell(peer_id, item):
			break


func _local_cliff() -> int:
	return NetworkManager.cliff_of(multiplayer.get_unique_id())


## Host: one sale or one seed purchase. Returns false when it couldn't happen.
func _sell(peer_id: int, item: StringName) -> bool:
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	if SEEDS.has(item):
		var info: Array = SEEDS[item]
		var streak := StyleCombo.streak_for(peer_id) # Hot Streak: off this one purchase
		var cost := ComboRules.cut_price(seed_cost(item), streak)
		if not Economy.spend(payer, {&"scrap": cost}):
			Economy.notify(peer_id, "%s cost %s each." % [str(info[0]), UiStyle.cost(cost, ResNames.TEAM_ID)])
			return false
		Economy.earn(payer, {item: 1})
		if streak > 0.0:
			StyleCombo.use_streak(peer_id)
			Economy.notify(peer_id, "Hot Streak: %d%% off those seeds." % roundi(streak * 100.0))
		_ka_ching.rpc()
		return true
	if not ITEMS.has(item):
		return false
	if not Economy.spend(payer, {item: 1}):
		var where := "Bring some up from the canyon floor." if SitePlan.NEW_ITEMS.has(item) else "Grow some on a farm plot."
		Economy.notify(peer_id, "You have no %s to sell. %s" % [String(NAMES[item]).to_lower(), where])
		return false
	var cur := MarketPrices.currency(item)
	var key := "%d:%s" % [payer, cur]
	_credit[key] = float(_credit.get(key, 0.0)) + market.sell(item, 1)
	var whole := int(floor(float(_credit[key])))
	if whole > 0:
		_credit[key] = float(_credit[key]) - whole
		Economy.earn(payer, {cur: whole})
	_ka_ching.rpc()
	return true


## Host: a CPU teammate sells `n` of `item` for cliff `cid` (paid like a rider's sale).
## Returns what it fetched.
func cpu_sell(cid: int, item: StringName, n: int) -> int:
	if not ITEMS.has(item) or n <= 0:
		return 0
	var cur := MarketPrices.currency(item)
	var key := "%d:%s" % [cid, cur]
	_credit[key] = float(_credit.get(key, 0.0)) + market.sell(item, n)
	var whole := int(floor(float(_credit[key])))
	if whole > 0:
		_credit[key] = float(_credit[key]) - whole
		Economy.earn(cid, {cur: whole})
	_ka_ching.rpc()
	return whole


@rpc("authority", "call_local", "unreliable")
func _ka_ching() -> void:
	Audio.play_at(&"coin", global_position, -4.0)
