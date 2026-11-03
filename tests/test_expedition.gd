extends TestCase
## Canyon Expeditions: the backpack (capacity, weight, slowing, deposit, the
## sack you drop when downed on the floor), the lever lock while someone is
## down, gunshot noise and the risk clock.


func test_backpack_fits_by_weight() -> void:
	var b := Backpack.make({}, 10)
	assert_eq(b.add({&"scrap": 4}), 4)
	assert_eq(b.weight(), 4)
	# Chitin weighs 2: only 3 of 5 fit in the 6 left.
	assert_eq(b.add({&"chitin": 5}), 3, "a partial stack goes in")
	assert_eq(b.leftover, {&"chitin": 2}, "what didn't fit is left over")
	assert_eq(b.weight(), 10)
	assert_eq(b.room(), 0)
	assert_eq(b.add({&"scrap": 1}), 0, "a full pack takes nothing")
	assert_eq(b.leftover, {&"scrap": 1})


func test_unknown_items_weigh_the_default_and_seeds_ride_free() -> void:
	var b := Backpack.make({}, 5)
	assert_eq(Backpack.weight_of(&"mystery_relic"), Backpack.DEFAULT_WEIGHT)
	assert_eq(b.add({&"seed_corn": 30}), 30, "seeds weigh nothing")
	assert_eq(b.weight(), 0)
	assert_eq(b.units(), 30)


func test_heavier_pack_is_slower() -> void:
	assert_almost(Backpack.speed_for(0), 1.0)
	assert_almost(Backpack.speed_for(Backpack.CAPACITY), Backpack.FULL_SPEED)
	var half := Backpack.speed_for(Backpack.CAPACITY / 2)
	assert_true(half < 1.0 and half > Backpack.FULL_SPEED, "half full is in between")
	assert_true(Backpack.speed_for(30) < Backpack.speed_for(10), "more loot, slower")
	assert_almost(Backpack.speed_for(Backpack.CAPACITY * 3), Backpack.FULL_SPEED, 0.001, "never slower than full")


func test_deposit_lands_in_your_cliffs_stockpile() -> void:
	var ledger := EconomyLedger.new()
	ledger.reset({&"scrap": 10}, 2)
	var b := Backpack.make({&"chitin": 3, &"scrap": 5, &"bone": 2})
	var items := b.take_all()
	ledger.earn(1, items)
	assert_true(b.is_empty(), "the pack is empty after unpacking")
	assert_eq(ledger.amount(1, &"chitin"), 3, "chitin is the cliff's own")
	assert_eq(ledger.amount(0, &"chitin"), 0, "not the partner's")
	assert_eq(ledger.team_amount(&"scrap"), 25, "scrap goes in the team pot")
	assert_eq(ledger.amount(1, &"bone"), 2, "site loot the ledger never heard of still lands")


func test_downed_sack_holds_the_pack_and_partial_grabs_leave_the_rest() -> void:
	# Downed on the floor: the whole pack goes into the sack, the pack empties.
	var mine := Backpack.make({&"chitin": 6, &"scrap": 10})
	var sack := mine.take_all()
	assert_true(mine.is_empty())
	assert_eq(Backpack.weigh(sack), 22)
	# A partner with room for 8 grabs what fits; the rest stays in the sack.
	var theirs := Backpack.make({}, 8)
	var n := theirs.add(sack)
	assert_eq(n, 4, "4 chitin (8 weight) fit")
	assert_eq(ExpeditionRules.taken(sack, theirs.leftover), {&"chitin": 4})
	assert_eq(theirs.leftover, {&"chitin": 2, &"scrap": 10}, "the rest stays in the sack")


func test_sack_lasts_until_the_next_wave_ends() -> void:
	# Dropped in wave 3's build phase: still there through wave 3, gone at wave 4's build.
	assert_false(ExpeditionRules.sack_expired(3, 3))
	assert_true(ExpeditionRules.sack_expired(3, 4))


func test_lever_lock_while_down() -> void:
	var down := {2: true}
	assert_false(ExpeditionRules.can_throw_lever(2, down), "down in the canyon: no lever")
	assert_true(ExpeditionRules.can_throw_lever(1, down), "the partner up top still can")
	assert_false(ExpeditionRules.countdown_allowed(down), "the wave can't start while anyone's down")
	assert_true(ExpeditionRules.countdown_allowed({}))


