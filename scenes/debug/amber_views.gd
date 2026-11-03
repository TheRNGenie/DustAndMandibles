extends Node
## Debug views for hive amber (DebugTools starts it on --amberview=<what>):
##   --amberview=kiln|bell|lance   that amber turret built on your lip (crafted
##                                 from a debug blueprint and amber), a wave's worth
##                                 of bugs climbing the far wall in front of it
##                                 (fliers too for the bell); the camera watches the
##                                 wall. --ambercam=turret|wall|close (default wall).
##   --amberview=lineup            all three side by side on your lip (--ambercam=front|back).
##   --amberview=icons             their build-menu icons on one sheet.
##   --amberview=lucky             you on the airship in front of Lucky's stall.
##   --amberview=luckymenu         ...with his shop open (--ambertab=N picks the tab).
##   --amberview=loot              a raid site's amber pickup, close up.
## --ambershot=<png> saves the view after --amberdelay=S seconds (default 6; the
## turret views count from the first shot) and quits, logging what happened.

var world: Node3D
var _turret: AmberTurret
var _first_ms := -1
var _cam: Camera3D
var _what := ""
var _cid := 0


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	_what = GameState.flag_value("--amberview")
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	_cid = player.cliff_id if player != null else WorldLayout.WEST
	for c in WorldLayout.cliff_count():
		Economy.earn(c, {&"scrap": 5000, &"chitin": 200, AmberRules.ITEM: 120})
	for id in AmberRules.IDS:
		Amber.unlock_blueprint(id, false)
	match _what:
		"icons":
			_icons()
		"lineup":
			_lineup(player)
		"lucky", "luckymenu":
			_lucky(player)
		"loot":
			_loot(player)
		"kiln", "bell", "lance":
			_single(player, {"kiln": AmberRules.KILN, "bell": AmberRules.BELL, "lance": AmberRules.LANCE}[_what])
		_:
			push_error("amber_views: unknown view " + _what)


func _camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 58.0
	world.add_child(cam)
	cam.current = true
	return cam


func _delay() -> float:
	return GameState.flag_value("--amberdelay").to_float() if GameState.flag_value("--amberdelay") != "" else 6.0


## Builds an amber turret at `cell` the honest way: crafted item, then placed.
func _build(id: StringName, cell: Vector2i) -> AmberTurret:
	Economy.earn(_cid, {id: 1})
	BuildManager.instance._do_build(1, id, _cid, cell)
	await get_tree().physics_frame
	for n: Node in get_tree().get_nodes_in_group("amber_turrets"):
		if (n as AmberTurret).def.id == id:
			return n as AmberTurret
	return null


