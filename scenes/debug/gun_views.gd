extends Node
## Debug views for the eight frontier guns (gen/frontier_guns.gd). Started by
## DebugTools when --gunview=<what> is given:
##   --gunview=lineup     all eight floating side by side in daylight
##                        (pistols on the right, drawn 1.6x so they read)
##   --gunview=<id>       that gun in your hands doing its thing (bugs placed
##                        for it), e.g. --gunview=flare_gun
##   --gunview=harpoon_pull   the harpoon fired into the far wall: you fly
## --gunshot=<png> saves the view --gundelay=S seconds after the first shot
## (default 0.4; lineup: after a moment) and quits. Logs what the special did.

var world: Node3D
var player: Player
var bugs: BugManager
var cliffs: CliffBuilder
var _what := ""
var _fired := 0
var _target: Bug


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	_what = GameState.flag_value("--gunview")
	for i in 40:
		await get_tree().physics_frame
	player = world.call("local_player") as Player
	bugs = world.get("bugs") as BugManager
	cliffs = world.get("cliffs") as CliffBuilder
	if _what == "lineup":
		_lineup()
		return
	var id := StringName(_what)
	if _what == "harpoon_pull":
		id = &"harpoon_pistol"
	if not FrontierGuns.has(id):
		push_error("gun_views: unknown view " + _what)
		return
	player.gun.grant(id, 0)
	player.gun.equip(id)
	await get_tree().create_timer(0.6).timeout
	await _stage(id)


# ------------------------------------------------------------------ lineup

func _lineup() -> void:
	var hud: Variant = world.get("hud")
	if hud != null:
		hud.set("visible", false)
	var cam := Camera3D.new()
	cam.fov = 34.0
	world.add_child(cam)
	cam.current = true
	var at := cliffs.plateau_point(player.cliff_id, 14.0, 0.0) + Vector3.UP * 18.0
	var fwd := WorldLayout.inward(player.cliff_id) # look out over the canyon
	var right := fwd.cross(Vector3.UP).normalized()
	cam.global_position = at
	cam.look_at(at + fwd + Vector3.UP * 0.12, Vector3.UP)
	var longs: Array[StringName] = [&"telescope_rifle", &"salt_shotgun", &"punt_gun", &"bee_smoker"]
	var shorts: Array[StringName] = [&"derringer_pair", &"pepperbox", &"harpoon_pistol", &"flare_gun"]
	var dist := 3.1
	for i in 4:
		var y := 1.08 - i * 0.42
		_place(longs[i], at + fwd * dist + right * -0.42 + Vector3.UP * y, fwd, 1.0)
		_place(shorts[i], at + fwd * dist + right * 0.62 + Vector3.UP * y, fwd, 1.6)
	if player != null:
		player.global_position = cliffs.plateau_point(player.cliff_id, 25.0, 0.0)
	await get_tree().create_timer(1.5).timeout
	_save()


## A whole gun at `p`, barrel pointing left across the view, a touch toward you.
func _place(id: StringName, p: Vector3, fwd: Vector3, scale: float) -> void:
	var n := FrontierGuns.whole(id, true)
	world.add_child(n)
	var right := fwd.cross(Vector3.UP).normalized()
	# Gun -Z (barrel) to screen left (-right); its +X (right side) toward the camera.
	var b := Basis(-fwd, Vector3.UP, right).rotated(Vector3.UP, deg_to_rad(-12.0))
	n.global_transform = Transform3D(b.scaled(Vector3.ONE * scale), p)
	var aabb := AABB()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge(mi.mesh.get_aabb())
	n.global_position = p - b * (aabb.get_center() * scale)


# ------------------------------------------------------------------ in action