func test_lever_lock_blocks_the_countdown_scenario() -> void:
	# Two players: 1 throws, 2 is down. 2 can't throw, so the votes never reach
	# two and the levers (Waterworks) show only cliff 0 thrown.
	var down := {2: true}
	var voters: Array = []
	for peer: int in [1, 2]:
		if ExpeditionRules.can_throw_lever(peer, down):
			voters.append(peer)
	assert_eq(voters, [1])
	var levers := Waterworks.levers(2, voters, {1: 0, 2: 1}, {}, voters.size() >= 2, {0: true, 1: true})
	assert_eq(levers, [true, false] as Array[bool])
	# Back up: now both throw and the countdown may run.
	down.erase(2)
	assert_true(ExpeditionRules.can_throw_lever(2, down) and ExpeditionRules.countdown_allowed(down))


func test_gunshots_make_noise_the_smoker_doesnt() -> void:
	assert_almost(ExpeditionRules.gun_noise(&"", 0.0, 1), ExpeditionRules.GUN_NOISE)
	assert_almost(ExpeditionRules.gun_noise(&"", 2.0, 1), ExpeditionRules.LOUD_GUN_NOISE, 0.001, "the Punt Gun's kick is loud")
	assert_almost(ExpeditionRules.gun_noise(&"", 0.0, 8), ExpeditionRules.LOUD_GUN_NOISE, 0.001, "a scattergun is loud")
	assert_almost(ExpeditionRules.gun_noise(&"smoke", 0.0, 1), 0.0, 0.001, "the Bee Smoker only hisses")


func test_noise_heats_the_risk_clock_in_range_only() -> void:
	assert_almost(ExpeditionRules.shot_heat(10.0, 45.0, 0.0), ExpeditionRules.SHOT_HEAT)
	assert_almost(ExpeditionRules.shot_heat(60.0, 45.0, 0.0), 0.0, 0.001, "out of earshot")
	assert_almost(ExpeditionRules.shot_heat(10.0, 0.0, 0.0), 0.0, 0.001, "silent")
	assert_almost(ExpeditionRules.shot_heat(10.0, 45.0, ExpeditionRules.MAX_HEAT - 1.0), 1.0, 0.001, "capped")


func test_risk_clock_rumbles_then_hunts() -> void:
	assert_eq(ExpeditionRules.risk_stage(0.0), 0)
	assert_eq(ExpeditionRules.risk_stage(ExpeditionRules.RUMBLE_AT), 1, "the ground rumbles first")
	assert_eq(ExpeditionRules.risk_stage(ExpeditionRules.HUNT_AT), 2, "then the bugs come")
	assert_eq(ExpeditionRules.hunters_to_send(ExpeditionRules.RUMBLE_AT, 0), 0, "no hunters while it only rumbles")
	assert_eq(ExpeditionRules.hunters_to_send(ExpeditionRules.HUNT_AT, 0), 2)
	assert_true(ExpeditionRules.hunters_to_send(ExpeditionRules.HUNT_AT + 200.0, 0) > 2, "more the longer you stay")
	assert_eq(ExpeditionRules.hunters_to_send(ExpeditionRules.HUNT_AT + 999.0, ExpeditionRules.MAX_HUNTERS), 0, "never past the cap")


func test_turrets_may_shoot_floor_bugs_only_within_their_pitch() -> void:
	assert_true(Targeting.floor_allows(true, true))
	assert_false(Targeting.floor_allows(false, true), "an ordinary crossing bug is still off limits")
	# Straight down the 60 m wall to the far foot (45 m across) is past 30 degrees...
	var muzzle := Vector3(-22.5, 61.0, 0.0)
	assert_false(Targeting.in_arc(muzzle, Vector3(22.0, 0.5, 0.0), 30.0, 120.0), "Downward Discharge law")
	# ...but the far floor well down the canyon is in reach of a 40 degree gun.
	assert_true(Targeting.in_arc(muzzle, Vector3(20.0, 0.5, 65.0), 40.0, 120.0))
	assert_true(Targeting.floor_priority(5.0) > Targeting.priority(60.0, 1.0), "a partner's life before any climber")


func test_rope_ride_eases_in_and_out() -> void:
	assert_almost(ExpeditionRules.ride_ease(0.0), 0.0)
	assert_almost(ExpeditionRules.ride_ease(1.0), 1.0)
	assert_almost(ExpeditionRules.ride_ease(0.5), 0.5)
	assert_true(ExpeditionRules.ride_ease(0.1) < 0.1, "a gentle start")
	assert_almost(ExpeditionRules.RIDE_TIME, 8.0, 0.001, "about eight seconds on the rope")
