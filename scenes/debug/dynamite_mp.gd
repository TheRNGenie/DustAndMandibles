extends Node
## The grapple's dynamite, two-window network test (DebugTools starts it on
## --dynmp=host|client). Run a host with
##   --debug --direct --host --menu --port=P --dynmp=host
## and a client with
##   --debug --direct --join=127.0.0.1 --port=P --dynmp=client
## Both log "[dynmp <side>]" lines; --dynmpshot=<prefix> saves pictures.
##   host:   hands both riders the Powder Satchel (the client's with every mod),
##           sends a pack up its own wall (the client's far wall), watches the
##           client's body from a camera on their lip: the bundle lit in their
##           hand (<prefix>_host_remote.png), then the blast on its wall
##           (<prefix>_host_blast.png); logs each blast, and being knocked by
##           the client's second bundle (and that it isn't hurt).
##   client: waits for its satchel, throws a bundle into the pack (the host
##           decides the hits), then one at the host's feet across the canyon,
##           and photographs the host's body blown about (<prefix>_client_knock.png);
##           logs its bundle count as the host keeps it.

var world: Node3D
var side := ""
var me: Player
var other: Player
var _cam: Camera3D
var _t0 := 0


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	side = GameState.flag_value("--dynmp")
	_t0 = Time.get_ticks_msec()
	get_tree().create_timer(120.0).timeout.connect(get_tree().quit)
	_run.call_deferred()


func _p(text: String) -> void:
	print("[dynmp %s] t=%.1f %s" % [side, (Time.get_ticks_msec() - _t0) / 1000.0, text])


func _run() -> void:
	var until := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		me = world.call("local_player") as Player
		if me != null and get_tree().get_nodes_in_group("players").size() >= 2:
			break
		await get_tree().process_frame
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n != me:
			other = n as Player
	if me == null or other == null:
		_p("no partner, giving up")
		return
	for i in 60:
		await get_tree().physics_frame
	me.grapple.test_mode = true
	_p("me cliff %d, partner %s cliff %d" % [me.cliff_id, other.display_name(), other.cliff_id])
	if side == "host":
		await _host()
	else:
		await _client()


