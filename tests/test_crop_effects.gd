extends TestCase
## The universal crop-fed turrets (Nov 2026 handoff): the nine crops and their
## effects (CropEffects), the bug statuses they leave (BugStatus: stacking slow,
## poison stacks, volatile, the mark), the universal tier tables (TurretDef.UNI_*)
## and the registry (30 cf_* turrets, the retired crop-specific ones off the menu).


class FakeHealth:
	var hurt := 0.0

	func take_damage(amount: float, _source: String, _cliff: int) -> void:
		hurt += amount


class FakeBug:
	var def := BugDef.new()
	var health := FakeHealth.new()
	var entombed := 0.0


func _status() -> BugStatus:
	return BugStatus.new(FakeBug.new())


func test_nine_crops_each_with_an_effect_colour_and_sack() -> void:
	assert_eq(CropEffects.IDS.size(), 9)
	var effects := {}
	for c: StringName in CropEffects.IDS:
		assert_true(Defs.CROPS.has(c), "%s is a crop" % c)
		assert_true(CropEffects.effect_name(c) != "", "%s has an effect" % c)
		assert_true(CropEffects.sack_of(c) != &"", "%s has a sack" % c)
		assert_true(EconomyLedger.RESOURCES.has(CropEffects.sack_of(c)), "%s's sack is a resource" % c)
		effects[CropEffects.effect_name(c)] = true
	assert_eq(effects.size(), 9, "nine different effects")
	assert_eq(CropEffects.effect_name(&"corn"), "Ricochet")
	assert_eq(CropEffects.effect_name(&"sarsaparilla"), "Mark")
	assert_eq(CropEffects.color_of(&"firecracker_chili"), Color("#FF4500"))
	assert_eq(CropEffects.color_of(&""), CropEffects.EMPTY_COLOR)


func test_strength_scales_with_tier() -> void:
	assert_almost(CropEffects.strength(0), 1.0)
	assert_almost(CropEffects.strength(1), 1.25)
	assert_almost(CropEffects.strength(2), 1.5)
	assert_almost(CropEffects.armour_ignored(&"prickly_pear", 0), 0.5)
	assert_almost(CropEffects.armour_ignored(&"prickly_pear", 2), 0.75)
	assert_almost(CropEffects.armour_ignored(&"corn", 2), 0.0, 0.001, "only prickly pear pierces")
	assert_almost(CropEffects.entangle_chance(0), 0.15)
	assert_almost(CropEffects.stagger_time(false, 0), 0.3)
	assert_almost(CropEffects.stagger_time(true, 0), 0.5, 0.001, "heavy guns stagger longer")
	assert_almost(CropEffects.mark_bonus(0), 0.2)


func test_cotton_slow_stacks_to_half() -> void:
	var st := _status()
	st.crop_slow(CropEffects.slow_step(0), CropEffects.slow_max(0), CropEffects.SLOW_TIME)
	assert_almost(st.speed_multiplier(), 0.75)
	st.crop_slow(CropEffects.slow_step(0), CropEffects.slow_max(0), CropEffects.SLOW_TIME)
	assert_almost(st.speed_multiplier(), 0.5)
	st.crop_slow(CropEffects.slow_step(0), CropEffects.slow_max(0), CropEffects.SLOW_TIME)
	assert_almost(st.speed_multiplier(), 0.5, 0.001, "capped at half")
	st.tick(2.1)
	assert_almost(st.speed_multiplier(), 1.0, 0.001, "wears off after 2 s")


func test_herb_poison_stacks_three_times() -> void:
	var st := _status()
	var hp: FakeHealth = st.bug.health
	for i in 4:
		st.poison(2.0, 3.0, CropEffects.POISON_STACKS, "test", 0)
	assert_eq(st.poison_stacks(), 3, "three stacks at most")
	st.tick(1.0)
	assert_almost(hp.hurt, 6.0, 0.01, "three stacks of 2/s for a second")
	st.tick(2.5)
	assert_eq(st.poison_stacks(), 0, "gone after 3 s")
	assert_almost(hp.hurt, 18.0, 0.01, "each stack ran its 3 s")


