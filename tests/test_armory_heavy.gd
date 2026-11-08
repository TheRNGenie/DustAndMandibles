extends TestCase
## The heavies' (and two primaries') specials (ArmoryHeavyRules): mortar flight
## and blast falloff, the flame and acid cones, acid exposure and stripping,
## pins and trap holds (bosses shorter), trap clearing and the cap, rocket
## lock-on and flight path, the fx number packing, and the ricochet bounce.


func test_mortar_flight_and_arc() -> void:
	assert_almost(ArmoryHeavyRules.mortar_flight(0.0), ArmoryHeavyRules.MORTAR_FLIGHT_MIN)
	assert_almost(ArmoryHeavyRules.mortar_flight(200.0), ArmoryHeavyRules.MORTAR_FLIGHT_MAX)
	assert_almost(ArmoryHeavyRules.mortar_flight(900.0), ArmoryHeavyRules.MORTAR_FLIGHT_MAX, 0.001, "capped")
	assert_true(ArmoryHeavyRules.mortar_flight(50.0) < ArmoryHeavyRules.mortar_flight(150.0))
	var a := Vector3(0, 60, 0)
	var b := Vector3(40, 30, 0)
	assert_true(ArmoryHeavyRules.mortar_at(a, b, 0.0).is_equal_approx(a), "starts at the muzzle")
	assert_true(ArmoryHeavyRules.mortar_at(a, b, 1.0).is_equal_approx(b), "lands on the point")
	assert_true(ArmoryHeavyRules.mortar_at(a, b, 0.5).y > a.y + 5.0, "a high arc")


func test_blast_falloff() -> void:
	assert_almost(ArmoryHeavyRules.blast_share(0.0, 6.0), 1.0)
	assert_almost(ArmoryHeavyRules.blast_share(6.0, 6.0), ArmoryHeavyRules.BLAST_EDGE)
	assert_almost(ArmoryHeavyRules.blast_share(6.1, 6.0), 0.0, 0.001, "outside the radius")
	assert_true(ArmoryHeavyRules.blast_share(2.0, 6.0) > ArmoryHeavyRules.blast_share(4.0, 6.0))


func test_cones() -> void:
	var o := Vector3.ZERO
	var fwd := Vector3(0, 0, -1)
	assert_true(ArmoryHeavyRules.in_flame(o, fwd, Vector3(0, 0, -10), 15.0))
	assert_false(ArmoryHeavyRules.in_flame(o, fwd, Vector3(0, 0, -16), 15.0), "past the 15 m reach")
	assert_false(ArmoryHeavyRules.in_flame(o, fwd, Vector3(8, 0, -8), 15.0), "45 degrees off")
	assert_true(ArmoryHeavyRules.in_acid(o, fwd, Vector3(1, 0, -17), 18.0))
	assert_false(ArmoryHeavyRules.in_acid(o, fwd, Vector3(0, 0, 5), 18.0), "behind")


func test_burn_scales_with_rarity() -> void:
	var common := ArmoryHeavyRules.burn_dps(0)
	var rare := ArmoryHeavyRules.burn_dps(WeaponMods.with_level(0, GunRarity.RARE))
	assert_almost(common, ArmoryHeavyRules.FIRE_BURN_DPS)
	assert_true(rare > common)
	assert_almost(ArmoryHeavyRules.burn_time(&"fire_lance", 0), 4.0)


func test_acid_exposure_strips_after_two_seconds() -> void:
	var e := 0.0
	var puffs := 0
	var gap := 1000.0 # the first puff
	while not ArmoryHeavyRules.acid_strips(e) and puffs < 50:
		e = ArmoryHeavyRules.acid_exposure(e, gap, 0.2)
		gap = 0.2
		puffs += 1
	assert_eq(puffs, 10, "2 s of sustained 0.2 s puffs")
	# A pause past the grace fades it; a short one does not.
	assert_almost(ArmoryHeavyRules.acid_exposure(1.0, 0.3, 0.2), 1.2)
	assert_true(ArmoryHeavyRules.acid_exposure(1.0, 1.45, 0.2) < 0.25)
	assert_almost(ArmoryHeavyRules.acid_exposure(1.0, 100.0, 0.2), 0.2, 0.001, "starts over")
	assert_almost(ArmoryHeavyRules.acid_strip_time(&"acid_drencher", 0), 10.0)


func test_pins_and_traps() -> void:
	assert_almost(ArmoryHeavyRules.ballista_pin(false, &"harpoon_ballista", 0), 3.0)
	assert_almost(ArmoryHeavyRules.ballista_pin(true, &"harpoon_ballista", 0), 1.0, 0.001, "bosses shrug it off")
	assert_almost(ArmoryHeavyRules.trap_root(false, &"bear_trap_launcher", 0), 3.0)
	assert_true(ArmoryHeavyRules.trap_root(true, &"bear_trap_launcher", 0) < 3.0)
	var epic := WeaponMods.with_level(0, GunRarity.EPIC)
	assert_true(ArmoryHeavyRules.trap_root(false, &"bear_trap_launcher", epic) > 3.0, "rarity holds longer")
	assert_true(ArmoryHeavyRules.trap_catches(1.0, 0.5))
	assert_false(ArmoryHeavyRules.trap_catches(3.0, 0.5))


