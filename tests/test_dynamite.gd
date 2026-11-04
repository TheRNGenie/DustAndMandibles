extends TestCase
## The grapple's dynamite (DynamiteRules), its workshop mods, the noise it makes,
## the knock it gives teammates; and the grapple's toggle swing and Free Hands.

const KillMethod := preload("res://scenes/bugs/kill_method.gd")


func test_satchel_unlocks_it() -> void:
	assert_false(DynamiteRules.unlocked(0))
	assert_true(DynamiteRules.unlocked(1))
	# A mod alone (no satchel) doesn't count; the gunsmith never sells one first anyway.
	assert_false(DynamiteRules.unlocked(WeaponMods.with_mod(0, 0)))


func test_blast_falls_off_and_stops_at_the_rim() -> void:
	var c := 1
	assert_almost(DynamiteRules.damage_at(c, 0.0), DynamiteRules.DAMAGE)
	assert_almost(DynamiteRules.damage_at(c, DynamiteRules.RADIUS), DynamiteRules.DAMAGE * DynamiteRules.EDGE_FRACTION)
	assert_true(DynamiteRules.damage_at(c, DynamiteRules.RADIUS * 0.5) < DynamiteRules.DAMAGE)
	assert_eq(DynamiteRules.damage_at(c, DynamiteRules.RADIUS + 0.1), 0.0)
	# A big bug's flank inside the blast counts.
	assert_true(DynamiteRules.damage_at(c, DynamiteRules.RADIUS + 1.0, 1.5) > 0.0)


func test_moderate_to_high_damage() -> void:
	# More than a Dynamite Lobber shell (45 in 3.5 m), kills a wolf spider (60 HP) all but
	# at the very rim, and a rattler beetle (120 HP) near the middle.
	var lobber := Defs.turret(&"dynamite_lobber")
	assert_true(DynamiteRules.DAMAGE > lobber.damage * 3.0)
	assert_true(DynamiteRules.RADIUS > lobber.effect_size * 1.5)
	assert_true(DynamiteRules.damage_at(1, DynamiteRules.RADIUS) < Defs.bug(&"wolf_spider").max_hp)
	assert_true(DynamiteRules.damage_at(1, DynamiteRules.RADIUS * 0.6) >= Defs.bug(&"wolf_spider").max_hp)
	assert_true(DynamiteRules.damage_at(1, 1.0) >= Defs.bug(&"rattler_beetle").max_hp)


func test_workshop_mods() -> void:
	var mods := WeaponMods.list(DynamiteRules.ID)
	assert_eq(mods.size(), 3)
	for m: Dictionary in mods:
		assert_true(int(m["cost"]) >= 15 and int(m["cost"]) <= 30, "priced like the other mods: %s" % m["name"])
	var bigger := WeaponMods.with_mod(1, DynamiteRules.MOD_BIGGER)
	var heavier := WeaponMods.with_mod(1, DynamiteRules.MOD_HEAVIER)
	var oil := WeaponMods.with_mod(1, DynamiteRules.MOD_COAL_OIL)
	assert_almost(DynamiteRules.radius_for(bigger), DynamiteRules.RADIUS * 1.4)
	assert_almost(DynamiteRules.damage_for(heavier), DynamiteRules.DAMAGE * 1.4)
	assert_almost(DynamiteRules.radius_for(heavier), DynamiteRules.RADIUS)
	assert_true(DynamiteRules.burns(oil))
	assert_false(DynamiteRules.burns(bigger | heavier))
	# Bigger Blast reaches bugs the plain bundle doesn't.
	assert_eq(DynamiteRules.damage_at(1, DynamiteRules.RADIUS * 1.2), 0.0)
	assert_true(DynamiteRules.damage_at(bigger, DynamiteRules.RADIUS * 1.2) > 0.0)


func test_restock() -> void:
	var r := DynamiteRules.restock(0, 0.0, DynamiteRules.RESTOCK_SECS * 0.5)
	assert_eq(int(r[0]), 0)
	r = DynamiteRules.restock(int(r[0]), float(r[1]), DynamiteRules.RESTOCK_SECS * 0.5 + 0.01)
	assert_eq(int(r[0]), 1)
	r = DynamiteRules.restock(1, 0.0, DynamiteRules.RESTOCK_SECS * 10.0)
	assert_eq(int(r[0]), DynamiteRules.MAX_BUNDLES, "never more than the satchel holds")
	assert_eq(float(r[1]), 0.0)


