extends TestCase
## Tiers: Early / Mid / Late turrets, their wave unlocks, the build menu order,
## the CPU's picks, and the new turrets' ricochet, pierce and rail-spike maths.

const KillMethod := preload("res://scenes/bugs/kill_method.gd")
## (The Hornet's Nest, Elephant Battery and Rail Spike Driver are archived with
## the other crop-specific turrets: D:/DustAndMandibles-archive/retired/turrets.)
const NEW: Array[StringName] = [&"twin_gatling", &"gatling_porch"]


func test_unlock_waves_live_in_one_place() -> void:
	assert_eq(TurretDef.UNLOCK_WAVES, [1, 5, 10] as Array[int])
	assert_eq(TurretDef.ERA_NAMES.size(), TurretDef.UNLOCK_WAVES.size())
	for id: StringName in Defs.TURRETS:
		var d := Defs.turret(id)
		assert_true(d.tier >= 0 and d.tier <= 2, "%s tier in range" % id)
		assert_eq(Defs.unlock_wave(id), TurretDef.UNLOCK_WAVES[d.tier], "%s unlock wave" % id)


func test_tier_chart() -> void:
	var chart := {
		0: [&"gatling_post", &"buffalo_rifle", &"duck_gun", &"sky_sweeper", &"scattergun_post", &"porch_repeater", &"cf_crop_hopper"],
		1: [&"twin_gatling", &"powder_flak", &"sharpshooter_tower", &"repeater_post", &"buck_blaster", &"skeet_post", &"big_fifty",
				&"cf_iron_mule"],
		2: [&"gatling_porch", &"brass_gatling", &"long_tom_rifle", &"grapeshot_turret", &"flak_porch"],
	}
	for t: int in chart:
		for id: StringName in chart[t]:
			assert_eq(Defs.tier_of(id), t, "%s is %s" % [id, TurretDef.ERA_NAMES[t]])


func test_mid_unlocks_at_wave_five_late_at_ten() -> void:
	for w in [1, 4]:
		assert_true(Defs.is_unlocked(&"gatling_post", w), "early from the start")
		assert_false(Defs.is_unlocked(&"twin_gatling", w), "mid locked on wave %d" % w)
	assert_true(Defs.is_unlocked(&"twin_gatling", 5))
	assert_false(Defs.is_unlocked(&"brass_gatling", 9))
	assert_true(Defs.is_unlocked(&"brass_gatling", 10))
	assert_true(Defs.is_unlocked(&"farm_plot", 0), "structures are never locked")
	assert_true(Defs.is_unlocked(&"scaffold", 1))
	assert_eq(Defs.lock_reason(&"big_fifty", 2), "Unlocks at Wave 5")
	assert_eq(Defs.lock_reason(&"long_tom_rifle", 6), "Unlocks at Wave 10")
	assert_eq(Defs.lock_reason(&"long_tom_rifle", 10), "")


func test_crafted_turrets_are_never_locked() -> void:
	var designs := CraftTable.all_designs()
	if designs.is_empty():
		return
	assert_eq(Defs.tier_of(designs[0]), 0)
	assert_true(Defs.is_unlocked(designs[0], 1))


func test_categories_sort_by_tier_and_keep_everything() -> void:
	for cat: Dictionary in Defs.BUILD_CATEGORIES:
		var items: Array = cat["items"]
		var sorted := Defs.by_tier(items)
		assert_eq(sorted.size(), items.size(), "%s keeps every item" % cat["name"])
		for i in range(1, sorted.size()):
			assert_true(Defs.tier_of(sorted[i - 1]) <= Defs.tier_of(sorted[i]), "%s sorted by tier" % cat["name"])
	var cliff := Defs.by_tier(Defs.category_items("Cliff Turrets"))
	assert_eq(cliff[0], &"gatling_post", "Early first, in listed order")
	assert_true(cliff.find(&"twin_gatling") < cliff.find(&"brass_gatling"), "Mid before Late")


func test_new_turrets_are_registered() -> void:
	var guide: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/field_guide.json")) as Dictionary)["turrets"]
	for id in NEW:
		assert_true(Defs.TURRETS.has(id), "%s registered" % id)
		assert_true(Defs.BUILD_ORDER.has(id), "%s in BUILD_ORDER" % id)
		var listed := false
		for cat: Dictionary in Defs.BUILD_CATEGORIES:
			listed = listed or (cat["items"] as Array).has(id)
		assert_true(listed, "%s in a build tab" % id)
		assert_true(Defs.turret(id).tier > 0, "%s is Mid or Late" % id)
		assert_true(TierBuilder.has(id), "%s has its own model" % id)
		assert_true(guide.has(String(id)) and str(guide[String(id)].get("lore", "")) != "", "%s has a field guide entry" % id)
		assert_eq(KillMethod.classify("Logan's " + Defs.turret(id).display_name), KillMethod.BULLET, "%s kills count as bullets" % id)
	assert_true(Defs.is_house_turret(&"gatling_porch"), "the porch Gatling mounts on the house")
	assert_true(Defs.turret(&"gatling_porch").yard_wide)
	assert_false(Defs.gets_scaffold(&"gatling_porch"))


