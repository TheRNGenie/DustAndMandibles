extends Node
## Debug (--storyplay, with --debug --story=9 or 10): plays chapter 9 or 10
## start to finish against its full waves, as a player would, and logs it.
## Host / solo only. Runs on its own (pair it with --fast for short build
## phases); quits --playend seconds after the end screen (default 45).
##
## Chapter 9: in each build phase it rides down to each family's homestead
## (the real expedition path: on the floor, E on the tin box, back up over the
## lip so the pack is unpacked), two bundles a trip, then the ledger once the
## camp turns up. --playdrop: the carrier is downed on the floor once with a
## bundle in the pack (it must drop, then be repacked). --playlate: leave the
## ledger until the story hold build after the last wave (chapter 10: the
## furnace).
## Chapter 10: --playfurnace=S S seconds into the train night, the player
## stands on the rim (--playfloor: on the canyon floor beside it) and shoots
## the Iron Mandible's furnace with their own gun (--playgun=<id>, default the
## lever rifle) through the real firing path until it blows. --playmother:
## shoots at the Hive Mother too.
## Both: --playbuild spends each cliff's own scrap and chitin on a late-game
## defence every build phase (no free money); --playsafe keeps the player
## alive (homesteads still take damage); --playskip readies up as soon as the
## job of the build phase is done; --playnojob does nothing (a lost-chapter
## test); --playshots=<dir> saves screenshots at the beats (needs a window).

var world: Node3D
var director: StoryDirector
var me: Player
var _t0 := 0
var _said_seen: Dictionary = {}
var _busy := false
var _shots_dir := ""
var _shot_n := 0
var _frame_worst := 0.0
var _frames := 0
var _frame_sum := 0.0
var _hp_before := -1.0
var _furnace_shots := 0
var _furnace_t0 := -1.0
var _mother_seen := -1.0
var _over := false
var _bug_peak := 0
var _kill_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_shots_dir = GameState.flag_value("--playshots")
	if _shots_dir != "":
		DirAccess.make_dir_recursive_absolute(_shots_dir)
	while StoryDirector.instance == null or world == null or not bool(world.get("_started")):
		await get_tree().process_frame
		if world == null and DebugTools.instance != null:
			world = DebugTools.instance.world
	director = StoryDirector.instance
	while me == null:
		await get_tree().process_frame
		me = world.call("local_player") as Player
	if not multiplayer.is_server():
		_log("not the host: the driver only plays on the host")
		return
	GameState.phase_changed.connect(_on_phase)
	GameState.game_over.connect(_on_over)
	var gid := StringName(GameState.flag_value("--playgun") if GameState.flag_value("--playgun") != "" else "lever_rifle")
	if Gun.weapon(gid) != null:
		me.gun.grant(gid, 0)
		me.gun.equip(gid)
	_log("start: chapter %d %s, gun %s, scrap %s" % [director.chapter.number, director.chapter.title, String(me.gun.def.id), _scrap()])
	var tick := Timer.new()
	tick.wait_time = 5.0
	tick.autostart = true
	tick.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tick)
	tick.timeout.connect(_report)
	if GameState.phase == GameState.Phase.BUILD:
		_on_phase(GameState.phase)


func _now() -> float:
	return (Time.get_ticks_msec() - _t0) / 1000.0


func _log(s: String) -> void:
	print("[play %6.1fs] %s" % [_now(), s])


func _scrap() -> String:
	var parts: PackedStringArray = []
	for cid in WorldLayout.cliff_count():
		parts.append("%d/%dc" % [Economy.amount(cid, &"scrap"), Economy.amount(cid, &"chitin")])
	return " ".join(parts)


