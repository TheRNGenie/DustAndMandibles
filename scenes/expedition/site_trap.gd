class_name SiteTrap
extends StaticBody3D
## A booby trap left round the old survey camp (Canyon Expeditions): a bear
## trap (steps on it: it bites, and the snap is loud) or a dynamite tripwire
## (walk through the wire: a short fuse, then a blast). E disarms either one.
## SiteManager (host) checks who trips it and tells everyone.

static var _meshes: Dictionary = {}

var site_index := 0
var trap_index := 0
## &"bear" or &"wire".
var kind: StringName = &"bear"
## Tripwire: the wire runs this far along the trap's local +X.
var span := 3.2
var armed := true
var _mi: MeshInstance3D


func setup(site: int, k: int, trap_kind: StringName) -> void:
	site_index = site
	trap_index = k
	kind = trap_kind
	name = "Trap%d_%d" % [site, k]
	collision_layer = WorldLayout.LAYER_TRAP
	collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 0.3, 0.7) if kind == &"bear" else Vector3(0.4, 0.8, 0.4)
	col.shape = shape
	col.position.y = shape.size.y * 0.5
	add_child(col)
	_mi = MeshInstance3D.new()
	_mi.material_override = Materials.toon(0.008)
	add_child(_mi)
	set_armed(true)


static func _mesh(key: String) -> ArrayMesh:
	if not _meshes.has(key):
		match key:
			"bear":
				_meshes[key] = SiteBuilder.bear_trap(false)
			"bear_shut":
				_meshes[key] = SiteBuilder.bear_trap(true)
			"wire":
				_meshes[key] = SiteBuilder.tripwire()
	return _meshes[key]


func set_armed(on: bool) -> void:
	armed = on
	if kind == &"bear":
		_mi.mesh = _mesh("bear" if on else "bear_shut")
		_mi.visible = true
	else:
		_mi.mesh = _mesh("wire")
		_mi.visible = on
	collision_layer = WorldLayout.LAYER_TRAP if on else 0


## Host: does a player standing at `pos` set it off?
func triggered_by(pos: Vector3) -> bool:
	if not armed:
		return false
	var local := to_local(pos)
	if absf(local.y) > 1.6:
		return false
	if kind == &"bear":
		return Vector2(local.x, local.z).length() < 0.55
	return local.x > 0.1 and local.x < span - 0.1 and absf(local.z) < 0.35


func interact_prompt() -> String:
	if not armed:
		return ""
	return "E: Disarm the Bear Trap" if kind == &"bear" else "E: Cut the Dynamite Tripwire"


func local_interact(holding: bool) -> void:
	if holding or not armed or SiteManager.instance == null:
		return
	SiteManager.instance.request_disarm(site_index, trap_index)
