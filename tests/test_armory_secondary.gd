extends TestCase
## The new secondaries' specials (ArmorySecondaryRules): the pure rules and the
## host's lasting effects (armory_secondary_zones.gd), driven with stand-in bugs.
## (The rules script itself leans on PlayerNet, which doesn't compile under the
## bare test runner, so its wiring is checked in the source text.)

const Zones := preload("res://scenes/fx/armory_secondary_zones.gd")
## ArmoryEffects.SECONDARY (the router loads the fx, which needs autoloads).
const SPECIALS: Array[String] = ["scream", "tar", "flash", "pepper", "concuss", "chain", "rust", "lure", "caltrops",
	"phosphor"]


## Stand-in for BugStatus.
class FakeStatus:
	extends RefCounted
	var slow_factor := 1.0
	var root_t := 0.0
	var burn_dps := 0.0

	func slow(factor: float, _seconds: float) -> void:
		slow_factor = minf(slow_factor, factor)

	func root(seconds: float) -> void:
		root_t = maxf(root_t, seconds)

	func burn(dps: float, _seconds: float, _source: String, _cliff: int) -> void:
		burn_dps = maxf(burn_dps, dps)


class FakeHealth:
	extends RefCounted
	var taken := 0.0

	func take_damage(amount: float, _source: String, _cliff: int) -> void:
		taken += amount


class FakeClimber:
	extends RefCounted
	var target_z := 0.0


## Stand-in for a Bug: the fields and methods the zones use.
class FakeBug:
	extends RefCounted
	var def: BugDef
	var boss: Variant = null
	var state := 0
	var cliff_id := 0
	var lane_z := 0.0
	var climb_y := 20.0
	var ground_pos := Vector3.ZERO
	var global_position := Vector3.ZERO
	var crowd_r := 0.5
	var latched := false
	var entombed := 0.0
	var status := FakeStatus.new()
	var health := FakeHealth.new()
	var _climber := FakeClimber.new()
	var hits := 0.0

	func is_alive() -> bool:
		return true

	func is_hidden() -> bool:
		return state == 4

	func receive_hit(damage: float, _p: Vector3, _d: Vector3, _pierce: bool, _m: float, _s: String, _c: int) -> void:
		hits += damage


func _small() -> BugDef:
	var d := BugDef.new()
	d.max_hp = 20.0
	d.walk_speed = 2.5
	return d


func _heavy() -> BugDef:
	var d := BugDef.new()
	d.max_hp = 5000.0
	d.front_armor = 0.5
	return d


## A climber at lane `lane`, height `y` (its world spot: canyon-style, x = 0).
func _climber(lane: float, y: float) -> FakeBug:
	var b := FakeBug.new()
	b.def = _small()
	b.state = Zones.ST_CLIMBING
	b.lane_z = lane
	b.climb_y = y
	b.global_position = Vector3(0, y, lane)
	return b


func _walker(p: Vector3, state: int = Zones.ST_BREACHING) -> FakeBug:
	var b := FakeBug.new()
	b.def = _small()
	b.state = state
	b.ground_pos = p
	b.global_position = p
	return b


func test_states_mirror_bug() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/bugs/bug.gd")
	assert_true(src.contains("enum State { CLIMBING, CRESTING, BREACHING, DEAD, BURROWED, FLYING, CROSSING, SLEEPING, HUNTING }"),
			"Zones.ST_* mirror Bug.State")


func test_every_special_is_wired() -> void:
	var rules := FileAccess.get_file_as_string("res://components/armory_secondary_rules.gd")
	var fx := FileAccess.get_file_as_string("res://scenes/fx/armory_secondary_fx.gd")
	var router := FileAccess.get_file_as_string("res://components/armory_effects.gd")
	for s in SPECIALS:
		assert_true(rules.contains('&"%s"' % s), "rules handle %s" % s)
		assert_true(router.contains('&"%s"' % s), "router knows %s" % s)
	for k in ["sec_tar", "sec_rust", "sec_scream", "sec_flash", "sec_pepper", "sec_concuss", "sec_chain", "sec_lure",
			"sec_caltrops", "sec_caltrops_clear", "sec_phosphor"]:
		assert_true(rules.contains('&"%s"' % k), "rules send %s" % k)
		assert_true(fx.contains('&"%s":' % k), "fx draws %s" % k)
	var guns := ["tar_sprayer", "rust_duster", "screamer_pistol", "flashbang_pistol", "pepper_bomb_pistol",
			"concussion_pistol", "chain_binder", "glow_worm_launcher", "caltrops_launcher", "phosphor_grenade"]
	for w in guns:
		assert_true(SPECIALS.has(String(Defs.weapon(StringName(w)).special)), "%s has one of these specials" % w)


