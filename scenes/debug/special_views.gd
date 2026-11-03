extends Node
## Debug views for the special-shot turrets (Steam Cannon, Flood Gate, Twin Mortar,
## Bola Launcher). Started by DebugTools when --specialview=<what> is given.
##   --specialview=lineup         all four built side by side on your lip
##                                (--specialcam=back|front|side, default back)
##   --specialview=<id>           that turret alone, bugs climbing the far wall in
##                                front of it; the camera watches the shot land
##   --specialview=icons          the four build-menu icons on one sheet
## --specialshot=<png> saves the view (lineup / icons: after a moment; a turret:
## --specialdelay=S seconds after its first shot, default 0.5) and quits.

const IDS: Array[StringName] = [&"steam_cannon", &"bola_launcher", &"twin_mortar", &"flood_gate"]

var world: Node3D
var _turret: Turret
var _shots := 0
var _first_shot_ms := -1
var _cam: Camera3D
var _inward := Vector3.ZERO


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	var what := GameState.flag_value("--specialview")
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var cid := player.cliff_id if player != null else WorldLayout.WEST
	var bm := BuildManager.instance
	for c in 2:
		Economy.earn(c, {&"scrap": 5000, &"chili": 200})
	var cliffs := world.get("cliffs") as CliffBuilder
	if what == "icons":
		_icons()
		return
	if what == "models":
		# Plain posed meshes (no scaffold), like the crafted-turret lineup.
		var cv: Object = load("res://scenes/debug/craft_views.gd").new()
		cv.set("world", world)
		var a := Buildable.cell_center(cliffs, cid, Vector2i(3, 6))
		var b := Buildable.cell_center(cliffs, cid, Vector2i(3, 7))
		var along := (b - a).normalized()
		var yaw := WorldLayout.facing_canyon_yaw(cid)
		var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		var gap := 2.7
		var centre := Vector3.ZERO
		var turn := deg_to_rad(GameState.flag_value("--specialyaw").to_float()) if GameState.flag_value("--specialyaw") != "" else deg_to_rad(-25.0)
		for i in IDS.size():
			var p := a + along * gap * (float(i) - (IDS.size() - 1) * 0.5)
			p.y = a.y
			centre += p / IDS.size()
			cv.call("_pose", IDS[i], p, yaw, turn, deg_to_rad(8.0), Palette.team_color(cid))
		(cv as Node).free()
		var right := fwd.cross(Vector3.UP).normalized()
		var width := gap * IDS.size()
		var cam := _camera()
		cam.fov = 40.0
		match GameState.flag_value("--specialcam"):
			"back":
				cam.global_position = centre - fwd * width * 0.8 + right * 1.5 + Vector3.UP * 3.0
			"near":
				var k := GameState.flag_value("--specialnear").to_int()
				var p := a + along * gap * (float(k) - (IDS.size() - 1) * 0.5)
				p.y = a.y
				cam.global_position = p + fwd * 3.6 - right * 2.0 + Vector3.UP * 2.4
				cam.look_at(p + Vector3.UP * 1.3, Vector3.UP)
			_:
				cam.global_position = centre + fwd * width * 0.95 - right * 1.5 + Vector3.UP * 2.8
		if GameState.flag_value("--specialcam") != "near":
			cam.look_at(centre + Vector3.UP * 1.2, Vector3.UP)
		if player != null:
			player.global_position = centre - fwd * 16.0
		await get_tree().create_timer(2.0).timeout
		_save()
		return
	if what == "lineup":
		for i in IDS.size():
			bm._do_build(1, IDS[i], cid, Vector2i(0, 6 + i * 2))
		await get_tree().physics_frame
		var mid := (Buildable.cell_center(cliffs, cid, Vector2i(0, 8)) + Buildable.cell_center(cliffs, cid, Vector2i(0, 10))) * 0.5
		var inward := WorldLayout.inward(cid) # toward the canyon
		var along := (Buildable.cell_center(cliffs, cid, Vector2i(0, 9)) - Buildable.cell_center(cliffs, cid, Vector2i(0, 8))).normalized()
		var cam := _camera()
		match GameState.flag_value("--specialcam"):
			"front":
				cam.global_position = mid + inward * 7.5 + along * 2.0 + Vector3.UP * 1.0
			"side":
				cam.global_position = mid - along * 9.0 - inward * 3.5 + Vector3.UP * 3.2
			_:
				cam.global_position = mid - inward * 8.5 - along * 3.0 + Vector3.UP * 4.0
		cam.look_at(mid + Vector3.UP * 1.6, Vector3.UP)
		if player != null:
			player.global_position = mid - inward * 20.0
		_spawn_bugs(cid, 2)
		await get_tree().create_timer(4.0).timeout
		_save()
		return
	var id := StringName(what)
	if not IDS.has(id):
		push_error("special_views: unknown view " + what)
		return
	var cell := Vector2i(0, 9)
	bm._do_build(1, id, cid, cell)
	await get_tree().physics_frame
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		if n is Turret and (n as Turret).def.id == id:
			_turret = n
	var at := Buildable.cell_center(cliffs, cid, cell)
	var inward := WorldLayout.inward(cid)
	var far := WorldLayout.other_cliff(cid)
	var lane := _lane_near(at)
	var target := cliffs.face_point(far, 34.0, WorldLayout.LANE_Z[lane])
	var cam := _camera()
	var side := Vector3.UP.cross(inward).normalized()
	# From the lip beside the turret, over its shoulder toward the far wall.
	cam.global_position = at - inward * 3.0 + side * 3.5 + Vector3.UP * 4.5
	if GameState.flag_value("--specialcam") == "wall":
		cam.global_position = at + inward * 14.0 + side * 12.0 + Vector3.UP * -6.0
	cam.look_at(at.lerp(target, 0.8), Vector3.UP)
	_cam = cam
	_inward = inward
	if player != null:
		player.global_position = at - inward * 20.0
	_spawn_bugs(cid, lane, id)