func _process(delta: float) -> void:
	_frames += 1
	_frame_sum += delta
	_frame_worst = maxf(_frame_worst, delta)
	if director == null or not is_instance_valid(director):
		return
	# Every new beat, with the time it went out.
	for k: Variant in director._said.keys():
		if not _said_seen.has(k):
			_said_seen[k] = true
			_log("beat %s" % str(k))
			_shot("beat_" + str(k))
	# --playkill: a stand-in for riders with revolvers at the houses: 25 damage a
	# second to every bug breaching a house or flying over one.
	_kill_t -= delta
	if _kill_t <= 0.0:
		_kill_t = 1.0
	if GameState.has_flag("--playkill") and _kill_t == 1.0 and multiplayer.is_server():
		for n: Node in get_tree().get_nodes_in_group("bugs"):
			var b := n as Bug
			if b.is_alive() and (b.state == Bug.State.BREACHING or b.state == Bug.State.FLYING):
				b.receive_hit(25.0, b.global_position, Vector3.DOWN, false, 1.0, "Rancher", b.cliff_id)
	# --playarmor: every turret is kept whole (a stand-in for a defence that
	# holds: walls, repairs, a partner), so the boss fight can be timed.
	if GameState.has_flag("--playarmor") and _kill_t == 1.0:
		for n: Node in get_tree().get_nodes_in_group("turrets"):
			var t := n as Turret
			if t != null and t.health != null and not t.health.dead:
				t.health.hp = t.health.max_hp
	if GameState.has_flag("--god") and not _over:
		GameState.god_mode = true # (the houses can't fall: the whole flow plays out)
	if GameState.has_flag("--playsafe") and me != null and is_instance_valid(me) and me.vitals != null and not me.vitals.downed:
		me.vitals.hp = PlayerVitals.MAX_HP


func _report() -> void:
	if director == null or _over:
		return
	var bm := BugManager.instance
	var alive := bm.alive_count() if bm != null else 0
	_bug_peak = maxi(_bug_peak, alive)
	var fps := _frames / maxf(_frame_sum, 0.001)
	var st: Array = director.piece.call("status") if director.piece != null else ["", ""]
	var extra := ""
	var m := _mother()
	if m != null:
		if _mother_seen < 0.0:
			_mother_seen = _now()
			_log("the Hive Mother is out: %.0f hp, cliff %d" % [m.health.max_hp, m.cliff_id])
			_shot("mother_out")
		extra = "  mother %.0f%% state %d y %.1f pinned %s" % [m.health.hp / m.health.max_hp * 100.0, m.state, m.climb_y, str(m.boss.get("pinned")) if m.boss != null else "?"]
	_log("wave %d phase %d hold %s  bugs %d (peak %d)  fps %.0f worst %.0f ms  homes %s  scrap %s  turrets %d  | %s%s" % [
			GameState.wave, GameState.phase, str(GameState.story_hold), alive, _bug_peak, fps, _frame_worst * 1000.0,
			str(GameState.homestead_hp.map(func(h: float) -> int: return int(h))), _scrap(),
			get_tree().get_nodes_in_group("turrets").size(), str(st[0]), extra])
	if alive > 0 and alive <= 3 and GameState.phase == GameState.Phase.WAVE:
		for n: Node in get_tree().get_nodes_in_group("bugs"):
			var b := n as Bug
			if b.is_alive():
				_log("  left: %s state %d cliff %d y %.1f at %s hp %.0f hidden %s" % [b.def.id, b.state, b.cliff_id, b.climb_y, str(b.global_position.snapped(Vector3.ONE * 0.1)), b.health.hp, str(b.is_hidden())])
	_frames = 0
	_frame_sum = 0.0
	_frame_worst = 0.0


func _mother() -> Bug:
	var bm := BugManager.instance
	if bm == null:
		return null
	for c in bm.get_children():
		var b := c as Bug
		if b != null and b.def != null and b.def != null and b.def.behavior == BugDef.Behavior.BOSS and b.is_alive():
			return b
	return null


func _shot(tag: String) -> void:
	if _shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	_shot_n += 1
	var path := "%s/%02d_%s.png" % [_shots_dir, _shot_n, tag.validate_filename()]
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	_log("shot %s" % path)


# ------------------------------------------------------------------ phases

func _on_phase(p: GameState.Phase) -> void:
	_log("phase %d wave %d (hold %s)" % [p, GameState.wave, str(GameState.story_hold)])
	if p == GameState.Phase.BUILD:
		_build_phase.call_deferred()
	elif p == GameState.Phase.WAVE and director.chapter.kind() == "reckoning":
		_train_night.call_deferred()