func test_where_a_bug_is() -> void:
	assert_eq(Zones.where(_climber(0, 10)), Zones.Where.WALL)
	assert_eq(Zones.where(_walker(Vector3.ZERO)), Zones.Where.GROUND)
	assert_eq(Zones.where(_walker(Vector3.ZERO, Zones.ST_CROSSING)), Zones.Where.GROUND)
	assert_eq(Zones.where(_walker(Vector3.ZERO, Zones.ST_FLYING)), Zones.Where.AIR)
	assert_eq(Zones.where(_walker(Vector3.ZERO, Zones.ST_CRESTING)), Zones.Where.NONE)
	assert_eq(Zones.where(_walker(Vector3.ZERO, Zones.ST_BURROWED)), Zones.Where.NONE)
	var stuck := _climber(0, 10)
	stuck.latched = true
	assert_eq(Zones.where(stuck), Zones.Where.NONE, "latch bugs stay clamped")


func test_radius_cone_and_line_picks() -> void:
	var near := _walker(Vector3(3, 0, 0))
	var far := _walker(Vector3(20, 0, 0))
	var under := _walker(Vector3(1, 0, 0), Zones.ST_BURROWED)
	var bugs := [near, far, under]
	assert_eq(Zones.in_radius(bugs, Vector3.ZERO, 12.0), [near], "burrowed bugs can't be reached")
	assert_eq(Zones.in_cone(bugs, Vector3(-1, 0, 0), Vector3.RIGHT, 15.0, 10.0), [near])
	var off := _walker(Vector3(10, 0, 3))
	var line := Zones.along_line([far, off, near, _walker(Vector3(-5, 0, 0))], Vector3.ZERO, Vector3.RIGHT, 30.0, 1.0, 3)
	assert_eq(line, [near, far], "nearest first, off the line and behind left out")
	assert_eq(Zones.along_line([far, near], Vector3.ZERO, Vector3.RIGHT, 30.0, 1.0, 1, [near]), [far], "skip and count")
	assert_eq(Zones.along_line([far, near], Vector3.ZERO, Vector3.RIGHT, 10.0, 1.0, 4), [near], "no further than reach")


func test_caltrop_patch_shape_on_any_surface() -> void:
	# On the floor (normal up): a flat disc.
	assert_true(Zones.on_patch(Vector3(3, 0.5, 0), Vector3.ZERO, Vector3.UP, 4.0))
	assert_false(Zones.on_patch(Vector3(5, 0, 0), Vector3.ZERO, Vector3.UP, 4.0))
	assert_false(Zones.on_patch(Vector3(0, 3, 0), Vector3.ZERO, Vector3.UP, 4.0), "flattened")
	# On a cliff face (normal sideways): tall along the wall, thin off it.
	assert_true(Zones.on_patch(Vector3(0.5, 3, 0), Vector3.ZERO, Vector3.RIGHT, 4.0))
	assert_false(Zones.on_patch(Vector3(3, 0, 0), Vector3.ZERO, Vector3.RIGHT, 4.0))
	# A shot into the open air (no normal) lies flat.
	assert_true(Zones.on_patch(Vector3(2, 0, 2), Vector3.ZERO, Vector3.ZERO, 4.0))


func test_scatter_drift_moves_climbers_along_the_wall() -> void:
	var z := Zones.new()
	var b := _climber(5.0, 30.0)
	z.add_drift(b, Vector2(3.5, -1.0), Vector3.ZERO, 1.0)
	for i in 10:
		z.step(0.1, [])
	z.step(0.001, [])
	assert_almost(b.lane_z, 8.5, 0.01, "pushed sideways")
	assert_almost(b.climb_y, 29.0, 0.01, "and a little down")
	assert_almost(b._climber.target_z, b.lane_z, 0.01, "its climbing brain doesn't steer back")
	assert_true(z.drifts.is_empty(), "the drift ends")
	# Clamped to the lanes.
	var edge := _climber(17.0, 30.0)
	z.add_drift(edge, Vector2(10.0, 0.0), Vector3.ZERO, 1.0)
	z.step(1.0, [])
	assert_almost(edge.lane_z, Zones.LANE_HALF, 0.01)
	z.free()


func test_knockback_drift_on_the_ground() -> void:
	var z := Zones.new()
	var b := _walker(Vector3.ZERO)
	# The concussion's 8 m over its push time.
	z.add_drift(b, Vector2.ZERO, Vector3.RIGHT * 8.0 / 0.35, 0.35)
	for i in 7:
		z.step(0.05, [])
	assert_almost(b.ground_pos.x, 8.0, 0.05, "tumbled 8 m back")
	z.free()


func test_away_directions() -> void:
	assert_eq(Zones.away_lane(4.0, 1.0), 1.0)
	assert_eq(Zones.away_lane(-4.0, 1.0), -1.0)
	assert_eq(Zones.away_lane(1.0, 1.0, -1.0), -1.0, "dead level: the tie-break")
	assert_almost(Zones.away_flat(Vector3(0, 5, 3), Vector3.ZERO).z, 1.0, 0.001, "flat, outward")


