class_name SiteLoot
extends StaticBody3D
## One pickup at a canyon-floor raid site (Canyon Expeditions): a heap of
## chitin, a scrap pile, a crate with a turret part, Doc's journal, a specimen
## jar, a blueprint tube, a boss trophy or a clutch of nest eggs. Built on every
## peer from SitePlan.loot_for (same seed, same loot); the host hands it out.
## E takes it (chitin and loose scrap: just walk over it); on a clutch of eggs,
## F smashes them instead.

static var _mesh_cache: Dictionary = {}

var site_index := 0
var loot: SitePlan.Loot
var _mi: MeshInstance3D
var _t := randf() * 5.0
var _spin := false


func setup(index: int, l: SitePlan.Loot, seed_value: int) -> void:
	site_index = index
	loot = l
	name = "Loot%d_%d" % [index, l.slot]
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	add_to_group("site_loot")
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.75 if l.look == &"egg" or l.look == &"part" or l.look == &"trophy" else 0.55
	col.shape = shape
	col.position.y = 0.35
	add_child(col)
	_mi = MeshInstance3D.new()
	var key := "%s:%d" % [l.look, seed_value % 3]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = SiteBuilder.loot(l.look, seed_value % 3 + 11)
	_mi.mesh = _mesh_cache[key]
	_mi.material_override = Materials.toon(0.012)
	add_child(_mi)
	# Small things bob and turn so they read as something to pick up.
	_spin = l.look in [&"page", &"specimen", &"blueprint"]
	set_process(_spin)


func _process(delta: float) -> void:
	_t += delta
	_mi.position.y = 0.06 + sin(_t * 2.2) * 0.05
	_mi.rotation.y += delta * 0.5


func describe() -> String:
	var parts: PackedStringArray = []
	for k: StringName in loot.items:
		var n := int(loot.items[k])
		if k == &"scrap" or k == &"chitin":
			parts.append("%d %s" % [n, k])
		elif n > 1:
			parts.append("%d %s" % [n, SitePlan.item_name(k)])
		else:
			parts.append(SitePlan.item_name(k))
	return ", ".join(parts)


func interact_prompt() -> String:
	if loot == null:
		return ""
	if loot.look == &"egg":
		var m := SiteManager.instance
		var need := m.smash_needed(site_index) if m != null else 0
		return "E: Take the Nest Eggs (%d)  ·  F: Smash Them (%d More Thins Its Tunnel)" % [int(loot.items.get(SitePlan.NEST_EGG, 0)), need]
	if loot.look == &"blueprint":
		return "E: Take %s (Parts for One)" % loot.label
	return "E: Take the %s (%s)" % [loot.label, describe()]


func local_interact(holding: bool) -> void:
	if holding or SiteManager.instance == null:
		return
	SiteManager.instance.request_take(site_index, loot.slot)


func cycle_option() -> void:
	if loot != null and loot.look == &"egg" and SiteManager.instance != null:
		SiteManager.instance.request_smash(site_index, loot.slot)
