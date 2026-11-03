extends TestCase
## Crewed: the four 2 x 2 crewed guns: data, footprint, build rules and the pure
## maths in CrewRules (unmanned power, Bertha's heat, the Whaler's drop, Thunder
## Mule's salvo and arc, Sky Hound's fuse, aim arcs).

const CREWED: Array[StringName] = [&"big_bertha", &"whaler", &"thunder_mule", &"sky_hound"]


func test_crewed_defs_are_registered_and_listed() -> void:
	var cat := Defs.category_items("Crewed Guns")
	assert_eq(cat.size(), CREWED.size(), "Crewed Guns tab lists all four")
	var names: Array = Defs.BUILD_CATEGORIES.map(func(c: Dictionary) -> String: return str(c["name"]))
	assert_eq(names.find("Crewed Guns"), names.find("Cliff Turrets") + 1, "tab sits right after Cliff Turrets")
	for id in CREWED:
		assert_true(Defs.is_crewed(id), "%s is crewed" % id)
		assert_true(cat.has(id), "%s in the tab" % id)
		assert_true(Defs.BUILD_ORDER.has(id), "%s in BUILD_ORDER" % id)
		assert_true(CrewedBuilder.has(id), "%s has a model" % id)
	assert_false(Defs.is_crewed(&"gatling_post"))
	assert_false(Defs.is_crewed(&"farm_plot"))


func test_crewed_guns_cost_more_than_any_normal_turret() -> void:
	var priciest := 0
	for id: StringName in Defs.TURRETS:
		# Tiers: the new Mid / Late guns (gen/tier_builder.gd) sit in the crewed price band by design.
		if not Defs.is_crewed(id) and not TierBuilder.has(id):
			priciest = maxi(priciest, Defs.cost_of(id))
	for id in CREWED:
		var c := Defs.cost_of(id)
		assert_true(c >= priciest * 1.5 and c <= priciest * 2, "%s costs %d (1.5-2x %d)" % [id, c, priciest])


func test_crewed_roles_and_no_upkeep() -> void:
	for id in CREWED:
		var d := Defs.turret(id)
		assert_true(d.role != "" and d.weakness != "", "%s has a job and a weakness" % id)
		assert_false(d.has_upkeep(), "%s keeps it simple: no upkeep" % id)
		assert_true(d.crew_yaw_arc_deg > 0.0 and d.crew_yaw_arc_deg <= 180.0, "%s arc" % id)
	assert_true(Defs.turret(&"sky_hound").anti_air, "Sky Hound is air defence")
	assert_true(Defs.turret(&"whaler").heavy_mult > 1.0, "Whaler is a big-game gun")
	assert_true(Defs.turret(&"big_bertha").heavy_mult < 1.0, "Bertha is a swarm gun")


func test_crewed_footprint_is_two_by_two_and_no_scaffold() -> void:
	for id in CREWED:
		var fp := Buildable.footprint(id, Vector2i(3, 5))
		assert_eq(fp.size(), 4, "%s is 2 x 2" % id)
		assert_true(fp.has(Vector2i(4, 6)), "%s covers the far corner" % id)
		assert_false(Defs.gets_scaffold(id), "%s never gets a scaffold" % id)
	assert_eq(Buildable.footprint(&"gatling_post", Vector2i(3, 5)).size(), 1)
	assert_true(Defs.gets_scaffold(&"gatling_post"), "normal turrets still do")


func test_unmanned_is_half_power() -> void:
	assert_eq(CrewRules.UNMANNED_MULT, 0.5)


func test_bertha_spin_up_and_fire_rate() -> void:
	var spin := 0.0
	for i in 10:
		spin = CrewRules.spin_step(spin, true, 0.05)
	assert_true(spin > CrewRules.SPIN_FIRE_MIN and spin < 1.0, "half a second spins her partway (%.2f)" % spin)
	assert_eq(CrewRules.spin_interval(0.06, 0.1), INF, "no fire before the barrels are turning")
	assert_almost(CrewRules.spin_interval(0.06, 1.0), 0.06)
	assert_true(CrewRules.spin_interval(0.06, 0.5) > CrewRules.spin_interval(0.06, 1.0), "faster as she spins up")
	assert_eq(CrewRules.spin_step(1.0, true, 1.0), 1.0, "spin caps at 1")
	assert_eq(CrewRules.spin_step(0.1, false, 1.0), 0.0, "winds down to 0")


