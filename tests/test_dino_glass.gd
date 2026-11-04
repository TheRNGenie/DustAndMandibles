extends TestCase
## The Dino Rifle's glass: six fits, stored in the gun's code without touching level or mods.


func test_six_fits() -> void:
	assert_eq(DinoGlass.VARIANTS.size(), 6)
	assert_almost(float(DinoGlass.VARIANTS[0]["zoom"]), 3.5, 0.001, "the good one is 3.5x")
	assert_false(bool(DinoGlass.VARIANTS[5]["scoped"]), "knocked flat: no scope")


func test_code_round_trip_keeps_level_and_mods() -> void:
	var code := WeaponMods.with_mod(2, 1) # level 2, second mod
	for v in 6:
		var c := DinoGlass.with_variant(code, v)
		assert_eq(DinoGlass.of(c), v)
		assert_eq(WeaponMods.level(c), 2)
		assert_true(WeaponMods.has_mod(c, 1))
		assert_false(WeaponMods.has_mod(c, 0))
	# Upgrading (+1 on the code) keeps the fit.
	assert_eq(DinoGlass.of(DinoGlass.with_variant(0, 4) + 1), 4)


func test_rolls_are_spread_evenly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 6000:
		counts[DinoGlass.roll(rng)] += 1
	for n: int in counts:
		assert_true(n > 850 and n < 1150, "each fit about 1 in 6 (got %d)" % n)


func test_scoped_gun_model_stays_away_while_an_item_is_out() -> void:
	# Put away for the grapple, lighter, bucket, a crop or empty hands, the last
	# gun's model must not show (it used to, for the scoped guns: wrong model, no shot).
	for item: StringName in [&"grapple", &"lighter", &"water", &"herbs", &"corn", &"none"]:
		assert_false(GunRules.model_shown(item, false), "%s out: no gun model" % item)
	assert_true(GunRules.model_shown(&"", false), "gun in hand: shown")
	assert_false(GunRules.model_shown(&"", true), "looking through the glass: hidden")
	for id: StringName in [&"elephant_gun", &"dino_rifle", &"telescope_rifle"]:
		assert_true(GunRules.SCOPED.has(id))
