extends SceneTree
## Renders the universal crop-fed turrets (UniversalBuilder) on a plain studio
## stage for review, posed in their animation states by their own animate():
##   empty   unloaded: barrel up, no glow, nothing in the hopper
##   loaded  loaded with a crop (--crop, default corn): level, glowing
##   fire    a moment after a shot (recoil, spinning, the next barrel's turn)
##   load    halfway through the loading animation (lids / doors open)
##   tier3   loaded at Tier 3 (armour, trims, +20% size)
##   gone    obstructions: 0.25 s after going off
## Prints each model's size, triangle count and part names. No game, no saves.
##
##   Godot --path . --screen 0 --windowed --resolution 1280x720 -s res://tools/universal/uni_preview.gd
##       -- --out=<dir> [--ids=cliff|air|house|ground|crewed|all|id,id] [--states=empty,loaded,fire,load,tier3]
##          [--views=quarter,side,front,top] [--crop=corn]

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _arg(key: String, def: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return def


func _run() -> void:
	_out = _arg("--out", OS.get_user_data_dir() + "/uni")
	DirAccess.make_dir_recursive_absolute(_out)
	var pick := _arg("--ids", "all")
	var ids: Array[StringName] = []
	var groups := {"cliff": Defs.UNIVERSAL_CLIFF, "air": Defs.UNIVERSAL_AA, "house": Defs.UNIVERSAL_LAST,
		"ground": Defs.UNIVERSAL_OBSTRUCTIONS, "crewed": Defs.UNIVERSAL_CREWED}
	if pick == "all":
		for g: String in groups:
			ids.append_array(groups[g])
	elif groups.has(pick):
		ids.append_array(groups[pick])
	else:
		for s: String in pick.split(",", false):
			ids.append(StringName(s.strip_edges()))
	var states := _arg("--states", "empty,loaded,fire,load").split(",", false)
	var views := _arg("--views", "quarter,side").split(",", false)
	var crop := StringName(_arg("--crop", "corn"))
	var stage := _stage()
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	for id: StringName in ids:
		var s := UniversalBuilder.spec(id, Color("#C0392B"))
		var holder := Node3D.new()
		stage.add_child(holder)
		var base := Node3D.new()
		holder.add_child(base)
		var head := Node3D.new()
		head.position.y = float(s.get("head_y", 0.2))
		holder.add_child(head)
		var gun := Node3D.new()
		gun.position.y = float(s.get("gun_y", 0.4))
		head.add_child(gun)
		var rig := UniRig.make(s, base, head, gun)
		var box := _aabb(holder)
		var tris := 0
		for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		print("[uni] %s: %.2f x %.2f x %.2f m (w x h x l), %d tris, parts %s, muzzles %d" % [id, box.size.x, box.size.y, box.size.z,
				tris, str(rig.parts.keys()), rig.muzzles.size()])
		for st: String in states:
			var ctx := UniCtx.new()
			_pose(id, s, rig, ctx, gun, st, crop)
			for v: String in views:
				_place(cam, v, box)
				for i in 3:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s_%s_%s.png" % [_out, id, st, v])
		holder.free()
	quit()


## Puts the rig in a state: runs its animate() for a few steps with the context
## set the way the game would have it.
func _pose(id: StringName, s: Dictionary, rig: UniRig, ctx: UniCtx, gun: Node3D, state: String, crop: StringName) -> void:
	rig.state.clear()
	rig.show_tier(0)
	for h in rig.holders:
		h.scale = Vector3.ONE
	var no_aim := bool(s.get("no_aim", false)) or Defs.turret(id).obstruction
	ctx.loaded = state != "empty"
	ctx.crop = crop if ctx.loaded else &""
	ctx.color = CropEffects.color_of(crop) if ctx.loaded else CropEffects.EMPTY_COLOR
	ctx.t = 1.3
	ctx.load_k = 1.0
	ctx.drain_k = 1.0
	ctx.shot_age = 9.0
	ctx.firing = 0.0
	ctx.placed_age = 5.0
	gun.rotation.x = 0.0 if no_aim else (float(s.get("rest_pitch", UniKit.REST_UP)) if state == "empty" else float(s.get("loaded_pitch", 0.0)))
	match state:
		"fire":
			ctx.in_wave = true
			ctx.tracking = true
			ctx.firing = 1.0
			for i in 6:
				ctx.shots += 1
				ctx.shot_age = 0.0
				UniversalBuilder.animate(id, rig, ctx, 0.05)
				ctx.shot_age = 0.05
				ctx.firing += 0.1
			ctx.shot_age = 0.02
			ctx.charge = 0.05
		"load":
			ctx.load_k = 0.5
		"tier3":
			ctx.tier = 2
			rig.show_tier(2)
			for h in rig.holders:
				h.scale = Vector3.ONE * 1.2
		"gone":
			ctx.triggered = true
			ctx.trigger_age = 0.25
	UniversalBuilder.animate(id, rig, ctx, 0.016)
	rig.set_crop(ctx.color, 1.0 if ctx.loaded and ctx.load_k >= 1.0 else (0.4 if ctx.loaded else 0.0), ctx.loaded)


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
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#C9A877")
	floor_mi.material_override = fm
	stage.add_child(floor_mi)
	return stage


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _place(cam: Camera3D, view: String, box: AABB) -> void:
	var c := box.get_center()
	var span := maxf(box.size.length(), 1.0)
	cam.fov = 32.0
	var d := span * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.05
	match view:
		"quarter": # front left, a little above: the gun points at the camera's left
			cam.global_position = c + Vector3(-0.75, 0.5, -0.7).normalized() * d
		"side":
			cam.global_position = c + Vector3(-1, 0.12, 0).normalized() * d
		"front":
			cam.global_position = c + Vector3(0, 0.2, -1).normalized() * d
		"back":
			cam.global_position = c + Vector3(0.6, 0.45, 0.8).normalized() * d
		"top":
			cam.global_position = c + Vector3(0.001, 1, 0.25).normalized() * d
	cam.look_at(c, Vector3.UP)
