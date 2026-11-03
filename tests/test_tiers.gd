extends TestCase
## Tiers: Early / Mid / Late turrets, their wave unlocks, the build menu order,
## the CPU's picks, and the new turrets' ricochet, pierce and rail-spike maths.

const KillMethod := preload("res://scenes/bugs/kill_method.gd")
const NEW: Array[StringName] = [&"twin_gatling", &"hornets_nest", &"elephant_battery", &"rail_spike_driver", &"gatling_porch"]


func test_unlock_waves_live_in_one_place() -> void:
	assert_eq(TurretDef.UNLOCK_WAVES, [1, 5, 10] as Array[int])
	assert_eq(TurretDef.ERA_NAMES.size(), TurretDef.UNLOCK_WAVES.size())
	for id: StringName in Defs.TURRETS:
		var d := Defs.turret(id)
		assert_true(d.tier >= 0 and d.tier <= 2, "%s tier in range" % id)
		assert_eq(Defs.unlock_wave(id), TurretDef.UNLOCK_WAVES[d.tier], "%s unlock wave" % id)


func test_tier_chart() -> void:
	var chart := {
		0: [&"gatling_post", &"buffalo_rifle", &"water_cannon", &"chili_mortar", &"dynamite_lobber", &"lasso_harpoon",
				&"duck_gun", &"sky_sweeper", &"scattergun_post"],
		1: [&"twin_gatling", &"elephant_battery", &"powder_flak", &"net_thrower", &"porch_repeater", &"sharpshooter_tower"],
		2: [&"hornets_nest", &"rail_spike_driver", &"thunder_mule", &"whaler", &"firework_battery", &"sky_hound", &"gatling_porch"],
	}
	for t: int in chart:
		for id: StringName in chart[t]:
			assert_eq(Defs.tier_of(id), t, "%s is %s" % [id, TurretDef.ERA_NAMES[t]])


func test_mid_unlocks_at_wave_five_late_at_ten() -> void:
	for w in [1, 4]:
		assert_true(Defs.is_unlocked(&"gatling_post", w), "early from the start")
		assert_false(Defs.is_unlocked(&"twin_gatling", w), "mid locked on wave %d" % w)
	assert_true(Defs.is_unlocked(&"twin_gatling", 5))
	assert_false(Defs.is_unlocked(&"hornets_nest", 9))
	assert_true(Defs.is_unlocked(&"hornets_nest", 10))
	assert_true(Defs.is_unlocked(&"farm_plot", 0), "structures are never locked")
	assert_true(Defs.is_unlocked(&"scaffold", 1))
	assert_eq(Defs.lock_reason(&"elephant_battery", 2), "Unlocks at Wave 5")
	assert_eq(Defs.lock_reason(&"rail_spike_driver", 6), "Unlocks at Wave 10")
	assert_eq(Defs.lock_reason(&"rail_spike_driver", 10), "")


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
	assert_true(cliff.find(&"twin_gatling") < cliff.find(&"hornets_nest"), "Mid before Late")


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
	assert_true(twin.has("spin_b") and twin.has("muzzle_b"), "twin barrels each spin and fire")
	assert_true(TierBuilder.loose_spike().get_surface_count() > 0)


func test_twin_gatling_doubles_the_rate() -> void:
	var g := Defs.turret(&"gatling_post")
	var t := Defs.turret(&"twin_gatling")
	assert_almost(t.fire_interval, g.fire_interval * 0.5, 0.001)
	assert_eq(t.heavy_mult, 0.5, "still weak against heavy")
	assert_eq(t.cost_scrap, 110)


func test_new_turret_numbers_and_stat_lines() -> void:
	assert_eq(Defs.cost_of(&"hornets_nest"), 200)
	assert_eq(Defs.cost_of(&"elephant_battery"), 120)
	assert_eq(Defs.cost_of(&"rail_spike_driver"), 220)
	assert_eq(Defs.cost_of(&"gatling_porch"), 180)
	assert_true(Defs.turret(&"hornets_nest").stat_line().contains("Ricochets to 2 More"))
	assert_true(Defs.turret(&"elephant_battery").stat_line().contains("Pierces 2 Bugs"))
	assert_true(Defs.turret(&"elephant_battery").stat_line().contains("x1.5 vs Heavy"))
	assert_true(Defs.turret(&"rail_spike_driver").stat_line().contains("Pins 2.5 s"))
	assert_true(Defs.turret(&"gatling_porch").stat_line().contains("Whole Yard"))
	assert_true(Defs.turret(&"rail_spike_driver").fire_interval > Defs.turret(&"elephant_battery").fire_interval, "the spike is very slow")
	assert_true(Defs.turret(&"elephant_battery").heavy_mult >= 1.5)


func test_cpu_moves_on_to_new_tiers_once_unlocked() -> void:
	var ids: Array = [&"gatling_post", &"twin_gatling", &"hornets_nest", &"buffalo_rifle"]
	assert_eq(TierRules.best_first(ids, 1), [&"gatling_post", &"buffalo_rifle"], "only Early before wave 5")
	assert_eq(TierRules.best_first(ids, 5), [&"twin_gatling", &"gatling_post", &"buffalo_rifle"], "Mid first from wave 5")
	assert_eq(TierRules.best_first(ids, 10), [&"hornets_nest", &"twin_gatling", &"gatling_post", &"buffalo_rifle"], "Late first from wave 10")


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