func _single(player: Player, id: StringName) -> void:
	var cliffs := world.get("cliffs") as CliffBuilder
	var cell := Vector2i(0, 9)
	_turret = await _build(id, cell)
	if _turret == null:
		push_error("amber_views: %s didn't build" % id)
		get_tree().quit(1)
		return
	# One of each: a second one must be refused.
	Economy.earn(_cid, {id: 1})
	BuildManager.instance._do_build(1, id, _cid, Vector2i(0, 12))
	await get_tree().physics_frame
	print("[amber] one-each: %d %s standing after a second build (want 1)" % [Amber.placed_count(id), id])
	Economy.spend(_cid, {id: 1})
	var at := Buildable.cell_center(cliffs, _cid, cell)
	var inward := WorldLayout.inward(_cid)
	var far := _turret.covers
	var lane := 2
	var best := INF
	for i in WorldLayout.LANE_Z.size():
		if absf(WorldLayout.LANE_Z[i] - at.z) < best:
			best = absf(WorldLayout.LANE_Z[i] - at.z)
			lane = i
	var wall := cliffs.face_point(far, 40.0, WorldLayout.LANE_Z[lane])
	_cam = _camera()
	var side := Vector3.UP.cross(inward).normalized()
	match GameState.flag_value("--ambercam"):
		"turret":
			_cam.global_position = at - inward * 3.2 + side * 3.6 + Vector3.UP * 3.2
			_cam.look_at(at + Vector3.UP * 1.2 + inward * 2.0, Vector3.UP)
		"close":
			_cam.global_position = wall + WorldLayout.inward(far) * 14.0 + Vector3.UP * 2.0 + side * 4.0
			_cam.look_at(wall, Vector3.UP)
		_:
			# From beside the turret over its shoulder, the whole far wall in view.
			_cam.global_position = at - inward * 4.0 + side * 6.0 + Vector3.UP * 6.0
			_cam.look_at(at.lerp(wall, 0.85) + Vector3.DOWN * 4.0, Vector3.UP)
	if player != null:
		player.global_position = at - inward * 18.0
	var bugs := world.get("bugs") as BugManager
	match id:
		AmberRules.KILN:
			bugs.spawn_group(&"dust_mite", 10, far, lane, 36.0)
			bugs.spawn_group(&"wolf_spider", 5, far, lane, 30.0)
			bugs.spawn_group(&"rattler_beetle", 2, far, lane, 26.0)
			bugs.spawn_group(&"dust_mite", 10, far, lane, 18.0)
		AmberRules.BELL:
			bugs.spawn_group(&"dust_mite", 12, far, lane, 34.0)
			bugs.spawn_group(&"wolf_spider", 6, far, lane, 30.0)
			bugs.spawn_group(&"rattler_beetle", 2, far, lane, 28.0)
			_spawn_fliers(bugs, far, 4)
		AmberRules.LANCE:
			for l in [maxi(lane - 1, 0), lane, mini(lane + 1, 4)]:
				bugs.spawn_group(&"dust_mite", 6, far, l, 30.0)
				bugs.spawn_group(&"wolf_spider", 2, far, l, 24.0)
			bugs.spawn_group(&"rattler_beetle", 2, far, lane, 20.0)
	if GameState.has_flag("--amberboss"):
		bugs.spawn_group(&"queen_spider", 1, far, lane, 22.0)


## Dragonfly bandits already in the air over the canyon in front of the turret.
func _spawn_fliers(bugs: BugManager, far: int, n: int) -> void:
	for i in n:
		bugs.spawn_group(&"dragonfly_bandit", 1, far, i % 5, 0.0)


func _physics_process(_delta: float) -> void:
	if _turret == null or not is_instance_valid(_turret):
		return
	var fired := _turret.shots > 0 or _turret.beam_on
	if fired and _first_ms < 0:
		_first_ms = Time.get_ticks_msec()
		print("[amber] %s first fire at t=%.1f" % [_turret.def.id, Time.get_ticks_msec() / 1000.0])
		if GameState.flag_value("--ambershot") != "":
			get_tree().create_timer(_delay()).timeout.connect(_save)


func _save() -> void:
	var path := GameState.flag_value("--ambershot")
	if path == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[amber] saved ", path)
	if _turret != null and is_instance_valid(_turret):
		print("[amber] %s stats %s heat %.1f venting %s" % [_turret.def.id, str(_turret.stats), _turret.heat, _turret.venting])
	print("[amber] bug tallies %s" % str(Bug.amber_stats))
	var bugs := world.get("bugs") as BugManager
	for b: Node in bugs.get_children():
		var bug := b as Bug
		if bug != null and bug.is_alive():
			print("[amber]   %s state %d y=%.1f z=%.1f hp %.0f/%.0f entombed %.1f frenzied %s" % [bug.def.id, bug.state, bug.climb_y, bug.lane_z,
					bug.health.hp, bug.health.max_hp, bug.entombed, bug.status.is_frenzied()])
	if not GameState.has_flag("--amberstay"):
		get_tree().quit()


func _lineup(player: Player) -> void:
	var cliffs := world.get("cliffs") as CliffBuilder
	var cells: Array[Vector2i] = [Vector2i(0, 7), Vector2i(0, 9), Vector2i(0, 11)]
	for i in AmberRules.IDS.size():
		await _build(AmberRules.IDS[i], cells[i])
	var mid := Buildable.cell_center(cliffs, _cid, cells[1])
	var inward := WorldLayout.inward(_cid)
	var along := (Buildable.cell_center(cliffs, _cid, cells[2]) - mid).normalized()
	_cam = _camera()
	if GameState.flag_value("--ambercam") == "back":
		_cam.global_position = mid - inward * 9.0 - along * 2.0 + Vector3.UP * 4.0
	else:
		_cam.global_position = mid + inward * 7.0 + along * 1.5 + Vector3.UP * 2.4
	_cam.look_at(mid + Vector3.UP * 1.4, Vector3.UP)
	if player != null:
		player.global_position = mid - inward * 20.0
	await get_tree().create_timer(_delay()).timeout
	_save()


