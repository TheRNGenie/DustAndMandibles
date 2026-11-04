extends Node
## Debug views for the grapple's dynamite (DebugTools starts it on --dynview=<what>;
## --dynamite grants the Powder Satchel itself, --dynamite=all with every mod):
##   --dynview=raised   the launcher out, a bundle raised in the left hand
##   --dynview=strike   the fuse dragged along the match strip (--dynfreeze=0..1
##                      holds the strike there; default 0.62, the catch)
##   --dynview=windup   lit, the arm wound back (freeze 1.5)
##   --dynview=arc      thrown at the far wall; a side camera on the bundle in flight
##   --dynview=wall     bugs climbing the far wall, a bundle thrown into them;
##                      the shot is the blast (--dyncam=side|eye)
##   --dynview=floor    on the canyon floor by a raid site, a bundle thrown at the
##                      sleepers: the shot is them up and coming (logs who woke)
##   --dynview=knock    a bundle at your own feet, seen from outside (with
##                      --thirdperson): the blast's knock and small ragdoll
##   --dynview=shop     buys the Powder Satchel and all three mods at the gunsmith
##                      (logging prices and the code) and shows its Workshop Mods
##                      tab (--dyntab=N for another tab)
##   --dynview=body     (with --thirdperson) your body from the front-left, as
##                      others see it: the bundle up, the fuse lit
##   --dynview=freehands  (with --freehands) a grapple pull across the canyon,
##                      the revolver out and firing mid-pull
## --dynshot=<png> saves the view --dyndelay=S seconds after the moment above
## and quits.

var world: Node3D
var player: Player
var _cam: Camera3D
var _what := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	world = get_tree().current_scene as Node3D
	_what = GameState.flag_value("--dynview")
	var until := Time.get_ticks_msec() + 20000
	while player == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		player = world.call("local_player") as Player
	if player == null:
		push_error("dynamite_views: no player")
		return
	for i in 40:
		await get_tree().physics_frame
	if _what == "shop":
		await _shop()
		return
	if multiplayer.is_server() and (GameState.has_flag("--dynamite") or GameState.flag_value("--dynamite") != "" or _what != ""):
		# --dynamite: the satchel; --dynamite=all: every mod too.
		var all := GameState.flag_value("--dynamite") == "all"
		player.dynamite.grant(1 | (7 << 2) if all else 1)
		print("[dynview] granted the Powder Satchel (code %d)" % player.dynamite.code)
	if _what == "":
		return
	player.grapple.test_mode = true # no captured mouse in automated runs
	await get_tree().physics_frame
	match _what:
		"raised":
			_grapple_out()
			_aim_flat(-6.0)
			player.dynamite.press()
			await _shoot(1.2)
		"strike", "windup":
			_grapple_out()
			_aim_flat(-6.0)
			player.dynamite.freeze = 0.62 if _what == "strike" else 1.5
			if GameState.flag_value("--dynfreeze") != "":
				player.dynamite.freeze = GameState.flag_value("--dynfreeze").to_float()
			if GameState.flag_value("--dyncam") == "close":
				# A close look at the strike from beside the launcher.
				var c := Camera3D.new()
				c.fov = 40.0
				c.near = 0.01
				player.camera.add_child(c)
				c.position = Vector3(-0.05, 0.02, -0.18)
				c.look_at(player.camera.to_global(Vector3(0.12, -0.2, -0.5)), player.camera.global_basis.y)
				c.make_current()
			await _shoot(1.5)
		"arc":
			var t := await _wall_setup(false)
			_grapple_out()
			await _throw_at(t)
			await get_tree().create_timer(DynamiteRules.STRIKE_TIME + DynamiteRules.WINDUP_TIME + 0.55).timeout
			# A camera beside the bundle in flight, looking back along its arc to the thrower.
			Engine.time_scale = 0.02 # hold it in the air for the picture
			for c in world.get_children():
				if c is DynamiteBundle:
					var b := c as DynamiteBundle
					_cam.global_position = b.global_position + Vector3(-2.0, 0.8, 4.5)
					_cam.look_at(b.global_position + Vector3(-1.5, 0.0, 0.0), Vector3.UP)
					print("[dynview] arc: bundle at %s" % str(b.global_position.snapped(Vector3.ONE * 0.1)))
			await _shoot(0.004)
		"wall":
			var t := await _wall_setup(true)
			_grapple_out()
			await _throw_at(t)
			await _wait_blast()
			await _shoot(0.22)
		"floor":
			await _floor()
		"knock":
			_side_cam(player.global_position + Vector3.UP * 2.5, 13.0, 3.0)
			_grapple_out()
			player.head.rotation.x = deg_to_rad(-80.0)
			player.dynamite.press()
			await get_tree().create_timer(DynamiteRules.RAISE_TIME + 0.05).timeout
			player.dynamite.press()
			await _wait_blast()
			await _shoot(0.45)
		"freehands":
			await _free_hands()
		"body":
			# (with --thirdperson) your body as others see it: the bundle up, its fuse lit.
			_grapple_out()
			player.dynamite.press()
			await get_tree().create_timer(0.5).timeout
			player.rig.set_dynamite(2)
			var at := player.global_position + Vector3.UP * 1.5
			_cam = Camera3D.new()
			_cam.fov = 45.0
			world.add_child(_cam)
			_cam.global_position = at - player.global_basis.z * 2.6 - player.global_basis.x * 1.6 + Vector3.UP * 0.3
			_cam.look_at(at, Vector3.UP)
			_cam.make_current()
			await _shoot(0.6)
		_:
			push_error("dynamite_views: unknown view " + _what)


