extends SceneTree
## Renders the code-built weapons (ArmoryGuns) on a plain studio stage for
## review: each gun from its left and right sides, a three-quarter view from
## the muzzle end, and roughly where it sits in first person. Prints each gun's
## size and triangle count. No game, no network, no saves touched.
##
##   Godot --path . --screen 0 --windowed --resolution 1280x720 -s res://tools/armory/armory_preview.gd
##       -- --out=<dir> [--ids=primary|secondary|heavy|all|id,id,...] [--views=left,right,quarter,fp]

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _arg(key: String, def: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _run() -> void:
	_out = _arg("--out", OS.get_user_data_dir() + "/armory")
	DirAccess.make_dir_recursive_absolute(_out)
	var pick := _arg("--ids", "all")
	var ids: Array[StringName] = []
	match pick:
		"all":
			ids = ArmoryGuns.all_ids()
		"primary":
			ids = ArmoryGuns.ids(ArmoryGuns.PRIMARY)
		"secondary":
			ids = ArmoryGuns.ids(ArmoryGuns.SECONDARY)
		"heavy":
			ids = ArmoryGuns.ids(ArmoryGuns.HEAVY)
		_:
			for s: String in pick.split(",", false):
				ids.append(StringName(s.strip_edges()))
	var views := _arg("--views", "left,right,quarter,detail,fp").split(",", false)
	var stage := _stage()
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	for id: StringName in ids:
		var g := ArmoryGuns.whole(id)
		if g == null:
			print("[armory] %s: not built yet" % id)
			continue
		stage.add_child(g)
		var box := _aabb(g)
		var tris := 0
		for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		print("[armory] %s: %.2f x %.2f x %.2f m (w x h x l), %d tris, parts %s" % [id, box.size.x, box.size.y, box.size.z, tris,
				str(ArmoryGuns.parts(id).keys())])
		for v: String in views:
			_place(cam, v, box, id)
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, id, v])
		g.free()
	quit()


## A warm-lit studio: a dark backdrop, a key light with shadows, a cool rim, and a
## sky the metal can reflect.
func _stage() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#2E2620")
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#8AA4C0")
	sm.sky_horizon_color = Color("#E0C49A")
	sm.ground_bottom_color = Color("#4A3A2C")
	sm.ground_horizon_color = Color("#B89A74")
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	we.environment = e
	stage.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_color = Color("#FFE8C8")
	key.light_energy = 1.6
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_color = Color("#A8C0FF")
	rim.light_energy = 0.6
	stage.add_child(rim)
	return stage


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _place(cam: Camera3D, view: String, box: AABB, id: StringName = &"") -> void:
	var c := box.get_center()
	var span := maxf(box.size.z, maxf(box.size.y * 1.9, box.size.x * 1.9))
	match view:
		"muzzle":
			# Close on the business end, from the front left.
			var m := ArmoryGuns.muzzle(id)
			cam.fov = 30.0
			cam.global_position = m + Vector3(-0.2, 0.09, -0.16)
			cam.look_at(m + Vector3(0, 0, 0.04), Vector3.UP)
		"left", "right":
			cam.fov = 24.0
			var d := span * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 0.66
			cam.global_position = c + Vector3(-d if view == "left" else d, 0.0, 0.0)
			cam.look_at(c, Vector3.UP)
		"quarter":
			cam.fov = 30.0
			var d := span * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 0.62
			cam.global_position = c + Vector3(-0.62, 0.42, -0.66).normalized() * d
			cam.look_at(c, Vector3.UP)
		"detail":
			# Close on the action (the origin sits in the frame over the trigger).
			cam.fov = 30.0
			cam.global_position = Vector3(-0.3, 0.16, -0.12)
			cam.look_at(Vector3(0, 0.0, 0.0), Vector3.UP)
		"fp":
			# About where the viewmodel holds a gun: low and to the right of the eye.
			cam.fov = 70.0
			var heavy := box.size.z > 0.95
			var eye := Vector3(-0.09, 0.11, 0.3) if not heavy else Vector3(-0.15, 0.16, 0.4)
			cam.global_position = eye
			cam.look_at(eye + Vector3(0.04, -0.07, -1.0), Vector3.UP)