func _shot(shot_name: String) -> void:
	var prefix := GameState.flag_value("--dynmpshot")
	if prefix == "":
		return
	await RenderingServer.frame_post_draw
	var path := "%s_%s.png" % [prefix, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	_p("saved " + path)


func _stand_on_lip(p: Player, z: float) -> void:
	var cliffs := world.get("cliffs") as CliffBuilder
	p.global_position = cliffs.plateau_point(p.cliff_id, 1.5, z) + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO


func _host() -> void:
	me.dynamite.grant(1)
	other.dynamite.grant(1 | (7 << 2))
	_p("granted: mine %d, the client's %d (host record %s)" % [me.dynamite.code, int(GunShop.dynamite.get(other.get_multiplayer_authority(), 0)), str(GunShop.dynamite)])
	_stand_on_lip(me, 8.0)
	var bugs := world.get("bugs") as BugManager
	bugs.spawn_group(&"dust_mite", 10, me.cliff_id, 2, WorldLayout.CLIFF_HEIGHT - 20.0)
	bugs.spawn_group(&"rattler_beetle", 2, me.cliff_id, 2, WorldLayout.CLIFF_HEIGHT - 21.0)
	bugs.spawn_group(&"wolf_spider", 4, me.cliff_id, 2, WorldLayout.CLIFF_HEIGHT - 22.0)
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		if (n as Bug).site < 0:
			(n as Bug).speed_mult = 0.0 # hold them where the client aims
	# Watch the client's body from beside them on their lip.
	_cam = Camera3D.new()
	_cam.fov = 50.0
	world.add_child(_cam)
	_cam.make_current()
	var seen_lit := false
	var blasts := 0
	var hp0 := float(me.vitals.get("hp"))
	var until := Time.get_ticks_msec() + 70000
	var on_blast := false
	var hp_last := hp0
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var hp_now := float(me.vitals.get("hp"))
		if hp_now != hp_last:
			var near := 0
			for b: Node in get_tree().get_nodes_in_group("bugs"):
				if (b as Node3D).global_position.distance_to(me.global_position) < 4.0:
					near += 1
			_p("hp %.0f -> %.0f (%d bugs within 4 m)" % [hp_last, hp_now, near])
			hp_last = hp_now
		if not on_blast:
			_cam.global_position = other.global_position - other.global_basis.x * 2.4 + Vector3.UP * 1.9 - other.global_basis.z * 2.4
			_cam.look_at(other.global_position + Vector3.UP * 1.5, Vector3.UP)
		if not seen_lit and int(other.rig.get("_dyn_state")) == 2:
			seen_lit = true
			_p("saw the client's bundle lit in their hand")
			await _shot("host_remote")
		for c in world.get_children():
			if c is DynamiteBlast and not c.has_meta(&"seen"):
				c.set_meta(&"seen", true)
				blasts += 1
				var at := (c as Node3D).global_position
				_p("blast %d at %s" % [blasts, str(at.snapped(Vector3.ONE * 0.1))])
				if blasts == 1:
					on_blast = true
					# From over the client's shoulder, the way they saw it go.
					_cam.global_position = other.global_position + Vector3.UP * 2.6 + (other.global_position - at).normalized() * 2.0
					_cam.look_at(at, Vector3.UP)
					await get_tree().create_timer(0.25).timeout
					await _shot("host_blast")
					on_blast = false
				else:
					var p0 := me.global_position
					await get_tree().create_timer(0.3).timeout
					_p("knocked: moved %.1f m in 0.3 s" % me.global_position.distance_to(p0))
					_p("knocked: velocity %s, hp %.0f -> %.0f (never hurt)" % [str(me.velocity.snapped(Vector3.ONE * 0.1)), hp0, float(me.vitals.get("hp"))])
		if blasts >= 2:
			await get_tree().create_timer(2.0).timeout
			_p("client's bundles by the host's count: %d" % other.dynamite.host_bundles)
			break
	_p("done")
	get_tree().quit()


func _client() -> void:
	var until := Time.get_ticks_msec() + 30000
	while not DynamiteRules.unlocked(me.dynamite.code) and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_p("my satchel arrived: code %d, %d bundles" % [me.dynamite.code, me.dynamite.bundles])
	_stand_on_lip(me, 8.0)
	await get_tree().create_timer(1.0).timeout
	me.hotbar_use_grapple()
	# 1: into the pack on the far wall (the host's cliff).
	var cliffs := world.get("cliffs") as CliffBuilder
	var target := cliffs.face_point(other.cliff_id, WorldLayout.CLIFF_HEIGHT - 19.0, WorldLayout.LANE_Z[2])
	_p("throwing into the pack at %s" % str(target.snapped(Vector3.ONE * 0.1)))
	await _throw_at(target)
	await get_tree().create_timer(4.0).timeout
	_p("bundles after one throw: %d" % me.dynamite.bundles)
	# 2: at the host's feet, across the canyon; watch their body from near them.
	var host_at := other.global_position + Vector3(0, 0.2, 2.0)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	world.add_child(_cam)
	var old_fx: Array = []
	for c in world.get_children():
		if c is DynamiteBlast:
			old_fx.append(c) # the first blast's smoke is still hanging
	await _throw_at(host_at)
	_cam.global_position = other.global_position + Vector3(0, 3.0, 12.0)
	_cam.look_at(other.global_position + Vector3.UP * 1.5, Vector3.UP)
	_cam.make_current()
	var t := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame
		var fx := false
		for c in world.get_children():
			if c is DynamiteBlast and not old_fx.has(c):
				fx = true
		if fx:
			var p0 := other.global_position
			for k in 4:
				await get_tree().create_timer(0.1).timeout
				_p("the host's body %.1f m from where it stood, rig tumble %.2f s left" % [other.global_position.distance_to(p0), float(other.rig.get("_tumble_t"))])
				if k == 1:
					_cam.look_at(other.global_position + Vector3.UP * 1.0, Vector3.UP)
					await _shot("client_knock")
			_p("saw the host blown about at %s" % str(other.global_position.snapped(Vector3.ONE * 0.1)))
			break
	await get_tree().create_timer(3.0).timeout
	_p("bundles at the end: %d" % me.dynamite.bundles)
	_p("done")


func _throw_at(p: Vector3) -> void:
	_aim(p)
	me.dynamite.press()
	await get_tree().create_timer(DynamiteRules.RAISE_TIME + 0.1).timeout
	_aim(p)
	me.dynamite.press()
	await get_tree().create_timer(DynamiteRules.STRIKE_TIME + DynamiteRules.WINDUP_TIME + 0.1).timeout


func _aim(p: Vector3) -> void:
	var eye := me.camera.global_position
	var d := p - eye
	me.rotation.y = atan2(-d.x, -d.z)
	me.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
