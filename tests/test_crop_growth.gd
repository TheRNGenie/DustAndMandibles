extends TestCase
## Crop growth: plant, water, grow, pause when unwatered, harvest.


func _corn() -> CropDef:
	return Defs.crop(&"corn")


func test_unwatered_crop_does_not_grow() -> void:
	var g := CropGrowth.new()
	assert_true(g.plant(_corn()))
	g.tick(1000.0)
	assert_eq(g.stage, CropGrowth.Stage.PLANTED)
	assert_almost(g.fraction(), 0.0)


func test_watered_crop_grows_and_ripens() -> void:
	var g := CropGrowth.new()
	g.plant(_corn())
	assert_true(g.water())
	g.tick(_corn().grow_time * 0.5)
	assert_almost(g.fraction(), 0.5)
	assert_eq(g.stage, CropGrowth.Stage.GROWING)
	g.tick(_corn().grow_time)
	assert_eq(g.stage, CropGrowth.Stage.RIPE)


func test_harvest_yields_and_clears() -> void:
	var g := CropGrowth.new()
	g.plant(_corn())
	g.water()
	assert_true(g.harvest().is_empty(), "not ripe yet")
	g.tick(10000.0)
	var out := g.harvest()
	# (Nov 11: harvests give the raw crop; the cellar's workbench makes the sacks.)
	assert_eq(int(out.get(&"corn_load", 0)), 0, "no turret loads from the plot")
	assert_eq(int(out.get(&"corn", 0)), 1, "one corn to carry")
	assert_eq(g.stage, CropGrowth.Stage.EMPTY)


func test_cannot_plant_twice_or_water_twice() -> void:
	var g := CropGrowth.new()
	assert_true(g.plant(_corn()))
	assert_false(g.plant(Defs.crop(&"firecracker_chili")))
	assert_true(g.water())
	assert_false(g.water())


func test_prickly_pear_gives_pears_and_water() -> void:
	var g := CropGrowth.new()
	g.plant(Defs.crop(&"prickly_pear"))
	g.water()
	g.tick(10000.0)
	var out := g.harvest()
	assert_eq(int(out.get(&"prickly_pear_load", 0)), 0)
	assert_eq(int(out.get(&"prickly_pear", 0)), 1)
	assert_eq(int(out.get(&"water", 0)), 2)


func test_weevil_clears_growing_crop() -> void:
	var g := CropGrowth.new()
	g.plant(_corn())
	g.water()
	g.tick(30.0)
	g.clear()
	assert_eq(g.stage, CropGrowth.Stage.EMPTY)


# ---- each crop has a job (Gameplay helper) ----

func test_corn_is_fastest_and_pear_slowest() -> void:
	var corn := Defs.crop(&"corn")
	for id: StringName in [&"prickly_pear", &"firecracker_chili", &"herbs"]:
		assert_true(corn.grow_time < Defs.crop(id).grow_time, "corn ripens before %s" % id)
		assert_true(Defs.crop(&"prickly_pear").grow_time >= Defs.crop(id).grow_time, "pear is the slowest")
	assert_almost(corn.grow_time, 120.0)
	assert_almost(Defs.crop(&"prickly_pear").grow_time, 300.0)


func test_growth_times_hold_in_crop_growth() -> void:
	for id: StringName in [&"corn", &"prickly_pear", &"firecracker_chili", &"herbs"]:
		var c := Defs.crop(id)
		var g := CropGrowth.new()
		g.plant(c)
		g.water()
		g.tick(c.grow_time - 1.0)
		assert_true(g.stage != CropGrowth.Stage.RIPE, "%s not ripe a second early" % id)
		g.tick(1.0)
		assert_eq(g.stage, CropGrowth.Stage.RIPE, "%s ripe on time" % id)


func test_corn_seeds_are_cheapest() -> void:
	var corn := MarketPrices.seed_price(Defs.crop(&"corn"))
	for id: StringName in [&"prickly_pear", &"firecracker_chili", &"herbs"]:
		assert_true(corn < MarketPrices.seed_price(Defs.crop(id)), "corn seeds cheaper than %s" % id)


func test_chili_feeds_the_mortar_and_sells_for_team_chitin() -> void:
	assert_eq(CropEffects.sack_of(&"firecracker_chili"), &"chili_load", "a chili sack loads any crop-fed turret with chili")
	assert_true(Defs.turret(&"cf_harvest_mortar").ammo_cost.is_empty(), "no per-shot upkeep any more")
	assert_eq(MarketPrices.currency(&"chili"), &"scrap")
	assert_true(Defs.crop(&"firecracker_chili").water_cost > Defs.crop(&"corn").water_cost, "chili is thirsty")


func test_every_crop_has_a_role() -> void:
	for id: StringName in [&"corn", &"prickly_pear", &"firecracker_chili", &"herbs"]:
		assert_true(Defs.crop(id).role != "", "%s has a role line" % id)
