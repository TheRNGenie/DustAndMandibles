extends TestCase
## The universal crop-loaded heavies (heavy weapons handoff): the ten guns' data,
## the sack economy (load, swap, persist, drop), crop strength per upgrade, the
## mods, and the maths behind lobs, cones, the spike's shockwave, the gatling's
## heat, the bola and the kegs.


func test_ten_heavies_are_registered_in_the_heavy_slot() -> void:
	assert_eq(HeavyRules.IDS.size(), 10)
	var shots := {&"crop_mortar": 15, &"hand_cannon": 10, &"crop_sprayer": 40, &"spike_driver": 5, &"drum_launcher": 30,
		&"harvest_gatling": 150, &"crop_crossbow": 20, &"bola_launcher": 10, &"powder_keg_launcher": 15, &"crop_blunderbuss": 15}
	var prices := {&"crop_mortar": 80, &"hand_cannon": 100, &"crop_sprayer": 60, &"spike_driver": 90, &"drum_launcher": 70,
		&"harvest_gatling": 85, &"crop_crossbow": 75, &"bola_launcher": 70, &"powder_keg_launcher": 75, &"crop_blunderbuss": 80}
	for id: StringName in HeavyRules.IDS:
		var w: WeaponDef = Defs.WEAPONS.get(id)
		assert_true(w != null, "%s registered" % id)
		assert_eq(int(w.slot), int(WeaponDef.Slot.HEAVY), "%s is a heavy" % id)
		assert_true(w.crop_ammo, "%s loads any crop" % id)
		assert_eq(w.crop, &"", "%s isn't tied to one crop" % id)
		assert_eq(w.mag_size, int(shots[id]), "%s shots a sack" % id)
		assert_eq(w.price_chitin, int(prices[id]), "%s price" % id)
		assert_true(HeavyRules.handles(w.special), "%s has a heavy special" % id)
		assert_eq(WeaponMods.list(id).size(), 3, "%s has three mods" % id)
		assert_true(UniHeavies.has(id), "%s has a model" % id)
		assert_true(Gun.ORDER.has(id), "%s is on the shelf" % id)
		assert_true(w.stat_line().contains("Shots a Sack"), "%s's stat line" % id)
	assert_true(Defs.WEAPONS[&"hand_cannon"].pierce_armor, "the Hand Cannon pierces armour")


func test_old_heavies_leave_the_heavy_slot() -> void:
	for id: StringName in [&"elephant_gun", &"punt_gun", &"swivel_gun"]:
		var w: WeaponDef = Defs.WEAPONS[id]
		assert_eq(int(w.slot), int(WeaponDef.Slot.PRIMARY), "%s is a primary" % id)
		assert_eq(w.crop, &"", "%s takes ordinary ammunition" % id)
	for id: StringName in HeavyRules.ARCHIVED_PRICES:
		assert_false(Defs.WEAPONS.has(id), "%s archived" % id)
		assert_false(Gun.ORDER.has(id), "%s off the shelf" % id)
	var fit := Gun.fit_slots({&"revolver": 0, &"mortar_tube": 0})
	assert_false((fit[0] as Dictionary).has(&"mortar_tube"), "an old save's archived heavy is dropped (and paid back)")
	for id: StringName in Defs.WEAPONS:
		var w: WeaponDef = Defs.WEAPONS[id]
		if int(w.slot) == int(WeaponDef.Slot.HEAVY) and not Defs.is_retired(id):
			assert_true(w.crop_ammo, "only universal heavies in the heavy slot: %s" % id)


