class_name StoryDirector
extends Node
## Runs a Story chapter (StoryChapter) on top of a normal run. The host decides
## everything and tells every peer through this node's RPCs (same path on every
## peer: /root/World/StoryDirector); the radio lines tied to a wave come from the
## chapter data, so every peer says them itself when the phase changes.
##
## What it does: starts the run at the chapter's first wave with its start
## bonus and the players' blueprints; edits each wave's plan (the chapter's boss,
## its extra bugs) and weather; pins the telegram on every house's noticeboard;
## runs the chapter's objective; wins the chapter when its last wave is cleared
## and the objective is done (or holds until it is); and books the result in
## every player's own Story progress (Notches, unlock, journal page).
##
## Objectives (StoryChapter.objective, the field a Canyon Expedition replaces later):
## - hold: survive the waves (losing a Homestead loses, as in any run).
## - fetch: a thing to carry (E picks it up) to a well or a noticeboard. Canyon
##   Expeditions: it lies on the canyon floor (Dry Season's pump valve in a
##   wrecked supply wagon on the way to the main tunnel; The Survey Map's Queen
##   Spider gland in her carcass, which always ends up on the floor), goes in
##   your backpack (Expedition.story_items: never unpacked onto the stockpile,
##   left where you fall if you're downed) and rides on your back once you're
##   up. The plateau stand-ins still work from the data (spawn airship_drop /
##   boss_drop).
## - blast: Down the Hole's dynamite job (DownTheHole).
## - salvage: The Dry Gulch Families' floor job (DryGulchFamilies): the four
##   families' papers from their ruined homesteads and the board's harvest
##   ledger from the amber crew's camp, all brought up out of the canyon.
## - reckoning: The Reckoning's set piece (IronMandible): the board's train and
##   its amber furnace, the second blast, the Hive Mother and Silas's charge.
##   Won with an epilogue (EpilogueView: typed decree cards, then the last word).
## - protect: payroll strongboxes by every house that Dragonfly Bandits rob;
##   shoot a bandit with a sack and the silver goes back. All of it gone loses.
## - keep: so many scaffold storeys (The Railroad's Secret, against the
##   Burrowing Beetle) or lantern posts (Dust and Thunder, whose Thunder Cicada
##   breaks lanterns in its screech ring) per held cliff, standing whenever a
##   night ends. Short when a night ends loses the chapter.
## A floor job still open when the last wave is cleared puts the run back in a
## build phase that never ends in a wave (GameState.story_hold_build), so the
## team can go down and finish it.
##
## Debug (with --debug): --story=N plays chapter N, --storywave=W starts at wave W
## of it, --storyfetch carries the fetch item to you at once, --storywin /
## --storylose end the chapter after --seconds (screenshots of the end screen).

enum Cargo { NONE, FALLING, GROUND, CARRIED, DELIVERED, PACKED }

const DELIVER_REACH := 3.6
## Seconds between "a bandit's got a sack" lines.
const STEAL_LINE_GAP := 25.0
## Seconds between "you're short" lines (keep).
const SHORT_LINE_GAP := 30.0

static var instance: StoryDirector

var world: Node3D
var chapter: StoryChapter
var radio: RadioCard
var tracker: StoryTracker
var telegram: TelegramView

# Fetch (every peer, from the host's RPCs).
var cargo_state := Cargo.NONE
var carrier := 0
var cargo: StoryCargo
## The wreck or carcass a floor item lies in (every peer; stays when it's taken).
var cargo_dressing: Node3D
## Down the Hole's set piece (blast chapters), on every peer.
var blast: DownTheHole
## Chapters 9 and 10's set piece (DryGulchFamilies / IronMandible), on every
## peer: status() -> [text, kind], done() -> bool.
var piece: Node
# Protect: one strongbox per cliff; loot per box (every peer).
var boxes: Array[StoryStrongbox] = []
var in_flight := 0
var escaped := 0
## Host: the last wave is cleared and the chapter waits on its objective.
var holding := false
var finished := false

var _started := false
var _ending := false
var _boards_made := false
var _said: Dictionary = {}
var _steal_line_t := -999.0
var _short_line_t := -999.0
var _keep_t := 0.0
## keep: the last count (local, refreshed twice a second for the tracker).
var keep_have := 0
var _blueprints_from: Dictionary = {}


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	GameState.story_last_wave = 0
	GameState.story_end_hook = Callable()
	GameState.forced_weather = {}
	WaveDirector.plan_hook = Callable()
	MechWell.valve_broken = false
	BossBrain.screech_breaks_lanterns = false
	Expedition.story_items.clear()
	SitePlan.skip_tunnels = []
	SitePlan.story_zones.clear()
	Bug.frenzy_lit = false
	BugManager.boss_tunnel = -1
	if Expedition.story_item_up.is_connected(_on_item_up):
		Expedition.story_item_up.disconnect(_on_item_up)
		Expedition.story_item_dropped.disconnect(_on_item_dropped)


