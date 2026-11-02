extends TestCase
## Health: damage, healing, death.
## (Pings._sector and BugStatus can't be loaded by the -s runner: their scripts
## depend on autoloads (GameState, Audio) that don't exist outside the game.)


func test_health_damage_and_death() -> void:
	var h := Health.new()
	h.setup(50.0)
	var deaths := [0]
	h.died.connect(func(_s: String, _c: int) -> void: deaths[0] += 1)
	h.take_damage(-5.0)
	assert_almost(h.hp, 50.0, 0.001, "negative damage ignored")
	h.take_damage(20.0)
	assert_almost(h.fraction(), 0.6)
	h.heal(100.0)
	assert_almost(h.hp, 50.0, 0.001, "heal capped")
	h.take_damage(80.0)
	assert_almost(h.hp, 0.0)
	assert_true(h.dead)
	h.take_damage(10.0)
	h.heal(10.0)
	assert_eq(deaths[0], 1, "dies once")
	assert_almost(h.hp, 0.0, 0.001, "no healing the dead")
	h.free()


func test_health_zero_max_fraction_is_safe() -> void:
	var h := Health.new()
	h.setup(0.0)
	assert_almost(h.fraction(), 0.0)
	h.free()