func test_crop_strength_follows_the_handoff_levels() -> void:
	# Common / Uncommon (Level 1) / Rare (Level 2).
	assert_almost(CropEffects.RICOCHET_SHARE * HeavyRules.crop_strength(&"corn", 1), 0.55)
	assert_almost(CropEffects.RICOCHET_SHARE * HeavyRules.crop_strength(&"corn", 2), 0.6)
	assert_almost(CropEffects.PIERCE_SHARE * HeavyRules.crop_strength(&"prickly_pear", 2), 0.6)
	assert_almost(CropEffects.SLOW_STEP * HeavyRules.crop_strength(&"cotton", 1), 0.28)
	assert_almost(CropEffects.SLOW_STEP * HeavyRules.crop_strength(&"cotton", 2), 0.3)
	assert_almost(CropEffects.VOLATILE_SHARE * HeavyRules.crop_strength(&"sulfur_root", 2), 0.36)
	assert_almost(CropEffects.STAGGER_HEAVY * HeavyRules.crop_strength(&"barrel_cactus", 1), 0.55)
	assert_almost(CropEffects.ENTANGLE_CHANCE * HeavyRules.crop_strength(&"tumbleweed_vine", 1), 0.17)
	assert_almost(CropEffects.ENTANGLE_CHANCE * HeavyRules.crop_strength(&"tumbleweed_vine", 2), 0.2)
	assert_almost(CropEffects.MARK_BONUS * HeavyRules.crop_strength(&"sarsaparilla", 1), 0.22)
	assert_almost(CropEffects.MARK_BONUS * HeavyRules.crop_strength(&"sarsaparilla", 2), 0.25)
	assert_almost(HeavyRules.crop_strength(&"firecracker_chili", 2), 1.3, 0.001, "chili splash +30%")
	assert_almost(HeavyRules.crop_strength(&"herbs", 1), 1.15, 0.001, "herbs +15% a tick")
	for c: StringName in CropEffects.IDS:
		assert_almost(HeavyRules.crop_strength(c, 0), 1.0, 0.001, "%s base" % c)
		assert_true(HeavyRules.crop_strength(c, 4) >= HeavyRules.crop_strength(c, 3), "%s keeps growing" % c)
		assert_true(HeavyRules.COLORS.has(c), "%s colour" % c)


func test_loading_a_sack_fills_and_swapping_throws_the_rest_away() -> void:
	var r := HeavyRules.load_result(&"", 0, &"corn", 15)
	assert_eq(int(r["shots"]), 15)
	assert_eq(int(r["lost"]), 0)
	assert_false(bool(r["swap"]))
	r = HeavyRules.load_result(&"corn", 6, &"cotton", 15)
	assert_eq(int(r["shots"]), 15, "the new crop's full count")
	assert_eq(int(r["lost"]), 6, "no refund")
	assert_true(bool(r["swap"]))
	r = HeavyRules.load_result(&"corn", 4, &"corn", 15)
	assert_eq(int(r["shots"]), 15)
	assert_false(bool(r["swap"]), "a fresh sack of the same crop isn't a swap")


func test_host_counts_shots_and_keeps_them() -> void:
	HeavyAmmo.reset()
	assert_eq(HeavyAmmo.take_shot(7, &"crop_mortar")["crop"], &"", "an empty gun fires nothing")
	HeavyAmmo.put(7, &"crop_mortar", &"herbs", 2)
	var s := HeavyAmmo.take_shot(7, &"crop_mortar")
	assert_eq(s["crop"], &"herbs")
	assert_false(bool(s["ran_out"]))
	s = HeavyAmmo.take_shot(7, &"crop_mortar")
	assert_true(bool(s["ran_out"]), "the last shell")
	assert_eq(HeavyAmmo.take_shot(7, &"crop_mortar")["crop"], &"", "then it's empty")
	HeavyAmmo.put(7, &"crop_mortar", &"corn", 9)
	# A saved run (through JSON) brings it back.
	var back := HeavyAmmo.from_save(JSON.parse_string(JSON.stringify(HeavyAmmo.save_of(7))))
	assert_eq(back[&"crop_mortar"][0], &"corn")
	assert_eq(int(back[&"crop_mortar"][1]), 9)
	assert_true(HeavyAmmo.from_save({"crop_mortar": ["not_a_crop", 3]}).is_empty(), "junk ignored")
	HeavyAmmo.forget(7, &"crop_mortar")
	assert_eq(int(HeavyAmmo.of(7, &"crop_mortar")[1]), 0)
	HeavyAmmo.reset()


func test_low_ammo_is_the_last_tenth() -> void:
	assert_true(HeavyRules.is_low(1, 15))
	assert_true(HeavyRules.is_low(2, 15))
	assert_false(HeavyRules.is_low(3, 15))
	assert_false(HeavyRules.is_low(0, 15), "empty isn't low, it's empty")
	assert_true(HeavyRules.is_low(15, 150))
	assert_false(HeavyRules.is_low(16, 150))


