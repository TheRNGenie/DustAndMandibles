class_name TutorialRun
extends Node
## The tutorial (main menu > Tutorial): an offline solo run on the canyon that
## walks through the core loop in about five minutes, one short card at a time
## (TutorialCard), with a marker on the thing to look at and a tick when each
## step is done. Steps: find your feet, shoot practice Dust Mites on your
## partner's wall, the cross-cliff idea (a coverage cone), build a Gatling Post,
## sell it and build it again, throw your lever, hold a tiny scripted wave, fill
## your bucket and water a seedling, the airship's gunsmith and market, the
## Workshop. Then "You're Ready": Back to Menu or Keep Playing.
##
## Safe by design: Homesteads take no damage while it runs (GameState.god_mode),
## the first wave is six slow Dust Mites (wave_plan), and with GameState.tutorial
## set the run is never saved (RunSaver) and pays no Notches (Perks). Finishing
## marks Settings.tutorial_done so the first-wave hint cards stay away.
##
## Test flags: --tutorialstep=N starts at step N (screenshots), --tutorialrun
## does every step by itself and quits at the end (smoke test), and
## --tutorialshot=<png> saves a screenshot --seconds (default 5) after the
## starting step shows, then quits.

enum Step { MOVE, SHOOT, IDEA, BUILD, SELL, LEVER, WAVE, WATER, AIRSHIP, WORKSHOP, DONE }

## The practice bug and the wave's bug: a Dust Mite at 60% speed (Defs.bug).
const SLOW_MITE := TutorialPlan.SLOW_MITE
const PRACTICE := 3
## Seconds a "look at it" step needs the marker near the middle of the screen.
const DWELL := 1.2
## Seconds before a stuck step offers a skip.
const SKIP_AFTER := 45.0
## Seconds the finished card stays (all ticked) before the next one.
const TICK_HOLD := 1.3
## Scrap the tutorial makes sure you have (two Gatling Posts and change).
const SCRAP_FLOOR := 160

## Per step: card title and body (short), the sub-tasks ticked off one by one,
## the keys shown ([action, words]; "accept" is Enter / pad A), the marker's
## caption, and whether looking at the marker finishes it.
const STEPS: Array[Dictionary] = [
	{"title": "Find Your Feet", "body": "This is your homestead on the West Cliff. Walk about and have a look round.",
		"tasks": ["Walk a Few Steps", "Look Around"], "keys": [["move", "Move"], ["jump", "Jump"], ["sprint", "Sprint"]]},
	{"title": "Shoot the Dust Mites", "body": "Practice bugs are climbing the far wall across the canyon. Step up to your edge and pop them.",
		"tasks": ["Dust Mites Shot"], "keys": [["fire", "Shoot"], ["reload", "Reload"]], "marker": "Dust Mite"},
	{"title": "Across the Canyon", "body": "Turrets on your lip can't dip below thirty degrees, so they shoot across the canyon. The green patch is the wall one would cover.",
		"tasks": ["Look at the Covered Wall"], "keys": [["accept", "Continue"]], "marker": "Covered Wall", "look": true},
	{"title": "Build a Gatling Post", "body": "Open the build menu, pick the Gatling Post and place it on the marked lip. Turrets cost chitin from the team pot you share with your partner (every bug you kill pays into it).",
		"tasks": ["Open the Build Menu", "Pick the Gatling Post", "Place It on Your Lip"],
		"keys": [["build_menu", "Build Menu"], ["fire", "Place"], ["alt_fire", "Cancel"]], "marker": "Your Lip"},
	{"title": "Sell It and Build Again", "body": "Changed your mind? Aim at a build and sell it for half its chitin back, then put it up again.",
		"tasks": ["Sell the Gatling Post", "Place It Again"], "keys": [["demolish", "Sell"], ["build_menu", "Build Menu"]], "marker": "Gatling Post"},
	{"title": "Throw Your Lever", "body": "The breaker on your generator is how you ready up. Once every lever is thrown the engines start, the pump fills your water tower and the wave comes.",
		"tasks": ["Throw the Lever"], "keys": [["interact", "Throw Lever"]], "marker": "Generator"},
	{"title": "Hold the Wave", "body": "A few slow Dust Mites climb the far wall: your Gatling Post has it covered, so help it out. While the engine runs, the pump fills your tower.",
		"tasks": ["Wave Held"], "keys": [["fire", "Shoot"]], "marker": "Dust Mite"},
	{"title": "Water Your Crops", "body": "The well trough and the water tower tap fill your bucket. Water a seedling and it grows into food.",
		"tasks": ["Fill Your Bucket", "Water the Seedling"], "keys": [["select_8", "Bucket"], ["interact", "Fill or Water"]], "marker": "Well"},
	{"title": "The Lucky Mandible", "body": "The airship over the canyon holds the gunsmith (guns and upgrades for your own scrap, from the junk heap by the house) and the market (sell crops, buy seeds). Climb an arch and grapple its ring.",
		"tasks": ["Look at the Airship"], "keys": [["select_10", "Grapple"], ["accept", "Continue"]], "marker": "Gunsmith and Market", "look": true},
	{"title": "Workshop and Crafted Turrets", "body": "Buy a Workshop at the ledger in your house. Its bench joins parts from big bugs into crafted turrets, placed from the build menu's Crafted tab.",
		"tasks": ["Look at the House Ledger"], "keys": [["accept", "Continue"]], "marker": "House Ledger", "look": true},
]