func _grapple_out() -> void:
	player.hotbar_use_grapple()


func _aim_flat(pitch_deg: float) -> void:
	player.head.rotation.x = deg_to_rad(pitch_deg)


## Turn the player (yaw) and head (pitch) to look at `p`.
func _aim_at(p: Vector3) -> void:
	var eye := player.camera.global_position
	var d := p - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _throw_at(p: Vector3) -> void:
	_aim_at(p)
	await get_tree().physics_frame
	player.dynamite.press()
	await get_tree().create_timer(DynamiteRules.RAISE_TIME + 0.1).timeout
	_aim_at(p)
	player.dynamite.press()


func _wait_blast() -> void:
	var fx: Node = null
	var until := Time.get_ticks_msec() + 8000
	while fx == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for c in world.get_children():
			if c is DynamiteBlast:
				fx = c
	print("[dynview] blast seen: %s" % (fx != null))


func _shoot(delay: float) -> void:
	var d := GameState.flag_value("--dyndelay")
	await get_tree().create_timer(d.to_float() if d != "" else delay).timeout
	var path := GameState.flag_value("--dynshot")
	if path == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[dynview] saved %s" % path)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _side_cam(look: Vector3, dist: float, up: float) -> void:
	_cam = Camera3D.new()
	_cam.fov = 60.0
	world.add_child(_cam)
	var side := player.global_basis.x
	_cam.global_position = look + side * dist + Vector3.UP * up - player.global_basis.z * 1.5
	_cam.look_at(look, Vector3.UP)
	_cam.make_current()


