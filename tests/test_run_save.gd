extends TestCase
## The saved run (Continue last run) as pure data: encode -> decode keeps every
## field, and a file with missing or odd fields still loads with sane defaults.


func _sample() -> Dictionary:
	return {
		"wave": 7, "phase": 1, "endless": false, "weather": 2, "cpu_quality": 1, "saved_at": 1700000000,
		"homesteads": [
			{"hp": 320.5, "max": 750.0, "floors": 2, "boarded": true, "reinforced": true, "tower": false},
			{"hp": 500.0, "max": 500.0, "floors": 3, "boarded": false, "reinforced": false, "tower": true},
		],
		"builds": [
			{"type": &"scaffold", "cliff": 0, "row": 0, "col": 3, "level": 0, "owner": "", "levels": 2},
			{"type": &"gatling_post", "cliff": 0, "row": 0, "col": 3, "level": 2, "owner": "Ada", "tier": 1,
					"hp": 140.0, "perk": [1.1, 0.9, 1.2]},
			{"type": &"bear_trap", "cliff": 1, "row": 4, "col": 8, "level": 0, "owner": "Bo", "hp": 60.0, "armed": false},
			{"type": &"farm_plot", "cliff": 1, "row": 6, "col": 2, "level": 0, "owner": "",
					"crop": {"id": &"corn", "stage": 2, "progress": 31.5, "watered": true}},
			{"type": &"rain_catcher", "cliff": 0, "row": 5, "col": 5, "level": 0, "owner": "", "stored": 6},
		],
		"wells": [{"path": "Dressing/Well0", "stored": 4, "working": true}],
		"economy": {"stock": {0: {&"scrap": 240, &"chitin": 12, &"seed_corn": 2}, 1: {&"scrap": 15, &"water": 3}},
				"shared": true, "gained": {&"scrap": 900}, "cpu_spent": {"Dusty": {&"scrap": 120}}, "cpu_share": 0.5},
		"players": {0: {"food": 0.4, "water": 0.25}, 1: {"food": 1.0, "water": 0.9}},
		"perks": {0: {"loadout": {"scrap_stash": 2, "barn_raising": 1}, "free_used": true}, 1: {"loadout": {}, "free_used": false}},
		"guns": {0: {&"revolver": 0, &"lever_rifle": 3}},
	}


func test_round_trip_keeps_everything() -> void:
	var back := RunSave.decode(RunSave.encode(_sample()))
	assert_false(back.is_empty(), "decoded")
	assert_eq(back["version"], RunSave.VERSION)
	assert_eq(back["wave"], 7)
	assert_eq(back["weather"], 2)
	assert_eq(back["cpu_quality"], 1)
	var h: Dictionary = back["homesteads"][0]
	assert_almost(float(h["hp"]), 320.5)
	assert_almost(float(h["max"]), 750.0)
	assert_eq(h["floors"], 2)
	assert_true(bool(h["boarded"]) and bool(h["reinforced"]) and not bool(h["tower"]))
	assert_true(bool(back["homesteads"][1]["tower"]))
	var builds: Array = back["builds"]
	assert_eq(builds.size(), 5)
	assert_eq(builds[0]["type"], &"scaffold")
	assert_eq(builds[0]["levels"], 2)
	var g: Dictionary = builds[1]
	assert_eq(g["type"], &"gatling_post")
	assert_eq(g["level"], 2)
	assert_eq(g["tier"], 1)
	assert_eq(g["owner"], "Ada")
	assert_almost(float(g["hp"]), 140.0)
	assert_almost(float(g["perk"][2]), 1.2)
	assert_false(bool(builds[2]["armed"]))
	var crop: Dictionary = builds[3]["crop"]
	assert_eq(crop["id"], &"corn")
	assert_eq(crop["stage"], 2)
	assert_almost(float(crop["progress"]), 31.5)
	assert_true(bool(crop["watered"]))
	assert_eq(builds[4]["stored"], 6)
	assert_eq(back["wells"][0]["path"], "Dressing/Well0")
	var eco: Dictionary = back["economy"]
	assert_eq(eco["stock"][0][&"scrap"], 240)
	assert_eq(eco["stock"][0][&"seed_corn"], 2)
	assert_eq(eco["stock"][1][&"water"], 3)
	assert_true(bool(eco["shared"]))
	assert_eq(eco["gained"][&"scrap"], 900)
	assert_eq(eco["cpu_spent"]["Dusty"][&"scrap"], 120)
	assert_almost(float(eco["cpu_share"]), 0.5)
	assert_almost(float(back["players"][0]["water"]), 0.25)
	assert_almost(float(back["players"][1]["food"]), 1.0)
	assert_eq(back["perks"][0]["loadout"][&"scrap_stash"], 2)
	assert_true(bool(back["perks"][0]["free_used"]))
	assert_false(bool(back["perks"][1]["free_used"]))
	assert_eq(back["guns"][0][&"lever_rifle"], 3)