static var instance: TutorialRun

var world: Node3D
var player: Player
var cliffs: CliffBuilder
var card: TutorialCard
var me := WorldLayout.WEST
var other := WorldLayout.EAST
var step := -1
var _tasks: Array[bool] = []
var _t := 0.0 # seconds on this step
var _hold := -1.0 # counting down the ticked card, then the next step
var _dwell := 0.0
var _begun := false
var _cell := Vector2i(0, 10) # the lip cell the Gatling Post goes on
var _preview: CoveragePreview
var _kills := 0
var _spawned := 0
var _start_pos := Vector3.ZERO
var _turned := 0.0
var _last_yaw := 0.0
var _water0 := 0
var _plot: CropPlot
var _gatling_id := 0 # the first Gatling Post (the one to sell)
var _auto := false
var _frozen := false
var _auto_t := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	GameState.god_mode = false


func _ready() -> void:
	_auto = GameState.has_flag("--tutorialrun")
	cliffs = world.get("cliffs") as CliffBuilder
	var bugs := world.get("bugs") as BugManager
	bugs.bug_killed.connect(_on_bug_killed)
	card = TutorialCard.new()
	card.name = "TutorialCard"
	card.run = self
	(world.get("hud") as Node).add_child(card)


## The tutorial's first wave (WaveDirector asks while GameState.tutorial is set).
static func wave_plan() -> Dictionary:
	return TutorialPlan.wave(instance.other if instance != null else WorldLayout.EAST)


func _process(delta: float) -> void:
	if not _begun:
		_try_begin()
		return
	if player == null or not is_instance_valid(player) or step < 0 or step >= Step.DONE:
		return
	_t += delta
	if _frozen: # --tutorialshot: hold the starting step for the picture
		card.set_marker(_marker(), str(STEPS[step].get("marker", "")))
		return
	if _hold >= 0.0:
		_hold -= delta
		if _hold < 0.0:
			_enter(step + 1)
		return
	_check(delta)
	if _auto:
		_auto_t += delta
		if _auto_t > 1.0:
			_auto_step()
	card.set_marker(_marker(), str(STEPS[step].get("marker", "")))
	card.show_skip(_t > SKIP_AFTER and not STEPS[step].get("look", false))


func _try_begin() -> void:
	player = world.call("local_player") as Player
	if player == null or not player.is_node_ready() or GameState.phase != GameState.Phase.BUILD:
		return
	_begun = true
	me = player.cliff_id
	other = WorldLayout.other_cliff(me)
	GameState.god_mode = true # practice: the houses take no damage
	var short := SCRAP_FLOOR - Economy.amount(me, &"scrap")
	if short > 0:
		Economy.earn(me, {&"scrap": short})
	for c: Vector2i in [Vector2i(0, 10), Vector2i(0, 9), Vector2i(0, 11), Vector2i(0, 8), Vector2i(0, 12), Vector2i(0, 7)]:
		if Buildable.cell_ok_for(&"gatling_post", c) and BuildManager.instance.is_free_for(&"gatling_post", me, c):
			_cell = c
			break
	var first := clampi(int(GameState.flag_value("--tutorialstep")), 0, Step.DONE)
	if first > Step.SELL and first <= Step.WAVE:
		_build_gatling() # later steps want the turret standing
	if first == Step.SELL:
		_build_gatling()
	print("[tutorial] begin on cliff %d, Gatling Post cell %s, starting at step %d" % [me, str(_cell), first])
	_enter(first)
	if first == Step.WAVE:
		GameState.toggle_ready()
	var shot := GameState.flag_value("--tutorialshot")
	if shot != "":
		_frozen = true
		# --pos=d,z (metres back from the lip, along the canyon) and --look=yaw,pitch place the camera.
		var pos := GameState.flag_value("--pos").split(",")
		if pos.size() == 2:
			player.global_position = cliffs.plateau_point(me, pos[0].to_float(), pos[1].to_float()) + Vector3.UP * 0.2
		var look := GameState.flag_value("--look").split(",")
		if look.size() == 2:
			player.rotation.y += deg_to_rad(look[0].to_float())
			player.head.rotation.x = deg_to_rad(look[1].to_float())
		var secs := GameState.flag_value("--seconds").to_float()
		get_tree().create_timer(secs if secs > 0.0 else 5.0).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(shot)
			print("[tutorial] saved ", shot)
			get_tree().quit())


