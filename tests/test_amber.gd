extends TestCase
## Hive amber: the item (weight, personal pile, floor loot), Lucky Moreau's
## stock and gun finishes, the three amber turrets' data and rules (recipes, one
## of each, the thirty-degree law, entomb / frenzy / drop / lance heat), statues
## in the bug crowd, and the saved amber blueprints.


func test_amber_is_a_heavy_personal_item() -> void:
	assert_eq(Backpack.weight_of(AmberRules.ITEM), 4)
	assert_eq(AmberRules.WEIGHT, Backpack.weight_of(AmberRules.ITEM))
	assert_true(EconomyLedger.RESOURCES.has(AmberRules.ITEM), "a stockpile resource")
	assert_false(EconomyLedger.is_shared(AmberRules.ITEM), "never the team pot")
	var l := EconomyLedger.new()
	l.reset({&"scrap": 100}, 2)
	l.earn(0, {AmberRules.ITEM: 7})
	assert_eq(l.amount(0, AmberRules.ITEM), 7)
	assert_eq(l.amount(1, AmberRules.ITEM), 0, "your partner can't spend yours")
	assert_eq(l.team_amount(AmberRules.ITEM), 0)
	assert_true(l.transfer(0, 1, {AmberRules.ITEM: 2}), "can be handed over like chitin")
	assert_eq(SitePlan.item_name(AmberRules.ITEM), "Hive Amber")
	assert_eq(ExpeditionRules.item_name(AmberRules.ITEM), "Hive Amber")


func test_sites_hold_a_little_amber_nests_and_wrecks_more() -> void:
	var per_kind: Array[int] = [0, 0, 0, 0, 0]
	var sites_with := 0
	var runs := 0
	for kind in 5:
		for s in 60:
			var loot := SitePlan.loot_for(kind, 1000 + s * 17, 6)
			var n := int(SitePlan.totals(loot).get(AmberRules.ITEM, 0))
			assert_true(n <= 5, "a few units a site, never a haul (%d)" % n)
			per_kind[kind] += n
			runs += 1
			if n > 0:
				sites_with += 1
			for l in loot:
				if l.items.has(AmberRules.ITEM):
					assert_eq(l.look, &"amber")
					assert_false(l.walk, "E to take it")
	assert_true(sites_with > runs / 4 and sites_with < runs * 3 / 4, "rare-ish: %d of %d refills" % [sites_with, runs])
	assert_true(per_kind[SitePlan.Kind.NEST] > per_kind[SitePlan.Kind.CAMP], "nests richer than camps")
	assert_true(per_kind[SitePlan.Kind.WRECK] > per_kind[SitePlan.Kind.MOUTH], "wrecks richer than tunnel mouths")


func test_lucky_opens_past_chapter_four_or_wave_eight() -> void:
	assert_false(AmberRules.lucky_open(0, 1))
	assert_false(AmberRules.lucky_open(0, AmberRules.LUCKY_WAVE - 1))
	assert_true(AmberRules.lucky_open(0, AmberRules.LUCKY_WAVE))
	assert_false(AmberRules.lucky_open(4, 30), "story: not in chapter 4")
	assert_true(AmberRules.lucky_open(5, 14), "story: from chapter 5")
	assert_eq(AmberRules.LUCKY_GREETING, "I hear the railroad lost a strongbox. Got anything shiny?")