func test_bertha_overheats_and_cools() -> void:
	var heat := 0.0
	var hot := false
	var t := 0.0
	# Steady fire at full spin (about 16 rounds a second) overheats in a few seconds.
	while not hot and t < 20.0:
		var h := CrewRules.heat_step(heat, hot, 1, true, 0.06)
		heat = h[0]
		hot = h[1]
		t += 0.06
	assert_true(hot, "she overheats")
	assert_true(t > 3.0 and t < 8.0, "after a good long burst (%.1f s)" % t)
	# Held trigger or not, overheated barrels cool until RESUME_HEAT.
	var cool_t := 0.0
	while hot and cool_t < 10.0:
		var h := CrewRules.heat_step(heat, hot, 0, true, 0.1)
		heat = h[0]
		hot = h[1]
		cool_t += 0.1
	assert_false(hot, "cools down")
	assert_true(cool_t > 1.0 and cool_t < 3.0, "cool-down takes a moment (%.1f s)" % cool_t)
	assert_true(heat <= CrewRules.RESUME_HEAT + 0.001)
	# Holding fire without shooting a round this tick doesn't cool her.
	var h2 := CrewRules.heat_step(0.5, false, 0, true, 0.1)
	assert_almost(h2[0], 0.5)
	var h3 := CrewRules.heat_step(0.5, false, 0, false, 0.1)
	assert_true(float(h3[0]) < 0.5, "letting go cools")


func test_whaler_reel_and_drop() -> void:
	assert_almost(CrewRules.reel_step(20.0, 0.5), CrewRules.REEL_SPEED * 0.5)
	assert_almost(CrewRules.reel_step(0.4, 1.0), 0.4, 0.001, "never below the canyon floor")
	assert_eq(CrewRules.reel_step(0.0, 1.0), 0.0)
	assert_eq(CrewRules.drop_damage(0.0, 0), 0.0)
	assert_almost(CrewRules.drop_damage(10.0, 0), 10.0 * CrewRules.DROP_DAMAGE_PER_M)
	assert_true(CrewRules.drop_damage(10.0, 2) > CrewRules.drop_damage(10.0, 0), "upgrades hit harder")
	# A full chain's worth of reeling is a big hit, a boss-sized one.
	var d := Defs.turret(&"whaler")
	assert_true(CrewRules.drop_damage(CrewRules.REEL_SPEED * d.effect_size, 0) >= 100.0)


func test_mule_salvo_is_three_shells_and_deterministic() -> void:
	var a := CrewRules.salvo_offsets(7)
	var b := CrewRules.salvo_offsets(7)
	assert_eq(a.size(), CrewRules.SALVO)
	assert_eq(a, b, "same seed, same landing points on every peer")
	assert_eq(a[0], Vector2.ZERO, "first shell dead centre")
	assert_true(a[1].x < 0.0 and a[2].x > 0.0, "the others land either side")
	for o in a:
		assert_true(absf(o.x) <= CrewRules.SALVO_SPREAD.x + 0.001 and absf(o.y) <= CrewRules.SALVO_SPREAD.y + 0.001)
	assert_true(CrewRules.salvo_offsets(8) != a, "a new salvo scatters differently")


func test_mule_arc_matches_the_shell() -> void:
	var from := Vector3(0, 60, 0)
	var to := Vector3(80, 40, 10)
	assert_eq(CrewRules.lob_point(from, to, 0.0), from)
	assert_true(CrewRules.lob_point(from, to, 1.0).is_equal_approx(to))
	var mid := CrewRules.lob_point(from, to, 0.5)
	assert_true(mid.y > (from.y + to.y) * 0.5 + 3.0, "it arcs up over the straight line")
	assert_true(CrewRules.lob_time(100.0) > CrewRules.lob_time(30.0), "longer shots fly longer")
	assert_true(CrewRules.lob_pitch_deg(100.0, 115.0) > CrewRules.lob_pitch_deg(20.0, 115.0), "tubes lift for far shots")


func test_hound_fuse_picks_the_first_flier_near_the_path() -> void:
	var origin := Vector3.ZERO
	var dir := Vector3(0, 0, -1)
	var fliers: Array = [Vector3(0, 0, -50), Vector3(1.5, 0, -30), Vector3(10, 0, -20), Vector3(0, 0, 10)]
	assert_eq(CrewRules.fuse_index(origin, dir, fliers, 75.0), 1, "nearest along the path, within the fuse")
	assert_eq(CrewRules.fuse_index(origin, dir, [Vector3(10, 0, -20)], 75.0), -1, "too far off the path")
	assert_eq(CrewRules.fuse_index(origin, dir, [Vector3(0, 0, -90)], 75.0), -1, "out of range")
	assert_eq(CrewRules.fuse_index(origin, dir, [Vector3(0, 0, 5)], 75.0), -1, "never behind the gun")


func test_aim_arcs_clamp() -> void:
	var c := CrewRules.clamp_aim(deg_to_rad(100.0), deg_to_rad(-60.0), 75.0, 38.0, 30.0)
	assert_almost(rad_to_deg(c.x), 75.0, 0.01)
	assert_almost(rad_to_deg(c.y), -38.0, 0.01)
	var ok := CrewRules.clamp_aim(deg_to_rad(10.0), deg_to_rad(5.0), 75.0, 38.0, 30.0)
	assert_almost(rad_to_deg(ok.x), 10.0, 0.01)
	assert_almost(rad_to_deg(ok.y), 5.0, 0.01)
	var wrapped := CrewRules.clamp_aim(deg_to_rad(350.0), 0.0, 75.0, 38.0, 30.0)
	assert_almost(rad_to_deg(wrapped.x), -10.0, 0.01, "angles wrap")