# ------------------------------------------------------------------ steps

func _enter(s: int) -> void:
	step = s
	_t = 0.0
	_hold = -1.0
	_dwell = 0.0
	_auto_t = 0.0
	if _preview != null and s != Step.IDEA:
		_preview.queue_free()
		_preview = null
	if s >= Step.DONE:
		_finish()
		return
	_tasks.clear()
	for i in (STEPS[s]["tasks"] as Array).size():
		_tasks.append(false)
	match s:
		Step.MOVE:
			_start_pos = player.global_position
			_last_yaw = player.rotation.y
			_turned = 0.0
		Step.SHOOT:
			_kills = 0
			_spawned = 0
			_spawn_practice(PRACTICE)
		Step.IDEA:
			_show_cone()
		Step.SELL:
			var g := _my_gatling()
			_gatling_id = g.get_instance_id() if g != null else 0
		Step.WATER:
			_water0 = Economy.amount(me, &"water")
			_prepare_water()
	print("[tutorial] step %d: %s" % [s, STEPS[s]["title"]])
	card.show_step(s, Step.DONE, STEPS[s], _task_words())


## Ticks this step's sub-tasks off from what's happening in the world.
func _check(delta: float) -> void:
	var before := _tasks.duplicate()
	match step:
		Step.MOVE:
			var flat := player.global_position - _start_pos
			flat.y = 0.0
			if flat.length() > 4.0:
				_tasks[0] = true
			_turned += absf(angle_difference(_last_yaw, player.rotation.y))
			_last_yaw = player.rotation.y
			if _turned > deg_to_rad(100.0):
				_tasks[1] = true
		Step.SHOOT:
			if _kills >= PRACTICE:
				_tasks[0] = true
			elif _practice_alive() == 0 and _t > 3.0 and _spawned - _kills < PRACTICE:
				_spawn_practice(PRACTICE - _kills) # one got away: send another
			card.set_task_text(0, "Dust Mites Shot: %d / %d" % [mini(_kills, PRACTICE), PRACTICE])
		Step.IDEA, Step.AIRSHIP, Step.WORKSHOP:
			if _looking_at(_marker()) and _t > 1.5:
				_dwell += delta
			if _dwell >= DWELL:
				_tasks[0] = true
		Step.BUILD:
			var bm := player.build_mode
			if bm != null and (bm.menu_open or bm.active):
				_tasks[0] = true
			if bm != null and bm.active and bm.selected_id() == &"gatling_post":
				_tasks[0] = true
				_tasks[1] = true
			if _my_gatling() != null:
				_tasks = [true, true, true]
		Step.SELL:
			var g := _my_gatling()
			var gid := g.get_instance_id() if g != null else 0
			if _gatling_id == 0:
				_gatling_id = gid # (it went up a moment after the step began)
			elif not _tasks[0] and gid != _gatling_id:
				_tasks[0] = true
			if _tasks[0] and gid != 0 and gid != _gatling_id:
				_tasks[1] = true
		Step.LEVER:
			if GameState.lever_thrown(me) or GameState.phase != GameState.Phase.BUILD:
				_tasks[0] = true
		Step.WAVE:
			if GameState.phase == GameState.Phase.BUILD and GameState.wave >= 2:
				_tasks[0] = true
		Step.WATER:
			if Economy.amount(me, &"water") > _water0:
				_tasks[0] = true
			_water0 = mini(_water0, Economy.amount(me, &"water")) # watering spends some first: still counts the fill
			if _plot != null and is_instance_valid(_plot) and (_plot.growth.watered or _plot.growth.stage >= CropGrowth.Stage.GROWING):
				_tasks[1] = true
	if _tasks != before:
		card.set_tasks(_tasks)
		if not _tasks.has(false):
			_hold = TICK_HOLD
			card.tick()
			print("[tutorial] step %d done (%.1f s)" % [step, _t])


