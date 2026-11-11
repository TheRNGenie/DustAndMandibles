extends TestCase
## The crop bag's UI rules (CropBagUI, playtest fixes Nov 2026): what a left
## click would do to a crop-fed turret, the card it shows, the wheel's picker,
## and the ammo workbench's rows (AmmoBenchMenu).


## A crop-fed turret as the bag sees it (UniversalTurret's duck-typed face).
class FakeTurret extends Node:
	var crop: StringName = &""
	var tier := 0
	var def := TurretDef.new()
	var in_wave := false
	var stock: Dictionary = {}
	var loads: Array = []

	func _init() -> void:
		def.display_name = "Crop Hopper"

	func can_load_now() -> bool:
		return not in_wave or crop == &""

	func sacks_of(c: StringName) -> int:
		return int(stock.get(c, 0))

	func request_load(c: StringName) -> void:
		loads.append(c)


class FakeBag extends RefCounted:
	var set_crop: StringName = &""
	var out := true

	func sacks_of(c: StringName) -> int:
		return 4 if c == &"corn" else 0

	func is_out() -> bool:
		return out

	func set_bag_crop(c: StringName) -> void:
		set_crop = c


func test_feed_rules() -> void:
	var t := FakeTurret.new()
	t.stock = {&"corn": 4}
	assert_eq(CropBagUI.feed(t, &""), CropBagUI.Feed.UNSET, "no crop set")
	assert_eq(CropBagUI.feed(t, &"corn"), CropBagUI.Feed.LOAD, "empty turret, corn in stock")
	assert_eq(CropBagUI.feed(t, &"cotton"), CropBagUI.Feed.NO_STOCK, "no cotton sacks")
	t.crop = &"corn"
	assert_eq(CropBagUI.feed(t, &"corn"), CropBagUI.Feed.SAME, "already corn")
	t.stock[&"herbs"] = 2
	assert_eq(CropBagUI.feed(t, &"herbs"), CropBagUI.Feed.SWAP, "build phase: a loaded turret swaps")
	t.in_wave = true
	assert_eq(CropBagUI.feed(t, &"herbs"), CropBagUI.Feed.BUSY, "mid-wave: only an empty turret takes a sack")
	assert_eq(CropBagUI.feed(null, &"corn"), CropBagUI.Feed.NONE, "nothing aimed at")
	var plain := Node.new()
	assert_eq(CropBagUI.feed(plain, &"corn"), CropBagUI.Feed.NONE, "not a crop-fed turret")
	plain.free()
	t.free()


func test_prompt_card_text() -> void:
	var t := FakeTurret.new()
	t.stock = {&"corn": 12}
	var p := CropBagUI.prompt(t, &"corn")
	assert_true(p.begins_with("@bag:"), "a bag card")
	var info: Dictionary = JSON.parse_string(p.substr(5))
	assert_eq(str(info["name"]), "Crop Hopper")
	assert_eq(int(info["have"]), 12)
	assert_true(str((info["keys"] as Array)[0][1]).begins_with("Load Corn"), "left click loads corn")
	var plain := Node.new()
	assert_eq(CropBagUI.prompt(plain, &"corn"), "", "no card for a non-turret")
	plain.free()
	t.free()


func test_wheel_sets_the_bag() -> void:
	var bag := FakeBag.new()
	var w := CropBagUI.Wheel.new(bag)
	assert_eq(w.crop, &"", "starts empty")
	assert_true(w.can_pick(&"cotton"), "any crop can be set, stock or not")
	w.request_load(&"cotton")
	assert_eq(bag.set_crop, &"cotton")
	assert_eq(w.crop, &"cotton", "the wheel rings the set crop")
	assert_false(w.can_pick(&"cotton"), "the set crop is already set")
	assert_true(w.wheel_status().contains("Cotton"))
	assert_eq(w.sacks_of(&"corn"), 4, "the wheel shows the bag's counts")
	bag.out = false
	assert_false(w.can_load_now(), "the wheel closes when the bag is put away")


func test_bench_rows_and_convert() -> void:
	var bench := AmmoBenchMenu.DemoBench.new()
	var m := AmmoBenchMenu.new(bench)
	var rows := m.menu_items(0)
	assert_eq(rows.size(), CropEffects.IDS.size(), "a row per crop")
	assert_eq(str(rows[0]["id"]), "convert:corn", "the crops you carry come first (corn: 12)")
	var corn: Dictionary = rows[0]
	assert_eq(int(corn["quantity"]["max"]), 12, "all 12 carried corn fit the bin")
	var chili: Dictionary = rows.filter(func(r: Dictionary) -> bool: return str(r["id"]) == "convert:firecracker_chili")[0]
	assert_true(str(chili["disabled"]).contains("full"), "498 of 500: no room for 3 more")
	m.menu_press("convert:corn", &"convert:5")
	assert_eq(bench.raw_of(&"corn"), 7)
	assert_eq(bench.sacks_of(&"corn"), 55, "5 corn make 15 sacks")