## Bugs climbing the far wall straight across from the player on their lip;
## returns where to throw (among them).
func _wall_setup(spawn: bool) -> Vector3:
	var cliffs := world.get("cliffs") as CliffBuilder
	var bugs := world.get("bugs") as BugManager
	var cid := player.cliff_id
	var far := WorldLayout.other_cliff(cid)
	var lane := 2
	var z := WorldLayout.LANE_Z[lane]
	player.global_position = cliffs.plateau_point(cid, 1.2, z) + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	var target := cliffs.face_point(far, WorldLayout.CLIFF_HEIGHT - 12.0, z)
	if spawn:
		bugs.spawn_group(&"wolf_spider", 5, far, lane, WorldLayout.CLIFF_HEIGHT - 22.0)
		bugs.spawn_group(&"dust_mite", 10, far, lane, WorldLayout.CLIFF_HEIGHT - 20.0)
		bugs.spawn_group(&"rattler_beetle", 2, far, lane, WorldLayout.CLIFF_HEIGHT - 21.0)
		await get_tree().create_timer(0.4).timeout
		# Aim at the middle of the pack.
		var sum := Vector3.ZERO
		var n := 0
		for b: Node in get_tree().get_nodes_in_group("bugs"):
			var bug := b as Bug
			if bug != null and bug.cliff_id == far and bug.is_climbing():
				sum += bug.global_position
				n += 1
		if n > 0:
			target = sum / n + Vector3.UP * 3.5 # they'll have climbed on by the time it lands
		print("[dynview] %d bugs on the far wall" % n)
	_aim_at(target)
	if GameState.flag_value("--dyncam") != "eye" and _what != "arc":
		_cam = Camera3D.new()
		_cam.fov = 55.0
		world.add_child(_cam)
		var inward := WorldLayout.inward(far)
		_cam.global_position = target + inward * 30.0 + Vector3.UP * 6.0 + Vector3(0, 0, 12.0)
		_cam.look_at(target, Vector3.UP)
		_cam.make_current()
	elif _what == "arc":
		_cam = Camera3D.new()
		_cam.fov = 62.0
		world.add_child(_cam)
		var mid := player.global_position.lerp(target, 0.5)
		_cam.global_position = mid + Vector3(0, 6.0, 30.0)
		_cam.look_at(mid + Vector3.UP * 4.0, Vector3.UP)
		_cam.make_current()
	return target


func _floor() -> void:
	var mgr := SiteManager.instance
	var until := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until and (mgr == null or mgr.sites.is_empty() or mgr.gen_wave <= 0):
		await get_tree().process_frame
		mgr = SiteManager.instance
	if mgr == null or mgr.sites.is_empty():
		push_error("dynamite_views: no raid sites")
		return
	# The site with the most sleepers.
	var best := mgr.sites[0]
	var most := -1
	for s in mgr.sites:
		var n := 0
		for b in BugManager.instance.site_bugs():
			if b.site == s.index:
				n += 1
		if n > most:
			most = n
			best = s
	var stand := best.at(Vector2(1.5, SitePlan.RADIUS + 16.0))
	stand.y = mgr.ground_at(stand) + 0.2
	player.global_position = stand
	player.velocity = Vector3.ZERO
	var ex := get_node_or_null("/root/Expedition")
	if ex != null and ex.has_method("report_trip"):
		ex.call("report_trip", true)
	await get_tree().physics_frame
	_grapple_out()
	var states := func() -> String:
		var parts: PackedStringArray = []
		for b in BugManager.instance.site_bugs():
			parts.append("%s@%d:%s(%.0fm)" % [b.def.id, b.site, Bug.State.keys()[b.state], b.global_position.distance_to(best.pos)])
		return " ".join(parts)
	print("[dynview] floor: site %d %s, %d sleepers here; before: %s" % [best.index, best.display_name(), most, states.call()])
	_cam = Camera3D.new()
	_cam.fov = 64.0
	world.add_child(_cam)
	_cam.global_position = best.pos.lerp(stand, 0.5) + Vector3.UP * 14.0 + (stand - best.pos).cross(Vector3.UP).normalized() * 14.0
	_cam.look_at(best.pos.lerp(stand, 0.4), Vector3.UP)
	if GameState.flag_value("--dyncam") != "eye":
		_cam.make_current()
	# Thrown short of the site (a nearby blast, not on top of them): the noise does the rest.
	var at := best.pos.lerp(stand, 0.45)
	at.y = mgr.ground_at(at)
	await _throw_at(at)
	await _wait_blast()
	await get_tree().create_timer(0.3).timeout
	var woke := 0
	for b in BugManager.instance.site_bugs():
		if b.state != Bug.State.SLEEPING:
			woke += 1
	print("[dynview] floor: after the blast %d site bugs awake (all sites); %s" % [woke, states.call()])
	print("[dynview] floor: risk clock %.1f s" % float(Expedition.risk(multiplayer.get_unique_id())))
	await _shoot(1.6)


