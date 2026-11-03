extends Node
## Crewed: debug views for the crewed guns (started by DebugTools when
## --crewview=<what> is given with --shot; the screenshot waits as usual).
##   --crewview=<id>          build that crewed gun on your plateau, bugs on the
##                            far cliff (fliers for the Sky Hound), then sit you in it
##   --crewview=outside:<id>  the same gun unmanned, seen from a camera beside it
##   --crewview=lineup        all four side by side, seen from behind
## Options: --crewlook=yaw,pitch (degrees, relative to straight across), --crewaim (aim at the gun's own pick),
##   --crewfire / --crewalt (hold LMB / RMB), --crewcell=row,col,
##   --crewcam=x,y,z (outside camera, in the gun's space), --crewsit=S (seat after S s), --crewleave=S (leave S s later).

var world: Node3D
var _turret: CrewedTurret
var _player: Player
var _cam: Camera3D
var _look := Vector2.ZERO
var _has_look := false
var _seated := false


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	var what := GameState.flag_value("--crewview")
	for i in 25:
		await get_tree().physics_frame
	_player = world.call("local_player") as Player
	for i in 600:
		if _player != null:
			break
		await get_tree().physics_frame # a client's own player arrives a little later
		_player = world.call("local_player") as Player
	var cid := _player.cliff_id if _player != null else WorldLayout.WEST
	var bm := BuildManager.instance
	if multiplayer.is_server():
		for c in 2:
			Economy.earn(c, {&"scrap": 3000})
	if what == "hostprep":
		# Network test, host side: pay for the client's build, give it bugs to shoot,
		# and log what the host sees of every crewed gun.
		for i in 60:
			await get_tree().physics_frame
		_spawn_bugs(&"", WorldLayout.WEST)
		_host_watch = true
		print("[crew host] watching")
		return
	if GameState.flag_value("--crewlook") != "":
		var p := GameState.flag_value("--crewlook").split(",")
		_look = Vector2(p[0].to_float(), p[1].to_float())
		_has_look = true
	var cell := Vector2i(0, 9)
	if GameState.flag_value("--crewcell") != "":
		var c := GameState.flag_value("--crewcell").split(",")
		cell = Vector2i(c[0].to_int(), c[1].to_int())
	if what == "lineup":
		var ids := [&"big_bertha", &"whaler", &"thunder_mule", &"sky_hound"]
		for i in ids.size():
			bm._do_build(1, ids[i], cid, Vector2i(0, 3 + i * 3))
		print("[crew] lineup built: %d crewed guns" % get_tree().get_nodes_in_group("crewed_turrets").size())
		var cliffs := world.get("cliffs") as CliffBuilder
		_cam = Camera3D.new()
		_cam.fov = 55.0
		world.add_child(_cam)
		var at := cliffs.plateau_point(cid, 11.0, 0.0) + Vector3.UP * 4.5
		_cam.global_position = at
		_cam.look_at(cliffs.plateau_point(cid, 2.0, -1.0) + Vector3.UP * 0.8, Vector3.UP)
		_cam.current = true
		_spawn_bugs(&"", cid)
		return
	var outside := what.begins_with("outside:")
	var id := StringName(what.trim_prefix("outside:"))
	if not Defs.is_crewed(id):
		push_error("crewed_views: not a crewed gun: " + what)
		return
	print("[crew] free for %s at %s: %s" % [id, str(cell), bm.is_free_for(id, cid, cell)])
	if multiplayer.is_server():
		bm._do_build(1, id, cid, cell)
		await get_tree().physics_frame
	else:
		await get_tree().create_timer(2.0).timeout # the host hands out the test scrap first
		bm.build(id, cid, cell) # a client asks the host, like the build menu does
		for i in 90:
			await get_tree().physics_frame
	_turret = bm.turret_at(cid, cell, 0) as CrewedTurret
	if _turret == null:
		push_error("crewed_views: the gun didn't go up")
		return
	# The build rules: nothing else on its cells, no scaffold.
	print("[crew] %s up; gatling on its corner allowed: %s, scaffold allowed: %s, plot overlapping: %s" % [id,
			bm.is_free_for(&"gatling_post", cid, cell + Vector2i(1, 1)), bm.is_free_for(&"scaffold", cid, cell + Vector2i(0, 1)),
			bm.is_free_for(&"farm_plot", cid, cell + Vector2i(1, 1))])
	_spawn_bugs(id, cid)
	if outside:
		_cam = Camera3D.new()
		_cam.fov = 50.0
		world.add_child(_cam)
		var off := Vector3(4.5, 3.0, 4.5)
		if GameState.flag_value("--crewcam") != "":
			var o := GameState.flag_value("--crewcam").split(",")
			off = Vector3(o[0].to_float(), o[1].to_float(), o[2].to_float())
		_cam.global_position = _turret.to_global(off)
		_cam.look_at(_turret.to_global(Vector3(0, 1.2, -0.4)), Vector3.UP)
		_cam.current = true
		if _player != null:
			_player.global_position = _turret.global_position + Vector3(0, 0, 14)
		return
	var sit := GameState.flag_value("--crewsit").to_float() if GameState.flag_value("--crewsit") != "" else 1.0
	await get_tree().create_timer(sit).timeout
	if _player != null and is_instance_valid(_turret):
		_turret._take_seat()
		_seated = true
		print("[crew] seated: crewing=%s crew_peer=%d" % [_player.crewing != null, _turret.crew_peer])
		if GameState.flag_value("--crewleave") != "":
			await get_tree().create_timer(GameState.flag_value("--crewleave").to_float()).timeout
			_seated = false
			_turret._leave_seat()
			print("[crew] left the seat: crewing=%s crew_peer=%d at %s" % [_player.crewing != null, _turret.crew_peer, str(_player.global_position.snapped(Vector3.ONE * 0.1))])


