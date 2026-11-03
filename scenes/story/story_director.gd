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
## - fetch: a thing to carry (E picks it up) to a well or a noticeboard. It
##   comes by airship drop (Dry Season's pump valve) or drops where a boss dies
##   (The Survey Map's Queen Spider gland).
## - protect: payroll strongboxes by every house that Dragonfly Bandits rob;
##   shoot a bandit with a sack and the silver goes back. All of it gone loses.
##
## Debug (with --debug): --story=N plays chapter N, --storywave=W starts at wave W
## of it, --storyfetch carries the fetch item to you at once, --storywin /
## --storylose end the chapter after --seconds (screenshots of the end screen).

enum Cargo { NONE, FALLING, GROUND, CARRIED, DELIVERED }

const DELIVER_REACH := 3.6
## Seconds between "a bandit's got a sack" lines.
const STEAL_LINE_GAP := 25.0

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
# Protect: one strongbox per cliff; loot per box (every peer).
var boxes: Array[StoryStrongbox] = []
var in_flight := 0
var escaped := 0
## Host: the last wave is cleared and the chapter waits on its objective.
var holding := false
var finished := false

var _started := false
var _boards_made := false
var _said: Dictionary = {}
var _steal_line_t := -999.0
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
	if GameState.has_flag("--telegram"):
		get_tree().create_timer(2.5).timeout.connect(func() -> void: telegram.open())


## The wave the run starts on (Debug: --storywave=W inside the chapter).
func start_wave() -> int:
	var w := chapter.first_wave
	if GameState.debug_enabled() and GameState.flag_value("--storywave") != "":
		w = clampi(int(GameState.flag_value("--storywave")), chapter.first_wave, chapter.last_wave)
	return w


func _process(_delta: float) -> void:
	if not _boards_made:
		_make_boards()
	if cargo != null and is_instance_valid(cargo):
		_follow_carrier()
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
				_say_lines(chapter.lines(w - 1, "held"), "held%d" % (w - 1))
			_say_lines(chapter.lines(w, "build"), "build%d" % w)
			if multiplayer.is_server():
				_host_build(w)
		GameState.Phase.WAVE:
			_say_lines(chapter.lines(w, "wave"), "wave%d" % w)
			if multiplayer.is_server() and chapter.kind() == "fetch" and cargo_state != Cargo.DELIVERED and cargo_state != Cargo.NONE:
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
	if chapter.kind() == "fetch" and str(chapter.objective.get("spawn", "")) == "airship_drop":
		if cargo_state == Cargo.NONE and w >= int(chapter.objective.get("drop_wave", chapter.first_wave)):
			_airship_drop()


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
	print("[story] last wave %d cleared, objective done: %s" % [GameState.wave, objective_done()])
	if objective_done():
		_win()
	else:
		holding = true
		_set_holding.rpc()
		_event.rpc("hold")


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
	return true


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
	# Debug: --storyrestart rides on (or retries) by itself a few seconds later.
	if GameState.has_flag("--storyrestart") and GameState.debug_enabled() and multiplayer.is_server():
		var next := StoryChapter.next_id(chapter.id) if won else chapter.id
		if next != "":
			get_tree().create_timer(3.0).timeout.connect(func() -> void: Story.restart(next))
	var lines: Array = []
	if won:
		lines.append(["Chapter %d complete" % chapter.number, "first time" if bool(res.get("first", false)) else "replay", int(res["notches"])])
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
	_spawn_cargo.rpc(at, true)


## Host: where a dead boss leaves its prize: where it fell if that's up top,
## else on the plateau above the lane it climbed.
func _boss_drop(bug: Bug) -> void:
	if cargo_state != Cargo.NONE:
		return
	var at := bug.global_position
	var cliffs := world.get("cliffs") as CliffBuilder
	if at.y < WorldLayout.CLIFF_HEIGHT - 1.0 or bug.state == Bug.State.CLIMBING:
		at = cliffs.plateau_point(bug.cliff_id, 7.0, bug.lane_z)
	_spawn_cargo.rpc(at, false)
	_event.rpc("drop")


@rpc("authority", "call_local", "reliable")
func _spawn_cargo(at: Vector3, falling: bool) -> void:
	if cargo != null and is_instance_valid(cargo):
		cargo.queue_free()
	cargo = StoryCargo.new()
	cargo.name = "Cargo"
	cargo.kind = str(chapter.objective.get("item", "valve"))
	cargo.title = item_name()
	cargo.director = self
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
		elif state == Cargo.CARRIED:
			cargo.set_carried(true, who == multiplayer.get_unique_id())
	if state == Cargo.DELIVERED and bool(chapter.objective.get("breaks_wells", false)):
		MechWell.valve_broken = false
	if tracker != null:
		tracker.refresh()


func _follow_carrier() -> void:
	if cargo_state != Cargo.CARRIED:
		return
	var p := _player_of(carrier)
	if p != null:
		cargo.carry_at(p)


func _host_fetch() -> void:
	if GameState.has_flag("--storyfetch") and GameState.debug_enabled() and cargo_state == Cargo.GROUND:
		_pickup(multiplayer.get_unique_id())
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
	if GameState.has_flag("--storyfetch") and GameState.debug_enabled() and cargo_state == Cargo.CARRIED:
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