func _icons() -> void:
	var texs: Array[Texture2D] = []
	for id in AmberRules.IDS:
		texs.append(IconStudio.turret(self, id, Palette.TEAM_WEST))
	texs.append(IconStudio.site_loot(self, &"amber"))
	for i in 10:
		await get_tree().process_frame
	var sheet := Image.create(128 * texs.size(), 128, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.18, 0.13, 0.11))
	for i in texs.size():
		var img := texs[i].get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(128, 128)
		sheet.blend_rect(img, Rect2i(0, 0, 128, 128), Vector2i(128 * i, 0))
	var path := GameState.flag_value("--ambershot")
	if path != "":
		sheet.save_png(path)
		print("[amber] icons saved ", path)
	get_tree().quit()


func _lucky(player: Player) -> void:
	var ship := world.get_node_or_null("Airship") as Node3D
	var stall := ship.get_node_or_null("Lucky") as LuckyStall if ship != null else null
	if stall == null:
		push_error("amber_views: no Lucky stall")
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	print("[amber] Lucky open: %s (wave %d)" % [stall.visible, GameState.wave])
	if player != null:
		player.global_position = stall.to_global(Vector3(0.0, 0.3, -2.4))
		player.velocity = Vector3.ZERO
	_cam = _camera()
	_cam.fov = 62.0
	_cam.global_position = stall.to_global(Vector3(-1.2, 1.75, -4.2))
	_cam.look_at(stall.to_global(Vector3(0.1, 1.35, 0.0)), Vector3.UP)
	await get_tree().create_timer(1.5).timeout
	stall.say(AmberRules.LUCKY_GREETING, 30.0)
	if _what == "luckymenu":
		MenuScreen.instance.open(stall)
		var tab := GameState.flag_value("--ambertab").to_int()
		if tab > 0:
			MenuScreen.instance.tab = tab
			MenuScreen.instance.refresh()
	await get_tree().create_timer(_delay()).timeout
	if GameState.has_flag("--amberbuy"):
		# Buy the Engraved Peacemaker and the supply favour, then log the result.
		Amber.buy(1, "gun:revolver")
		Amber.buy(1, "favour:supply")
		Amber.buy(1, "look:paint:amber")
		await get_tree().create_timer(0.5).timeout
		if player != null:
			print("[amber] revolver code %d lucky %s, damage %.1f" % [player.gun.code_of(&"revolver"), AmberRules.is_lucky(player.gun.code_of(&"revolver")),
					Gun.damage_for(&"revolver", player.gun.code_of(&"revolver"))])
		print("[amber] favours pending %s, amber left %d, owns amber paint %s" % [str(Amber.pending), Economy.amount(_cid, AmberRules.ITEM), Perks.owns_look("paint", "amber")])
		if MenuScreen.instance != null and _what == "luckymenu":
			MenuScreen.instance.refresh()
		await get_tree().create_timer(0.5).timeout
	_save()


func _loot(player: Player) -> void:
	var cliffs := world.get("cliffs") as CliffBuilder
	var pos := cliffs.plateau_point(_cid, 6.0, 0.0) + Vector3.UP * 0.05
	var dummy := SitePlan.Loot.new()
	dummy.items = {AmberRules.ITEM: 3}
	dummy.look = &"amber"
	dummy.label = AmberRules.NAME
	var l := SiteLoot.new()
	l.setup(0, dummy, 3)
	world.add_child(l)
	l.global_position = pos
	_cam = _camera()
	_cam.global_position = pos + Vector3(1.4, 1.1, 1.4)
	_cam.look_at(pos + Vector3.UP * 0.2, Vector3.UP)
	if player != null:
		player.global_position = pos + Vector3(10, 0, 10)
	await get_tree().create_timer(_delay()).timeout
	_save()
