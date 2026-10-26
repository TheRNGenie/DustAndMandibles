class_name VendorCart
extends StaticBody3D
## The produce vendor at the Oasis. Sell vegetables for chitin (for turret and
## weapon upgrades) and buy seeds for scrap. F picks a line, E sells or buys one,
## hold E to repeat. Vegetable prices drop as you sell (down to -50%) and climb
## back while you don't (up to +50%); the sign shows today's prices.

const ITEMS: Array[StringName] = [&"corn", &"prickly_pear", &"chili", &"herbs"]
const NAMES: Dictionary = {&"corn": "Corn", &"prickly_pear": "Prickly pear", &"chili": "Firecracker chili", &"herbs": "Sage herbs"}
const SYNC_INTERVAL := 1.5
## Seeds for sale: seed resource -> [name, crop id]. Price = MarketPrices.seed_price.
const SEEDS: Dictionary = {&"seed_corn": ["Corn seeds", &"corn"], &"seed_prickly_pear": ["Prickly pear seeds", &"prickly_pear"],
	&"seed_chili": ["Chili seeds", &"firecracker_chili"], &"seed_herbs": ["Herb seeds", &"herbs"]}


static func seed_cost(seed_res: StringName) -> int:
	return MarketPrices.seed_price(Defs.crop((SEEDS[seed_res] as Array)[1]))

static var selected := 0

var cliff_id: int = 0
var market := MarketPrices.new()
## Fractional chitin owed to each cliff (paid out in whole units).
var _credit: Dictionary = {0: 0.0, 1: 0.0}
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
	board.position = Vector3(-2.5, 0, -0.3)
	add_child(board)
	_label = ShopBuilder.sign_label()
	board.add_child(_label)
	for k: StringName in ITEMS:
		_prices[k] = market.price(k)
	_refresh_sign()


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	market.tick(delta)
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = SYNC_INTERVAL
		var p: Dictionary = {}
		for k: StringName in ITEMS:
			p[k] = market.price(k)
		_sync_prices.rpc(p)


@rpc("authority", "call_local", "unreliable")
func _sync_prices(prices: Dictionary) -> void:
	_prices = prices
	_refresh_sign()


func _refresh_sign() -> void:
	var lines: PackedStringArray = ["PRODUCE BOUGHT HERE", "paid in chitin", ""]
	for k: StringName in ITEMS:
		var p := float(_prices.get(k, 0.0))
		var base := float(MarketPrices.BASE[k])
		var trend := "  (high!)" if p > base * 1.15 else ("  (low)" if p < base * 0.85 else "")
		lines.append("%s ... %.1f%s" % [NAMES[k], p, trend])
	lines.append("")
	lines.append("SEEDS SOLD (scrap)")
	for s: StringName in SEEDS:
		lines.append("%s ... %d" % [str((SEEDS[s] as Array)[0]), seed_cost(s)])
	_label.text = "\n".join(lines)


## Lines on the counter: the four vegetables to sell, then the four seeds to buy.
static func _line(i: int) -> StringName:
	var n := ITEMS.size() + SEEDS.size()
	i = i % n
	return ITEMS[i] if i < ITEMS.size() else SEEDS.keys()[i - ITEMS.size()]


func cycle_option() -> void:
	selected = (selected + 1) % (ITEMS.size() + SEEDS.size())


func interact_prompt() -> String:
	var item := _line(selected)
	if SEEDS.has(item):
		var info: Array = SEEDS[item]
		return "Vendor: buy %s for %d scrap each\nE: buy one (hold to keep buying)   F: next line" % [str(info[0]).to_lower(), seed_cost(item)]
	var p := float(_prices.get(item, 0.0))
	return "Vendor: sell %s for %.1f chitin each\nE: sell one (hold to keep selling)   F: next line" % [NAMES[item], p]


func local_interact(_holding: bool) -> void:
	var item := _line(selected)
	if multiplayer.is_server():
		_sell(multiplayer.get_unique_id(), item)
	else:
		_request_sell.rpc_id(1, item)


@rpc("any_peer", "reliable")
func _request_sell(item: StringName) -> void:
	if multiplayer.is_server():
		_sell(multiplayer.get_remote_sender_id(), item)


func _sell(peer_id: int, item: StringName) -> void:
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	if SEEDS.has(item):
		var info: Array = SEEDS[item]
		var cost := seed_cost(item)
		if Economy.spend(payer, {&"scrap": cost}):
			Economy.earn(payer, {item: 1})
			_ka_ching.rpc()
		else:
			Economy.notify(peer_id, "%s cost %d scrap each." % [str(info[0]), cost])
		return
	if not ITEMS.has(item):
		return
	if not Economy.spend(payer, {item: 1}):
		Economy.notify(peer_id, "You have no %s to sell. Grow some on a farm plot." % String(NAMES[item]).to_lower())
		return
	_credit[payer] = float(_credit.get(payer, 0.0)) + market.sell(item, 1)
	var whole := int(floor(float(_credit[payer])))
	if whole > 0:
		_credit[payer] = float(_credit[payer]) - whole
		Economy.earn(payer, {&"chitin": whole})
	_ka_ching.rpc()


@rpc("authority", "call_local", "unreliable")
func _ka_ching() -> void:
	Audio.play_at(&"coin", global_position, -4.0)
