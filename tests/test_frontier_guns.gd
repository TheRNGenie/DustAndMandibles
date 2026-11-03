extends TestCase
## The eight frontier guns: registration, roles and prices, and their specials
## (GunRules): harpoon reel-or-pull, flare marks and turret priority, rock-salt
## slip, bee-smoke drowsiness, Telescope Rifle crits, the Punt Gun's kick and
## the smoker's fuel.

const NEW: Array[StringName] = [&"derringer_pair", &"pepperbox", &"salt_shotgun", &"harpoon_pistol",
	&"bee_smoker", &"flare_gun", &"punt_gun", &"telescope_rifle"]


## Stand-in for BugStatus (slow / root / smoke / mark).
class FakeStatus:
	extends RefCounted
	var slow_factor := 1.0
	var root_t := 0.0
	var drowsy_t := 0.0

	func slow(factor: float, _seconds: float) -> void:
		slow_factor = minf(slow_factor, factor)

	func root(seconds: float) -> void:
		root_t = maxf(root_t, seconds)

	func smoke(factor: float, seconds: float) -> void:
		slow(factor, seconds)
		drowsy_t = maxf(drowsy_t, seconds)


## Stand-in for a Bug: the fields and methods GunRules uses.
class FakeBug:
	extends RefCounted
	var def: BugDef
	var boss: Variant = null
	var climb_y := 0.0
	var climbing := true
	var status := FakeStatus.new()

	func is_climbing() -> bool:
		return climbing


func _bug(id: StringName, y: float = 20.0, boss: bool = false) -> FakeBug:
	var b := FakeBug.new()
	b.def = Defs.bug(id)
	b.climb_y = y
	if boss:
		b.boss = RefCounted.new()
	return b