func _stage(id: StringName) -> void:
	var cid := player.cliff_id
	var far := WorldLayout.other_cliff(cid)
	var lip := cliffs.plateau_point(cid, 2.5, 0.0)
	var inward := WorldLayout.inward(cid)
	player.global_position = lip
	match _what:
		"derringer_pair", "punt_gun":
			# A pack that made it over the lip, right on top of you.
			for i in (1 if id == &"derringer_pair" else 6):
				var z := -1.5 + i * 0.7
				var pos := cliffs.plateau_point(cid, 5.0 + (i % 2) * 1.5, z)
				var kind := &"wolf_spider" if id == &"derringer_pair" else &"dust_mite"
				bugs.spawn_at(kind, cid, 2, z, 0.0, Bug.State.BREACHING, pos)
			player.global_position = cliffs.plateau_point(cid, 9.5, 0.0)
		"bee_smoker":
			for i in 3:
				var pos := cliffs.plateau_point(cid, 8.0, -1.5 + i * 1.5) + Vector3.UP * 3.5
				bugs.spawn_at(&"dragonfly_bandit", cid, 2, 0.0, 0.0, Bug.State.FLYING, pos)
			player.global_position = cliffs.plateau_point(cid, 13.0, 0.0)
		"harpoon_pull":
			# A beetle too heavy to reel in: the line drags YOU to it.
			bugs.spawn_at(&"rattler_beetle", cid, 2, 12.0, 0.0, Bug.State.BREACHING, cliffs.plateau_point(cid, 5.0, 12.0))
			player.global_position = cliffs.plateau_point(cid, 24.0, 12.0)
			player.grapple.test_mode = true # no captured mouse in a debug launch
		"pepperbox", "harpoon_pistol":
			# Point blank on your own plateau (the pepperbox's job), or a spider
			# across the yard for the harpoon to reel in.
			var n := 5 if id == &"pepperbox" else 1
			for i in n:
				var z := -1.2 + i * 0.6 if id == &"pepperbox" else 12.0
				var d := 9.0 + (i % 2) * 1.0 if id == &"pepperbox" else 5.0
				bugs.spawn_at(&"dust_mite" if id == &"pepperbox" else &"wolf_spider", cid, 2, z, 0.0, Bug.State.BREACHING, cliffs.plateau_point(cid, d, z))
			player.global_position = cliffs.plateau_point(cid, 15.0 if id == &"pepperbox" else 19.0, 0.0 if id == &"pepperbox" else 12.0)
		_:
			# Climbers near the top of the far wall, across the canyon from you.
			for i in 5:
				bugs.spawn_at(&"dust_mite" if i % 3 != 2 else &"wolf_spider", far, 2, -1.6 + i * 0.8, 50.0 + (i % 3) * 1.4, Bug.State.CLIMBING, Vector3.ZERO)
			bugs.spawn_at(&"rattler_beetle", far, 2, 3.5, 48.0, Bug.State.CLIMBING, Vector3.ZERO)
			player.global_position = cliffs.plateau_point(cid, 1.2, 0.0)
	if id == &"flare_gun":
		# Turrets on your lip, so the mark has someone to call.
		var bm := BuildManager.instance
		Economy.earn(cid, {&"scrap": 5000})
		for k in 3:
			bm._do_build(1, &"gatling_post", cid, Vector2i(0, 7 + k * 2))
	for i in 30:
		await get_tree().physics_frame
	for b: Node in bugs.get_children():
		if b is Bug:
			if id != &"bee_smoker":
				(b as Bug).status.slow(0.08, 60.0) # crawling, so the shot catches them where we put them
	_target = _pick_target(id)
	var aim := _target.global_position if _target != null else cliffs.face_point(far, 30.0, 0.0)
	_aim_at(aim + Vector3.UP * 0.35)
	await get_tree().physics_frame
	var before := _snapshot()
	var pos0 := player.global_position
	if id == &"telescope_rifle" or id == &"salt_shotgun":
		player.gun.aiming = true
		await get_tree().create_timer(0.5).timeout
		if _target != null:
			_aim_at(_target.to_global((_target.get_node("Hitbox") as Hitbox).weak_center))
	var shots := {&"derringer_pair": 4, &"pepperbox": 6, &"salt_shotgun": 2, &"bee_smoker": 20}.get(id, 1) as int
	for s in shots:
		if _target != null and is_instance_valid(_target) and id != &"bee_smoker" and id != &"telescope_rifle":
			_aim_at(_target.global_position + Vector3.UP * 0.35)
		player.gun.trigger_held = true
		player.gun.spin = 1.0
		player.gun.set("_cooldown", 0.0)
		var probe := player.gun.raycast(player.camera.global_position, -player.camera.global_transform.basis.z, [player.get_rid()], 600.0)
		if not probe.is_empty():
			print("[gunview]   aim ray hits %s at %.1f m" % [probe["collider"], player.camera.global_position.distance_to(probe["position"])])
		var from := player.camera.global_position
		var dir := -player.camera.global_transform.basis.z
		if player.gun.trigger(player.camera):
			player.net.fire(from, dir)
			player.kick_back(player.gun.def.kickback)
			_fired += 1
		await get_tree().create_timer(0.1 if id != &"salt_shotgun" else 0.8).timeout
	if GameState.flag_value("--guncam") == "near" and _target != null and is_instance_valid(_target):
		# --guncam=near: watch it land from a few metres off the target.
		var t := _target.global_position
		var back := (player.global_position - t)
		back.y = 0.0
		back = back.normalized()
		var cam := Camera3D.new()
		cam.fov = 55.0
		world.add_child(cam)
		cam.current = true
		cam.global_position = t + back * 9.0 + back.cross(Vector3.UP) * 4.0 + Vector3.UP * 3.0
		cam.look_at(t + Vector3.DOWN * 1.5, Vector3.UP)
	var delay := GameState.flag_value("--gundelay").to_float() if GameState.flag_value("--gundelay") != "" else 0.4
	await get_tree().create_timer(delay).timeout
	_report(id, before, pos0)
	_save()


