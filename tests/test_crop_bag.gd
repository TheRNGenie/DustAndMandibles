extends TestCase
## The crop bag (CropBag, Nov 11 playtest fixes): only crop-fed turrets on your
## own cliff answer it, and only LOAD / SWAP feed them.


class FakeTurret extends Node:
	var cliff_id := 0
	var crop: StringName = &""
	var tier := 0
	var def := TurretDef.new()
	var in_wave := false
	var stock := 3
	var loads: Array = []

	func can_load_now() -> bool:
		return not in_wave or crop == &""

	func sacks_of(_c: StringName) -> int:
		return stock

	func request_load(c: StringName) -> void:
		loads.append(c)


func test_only_your_own_crop_fed_turrets() -> void:
	var t := FakeTurret.new()
	t.cliff_id = 0
	assert_true(CropBag.feedable(t, 0), "your own cliff")
	assert_false(CropBag.feedable(t, 1), "never the partner's turrets")
	var plain := Node.new()
	assert_false(CropBag.feedable(plain, 0), "not a crop-fed turret")
	assert_false(CropBag.feedable(null, 0))
	t.free()
	plain.free()


func test_what_a_click_does() -> void:
	var t := FakeTurret.new()
	assert_eq(CropBagUI.feed(t, &""), CropBagUI.Feed.UNSET, "nothing set")
	assert_eq(CropBagUI.feed(t, &"corn"), CropBagUI.Feed.LOAD, "empty turret loads")
	t.crop = &"herbs"
	assert_eq(CropBagUI.feed(t, &"corn"), CropBagUI.Feed.SWAP, "build phase swaps")
	t.in_wave = true
	assert_eq(CropBagUI.feed(t, &"corn"), CropBagUI.Feed.BUSY, "mid-wave a loaded one won't swap")
	t.in_wave = false
	t.stock = 0
	assert_eq(CropBagUI.feed(t, &"corn"), CropBagUI.Feed.NO_STOCK)
	assert_eq(CropBagUI.feed(t, &"herbs"), CropBagUI.Feed.SAME)
	assert_almost(CropBagUI.REACH, 15.0, 0.01, "the bag's reach")
	assert_true(CropBagUI.REACH > PlayerVitals.INTERACT_REACH, "longer than E's")
	t.free()


func test_highlight_colours() -> void:
	var t := FakeTurret.new()
	assert_eq(CropBag.mark_color(t), CropBag.EMPTY_COLOR, "empty crop-fed: red")
	t.crop = &"corn"
	assert_eq(CropBag.mark_color(t), CropBag.LOADED_COLOR, "loaded: green")
	var plain := Node.new()
	assert_eq(CropBag.mark_color(plain), CropBag.OTHER_COLOR, "not crop-fed: orange")
	t.free()
	plain.free()
