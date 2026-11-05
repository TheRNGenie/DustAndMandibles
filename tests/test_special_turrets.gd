extends TestCase
## The Steam Cannon, Flood Gate, Twin Mortar and Bola Launcher: their special
## shots (SpecialShotRules, applied by TurretEffects), stat lines, kill methods,
## models and registration.

const KillMethod := preload("res://scenes/bugs/kill_method.gd")
const NEW: Array[StringName] = [&"steam_cannon", &"flood_gate", &"twin_mortar", &"bola_launcher"]


## Stand-in for BugStatus (slow / root).
class FakeStatus:
	extends RefCounted
	var slow_factor := 1.0
	var root_t := 0.0

	func slow(factor: float, _seconds: float) -> void:
		slow_factor = minf(slow_factor, factor)

	func root(seconds: float) -> void:
		root_t = maxf(root_t, seconds)

	func is_rooted() -> bool:
		return root_t > 0.0


## Stand-in for a climbing Bug: the fields and methods the rules use.
class FakeBug:
	extends RefCounted
	var def: BugDef
	var boss: Variant = null
	var climb_y := 0.0
	var lane_z := 0.0
	var position := Vector3.ZERO
	var climbing := true
	var fell := -1.0
	var status := FakeStatus.new()

	func is_alive() -> bool:
		return true

	func is_climbing() -> bool:
		return climbing

	func knock_off(_source: String, _cliff: int) -> void:
		fell = climb_y
		climb_y = 0.0


func _bug(id: StringName, y: float, lane_z: float = 0.0, boss: bool = false) -> FakeBug:
	var b := FakeBug.new()
	b.def = Defs.bug(id)
	b.climb_y = y
	b.lane_z = lane_z
	b.position = Vector3(0, y, lane_z)
	if boss:
		b.boss = RefCounted.new()
	return b


func test_registered_and_buildable() -> void:
	var cliff := Defs.category_items("Cliff Turrets")
	var guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/field_guide.json"))
	for id in NEW:
		var d := Defs.turret(id)
		assert_true(d != null, "%s registered" % id)
		assert_eq(d.id, id)
		assert_true(Defs.BUILD_ORDER.has(id), "%s in the build order" % id)
		assert_true(cliff.has(id), "%s on the Cliff Turrets tab" % id)
		assert_true(Defs.gets_scaffold(id), "%s stands on a scaffold like other cliff turrets" % id)
		assert_true(d.role != "" and d.weakness != "", "%s has a job and a weakness" % id)
		assert_true(d.special != &"", "%s has a special shot" % id)
		assert_false(d.anti_air or d.guards_plateau or d.crewed, "%s shoots climbers on the far wall" % id)
		var parts := TurretBuilder.build(id, Palette.TEAM_WEST)
		for k: String in ["base", "head", "gun"]:
			var m := parts[k] as ArrayMesh
			assert_true(m != null and m.get_surface_count() > 0, "%s has a %s mesh" % [id, k])
		assert_true((guide["turrets"] as Dictionary).has(String(id)), "%s has a field guide entry" % id)


func test_stat_lines_name_the_special() -> void:
	var steam := Defs.turret(&"steam_cannon").stat_line()
	assert_true(steam.contains("Knocks 3 Off"), steam)
	assert_false(steam.contains("Knocks Bugs Off"), "no plain knockback line: " + steam)
	assert_true(steam.contains("x0.5 vs Heavy"), steam)
	var flood := Defs.turret(&"flood_gate").stat_line()
	assert_true(flood.contains("Floods a 9 m Lane"), flood)
	assert_true(flood.contains("1 Shot / 20 s"), flood)
	var twin := Defs.turret(&"twin_mortar").stat_line()
	assert_true(twin.contains("Fire + Blast 3 m"), twin)
	assert_false(twin.contains("Splash"), twin)
	var bola := Defs.turret(&"bola_launcher").stat_line()
	assert_true(bola.contains("Tangles 2 Bugs 3.5 s"), bola)
	assert_false(bola.contains("Pins"), bola)
	assert_true(Defs.turret(&"twin_mortar").role_line().contains("Upkeep: 1 chili, 1 chitin a shot"), Defs.turret(&"twin_mortar").role_line())
	# Older turrets keep their plain lines.
	assert_true(Defs.turret(&"water_cannon").stat_line().contains("Knocks Bugs Off"))
	assert_true(Defs.turret(&"chili_mortar").stat_line().contains("Burning Patch 3 m"))


func test_kill_methods() -> void:
	assert_eq(KillMethod.classify("Logan's Twin Mortar"), KillMethod.BLAST)
	assert_eq(KillMethod.classify("Logan's Twin Mortar" + SpecialShotRules.FIRE_SHELL), KillMethod.FIRE)
	assert_eq(KillMethod.classify("Logan's Bola Launcher"), KillMethod.TRAP)
	assert_eq(KillMethod.classify("Logan's Steam Cannon"), KillMethod.OTHER)
	assert_eq(KillMethod.classify("Logan's Flood Gate"), KillMethod.OTHER)


