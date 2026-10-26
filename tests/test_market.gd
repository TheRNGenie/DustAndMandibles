extends TestCase
## Vendor prices: selling lowers them (down to -50%), waiting raises them (up to +50%).


func test_starts_at_base_price() -> void:
	var m := MarketPrices.new()
	assert_almost(m.price(&"corn"), 1.0)
	assert_almost(m.price(&"herbs"), 2.2)


func test_selling_lowers_the_price_but_not_below_half() -> void:
	var m := MarketPrices.new()
	var first := m.sell(&"corn", 1)
	assert_almost(first, 1.0)
	assert_true(m.price(&"corn") < 1.0)
	m.sell(&"corn", 100)
	assert_almost(m.price(&"corn"), 0.5)


func test_selling_one_item_leaves_others_alone() -> void:
	var m := MarketPrices.new()
	m.sell(&"corn", 5)
	assert_almost(m.price(&"chili"), 1.2)


func test_prices_recover_up_to_one_and_a_half() -> void:
	var m := MarketPrices.new()
	m.sell(&"corn", 100)
	m.tick(60.0)
	assert_true(m.price(&"corn") > 0.5)
	m.tick(100000.0)
	assert_almost(m.price(&"corn"), 1.5)


func test_unknown_items_are_worthless() -> void:
	var m := MarketPrices.new()
	assert_almost(m.sell(&"scrap", 3), 0.0)