## Scripts that lean on autoloads don't compile under the bare test runner, so
## their tables are checked in the source text.
func _source(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_registered_everywhere() -> void:
	var gun_src := _source("res://scenes/player/gun.gd")
	var shop_src := _source("res://scenes/shops/gun_shop.gd")
	for id in NEW:
		var w := Defs.weapon(id)
		assert_true(w != null, "%s registered" % id)
		assert_eq(w.id, id)
		assert_true(w.role != "", "%s has a role" % id)
		assert_true(w.price_chitin > 0, "%s costs chitin" % id)
		assert_eq(w.upgrade_costs.size(), 2)
		assert_eq(WeaponMods.list(id).size(), 3, "%s has three workshop mods" % id)
		assert_true(FrontierGuns.has(id), "%s has a model" % id)
		assert_true(WeaponBuilder.LEFT_FIST.has(id) and WeaponBuilder.LOAD_POINT.has(id), "%s has hand poses" % id)
		assert_true(FrontierGuns.MUZZLE.has(id), "%s has a muzzle" % id)
		# Gun.ORDER, TRACERS, AIM_POS, AIM_ZOOM all name it.
		assert_true(gun_src.count('&"%s"' % id) >= 4, "%s in the gun's tables" % id)
		for kind in ["buy", "upgrade", "mods"]:
			assert_true(shop_src.contains('{"kind": "%s", "id": &"%s"}' % [kind, id]), "gunsmith: %s %s" % [kind, id])
		assert_true(ResourceLoader.exists("res://audio/sfx/%s.wav" % w.sound), "%s reuses a real sound" % id)
		assert_true(w.sound_layer == &"" or ResourceLoader.exists("res://audio/sfx/%s.wav" % w.sound_layer))
	var guide: Dictionary = (JSON.parse_string(_source("res://data/field_guide.json")) as Dictionary)["guns"]
	for id in NEW:
		assert_true(guide.has(String(id)), "%s in the field guide" % id)


func test_models_have_their_moving_parts() -> void:
	var want := {&"derringer_pair": ["barrels"], &"pepperbox": ["drum"], &"harpoon_pistol": ["reel", "dart"],
		&"flare_gun": ["barrels"], &"salt_shotgun": ["pump"], &"punt_gun": ["barrels"], &"bee_smoker": ["bellows", "pleats"],
		&"telescope_rifle": ["bolt"]}
	for id: StringName in want:
		var p := FrontierGuns.parts(id)
		assert_true(p.has("body") and (p["body"] as ArrayMesh).get_surface_count() >= 2, "%s body has metal and wood/leather" % id)
		for part: String in want[id]:
			assert_true(p.has(part), "%s has its %s" % [id, part])
			assert_true(FrontierGuns.PIVOTS.has("%s_%s" % [id, part]), "%s %s has a pivot" % [id, part])
	# Real size: pistols short, long guns long (barrel along -Z).
	var pistol := FrontierGuns.parts(&"pepperbox")["body"] as ArrayMesh
	var rifle := FrontierGuns.parts(&"telescope_rifle")["body"] as ArrayMesh
	assert_true(pistol.get_aabb().size.z < 0.3)
	assert_true(rifle.get_aabb().size.z > 1.0)


func test_roles_balance() -> void:
	var rev := Defs.weapon(&"revolver")
	var der := Defs.weapon(&"derringer_pair")
	var pep := Defs.weapon(&"pepperbox")
	var punt := Defs.weapon(&"punt_gun")
	var blun := Defs.weapon(&"blunderbuss")
	var tele := Defs.weapon(&"telescope_rifle")
	var lever := Defs.weapon(&"lever_rifle")
	# Derringers: quickest to draw and reload, hardest hitting up close, useless far off.
	assert_true(der.draw_speed > 1.0 and der.reload_time < rev.reload_time)
	assert_true(der.damage > rev.damage)
	assert_true(der.falloff(25.0) < 0.3)
	# Pepperbox: faster and wilder than the revolver, weaker per shot.
	assert_true(pep.fire_interval < rev.fire_interval and pep.spread_deg > rev.spread_deg and pep.damage < rev.damage)
	# Punt Gun: the biggest single blast of any gun, one shell, the longest reload, a kick.
	assert_true(punt.damage * punt.pellets > blun.damage * blun.pellets)
	assert_eq(punt.mag_size, 1)
	assert_true(punt.reload_time > blun.reload_time and punt.kickback > 0.0)
	# Telescope Rifle: slow bolt, long reach, the weak-spot crit nobody else has.
	assert_true(tele.fire_interval > lever.fire_interval and tele.range > lever.range)
	assert_true(tele.weak_bonus > 1.0)
	assert_true(tele.stat_line().contains("Weak Spots x5"))
	# Bee Smoker: no damage, continuous, its own stat line.
	var smoke := Defs.weapon(&"bee_smoker")
	assert_true(smoke.damage == 0.0 and smoke.automatic)
	assert_true(smoke.stat_line().begins_with("No Damage"))


func test_harpoon_reels_small_bugs_and_pulls_you_to_big_ones() -> void:
	# The decision itself.
	assert_eq(GunRules.harpoon_action(true, false, false, false), GunRules.Harpoon.REEL)
	assert_eq(GunRules.harpoon_action(true, false, true, false), GunRules.Harpoon.PULL)
	assert_eq(GunRules.harpoon_action(true, false, false, true), GunRules.Harpoon.PULL)
	assert_eq(GunRules.harpoon_action(false, true), GunRules.Harpoon.PULL, "rock pulls you")
	assert_eq(GunRules.harpoon_action(false, false), GunRules.Harpoon.NONE, "a miss does nothing")
	# By bug kind: mites and spiders come to you; beetles and bosses take you to them.
	assert_eq(GunRules.harpoon_for_bug(_bug(&"dust_mite")), GunRules.Harpoon.REEL)
	assert_eq(GunRules.harpoon_for_bug(_bug(&"wolf_spider")), GunRules.Harpoon.REEL)
	assert_eq(GunRules.harpoon_for_bug(_bug(&"rattler_beetle")), GunRules.Harpoon.PULL)
	assert_eq(GunRules.harpoon_for_bug(_bug(&"queen_spider", 20.0, true)), GunRules.Harpoon.PULL)
	# Reeled in: stops REEL_STOP short of you, never pushed away.
	var shooter := Vector3(0, 60, 0)
	var p := GunRules.reel_point(Vector3(20, 60, 0), shooter)
	assert_almost(p.distance_to(shooter), GunRules.REEL_STOP)
	assert_almost(p.x, GunRules.REEL_STOP)
	var near := Vector3(1, 60, 0)
	assert_eq(GunRules.reel_point(near, shooter), near)


func test_flare_marks_and_turrets_prioritise_it() -> void:
	var st := BugStatus.new(null)
	assert_false(st.is_marked())
	st.mark(GunRules.MARK_TIME)
	assert_true(st.is_marked())
	st.tick(GunRules.MARK_TIME - 0.5)
	assert_true(st.is_marked(), "still burning")
	st.tick(1.0)
	assert_false(st.is_marked(), "burnt out after MARK_TIME")
	# A marked bug low on the wall and far off beats an unmarked one at the lip.
	var marked := Targeting.marked_priority(Targeting.priority(2.0, 60.0), true)
	var top := Targeting.marked_priority(Targeting.priority(WorldLayout.CLIFF_HEIGHT - 1.0, 5.0), false)
	assert_true(marked > top)
	# Unmarked scores are unchanged.
	assert_almost(Targeting.marked_priority(12.5, false), 12.5)


func test_salt_slip() -> void:
	var mite := _bug(&"dust_mite", 20.0)
	assert_almost(GunRules.salt_hit(mite), GunRules.SALT_SLIP)
	assert_almost(mite.climb_y, 20.0 - GunRules.SALT_SLIP)
	assert_almost(mite.status.root_t, GunRules.SALT_FLINCH, 0.001, "it flinches")
	# Heavy bugs slide less.
	var beetle := _bug(&"rattler_beetle", 20.0)
	assert_almost(GunRules.salt_hit(beetle), GunRules.SALT_HEAVY_SLIP)
	assert_true(GunRules.SALT_HEAVY_SLIP < GunRules.SALT_SLIP)
	# Never below the foot of the wall.
	var low := _bug(&"dust_mite", 1.0)
	assert_almost(GunRules.salt_hit(low), 1.0)
	assert_almost(low.climb_y, 0.0)
	# Bosses: a short slip, then nothing until the shared gap has passed; no flinch.
	var boss := _bug(&"queen_spider", 30.0, true)
	assert_almost(GunRules.salt_hit(boss), SpecialShotRules.BOSS_SLIP)
	assert_almost(GunRules.salt_hit(boss), 0.0, 0.001, "boss resists a second salting")
	assert_almost(boss.status.root_t, 0.0)
	# Not on a wall: nothing.
	var walker := _bug(&"dust_mite", 0.0)
	walker.climbing = false
	assert_almost(GunRules.salt_hit(walker), 0.0)


func test_bee_smoke_slows_fliers_and_spiders() -> void:
	assert_true(GunRules.smokeable(Defs.bug(&"dragonfly_bandit")))
	assert_true(GunRules.smokeable(Defs.bug(&"wolf_spider")))
	assert_true(GunRules.smokeable(Defs.bug(&"spiderling")))
	assert_false(GunRules.smokeable(Defs.bug(&"rattler_beetle")), "beetles don't care")
	assert_false(GunRules.smokeable(Defs.bug(&"dust_mite")))
	var spider := _bug(&"wolf_spider")
	assert_true(GunRules.smoke_hit(spider, 0))
	assert_almost(spider.status.slow_factor, GunRules.SMOKE_SLOW)
	assert_almost(spider.status.drowsy_t, GunRules.SMOKE_TIME)
	var upgraded := _bug(&"dragonfly_bandit")
	GunRules.smoke_hit(upgraded, 2)
	assert_almost(upgraded.status.drowsy_t, GunRules.SMOKE_TIME + 2.0 * GunRules.SMOKE_TIME_PER_LEVEL)
	var beetle := _bug(&"rattler_beetle")
	assert_false(GunRules.smoke_hit(beetle, 0))
	assert_almost(beetle.status.slow_factor, 1.0)
	var queen := _bug(&"queen_spider", 20.0, true)
	GunRules.smoke_hit(queen, 0)
	assert_almost(queen.status.slow_factor, GunRules.SMOKE_BOSS_SLOW, 0.001, "bosses shrug most of it off")
	# The real BugStatus: drowsy and slowed together, both wear off.
	var st := BugStatus.new(null)
	st.smoke(GunRules.SMOKE_SLOW, 2.0)
	assert_true(st.is_drowsy())
	assert_almost(st.speed_multiplier(), GunRules.SMOKE_SLOW)
	st.tick(2.5)
	assert_false(st.is_drowsy())
	assert_almost(st.speed_multiplier(), 1.0)
	# The cloud: a cone out of the spout.
	var o := Vector3.ZERO
	assert_true(GunRules.in_smoke(o, Vector3.FORWARD, Vector3(0, 0, -6)))
	assert_false(GunRules.in_smoke(o, Vector3.FORWARD, Vector3(0, 0, -14)), "out of reach")
	assert_false(GunRules.in_smoke(o, Vector3.FORWARD, Vector3(6, 0, -3)), "off to the side")
	assert_true(GunRules.in_smoke(o, Vector3.FORWARD, Vector3(0, 0, -12), 13.0), "a wider spout reaches further")


func test_telescope_crit() -> void:
	var tele := Defs.weapon(&"telescope_rifle")
	assert_almost(GunRules.crit_mult(tele.weak_bonus, true), tele.weak_bonus)
	assert_almost(GunRules.crit_mult(tele.weak_bonus, false), 1.0, 0.001, "body shots: no crit")
	assert_almost(GunRules.crit_mult(Defs.weapon(&"revolver").weak_bonus, true), 1.0, 0.001, "other guns: just the weak spot")
	# Through a real bug hitbox: a weak-spot hit is x2 from the spot, x2.5 more from the rifle.
	var hb := Hitbox.make_bug(null, 1.0, Vector3.ZERO, 0.3, Vector3(0, 0, -0.9))
	var weak := hb.multiplier_at(Vector3(0, 0, -0.9))
	var total := weak * GunRules.crit_mult(tele.weak_bonus, weak > 1.0)
	assert_almost(total, 5.0)
	hb.free()


func test_punt_kick_and_smoker_fuel() -> void:
	var kick := GunRules.kick_velocity(Vector3(0, 0, -1), 11.0)
	assert_true(kick.z > 8.0, "shoved straight back")
	assert_true(kick.y > 0.0)
	var down := GunRules.kick_velocity(Vector3(0, -1, 0), 11.0)
	assert_true(down.y > 4.0, "firing at your feet throws you up")
	assert_eq(GunRules.kick_velocity(Vector3(0, 0, -1), 0.0), Vector3.ZERO)
	# Fuel: waits FUEL_DELAY after the last puff, then smoulders back up, capped.
	assert_almost(GunRules.refill(10.0, 0.2, 1.0, 0, 100.0), 10.0)
	assert_almost(GunRules.refill(10.0, 1.0, 1.0, 0, 100.0), 10.0 + GunRules.FUEL_REFILL)
	assert_almost(GunRules.refill(10.0, 1.0, 1.0, 2, 100.0), 10.0 + GunRules.FUEL_REFILL * 1.5)
	assert_almost(GunRules.refill(95.0, 5.0, 1.0, 0, 100.0), 100.0)