func test_new_models_build_in_parts() -> void:
	for id in NEW:
		var p := TurretBuilder.build(id, Color.RED)
		for k: String in ["base", "head", "gun", "muzzle", "head_y", "gun_y"]:
			assert_true(p.has(k), "%s model has %s" % [id, k])
		assert_true((p["gun"] as ArrayMesh).get_surface_count() > 0, "%s gun has geometry" % id)
		assert_true((p["muzzle"] as Vector3).z < -0.5, "%s muzzle out front" % id)
	var twin := TurretBuilder.build(&"twin_gatling", Color.RED)
	assert_true(twin.has("spin"), "the barrels spin") # (the fal model: one cluster of four barrels)
	assert_true(TierBuilder.loose_spike().get_surface_count() > 0)


func test_twin_gatling_doubles_the_rate() -> void:
	var g := Defs.turret(&"gatling_post")
	var t := Defs.turret(&"twin_gatling")
	assert_almost(t.fire_interval, g.fire_interval * 0.5, 0.001)
	assert_eq(t.heavy_mult, 0.5, "still weak against heavy")
	assert_eq(t.cost_scrap, 85) # (balance pass: was 110)


func test_new_turret_numbers_and_stat_lines() -> void:
	assert_eq(Defs.cost_of(&"gatling_porch"), 180)
	assert_true(Defs.turret(&"gatling_porch").stat_line().contains("Whole Yard"))


func test_cpu_moves_on_to_new_tiers_once_unlocked() -> void:
	var ids: Array = [&"gatling_post", &"twin_gatling", &"brass_gatling", &"buffalo_rifle"]
	assert_eq(TierRules.best_first(ids, 1), [&"gatling_post", &"buffalo_rifle"], "only Early before wave 5")
	assert_eq(TierRules.best_first(ids, 5), [&"twin_gatling", &"gatling_post", &"buffalo_rifle"], "Mid first from wave 5")
	assert_eq(TierRules.best_first(ids, 10), [&"brass_gatling", &"twin_gatling", &"gatling_post", &"buffalo_rifle"], "Late first from wave 10")


func test_ricochet_hops_to_close_bugs_only() -> void:
	var pts := PackedVector3Array([Vector3(2, 0, 0), Vector3(4.5, 0, 0), Vector3(20, 0, 0), Vector3(1, 0, 0)])
	# From the origin: nearest first (1 m), then 2 m on, then 4.5 m (2.5 away); never 20 m.
	assert_eq(TierRules.chain_path(Vector3.ZERO, pts, 2, 3.0), [3, 0] as Array[int])
	assert_eq(TierRules.chain_path(Vector3.ZERO, pts, 5, 3.0), [3, 0, 1] as Array[int], "hops stop when nothing is close")
	assert_eq(TierRules.chain_path(Vector3(50, 0, 0), pts, 2, 3.0), [] as Array[int], "a lone bug: no bounce")


func test_pierce_carries_on_through_bugs_in_line() -> void:
	var from := Vector3.ZERO
	var aim := Vector3(0, 0, -20)
	var pts := PackedVector3Array([Vector3(0, 0, -24), Vector3(0.5, 0, -22), Vector3(4, 0, -22), Vector3(0, 0, -40), Vector3(0, 0, -26)])
	assert_eq(TierRules.pierce_line(from, aim, pts, 2, 1.5), [1, 0] as Array[int], "the two nearest in line")
	assert_eq(TierRules.pierce_line(from, aim, pts, 5, 1.5), [1, 0, 4] as Array[int], "none off the line or 10 m past the target")


func test_rail_spike_skewers_a_line_down_the_wall() -> void:
	# A wall facing +X: climbers in a column below the target, one off to the side, one above.
	var n := Vector3.RIGHT
	var aim := Vector3(0, 20, 0)
	var shot := Vector3(-1, -0.5, 0).normalized() # shooting across and down at the wall
	assert_true(TierRules.spike_run(shot, n).is_equal_approx(Vector3.DOWN), "runs straight down the wall")
	var pts := PackedVector3Array([Vector3(0, 14, 0.5), Vector3(0, 17, -0.3), Vector3(0, 15, 6.0), Vector3(0, 24, 0), Vector3(0.3, 2, 0)])
	assert_eq(TierRules.spike_line(aim, shot, n, pts, 1.6), [1, 0, 4] as Array[int], "every bug under it, nearest first")
	# A shot that hits the wall head on still runs downward; one rising bends down.
	assert_true(TierRules.spike_run(-n, n).is_equal_approx(Vector3.DOWN))
	assert_true(TierRules.spike_run(Vector3(-1, 0.4, 1).normalized(), n).y < 0.0)