## The gunsmith: the satchel (Upgrades) and the mods (Workshop Mods), bought the real way.
func _shop() -> void:
	var shop := get_tree().root.find_child("GunShop*", true, false) as GunShop
	if shop == null:
		push_error("dynamite_views: no gunsmith")
		return
	var me := multiplayer.get_unique_id()
	Economy.earn(player.cliff_id, {&"chitin": 200})
	var before := Economy.amount(player.cliff_id, &"chitin")
	shop._buy(me, "mod", DynamiteRules.ID, 0) # refused: no satchel yet
	print("[dynview] shop: a mod before the satchel -> code %d, chitin %d" % [int(GunShop.dynamite.get(me, 0)), Economy.amount(player.cliff_id, &"chitin")])
	shop._buy(me, "upgrade", DynamiteRules.ID)
	await get_tree().physics_frame
	print("[dynview] shop: satchel -> code %d, %d bundles, chitin %d -> %d" % [player.dynamite.code, player.dynamite.bundles, before, Economy.amount(player.cliff_id, &"chitin")])
	shop._buy(me, "upgrade", DynamiteRules.ID) # refused: already bought
	for i in 3:
		var c0 := Economy.amount(player.cliff_id, &"chitin")
		shop._buy(me, "mod", DynamiteRules.ID, i)
		await get_tree().physics_frame
		print("[dynview] shop: mod %d (%s) -> code %d, %d chitin" % [i, WeaponMods.list(DynamiteRules.ID)[i]["name"], player.dynamite.code, c0 - Economy.amount(player.cliff_id, &"chitin")])
	print("[dynview] shop: radius %.1f m, damage %.0f, burns %s" % [DynamiteRules.radius_for(player.dynamite.code), DynamiteRules.damage_for(player.dynamite.code), DynamiteRules.burns(player.dynamite.code)])
	if MenuScreen.instance != null:
		MenuScreen.instance.open(shop)
		MenuScreen.instance.tab = int(GameState.flag_value("--dyntab")) if GameState.flag_value("--dyntab") != "" else 2
		MenuScreen.instance.refresh()
	await _shoot(1.0)


## Free Hands: hook the far lip, pull, switch to the revolver half way and fire.
func _free_hands() -> void:
	var cliffs := world.get("cliffs") as CliffBuilder
	var cid := player.cliff_id
	var far := WorldLayout.other_cliff(cid)
	var z := WorldLayout.LANE_Z[2]
	player.global_position = cliffs.plateau_point(cid, 1.2, z) + Vector3.UP * 0.2
	var anchor := cliffs.face_point(far, WorldLayout.CLIFF_HEIGHT - 3.0, z)
	_aim_at(anchor)
	_grapple_out()
	await get_tree().physics_frame
	player.grapple.attach(Grapple.Mode.PULL, anchor)
	await get_tree().create_timer(0.5).timeout
	player.gun.equip(&"revolver")
	print("[dynview] freehands: switched to the revolver mid-pull; grapple still active: %s" % player.grapple.is_active())
	_aim_at(anchor + Vector3(0, -6.0, 6.0))
	for i in 3:
		await get_tree().create_timer(0.22).timeout
		if player.gun.trigger(player.camera):
			player.net.fire(player.camera.global_position, -player.camera.global_transform.basis.z)
	print("[dynview] freehands: fired; grapple still active: %s, %.1f m to the hook" % [player.grapple.is_active(), player.global_position.distance_to(anchor)])
	await _shoot(0.02)