func _ready() -> void:
	chapter = Story.chapter()
	if chapter == null:
		queue_free()
		return
	print("[story] chapter %d: %s (waves %d-%d, %s)" % [chapter.number, chapter.title, chapter.first_wave, chapter.last_wave, chapter.kind()])
	GameState.story_last_wave = chapter.last_wave
	GameState.story_end_hook = _on_last_wave_cleared
	var forced := {}
	for w in range(chapter.first_wave, chapter.last_wave + 1):
		if chapter.weather_for(w) >= 0:
			forced[w] = chapter.weather_for(w)
	GameState.forced_weather = forced
	WaveDirector.plan_hook = func(plan: Dictionary) -> Dictionary: return chapter.apply_to_plan(plan, GameState.wave)
	MechWell.valve_broken = bool(chapter.objective.get("breaks_wells", false))
	BossBrain.screech_breaks_lanterns = bool(chapter.objective.get("screech_breaks_lanterns", false))
	var hud := world.get("hud") as Node
	radio = RadioCard.new()
	radio.name = "RadioCard"
	hud.add_child(radio)
	tracker = StoryTracker.new()
	tracker.name = "StoryTracker"
	tracker.director = self
	hud.add_child(tracker)
	telegram = TelegramView.new()
	telegram.name = "TelegramView"
	add_child(telegram)
	GameState.phase_changed.connect(_on_phase)
	GameState.game_over.connect(_on_game_over)
	_hook_bugs.call_deferred()
	Expedition.story_items.clear()
	if chapter.pack_item() != &"":
		Expedition.story_items.append(chapter.pack_item())
	Expedition.story_item_up.connect(_on_item_up)
	Expedition.story_item_dropped.connect(_on_item_dropped)
	if chapter.kind() == "blast":
		blast = DownTheHole.new()
		blast.name = "DownTheHole"
		blast.director = self
		blast.world = world
		add_child(blast)
	elif chapter.sealed_tunnel:
		DownTheHole.seal_main(world)
	if chapter.kind() == "salvage":
		var fam := DryGulchFamilies.new()
		fam.name = "DryGulchFamilies"
		fam.director = self
		fam.world = world
		piece = fam
		add_child(fam)
	elif chapter.kind() == "reckoning":
		var train := IronMandible.new()
		train.name = "IronMandible"
		train.director = self
		train.world = world
		piece = train
		add_child(train)
	if not multiplayer.is_server():
		_tell_blueprints.rpc_id(1, Story.progress.blueprints)
	_debug_flags()


## Debug: --storywin / --storylose end the chapter after --storyend seconds (default 6);
## --telegram opens the telegram once the first build phase is up.
func _debug_flags() -> void:
	if not GameState.debug_enabled():
		return
	var end_after := GameState.flag_value("--storyend").to_float()
	if end_after <= 0.0:
		end_after = 6.0
	if multiplayer.is_server() and (GameState.has_flag("--storywin") or GameState.has_flag("--storylose")):
		get_tree().create_timer(end_after).timeout.connect(func() -> void:
			if GameState.has_flag("--storywin"):
				_win()
			else:
				_lose("The %s Homestead fell on wave %d." % [WorldLayout.map().name_of(0), GameState.wave]))
	if GameState.has_flag("--lookboard"): # stand in front of your house's noticeboard
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			var p := world.call("local_player") as Player
			var home := Homestead.of(p.cliff_id) if p != null else null
			var board := home.get_node_or_null("NoticeBoard") as Node3D if home != null else null
			if board == null:
				return
			p.global_position = board.to_global(Vector3(-0.9, 0.0, 2.7))
			var d := board.to_global(Vector3(0, 1.5, 0)) - p.global_position
			p.rotation.y = atan2(-d.x, -d.z)
			p.head.rotation.x = deg_to_rad(-6.0))
	if GameState.has_flag("--lookbox"): # stand by your house's payroll strongbox (Bandits in the Bargain)
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			var p := world.call("local_player") as Player
			if p == null or boxes.is_empty():
				return
			var box: StoryStrongbox = boxes[clampi(p.cliff_id, 0, boxes.size() - 1)]
			p.global_position = box.to_global(Vector3(1.6, 0.0, -3.2))
			var d := box.to_global(Vector3(0, 0.6, 0)) - p.global_position
			p.rotation.y = atan2(-d.x, -d.z)
			p.head.rotation.x = deg_to_rad(-14.0))
	if GameState.has_flag("--storyfloorview"): # on the canyon floor in front of the fetch item (screenshots)
		get_tree().create_timer(3.5).timeout.connect(func() -> void:
			var p := world.call("local_player") as Player
			if p == null or cargo == null or not is_instance_valid(cargo):
				print("[story] floor view: no cargo yet")
				return
			var at := cargo.global_position
			var dir := Vector3(cos(at.x), 0.0, sin(at.x)).normalized()
			if GameState.flag_value("--storyfloordir") != "":
				var a := deg_to_rad(GameState.flag_value("--storyfloordir").to_float())
				dir = Vector3(cos(a), 0.0, sin(a))
			var stand := at + dir * GameState.flag_value("--storyfloordist").to_float() if GameState.flag_value("--storyfloordist") != "" else at + dir * 4.5
			var cl := world.get("cliffs") as CliffBuilder
			stand.y = cl.floor_height(stand.x, stand.z) + 0.1
			p.set("_trip", true)
			p.global_position = stand
			p.velocity = Vector3.ZERO
			var d := at + Vector3.UP * 0.5 - (stand + Vector3.UP * 1.6)
			p.rotation.y = atan2(-d.x, -d.z)
			p.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
			print("[story] floor view at %s, cargo %s" % [str(stand.snapped(Vector3.ONE * 0.1)), str(at.snapped(Vector3.ONE * 0.1))]))
	if GameState.has_flag("--telegram"):
		get_tree().create_timer(2.5).timeout.connect(func() -> void: telegram.open())
	if GameState.has_flag("--epilogue") and not chapter.epilogue.is_empty(): # the epilogue cards now (screenshots)
		var ep := EpilogueView.new()
		ep.name = "EpilogueView"
		ep.chapter = chapter
		ep.delay = 3.0
		add_child(ep)


