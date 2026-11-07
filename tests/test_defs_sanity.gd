extends TestCase
## Data sanity: every def's id matches its registry key and its numbers are usable.


func test_ids_match_keys() -> void:
	for reg: Dictionary in [Defs.BUGS, Defs.TURRETS, Defs.STRUCTURES, Defs.CROPS]:
		for key: StringName in reg.keys():
			var d: Resource = reg[key]
			assert_true(d != null, "%s loads" % key)
			if d != null:
				assert_eq(StringName(d.get("id")), key, "id of %s" % key)


func test_turret_numbers() -> void:
	for id: StringName in Defs.TURRETS.keys():
		var t := Defs.turret(id)
		assert_true(t.cost_scrap > 0, "%s cost" % id)
		assert_true(t.max_hp > 0.0, "%s hp" % id)
		assert_true(t.range > 0.0, "%s range" % id)
		assert_true(t.fire_interval > 0.0, "%s fire interval" % id)
		assert_true(t.damage >= 0.0, "%s damage" % id)
		assert_true(t.hit_chance > 0.0 and t.hit_chance <= 1.0, "%s hit chance %.2f" % [id, t.hit_chance])
		assert_false(t.display_name.is_empty(), "%s name" % id)


func test_structure_numbers() -> void:
	for id: StringName in Defs.STRUCTURES.keys():
		var s := Defs.structure(id)
		assert_true(s.cost_scrap >= 0, "%s cost" % id)
		assert_true(s.max_hp > 0.0, "%s hp" % id)
		assert_false(s.display_name.is_empty(), "%s name" % id)


func test_bug_numbers() -> void:
	for id: StringName in Defs.BUGS.keys():
		var b := Defs.bug(id)
		assert_true(b.group_size >= 1, "%s group size" % id)
		assert_true(b.cost >= 0, "%s cost" % id)
		assert_true(b.first_wave >= 1, "%s first wave" % id)


func test_crop_numbers() -> void:
	for id: StringName in Defs.CROPS.keys():
		var c: CropDef = Defs.CROPS[id]
		assert_true(c.grow_time > 0.0, "%s grow time" % id)
		assert_false(c.harvest_out().is_empty(), "%s harvests something" % id)
		assert_true(c.loads_per_harvest > 0 and c.load_item != &"", "%s gives turret loads" % id)


func test_every_bug_wave_is_reachable() -> void:
	# A bug that unlocks after the last wave never shows up (spiderlings hatch, so they're exempt).
	var last := Defs.WAVE_CONFIG.last_wave
	for id: StringName in Defs.active_bug_ids():
		var b := Defs.bug(id)
		if b.cost > 0:
			assert_true(b.first_wave <= last, "%s first_wave %d > last wave %d" % [id, b.first_wave, last])


func test_upgrade_costs_increase() -> void:
	for i in range(1, Defs.UPGRADE_COSTS.size()):
		assert_true(Defs.UPGRADE_COSTS[i] > Defs.UPGRADE_COSTS[i - 1])