func test_lucky_stock_is_all_real_and_priced_in_amber() -> void:
	var ids: Array[String] = []
	var kinds := {}
	var dearest_other := 0
	var cheapest_blueprint := 9999
	for s: Dictionary in AmberRules.STOCK:
		var id := str(s["id"])
		assert_false(ids.has(id), "%s listed once" % id)
		ids.append(id)
		assert_true(int(s["price"]) > 0, "%s has a price" % id)
		kinds[str(s["kind"])] = true
		assert_eq(AmberRules.stock_item(id), s)
		match str(s["kind"]):
			"gun":
				assert_true(Defs.weapon(s["gun"]) != null, "%s is a real gun" % id)
				assert_true(AmberRules.has_finish(s["gun"]), "%s has a finish" % id)
			"look":
				var found := false
				for o: Array in DummyLook.SLOTS[str(s["slot"])][1]:
					found = found or o[0] == str(s["option"])
				assert_true(found, "%s is a wardrobe option" % id)
				assert_true(PerkTable.LUCKY_LOOKS.has(PerkTable.cosmetic_key(str(s["slot"]), str(s["option"]))), "%s is Lucky-only" % id)
			"favour":
				assert_true(AmberRules.FAVOURS.has(s["favour"]), "%s is a favour" % id)
			"blueprint":
				assert_true(AmberRules.is_amber(s["turret"]), "%s is an amber turret" % id)
				cheapest_blueprint = mini(cheapest_blueprint, int(s["price"]))
		if str(s["kind"]) != "blueprint":
			dearest_other = maxi(dearest_other, int(s["price"]))
	for k: String in ["gun", "look", "favour", "blueprint"]:
		assert_true(kinds.has(k), "Lucky sells a %s" % k)
	assert_true(cheapest_blueprint > dearest_other * 2, "blueprints are the expensive shelf")
	for id in AmberRules.IDS:
		assert_false(AmberRules.stock_item("blueprint:%s" % id).is_empty(), "Lucky sells %s" % id)


func test_lucky_finish_rides_in_the_weapon_code() -> void:
	# Bit 9: clear of the level (0-1), the mods (2-4), the golden whip (5) and the Dino glass (6-8).
	assert_eq(AmberRules.LUCKY_BIT & (3 | (7 << 2) | WeaponMods.GOLDEN_BIT | DinoGlass.MASK), 0)
	var plain := 1 | (1 << 2) # level 1, first mod
	var lucky := AmberRules.with_lucky(plain)
	assert_true(AmberRules.is_lucky(lucky))
	assert_false(AmberRules.is_lucky(plain))
	assert_eq(WeaponMods.level(lucky), 1, "keeps its level")
	assert_true(WeaponMods.has_mod(lucky, 0), "keeps its mods")
	assert_almost(WeaponMods.mult(&"revolver", lucky, "damage") / WeaponMods.mult(&"revolver", plain, "damage"), 1.4)
	assert_eq(WeaponMods.add(&"revolver", lucky, "mag") - WeaponMods.add(&"revolver", plain, "mag"), 2)
	assert_true(WeaponMods.flag(&"lever_rifle", AmberRules.LUCKY_BIT, "pierce"), "Amberstock pierces")
	assert_false(WeaponMods.flag(&"lever_rifle", 0, "pierce"))
	assert_eq(WeaponMods.add(&"coach_shotgun", AmberRules.LUCKY_BIT, "pellets"), 4)
	assert_eq(AmberRules.finish_name(&"revolver", lucky), "Engraved Peacemaker")
	assert_eq(AmberRules.finish_name(&"revolver", plain), "")
	assert_almost(AmberRules.finish_mult(&"blunderbuss", AmberRules.LUCKY_BIT, "damage"), 1.0, 0.001, "no finish for guns Lucky doesn't sell")


func test_lucky_look_isnt_free_or_in_the_ledger() -> void:
	var p := PerkProfile.new()
	assert_false(p.owns_cosmetic("paint", "amber"), "only Lucky sells it")
	assert_eq(PerkTable.cosmetic_price("paint", "amber"), 0, "never priced in Notches")
	assert_false((PerkTable.COSMETICS.get("paint", {}) as Dictionary).has("amber"), "not in the Rancher's Ledger")
	p.cosmetics.append(PerkTable.cosmetic_key("paint", "amber"))
	assert_true(p.owns_cosmetic("paint", "amber"))
	assert_true(DummyLook.PAINTS.has("amber"))


