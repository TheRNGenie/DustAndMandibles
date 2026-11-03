extends TestCase
## Turret crafting: designs, recipes and the turret stats they make.


func test_design_round_trip() -> void:
	var id := CraftTable.design_id(&"swivel", &"scatter", &"fire")
	assert_eq(String(id), "craft_swivel_scatter_fire")
	assert_eq(CraftTable.parse(id), [&"swivel", &"scatter", &"fire"])
	assert_true(CraftTable.parse(&"gatling_post").is_empty())
	assert_eq(CraftTable.name_of(id), "Swivel Brush Peppergun")
	assert_eq(CraftTable.recipe(id).size(), 3)
	assert_eq(CraftTable.all_designs().size(), 48)


func test_defs_know_crafted() -> void:
	var id := CraftTable.design_id(&"tripod", &"rifle", &"acid")
	assert_true(Defs.is_turret(id))
	var d := Defs.turret(id)
	assert_true(d != null)
	assert_true(d.armor_pierce, "acid pierces armour")
	assert_eq(d.cost_scrap, 0, "placing uses the item, not scrap")
	assert_true(d.max_hp > CraftTable.BARRELS[&"rifle"]["hp"], "a tripod is sturdier")
	assert_eq(Defs.turret(CraftTable.design_id(&"post", &"scatter", &"fire")).effect, TurretDef.Effect.BURN)
	assert_eq(Defs.turret(CraftTable.design_id(&"post", &"rifle", &"explosive")).effect, TurretDef.Effect.SPLASH)


func test_parts() -> void:
	assert_eq(CraftTable.part_keys().size(), 11)
	assert_eq(CraftTable.part_name(&"part_swivel"), "Swivel mount")
	assert_true(CraftTable.is_part(CraftTable.random_part()))


func test_crafted_models_are_modular() -> void:
	# Every design builds its own model with the parts a Turret needs.
	var sizes: Dictionary = {}
	for id: StringName in CraftTable.all_designs():
		var p := TurretBuilder.build(id, Color.RED)
		for k: String in ["base", "head", "gun"]:
			assert_true(p[k] is ArrayMesh and (p[k] as ArrayMesh).get_surface_count() == 1, "%s %s" % [id, k])
		assert_true(float(p["head_y"]) > 0.5 and float(p["gun_y"]) > 0.1)
		assert_true((p["muzzle"] as Vector3).z < -0.5, "%s muzzle out front" % id)
		var verts := 0
		for k: String in ["base", "head", "gun", "spin"]:
			if p.has(k):
				verts += (p[k] as ArrayMesh).surface_get_array_len(0)
		assert_true(verts < 5000, "%s stays light: %d" % [id, verts])
		sizes[verts] = true
	assert_true(sizes.size() > 20, "the parts really change the model")
	# Mounts differ in height; the scatter barrel spins.
	var post := TurretBuilder.build(&"craft_post_rifle_lead", Color.RED)
	var swivel := TurretBuilder.build(&"craft_swivel_rifle_lead", Color.RED)
	assert_true(float(post["head_y"]) != float(swivel["head_y"]))
	assert_true(TurretBuilder.build(&"craft_tripod_scatter_fire", Color.RED).has("spin"))
	for k: StringName in CraftTable.part_keys():
		assert_true(not CraftBuilder.part_meshes(k).is_empty(), String(k))