func _build_phase() -> void:
	await get_tree().create_timer(3.0).timeout
	if _over:
		return
	if GameState.has_flag("--playbuild"):
		_build()
	if not GameState.has_flag("--playnojob") and director.chapter.kind() == "salvage":
		await _salvage()
	if director.chapter.kind() == "reckoning" and GameState.story_hold and not GameState.has_flag("--playnojob"):
		await _shoot_furnace() # the hold: the furnace is still burning
	await get_tree().create_timer(2.0).timeout
	# --playwait=S: hold every build phase S seconds before readying (the train rolls in).
	var hold := GameState.flag_value("--playwait").to_float()
	if hold > 0.0 and GameState.phase == GameState.Phase.BUILD:
		var was := GameState.has_flag("--fast")
		GameState.flags.erase("--fast") # (the build clock stops without --fast)
		await get_tree().create_timer(hold).timeout
		if was:
			GameState.flags.append("--fast")
	if GameState.has_flag("--playskip") and GameState.phase == GameState.Phase.BUILD and not GameState.story_hold and not _over:
		_log("readying up")
		GameState.debug_skip()


func _on_over(won: bool, reason: String) -> void:
	_over = true
	_log("GAME OVER won=%s: %s  (wave %d)" % [str(won), reason, GameState.wave])
	_shot("end_0")
	var end_s := GameState.flag_value("--playend").to_float()
	if end_s <= 0.0:
		end_s = 45.0
	for i in int(end_s / 5.0):
		await get_tree().create_timer(5.0, true, false, true).timeout
		_shot("end_%d" % (i + 1))
	var pr := Story.progress
	_log("progress: done %s, journal %s, blueprints %s, amber blueprints %s; Amber.unlocked %s" % [
			str(pr.done), str(pr.journal), str(pr.blueprints), str(pr.amber_blueprints), str(Amber.get("unlocked"))])
	_log("last result %s" % str(Story.last_result))
	get_tree().quit()


# ------------------------------------------------------------------ chapter 9

func _salvage() -> void:
	var fam := director.piece as DryGulchFamilies
	if fam == null or _busy:
		return
	_busy = true
	var late := GameState.has_flag("--playlate")
	var todo: Array[int] = []
	for i in fam.states.size():
		if int(fam.states[i]) != HomesteadRules.Papers.UP:
			todo.append(i)
	# Two families a trip.
	while not todo.is_empty() and not _over and GameState.phase == GameState.Phase.BUILD:
		var trip := todo.slice(0, 2)
		todo = todo.slice(2)
		for i: int in trip:
			var r: DryGulchFamilies.Ruin = fam.ruins[i]
			await _go_floor(r.to_global(Vector3(0.4, 0.0, 1.4)), r.box.global_position)
			r.box.local_interact(false)
			await get_tree().create_timer(0.6).timeout
			_log("took the %s papers: state %d, pack %s" % [HomesteadRules.family_name(i), int(fam.states[i]), str(Expedition.local_pack())])
			_shot("papers_%s" % HomesteadRules.family_name(i))
			if GameState.has_flag("--playdrop") and not has_meta(&"dropped"):
				set_meta(&"dropped", true)
				await _downed_and_repack(fam, i)
		await _go_up()
	# The ledger, once the camp's found (or in the hold, with --playlate).
	if fam.camp_found and fam.ledger != HomesteadRules.Papers.UP and (not late or GameState.story_hold) and not _over:
		var c := fam.camp
		await _go_floor(c.to_global(DryGulchFamilies.Camp.BOX_AT + Vector3(0.6, 0.0, 2.2)), c.strongbox.global_position)
		_shot("camp")
		c.strongbox.local_interact(false)
		await get_tree().create_timer(0.6).timeout
		_log("took the ledger: %d, pack %s" % [fam.ledger, str(Expedition.local_pack())])
		await _go_up()
	_busy = false
	_log("salvage: %s" % str(fam.status()[0]))


## Down on the floor at `at`, looking at `look`; waits until the host has us down.
func _go_floor(at: Vector3, look: Vector3) -> void:
	var cl := world.get("cliffs") as CliffBuilder
	at.y = cl.floor_height(at.x, at.z) + 0.1
	me.set("_trip", true)
	me.global_position = at
	me.velocity = Vector3.ZERO
	_look(look)
	var until := _now() + 5.0
	while not Expedition.is_down(me.get_multiplayer_authority()) and _now() < until:
		await get_tree().process_frame
		me.global_position = at
		me.velocity = Vector3.ZERO
	await get_tree().create_timer(0.4).timeout
	_look(look)


## Back up over our own lip (the rope ride's end): the pack is unpacked.
func _go_up() -> void:
	var cl := world.get("cliffs") as CliffBuilder
	me.global_position = cl.plateau_point(me.cliff_id, 6.0, 0.0) + Vector3.UP * 0.3
	me.velocity = Vector3.ZERO
	var until := _now() + 5.0
	while Expedition.is_down(me.get_multiplayer_authority()) and _now() < until:
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	_log("up top: pack %s" % str(Expedition.local_pack()))


