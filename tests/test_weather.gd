extends TestCase
## Weather: roll odds, and how rain and snow treat crops.


func test_roll_favours_clear_and_snow_is_rare() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := [0, 0, 0, 0, 0, 0, 0, 0, 0]
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


func test_blood_moon_only_at_night() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var day_moons := 0
	var night_moons := 0
	for i in 3000:
		if Weather.roll(rng, false) == Weather.Kind.BLOOD_MOON:
			day_moons += 1
		if Weather.roll(rng, true) == Weather.Kind.BLOOD_MOON:
			night_moons += 1
	assert_eq(day_moons, 0)
	assert_true(night_moons > 0)
	assert_true(Weather.is_night(0.0))
	assert_false(Weather.is_night(12.0))


func test_temperature_and_its_effects() -> void:
	var noon := Weather.temperature(15.0, Weather.Kind.CLEAR)
	var night := Weather.temperature(3.0, Weather.Kind.CLEAR)
	assert_true(noon > 95.0 and noon < 110.0)
	assert_true(night < 65.0)
	assert_true(Weather.temperature(15.0, Weather.Kind.HEAT_WAVE) > noon)
	assert_true(Weather.temperature(12.0, Weather.Kind.SNOW) < 50.0)
	assert_almost(Weather.crop_temp_rate(75.0), 1.0)
	assert_true(Weather.crop_temp_rate(115.0) < 1.0)
	assert_true(Weather.bug_temp_speed(35.0) < Weather.bug_temp_speed(100.0))


func test_fog_lanterns_and_dust() -> void:
	assert_true(Weather.turret_range(Weather.Kind.FOG) < 1.0)
	assert_almost(Weather.turret_range(Weather.Kind.FOG, true), 1.0)
	assert_true(Weather.turret_range(Weather.Kind.DUST_STORM) < Weather.turret_range(Weather.Kind.FOG))
	assert_eq(Weather.chitin_mult(Weather.Kind.BLOOD_MOON), 2)