## The wave the run starts on (Debug: --storywave=W inside the chapter).
func start_wave() -> int:
	var w := chapter.first_wave
	if GameState.debug_enabled() and GameState.flag_value("--storywave") != "":
		w = clampi(int(GameState.flag_value("--storywave")), chapter.first_wave, chapter.last_wave)
	return w


func _process(delta: float) -> void:
	if not _boards_made:
		_make_boards()
	if cargo != null and is_instance_valid(cargo):
		_follow_carrier()
	if chapter.kind() == "keep":
		_keep_t -= delta
		if _keep_t <= 0.0:
			_keep_t = 0.5
			keep_have = count_keep()
	if multiplayer.is_server() and not finished:
		_host_tick()


# ------------------------------------------------------------------ phases and radio

func _on_phase(p: GameState.Phase) -> void:
	var w := GameState.wave
	match p:
		GameState.Phase.BUILD:
			if not _started:
				_started = true
				_begin()
			elif w - 1 >= chapter.first_wave:
				if multiplayer.is_server() and chapter.kind() == "keep" and not finished and not objective_done():
					_lose(_keep_lost_reason())
					return
				_say_lines(chapter.lines(w - 1, "held"), "held%d" % (w - 1))
			_say_lines(chapter.lines(w, "build"), "build%d" % w)
			if multiplayer.is_server():
				_host_build(w)
		GameState.Phase.WAVE:
			_say_lines(chapter.lines(w, "wave"), "wave%d" % w)
			if multiplayer.is_server() and chapter.kind() == "fetch" and cargo_state != Cargo.DELIVERED and cargo_state != Cargo.NONE:
				_event.rpc("reminder")
			elif multiplayer.is_server() and blast != null and not blast.blown:
				_event.rpc("reminder")
	if tracker != null:
		tracker.refresh()


## Every peer: the chapter's first build phase.
func _begin() -> void:
	Story.progress.note_tried(chapter.id)
	if multiplayer.is_server():
		# The start bonus (later chapters start on a later wave) and blueprints.
		for cid in WorldLayout.cliff_count():
			if not chapter.start_bonus.is_empty():
				var bonus: Dictionary = {}
				for r: String in chapter.start_bonus:
					bonus[StringName(r)] = int(chapter.start_bonus[r])
				Economy.earn(cid, bonus)
		_give_blueprints(1, Story.progress.blueprints)
		if chapter.kind() == "protect":
			_place_strongboxes()


func _host_build(w: int) -> void:
	# Debug: --storycargo puts the chapter's fetch item on the ground at --storydropat (screenshots).
	if GameState.has_flag("--storycargo") and GameState.debug_enabled() and chapter.kind() == "fetch" and cargo_state == Cargo.NONE:
		var p := GameState.flag_value("--storydropat").split(",")
		var cliffs := world.get("cliffs") as CliffBuilder
		_spawn_cargo.rpc(cliffs.plateau_point(_local_cliff(), p[0].to_float() if p.size() == 2 else 6.0, p[1].to_float() if p.size() == 2 else 2.0), false, "")
		return
	# Debug: --storycarcass lays the boss's carcass (and its prize) at the foot of your cliff now.
	if GameState.has_flag("--storycarcass") and GameState.debug_enabled() and cargo_state == Cargo.NONE 			and str(chapter.objective.get("spawn", "")) == "boss_carcass":
		_spawn_cargo.rpc(carcass_point(world.get("cliffs") as CliffBuilder, _local_cliff(), -6.0), false, "carcass")
		_event.rpc("drop")
		return
	if chapter.kind() == "fetch" and str(chapter.objective.get("spawn", "")) == "airship_drop":
		if cargo_state == Cargo.NONE and w >= int(chapter.objective.get("drop_wave", chapter.first_wave)):
			_airship_drop()
	if chapter.kind() == "fetch" and str(chapter.objective.get("spawn", "")) == "floor_wagon":
		if cargo_state == Cargo.NONE and w >= int(chapter.objective.get("drop_wave", chapter.first_wave)):
			_floor_wagon()


func _say_lines(lines: Array, key: String) -> void:
	if _said.has(key) or radio == null:
		return
	_said[key] = true
	for l: Array in lines:
		radio.say(str(l[0]), str(l[1]))


## Host -> everyone: one of the chapter's event lines ("drop", "win"...).
@rpc("authority", "call_local", "reliable")
func _event(key: String) -> void:
	print("[story] event %s (wave %d)" % [key, GameState.wave])
	if radio == null:
		return
	for l: Array in chapter.event_lines(key):
		radio.say(str(l[0]), str(l[1]))
	if tracker != null:
		tracker.refresh()


