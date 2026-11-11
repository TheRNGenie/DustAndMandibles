extends TestCase
## Vendor prices: selling lowers them (down to -50%), waiting raises them (up to +50%).


func test_starts_at_base_price() -> void:
	var m := MarketPrices.new()
	assert_almost(m.price(&"corn"), 10.0)
	assert_almost(m.price(&"herbs"), 22.0)


func test_selling_lowers_the_price_but_not_below_half() -> void:
	var m := MarketPrices.new()
	var first := m.sell(&"corn", 1)
	assert_almost(first, 10.0)
	assert_true(m.price(&"corn") < 10.0)
	m.sell(&"corn", 100)
	assert_almost(m.price(&"corn"), 5.0)


func test_selling_one_item_leaves_others_alone() -> void:
	var m := MarketPrices.new()
	m.sell(&"corn", 5)
	assert_almost(m.price(&"chili"), float(MarketPrices.BASE[&"chili"]))


func test_prices_recover_up_to_one_and_a_half() -> void:
	var m := MarketPrices.new()
	m.sell(&"corn", 100)
	m.tick(60.0)
	assert_true(m.price(&"corn") > 5.0)
	m.tick(100000.0)
	assert_almost(m.price(&"corn"), 15.0)


func test_unknown_items_are_worthless() -> void:
	var m := MarketPrices.new()
	assert_almost(m.sell(&"scrap", 3), 0.0)


func test_seed_costs_a_third_of_the_harvest_value() -> void:
	if MarketPrices.FLAT_SEED > 0:
		return # (every seed is one flat price for now)
	# Herbs: 2 herbs x 22 scrap = 44 scrap; a third is 15.
	assert_eq(MarketPrices.seed_price(Defs.crop(&"herbs")), 15)
	# Corn is the cheap crop: a fixed 8 scrap per seed.
	assert_eq(MarketPrices.seed_price(Defs.crop(&"corn")), 8)
	# Chili is a fixed 20 scrap per seed (Logan's call).
	assert_eq(MarketPrices.seed_price(Defs.crop(&"firecracker_chili")), 20)


## Every crop sells at the vendor for team chitin; only sarsaparilla pays your
## own scrap (Logan, Nov 11).
func test_every_crop_sells_and_only_sarsaparilla_pays_your_scrap() -> void:
	assert_eq(MarketPrices.currency(&"sarsaparilla"), &"chitin")
	for k: StringName in [&"corn", &"prickly_pear", &"chili", &"herbs", &"cotton", &"sulfur_root", &"barrel_cactus", &"tumbleweed_vine"]:
		assert_eq(MarketPrices.currency(k), &"scrap", "%s pays team chitin" % k)
	for c: StringName in [&"corn", &"prickly_pear", &"firecracker_chili", &"herbs", &"cotton", &"sulfur_root", &"barrel_cactus", &"tumbleweed_vine", &"sarsaparilla"]:
		var item := PlayerCarry.item_of(c)
		assert_true(MarketPrices.BASE.has(item), "%s has a vendor price" % item)
		assert_true(VendorCart.ITEMS.has(item), "%s is on the vendor's list" % item)


## For now every seed is 10 team chitin and every crop has a price of its own
## that sales push down (Logan, Nov 11).
func test_every_seed_is_ten_and_every_crop_has_its_own_price() -> void:
	var seen := {}
	for id: StringName in Defs.CROPS:
		var c := Defs.crop(id)
		assert_eq(MarketPrices.seed_price(c), 10, "%s seeds" % c.id)
		var p := float(MarketPrices.BASE[PlayerCarry.item_of(c.id)])
		assert_false(seen.has(p), "%s shares its price" % c.id)
		seen[p] = true
	var m := MarketPrices.new()
	m.sell(&"cotton", 3)
	assert_true(m.price(&"cotton") < float(MarketPrices.BASE[&"cotton"]), "sales push the price down")