func test_steam_cone_shape() -> void:
	var m := Vector3.ZERO
	var axis := Vector3(0, 0, -1)
	var a := SpecialShotRules.STEAM_HALF_ANGLE_DEG
	assert_true(SpecialShotRules.in_cone(m, axis, Vector3(0, 0, -40), a, 60.0), "on the axis")
	assert_true(SpecialShotRules.in_cone(m, axis, Vector3(5, 0, -40), a, 60.0), "5 m off at 40 m (7 deg)")
	assert_false(SpecialShotRules.in_cone(m, axis, Vector3(9, 0, -40), a, 60.0), "9 m off at 40 m (13 deg)")
	assert_false(SpecialShotRules.in_cone(m, axis, Vector3(0, 0, -70), a, 60.0), "past its reach")
	assert_false(SpecialShotRules.in_cone(m, axis, Vector3(0, 0, 10), a, 60.0), "behind the nozzle")


func test_steam_knocks_off_the_highest_three_and_slows_the_rest() -> void:
	var mites: Array = [_bug(&"dust_mite", 10), _bug(&"dust_mite", 50), _bug(&"dust_mite", 20), _bug(&"dust_mite", 40), _bug(&"dust_mite", 30)]
	var beetle := _bug(&"rattler_beetle", 30)
	var caught: Array = mites + [beetle]
	var n := SpecialShotRules.steam_wash(caught, 3, "test", 0)
	assert_eq(n, 3, "three knocked off")
	assert_eq(mites[1].fell, 50.0, "the 50 m mite fell")
	assert_eq(mites[3].fell, 40.0, "the 40 m mite fell")
	assert_eq(mites[4].fell, 30.0, "the 30 m mite fell")
	assert_eq(mites[0].climb_y, 10.0, "the 10 m mite held on")
	assert_eq(mites[2].climb_y, 20.0, "the 20 m mite held on")
	assert_almost(mites[0].status.slow_factor, SpecialShotRules.STEAM_SLOW, 0.001, "left in the steam: slowed")
	assert_almost(mites[2].status.slow_factor, SpecialShotRules.STEAM_SLOW, 0.001, "left in the steam: slowed")
	assert_almost(mites[1].status.slow_factor, 1.0, 0.001, "fallen bugs aren't slowed")
	assert_eq(beetle.fell, -1.0, "heavy bugs never fall")
	assert_almost(beetle.climb_y, 30.0 - SpecialShotRules.HEAVY_SLIP, 0.001, "heavy bugs only slip")
	assert_almost(beetle.status.slow_factor, SpecialShotRules.STEAM_SLOW, 0.001, "and are slowed")


func test_steam_knocks_none_off_when_only_heavies() -> void:
	var a := _bug(&"rattler_beetle", 30)
	var b := _bug(&"brood_mother", 20)
	assert_eq(SpecialShotRules.steam_wash([a, b], 3, "test", 0), 0)
	assert_almost(a.climb_y, 27.0, 0.001)
	assert_almost(b.climb_y, 17.0, 0.001)


func test_steam_on_a_boss_is_small_and_spaced_out() -> void:
	var boss := _bug(&"rattler_beetle", 40, 0.0, true)
	SpecialShotRules.steam_wash([boss], 3, "test", 0)
	assert_almost(boss.climb_y, 40.0 - SpecialShotRules.BOSS_SLIP, 0.001, "a boss slips a little")
	assert_almost(boss.status.slow_factor, SpecialShotRules.STEAM_BOSS_SLOW, 0.001, "and is barely slowed")
	SpecialShotRules.steam_wash([boss], 3, "test", 0)
	assert_almost(boss.climb_y, 40.0 - SpecialShotRules.BOSS_SLIP, 0.001, "no second slip within the gap")
	# The boss never uses up a knock: the mite still falls.
	var mite := _bug(&"dust_mite", 12)
	assert_eq(SpecialShotRules.steam_wash([boss, mite], 1, "test", 0), 1)
	assert_eq(mite.climb_y, 0.0, "the mite still falls")


func test_boss_slip_gap_is_shared_by_every_water_turret() -> void:
	var boss := _bug(&"rattler_beetle", 40, 0.0, true)
	assert_almost(SpecialShotRules.slip_for(boss, 3.0), SpecialShotRules.BOSS_SLIP)
	# A flood straight after a water / steam hit can't slip it again.
	SpecialShotRules.flood_wash([boss], "test", 0)
	assert_almost(boss.climb_y, 40.0, 0.001, "the flood finds the boss inside its gap")


func test_flood_band_is_one_lane_wide() -> void:
	var bugs: Array = [_bug(&"dust_mite", 20, 0.0), _bug(&"dust_mite", 50, 3.0), _bug(&"wolf_spider", 5, -4.4), _bug(&"dust_mite", 30, 6.0), _bug(&"dust_mite", 30, -8.0)]
	bugs.append(_bug(&"dust_mite", 0, 1.0))
	bugs[5].climbing = false # on the plateau already: not on the wall
	var band := SpecialShotRules.flood_band(bugs, 0.0, Defs.turret(&"flood_gate").effect_size * 0.5)
	assert_eq(band.size(), 3, "the three climbers within 4.5 m of the lane")
	assert_true(band.has(bugs[0]) and band.has(bugs[1]) and band.has(bugs[2]))
	assert_true(Defs.turret(&"flood_gate").effect_size >= 8.0, "at least a lane wide (lanes are 8 m apart)")