func _spawn_bugs(id: StringName, cid: int) -> void:
	if not multiplayer.is_server():
		return
	var bugs := world.get("bugs") as BugManager
	var far := WorldLayout.other_cliff(cid)
	if id == &"sky_hound":
		for lane in 5:
			bugs.spawn_group(&"dragonfly_bandit", 2, far, lane)
		return
	for lane in 5:
		bugs.spawn_group(&"dust_mite", 5, far, lane, 18.0 + lane * 4.0)
	bugs.spawn_group(&"rattler_beetle", 1, far, 2, 30.0)
	bugs.spawn_group(&"brood_mother", 1, far, 1, 22.0)
	bugs.spawn_group(&"wolf_spider", 3, far, 3, 26.0)


var _log_t := 0.0
var _host_watch := false
var _aim_bug: Bug


func _physics_process(delta: float) -> void:
	_log_t += delta
	if _host_watch and _log_t > 1.0:
		_log_t = 0.0
		for n: Node in get_tree().get_nodes_in_group("crewed_turrets"):
			var t := n as CrewedTurret
			print("[crew host] %s on cliff %d: crew %d, shots %d, heat %.2f, aim %s" % [t.def.id, t.cliff_id, t.crew_peer, t.shots, t.heat, str(t.aim_point.snapped(Vector3.ONE * 0.1))])
		return
	if _log_t > 0.5 and is_instance_valid(_turret):
		_log_t = 0.0
		print("[crew] %s: shots %d, heat %.2f, overheated %s, chain %s, reeling %s, crew %d, spin %.2f" % [_turret.def.id, _turret.shots,
				_turret.heat, _turret.overheated, _turret.chain_on, _turret.reeling, _turret.crew_peer, _turret.spin_up])
		if _turret._chain_mi != null and _turret.chain_on:
			print("[crew]   chain visible %s at %s scale %s end %s muzzle %s" % [_turret._chain_mi.visible, str(_turret._chain_mi.global_position.snapped(Vector3.ONE * 0.1)),
					str(_turret._chain_mi.global_basis.get_scale().snapped(Vector3.ONE * 0.1)), str(_turret.chain_end.snapped(Vector3.ONE * 0.1)), str(_turret.muzzle_position().snapped(Vector3.ONE * 0.1))])
	if not _seated or _player == null or not is_instance_valid(_turret):
		return
	if GameState.has_flag("--crewaim"):
		# Point the view at what the gun would pick for itself (the Whaler: the biggest bug).
		if _aim_bug == null or not is_instance_valid(_aim_bug) or not _aim_bug.is_alive():
			_aim_bug = _turret._pick_target()
			if _aim_bug == null and _turret.def.anti_air:
				var best := INF
				for n: Node in get_tree().get_nodes_in_group("bugs"):
					var b := n as Bug
					if b != null and b.is_alive() and b.state == Bug.State.FLYING and b.global_position.distance_to(_turret.global_position) < best:
						best = b.global_position.distance_to(_turret.global_position)
						_aim_bug = b
		if _aim_bug != null:
			var to := _aim_bug.global_position - _player.camera.global_position
			_player.rotation.y = atan2(-to.x, -to.z)
			_player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	elif _has_look:
		_player.rotation.y = _turret.global_rotation.y + deg_to_rad(_look.x)
		_player.head.rotation.x = deg_to_rad(_look.y)
	_turret.debug_fire = GameState.has_flag("--crewfire")
	_turret.debug_alt = GameState.has_flag("--crewalt")

