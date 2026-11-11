extends TestCase
## Carrying crops and the cellar's ammo workbench (Nov 11 playtest fixes).


func test_carry_caps_at_25_each() -> void:
	var c := PlayerCarry.new()
	assert_eq(c.add(&"corn", 20), 20)
	assert_eq(c.add(&"corn", 10), 5, "only 5 more fit")
	assert_eq(c.amount(&"corn"), PlayerCarry.CAP)
	assert_eq(c.add(&"cotton", 3), 3, "each kind has its own 25")
	assert_false(c.take(&"cotton", 4), "all or nothing")
	assert_true(c.take(&"cotton", 3))
	assert_eq(c.carried(), {&"corn": 25}, "empty kinds drop off the list")
	c.free()


func test_food_items_map_to_crops() -> void:
	assert_eq(PlayerCarry.crop_of_item(&"chili"), &"firecracker_chili")
	assert_eq(PlayerCarry.item_of(&"firecracker_chili"), &"chili")
	assert_eq(PlayerCarry.crop_of_item(&"corn"), &"corn")
	assert_eq(PlayerCarry.crop_of_item(&"herbs"), &"herbs")
	assert_eq(PlayerCarry.crop_of_item(&"water"), &"", "water isn't carried")


func test_harvests_give_raw_crops_not_sacks() -> void:
	var want := {&"corn": [&"corn", 1], &"firecracker_chili": [&"chili", 1], &"prickly_pear": [&"prickly_pear", 1],
		&"herbs": [&"herbs", 1], &"sarsaparilla": [&"sarsaparilla", 1], &"cotton": [&"cotton", 1],
		&"sulfur_root": [&"sulfur_root", 1], &"barrel_cactus": [&"barrel_cactus", 1], &"tumbleweed_vine": [&"tumbleweed_vine", 1]}
	for id: StringName in want:
		var out := Defs.crop(id).harvest_out()
		assert_eq(int(out.get(want[id][0], 0)), int(want[id][1]), "%s raw" % id)
		assert_false(out.has(Defs.crop(id).load_item), "%s: no sacks from the plot" % id)


func test_the_bench_makes_three_a_crop() -> void:
	assert_eq(HarvestRules.SACKS_PER_CROP, AmmoBenchMenu.PER_CROP, "the menu and the bench agree")
	assert_eq(HarvestRules.convertible(5, 12, 500), 5)
	assert_eq(HarvestRules.convertible(20, 12, 500), 12, "no more than you carry")
	assert_eq(HarvestRules.convertible(10, 12, 7), 2, "no more than the bin has room for")
	assert_eq(HarvestRules.convertible(10, 12, 0), 0)
	assert_eq(AmmoStore.CELLAR_CAP, 500)
	assert_true(AmmoStore.has_cellar(0), "every house has its cellar")
