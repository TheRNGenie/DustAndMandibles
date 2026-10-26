class_name IconStudio
extends RefCounted
## Small pictures of 3D things (turrets, structures, bugs) rendered once into a
## SubViewport and cached by key. The host node keeps the viewports alive.

static var _cache: Dictionary = {}


static func turret(host: Node, id: StringName, color: Color = Color.WHITE) -> Texture2D:
	var key := "turret:%s" % id
	if not _cache.has(key) or not is_instance_valid(_cache[key]["vp"]):
		var p := TurretBuilder.build(id, color)
		var head_y: float = p["head_y"]
		var gun_y: float = p["gun_y"]
		_render(host, key, [[p["base"], Transform3D()], [p["head"], Transform3D(Basis(), Vector3(0, head_y, 0))],
				[p["gun"], Transform3D(Basis(), Vector3(0, head_y + gun_y, 0))]], -35.0)
	return _cache[key]["tex"]


static func structure(host: Node, id: StringName) -> Texture2D:
	var key := "structure:%s" % id
	if not _cache.has(key) or not is_instance_valid(_cache[key]["vp"]):
		_render(host, key, [[StructureBuilder.build(Defs.structure(id).kind), Transform3D()]], -35.0)
	return _cache[key]["tex"]


static func seed_packet(host: Node, crop: StringName) -> Texture2D:
	var key := "packet:%s" % crop
	if not _cache.has(key) or not is_instance_valid(_cache[key]["vp"]):
		_render(host, key, [[CropBuilder.packet(crop), Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)]], -20.0)
	return _cache[key]["tex"]


static func bug(host: Node, id: StringName) -> Texture2D:
	var key := "bug:%s" % id
	if not _cache.has(key) or not is_instance_valid(_cache[key]["vp"]):
		var spec := BugBuilder.build(Defs.bug(id))
		var s := float(spec["scale"])
		var parts: Array = [[spec["body"], Transform3D(Basis().scaled(Vector3.ONE * s), Vector3.ZERO)]]
		# Legs as simple bent limbs from hip to the resting foot.
		var st := MeshKit.begin()
		for leg: Dictionary in spec["legs"]:
			var hip: Vector3 = leg["hip"]
			var foot: Vector3 = leg["rest"]
			var knee := (hip + foot) * 0.5 + Vector3.UP * float(spec.get("upper", 0.5)) * 0.6
			MeshKit.add_limb(st, hip, knee, float(spec.get("thick", 0.05)), spec.get("leg_color", Palette.OUTLINE), 5)
			MeshKit.add_limb(st, knee, foot, float(spec.get("thick", 0.05)) * 0.8, spec.get("leg_color", Palette.OUTLINE), 5)
		parts.append([MeshKit.finish(st), Transform3D()])
		_render(host, key, parts, 145.0)
	return _cache[key]["tex"]


static func _render(host: Node, key: String, parts: Array, yaw_deg: float) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var mat := Materials.toon(0.01)
	var aabb := AABB()
	var first := true
	for part: Array in parts:
		var mesh := part[0] as Mesh
		var xf: Transform3D = part[1]
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.transform = xf
		root.add_child(mi)
		var box := xf * mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	root.rotation.y = deg_to_rad(yaw_deg)
	var center := root.transform * aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 0.04)
	var cam := Camera3D.new()
	cam.fov = 35.0
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.05
	cam.position = center + Vector3(0, 0.45, 1.0).normalized() * dist
	vp.add_child(cam)
	cam.look_at(center)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	cam.environment = env
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	vp.add_child(sun)
	_cache[key] = {"vp": vp, "tex": vp.get_texture()}
