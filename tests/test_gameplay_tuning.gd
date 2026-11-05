extends TestCase
## Gameplay helper's tuning rules: wave toughness, endless length, weather nudges,
## per-gun roles and breach thieves. Pure data/logic checks.


func test_count_grows_faster_than_toughness() -> void:
	var c := Defs.WAVE_CONFIG
	assert_almost(c.count_growth, 1.25)
	assert_almost(c.hp_per_wave, 0.10)
	assert_almost(c.damage_per_wave, 0.10)
	# Wave 11: ~9.3x the bugs of wave 1, but each only 2x as tough.
	assert_almost(c.hp_scale(11), 2.0)
	assert_almost(c.damage_scale(11), 2.0)
	assert_true(float(c.bug_count(11)) / float(c.bug_count(1)) > 9.0)


func test_win_at_twenty() -> void:
	assert_eq(Defs.WAVE_CONFIG.last_wave, 20)
	# Endless keeps the same growth past the last wave.
	var c := Defs.WAVE_CONFIG
	assert_true(c.bug_count(21) > c.bug_count(20))
	assert_almost(c.hp_scale(21) - c.hp_scale(20), c.hp_per_wave)


func test_heat_makes_you_thirsty() -> void:
	assert_almost(Weather.thirst_rate(70.0), 0.8)
	assert_almost(Weather.thirst_rate(85.0), 1.0)
	assert_true(Weather.thirst_rate(Weather.temperature(15.0, Weather.Kind.HEAT_WAVE)) > 1.5, "heat wave afternoons are thirsty")


func test_dust_storm_cuts_turret_range() -> void:
	assert_true(Weather.turret_range(Weather.Kind.DUST_STORM) < 0.6)
	assert_true(Weather.turret_range(Weather.Kind.DUST_STORM, true) > Weather.turret_range(Weather.Kind.DUST_STORM))
	assert_true(Weather.is_rain(Weather.Kind.LIGHT_RAIN) and Weather.is_rain(Weather.Kind.THUNDERSTORM))


func _w(id: StringName) -> WeaponDef:
	return load("res://data/weapons/%s.tres" % id) as WeaponDef


func test_gun_roles() -> void:
	var rev := _w(&"revolver")
	var rifle := _w(&"lever_rifle")
	var coach := _w(&"coach_shotgun")
	var gat := _w(&"crank_gatling")
	# Revolver: no spread, the lightest kick of the single-shot guns.
	assert_almost(rev.spread_deg, 0.0)
	assert_true(rev.recoil_deg < rifle.recoil_deg and rev.recoil_deg < coach.recoil_deg)
	# Rifle: full damage at any range; shotguns fade fast.
	assert_almost(rifle.falloff(250.0), 1.0)
	assert_almost(coach.falloff(5.0), 1.0)
	assert_true(coach.falloff(30.0) < 0.3)
	assert_true(_w(&"blunderbuss").falloff(28.0) < 0.3)
	# Gatling: suppression (hits slow bugs) and a light kick per round.
	assert_true(gat.suppress_slow < 1.0 and gat.suppress_time > 0.0)
	assert_true(gat.recoil_deg < rev.recoil_deg)
	for id: StringName in [&"revolver", &"lever_rifle", &"coach_shotgun", &"blunderbuss", &"crank_gatling"]:
		assert_true(_w(id).role != "", "%s has a role" % id)


func test_falloff_is_monotonic() -> void:
	var coach := _w(&"coach_shotgun")
	var last := 2.0
	for d in range(0, 40, 2):
		var f := coach.falloff(float(d))
		assert_true(f <= last + 0.0001)
		last = f


func test_breach_thieves() -> void:
	assert_true(BreachRules.is_thief(Defs.bug(&"dust_mite")))
	assert_false(BreachRules.is_thief(Defs.bug(&"iron_tumble")))
	assert_false(BreachRules.is_thief(Defs.bug(&"dragonfly_bandit")), "bandits already steal their own way")
	var take := BreachRules.steal_amounts(Defs.bug(&"dust_mite"))
	assert_true(int(take.get(&"scrap", 0)) > 0)
	assert_eq(BreachRules.describe({&"scrap": 7, &"chitin": 1}), "7 chitin and 1 scrap") # player-facing names (ResNames)
