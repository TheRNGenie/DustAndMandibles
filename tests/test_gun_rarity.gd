extends TestCase
## Gun rarity (GunRarity): Common to Legendary, Meteor Iron for the last step.


func test_five_rarities_climb() -> void:
	assert_eq(GunRarity.NAMES.size(), 5)
	assert_eq(GunRarity.label(0), "Common (White)")
	assert_eq(GunRarity.label(4), "Legendary (Gold)")
	for r in range(1, 5):
		assert_true(GunRarity.damage_mult(r) > GunRarity.damage_mult(r - 1), "more damage at %s" % GunRarity.name_of(r))
		assert_true(GunRarity.reload_mult(r) < GunRarity.reload_mult(r - 1), "faster reload at %s" % GunRarity.name_of(r))


func test_costs_rise_and_legendary_takes_iron() -> void:
	var base := PackedInt32Array([10, 25])
	var last := 0
	for r in 4:
		var c := GunRarity.cost(base, r)
		assert_true(c > last, "step %d costs more" % r)
		last = c
	assert_eq(GunRarity.cost(base, 4), -1, "nothing past Legendary")
	assert_false(GunRarity.needs_item(2))
	assert_true(GunRarity.needs_item(3), "Epic to Legendary takes Meteor Iron")
	assert_eq(int(GunRarity.price(base, 3).get(GunRarity.ITEM, 0)), 1)
	assert_true(EconomyLedger.RESOURCES.has(GunRarity.ITEM))


func test_level_bits_reach_legendary_and_keep_mods() -> void:
	var code := WeaponMods.with_mod(0, 1)
	for r in 5:
		code = WeaponMods.with_level(code, r)
		assert_eq(WeaponMods.level(code), r)
		assert_true(WeaponMods.has_mod(code, 1), "mods kept at %d" % r)
	assert_eq(WeaponMods.count(code), 1)
	assert_true(Gun.damage_for(&"revolver", WeaponMods.with_level(0, 4)) > Gun.damage_for(&"revolver", 0) * 1.9)
