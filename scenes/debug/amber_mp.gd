extends Node
## Hive amber, two-window network test (DebugTools starts it on --ambermp=host|client).
## Run a host with --ambermp=host and a client with --ambermp=client (both
## --debug --direct --alltiers --lucky); each logs "[ambermp <side>]" lines.
##   host:   gives the two cliffs different amber (personal piles), Amber.grant_all(6),
##           teaches the team the Queen's Bell (story API), turns on both workshops,
##           crafts and places a Bell on its own lip, then later tries a Kiln of its
##           own (refused while the client's stands or waits in a stockpile), and
##           sends bugs (climbers and fliers) up both walls.
##   client: buys from Lucky (Peacemaker finish, Amber Lacquer, two blueprints, a
##           favour) through the stall, crafts a Kiln and a Lance at its own
##           Workshop, places them, tries a Bell (refused: one each), picks the
##           Kiln up and puts it back, and photographs what it sees of each
##           turret's effect (--ambershot=<prefix>: <prefix>_kiln.png, _lance.png, _bell.png).
## Both log their view of amber, blueprints, turrets, statues, frenzy marks and the beam.

var world: Node3D
var side := ""
var me: Player
var cid := 0
var partner := 1
var _t0 := 0
var _log_t := 0.0
var _shots: Dictionary = {}
var _cam: Camera3D
var _busy := false


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	side = GameState.flag_value("--ambermp")
	_t0 = Time.get_ticks_msec()
	var quit_after := GameState.flag_value("--ambermpquit").to_float() if GameState.flag_value("--ambermpquit") != "" else 170.0
	get_tree().create_timer(quit_after).timeout.connect(get_tree().quit)
	Economy.notice.connect(func(text: String) -> void: _p("notice: " + text))
	var until := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		me = world.call("local_player") as Player
		if me != null and (side != "host" or NetworkManager.players.size() >= 2) and get_tree().get_nodes_in_group("players").size() >= 2:
			break
		await get_tree().physics_frame
	if me == null:
		_p("FAIL no local player")
		return
	cid = me.cliff_id
	partner = WorldLayout.other_cliff(cid)
	_p("ready: my peer %d cliff %d, players %s" % [multiplayer.get_unique_id(), cid, str(NetworkManager.players.keys())])
	for i in 60:
		await get_tree().physics_frame
	if side == "host":
		_host()
	elif side == "client":
		_client()
	# "watch": only log (e.g. the ch7 strongroom with --story=7 / --ch7view=strongroom)


func _p(s: String) -> void:
	print("[ambermp %s t=%.1f] %s" % [side, (Time.get_ticks_msec() - _t0) / 1000.0, s])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _peer_cliff(peer: int) -> int:
	return NetworkManager.cliff_of(peer)


# ------------------------------------------------------------------ host

