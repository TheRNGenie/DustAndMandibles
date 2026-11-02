extends TestCase
## One content registry: every bug, turret, structure, crop and weapon is a .tres
## resource registered in Defs. Every id is unique across all of them, every
## registered resource loads with the right type and id, and no .tres in a
## content folder is left out of the registry.

const FOLDERS := {"bugs": "res://data/bugs", "turrets": "res://data/turrets", "structures": "res://data/structures",
	"crops": "res://data/crops", "weapons": "res://data/weapons"}
const TYPES := {"bugs": "BugDef", "turrets": "TurretDef", "structures": "StructureDef", "crops": "CropDef", "weapons": "WeaponDef"}


func test_every_def_id_is_unique() -> void:
	var seen := {}
	for kind: String in Defs.REGISTRIES:
		for key: StringName in (Defs.REGISTRIES[kind] as Dictionary):
			assert_false(seen.has(key), "id %s is in both %s and %s" % [key, seen.get(key, ""), kind])
			seen[key] = kind
	assert_true(seen.size() > 30, "registries are populated (%d ids)" % seen.size())


func test_every_registered_resource_loads_as_its_type() -> void:
	for kind: String in Defs.REGISTRIES:
		var reg: Dictionary = Defs.REGISTRIES[kind]
		for key: StringName in reg:
			var res: Resource = reg[key]
			assert_true(res != null, "%s/%s loads" % [kind, key])
			if res == null:
				continue
			var script := res.get_script() as Script
			assert_true(script != null and script.get_global_name() == StringName(TYPES[kind]),
					"%s/%s is a %s" % [kind, key, TYPES[kind]])
			assert_eq(StringName(res.get("id")), key, "%s/%s id matches its key" % [kind, key])
			assert_eq(res.resource_path.get_file().get_basename(), String(key), "%s/%s file is named after its id" % [kind, key])


func test_no_content_file_is_left_out() -> void:
	for kind: String in FOLDERS:
		var reg: Dictionary = Defs.REGISTRIES[kind]
		var dir := DirAccess.open(FOLDERS[kind])
		assert_true(dir != null, "%s folder exists" % kind)
		if dir == null:
			continue
		for f in dir.get_files():
			f = f.trim_suffix(".remap")
			if not f.ends_with(".tres"):
				continue
			assert_true(reg.has(StringName(f.get_basename())), "%s/%s is registered in Defs" % [kind, f])
			var res := load(FOLDERS[kind] + "/" + f)
			assert_true(res != null, "%s/%s loads" % [kind, f])


func test_lookups_go_through_defs() -> void:
	for id: StringName in Defs.WEAPONS:
		assert_true(Defs.weapon(id) != null, "weapon %s" % id)
	for id: StringName in Defs.CROPS:
		var seed := Defs.seed_of(id)
		assert_true(String(seed).begins_with("seed_"), "crop %s has a seed item (%s)" % [id, seed])
		assert_true(EconomyLedger.RESOURCES.has(seed), "crop %s's seed %s is a stockpile resource" % [id, seed])
	assert_eq(Defs.weapon(&"nope"), null)
	assert_eq(Defs.seed_of(&"nope"), &"")
