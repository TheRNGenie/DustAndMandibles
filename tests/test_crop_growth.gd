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
	assert_eq(int(out.get(&"corn", 0)), 3)
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
	assert_eq(int(out.get(&"prickly_pear", 0)), 2)
	assert_eq(int(out.get(&"water", 0)), 1)


func test_weevil_clears_growing_crop() -> void:
	var g := CropGrowth.new()
	g.plant(_corn())
	g.water()
	g.tick(30.0)
	g.clear()
	assert_eq(g.stage, CropGrowth.Stage.EMPTY)
