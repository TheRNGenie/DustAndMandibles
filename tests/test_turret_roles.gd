extends TestCase
## Turret roles, upkeep rules, upgrade tiers and the scaffold range bonus.

## The cheap basic cliff turrets: never any ammo or upkeep.
const BASIC: Array[StringName] = [&"gatling_post", &"buffalo_rifle", &"water_cannon", &"lasso_harpoon"]


func test_every_turret_has_a_job_and_a_weakness() -> void:
	for id: StringName in Defs.TURRETS:
		var d := Defs.turret(id)
		assert_true(d.role != "", "%s has a role" % id)
		assert_true(d.weakness != "", "%s has a weakness" % id)
		assert_true(d.role_line().begins_with("Job: "), "%s role line" % id)


func test_basic_turrets_need_no_upkeep() -> void:
	for id in BASIC:
		assert_false(Defs.turret(id).has_upkeep(), "%s must never need ammo" % id)
	for id: StringName in Defs.TURRETS:
		var d := Defs.turret(id)
		if d.guards_plateau:
			assert_false(d.has_upkeep(), "last resort %s needs no ammo" % id)


func test_special_turrets_show_their_upkeep() -> void:
	assert_eq(Defs.turret(&"chili_mortar").upkeep_text(), "1 chili")
	assert_true(Defs.turret(&"dynamite_lobber").has_upkeep())
	assert_true(Defs.turret(&"chili_mortar").role_line().contains("Upkeep: 1 chili a shot"))


func test_swarm_gun_weak_and_rifle_strong_against_heavy() -> void:
	var g := Defs.turret(&"gatling_post")
	var r := Defs.turret(&"buffalo_rifle")
	assert_true(g.damage_at(0, true) < g.damage_at(0, false), "gatling worse vs heavy")
	assert_true(r.damage_at(0, true) > r.damage_at(0, false), "rifle better vs heavy")
	# Per second, the gatling out-fires the rifle on small bugs and loses on heavy ones.
	var g_dps_small := g.damage_at(0) * g.hit_chance / g.fire_interval
	var r_dps_heavy := r.damage_at(0, true) * r.hit_chance / r.fire_interval
	var g_dps_heavy := g.damage_at(0, true) * 0.5 * g.hit_chance / g.fire_interval # plate halves it again
	assert_true(r_dps_heavy > g_dps_heavy * 2.0, "rifle is the armour answer")
	assert_true(g.fire_interval * 5.0 < r.fire_interval, "gatling fires far more shots for swarms (%.1f dps)" % g_dps_small)


func test_bug_heaviness() -> void:
	assert_true(TurretDef.is_heavy(Defs.bug(&"rattler_beetle")))
	assert_true(TurretDef.is_heavy(Defs.bug(&"brood_mother")))
	assert_false(TurretDef.is_heavy(Defs.bug(&"dust_mite")))
	assert_false(TurretDef.is_heavy(Defs.bug(&"wolf_spider")))


func test_two_upgrade_tiers_each_better() -> void:
	assert_eq(Defs.UPGRADE_COSTS.size(), TurretDef.MAX_TIER)
	assert_true(Defs.UPGRADE_COSTS[0] < Defs.UPGRADE_COSTS[1])
	var d := Defs.turret(&"gatling_post")
	for t in TurretDef.MAX_TIER:
		assert_true(d.damage_at(t + 1) > d.damage_at(t), "damage rises at tier %d" % (t + 1))
		assert_true(d.range_at(t + 1) > d.range_at(t), "range rises at tier %d" % (t + 1))
		assert_true(d.interval_at(t + 1) < d.interval_at(t), "fires faster at tier %d" % (t + 1))
		assert_true(d.hp_at(t + 1) > d.hp_at(t), "tougher at tier %d" % (t + 1))
	assert_eq(d.damage_at(9), d.damage_at(TurretDef.MAX_TIER), "tiers clamp")


func test_scaffold_levels_add_modest_range() -> void:
	var d := Defs.turret(&"buffalo_rifle")
	assert_true(d.range_at(0, 2) > d.range_at(0, 1))
	assert_almost(d.range_at(0, 1), d.range_at(0, 0), 0.001, "the bottom deck gets no scaffold bonus (Logan)")
	assert_true(d.range_at(0, 3) < d.range * 1.2, "three levels stay modest")
	assert_eq(TurretDef.range_mult(0, 0), 1.0)