# ------------------------------------------------------------------ the chapter's end

## Host: GameState calls this when the chapter's last wave is cleared.
func _on_last_wave_cleared() -> void:
	if _ending:
		return # (already waiting on a beat; GameState asks again while the wave sits empty)
	print("[story] last wave %d cleared, objective done: %s" % [GameState.wave, objective_done()])
	if objective_done():
		# (Chapters 9-10: a beat still on the wire gets its say before the end.)
		var wait := float(piece.call("win_delay")) if piece != null and piece.has_method("win_delay") else 0.0
		if wait > 0.5:
			_ending = true
			get_tree().create_timer(wait).timeout.connect(_win)
		else:
			_win()
	elif chapter.kind() == "keep":
		_lose(_keep_lost_reason())
	else:
		holding = true
		_set_holding.rpc()
		_event.rpc("hold")
		if chapter.floor_job():
			GameState.story_hold_build() # back to daylight: the job's down in the canyon


@rpc("authority", "call_local", "reliable")
func _set_holding() -> void:
	holding = true
	if tracker != null:
		tracker.refresh()


func objective_done() -> bool:
	match chapter.kind():
		"fetch":
			return cargo_state == Cargo.DELIVERED
		"protect":
			return loot_left() + in_flight > 0
		"keep":
			return chapter.keep_ok(count_keep() if is_inside_tree() else keep_have, held_count())
		"blast":
			return blast != null and blast.blown
		"salvage", "reckoning":
			return piece != null and bool(piece.call("done"))
	return true


## Host (DownTheHole): the tunnel blew. Waiting on it after the last wave? Then that's the chapter.
func blast_done() -> void:
	if holding and not finished:
		get_tree().create_timer(6.0).timeout.connect(_win)


## Host (a chapter 9/10 set piece): the job's done. Waiting on it after the last
## wave? Then that's the chapter, `delay` seconds on (the radio has its say first).
func piece_done(delay: float) -> void:
	if holding and not finished:
		get_tree().create_timer(maxf(delay, 1.0)).timeout.connect(_win)


## Seconds of radio still queued on this peer (to let a beat finish before the end).
func radio_left() -> float:
	return radio.queued_seconds() if radio != null else 0.0


## Tunnels the canyon-floor raid sites must leave alone in the chapter about to
## be played (Down the Hole's main tunnel, before and after the blast). Pure on
## the chapter data; called by the world before it builds the sites.
static func reserved_tunnels(cliffs: CliffBuilder) -> Array[int]:
	var out: Array[int] = []
	var ch := Story.chapter()
	if ch != null and cliffs != null and (ch.kind() == "blast" or ch.sealed_tunnel):
		out.append(cliffs.main_tunnel())
	return out


## Floor the canyon dressing (rocks, cacti, webs) and the raid sites must keep
## clear of in the chapter about to be played: The Dry Gulch Families'
## homesteads and camp, The Reckoning's railroad. Called by the world before it
## dresses the canyon.
static func reserve_story_ground(cliffs: CliffBuilder) -> void:
	SitePlan.story_zones.clear()
	var ch := Story.chapter()
	if ch == null or cliffs == null:
		return
	match ch.kind():
		"salvage":
			SitePlan.story_zones.append_array(DryGulchFamilies.spots(cliffs))
		"reckoning":
			var route := IronMandible.route_for(cliffs)
			var s := 0.0
			var total := ReckoningRules.length_of(route)
			while s < total:
				var p := ReckoningRules.point_at(route, s)
				if cliffs.wildness(p.z) <= 0.0:
					SitePlan.story_zones.append(p)
				s += 5.0


func _win() -> void:
	if finished:
		return
	finished = true
	GameState.finish(true, "Chapter %d, %s: done." % [chapter.number, chapter.title])


func _lose(reason: String) -> void:
	if finished:
		return
	finished = true
	GameState.finish(false, reason)


## Every peer: book the result in this player's progress, say the closing line
## and put the Notches on the end screen.
func _on_game_over(won: bool, _reason: String) -> void:
	finished = true
	var res := Story.record(chapter, won)
	print("[story] chapter %s %s on wave %d: %s" % [chapter.id, "WON" if won else "LOST", GameState.wave, str(res)])
	if radio != null:
		for l: Array in chapter.event_lines("win" if won else "lost"):
			radio.say(str(l[0]), str(l[1]))
	if tracker != null:
		tracker.visible = false
	if radio != null:
		radio.visible = false # the closing line goes on the front page instead
	if won and not chapter.epilogue.is_empty():
		# The Reckoning: the decree cards over the front page, then the last word.
		var ep := EpilogueView.new()
		ep.name = "EpilogueView"
		ep.chapter = chapter
		add_child(ep)
		StoryAmber.after_reckoning() # WIRE TO AMBER AT MERGE (StoryAmber)
	# Debug: --storyrestart rides on (or retries) by itself a few seconds later.
	if GameState.has_flag("--storyrestart") and GameState.debug_enabled() and multiplayer.is_server():
		var next := StoryChapter.next_id(chapter.id) if won else chapter.id
		if next != "":
			get_tree().create_timer(3.0).timeout.connect(func() -> void: Story.restart(next))
	var lines: Array = []
	if won:
		lines.append(["Chapter %d complete" % chapter.number, "first time" if bool(res.get("first", false)) else "replay", int(res["notches"])])
	if not won:
		return # a lost chapter pays nothing: no Notches panel
	Perks.run_banked.emit({"earned": int(res.get("notches", 0)), "total_run": int(res.get("notches", 0)), "lines": lines,
			"banked": bool(res.get("banked", false)), "brands": Perks.profile.brands, "won": won})