func _downed_and_repack(fam: DryGulchFamilies, i: int) -> void:
	_log("downing the carrier on the floor with the %s papers" % HomesteadRules.family_name(i))
	var was_god := GameState.god_mode
	GameState.god_mode = false
	var safe := GameState.has_flag("--playsafe")
	me.vitals.hp = 1.0
	me.vitals.apply_damage(9999.0)
	GameState.god_mode = was_god
	await get_tree().create_timer(1.0).timeout
	_log("downed %s: state %d, dropped at %s" % [str(me.vitals.downed), int(fam.states[i]), str(fam.dropped_at[i])])
	_shot("dropped")
	var until := _now() + 30.0
	while me.vitals.downed and _now() < until:
		await get_tree().create_timer(0.5).timeout
	_log("back up after being downed (safe %s)" % str(safe))
	var node: Node3D = fam._dropped_nodes.get(i)
	if node != null and is_instance_valid(node):
		await _go_floor(node.global_position + Vector3(1.0, 0, 1.0), node.global_position)
		(node as DryGulchFamilies.DroppedBundle).local_interact(false)
		await get_tree().create_timer(0.6).timeout
	_log("repacked: state %d" % int(fam.states[i]))


# ------------------------------------------------------------------ chapter 10

func _train_night() -> void:
	if GameState.wave != director.chapter.first_wave or GameState.has_flag("--playnojob"):
		if GameState.has_flag("--playmother") and GameState.wave == director.chapter.last_wave:
			_shoot_mother()
		return
	if GameState.has_flag("--playlate"):
		return # (the furnace waits for the hold after the last wave)
	var wait := GameState.flag_value("--playfurnace").to_float() if GameState.flag_value("--playfurnace") != "" else 20.0
	await get_tree().create_timer(wait).timeout
	await _shoot_furnace()


