class_name DebugTools
extends Node
## Debug cheats (only with --debug): F6 skip phase, F7 +500 scrap, F8 spawn the next
## bug type on a random lane of your partner's cliff, F9 god mode, F10 show lanes.
## Also the automation flags used for testing:
##   --shot=<png> [--frames=N] [--pos=d,z] [--look=yaw,pitch] [--autofire] [--autoskip]
##   [--autobuild] (places turrets on both cliffs) saves a screenshot and quits.

var world: Node3D
var _bug_index := 0
var _lanes: MeshInstance3D


func _ready() -> void:
	var shot := GameState.flag_value("--shot")
	if shot != "":
		_take_screenshot(shot)
	elif GameState.flag_value("--soak") != "":
		_soak(GameState.flag_value("--soak").to_float())


## --soak=N: runs N seconds (works headless), auto-readies every build phase,
## logs each phase change, then quits. Combine with --autobuild and --fast.
func _soak(seconds: float) -> void:
	for i in 20:
		await get_tree().process_frame
	if GameState.has_flag("--autobuild") and multiplayer.is_server():
		_autobuild()
	var bugs := world.get("bugs") as BugManager
	GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
		print("[soak %5.1fs] wave %d phase %d  homesteads %s  bugs %d  scrap W%d E%d" % [
			Time.get_ticks_msec() / 1000.0, GameState.wave, p, str(GameState.homestead_hp),
			bugs.alive_count(), Economy.amount(0, &"scrap"), Economy.amount(1, &"scrap")]))
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0) and GameState.phase != GameState.Phase.GAME_OVER:
		await get_tree().create_timer(1.0).timeout
		if GameState.has_flag("--god"):
			GameState.god_mode = true
		if GameState.has_flag("--autokill"):
			# Stand-in for players with revolvers: 25 damage per second to every breacher and bandit.
			for n: Node in get_tree().get_nodes_in_group("bugs"):
				var b := n as Bug
				if b.is_alive() and (b.state == Bug.State.BREACHING or b.state == Bug.State.FLYING):
					b.receive_hit(25.0, b.global_position, Vector3.DOWN, false, 1.0, "Rancher", b.cliff_id)
		if GameState.phase == GameState.Phase.BUILD:
			if GameState.has_flag("--farm"):
				_farm()
			GameState.vote_skip()
	print("[soak] end: wave %d phase %d homesteads %s bugs %d" % [GameState.wave, GameState.phase, str(GameState.homestead_hp), bugs.alive_count()])
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.has_flag("--debug") or GameState.menu_open:
		return
	if event.is_action_pressed("debug_skip_phase"):
		GameState.debug_skip()
	elif event.is_action_pressed("debug_add_scrap"):
		_cheat.rpc_id(1, "scrap")
	elif event.is_action_pressed("debug_spawn_bug"):
		_cheat.rpc_id(1, "spawn")
	elif event.is_action_pressed("debug_god_mode"):
		_cheat.rpc_id(1, "god")
	elif event.is_action_pressed("debug_show_lanes"):
		_toggle_lanes()


@rpc("any_peer", "call_local", "reliable")
func _cheat(kind: String) -> void:
	if not multiplayer.is_server() or not GameState.has_flag("--debug"):
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var cid := NetworkManager.cliff_of(sender) if NetworkManager.is_online() else _local_cliff()
	match kind:
		"scrap":
			Economy.earn(cid, {&"scrap": 500, &"chitin": 50})
		"spawn":
			var ids: Array = Defs.BUGS.keys()
			var id: StringName = ids[_bug_index % ids.size()]
			_bug_index += 1
			var d := Defs.bug(id)
			(world.get("bugs") as BugManager).spawn_group(id, d.group_size, WorldLayout.other_cliff(cid), randi() % 5)
		"god":
			GameState.god_mode = not GameState.god_mode
			print("God mode: ", GameState.god_mode)


func _local_cliff() -> int:
	var p := world.call("local_player") as Player
	return p.cliff_id if p != null else WorldLayout.WEST