# ------------------------------------------------------------------ host tick

func _host_tick() -> void:
	# Debug: --storykillboss fells any boss 15 s after it shows (gland drop tests).
	if GameState.has_flag("--storykillboss") and GameState.debug_enabled() and GameState.phase == GameState.Phase.WAVE and BugManager.instance != null:
		for c: Node in BugManager.instance.get_children():
			var b := c as Bug
			if b != null and b.is_alive() and b.def.behavior == BugDef.Behavior.BOSS:
				var seen := float(b.get_meta("story_seen", Time.get_ticks_msec() / 1000.0))
				b.set_meta("story_seen", seen)
				if Time.get_ticks_msec() / 1000.0 - seen > 15.0:
					b.receive_hit(99999.0, b.global_position, Vector3.FORWARD, true, 1.0, "revolver", 0)
	if chapter.kind() == "fetch":
		_host_fetch()
	elif chapter.kind() == "keep" and _started and GameState.phase == GameState.Phase.WAVE:
		var now := Time.get_ticks_msec() / 1000.0
		if not chapter.keep_ok(keep_have, held_count()) and now - _short_line_t > SHORT_LINE_GAP:
			_short_line_t = now
			_event.rpc("short")
	elif chapter.kind() == "protect" and _started and not boxes.is_empty():
		if loot_left() + in_flight <= 0:
			_lose("The bandits cleaned out every payroll strongbox.")


# ------------------------------------------------------------------ fetch

func item_name() -> String:
	return str(chapter.objective.get("item_name", "Cargo"))


func _airship_drop() -> void:
	var cids := _held_cliffs()
	var cid: int = cids[randi() % cids.size()]
	var cliffs := world.get("cliffs") as CliffBuilder
	var at := cliffs.plateau_point(cid, randf_range(12.0, 20.0), randf_range(-8.0, 8.0))
	if GameState.flag_value("--storydropat") != "" and GameState.debug_enabled():
		var p := GameState.flag_value("--storydropat").split(",")
		at = cliffs.plateau_point(_local_cliff(), p[0].to_float(), p[1].to_float())
	_spawn_cargo.rpc(at, true, "")


## Host: Dry Season's wrecked supply wagon on the canyon floor, part way from a
## rope foot to the main tunnel (clear of the raid sites), the valve in its bed.
func _floor_wagon() -> void:
	var cliffs := world.get("cliffs") as CliffBuilder
	var tn := cliffs.tunnel(cliffs.main_tunnel())
	var anchor := RopeAnchor.of(_local_cliff())
	var foot: Vector3 = anchor.foot_stand if anchor != null else (tn[0] as Vector3) + (tn[1] as Vector3) * 20.0
	var at := wagon_point(foot, tn[0], tn[1])
	at.y = cliffs.floor_height(at.x, at.z)
	_spawn_cargo.rpc(at, false, "wagon")
	_event.rpc("drop")


## Where the wreck lies: 60% of the way from the rope foot to the tunnel's
## mouth, nudged off the line if a raid site could stand there. Pure.
static func wagon_point(foot: Vector3, mouth: Vector3, out: Vector3) -> Vector3:
	var to := Vector3(mouth.x - foot.x, 0.0, mouth.z - foot.z)
	var side := to.cross(Vector3.UP).normalized() if to.length() > 0.1 else Vector3.RIGHT
	var base := foot + to * 0.6 + out * 0.0
	for k: float in [0.0, 6.0, -6.0, 12.0, -12.0]:
		var p := base + side * k
		if not SitePlan.in_site_zone(p, 1.5):
			return p
	return base


## Host: where a dead boss leaves its prize: where it fell if that's up top,
## else on the plateau above the lane it climbed.
func _boss_drop(bug: Bug) -> void:
	if cargo_state != Cargo.NONE:
		return
	var at := bug.global_position
	var cliffs := world.get("cliffs") as CliffBuilder
	if str(chapter.objective.get("spawn", "")) == "boss_carcass":
		# Her carcass ends up on the canyon floor at the foot of her lane: killed on
		# the wall she falls; killed up top, the crew tips her back over the edge.
		var up_top := bug.state != Bug.State.CLIMBING and bug.state != Bug.State.CROSSING
		_spawn_cargo.rpc(carcass_point(cliffs, bug.cliff_id, bug.lane_z), false, "carcass")
		_event.rpc("drop")
		if up_top:
			_event.rpc("dumped")
		return
	if at.y < WorldLayout.CLIFF_HEIGHT - 1.0 or bug.state == Bug.State.CLIMBING:
		at = cliffs.plateau_point(bug.cliff_id, 7.0, bug.lane_z)
	_spawn_cargo.rpc(at, false, "")
	_event.rpc("drop")