func _shoot_furnace() -> void:
	var train := director.piece as IronMandible
	if train == null or train.blown or _busy:
		return
	_busy = true
	var floor := GameState.has_flag("--playfloor")
	_furnace_t0 = _now()
	_hp_before = train.hp
	var cl := world.get("cliffs") as CliffBuilder
	_log("shooting the furnace from the %s: %.0f / %.0f hp, train s %.1f, furnace at %s" % ["floor" if floor else "rim", train.hp, train.hp_max, train.s, str(train.furnace.global_position.snapped(Vector3.ONE * 0.1))])
	var last_hp := train.hp
	var shots := 0
	var hits := 0
	while not train.blown and not _over and _now() - _furnace_t0 < 240.0:
		var f := train.furnace.global_position
		if floor:
			var side := train.furnace.global_transform.basis.x
			var at := f + side * 12.0
			at.y = cl.floor_height(at.x, at.z) + 0.1
			if Expedition.is_down(me.get_multiplayer_authority()) or GameState.phase == GameState.Phase.WAVE:
				me.set("_trip", true)
			me.global_position = at
		else:
			# On the lip nearest the train, as far along as the plateau goes.
			var best := 0
			for c in WorldLayout.cliff_count():
				if cl.plateau_point(c, 0.0, f.z).distance_to(f) < cl.plateau_point(best, 0.0, f.z).distance_to(f):
					best = c
			me.set("_trip", false)
			me.global_position = cl.plateau_point(best, GameState.flag_value("--playlip").to_float() if GameState.flag_value("--playlip") != "" else 0.3, clampf(f.z, -18.0, 18.0)) + Vector3.UP * 0.2
		me.velocity = Vector3.ZERO
		# Aim at the firebox door on our side.
		var door := TrainMeshes.DOORS[0] if train.furnace.to_local(me.global_position).x > 0.0 else TrainMeshes.DOORS[1]
		var aim := train.furnace.to_global(door)
		_look(aim)
		await get_tree().process_frame
		_look(aim)
		var o := me.camera.global_position
		var dd := -me.camera.global_transform.basis.z # (aimed before the kick, as Player does)
		if me.gun.trigger(me.camera):
			shots += 1
			_furnace_shots += 1
			me.net.fire(o, dd)
			if shots <= 3 or shots % 20 == 0:
				var h := me.gun.raycast(o, dd, [me.get_rid()], Gun.range_for(me.gun.def.id, 0))
				_log("shot %d: from %s at %s (%.0f m): hit %s" % [shots, str(o.snapped(Vector3.ONE * 0.1)), str(aim.snapped(Vector3.ONE * 0.1)), o.distance_to(aim),
						"nothing" if h.is_empty() else "%s %s at %.0f m" % [(h["collider"] as Node).name, (h["collider"] as Node).get_class(), o.distance_to(h["position"])]])
				var fur := train.furnace
				var cs := fur.get_child(0) as CollisionShape3D
				_log("  furnace node %s, shape at %s, physics body at %s, layer %d" % [str(fur.global_position.snapped(Vector3.ONE * 0.1)), str(cs.global_position.snapped(Vector3.ONE * 0.1)),
						str((PhysicsServer3D.body_get_state(fur.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D).origin.snapped(Vector3.ONE * 0.1)), fur.collision_layer])
			if shots == 3:
				_shot("furnace_shooting")
		if train.hp < last_hp:
			hits += 1
			last_hp = train.hp
	var took := _now() - _furnace_t0
	_log("furnace %s after %.1f s: %d shots, %d hits, %.0f -> %.0f hp, from %s" % ["BLOWN" if train.blown else "still burning", took, shots, hits, _hp_before, train.hp, str(me.global_position.snapped(Vector3.ONE * 0.1))])
	_shot("furnace_blown")
	_busy = false
	if floor:
		await _go_up()


func _shoot_mother() -> void:
	while not _over and GameState.phase == GameState.Phase.WAVE:
		var m := _mother()
		if m == null:
			await get_tree().create_timer(1.0).timeout
			continue
		var cl := world.get("cliffs") as CliffBuilder
		var across := WorldLayout.map().defenders_of(m.cliff_id)
		var cid: int = across[0] if not across.is_empty() else WorldLayout.other_cliff(m.cliff_id)
		me.set("_trip", false)
		me.global_position = cl.plateau_point(cid, 0.8, clampf(m.global_position.z, -18.0, 18.0)) + Vector3.UP * 0.2
		me.velocity = Vector3.ZERO
		var crown: Vector3 = m.to_global(m.spec.get("crown", Vector3.ZERO)) if m.spec.has("crown") else m.global_position + Vector3.UP * 2.0
		_look(crown)
		await get_tree().process_frame
		_look(crown)
		var mo := me.camera.global_position
		var md := -me.camera.global_transform.basis.z
		if me.gun.trigger(me.camera):
			me.net.fire(mo, md)


func _look(at: Vector3) -> void:
	var d := at - me.camera.global_position
	me.rotation.y = atan2(-d.x, -d.z)
	me.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


# ------------------------------------------------------------------ the defence

## Spends each cliff's own scrap on a late-game line (row 0), then traps by the
## house, then upgrades with chitin. No free money.
func _build() -> void:
	var builds := world.get("builds") as BuildManager
	var line: Array[StringName] = [&"twin_gatling", &"rail_spike_driver", &"thunder_mule", &"twin_mortar", &"elephant_battery",
			&"firework_battery", &"gatling_post", &"hornets_nest", &"buffalo_rifle", &"big_bertha", &"sky_hound", &"whaler"]
	for cid in WorldLayout.cliff_count():
		var i := 0
		var built: PackedStringArray = []
		for col in Buildable.COLS:
			var cell := Vector2i(0, col)
			if not builds.is_free(cid, cell):
				continue
			var id := line[i % line.size()]
			var tries := 0
			while (not Defs.is_unlocked(id, GameState.tier_wave()) or Economy.amount(cid, &"scrap") < Defs.cost_of(id)) and tries < line.size():
				i += 1
				tries += 1
				id = line[i % line.size()]
			if tries >= line.size():
				break
			builds.build(id, cid, cell)
			built.append(String(id))
			i += 1
		var ups := 0
		for k in 30:
			var did := false
			for col in Buildable.COLS:
				var t := builds.turret_at(cid, Vector2i(0, col))
				if t != null and t.upgrade_cost() > 0 and Economy.amount(cid, &"chitin") >= t.upgrade_cost():
					builds.upgrade_node(t)
					ups += 1
					did = true
			if not did:
				break
		_log("build cliff %d: %s, %d upgrades, left %d scrap %d chitin" % [cid, ", ".join(built), ups, Economy.amount(cid, &"scrap"), Economy.amount(cid, &"chitin")])