## Draws each climb lane as a glowing line up both cliff faces.
func _toggle_lanes() -> void:
	if _lanes != null:
		_lanes.queue_free()
		_lanes = null
		return
	var cliffs := world.get("cliffs") as CliffBuilder
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Palette.ACID_GREEN
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for cid in 2:
		for lz in WorldLayout.LANE_Z:
			var y := 0.0
			while y < WorldLayout.CLIFF_HEIGHT:
				var n := cliffs.face_normal(cid, y, lz) * 0.3
				im.surface_add_vertex(cliffs.face_point(cid, y, lz) + n)
				im.surface_add_vertex(cliffs.face_point(cid, y + 1.0, lz) + n)
				y += 1.0
	im.surface_end()
	_lanes = MeshInstance3D.new()
	_lanes.mesh = im
	world.add_child(_lanes)


func _take_screenshot(path: String) -> void:
	var frames := int(GameState.flag_value("--frames")) if GameState.flag_value("--frames") != "" else 90
	# --seconds=N waits real time instead of a frame count (frame rate varies a lot).
	var seconds := GameState.flag_value("--seconds").to_float()
	for i in 20:
		await get_tree().process_frame
	var player := world.call("local_player") as Player
	var cliffs := world.get("cliffs") as CliffBuilder
	var pos := GameState.flag_value("--pos")
	if player != null and pos != "":
		var p := pos.split(",")
		player.global_position = cliffs.plateau_point(player.cliff_id, p[0].to_float(), p[1].to_float()) + Vector3.UP * 0.2
		player.spawn_transform = player.global_transform
	var look := GameState.flag_value("--look")
	if player != null and look != "":
		var parts := look.split(",")
		player.rotation.y += deg_to_rad(parts[0].to_float())
		player.head.rotation.x = deg_to_rad(parts[1].to_float())
	if GameState.has_flag("--autobuild") and multiplayer.is_server():
		_autobuild()
	if (GameState.has_flag("--showcase") or GameState.flag_value("--showcase") != "") and multiplayer.is_server():
		_showcase()
	if GameState.flag_value("--pause") != "":
		var pm := world.get_node("PauseMenu") as PauseMenu
		pm.open()
		pm.select_tab(int(GameState.flag_value("--pause")))
	var start := Time.get_ticks_msec()
	var i := 0
	while (seconds > 0.0 and Time.get_ticks_msec() - start < int(seconds * 1000.0)) or (seconds <= 0.0 and i < frames):
		await get_tree().process_frame
		i += 1
		if player != null and look != "":
			player.head.rotation.x = deg_to_rad(look.split(",")[1].to_float())
		_apply_freecam(player)
		if i == 30 and GameState.has_flag("--autoskip"):
			GameState.vote_skip()
		if player != null and GameState.has_flag("--autofire") and i % 40 == 0:
			if player.revolver.trigger(player.camera):
				player.net.fire(player.camera.global_position, -player.camera.global_transform.basis.z)
	var players_root := world.get("players_root") as Node3D
	print("[peer %d] phase %d wave %d, players %d, bugs %d, homesteads %s" % [multiplayer.get_unique_id(),
			GameState.phase, GameState.wave, players_root.get_child_count(),
			(world.get("bugs") as BugManager).alive_count(), str(GameState.homestead_hp)])
	var shown := 0
	for b: Node in get_tree().get_nodes_in_group("bugs"):
		if shown < 4:
			var bug := b as Bug
			print("  bug %s %s state %d y %.1f z %.1f at %s visible %s" % [bug.name, bug.def.id, bug.state, bug.climb_y, bug.lane_z, str(bug.global_position.snapped(Vector3.ONE * 0.1)), bug.is_visible_in_tree()])
			shown += 1
	for p: Node in players_root.get_children():
		print("[peer %d]   player %s at %s" % [multiplayer.get_unique_id(), p.name, str((p as Node3D).global_position.snapped(Vector3.ONE * 0.1))])
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved screenshot to ", path)
	get_tree().quit()


## --cam=x,y,z,tx,ty,tz puts the camera at a fixed spot looking at a target.
func _apply_freecam(player: Player) -> void:
	var cam := GameState.flag_value("--cam")
	if player == null or cam == "":
		return
	var v := cam.split(",")
	var from := Vector3(v[0].to_float(), v[1].to_float(), v[2].to_float())
	var to := Vector3(v[3].to_float(), v[4].to_float(), v[5].to_float())
	player.camera.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