func test_lobs_and_cones() -> void:
	var from := Vector3.ZERO
	var near := HeavyRules.lob_target(from, Vector3(0, 0, -3), HeavyRules.MORTAR_MIN)
	assert_almost(Vector2(near.x, near.z).length(), HeavyRules.MORTAR_MIN, 0.01, "mortar can't drop closer than 8 m")
	var far := HeavyRules.lob_target(from, Vector3(0, -5, -40), HeavyRules.MORTAR_MIN)
	assert_eq(far, Vector3(0, -5, -40))
	assert_almost(HeavyRules.lob_at(from, far, 0.0, true).distance_to(from), 0.0)
	assert_almost(HeavyRules.lob_at(from, far, 1.0, true).distance_to(far), 0.0)
	assert_true(HeavyRules.lob_at(from, far, 0.5, true).y > HeavyRules.lob_at(from, far, 0.5, false).y, "the mortar's shell goes higher")
	assert_true(HeavyRules.lob_peak(40.0, true) > HeavyRules.lob_peak(40.0, false), "the mortar arcs higher than the drum")
	assert_almost(HeavyRules.blast_share(0.0, 4.0, 0.5), 1.0)
	assert_almost(HeavyRules.blast_share(4.0, 4.0, 0.5), 0.5, 0.001, "half at the edge")
	assert_almost(HeavyRules.blast_share(4.1, 4.0, 0.5), 0.0)
	var dir := Vector3(0, 0, -1)
	assert_true(HeavyRules.in_cone(from, dir, Vector3(0, 0, -10), 45.0, 12.0))
	assert_true(HeavyRules.in_cone(from, dir, Vector3(3.5, 0, -10), 45.0, 12.0), "inside 22.5 deg")
	assert_false(HeavyRules.in_cone(from, dir, Vector3(5.0, 0, -10), 45.0, 12.0), "outside it")
	assert_false(HeavyRules.in_cone(from, dir, Vector3(0, 0, -13), 45.0, 12.0), "past 12 m")
	assert_almost(HeavyRules.spray_cone(0), 45.0)
	assert_almost(HeavyRules.spray_cone(1 << 2), 60.0, 0.001, "Wider Nozzle")
	assert_almost(HeavyRules.spray_cone(1 << 4), 35.0, 0.001, "Concentrated Mix")


func test_spike_gatling_bola_and_kegs() -> void:
	assert_almost(HeavyRules.spike_wave(0), 5.0)
	assert_almost(HeavyRules.spike_knock(0), 3.0)
	assert_almost(HeavyRules.spike_wave(1 << 2), 7.0, 0.001, "Deeper Bore")
	assert_almost(HeavyRules.spike_knock(1 << 2), 4.0)
	assert_almost(HeavyRules.gatling_spread(0.0, 0), 3.0)
	assert_almost(HeavyRules.gatling_spread(75.0, 0), 6.0, 0.001, "widens to 6 after ~75 rounds")
	assert_almost(HeavyRules.gatling_extra(0.0, 0), 0.0)
	assert_true(HeavyRules.gatling_spread(75.0, 1 << 3) < 6.0, "Tightened Crank")
	assert_almost(HeavyRules.walk_mult(&"harvest_gatling", 1.0), 0.5)
	assert_almost(HeavyRules.walk_mult(&"harvest_gatling", 0.0), 1.0, 0.001, "only while it turns")
	assert_almost(HeavyRules.walk_mult(&"hand_cannon", 0.0), 0.95)
	assert_almost(HeavyRules.bola_hold(false, 0), 1.5)
	assert_almost(HeavyRules.bola_hold(true, 0), 0.5, 0.001, "bosses resist")
	assert_almost(HeavyRules.bola_hold(false, 1 << 2), 2.0, 0.001, "Heavier Weights")
	assert_almost(HeavyRules.bola_hold(true, 1 << 2), 0.75, 0.001)
	assert_eq(HeavyRules.bola_clips(1 << 3), 3, "Wider Swing")
	assert_almost(HeavyRules.bola_swing(1 << 3), 5.0)
	assert_eq(HeavyRules.keg_to_pop(7), -1)
	assert_eq(HeavyRules.keg_to_pop(8), 0, "a ninth keg sets off the oldest")
	assert_eq(HeavyRules.keg_tick(-1.0, 2.0, 10.0, 60.0, 5.0, 1.5), "", "waits")
	assert_eq(HeavyRules.keg_tick(-1.0, 2.0, 10.0, 60.0, 1.0, 1.5), "boom", "a bug close by")
	assert_eq(HeavyRules.keg_tick(2.1, 2.0, 0.0, 60.0, 9.0, 1.5), "boom", "the fuse burnt down")
	assert_eq(HeavyRules.keg_tick(-1.0, 2.0, 61.0, 60.0, 9.0, 1.5), "gone", "waited too long")
	assert_almost(HeavyRules.keg_life(1 << 2), 120.0, 0.001, "Sticky Tar")
	assert_almost(HeavyRules.keg_prox(1 << 4), 3.0, 0.001, "Hair Trigger")
	assert_almost(HeavyRules.keg_fuse(1 << 4), 1.0)