func _host() -> void:
	var client_peer := 0
	for pid: int in NetworkManager.players:
		if pid != multiplayer.get_unique_id():
			client_peer = pid
	var ccid := _peer_cliff(client_peer)
	_p("client peer %d on cliff %d" % [client_peer, ccid])
	# Personal piles: different amounts on each cliff.
	Economy.earn(cid, {AmberRules.ITEM: 40, &"scrap": 3000, &"chitin": 100})
	Economy.earn(ccid, {AmberRules.ITEM: 124, &"chitin": 100})
	await _wait(1.0)
	Amber.grant_all(6, "a test grant")
	await _wait(0.5)
	_p("after grant_all: amber host cliff %d = %d, client cliff %d = %d (want 46 / 130)" % [cid, Economy.amount(cid, AmberRules.ITEM), ccid, Economy.amount(ccid, AmberRules.ITEM)])
	# Both workshops up (synced like the ledger's upgrade), parts for the client's two turrets
	# and the host's bell, and a spare kiln's worth for the host's one-each test.
	for c in [cid, ccid]:
		var home := Homestead.of(c)
		home._set_state.rpc(home.floors, home.boarded, home.reinforced, home.tower, true, home.porch)
	Economy.earn(ccid, {&"part_tripod": 2, &"part_cannon": 1, &"part_fire": 1, &"part_rifle": 1, &"part_acid": 1,
			&"part_post": 1, &"part_nozzle": 1, &"part_explosive": 1})
	Economy.earn(cid, {&"part_post": 1, &"part_nozzle": 1, &"part_explosive": 1, &"part_tripod": 1, &"part_cannon": 1, &"part_fire": 1})
	await _wait(1.0)
	Story.unlock_amber_blueprint(AmberRules.BELL)
	await _wait(1.0)
	var ws := Homestead.of(cid).get_node_or_null("Workshop") as Workshop
	ws._craft(multiplayer.get_unique_id(), AmberRules.BELL)
	BuildManager.instance.build(AmberRules.BELL, cid, Vector2i(0, 9))
	await _wait(1.0)
	_p("host bell placed: %d, amber host %d" % [Amber.placed_count(AmberRules.BELL), Economy.amount(cid, AmberRules.ITEM)])
	# Wait for the client's kiln (or 60 s), then try one of our own.
	var until := Time.get_ticks_msec() + 60000
	while Amber.placed_count(AmberRules.KILN) == 0 and Time.get_ticks_msec() < until:
		await _wait(0.5)
	await _wait(1.0)
	ws._craft(multiplayer.get_unique_id(), AmberRules.KILN)
	_p("host kiln craft while client's stands: host holds %d kilns (want 0), block '%s'" % [Economy.amount(cid, AmberRules.KILN), Amber.craft_block(AmberRules.KILN)])
	Economy.earn(cid, {AmberRules.KILN: 1})
	BuildManager.instance.build(AmberRules.KILN, cid, Vector2i(0, 12))
	await _wait(0.5)
	_p("host kiln place while client's stands: %d kilns standing (want 1), host still holds %d" % [Amber.placed_count(AmberRules.KILN), Economy.amount(cid, AmberRules.KILN)])
	Economy.spend(cid, {AmberRules.KILN: Economy.amount(cid, AmberRules.KILN)})
	# Bugs up both walls, a few rounds.
	var bugs := world.get("bugs") as BugManager
	for round in 6:
		for wall in [cid, ccid]:
			bugs.spawn_group(&"wolf_spider", 3, wall, 2, 18.0)
			bugs.spawn_group(&"dust_mite", 5, wall, 1, 14.0)
			bugs.spawn_group(&"rattler_beetle", 1, wall, 3, 12.0)
		for i in 2:
			bugs.spawn_group(&"dragonfly_bandit", 1, ccid, i + 1, 0.0)
		_p("round %d of bugs sent" % round)
		await _wait(12.0)
	await _wait(30.0)
	_final()


# ------------------------------------------------------------------ client

