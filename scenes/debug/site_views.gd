extends Node
## Canyon Expeditions debug views (loaded by SiteManager when --floor is given):
##   --floor=N               stand on the canyon floor at raid site N (players may
##                           stay down there: no fall-and-respawn)
##   --floor=overview        open the overview map (with the site markers)
##   --floorcam=eye|wide|top|close   eye: first person at the site's edge (default);
##                           wide / top / close: a free camera on the site
##   --floorshot=<png> [--seconds=N]  save a screenshot and quit
##   --floorwake             a noise at the site 2 s in (watch the sleepers get up)
##   --floorlog              print the site bugs' states every second

var _cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	var world := tree.current_scene
	var mgr := get_parent() as SiteManager
	var until := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until and (mgr.sites.is_empty() or mgr.gen_wave <= 0 or world.call("local_player") == null):
		await tree.process_frame
	for i in 10:
		await tree.process_frame
	var spec := GameState.flag_value("--floor")
	var player := world.call("local_player") as Player
	print("[floor] %d sites, wave %d" % [mgr.sites.size(), mgr.gen_wave])
	for s in mgr.sites:
		print("[floor]   %d %s at %s (tunnel %d), %d loot" % [s.index, s.display_name(), str(s.pos.snapped(Vector3.ONE * 0.1)), s.tunnel, mgr.loot_left(s.index)])
	if spec == "overview":
		var hud := world.get("hud") as Hud
		if hud != null:
			hud.overview.visible = true
	else:
		var idx := clampi(int(spec), 0, mgr.sites.size() - 1)
		var site := mgr.sites[idx]
		var mode := GameState.flag_value("--floorcam")
		if player != null:
			var stand := site.at(Vector2(1.5, SitePlan.RADIUS + 3.0))
			stand.y = mgr.ground_at(stand) + 0.2
			player.global_position = stand
			player.velocity = Vector3.ZERO
			player.look_at(Vector3(site.pos.x, stand.y, site.pos.z), Vector3.UP)
			player.rotation.x = 0.0
			player.rotation.z = 0.0
			player.head.rotation.x = deg_to_rad(-12.0)
		if mode != "" and mode != "eye":
			_cam = Camera3D.new()
			_cam.fov = 60.0
			world.add_child(_cam)
			var eye: Vector3
			var look := site.pos + Vector3(0, 1.2, 0)
			match mode:
				"top":
					eye = site.pos + Vector3(0, 24, 0.01)
					look = site.pos
				"close":
					eye = site.at(Vector2(3.5, 6.5)) + Vector3(0, 2.2, 0)
				"left":
					eye = site.at(Vector2(-9.5, 6.0)) + Vector3(0, 3.5, 0)
				_:
					eye = site.at(Vector2(6.0, 12.5)) + Vector3(0, 5.5, 0)
			_cam.global_position = eye
			_cam.look_at(look, Vector3.UP)
			_cam.make_current()
			var hud := world.get("hud") as CanvasLayer
			if hud != null and not GameState.has_flag("--keephud"):
				hud.visible = false
		if GameState.has_flag("--floorwake"):
			tree.create_timer(2.0).timeout.connect(func() -> void: ExpeditionApi.make_noise(site.pos, 30.0))
	if GameState.has_flag("--floorlog"):
		var t := Timer.new()
		t.wait_time = 1.0
		t.autostart = true
		add_child(t)
		t.timeout.connect(func() -> void:
			var parts: PackedStringArray = []
			for b in BugManager.instance.site_bugs():
				parts.append("%s@%d:%s" % [b.def.id, b.site, Bug.State.keys()[b.state]])
			var me := world.call("local_player") as Player
			print("[floor] t=%d down=%s hp=%s alive(wave)=%d  %s" % [Time.get_ticks_msec() / 1000,
					ExpeditionApi.is_down(multiplayer.get_unique_id()), str(me.vitals.get("hp")) if me != null else "?",
					BugManager.instance.alive_count(), " ".join(parts)]))
	var shot := GameState.flag_value("--floorshot")
	if shot != "":
		var secs := GameState.flag_value("--seconds").to_float()
		await tree.create_timer(secs if secs > 0.0 else 3.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("[floor] saved %s" % shot)
		tree.quit()
