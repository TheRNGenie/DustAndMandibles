extends TestCase
## The cross-defense rule: turrets only ever shoot the other cliff's climbers.


func test_turret_cannot_target_own_cliff() -> void:
	assert_false(Targeting.cliff_allows(WorldLayout.WEST, WorldLayout.WEST, true))
	assert_false(Targeting.cliff_allows(WorldLayout.EAST, WorldLayout.EAST, true))


func test_turret_targets_partner_cliff() -> void:
	assert_true(Targeting.cliff_allows(WorldLayout.WEST, WorldLayout.EAST, true))
	assert_true(Targeting.cliff_allows(WorldLayout.EAST, WorldLayout.WEST, true))


func test_breachers_are_never_turret_targets() -> void:
	assert_false(Targeting.cliff_allows(WorldLayout.WEST, WorldLayout.EAST, false))
	assert_false(Targeting.cliff_allows(WorldLayout.EAST, WorldLayout.WEST, false))


func test_pitch_limit_blocks_straight_down() -> void:
	var muzzle := Vector3(-23.0, 61.0, 0.0)
	# Own cliff face, almost straight below.
	assert_false(Targeting.in_arc(muzzle, Vector3(-24.5, 40.0, 0.0), 30.0, 100.0))
	# Far cliff, upper part: reachable.
	assert_true(Targeting.in_arc(muzzle, Vector3(23.0, 50.0, 0.0), 30.0, 100.0))


func test_range_limit() -> void:
	assert_false(Targeting.in_arc(Vector3.ZERO, Vector3(200.0, 0.0, 0.0), 30.0, 100.0))


func test_priority_prefers_higher_bugs() -> void:
	assert_true(Targeting.priority(50.0, 60.0) > Targeting.priority(30.0, 50.0))


func test_plateau_guard_never_shoots_cliff_faces() -> void:
	assert_false(Targeting.guard_allows(WorldLayout.WEST, WorldLayout.WEST, false))
	assert_false(Targeting.guard_allows(WorldLayout.WEST, WorldLayout.EAST, false))


func test_plateau_guard_only_shoots_own_plateau() -> void:
	assert_true(Targeting.guard_allows(WorldLayout.WEST, WorldLayout.WEST, true))
	assert_false(Targeting.guard_allows(WorldLayout.WEST, WorldLayout.EAST, true), "partner plateau is off limits")