func test_amber_turrets_are_registered_crafted_items() -> void:
	for id in AmberRules.IDS:
		var d := Defs.turret(id)
		assert_true(d != null, "%s has a def" % id)
		assert_eq(d.id, id)
		assert_true(Defs.is_turret(id))
		assert_true(CraftTable.is_item_turret(id), "%s is placed from an item" % id)
		assert_false(CraftTable.is_craft(id), "not a mount/barrel/load design")
		assert_false(Defs.TURRETS.has(id), "not in the scrap build tabs")
		assert_false(Defs.BUILD_ORDER.has(id))
		assert_false(Defs.gets_scaffold(id), "%s stands on bare ground" % id)
		assert_eq(d.cost_scrap, 0, "costs its item, not scrap")
		assert_eq(d.tier, 2, "%s is Late tier" % id)
		assert_true(d.role != "" and d.weakness != "", "%s has a job and a weakness" % id)
		assert_true(AmberBuilder.has(id), "%s has a model" % id)
		# The thirty-degree law: no amber turret looks further down.
		assert_true(d.pitch_limit_deg <= 30.0, "%s obeys the thirty-degree law (%.0f)" % [id, d.pitch_limit_deg])
		assert_false(d.guards_plateau or d.guards_house or d.anti_air, "%s guards the partner's wall" % id)
		assert_true(AmberRules.BLUEPRINTS.has(id) and AmberRules.FOUND_IN.has(id))
	assert_eq(Defs.turret(AmberRules.KILN).special, TurretDef.SPECIAL_KILN)
	assert_eq(Defs.turret(AmberRules.BELL).special, TurretDef.SPECIAL_BELL)
	assert_eq(Defs.turret(AmberRules.LANCE).special, TurretDef.SPECIAL_LANCE)
	assert_true(Defs.turret(AmberRules.LANCE).stat_line().begins_with("Beam 120 Damage/s"))
	assert_true(Defs.turret(AmberRules.KILN).stat_line().contains("Entombs"))
	assert_true(Defs.turret(AmberRules.BELL).stat_line().contains("Tolls Every 9 s"))


func test_recipes_need_amber_and_one_of_each_part() -> void:
	for id in AmberRules.IDS:
		var r := AmberRules.recipe(id)
		assert_true(AmberRules.amber_cost(id) >= 10, "%s costs real amber" % id)
		var mounts := 0
		var barrels := 0
		var loads := 0
		for k: StringName in r:
			if k == AmberRules.ITEM:
				continue
			assert_true(CraftTable.part_keys().has(k), "%s needs a real part %s" % [id, k])
			var bare := StringName(String(k).substr(CraftTable.PART_PREFIX.length()))
			mounts += 1 if CraftTable.MOUNTS.has(bare) else 0
			barrels += 1 if CraftTable.BARRELS.has(bare) else 0
			loads += 1 if CraftTable.LOADS.has(bare) else 0
		assert_eq([mounts, barrels, loads], [1, 1, 1], "%s: a mount, a barrel and a load" % id)
	r_is_copy()


func r_is_copy() -> void:
	var r := AmberRules.recipe(AmberRules.KILN)
	r[AmberRules.ITEM] = 0
	assert_eq(AmberRules.amber_cost(AmberRules.KILN), 10, "recipe() hands out a copy")


func test_one_of_each_per_team() -> void:
	assert_true(AmberRules.can_craft_another(0, 0))
	assert_false(AmberRules.can_craft_another(1, 0), "one standing")
	assert_false(AmberRules.can_craft_another(0, 1), "one waiting in a stockpile")
	assert_true(AmberRules.can_place(0))
	assert_false(AmberRules.can_place(1))
	assert_true(AmberRules.limit_text(AmberRules.BELL).contains("only one Queen's Bell"))