func _client() -> void:
	var stall := world.get_node_or_null("Airship/Lucky") as LuckyStall
	_p("lucky stall %s visible %s" % [stall != null, stall.visible if stall != null else false])
	var until := Time.get_ticks_msec() + 30000
	while Economy.amount(cid, AmberRules.ITEM) < 130 and Time.get_ticks_msec() < until:
		await _wait(0.25)
	await _wait(0.5)
	_p("my amber %d, partner cliff amber %d, HUD says '%s' (row shown %s)" % [Economy.amount(cid, AmberRules.ITEM), Economy.amount(partner, AmberRules.ITEM), _hud_amber(), _hud_amber_shown()])
	# Lucky: through the stall, like pressing Deal.
	var before := Economy.amount(cid, AmberRules.ITEM)
	for sid in ["gun:revolver", "look:paint:amber", "blueprint:amber_kiln", "blueprint:mandible_lance", "favour:supply"]:
		stall.menu_press(sid, &"buy")
		await _wait(0.6)
	await _wait(1.0)
	_p("after Lucky: amber %d -> %d (want %d), revolver code %d lucky %s, owns amber paint %s, unlocked %s" % [before, Economy.amount(cid, AmberRules.ITEM),
			before - 6 - 5 - 30 - 40 - 4, me.gun.code_of(&"revolver"), AmberRules.is_lucky(me.gun.code_of(&"revolver")), Perks.owns_look("paint", "amber"), str(Amber.unlocked)])
	# The blueprint again: the host refuses (already known), no charge.
	var b2 := Economy.amount(cid, AmberRules.ITEM)
	stall.menu_press("blueprint:amber_kiln", &"buy")
	await _wait(1.0)
	_p("second kiln blueprint: amber %d -> %d (want unchanged)" % [b2, Economy.amount(cid, AmberRules.ITEM)])
	# Workshop: craft a kiln and a lance (the host has a bell standing by now).
	until = Time.get_ticks_msec() + 20000
	while (Homestead.of(cid).get_node_or_null("Workshop") == null or Amber.placed_count(AmberRules.BELL) == 0) and Time.get_ticks_msec() < until:
		await _wait(0.25)
	var ws := Homestead.of(cid).get_node_or_null("Workshop") as Workshop
	_p("workshop %s, bell standing %d, amber tab: %s" % [ws != null, Amber.placed_count(AmberRules.BELL),
			str(ws._amber_items(cid).map(func(r: Dictionary) -> String: return "%s[%s]" % [r["id"], r["disabled"]]))])
	for id in [AmberRules.KILN, AmberRules.LANCE, AmberRules.BELL]:
		ws.menu_press(String(id), &"craft")
		await _wait(0.6)
	await _wait(0.6)
	_p("crafted: kiln %d lance %d bell %d (want 1 1 0), amber %d" % [Economy.amount(cid, AmberRules.KILN), Economy.amount(cid, AmberRules.LANCE),
			Economy.amount(cid, AmberRules.BELL), Economy.amount(cid, AmberRules.ITEM)])
	BuildManager.instance.build(AmberRules.KILN, cid, Vector2i(0, 7))
	BuildManager.instance.build(AmberRules.LANCE, cid, Vector2i(0, 11))
	await _wait(1.0)
	_p("placed: kiln %d lance %d (team), held kiln %d lance %d" % [Amber.placed_count(AmberRules.KILN), Amber.placed_count(AmberRules.LANCE),
			Economy.amount(cid, AmberRules.KILN), Economy.amount(cid, AmberRules.LANCE)])
	# Pick the kiln back up and put it down again.
	await _wait(3.0)
	var kiln := _turret(AmberRules.KILN)
	if kiln != null:
		BuildManager.instance.demolish_node(kiln)
		await _wait(1.0)
		_p("kiln picked up: standing %d, held %d (want 0 / 1), block for another: '%s'" % [Amber.placed_count(AmberRules.KILN), Economy.amount(cid, AmberRules.KILN), Amber.craft_block(AmberRules.KILN)])
		BuildManager.instance.build(AmberRules.KILN, cid, Vector2i(0, 7))
		await _wait(1.0)
		_p("kiln re-placed: standing %d held %d" % [Amber.placed_count(AmberRules.KILN), Economy.amount(cid, AmberRules.KILN)])


func _turret(id: StringName) -> AmberTurret:
	for n: Node in get_tree().get_nodes_in_group("amber_turrets"):
		var t := n as AmberTurret
		if t != null and t.def.id == id and not t.is_queued_for_deletion():
			return t
	return null


func _hud_amber() -> String:
	var l := _find_hud(get_tree().root)
	return l.text if l != null else "<none>"


func _hud_amber_shown() -> bool:
	var l := _find_hud(get_tree().root)
	return l != null and l.is_visible_in_tree()


func _find_hud(n: Node) -> Label:
	if n is Label and (n as Label).tooltip_text.begins_with("Hive amber: found only"):
		return n as Label
	for c in n.get_children():
		var f := _find_hud(c)
		if f != null:
			return f
	return null


# ------------------------------------------------------------------ both: watching

func _physics_process(delta: float) -> void:
	if me == null:
		return
	_log_t -= delta
	if _log_t <= 0.0:
		_log_t = 2.0
		_status()
		if side == "host": # the test is about the amber turrets, not losing: homes and turrets kept whole
			for c in WorldLayout.cliff_count():
				GameState.heal_homestead(c, 99999.0)
			for n: Node in get_tree().get_nodes_in_group("turrets"):
				var t := n as Turret
				if t != null and t.health != null:
					t.health.heal(99999.0)
	if side == "client" and GameState.flag_value("--ambershot") != "" and not _busy:
		var s := _seen()
		if int(s["shells"]) > 0 and not _shots.has("kiln"):
			_shoot("kiln", AmberRules.KILN)
		elif bool(s["beam"]) and not _shots.has("lance"):
			_shoot("lance", AmberRules.LANCE)
		elif int(s["frenzy"]) > 0 and not _shots.has("bell"):
			_shoot("bell", AmberRules.BELL)