## Enter / pad A: carries on from a "look at it" card, or skips a stuck step.
func accept_pressed() -> void:
	if step < 0 or step >= Step.DONE or _hold >= 0.0:
		return
	var look: bool = STEPS[step].get("look", false)
	if (look and _t > 1.0) or _t > SKIP_AFTER:
		for i in _tasks.size():
			_tasks[i] = true
		card.set_tasks(_tasks)
		_hold = 0.4
		card.tick()
		if step == Step.LEVER and GameState.phase == GameState.Phase.BUILD and not GameState.lever_thrown(me):
			GameState.toggle_ready()
		print("[tutorial] step %d continued by key" % step)


func _task_words() -> Array:
	var words: Array = (STEPS[step]["tasks"] as Array).duplicate()
	if step == Step.SHOOT:
		words[0] = "Dust Mites Shot: 0 / %d" % PRACTICE
	return words


func _on_bug_killed(_bug: String, _bug_cliff: int, _source: String, _source_cliff: int, _loot: Dictionary) -> void:
	if step == Step.SHOOT:
		_kills += 1


# ------------------------------------------------------------------ world setup

## Practice mites part way up your partner's wall, spread over the middle lanes.
func _spawn_practice(n: int) -> void:
	var bm := WaveDirector.bug_manager
	if bm == null or not multiplayer.is_server():
		return
	for i in n:
		bm.spawn_group(SLOW_MITE, 1, other, [2, 1, 3][(_spawned + i) % 3], 40.0 - float(i) * 3.0)
	_spawned += n


func _practice_alive() -> int:
	var bm := WaveDirector.bug_manager
	return bm.alive_count() if bm != null else 0


## The coverage cone of a Gatling Post on your lip, painted on the far wall.
func _show_cone() -> void:
	_preview = CoveragePreview.new()
	_preview.cliffs = cliffs
	world.add_child(_preview)
	_preview.show_for(&"gatling_post", me, _lip_point(), 0, true)


func _lip_point() -> Vector3:
	return Buildable.footprint_center(cliffs, me, &"gatling_post", _cell) + Vector3.UP * ScaffoldNode.turret_height(0)


func _my_gatling() -> Node3D:
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t != null and not t.is_queued_for_deletion() and t.cliff_id == me and t.def != null and t.def.id == &"gatling_post":
			return t
	return null


func _build_gatling() -> void:
	if _my_gatling() == null:
		BuildManager.instance.build(&"gatling_post", me, _cell)


## Water step: a corn seedling planted on the plot nearest the well, and some
## water in the trough (the wave's pumping usually filled it already).
func _prepare_water() -> void:
	var well := _well()
	if well != null and multiplayer.is_server() and well.stored < WaterSource.BUCKET:
		well.stored = maxi(well.capacity, WaterSource.BUCKET)
		well._sync.rpc(well.stored)
	_plot = null
	var best := INF
	var at := well.global_position if well != null else player.global_position
	for n: Node in get_tree().get_nodes_in_group("crops"):
		var p := n as CropPlot
		if p == null or p.cliff_id != me:
			continue
		var d := p.global_position.distance_to(at)
		if d < best:
			best = d
			_plot = p
	if _plot != null and multiplayer.is_server() and _plot.growth.stage == CropGrowth.Stage.EMPTY:
		_plot.crop_def = Defs.crop(&"corn")
		_plot.growth.plant(_plot.crop_def)
		_plot._broadcast()


func _well() -> WaterSource:
	for n: Node in get_tree().get_nodes_in_group("water_sources"):
		if n is MechWell and (n as MechWell).cliff_id == me:
			return n as WaterSource
	return null


# ------------------------------------------------------------------ the marker