func test_amber_turrets_outgun_the_rest() -> void:
	var best_dps := 0.0
	var best_splash := 0.0
	for id: StringName in Defs.TURRETS:
		var t := Defs.turret(id)
		if t.crewed or t.guards_plateau:
			continue # crewed guns are aimed by hand (and halve unmanned); last resorts never shoot the wall
		var dps := t.damage / t.fire_interval
		if t.burst > 0: # (a burst gun pauses between bursts)
			dps = t.damage * t.burst / (t.fire_interval * t.burst + t.burst_pause)
		best_dps = maxf(best_dps, dps)
		if t.effect == TurretDef.Effect.SPLASH and id != &"siege_mortar": # (the Siege Mortar is the one-load-a-wave exception)
			best_splash = maxf(best_splash, t.damage)
	var lance := Defs.turret(AmberRules.LANCE)
	assert_true(lance.damage > best_dps * 1.5, "the lance's beam (%.0f/s) beats any turret's %.0f/s" % [lance.damage, best_dps])
	var kiln := Defs.turret(AmberRules.KILN)
	assert_true(kiln.damage > best_splash and kiln.effect_size >= 4.0, "the kiln outhits every splash gun")
	assert_true(kiln.max_hp > 300.0 and lance.max_hp > 300.0 and Defs.turret(AmberRules.BELL).max_hp > 300.0, "built to last")


func test_entomb_rule() -> void:
	assert_true(AmberRules.should_entomb(false, true, 0.3))
	assert_false(AmberRules.should_entomb(false, true, 0.6), "healthy bugs aren't caught")
	assert_false(AmberRules.should_entomb(true, true, 0.1), "bosses never")
	assert_false(AmberRules.should_entomb(false, false, 0.1), "the dead never")
	var loot := AmberRules.shatter_loot(1.0)
	assert_true(int(loot[&"scrap"]) > AmberRules.SHATTER_CHITIN and not loot.has(&"chitin"), "a small loot burst, all to the team pot")
	assert_true(int(AmberRules.shatter_loot(3.0)[&"scrap"]) > int(loot[&"scrap"]), "bigger bugs, bigger burst")
	assert_true(AmberRules.STATUE_TIME >= 15.0 and AmberRules.STATUE_TIME <= 40.0)


func test_statues_block_the_crowd() -> void:
	var pos := PackedVector2Array([Vector2(0, 10), Vector2(0.3, 9.5)])
	var rad := PackedFloat32Array([0.8, 0.5])
	var wt := PackedFloat32Array([BugCrowd.STATUE_WEIGHT, BugCrowd.weight(3.0)])
	var r := BugCrowd.resolve_packed(pos, rad, wt)
	var push: PackedVector2Array = r["push"]
	var blocked: PackedByteArray = r["blocked"]
	assert_eq(push[0], Vector2.ZERO, "nothing shoves a statue")
	assert_true((pos[1] + push[1]).distance_to(pos[0]) >= 1.3 - 0.001, "even a beetle is put right back outside it")
	assert_eq(blocked[1], 1, "and knows it was blocked")
	assert_eq(blocked[0], 0)
	assert_almost((r["crouch"] as PackedFloat32Array)[1], 0.0, 0.001, "no crawling under a statue")
	assert_almost((r["ride"] as PackedFloat32Array)[0], 0.0, 0.001)
	# Two statues side by side stay put.
	var two := BugCrowd.resolve_packed(PackedVector2Array([Vector2.ZERO, Vector2(0.5, 0)]), PackedFloat32Array([0.6, 0.6]),
			PackedFloat32Array([BugCrowd.STATUE_WEIGHT, BugCrowd.STATUE_WEIGHT]))
	assert_eq((two["push"] as PackedVector2Array)[0], Vector2.ZERO)
	assert_eq((two["push"] as PackedVector2Array)[1], Vector2.ZERO)