func _seen() -> Dictionary:
	var statues := 0
	var shells := 0
	var frenzy := 0
	var fliers_low := 0
	var alive := 0
	var leaked: PackedStringArray = []
	var bugs := world.get("bugs") as Node
	for n: Node in bugs.get_children():
		var b := n as Bug
		if b == null:
			continue
		if b.is_alive():
			alive += 1
		if b.is_entombed():
			statues += 1
		var sh := b.get_node_or_null("AmberShell")
		if sh != null and not sh.is_queued_for_deletion():
			shells += 1
			if not b.is_alive():
				leaked.append(String(b.name))
		var fm := b.get("_frenzy_mark") as Label3D
		if fm != null and fm.visible:
			frenzy += 1
	var lance := _turret(AmberRules.LANCE)
	var beam := false
	var beam_mesh := false
	if lance != null:
		beam = lance.beam_on
		beam_mesh = (lance.get("_beam") as MeshInstance3D).visible
	return {"alive": alive, "statues": statues, "shells": shells, "frenzy": frenzy, "beam": beam, "beam_mesh": beam_mesh,
			"heat": lance.heat if lance != null else 0.0, "venting": lance.venting if lance != null else false, "leaked": leaked}


func _status() -> void:
	var s := _seen()
	var ids: PackedStringArray = []
	for n: Node in get_tree().get_nodes_in_group("amber_turrets"):
		ids.append("%s@c%d" % [(n as AmberTurret).def.id, (n as AmberTurret).cliff_id])
	var shell_names: PackedStringArray = []
	var bugs := world.get("bugs") as Node
	for n: Node in bugs.get_children():
		if n.get_node_or_null("AmberShell") != null:
			shell_names.append(String(n.name))
	_p("amber c%d=%d c%d=%d | saved bp %s | unlocked %s | turrets %s | bugs %d statues %d shells %d %s frenzy %d beam %s/%s heat %.1f vent %s leaked %s | tallies %s | phase %d wave %d" % [
			cid, Economy.amount(cid, AmberRules.ITEM), partner, Economy.amount(partner, AmberRules.ITEM), str(Story.progress.amber_blueprints), str(Amber.unlocked), str(ids),
			s["alive"], s["statues"], s["shells"], str(shell_names), s["frenzy"], s["beam"], s["beam_mesh"], s["heat"], s["venting"], str(s["leaked"]),
			str(Bug.amber_stats), GameState.phase, GameState.wave])


## Client: a camera on the turret's work, a picture, then back to the player's view.
func _shoot(tag: String, id: StringName) -> void:
	_busy = true
	_shots[tag] = true
	var t := _turret(id)
	var cliffs := world.get("cliffs") as CliffBuilder
	if t == null:
		_busy = false
		return
	var at := t.global_position
	var far := t.covers
	var inward := WorldLayout.inward(t.cliff_id)
	var wall := cliffs.face_point(far, 32.0, clampf(at.z, -20.0, 20.0))
	var side_v := Vector3.UP.cross(inward).normalized()
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 58.0
		world.add_child(_cam)
	_cam.global_position = at - inward * 4.0 + side_v * 6.0 + Vector3.UP * 6.0
	_cam.look_at(at.lerp(wall, 0.85) + Vector3.DOWN * 4.0, Vector3.UP)
	_cam.current = true
	await _wait(1.2 if tag != "bell" else 0.3)
	await RenderingServer.frame_post_draw
	var path := GameState.flag_value("--ambershot").replace(".png", "") + "_%s.png" % tag
	get_viewport().get_texture().get_image().save_png(path)
	var s := _seen()
	_p("shot %s saved %s (statues %d shells %d frenzy %d beam %s mesh %s)" % [tag, path, s["statues"], s["shells"], s["frenzy"], s["beam"], s["beam_mesh"]])
	_cam.current = false
	var pc := me.get_node_or_null("Head/Camera3D") as Camera3D
	if pc != null:
		pc.current = true
	_busy = false


func _final() -> void:
	_p("FINAL host view:")
	_status()
	for n: Node in get_tree().get_nodes_in_group("amber_turrets"):
		var t := n as AmberTurret
		_p("  %s stats %s" % [t.def.id, str(t.stats)])
	_p("  favours pending %s" % str(Amber.pending))