func test_tier_up_chains_go_up_one_tier_in_the_same_family() -> void:
	for id: StringName in Defs.TIER_UP:
		var next := Defs.tier_up_of(id)
		assert_true(next != &"", "%s steps up to a real turret" % id)
		assert_eq(Defs.tier_of(next), Defs.tier_of(id) + 1, "%s -> %s is one tier up" % [id, next])
		assert_false(Defs.is_crewed(next), "%s steps up to a 1x1 turret" % id)


## Logan: a turret never changes kind when it steps up. Cliff stays cliff, a
## last resort stays a last resort, anti-air stays anti-air, house stays house.
func test_tier_up_never_changes_the_turret_kind() -> void:
	for id: StringName in Defs.TIER_UP:
		var next := Defs.tier_up_of(id)
		assert_eq(Defs.kind_of(next), Defs.kind_of(id), "%s -> %s keeps its kind" % [id, next])
		var a := Defs.turret(id)
		var b := Defs.turret(next)
		assert_eq(b.guards_plateau, a.guards_plateau, "%s -> %s plateau guard" % [id, next])
		assert_eq(b.guards_house, a.guards_house, "%s -> %s house gun" % [id, next])
		assert_eq(b.anti_air, a.anti_air, "%s -> %s anti-air" % [id, next])
	assert_eq(Defs.kind_of(&"buffalo_rifle"), &"cliff")
	assert_eq(Defs.kind_of(&"sharpshooter_tower"), &"last_resort")
	assert_eq(Defs.kind_of(&"duck_gun"), &"air")
	assert_eq(Defs.kind_of(&"rooftop_cannon"), &"house")
	assert_eq(Defs.tier_up_of(&"buffalo_rifle"), &"big_fifty")
	assert_eq(Defs.tier_up_of(&"big_fifty"), &"long_tom_rifle")
	# The turrets the lines used to cross into still stand on their own.
	for id: StringName in [&"sharpshooter_tower"]:
		assert_true(Defs.TURRETS.has(id) and Defs.BUILD_ORDER.has(id), "%s still buildable" % id)
		assert_false(Defs.TIER_UP.values().has(id), "nothing steps up into %s" % id)


## The turret that closes the Buffalo line: registered, modelled, in the guide.
## (The Brimstone Bellows and Cotton Bale Cannon are archived.)
func test_line_turrets_are_complete() -> void:
	var guide: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/field_guide.json")) as Dictionary)["turrets"]
	for id: StringName in [&"big_fifty"]:
		assert_true(Defs.BUILD_ORDER.has(id), "%s in BUILD_ORDER" % id)
		var listed := false
		for cat: Dictionary in Defs.BUILD_CATEGORIES:
			listed = listed or (cat["items"] as Array).has(id)
		assert_true(listed, "%s in a build tab" % id)
		assert_true(TierBuilder.has(id), "%s has its own model" % id)
		assert_true(guide.has(String(id)) and str(guide[String(id)].get("lore", "")) != "", "%s has a field guide entry" % id)
		var p := TurretBuilder.build(id, Color.RED)
		for k: String in ["base", "head", "gun", "muzzle", "head_y", "gun_y"]:
			assert_true(p.has(k), "%s model has %s" % [id, k])
		assert_true((p["gun"] as ArrayMesh).get_surface_count() > 0, "%s gun has geometry" % id)
	assert_eq(KillMethod.classify("Logan's Big Fifty"), KillMethod.BULLET)
	# Each step is a real step: more damage per second than the turret before it.
	var dps := func(id: StringName) -> float:
		var d := Defs.turret(id)
		return d.damage * d.hit_chance / d.fire_interval
	assert_true(dps.call(&"big_fifty") > dps.call(&"buffalo_rifle") and dps.call(&"big_fifty") < dps.call(&"long_tom_rifle"))


func test_tier_up_is_a_bit_cheaper_than_building_new() -> void:
	assert_eq(Defs.tier_up_of(&"gatling_post"), &"repeater_post")
	assert_eq(Defs.tier_up_of(&"repeater_post"), &"brass_gatling")
	assert_eq(Defs.tier_up_of(&"brass_gatling"), &"")
	assert_eq(Defs.tier_up_of(&"cf_crop_hopper"), &"", "universal turrets go up by tiers instead")
	# Turret ammo: a line never crosses between self-powered and crop-fed.
	for id: StringName in Defs.TIER_UP:
		assert_eq(Defs.turret(id).crop_type, Defs.turret(Defs.TIER_UP[id]).crop_type, "%s stays on its track" % id)
	for id: StringName in Defs.TIER_UP:
		var c := Defs.tier_up_cost(id)
		var full := Defs.cost_of(Defs.tier_up_of(id))
		assert_true(c < full and c >= full * 0.8, "%s step-up %d vs %d new" % [id, c, full])
