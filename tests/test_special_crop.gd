extends TestCase
## Special weapons (slot 2, Nov 2026 special weapons handoff): the permanent crop
## upgrade in the gun's code (SpecialCrop), its reduced strengths and level
## scaling, the weakened status (BugStatus.weaken), the ten weapons' registry
## and the old secondaries moved to primary.

const IDS: Array[StringName] = [&"crop_duster", &"barb_sling", &"signal_flare", &"crop_syringe", &"smoke_bellows",
	&"bramble_pistol", &"spore_launcher", &"venom_needle", &"trip_wire_gun", &"spark_pistol"]


class FakeHealth:
	var hurt := 0.0

	func take_damage(amount: float, _source: String, _cliff: int) -> void:
		hurt += amount


class FakeBug:
	var def := BugDef.new()
	var health := FakeHealth.new()
	var entombed := 0.0


func test_crop_rides_in_the_code_and_keeps_level_and_mods() -> void:
	var code := WeaponMods.with_mod(WeaponMods.with_level(0, 2), 1)
	assert_eq(SpecialCrop.crop_of(code), &"", "a new gun has no crop")
	for crop: StringName in CropEffects.IDS:
		var c := SpecialCrop.with_crop(code, crop)
		assert_eq(SpecialCrop.crop_of(c), crop, "%s round-trips" % crop)
		assert_eq(WeaponMods.level(c), 2, "level kept with %s" % crop)
		assert_true(WeaponMods.has_mod(c, 1), "mod kept with %s" % crop)
		assert_false(WeaponMods.has_mod(c, 0) or WeaponMods.has_mod(c, 2), "no mods added by %s" % crop)
		assert_eq(SpecialCrop.crop_of(SpecialCrop.with_crop(c, &"")), &"", "removing %s clears it" % crop)
	# Legendary (the level's high bit 10) and Lucky's finish (bit 9) survive too.
	var legend := SpecialCrop.with_crop(WeaponMods.with_level(AmberRules.LUCKY_BIT, 4), &"sarsaparilla")
	assert_eq(WeaponMods.level(legend), 4)
	assert_eq(SpecialCrop.crop_of(legend), &"sarsaparilla")
	assert_true(legend & AmberRules.LUCKY_BIT != 0, "Lucky's finish kept")
	assert_eq(SpecialCrop.MASK & (WeaponMods.LEVEL_HIGH_BIT | AmberRules.LUCKY_BIT | WeaponMods.GOLDEN_BIT | 0x1F), 0,
			"the crop bits don't overlap level, mods, golden or Lucky's")


func test_reduced_strengths_are_the_handoffs() -> void:
	assert_almost(SpecialCrop.RICOCHET_SHARE, 0.35)
	assert_almost(SpecialCrop.SPLASH_RADIUS, 1.5)
	assert_almost(SpecialCrop.PIERCE_SHARE, 0.35)
	assert_almost(SpecialCrop.SLOW_STEP, 0.18)
	assert_almost(SpecialCrop.SLOW_MAX, 0.36)
	assert_eq(SpecialCrop.POISON_STACKS, 2)
	assert_almost(SpecialCrop.POISON_TIME, 2.0)
	assert_almost(SpecialCrop.VOLATILE_K * CropEffects.VOLATILE_SHARE, 0.2)
	assert_almost(SpecialCrop.STAGGER, 0.2)
	assert_almost(SpecialCrop.ENTANGLE_CHANCE, 0.1)
	assert_almost(SpecialCrop.ENTANGLE_TIME, 0.7)
	assert_almost(SpecialCrop.MARK_BONUS, 0.15)
	assert_almost(SpecialCrop.MARK_TIME, 2.0)
	# Every one stays under the turret value (at base strength).
	assert_true(SpecialCrop.RICOCHET_SHARE < CropEffects.RICOCHET_SHARE)
	assert_true(SpecialCrop.SLOW_STEP < CropEffects.SLOW_STEP)
	assert_true(SpecialCrop.MARK_BONUS < CropEffects.MARK_BONUS)


