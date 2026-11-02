extends TestCase
## Coverage heat map and the bugs' weak-spot bias.


func test_heat_colors() -> void:
	assert_true(CoverageRules.heat_color(0).r > 0.9 and CoverageRules.heat_color(0).g < 0.4, "none is red")
	assert_true(CoverageRules.heat_color(1).r > 0.9 and CoverageRules.heat_color(1).g > 0.5, "one is amber")
	assert_true(CoverageRules.heat_color(2).g > 0.8 and CoverageRules.heat_color(2).r < 0.5, "two is green")
	assert_eq(CoverageRules.heat_color(5), CoverageRules.heat_color(2))


func test_count_covering_uses_arc_rules() -> void:
	var muzzle := Vector3(0, 60, 0)
	var arcs := [[muzzle, 30.0, 50.0], [muzzle + Vector3(0, 0, 30), 30.0, 50.0]]
	# Straight across, level: both in range? first yes (40 m), second 50 m away.
	assert_eq(CoverageRules.count_covering(arcs, Vector3(45, 60, 0)), 1)
	assert_eq(CoverageRules.count_covering(arcs, Vector3(30, 60, 15)), 2)
	# Far below the look-down limit: nobody.
	assert_eq(CoverageRules.count_covering(arcs, Vector3(10, 20, 0)), 0)


func test_bias_prefers_weak_spot_but_not_always() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var weak := 0
	var n := 4000
	for i in n:
		if CoverageRules.pick_weakest([1.0, 0.0], [rng.randf(), rng.randf()]) == 1:
			weak += 1
	var share := float(weak) / n
	assert_true(share > 0.75, "weak spot picked %.2f" % share)
	assert_true(share < 0.95, "still wanders into cover sometimes (%.2f)" % share)


func test_bias_even_when_equal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var first := 0
	for i in 2000:
		if CoverageRules.pick_weakest([1.0, 1.0], [rng.randf(), rng.randf()]) == 0:
			first += 1
	assert_true(absf(first / 2000.0 - 0.5) < 0.05)