func test_mark_and_volatile() -> void:
	var st := _status()
	assert_almost(st.damage_taken_mult(), 1.0)
	st.crop_mark(CropEffects.MARK_TIME, CropEffects.mark_bonus(0))
	assert_almost(st.damage_taken_mult(), 1.2)
	st.crop_mark(CropEffects.MARK_TIME, CropEffects.mark_bonus(0))
	assert_almost(st.damage_taken_mult(), 1.2, 0.001, "doesn't stack")
	st.tick(3.1)
	assert_almost(st.damage_taken_mult(), 1.0, 0.001, "3 s")
	st.volatile(CropEffects.VOLATILE_TIME, 1.25, "x", 1)
	assert_true(st.is_volatile())
	assert_almost(CropEffects.volatile_damage(100.0, st.volatile_k()), 37.5)
	st.tick(4.1)
	assert_false(st.is_volatile())


func test_universal_tiers() -> void:
	var d := Defs.turret(&"cf_crop_hopper")
	assert_true(d.universal and d.is_crop_fed())
	assert_almost(d.damage_at(1) / d.damage_at(0), 1.4)
	assert_almost(d.damage_at(2) / d.damage_at(0), 2.0)
	assert_almost(d.interval_at(0) / d.interval_at(1), 1.15)
	assert_almost(d.interval_at(0) / d.interval_at(2), 1.3)
	assert_eq(d.uni_upgrade_cost(1), int(roundf(d.cost_scrap * 1.8 * 0.85)))
	assert_eq(d.uni_upgrade_cost(2), int(roundf(d.cost_scrap * 3.0 * 0.85)))
	assert_eq(TurretDef.UNI_TIER_WAVES, [1, 5, 10] as Array[int])


func test_registry() -> void:
	var all: Array = Defs.UNIVERSAL_CLIFF + Defs.UNIVERSAL_AA + Defs.UNIVERSAL_LAST + Defs.UNIVERSAL_OBSTRUCTIONS + Defs.UNIVERSAL_CREWED
	assert_eq(all.size(), 30)
	var menu := {}
	for cat: Dictionary in Defs.BUILD_CATEGORIES:
		for id: StringName in cat["items"]:
			menu[id] = true
	for id: StringName in all:
		assert_true(Defs.is_universal(id), "%s is universal" % id)
		assert_true(menu.has(id), "%s is in the build menu" % id)
		assert_true(UniversalBuilder.has(id))
	for id: StringName in Defs.RETIRED_TURRETS:
		assert_false(menu.has(id), "%s is off the menu" % id)
		assert_false(Defs.TURRETS.has(id), "%s is archived (not registered)" % id)
		assert_false(ResourceLoader.exists("res://data/turrets/%s.tres" % id), "%s's data is in the archive" % id)
		assert_false(RiggedTurret.has(id), "%s's model is in the archive" % id)
	assert_false(menu.has(&"big_bertha"), "Big Bertha cut for now (Logan)")
	assert_false(menu.has(&"whaler"), "the Whaler goes (Logan)")
	for id: StringName in Defs.UNIVERSAL_CLIFF:
		assert_true(Defs.is_cliff_turret(id), "%s is a cliff turret" % id)
		assert_true(Defs.turret(id).cone_deg in [15.0, 30.0, 45.0], "%s has a 15/30/45 cone" % id)
	for id: StringName in Defs.UNIVERSAL_LAST:
		assert_true(Defs.is_house_turret(id), "%s mounts on the house" % id)
	for id: StringName in Defs.UNIVERSAL_OBSTRUCTIONS:
		assert_true(Defs.turret(id).obstruction and not Defs.gets_scaffold(id), "%s is a ground obstruction" % id)
	for id: StringName in Defs.UNIVERSAL_CREWED:
		assert_true(Defs.is_crewed(id), "%s is crewed" % id)
	for id: StringName in Defs.UNIVERSAL_AA:
		assert_true(Defs.turret(id).anti_air, "%s shoots fliers" % id)


func test_every_model_builds() -> void:
	for id: StringName in Defs.UNIVERSAL_CLIFF + Defs.UNIVERSAL_AA + Defs.UNIVERSAL_LAST + Defs.UNIVERSAL_OBSTRUCTIONS + Defs.UNIVERSAL_CREWED:
		var s := UniversalBuilder.spec(id, Color.WHITE)
		assert_false((s.get("parts", []) as Array).is_empty(), "%s has parts" % id)
		assert_false((s.get("muzzles", []) as Array).is_empty(), "%s has a muzzle" % id)
		var whole := UniversalBuilder.turret_parts(id, Color.WHITE)["base"] as ArrayMesh
		assert_true(whole.get_surface_count() > 0, "%s has a ghost mesh" % id)
