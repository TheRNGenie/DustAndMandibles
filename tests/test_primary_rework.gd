extends TestCase
## The Nov 10 primary weapons evaluation and Logan's Nov 11 pool: 10 primaries
## and 10 specials, the Concussion Mortar, Repeating Crossbow and Coach slugs.


## (Gun itself needs the autoloads, so this reads the defs straight.)
func _shop(slot: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Defs.WEAPONS:
		var w: WeaponDef = Defs.WEAPONS[id]
		if int(w.slot) == slot and not Defs.is_retired(id):
			out.append(id)
	return out


func test_ten_primaries_and_ten_specials() -> void:
	var p := _shop(0)
	assert_eq(p.size(), 10, "primaries: %s" % str(p))
	for id: StringName in [&"revolver", &"lever_rifle", &"coach_shotgun", &"concussion_mortar", &"crank_gatling",
			&"elephant_gun", &"punt_gun", &"derringer_pair", &"repeating_crossbow", &"telescope_rifle"]:
		assert_true(p.has(id), "%s on sale" % id)
	assert_eq(_shop(1).size(), 10, "specials")
	for id: StringName in [&"blunderbuss", &"pepperbox", &"salt_shotgun", &"harpoon_pistol", &"bee_smoker", &"flare_gun"]:
		assert_true(Defs.is_retired(id), "%s archived" % id)
		assert_true(Defs.WEAPONS.has(id), "%s still registered (old saves)" % id)


func test_concussion_mortar() -> void:
	var w := Defs.WEAPONS[&"concussion_mortar"] as WeaponDef
	assert_almost(w.damage, 160.0, 0.01)
	assert_eq(w.mag_size, 1)
	assert_almost(w.range, 60.0, 0.01)
	assert_eq(w.special, &"mortar")
	# 4 m blast: full in the inner 2 m, 60% in the outer 2 m, none past it.
	var r := ArmoryHeavyRules.CONCUSSION_RADIUS
	assert_almost(ArmoryHeavyRules.blast_share(1.0, r, ArmoryHeavyRules.CONCUSSION_RING), 1.0, 0.001)
	assert_almost(ArmoryHeavyRules.blast_share(3.0, r, ArmoryHeavyRules.CONCUSSION_RING), 0.6, 0.001)
	assert_almost(ArmoryHeavyRules.blast_share(4.5, r, ArmoryHeavyRules.CONCUSSION_RING), 0.0, 0.001)
	assert_eq(WeaponMods.list(&"concussion_mortar").size(), 3)
	assert_almost(WeaponMods.mult(&"concussion_mortar", WeaponMods.with_mod(0, 0), "radius"), 1.4, 0.001, "Packed Powder")
	assert_true(WeaponMods.flag(&"concussion_mortar", WeaponMods.with_mod(0, 2), "burn"), "Incendiary Filler")


func test_repeating_crossbow_bleeds() -> void:
	var w := Defs.WEAPONS[&"repeating_crossbow"] as WeaponDef
	assert_almost(w.damage, 14.0, 0.01)
	assert_eq(w.mag_size, 10)
	assert_eq(w.special, &"bleed")
	assert_eq(GunRules.bleed_stacks(&"repeating_crossbow", 0), 5)
	assert_eq(GunRules.bleed_stacks(&"repeating_crossbow", WeaponMods.with_mod(0, 0)), 8, "Barbed Heads")
	assert_almost(ExpeditionRules.gun_noise(&"bleed", 0.0, 1), 0.0, 0.001, "near silent")
	# Bleed stacks on the bug's status, up to the cap.
	var st := BugStatus.new(null)
	for i in 7:
		st.poison(GunRules.BLEED_DPS, GunRules.BLEED_TIME, 5, "Tester", 0)
	assert_eq(st.poison_stacks(), 5)


func test_coach_slugs() -> void:
	var id := &"coach_shotgun"
	var buck := 0
	var slug := GunRules.toggle_slug(buck)
	assert_true(GunRules.is_slug(id, slug))
	assert_false(GunRules.is_slug(id, buck))
	assert_false(GunRules.is_slug(&"revolver", slug), "only the Coach")
	assert_almost(GunRules.SLUG_DAMAGE, 90.0, 0.01)
	assert_almost(GunRules.SLUG_RANGE, 100.0, 0.01)
	var rifled := WeaponMods.with_mod(slug, 0)
	assert_almost(WeaponMods.mult(id, rifled, "slug_damage"), 1.25, 0.001, "Rifled Bore damage")
	assert_almost(WeaponMods.mult(id, rifled, "slug_range"), 1.5, 0.001, "Rifled Bore range")
	assert_true(WeaponMods.flag(id, WeaponMods.with_mod(0, 2), "express"), "Express Loader")
	assert_eq(WeaponMods.level(slug), 0, "the slug bit isn't a level")
	assert_eq(GunRules.toggle_slug(slug), buck)
