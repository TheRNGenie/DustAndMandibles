extends TestCase
## Weather: roll odds, and how rain and snow treat crops.


func test_roll_favours_clear_and_snow_is_rare() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := [0, 0, 0, 0, 0]
	for i in 4000:
		counts[Weather.roll(rng)] += 1
	assert_true(counts[Weather.Kind.CLEAR] > counts[Weather.Kind.WINDY])
	assert_true(counts[Weather.Kind.WINDY] > counts[Weather.Kind.THUNDERSTORM])
	assert_true(counts[Weather.Kind.SNOW] > 0)
	assert_true(counts[Weather.Kind.SNOW] < counts[Weather.Kind.THUNDERSTORM])


func test_rain_waters_and_speeds_crops() -> void:
	var g := CropGrowth.new()
	var corn := Defs.crop(&"corn")
	g.plant(corn)
	g.tick(corn.grow_time * 0.4, Weather.crop_rate(Weather.Kind.LIGHT_RAIN))
	assert_eq(g.stage, CropGrowth.Stage.GROWING)
	assert_almost(g.fraction(), 0.6)


func test_snow_frosts_growing_crops() -> void:
	var g := CropGrowth.new()
	var corn := Defs.crop(&"corn")
	g.plant(corn)
	g.water()
	g.tick(corn.grow_time * 0.5)
	var before := g.fraction()
	g.tick(10.0, 0.0, Weather.frost_rate(Weather.Kind.SNOW))
	assert_true(g.fraction() < before)
	g.tick(10000.0, 0.0, Weather.frost_rate(Weather.Kind.SNOW))
	assert_almost(g.fraction(), 0.0)


func test_clear_is_standard_rules() -> void:
	assert_almost(Weather.crop_rate(Weather.Kind.CLEAR), 1.0)
	assert_almost(Weather.frost_rate(Weather.Kind.CLEAR), 0.0)
	assert_almost(Weather.bug_speed(Weather.Kind.CLEAR), 1.0)
	assert_almost(Weather.turret_accuracy(Weather.Kind.CLEAR), 1.0)
	assert_false(Weather.is_rain(Weather.Kind.CLEAR))