func test_throw_lands_where_you_aim() -> void:
	var from := Vector3(-23.0, 61.5, 0.0)
	var aim := Vector3(1.0, -0.3, 0.1).normalized()
	var hit := from + aim * 35.0
	var target := DynamiteRules.throw_target(from, aim, hit)
	assert_eq(target, hit)
	var t := DynamiteRules.flight_time(from, target)
	var v := DynamiteRules.launch_velocity(from, target, t)
	assert_true(DynamiteRules.arc_point(from, v, t).distance_to(target) < 0.01)
	assert_true(v.y > aim.y * v.length(), "it's lobbed, rising over the straight line")
	# Out of range (or nothing there): lobbed THROW_RANGE along the aim.
	var far := DynamiteRules.throw_target(from, aim, from + aim * 200.0)
	assert_almost(far.distance_to(from), DynamiteRules.THROW_RANGE)
	assert_almost(DynamiteRules.throw_target(from, aim, null).distance_to(from), DynamiteRules.THROW_RANGE)
	# Every honest throw passes the host's check; a teleport or a rocket doesn't.
	var pos := from - Vector3.UP * 1.5
	var tf := DynamiteRules.flight_time(from, far)
	assert_true(DynamiteRules.valid_throw(from, pos, DynamiteRules.launch_velocity(from, far, tf)))
	assert_false(DynamiteRules.valid_throw(from + Vector3(30, 0, 0), pos, v))
	assert_false(DynamiteRules.valid_throw(from, pos, Vector3(500, 0, 0)))


func test_reaches_the_far_wall_from_your_lip() -> void:
	# The Canyon's gap is 45 m (lip to lip): the far wall's climbers are in reach.
	assert_true(DynamiteRules.THROW_RANGE >= WorldLayout.GAP + 5.0)


func test_loudest_thing_in_the_canyon() -> void:
	for other: float in [ExpeditionRules.GUN_NOISE, ExpeditionRules.LOUD_GUN_NOISE, SiteManager.NOISE_SMASH, SiteManager.NOISE_TRAP,
			SiteManager.NOISE_BLAST, SiteManager.NOISE_COLLAPSE, HomesteadRules.LEDGER_NOISE]:
		assert_true(DynamiteRules.NOISE >= other * 2.0, "louder than %s by far" % str(other))
	assert_true(DynamiteRules.NOISE_HEAT > ExpeditionRules.SHOT_HEAT * 3.0)
	assert_almost(DynamiteRules.noise_heat(10.0, 0.0), DynamiteRules.NOISE_HEAT)
	assert_eq(DynamiteRules.noise_heat(DynamiteRules.NOISE + 1.0, 0.0), 0.0)
	assert_almost(DynamiteRules.noise_heat(10.0, ExpeditionRules.MAX_HEAT - 2.0), 2.0, 0.001, "within the risk clock's cap")
	# The risk clock takes the bigger heat through the same rule as gunshots.
	assert_almost(ExpeditionRules.shot_heat(10.0, DynamiteRules.NOISE, 0.0, DynamiteRules.NOISE_HEAT), DynamiteRules.NOISE_HEAT)
	assert_almost(ExpeditionRules.shot_heat(10.0, 45.0, 0.0), ExpeditionRules.SHOT_HEAT)


func test_teammates_are_knocked_not_hurt() -> void:
	assert_almost(DynamiteRules.KNOCK, 3.0, 0.001, "three rocks' worth")
	assert_almost(DynamiteRules.knock_strength(0.0, 6.5), 1.0)
	assert_true(DynamiteRules.knock_strength(6.0, 6.5) < 0.5)
	assert_eq(DynamiteRules.knock_strength(6.6, 6.5), 0.0)
	assert_true(DynamiteRules.STAGGER >= 0.6 and DynamiteRules.STAGGER <= 1.0)


func test_kill_method() -> void:
	assert_eq(KillMethod.classify("Logan's Dynamite"), KillMethod.BLAST)
	assert_eq(KillMethod.classify("Logan's Coal Oil"), KillMethod.FIRE)
	assert_eq(KillMethod.classify("Logan"), KillMethod.BULLET)


func test_swing_hold_or_toggle() -> void:
	# Hold (the default): letting go of right click lets go.
	assert_false(GrappleRules.swing_lets_go(true, false, true, false, false, false))
	assert_true(GrappleRules.swing_lets_go(true, false, false, false, false, false))
	# Toggle: still swinging with the button up; a second click lets go...
	assert_false(GrappleRules.swing_lets_go(true, true, false, false, false, false))
	assert_true(GrappleRules.swing_lets_go(true, true, true, true, false, false))
	# ...but not the click that hooked on.
	assert_false(GrappleRules.swing_lets_go(true, true, true, true, false, true))
	# Jump always lets go.
	assert_true(GrappleRules.swing_lets_go(true, true, false, false, true, false))
	# Free Hands, another weapon out: only jump.
	assert_false(GrappleRules.swing_lets_go(false, false, false, false, false, false))
	assert_false(GrappleRules.swing_lets_go(false, true, true, true, false, false))
	assert_true(GrappleRules.swing_lets_go(false, false, false, false, true, false))


func test_free_hands_code_toggles() -> void:
	assert_true(SecretCodes.is_secret("ability", String(SecretCodes.GRAPPLE_ANY)))
	var prof := PerkProfile.new()
	var on := [{"kind": "ability", "id": String(SecretCodes.GRAPPLE_ANY)}]
	var added := prof.unlock_secret(on)
	assert_eq(added.size(), 1)
	assert_true(prof.has_secret("ability", String(SecretCodes.GRAPPLE_ANY)))
	added = prof.unlock_secret(on)
	assert_true(bool((added[0] as Dictionary).get("off", false)), "the code again switches it off")
	assert_false(prof.has_secret("ability", String(SecretCodes.GRAPPLE_ANY)))
