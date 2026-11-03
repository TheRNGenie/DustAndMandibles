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
##   --floortest             (host) take every pickup at every site, smash a nest,
##                           trip a bear trap and sit in the wreck till it falls; prints it all

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
			# Count the teleport as a trip down, so the real backpack and the site timers see it.
			var ex := get_node_or_null("/root/Expedition")
			if ex != null and ex.has_method("report_trip"):
				ex.call("report_trip", true)
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
	if GameState.has_flag("--floortest"):
		await _floor_test(mgr, player)
	var shot := GameState.flag_value("--floorshot")
	if shot != "":
		var secs := GameState.flag_value("--seconds").to_float()
		await tree.create_timer(secs if secs > 0.0 else 3.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("[floor] saved %s" % shot)
		tree.quit()


func _floor_test(mgr: SiteManager, player: Player) -> void:
	var me := multiplayer.get_unique_id()
	var before := Economy.ledger.stock.duplicate(true)
	for site in mgr.sites:
		var got := 0
		for l: SitePlan.Loot in mgr.get("_loot_lists")[site.index]:
			if l.look == &"egg" and site.kind == SitePlan.Kind.NEST:
				continue
			if mgr.call("_take", me, site.index, l.slot):
				got += 1
		print("[floortest] %s: took %d, %d left" % [site.display_name(), got, mgr.loot_left(site.index)])
		if site.kind == SitePlan.Kind.NEST:
			var awake_before := 0
			for b in BugManager.instance.site_bugs():
				if b.site == site.index and b.state == Bug.State.HUNTING:
					awake_before += 1
			var smashed := 0
			for l: SitePlan.Loot in mgr.get("_loot_lists")[site.index]:
				if l.look == &"egg" and mgr.smash_needed(site.index) > 0:
					mgr.call("_smash", me, site.index, l.slot)
					smashed += 1
			await get_tree().create_timer(0.5).timeout
			var awake := 0
			for b in BugManager.instance.site_bugs():
				if b.site == site.index and b.state == Bug.State.HUNTING:
					awake += 1
			print("[floortest] nest: smashed %d, tunnel %d cut for wave %d: %s; awake %d -> %d" % [smashed, site.tunnel, GameState.wave,
					SitePlan.is_cut(site.tunnel, GameState.wave), awake_before, awake])
			print("[floortest] cut 10 -> %d" % SitePlan.cut_count(site.tunnel, GameState.wave, 10))
	# (Clear the floor so the bugs don't eat the tester before the traps and the wreck.)
	for b in BugManager.instance.site_bugs():
		b.health.take_damage(99999.0, "test", -1)
	print("[floortest] stock before %s" % str(before))
	print("[floortest] stock after  %s" % str(Economy.ledger.stock))
	for site in mgr.sites:
		if site.kind == SitePlan.Kind.CAMP:
			var trap: SiteTrap = mgr.get("_traps")["%d:0" % site.index]
			var hp0 := float(player.vitals.get("hp"))
			player.global_position = trap.global_position + Vector3(0, 0.1, 0)
			await get_tree().create_timer(0.6).timeout
			print("[floortest] bear trap: armed %s, hp %.0f -> %.0f" % [trap.armed, hp0, float(player.vitals.get("hp"))])
	for site in mgr.sites:
		if site.kind == SitePlan.Kind.WRECK:
			var stand := site.at(Vector2(0.5, 5.8))
			player.global_position = Vector3(stand.x, mgr.ground_at(stand) + 0.3, stand.z)
			var t0 := Time.get_ticks_msec()
			while not mgr.is_collapsed(site.index) and Time.get_ticks_msec() - t0 < 40000:
				await get_tree().process_frame
			print("[floortest] wreck collapsed %s after %.1f s, hp %.0f" % [mgr.is_collapsed(site.index), (Time.get_ticks_msec() - t0) / 1000.0, float(player.vitals.get("hp"))])