func _camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 58.0
	world.add_child(cam)
	cam.current = true
	return cam


## The lane (WorldLayout.LANE_Z index) nearest a point on the plateau.
func _lane_near(p: Vector3) -> int:
	var best := 0
	for i in WorldLayout.LANE_Z.size():
		if absf(WorldLayout.LANE_Z[i] - p.z) < absf(WorldLayout.LANE_Z[best] - p.z):
			best = i
	return best


func _spawn_bugs(cid: int, lane: int, id: StringName = &"") -> void:
	var bugs := world.get("bugs") as BugManager
	var far := WorldLayout.other_cliff(cid)
	match id:
		&"flood_gate":
			bugs.spawn_group(&"dust_mite", 10, far, lane, 18.0)
			bugs.spawn_group(&"wolf_spider", 4, far, lane, 30.0)
			bugs.spawn_group(&"rattler_beetle", 1, far, lane, 26.0)
			bugs.spawn_group(&"dust_mite", 5, far, mini(lane + 1, 4), 24.0)
		&"steam_cannon":
			bugs.spawn_group(&"dust_mite", 8, far, lane, 30.0)
			bugs.spawn_group(&"rattler_beetle", 1, far, lane, 28.0)
		&"twin_mortar":
			bugs.spawn_group(&"dust_mite", 10, far, lane, 30.0)
			bugs.spawn_group(&"wolf_spider", 3, far, lane, 28.0)
		&"bola_launcher":
			bugs.spawn_group(&"wolf_spider", 4, far, lane, 30.0)
			bugs.spawn_group(&"dust_mite", 4, far, lane, 32.0)
		_:
			for l in 5:
				bugs.spawn_group(&"dust_mite", 4, far, l, 20.0 + l * 3.0)


func _physics_process(_delta: float) -> void:
	if _turret == null or not is_instance_valid(_turret):
		return
	if _turret.shots != _shots:
		_shots = _turret.shots
		print("[special] %s shot %d at %s (t=%.2f)" % [_turret.def.id, _shots, str(_turret.aim_point.snapped(Vector3.ONE * 0.1)), Time.get_ticks_msec() / 1000.0])
		if _first_shot_ms < 0:
			_first_shot_ms = Time.get_ticks_msec()
			if GameState.flag_value("--specialcam") == "close" and _cam != null:
				# Close in on where the shot lands, from just off the far wall.
				var aim := _turret.aim_point
				var side := Vector3.UP.cross(_inward).normalized()
				_cam.global_position = aim - _inward * 9.0 + side * 3.0 + Vector3.UP * 1.5
				_cam.look_at(aim, Vector3.UP)
			var delay := GameState.flag_value("--specialdelay").to_float() if GameState.flag_value("--specialdelay") != "" else 0.5
			get_tree().create_timer(delay).timeout.connect(_save)


func _save() -> void:
	var path := GameState.flag_value("--specialshot")
	if path == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[special] saved ", path)
	# Log what happened to the bugs on the far wall.
	var bugs := world.get("bugs") as BugManager
	for b: Node in bugs.get_children():
		var bug := b as Bug
		if bug != null and bug.is_alive():
			print("[special]   %s y=%.1f z=%.1f speed %.2f rooted %s hp %.0f" % [bug.def.id, bug.climb_y, bug.lane_z, bug.status.speed_multiplier(), bug.status.is_rooted(), bug.health.hp])
	get_tree().quit()


func _icons() -> void:
	var texs: Array[Texture2D] = []
	for id in IDS:
		texs.append(IconStudio.turret(self, id, Palette.TEAM_WEST))
	for i in 10:
		await get_tree().process_frame
	var sheet := Image.create(128 * IDS.size(), 128, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.18, 0.13, 0.11))
	for i in texs.size():
		var img := texs[i].get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, 128, 128), Vector2i(128 * i, 0))
	var path := GameState.flag_value("--specialshot")
	if path != "":
		sheet.save_png(path)
		print("[special] icons saved ", path)
	get_tree().quit()