## Where a boss's carcass lands: on the canyon floor a few metres out from the
## foot of cliff `cid` at lane `z`.
static func carcass_point(cliffs: CliffBuilder, cid: int, z: float) -> Vector3:
	var foot := cliffs.face_point(cid, 0.5, z) + WorldLayout.inward(cid) * 5.0
	return Vector3(foot.x, cliffs.floor_height(foot.x, foot.z), foot.z)


@rpc("authority", "call_local", "reliable")
func _spawn_cargo(at: Vector3, falling: bool, dress: String) -> void:
	if cargo != null and is_instance_valid(cargo):
		cargo.queue_free()
	if dress != "":
		if cargo_dressing != null and is_instance_valid(cargo_dressing):
			cargo_dressing.queue_free()
		cargo_dressing = StoryFloorProps.dressing(dress)
		cargo_dressing.name = "CargoDressing"
		world.add_child(cargo_dressing)
		cargo_dressing.global_position = at
		cargo_dressing.rotation.y = fposmod(at.x * 0.37 + at.z * 0.11, TAU)
		at = cargo_dressing.to_global(StoryFloorProps.item_spot(dress))
	cargo = StoryCargo.new()
	cargo.name = "Cargo"
	cargo.kind = str(chapter.objective.get("item", "valve"))
	cargo.title = item_name()
	cargo.director = self
	cargo.on_floor = chapter.pack_item() != &""
	world.add_child(cargo)
	cargo.global_position = at
	cargo_state = Cargo.FALLING if falling else Cargo.GROUND
	if falling:
		cargo.fall_from(at + Vector3.UP * 38.0, func() -> void:
			if cargo_state == Cargo.FALLING:
				cargo_state = Cargo.GROUND
				if multiplayer.is_server() and not finished:
					_event.rpc("drop")
				if tracker != null:
					tracker.refresh())
	if tracker != null:
		tracker.refresh()


## Any peer: E on the cargo.
func request_pickup() -> void:
	if multiplayer.is_server():
		_pickup(multiplayer.get_unique_id())
	else:
		_ask_pickup.rpc_id(1)


@rpc("any_peer", "reliable")
func _ask_pickup() -> void:
	if multiplayer.is_server():
		_pickup(multiplayer.get_remote_sender_id())


func _pickup(peer: int) -> void:
	if cargo_state != Cargo.GROUND or finished:
		return
	var item := chapter.pack_item()
	if item != &"" and Expedition.is_down(peer):
		# Canyon floor: into the backpack (it's heavy); it comes up with you.
		if Expedition.add_to_backpack(peer, {item: 1}) <= 0:
			Economy.notify(peer, "No room in your backpack for the %s. Ride up and unpack, then come back for it." % item_name())
			return
		_set_cargo.rpc(Cargo.PACKED, peer, cargo.global_position if cargo != null else Vector3.ZERO)
		Economy.notify(peer, "The %s is in your backpack. Get it up out of the canyon." % item_name())
	else:
		_set_cargo.rpc(Cargo.CARRIED, peer, cargo.global_position if cargo != null else Vector3.ZERO)
	if not _said.has("ev_pickup"):
		_said["ev_pickup"] = true
		_event.rpc("pickup")


@rpc("authority", "call_local", "reliable")
func _set_cargo(state: int, who: int, at: Vector3) -> void:
	print("[story] cargo %s, carrier %d" % [Cargo.keys()[state], who])
	cargo_state = state as Cargo
	carrier = who
	if cargo != null and is_instance_valid(cargo):
		if state == Cargo.DELIVERED:
			cargo.delivered()
		elif state == Cargo.GROUND:
			cargo.global_position = at
			cargo.set_carried(false, false)
		elif state == Cargo.CARRIED or state == Cargo.PACKED:
			cargo.set_carried(true, who == multiplayer.get_unique_id())
	if state == Cargo.DELIVERED and bool(chapter.objective.get("breaks_wells", false)):
		MechWell.valve_broken = false
	if tracker != null:
		tracker.refresh()


func _follow_carrier() -> void:
	if cargo_state != Cargo.CARRIED and cargo_state != Cargo.PACKED:
		return
	var p := _player_of(carrier)
	if p != null:
		cargo.carry_at(p)


func _host_fetch() -> void:
	var auto_fetch := GameState.has_flag("--storyfetch") or (GameState.has_flag("--storyfetchlate") and holding)
	if auto_fetch and GameState.debug_enabled() and cargo_state == Cargo.GROUND:
		_set_cargo.rpc(Cargo.CARRIED, multiplayer.get_unique_id(), cargo.global_position if cargo != null else Vector3.ZERO)
	if cargo_state == Cargo.PACKED and _player_of(carrier) == null:
		# The carrier left the game with it in their pack: it lies where they were.
		_set_cargo.rpc(Cargo.GROUND, 0, _on_floor(cargo.global_position if cargo != null else Vector3.ZERO))
		return
	if cargo_state != Cargo.CARRIED:
		return
	var p := _player_of(carrier)
	if p == null:
		# The carrier left: the cargo stays where it was.
		_set_cargo.rpc(Cargo.GROUND, 0, cargo.global_position if cargo != null else Vector3.ZERO)
		return
	var target := _delivery_target(p.global_position)
	if target != null:
		_set_cargo.rpc(Cargo.DELIVERED, carrier, target.global_position)
		_event.rpc("delivered")
		if holding:
			get_tree().create_timer(3.0).timeout.connect(_win)