func _pick_target(id: StringName) -> Bug:
	var best: Bug = null
	for b: Node in bugs.get_children():
		var bug := b as Bug
		if bug == null or not bug.is_alive():
			continue
		if (id == &"flare_gun" or id == &"telescope_rifle") and bug.def.id != &"rattler_beetle":
			continue
		if best == null or bug.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
			best = bug
	return best


## Turn the player (body yaw, head pitch) to look at `p`.
func _aim_at(p: Vector3) -> void:
	var eye := player.camera.global_position
	var to := p - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _snapshot() -> Dictionary:
	var out := {}
	for b: Node in bugs.get_children():
		var bug := b as Bug
		if bug != null:
			out[bug] = {"y": bug.climb_y, "pos": bug.global_position, "hp": bug.health.hp, "state": bug.state}
	return out


func _report(id: StringName, before: Dictionary, pos0: Vector3) -> void:
	print("[gunview] %s fired %d, ammo left %d" % [id, _fired, player.gun.ammo])
	for key: Variant in before:
		if not is_instance_valid(key):
			print("[gunview]   (a bug died)")
			continue
		var bug := key as Bug
		var was: Dictionary = before[key]
		print("[gunview]   %s state %d->%d climb %.1f->%.1f moved %.1f m hp %.0f->%.0f speed x%.2f marked %s drowsy %s" % [
				bug.def.id, int(was["state"]), bug.state, float(was["y"]), bug.climb_y,
				(was["pos"] as Vector3).distance_to(bug.global_position), float(was["hp"]), bug.health.hp,
				bug.status.speed_multiplier(), bug.status.is_marked(), bug.status.is_drowsy()])
	print("[gunview]   player moved %.2f m (velocity %s), grapple %s" % [pos0.distance_to(player.global_position),
			str(player.velocity.snapped(Vector3.ONE * 0.1)), str(player.grapple.mode)])
	if id == &"flare_gun":
		for n: Node in get_tree().get_nodes_in_group("turrets"):
			var t := n as Turret
			if t != null:
				var tg: Bug = t.get("_target")
				print("[gunview]   turret %s targets %s" % [t.def.id, tg.def.id if tg != null and is_instance_valid(tg) else "-"])


func _save() -> void:
	var path := GameState.flag_value("--gunshot")
	if path == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[gunview] saved ", path)
	get_tree().quit()