func test_fx_numbers_round_trip() -> void:
	for c: StringName in CropEffects.IDS:
		var x := HeavyRules.pack(c, 123.0)
		assert_eq(HeavyRules.unpack_crop(x), c)
		assert_almost(HeavyRules.unpack_n(x), 123.0)
	assert_eq(HeavyRules.unpack_crop(HeavyRules.pack(&"", 5.0)), &"")
	assert_eq(HeavyRules.CROPS, CropEffects.IDS, "the crop order matches the turrets'")


func test_models_have_a_ring_and_their_moving_parts() -> void:
	var need := {&"crop_mortar": ["door"], &"hand_cannon": ["door"], &"crop_sprayer": ["pump"], &"spike_driver": ["rack"],
		&"drum_launcher": ["cylinder", "door"], &"harvest_gatling": ["spinner", "crank", "door"],
		&"crop_crossbow": ["limb_l", "limb_r", "string", "bolt", "lever"], &"bola_launcher": ["cylinder", "door"],
		&"powder_keg_launcher": ["shell", "door"], &"crop_blunderbuss": ["door", "rod"]}
	for id: StringName in HeavyRules.IDS:
		var p := ArmoryGuns.parts(id)
		if not ArmoryGuns.fal(id).is_empty():
			# The fal model (batch 3): its body, the crop ring, and the parts it was cut into.
			assert_true(p.has("body") and p.has("ring"), "%s fal body and ring" % id)
			for part: String in (ArmoryGuns.fal(id).get("parts", {}) as Dictionary):
				assert_true(p.has(part), "%s fal model has %s" % [id, part])
				assert_true(need[id].has(part) or ArmoryGuns.LOADED_PARTS.has(part), "%s: %s is a part the gun moves" % [id, part])
		else:
			assert_true(p.has("body") and p.has("ring") and p.has("glow"), "%s body, ring, glow" % id)
			for part: String in need[id]:
				assert_true(p.has(part), "%s has %s" % [id, part])
		assert_eq(ArmoryGuns.slot_of(id), ArmoryGuns.HEAVY)
		assert_true(ArmoryGuns.hands(id).size() == 3, "%s hands" % id)
		# (a fal model's muzzle is where its own barrel ends: the Harvest Gatling's barrels sit just ahead of the grip)
		assert_true(ArmoryGuns.muzzle(id).z < (-0.1 if not ArmoryGuns.fal(id).is_empty() else -0.3), "%s muzzle forward" % id)


func test_hotbar_crop_and_upgrade_trim() -> void:
	assert_eq(HeavyRules.crop_of_item(&"chili"), &"firecracker_chili", "the hotbar's chili is the chili sack")
	assert_eq(HeavyRules.crop_of_item(&"corn"), &"corn")
	assert_eq(HeavyRules.crop_of_item(&"water"), &"", "not a crop")
	for id: StringName in HeavyRules.IDS:
		if not ArmoryGuns.fal(id).is_empty():
			continue # (the fal models carry no code-built trim bands)
		var p := ArmoryGuns.parts(id)
		assert_true(p.has("trim1") and p.has("trim2"), "%s has upgrade trim" % id)
	assert_almost(UniHeavies.TRIM_SCALE[1], 1.05)
	assert_almost(UniHeavies.TRIM_SCALE[2], 1.1)