## Where this step's marker points (null: no marker).
func _marker() -> Variant:
	match step:
		Step.SHOOT, Step.WAVE:
			var b := _nearest_bug()
			if b != null:
				return b.global_position + Vector3.UP * 0.8
			if step == Step.WAVE:
				var tower := WaterTower.of(me)
				return tower.global_position + Vector3.UP * 6.0 if tower != null else null
			return null
		Step.IDEA:
			return cliffs.face_point(other, WorldLayout.CLIFF_HEIGHT - 5.0, _lip_point().z)
		Step.BUILD:
			return _lip_point() + Vector3.UP * 1.2
		Step.SELL:
			var g := _my_gatling()
			if _tasks.size() > 0 and not _tasks[0] and g != null:
				return g.global_position + Vector3.UP * 2.0
			return _lip_point() + Vector3.UP * 1.2
		Step.LEVER:
			var gen := Generator.of(me)
			return gen.global_position + Vector3.UP * 1.6 if gen != null else null
		Step.WATER:
			if _tasks.size() > 0 and not _tasks[0]:
				var w := _well()
				return w.global_position + Vector3.UP * 1.5 if w != null else null
			return _plot.global_position + Vector3.UP * 0.8 if _plot != null and is_instance_valid(_plot) else null
		Step.AIRSHIP:
			var ship := world.get_node_or_null("Airship")
			var shop := ship.get_node_or_null("GunShop") as Node3D if ship != null else null
			if shop != null:
				return shop.global_position + Vector3.UP * 2.0
			return Airship.ring_position()
		Step.WORKSHOP:
			var home := Homestead.of(me)
			var ledger := home.get_node_or_null("Ledger") as Node3D if home != null else null
			return ledger.global_position + Vector3.UP * 1.2 if ledger != null else null
	return null


func _nearest_bug() -> Node3D:
	var bm := WaveDirector.bug_manager
	if bm == null:
		return null
	var best: Node3D = null
	var bd := INF
	for c: Node in bm.get_children():
		var b := c as Bug
		if b == null or not b.is_alive():
			continue
		var d := b.global_position.distance_squared_to(player.global_position)
		if d < bd:
			bd = d
			best = b
	return best


## Is the camera pointed at `pos` (within a few degrees of the crosshair)?
func _looking_at(pos: Variant) -> bool:
	if pos == null or player.camera == null:
		return false
	var cam := player.camera
	var to := (pos as Vector3) - cam.global_position
	if to.length() < 0.1:
		return true
	var fwd := -cam.global_basis.z
	return fwd.dot(to.normalized()) > cos(deg_to_rad(14.0))


# ------------------------------------------------------------------ the end

func _finish() -> void:
	print("[tutorial] finished")
	card.set_marker(null, "")
	if not GameState.has_flag("--debug") and not Settings.tutorial_done:
		Settings.set_value("tutorial_done", true)
	if _auto:
		print("[tutorial] smoke run complete: every step done")
		get_tree().create_timer(2.0).timeout.connect(func() -> void: get_tree().quit())
	card.show_finish()


## Back to Menu (the finish card).
func to_menu() -> void:
	GameState.menu_open = false
	GameState.god_mode = false
	NetworkManager.leave()
	GameState.reset()
	get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)


## Keep Playing: the waves carry on as a normal run (still never saved, no
## Notches), and the houses can be hurt again.
func keep_playing() -> void:
	GameState.god_mode = false
	card.set_marker(null, "")


# ------------------------------------------------------------------ --tutorialrun

## Does the current step by itself (smoke test).
func _auto_step() -> void:
	match step:
		Step.MOVE:
			player.global_position += -player.global_basis.z * 5.0
			player.rotation.y += PI * 0.7
			_auto_t = 0.0
		Step.SHOOT:
			for c: Node in WaveDirector.bug_manager.get_children():
				var b := c as Bug
				if b != null and b.is_alive():
					b.receive_hit(999.0, b.global_position, Vector3.FORWARD, true, 1.0, "revolver", me)
					break
			_auto_t = 0.5
		Step.IDEA, Step.AIRSHIP, Step.WORKSHOP:
			accept_pressed()
		Step.BUILD:
			_build_gatling()
			_auto_t = -2.0
		Step.SELL:
			var g := _my_gatling()
			if not _tasks[0] and g != null:
				BuildManager.instance.demolish_node(g)
			elif _tasks[0]:
				_build_gatling()
			_auto_t = -1.0
		Step.LEVER:
			if not GameState.lever_thrown(me):
				GameState.toggle_ready()
			_auto_t = -5.0
		Step.WAVE:
			# Let the Gatling Post do the work; after two minutes, finish the stragglers.
			if _t > 120.0:
				for c: Node in WaveDirector.bug_manager.get_children():
					var b := c as Bug
					if b != null and b.is_alive():
						b.receive_hit(999.0, b.global_position, Vector3.FORWARD, true, 1.0, "revolver", me)
			_auto_t = -4.0
		Step.WATER:
			var w := _well()
			if not _tasks[0] and w != null:
				w._use(1)
			elif _plot != null:
				_plot._use(1, &"corn")
			_auto_t = 0.0