func test_resources_come_back_as_stringnames_and_ints() -> void:
	var back := RunSave.decode(RunSave.encode(_sample()))
	var s: Dictionary = back["economy"]["stock"][0]
	for k: Variant in s:
		assert_true(k is StringName, "resource keys are StringNames")
		assert_true(s[k] is int, "amounts are ints")


func test_missing_fields_get_defaults() -> void:
	var back := RunSave.decode('{"wave": 3}')
	assert_eq(back["wave"], 3)
	assert_eq(back["cpu_quality"], -1)
	assert_false(bool(back["endless"]))
	assert_eq((back["homesteads"] as Array).size(), 2)
	assert_eq(back["homesteads"][0]["floors"], 1)
	assert_eq((back["builds"] as Array).size(), 0)
	assert_eq((back["economy"]["stock"] as Dictionary).size(), 2)
	assert_false(bool(back["economy"]["shared"]))
	assert_eq((back["players"] as Dictionary).size(), 0)


func test_bad_entries_are_skipped_not_fatal() -> void:
	var text := '{"wave": "x", "builds": [5, {"cliff": 1}, {"type": "palisade", "cliff": 9, "level": -2}], "homesteads": "nope", "players": {"0": 3, "1": {"food": 7}}}'
	var back := RunSave.decode(text)
	assert_eq(back["wave"], 1, "a bad wave falls back to 1")
	var builds: Array = back["builds"]
	assert_eq(builds.size(), 1, "entries without a type are dropped")
	assert_eq(builds[0]["cliff"], 1, "cliff clamped")
	assert_eq(builds[0]["level"], 0, "level clamped")
	assert_almost(float(back["players"][1]["food"]), 1.0, 0.001, "clamped to 0..1")
	assert_false((back["players"] as Dictionary).has(0))


func test_not_a_run_decodes_empty() -> void:
	assert_true(RunSave.decode("").is_empty())
	assert_true(RunSave.decode("[1, 2]").is_empty())
	assert_true(RunSave.decode("{broken").is_empty())


func test_stock_fits_shared_and_separate_pools() -> void:
	var stock := {0: {&"scrap": 101, &"water": 4}, 1: {&"scrap": 0, &"water": 0}}
	var split := RunSave.fit_stock(stock, true, false)
	assert_eq(split[0][&"scrap"], 51)
	assert_eq(split[1][&"scrap"], 50)
	assert_eq(split[1][&"water"], 2)
	var merged := RunSave.fit_stock({0: {&"scrap": 10}, 1: {&"scrap": 5, &"chitin": 3}}, false, true)
	assert_eq(merged[0][&"scrap"], 15)
	assert_eq(merged[0][&"chitin"], 3)
	assert_eq(merged[1][&"scrap"], 0)
	var same := RunSave.fit_stock(stock, true, true)
	assert_eq(same[0][&"scrap"], 101)


func test_bosses_seen_round_trip_and_defaults() -> void:
	var d := _sample()
	d["bosses_seen"] = [&"queen_spider", &"locust_lord"]
	var back := RunSave.decode(RunSave.encode(d))
	assert_eq(back["bosses_seen"], [&"queen_spider", &"locust_lord"], "oldest first, as StringNames")
	assert_true(back["bosses_seen"][0] is StringName)
	assert_eq(RunSave.decode(RunSave.encode(_sample()))["bosses_seen"], [], "an older save has met no bosses")
	assert_eq(RunSave.normalize({"bosses_seen": [3, "", "hive_wagon", null]})["bosses_seen"], [&"hive_wagon"], "junk entries skipped")
	assert_eq(RunSave.normalize({"bosses_seen": "nope"})["bosses_seen"], [])