## Spends each cliff's scrap on the next free turret slot (Buffalo every third).
func _reinvest(builds: BuildManager) -> void:
	# Farm first (plant, water, harvest every plot) and use the wells, like a player would.
	_farm()
	var turret_cycle: Array[StringName] = [&"gatling_post", &"buffalo_rifle", &"water_cannon",
		&"gatling_post", &"chili_mortar", &"dynamite_lobber", &"lasso_harpoon"]
	var trap_cycle: Array[StringName] = [&"lantern_post", &"barbed_wire", &"bear_trap", &"dynamite_crate", &"palisade", &"rain_catcher"]
	for cid in 2:
		var i := 0
		for col in Buildable.COLS:
			var id := turret_cycle[i % turret_cycle.size()]
			if not builds.is_free(cid, Vector2i(0, col)):
				i += 1
				continue
			if Economy.amount(cid, &"scrap") < Defs.cost_of(id):
				break
			builds.build(id, cid, Vector2i(0, col))
			i += 1
		# Spare scrap goes into traps around the Homestead.
		var j := 0
		for col: int in [7, 9, 11, 13, 8, 12]:
			var tid := trap_cycle[j % trap_cycle.size()]
			j += 1
			var cell := Vector2i(9, col)
			if builds.is_free_for(tid, cid, cell) and Economy.amount(cid, &"scrap") >= Defs.cost_of(tid) + 60:
				builds.build(tid, cid, cell)
		# Upgrade a turret with spare chitin.
		for col in Buildable.COLS:
			var t := builds.turret_at(cid, Vector2i(0, col))
			if t != null and t.upgrade_cost() > 0 and Economy.amount(cid, &"chitin") >= t.upgrade_cost():
				builds.upgrade(cid, Vector2i(0, col))
				break


func _farm() -> void:
	for n: Node in get_tree().get_nodes_in_group("crops"):
		var plot := n as CropPlot
		for k in 2:
			plot.local_interact(false)
	for n: Node in get_tree().get_nodes_in_group("water_sources"):
		(n as WaterSource).local_interact(false)


## Test helper: one of each bug, frozen on the west face (lanes 1-4, 25 m up) for portraits.
func _showcase() -> void:
	var bm := world.get("bugs") as BugManager
	var lane := 1
	if GameState.flag_value("--showcase") == "2":
		for id: StringName in [&"brood_mother", &"spiderling", &"crop_weevil"]:
			bm.spawn_group(id, 1, WorldLayout.WEST, lane, 25.0)
			lane += 1
		var cliffs := world.get("cliffs") as CliffBuilder
		bm.spawn_at(&"burrow_tick", WorldLayout.WEST, 4, 16.0, 0.0, Bug.State.BREACHING, cliffs.plateau_point(WorldLayout.WEST, 3.0, 16.0))
		bm.spawn_at(&"dragonfly_bandit", WorldLayout.WEST, 4, 20.0, 0.0, Bug.State.FLYING, Vector3(-18.0, 30.0, 20.0))
	else:
		for id: StringName in [&"dust_mite", &"wolf_spider", &"rattler_beetle", &"spitter_scorpion"]:
			bm.spawn_group(id, 1, WorldLayout.WEST, lane, 25.0)
			lane += 1
	await get_tree().process_frame
	for b: Node in get_tree().get_nodes_in_group("bugs"):
		(b as Bug).speed_mult = 0.0


## Test helper: a row of turrets on both cliffs (free).
func _autobuild() -> void:
	var builds := world.get("builds") as BuildManager
	if GameState.has_flag("--light"):
		# Realistic start: what the starting scrap buys, then reinvest each build phase.
		for cid in 2:
			for col: int in [6, 13]:
				builds.build(&"gatling_post", cid, Vector2i(0, col))
		GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
			if p == GameState.Phase.BUILD:
				_reinvest(builds))
		return
	for cid in 2:
		Economy.earn(cid, {&"scrap": 1000})
		for col: int in [3, 6, 9, 12, 15]:
			builds.build(&"gatling_post", cid, Vector2i(0, col))
		for col: int in [5, 11]:
			builds.build(&"buffalo_rifle", cid, Vector2i(1, col))
