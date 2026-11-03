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
