extends TestCase
## Gunsmith mods: packed with the level into one int, and their stat effects.


func test_level_and_mods_pack_together() -> void:
	var code := 2
	code = WeaponMods.with_mod(code, 1)
	assert_eq(WeaponMods.level(code), 2)
	assert_true(WeaponMods.has_mod(code, 1))
	assert_true(not WeaponMods.has_mod(code, 0))
	assert_eq(WeaponMods.count(code), 1)
	# A level upgrade keeps the mods.
	assert_true(WeaponMods.has_mod(code + 0, 1))


func test_mod_effects() -> void:
	var trigger := WeaponMods.with_mod(0, 0)
	assert_almost(WeaponMods.mult(&"revolver", trigger, "fire_interval"), 0.66)
	assert_almost(WeaponMods.mult(&"revolver", 0, "fire_interval"), 1.0)
	var drum := WeaponMods.with_mod(0, 1)
	assert_eq(WeaponMods.add(&"crank_gatling", drum, "mag"), 40)
	assert_true(WeaponMods.flag(&"revolver", WeaponMods.with_mod(0, 2), "pierce"))


func test_buckshot_adds_pellets() -> void:
	var shotgun: WeaponDef = load("res://data/weapons/coach_shotgun.tres")
	var heavy := WeaponMods.with_mod(0, 1)
	assert_eq(shotgun.pellets + WeaponMods.add(&"coach_shotgun", heavy, "pellets"), shotgun.pellets + 3)


func test_damage_stacks_level_and_mods() -> void:
	# Same formula as Gun.damage_for: base x (1 + 0.25 x level) x mod multiplier.
	var code := WeaponMods.with_mod(1, 2) # level 1 + hollow points
	var k := (1.0 + 0.25 * WeaponMods.level(code)) * WeaponMods.mult(&"revolver", code, "damage")
	assert_almost(k, 1.25 * 1.2)