## Host (Expedition): a story item came up out of the canyon in someone's pack.
func _on_item_up(peer: int, item: StringName, _units: int) -> void:
	if finished or item != chapter.pack_item() or cargo_state != Cargo.PACKED:
		return
	_set_cargo.rpc(Cargo.CARRIED, peer, Vector3.ZERO)
	if not _said.has("ev_up"):
		_said["ev_up"] = true
		_event.rpc("up")


## Host (Expedition): its carrier went down on the floor: it lies where they fell.
func _on_item_dropped(_peer: int, item: StringName, _units: int, pos: Vector3) -> void:
	if finished or item != chapter.pack_item():
		return
	_set_cargo.rpc(Cargo.GROUND, 0, _on_floor(pos))


func _on_floor(pos: Vector3) -> Vector3:
	var cliffs := world.get("cliffs") as CliffBuilder
	if cliffs == null or pos.y > WorldLayout.CANYON_FALL_Y:
		return pos
	return Vector3(pos.x, cliffs.floor_height(pos.x, pos.z), pos.z)


## The well or noticeboard within reach of `pos`, if any.
func _delivery_target(pos: Vector3) -> Node3D:
	var to := str(chapter.objective.get("deliver_to", "well"))
	var group := "story_boards" if to == "board" else "water_sources"
	for n: Node in get_tree().get_nodes_in_group(group):
		if to == "well" and not n is MechWell:
			continue
		var node := n as Node3D
		var d := node.global_position - pos
		if Vector2(d.x, d.z).length() < DELIVER_REACH and absf(d.y) < 4.0:
			return node
	# Debug: --storyfetch delivers anywhere after a moment's carry.
	if (GameState.has_flag("--storyfetch") or GameState.has_flag("--storyfetchlate")) and GameState.debug_enabled() and cargo_state == Cargo.CARRIED:
		var nodes := get_tree().get_nodes_in_group(group)
		if not nodes.is_empty():
			return nodes[0] as Node3D
	return null


## Where things to carry to are, for the tracker's marker (local).
func delivery_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var to := str(chapter.objective.get("deliver_to", "well"))
	for n: Node in get_tree().get_nodes_in_group("story_boards" if to == "board" else "water_sources"):
		if to == "well" and not n is MechWell:
			continue
		out.append((n as Node3D).global_position)
	return out


func carrier_name() -> String:
	if carrier == multiplayer.get_unique_id():
		return "You"
	var p: Dictionary = NetworkManager.players.get(carrier, {})
	return str(p.get("name", "A Rancher"))


# ------------------------------------------------------------------ bosses

func _hook_bugs() -> void:
	var bm := BugManager.instance
	if bm != null:
		bm.child_entered_tree.connect(_on_bug_added)


func _on_bug_added(n: Node) -> void:
	var bug := n as Bug
	if bug == null or bug.def == null or not multiplayer.is_server():
		return
	if bug.def.behavior != BugDef.Behavior.BOSS:
		return
	bug.died.connect(func(b: Bug, _s: String, _c: int) -> void: _on_boss_died(b), CONNECT_ONE_SHOT)


func _on_boss_died(bug: Bug) -> void:
	if finished:
		return
	if chapter.kind() == "fetch" and str(chapter.objective.get("spawn", "")) == "boss_drop" \
			and bug.def.base_id() == StringName(str(chapter.objective.get("boss", ""))):
		_boss_drop(bug)
	elif not chapter.event_lines("boss_down").is_empty() and not _said.has("ev_boss"):
		_said["ev_boss"] = true
		_event.rpc("boss_down")


# ------------------------------------------------------------------ protect

func _place_strongboxes() -> void:
	var cliffs := world.get("cliffs") as CliffBuilder
	var spots: Array = []
	for cid in WorldLayout.cliff_count():
		var home := Homestead.of(cid)
		var at: Vector3
		if home != null:
			at = home.to_global(Vector3(-HouseBuilder.W * 0.5 - 1.7, 0.0, -0.6))
		else:
			at = cliffs.plateau_point(cid, 20.0, 4.0)
		spots.append(at)
	_spawn_boxes.rpc(spots, int(chapter.objective.get("loot_each", 6)))


@rpc("authority", "call_local", "reliable")
func _spawn_boxes(spots: Array, loot: int) -> void:
	for b in boxes:
		if is_instance_valid(b):
			b.queue_free()
	boxes.clear()
	for i in spots.size():
		var box := StoryStrongbox.new()
		box.name = "Strongbox%d" % i
		box.cliff_id = i
		box.loot = loot
		box.director = self
		world.add_child(box)
		box.global_position = spots[i]
		var home := Homestead.of(i)
		if home != null:
			box.global_rotation.y = home.global_rotation.y + PI * 0.5
		boxes.append(box)
	if tracker != null:
		tracker.refresh()


func loot_left() -> int:
	var n := 0
	for b in boxes:
		if is_instance_valid(b):
			n += b.loot
	return n


func loot_total() -> int:
	return boxes.size() * int(chapter.objective.get("loot_each", 6))


