extends Node
## Debug views of the bosses (added by BossFx when --bossview=<id> is given):
## spawns the boss on the east wall (or in the air / on the plateau, whichever
## suits it), frames it with a camera and saves screenshots, then quits.
##   godot --path . -- --debug --bossview=queen_spider --bossshot=C:/tmp/q.png --bossat=2,4
## --bossy=Y      climb height (default 32)
## --bosscam=K    near (default), far (from the west lip, like a player), top (from its own lip)
## --bossgo       let it move (otherwise it holds still)
## --bossturrets  builds turrets on the west lip for it to fight
## --bosshud      keep the HUD (boss bar) in the shot
## --bosshits     logs turret shots, boss HP and aim errors every second
## --bossfast     shortens its ability timers so the telegraph shows in the first seconds
## --bossground   stands it on the east plateau instead of the wall (model close-ups)
## --bosscam=front  a three-quarter view of its face (with --bossground: a portrait)

var world: Node
var _cam: Camera3D
var _t := 0.0
var _shots: Array[float] = []
var _taken := 0
var _bug: Bug
var _id: StringName


func _ready() -> void:
	_id = StringName(GameState.flag_value("--bossview"))
	var at := GameState.flag_value("--bossat")
	for s in (at if at != "" else "3").split(","):
		_shots.append(s.to_float())
	await get_tree().process_frame
	await get_tree().process_frame
	world = get_tree().current_scene
	if not GameState.has_flag("--bosshud"):
		var hud := world.get("hud") as CanvasLayer
		if hud != null:
			hud.visible = false
	if DayCycle.instance != null:
		DayCycle.instance.clock = 15.0
		DayCycle.instance.set("_target", 15.0)
		DayCycle.instance.set("_rate", 0.0)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 900.0
	world.add_child(_cam)
	_cam.current = true
	if GameState.has_flag("--bossturrets"):
		var builds := world.get("builds") as BuildManager
		Economy.earn(WorldLayout.WEST, {&"scrap": 5000})
		var ids: Array[StringName] = [&"gatling_post", &"buffalo_rifle", &"water_cannon", &"dynamite_lobber", &"dynamite_lobber", &"duck_gun", &"sky_sweeper"]
		var k := 0
		for col: int in [6, 8, 10, 12, 14, 16, 18]:
			builds.restore_built(ids[k % ids.size()], WorldLayout.WEST, Vector2i(0, col), 0, "Debug")
			k += 1
	var bm := world.get("bugs") as BugManager
	var y := float(GameState.flag_value("--bossy")) if GameState.flag_value("--bossy") != "" else 32.0
	var cl := Bug.cliffs
	match _id:
		&"locust_lord":
			var p := (cl.plateau_point(WorldLayout.WEST, 0.0, 0.0) + cl.plateau_point(WorldLayout.EAST, 0.0, 0.0)) * 0.5 + Vector3.UP * 7.0
			bm.spawn_at(_id, WorldLayout.EAST, 2, 0.0, 0.0, Bug.State.FLYING, p)
		&"burrow_beetle":
			bm.spawn_at(_id, WorldLayout.EAST, 2, 0.0, 0.0, Bug.State.BREACHING, cl.plateau_point(WorldLayout.EAST, 6.0, 0.0))
		_ when GameState.has_flag("--bossground"):
			bm.spawn_at(_id, WorldLayout.EAST, 2, 0.0, 0.0, Bug.State.BREACHING, cl.plateau_point(WorldLayout.EAST, 9.0, 0.0))
		_:
			bm.spawn_at(_id, WorldLayout.EAST, 2, 0.0, y, Bug.State.CLIMBING, Vector3.ZERO)
	await get_tree().process_frame
	for b: Node in get_tree().get_nodes_in_group("bugs"):
		if (b as Bug).def.id == _id:
			_bug = b as Bug
	if _bug == null:
		push_error("boss_views: no boss " + _id)
		return
	if not GameState.has_flag("--bossgo"):
		_bug.speed_mult = 0.0
		if _id == &"burrow_beetle" and _bug.boss != null:
			# Hold it up on the surface for the picture.
			_bug.boss.set("_phase", &"up")
			_bug.boss.set("_t", 999.0)
			_bug.state = Bug.State.BREACHING
	if GameState.has_flag("--bossfast") and _bug.boss != null:
		for v: String in ["_cd"]:
			if _bug.boss.get(v) != null:
				_bug.boss.set(v, 0.5)
	print("[bossview] %s spawned, %d HP, %d turrets" % [_id, int(_bug.health.max_hp), get_tree().get_nodes_in_group("turrets").size()])


var _hits_t := 0.0