func test_flood_washes_small_bugs_and_heavies_slip() -> void:
	var mite := _bug(&"dust_mite", 45)
	var spider := _bug(&"wolf_spider", 25)
	var beetle := _bug(&"rattler_beetle", 30)
	var boss := _bug(&"brood_mother", 40, 0.0, true)
	var washed := SpecialShotRules.flood_wash([mite, spider, beetle, boss], "test", 0)
	assert_eq(washed, 2, "both small bugs washed off")
	assert_eq(mite.fell, 45.0)
	assert_eq(spider.fell, 25.0)
	assert_almost(beetle.climb_y, 30.0 - SpecialShotRules.FLOOD_SLIP, 0.001, "heavy bugs slip")
	assert_almost(boss.climb_y, 40.0 - SpecialShotRules.BOSS_SLIP, 0.001, "a boss only slips a little")
	SpecialShotRules.flood_wash([boss], "test", 0)
	assert_almost(boss.climb_y, 40.0 - SpecialShotRules.BOSS_SLIP, 0.001, "and not again within the gap")
	var low := _bug(&"rattler_beetle", 2)
	SpecialShotRules.flood_wash([low], "test", 0)
	assert_eq(low.climb_y, 0.0, "never slips below the foot of the wall")


func test_flood_gate_is_a_long_cooldown() -> void:
	var d := Defs.turret(&"flood_gate")
	assert_true(d.fire_interval >= 15.0, "refills slowly")
	assert_true(d.cost_scrap > Defs.turret(&"water_cannon").cost_scrap * 3, "a late, pricey turret")


func test_twin_mortar_fire_shell_lands_above_the_blast() -> void:
	var aim := Vector3(22, 30, 4)
	var fire := SpecialShotRules.twin_fire_point(aim)
	assert_true(fire.y > aim.y, "the pack climbs up into the fire")
	assert_almost(fire.distance_to(aim), SpecialShotRules.TWIN_FIRE_ABOVE, 0.001)
	var d := Defs.turret(&"twin_mortar")
	assert_true(SpecialShotRules.TWIN_FIRE_ABOVE < d.effect_size * 2.0, "the two patches touch")
	assert_true(d.flight_time > Defs.turret(&"dynamite_lobber").flight_time, "slower than the Dynamite Lobber: fast bugs dodge it")
	assert_true(d.fire_interval > Defs.turret(&"dynamite_lobber").fire_interval, "a slow salvo")
	assert_false(d.anti_air, "never fires at fliers")


func test_bola_tangles_the_target_and_its_nearest_neighbour() -> void:
	var target := _bug(&"dust_mite", 20, 0.0)
	var near := _bug(&"dust_mite", 22, 1.0)
	var nearer := _bug(&"wolf_spider", 20, 1.5)
	var far := _bug(&"dust_mite", 20, 9.0)
	var held := _bug(&"dust_mite", 20, 0.5)
	held.status.root(3.0)
	var all: Array = [target, near, nearer, far, held]
	var pos := func(b: Object) -> Vector3: return b.get("position")
	var got := SpecialShotRules.bola_pick(target, all, 2, pos)
	assert_eq(got.size(), 2)
	assert_eq(got[0], target, "the target first")
	assert_eq(got[1], nearer, "then the nearest bug not already held")
	var three := SpecialShotRules.bola_pick(target, all, 3, pos)
	assert_eq(three.size(), 3)
	assert_false(three.has(far), "too far for another bola")
	assert_false(three.has(held), "already tangled")
	assert_eq(SpecialShotRules.bola_pick(target, [target], 2, pos).size(), 1, "alone: just the target")


func test_bola_hold_times() -> void:
	var secs := Defs.turret(&"bola_launcher").effect_size
	var mite := _bug(&"dust_mite", 20)
	var beetle := _bug(&"rattler_beetle", 20)
	var boss := _bug(&"rattler_beetle", 20, 0.0, true)
	assert_almost(SpecialShotRules.bola_time(mite, secs), secs)
	assert_almost(SpecialShotRules.bola_time(beetle, secs), secs * SpecialShotRules.BOLA_HEAVY)
	assert_almost(SpecialShotRules.bola_time(boss, secs), SpecialShotRules.BOSS_BOLA, 0.001, "a boss shrugs it off quickly")
	assert_almost(SpecialShotRules.bola_time(boss, secs), 0.0, 0.001, "and can't be held again straight away")
	assert_true(Defs.turret(&"bola_launcher").damage <= 2.0, "almost no damage")
	assert_eq(Defs.turret(&"bola_launcher").special_count, 2, "two bugs a throw")