## Host (StoryStrongbox.bandit_steal): a bandit takes a sack from box `i`. Shot
## down, it drops the sack back in the box; if it gets away, it's gone.
func bandit_took(i: int, bug: Bug) -> void:
	if i < 0 or i >= boxes.size() or boxes[i].loot <= 0:
		return
	in_flight += 1
	_box_loot.rpc(i, boxes[i].loot - 1, in_flight, escaped)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _steal_line_t > STEAL_LINE_GAP:
		_steal_line_t = now
		_event.rpc("steal")
	bug.died.connect(func(_b: Bug, _s: String, _c: int) -> void:
		in_flight -= 1
		if i < boxes.size() and is_instance_valid(boxes[i]):
			_box_loot.rpc(i, boxes[i].loot + 1, in_flight, escaped)
		if not _said.has("ev_recovered"):
			_said["ev_recovered"] = true
			_event.rpc("recovered"), CONNECT_ONE_SHOT)
	bug.fled.connect(func(_b: Bug) -> void:
		in_flight -= 1
		escaped += 1
		_box_loot.rpc(i, boxes[i].loot if i < boxes.size() else 0, in_flight, escaped)
		if not _said.has("ev_escaped"):
			_said["ev_escaped"] = true
			_event.rpc("escaped"), CONNECT_ONE_SHOT)


@rpc("authority", "call_local", "reliable")
func _box_loot(i: int, loot: int, flying: int, gone: int) -> void:
	in_flight = flying
	escaped = gone
	if i >= 0 and i < boxes.size() and is_instance_valid(boxes[i]):
		boxes[i].set_loot(loot)
	if tracker != null:
		tracker.refresh()


# ------------------------------------------------------------------ keep

## How many held cliffs the keep objective counts.
func held_count() -> int:
	return _held_cliffs().size() if is_inside_tree() else 1


## keep: what's standing on the held cliffs now (local; scaffolds and
## structures are replicated, so every peer counts the same).
func count_keep() -> int:
	if not is_inside_tree():
		return keep_have
	var cliffs := _held_cliffs()
	match chapter.keep_thing():
		"storeys":
			var bm := BuildManager.instance
			return count_storeys(bm.find_children("*", "", true, false) if bm != null else [], cliffs)
		"lanterns":
			return count_lanterns(get_tree().get_nodes_in_group("lanterns"), cliffs)
	return 0


## Scaffold storeys standing on `cliffs` (pure; tested).
static func count_storeys(scaffolds: Array, cliffs: Array[int]) -> int:
	var n := 0
	for o: Variant in scaffolds:
		var sc := o as ScaffoldNode
		if sc != null and cliffs.has(sc.cliff_id) and not sc.is_queued_for_deletion():
			n += sc.levels
	return n


## Lantern posts standing on `cliffs` (a lit lighter or a flare doesn't count; pure).
static func count_lanterns(nodes: Array, cliffs: Array[int]) -> int:
	var n := 0
	for o: Variant in nodes:
		var s := o as StructureNode
		if s != null and cliffs.has(s.cliff_id) and not s.is_queued_for_deletion() and (s.health == null or not s.health.dead):
			n += 1
	return n


func keep_noun(count: int) -> String:
	if chapter.keep_thing() == "lanterns":
		return "lantern post" if count == 1 else "lantern posts"
	return "scaffold storey" if count == 1 else "scaffold storeys"


func _keep_lost_reason() -> String:
	var need := chapter.keep_need(held_count())
	return "Night's end with %d of %d %s standing." % [count_keep(), need, keep_noun(need)]


# ------------------------------------------------------------------ noticeboards

## Every peer: a noticeboard with the chapter's telegram on every house.
func _make_boards() -> void:
	var homes := get_tree().get_nodes_in_group("homesteads")
	if homes.size() < WorldLayout.cliff_count():
		return
	_boards_made = true
	for h: Node in homes:
		var board := NoticeBoard.new()
		board.name = "NoticeBoard"
		board.director = self
		(h as Node3D).add_child(board)


# ------------------------------------------------------------------ blueprints

@rpc("any_peer", "reliable")
func _tell_blueprints(ids: Array) -> void:
	if multiplayer.is_server():
		var from := multiplayer.get_remote_sender_id()
		if _started:
			_give_blueprints(from, ids)
		else:
			_blueprints_from[from] = ids


## Host: one ready-made turret of each blueprint for that rider's cliff (once).
func _give_blueprints(peer: int, ids: Array) -> void:
	var cid := NetworkManager.cliff_of(peer) if NetworkManager.players.has(peer) else _local_cliff()
	var gift := {}
	for id: Variant in ids:
		if Defs.turret(StringName(str(id))) != null:
			gift[StringName(str(id))] = 1
	if not gift.is_empty():
		Economy.earn(cid, gift)
	for other: int in _blueprints_from:
		var later: Array = _blueprints_from[other]
		_blueprints_from.erase(other)
		_give_blueprints(other, later)
		break


# ------------------------------------------------------------------ helpers

func _held_cliffs() -> Array[int]:
	var out: Array[int] = []
	for id: int in NetworkManager.players:
		var c := NetworkManager.cliff_of(id)
		if not out.has(c):
			out.append(c)
	if out.is_empty():
		out.append(_local_cliff())
	return out


func _local_cliff() -> int:
	var p := world.call("local_player") as Player
	return p.cliff_id if p != null else 0


func _player_of(peer: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n is Player and n.get_multiplayer_authority() == peer:
			return n as Player
	return null