## --bosshits: once a second, how the turrets are doing against the boss
## (shots fired, boss HP, and per turret: target, aim error, pitch wanted vs limit).
func _log_hits() -> void:
	var shots := 0
	var parts: PackedStringArray = []
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		shots += t.shots
		var tgt: Variant = t.get("_target")
		var err: float = t.call("_aim_error_deg")
		var bd := Vector3.ZERO
		var why := ""
		if _bug != null and is_instance_valid(_bug):
			var muzzle: Vector3 = (t.get("_head") as Node3D).global_position
			bd = _bug.global_position - muzzle
			var q := PhysicsRayQueryParameters3D.create(muzzle, _bug.global_position, WorldLayout.LAYER_WORLD)
			var hit := t.get_world_3d().direct_space_state.intersect_ray(q)
			var blocked := not hit.is_empty()
			if blocked and parts.is_empty():
				print("   ray from %s blocked by %s at %s (boss at %s)" % [str(muzzle.snapped(Vector3.ONE * 0.1)), str(hit["collider"].get_path()) if hit["collider"] is Node else "?",
						str((hit["position"] as Vector3).snapped(Vector3.ONE * 0.1)), str(_bug.global_position.snapped(Vector3.ONE * 0.1))])
			why = "%s%s r%.0f/%.0f" % ["V" if bool(t.call("_valid", _bug)) else "x", "B" if blocked else "", bd.length(), t.def.range * t.range_multiplier()]
		var bp := rad_to_deg(atan2(bd.y, Vector2(bd.x, bd.z).length()))
		parts.append("%s:%s %s err%.0f body%.0f/-%.0f" % [String(t.def.id).left(6), "T" if tgt != null else "-", why, err, bp, t.pitch_limit()])
	print("[bosshits] t=%.0f shots %d hp %.0f y %.1f  %s" % [_t, shots, _bug.health.hp if _bug != null and is_instance_valid(_bug) else -1.0,
			_bug.climb_y if _bug != null and is_instance_valid(_bug) else -1.0, " ".join(parts)])


func _process(delta: float) -> void:
	if world == null or _cam == null:
		return
	_t += delta
	if GameState.has_flag("--bosshits"):
		_hits_t += delta
		if _hits_t >= 1.0:
			_hits_t = 0.0
			_log_hits()
	_cam.current = true
	if _bug != null and is_instance_valid(_bug):
		_frame()
	if _taken < _shots.size() and _t >= _shots[_taken]:
		var path := GameState.flag_value("--bossshot")
		if path != "":
			if _shots.size() > 1:
				path = path.get_basename() + "_%d.png" % _taken
			get_viewport().get_texture().get_image().save_png(path)
			var status := _bug.boss.hud_status() if _bug != null and is_instance_valid(_bug) and _bug.boss != null else "-"
			print("[bossview] saved ", path, " at t=%.1f fps %d status '%s'" % [_t, Engine.get_frames_per_second(), status])
		_taken += 1
		if _taken >= _shots.size():
			get_tree().quit()


func _frame() -> void:
	var p := _bug.global_position
	var r := float(_bug.spec["body_radius"]) + float(_bug.spec["upper"])
	var out := _bug.global_basis.y.normalized()
	match GameState.flag_value("--bosscam"):
		"far":
			var eye := Bug.cliffs.plateau_point(WorldLayout.WEST, 1.0, 6.0) + Vector3.UP * 1.7
			_look(eye, p)
		"turrets":
			# Watch the turret the boss picked on (a cocoon, acid or stars on it), else the line.
			var focus := Bug.cliffs.plateau_point(WorldLayout.WEST, 0.0, 12.0) + Vector3.UP * 1.0
			for n: Node in get_tree().get_nodes_in_group("turrets"):
				for c: Node in n.get_children():
					if String(c.name).begins_with("Boss_"):
						focus = (n as Node3D).global_position + Vector3.UP
			_look(focus + Vector3(7.0, 4.5, -6.0), focus)
		"top":
			var eye := Bug.cliffs.plateau_point(_bug.cliff_id, 0.5, p.z + 3.0) + Vector3.UP * 1.7
			_look(eye, p)
		"front":
			var fwd := -_bug.global_basis.z.normalized()
			var side := _bug.global_basis.x.normalized()
			var up := _bug.global_basis.y.normalized()
			var k := float(GameState.flag_value("--bossdist")) if GameState.flag_value("--bossdist") != "" else 1.0
			var aim := p + fwd * r * 0.35 + up * r * 0.35
			_look(aim + (fwd * r * 2.6 + side * r * 1.7 + up * r * 1.1) * k, aim)
		_:
			if _bug.state == Bug.State.FLYING:
				_look(p + Vector3(-11.0, 2.5, 0.0), p)
			elif _bug.state == Bug.State.BREACHING or _bug.state == Bug.State.BURROWED:
				_look(p + Vector3(-10.0, 5.0, 8.0), p)
			else:
				_look(p + out * (6.0 + r * 3.0) + Vector3(0, 1.5, 5.0 + r), p)


func _look(eye: Vector3, target: Vector3) -> void:
	_cam.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