func test_lure_pulls_bugs_but_not_bosses() -> void:
	var z := Zones.new()
	var climber := _climber(0.0, 20.0)
	var walker := _walker(Vector3(10, 0, 0))
	var boss := _walker(Vector3(8, 0, 0))
	boss.boss = RefCounted.new()
	var far := _walker(Vector3(40, 0, 0))
	z.add_lure(Vector3(0, 24, 6), 15.0, 5.0)
	z.add_lure(Vector3(0, 0, 0), 15.0, 5.0)
	var bugs := [climber, walker, boss, far]
	z.step(0.5, bugs)
	assert_true(climber.lane_z > 0.0, "climber slides toward the grub's lane")
	assert_true(climber.climb_y > 20.0, "and up toward it")
	assert_true(walker.ground_pos.x < 10.0, "ground bug walks to it")
	assert_almost(walker.status.slow_factor, Zones.LURE_SLOW, 0.001, "its own way slowed")
	assert_eq(boss.ground_pos.x, 8.0, "bosses ignore it")
	assert_eq(far.ground_pos.x, 40.0, "out of range")
	# Never pulled past the grub.
	for i in 46:
		z.step(0.1, bugs)
	assert_true(walker.ground_pos.x >= Zones.LURE_STOP - 0.01)
	assert_true(z.lures.is_empty(), "the glow fades after its time")
	z.free()


func test_caltrops_bite_slow_and_cap_per_shooter() -> void:
	var z := Zones.new()
	var on := _walker(Vector3(1, 0, 1))
	var flier := _walker(Vector3(0, 0.5, 0), Zones.ST_FLYING)
	var off := _walker(Vector3(9, 0, 0))
	z.add_caltrops(Vector3.ZERO, Vector3.UP, 4.0, 10.0, 12.0, 7, "Ann", 0)
	z.step(0.01, [on, flier, off])
	assert_eq(on.hits, 10.0, "one step's damage")
	assert_almost(on.status.slow_factor, Zones.CALTROP_SLOW, 0.001)
	assert_eq(flier.hits, 0.0, "fliers sail over")
	assert_eq(off.hits, 0.0)
	z.step(0.3, [on])
	assert_eq(on.hits, 10.0, "not again before the next step")
	z.step(0.3, [on])
	assert_eq(on.hits, 20.0)
	# A third patch from the same shooter lifts the oldest; another shooter's stays.
	assert_eq(z.add_caltrops(Vector3(20, 0, 0), Vector3.UP, 4.0, 10.0, 12.0, 7, "Ann", 0).size(), 0)
	z.add_caltrops(Vector3(40, 0, 0), Vector3.UP, 4.0, 10.0, 12.0, 8, "Bo", 1)
	var lifted := z.add_caltrops(Vector3(60, 0, 0), Vector3.UP, 4.0, 10.0, 12.0, 7, "Ann", 0)
	assert_eq(lifted, [Vector3.ZERO] as Array[Vector3])
	assert_eq(z.caltrops.size(), 3)
	# A mod for more patches.
	assert_eq(z.add_caltrops(Vector3(80, 0, 0), Vector3.UP, 4.0, 10.0, 12.0, 7, "Ann", 0, 3).size(), 0)
	z.step(13.0, [])
	assert_true(z.caltrops.is_empty(), "patches run out")
	z.free()


func test_phosphor_burns_half_for_heavies_and_pushes_out() -> void:
	var z := Zones.new()
	var small := _walker(Vector3(1, 0, 0))
	var heavy := _walker(Vector3(-1, 0, 0))
	heavy.def = _heavy()
	var wall := _climber(1.0, 0.0)
	z.add_fire(Vector3.ZERO, Vector3.UP, 5.0, 10.0, 6.0, "Ann", 0)
	z.step(0.1, [small, heavy, wall])
	assert_eq(small.status.burn_dps, 10.0)
	assert_eq(heavy.status.burn_dps, 5.0, "heavies take half")
	assert_true(small.ground_pos.x > 1.0 and heavy.ground_pos.x < -1.0, "pushed out of the fire")
	assert_true(wall.lane_z > 1.0, "climbers sidestep round it")
	z.step(6.0, [])
	assert_true(z.fires.is_empty())
	z.free()


func test_berserk_ground_bug_bites_nearest() -> void:
	var z := Zones.new()
	var mad := _walker(Vector3.ZERO)
	var near := _walker(Vector3(5, 0, 0))
	var other := _walker(Vector3(9, 0, 0))
	z.add_berserk(mad, 20.0, 3.0, "Ann", 0)
	var bugs := [mad, near, other]
	z.step(0.1, bugs)
	assert_true(mad.ground_pos.x > 0.0, "goes for the nearest")
	for i in 40:
		z.step(0.05, bugs)
		mad.global_position = mad.ground_pos
	assert_true(near.health.taken > 0.0, "and bites it")
	assert_eq(other.health.taken, 0.0)
	z.step(3.0, bugs)
	assert_true(z.berserk.is_empty(), "the frenzy wears off")
	z.free()