func test_traps_clear_only_when_a_wave_ends() -> void:
	assert_false(ArmoryHeavyRules.traps_clear(false, false), "build-phase traps wait")
	assert_false(ArmoryHeavyRules.traps_clear(false, true), "the wave starting keeps them")
	assert_false(ArmoryHeavyRules.traps_clear(true, true))
	assert_true(ArmoryHeavyRules.traps_clear(true, false), "the wave ended")


func test_trap_cap() -> void:
	assert_eq(ArmoryHeavyRules.trap_cap(&"bear_trap_launcher", 0), ArmoryHeavyRules.TRAP_CAP)
	assert_eq(ArmoryHeavyRules.trap_to_evict(ArmoryHeavyRules.TRAP_CAP - 1), -1)
	assert_eq(ArmoryHeavyRules.trap_to_evict(ArmoryHeavyRules.TRAP_CAP), 0, "the oldest goes")
	assert_eq(ArmoryHeavyRules.trap_to_evict(7, 8), -1, "a mod's extra traps")


func test_rocket_lock_on() -> void:
	var o := Vector3.ZERO
	var fwd := Vector3(0, 0, -1)
	var spots: Array[Vector3] = [Vector3(0, 0, -100), Vector3(10, 0, -40), Vector3(40, 0, -40), Vector3(0, 0, 40)]
	assert_eq(ArmoryHeavyRules.rocket_pick(o, fwd, spots, 250.0), 1, "the nearest within 30 degrees")
	assert_eq(ArmoryHeavyRules.rocket_pick(o, fwd, spots, 30.0), -1, "out of range")
	var none: Array[Vector3] = [Vector3(40, 0, -40)]
	assert_eq(ArmoryHeavyRules.rocket_pick(o, fwd, none, 250.0), -1, "45 degrees off: no lock")


func test_rocket_path() -> void:
	var start := Vector3.ZERO
	var fwd := Vector3(0, 0, -1)
	var target := Vector3(30, 0, -120)
	var path := ArmoryHeavyRules.rocket_path(start, fwd, target, true)
	assert_true(ArmoryHeavyRules.rocket_at(path, 0.0).is_equal_approx(start))
	assert_true(ArmoryHeavyRules.rocket_at(path, 1.0).distance_to(target) < 0.01, "ends on the bug")
	var leg := ArmoryHeavyRules.ROCKET_SPEED * ArmoryHeavyRules.ROCKET_STRAIGHT
	assert_true(path[1].is_equal_approx(fwd * leg), "flies straight first")
	var flight := ArmoryHeavyRules.rocket_flight(path)
	assert_true(flight > start.distance_to(target) / ArmoryHeavyRules.ROCKET_SPEED - 0.01)
	assert_true(flight < 3.0)
	var straight := ArmoryHeavyRules.rocket_path(start, fwd, Vector3(0, 0, -70), false)
	assert_true(ArmoryHeavyRules.rocket_at(straight, 0.5).distance_to(Vector3(0, 0, -35)) < 0.5, "no lock: a straight line")


func test_fx_number_packing() -> void:
	for d: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0.3, 0.2), Vector3(-0.5, -0.8, 0.1), Vector3(0.01, 0.99, 0.0)]:
		var x := ArmoryHeavyRules.pack_rocket(d, true)
		assert_true(ArmoryHeavyRules.rocket_dir(x).dot(d.normalized()) > 0.999, "dir %s" % d)
		assert_true(ArmoryHeavyRules.rocket_homing(x))
		assert_false(ArmoryHeavyRules.rocket_homing(ArmoryHeavyRules.pack_rocket(d, false)))
	var b := ArmoryHeavyRules.pack_blast(1.37, 6.6)
	assert_almost(ArmoryHeavyRules.blast_flight(b), 1.37, 0.001)
	assert_almost(ArmoryHeavyRules.blast_radius(b), 6.6, 0.001)


func test_ricochet_bounce() -> void:
	var out := ArmoryHeavyRules.bounce_dir(Vector3(1, -1, 0).normalized(), Vector3.UP)
	assert_true(out.is_equal_approx(Vector3(1, 1, 0).normalized()), "mirrors off the surface")
	assert_true(ArmoryHeavyRules.bounces_off(false, false), "rock")
	assert_true(ArmoryHeavyRules.bounces_off(true, true), "a heavy shell")
	assert_false(ArmoryHeavyRules.bounces_off(true, false), "a soft bug stops it")
	assert_almost(ArmoryHeavyRules.RICOCHET_MULT, 0.6)


func test_wired_specials() -> void:
	for s: StringName in [&"mortar", &"fire", &"ballista", &"acid", &"rocket", &"beartrap", &"ricochet", &"pierce_line"]:
		assert_true(ArmoryHeavyRules.handled(s), "%s has rules" % s)
	assert_true(ResourceLoader.exists(ArmoryHeavyRules.HOST_PATH), "the host helper exists")
