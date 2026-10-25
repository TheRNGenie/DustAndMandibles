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
	for i in frames:
		await get_tree().process_frame
		if i == 30 and GameState.has_flag("--autoskip"):
			GameState.vote_skip()
		if player != null and GameState.has_flag("--autofire") and i % 40 == 0 and i < frames - 60:
			if player.revolver.trigger(player.camera):
				player.net.fire(player.camera.global_position, -player.camera.global_transform.basis.z)
	var players_root := world.get("players_root") as Node3D
	print("[peer %d] phase %d wave %d, players %d, bugs %d, homesteads %s" % [multiplayer.get_unique_id(),
			GameState.phase, GameState.wave, players_root.get_child_count(),
			(world.get("bugs") as BugManager).alive_count(), str(GameState.homestead_hp)])
	for p: Node in players_root.get_children():
		print("[peer %d]   player %s at %s" % [multiplayer.get_unique_id(), p.name, str((p as Node3D).global_position.snapped(Vector3.ONE * 0.1))])
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved screenshot to ", path)
	get_tree().quit()


## Test helper: a row of turrets on both cliffs (free).
func _autobuild() -> void:
	var builds := world.get("builds") as BuildManager
	for cid in 2:
		Economy.earn(cid, {&"scrap": 1000})
		for col: int in [3, 6, 9, 12, 15]:
			builds.build(&"gatling_post", cid, Vector2i(0, col))
		for col: int in [5, 11]:
			builds.build(&"buffalo_rifle", cid, Vector2i(1, col))