func test_level_scaling_and_the_needles_double_dose() -> void:
	assert_almost(SpecialCrop.level_k(WeaponMods.with_level(0, 0)), 1.0)
	assert_almost(SpecialCrop.level_k(WeaponMods.with_level(0, 1)), 1.15)
	assert_almost(SpecialCrop.level_k(WeaponMods.with_level(0, 2)), 1.3)
	assert_almost(SpecialCrop.armour_ignored(&"prickly_pear", 1.0), 0.35)
	assert_almost(SpecialCrop.armour_ignored(&"corn", 1.0), 0.0)
	# Venom Needle: x2 at base (Cotton 36% a hit, Prickly Pear 70% armour).
	var k := 2.0 * SpecialCrop.level_k(0)
	assert_almost(SpecialCrop.SLOW_STEP * k, 0.36)
	assert_almost(SpecialCrop.armour_ignored(&"prickly_pear", k), 0.7)
	assert_true(SpecialCrop.preview(&"corn").begins_with("Corn - Ricochet"))
	assert_true(SpecialCrop.preview(&"corn").contains("35%"))


func test_weakened_multiplies_with_the_mark() -> void:
	var st := BugStatus.new(FakeBug.new())
	assert_almost(st.damage_taken_mult(), 1.0)
	st.weaken(4.0, 0.15)
	assert_true(st.is_weakened())
	assert_almost(st.damage_taken_mult(), 1.15)
	st.crop_mark(2.0, 0.15)
	assert_almost(st.damage_taken_mult(), 1.15 * 1.15)
	st.weaken(1.0, 0.1) # a weaker one doesn't lower it
	assert_almost(st.damage_taken_mult(), 1.15 * 1.15)
	st.tick(2.5)
	assert_almost(st.damage_taken_mult(), 1.15, 0.001, "the mark ran out")
	st.tick(2.0)
	assert_false(st.is_weakened())
	assert_almost(st.damage_taken_mult(), 1.0)


func test_ten_specials_registered_in_the_special_slot() -> void:
	for id: StringName in IDS:
		assert_true(Defs.WEAPONS.has(id), "%s registered" % id)
		var w: WeaponDef = Defs.WEAPONS[id]
		assert_eq(w.id, id)
		assert_eq(int(w.slot), int(WeaponDef.Slot.SECONDARY), "%s in slot 2" % id)
		assert_true(w.price_chitin > 0, "%s has a price" % id)
	var prices := {&"crop_duster": 25, &"barb_sling": 20, &"signal_flare": 35, &"crop_syringe": 30, &"smoke_bellows": 30,
		&"bramble_pistol": 25, &"spore_launcher": 30, &"venom_needle": 35, &"trip_wire_gun": 25, &"spark_pistol": 30}
	for id: StringName in prices:
		assert_eq((Defs.WEAPONS[id] as WeaponDef).price_chitin, prices[id], "%s price" % id)


func test_old_secondaries_are_primaries_now() -> void:
	for id: StringName in [&"derringer_pair", &"pepperbox", &"harpoon_pistol", &"bee_smoker", &"salt_shotgun", &"flare_gun", &"telescope_rifle"]:
		assert_eq(int((Defs.WEAPONS[id] as WeaponDef).slot), int(WeaponDef.Slot.PRIMARY), "%s is a primary" % id)


func test_design_doc_stats_and_three_mods_each() -> void:
	# [damage, mag, range, reload] from the design doc (ranges from the Nov 11
	# playtest fixes: every special reaches the other cliff, 60 m or more).
	var want := {&"crop_duster": [8, 12, 60, 1.8], &"barb_sling": [6, 4, 60, 2.0], &"signal_flare": [15, 1, 160, 2.8],
		&"crop_syringe": [15, 4, 65, 2.0], &"smoke_bellows": [0, 100, 60, 0.0], &"bramble_pistol": [15, 6, 65, 1.8],
		&"spore_launcher": [18, 3, 65, 2.5], &"venom_needle": [10, 1, 120, 1.5], &"trip_wire_gun": [20, 6, 65, 2.5],
		&"spark_pistol": [12, 8, 60, 1.8]}
	for id: StringName in want:
		var w: WeaponDef = Defs.WEAPONS[id]
		var v: Array = want[id]
		assert_almost(w.damage, float(v[0]), 0.01, "%s damage" % id)
		assert_eq(w.mag_size, int(v[1]), "%s mag" % id)
		assert_almost(w.range, float(v[2]), 0.01, "%s range" % id)
		assert_almost(w.reload_time, float(v[3]), 0.01, "%s reload" % id)
		assert_eq(WeaponMods.list(id).size(), 3, "%s has three mods" % id)
	assert_eq((Defs.WEAPONS[&"barb_sling"] as WeaponDef).pellets, 5)
	# The retired Weapon Slots secondaries are gone from the game (archived).
	for id: StringName in [&"screamer_pistol", &"tar_sprayer", &"phosphor_grenade"]:
		assert_false(Defs.WEAPONS.has(id), "%s retired" % id)
		assert_false(WeaponMods.MODS.has(id), "%s's mods archived" % id)