func test_bell_frenzy_and_drop() -> void:
	var others: Array[Vector2] = [Vector2(4.0, 0.0), Vector2(1.0, 1.0), Vector2(30.0, 0.0)]
	assert_eq(AmberRules.frenzy_target(Vector2.ZERO, others), 1, "goes for the nearest")
	var far: Array[Vector2] = [Vector2(20.0, 0.0)]
	assert_eq(AmberRules.frenzy_target(Vector2.ZERO, far), -1, "nobody in reach")
	assert_true(AmberRules.frenzy_dps(8.0, 1.0) >= AmberRules.FRENZY_MIN_DPS)
	assert_true(AmberRules.frenzy_dps(20.0, 3.0) > AmberRules.frenzy_dps(8.0, 1.0), "big biters bite harder")
	assert_eq(AmberRules.FRENZY_TIME, 6.0)
	assert_eq(AmberRules.BOSS_STUN, 2.0)
	assert_true(AmberRules.drop_damage(35.0) >= 35.0, "a dragonfly bandit doesn't survive the fall")
	assert_true(AmberRules.drop_damage(400.0) < 400.0, "something big lands stunned")
	var bell := Defs.turret(AmberRules.BELL)
	assert_true(bell.fire_interval >= 8.0 and bell.fire_interval <= 10.0, "tolls every 8-10 s")
	var s := BugStatus.new(null)
	s.frenzy(6.0)
	assert_true(s.is_frenzied())
	s.tick(6.1)
	assert_false(s.is_frenzied(), "wears off")


func test_lance_overheats_after_eight_seconds_and_vents_ten() -> void:
	var heat := 0.0
	var venting := false
	var t := 0.0
	while not venting and t < 20.0:
		var h := AmberRules.lance_heat(heat, venting, true, 0.1)
		heat = h[0]
		venting = h[1]
		t += 0.1
	assert_almost(t, AmberRules.LANCE_HOT, 0.15, "overheats after 8 s of fire")
	var vent := 0.0
	while venting and vent < 30.0:
		var h := AmberRules.lance_heat(heat, venting, true, 0.1)
		heat = h[0]
		venting = h[1]
		vent += 0.1
	assert_almost(vent, AmberRules.LANCE_VENT, 0.15, "vents for 10 s, even with a target")
	assert_almost(heat, 0.0, 0.001, "comes back cold")
	var cooled := AmberRules.lance_heat(5.0, false, false, 1.0)
	assert_almost(float(cooled[0]), 4.0, 0.001, "idle, it cools")
	assert_almost(AmberRules.seg_dist(Vector3(0, 1, 5), Vector3.ZERO, Vector3(0, 0, 10)), 1.0)
	assert_almost(AmberRules.seg_dist(Vector3(0, 0, 12), Vector3.ZERO, Vector3(0, 0, 10)), 2.0, 0.001, "past the end")


func test_amber_blueprints_save_with_story_progress() -> void:
	var p := StoryProgress.new()
	var ch := StoryChapter.from_dict({"id": "ch7", "number": 7, "title": "T", "map": "canyon", "first_wave": 19, "last_wave": 19,
		"rewards": {"notches": 10, "unlock": {"kind": "amber_blueprint", "id": "amber_kiln", "name": "Blueprint: Amber Kiln"}}})
	p.win(ch)
	assert_true(p.amber_blueprints.has("amber_kiln"), "a chapter can hand out an amber blueprint")
	p.amber_blueprints.append("queens_bell")
	var q := StoryProgress.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(q.amber_blueprints, ["amber_kiln", "queens_bell"] as Array[String], "kept when saved")
	var old := StoryProgress.from_dict({"done": {}})
	assert_true(old.amber_blueprints.is_empty(), "older saves load with none")


func test_field_guide_covers_amber() -> void:
	var guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/field_guide.json"))
	for id in AmberRules.IDS:
		assert_true((guide["turrets"] as Dictionary).has(String(id)), "guide entry for %s" % id)
	assert_true((guide["sites"] as Dictionary).has("amber"), "guide entry for hive amber")
	assert_true((guide["basics"] as Dictionary).has("lucky_moreau"), "guide entry for Lucky")
