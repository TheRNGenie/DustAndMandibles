class_name TutorialRun
extends Node
## The tutorial (main menu > Tutorial): an offline solo run on the canyon that
## walks through the game one short card at a time (TutorialCard), with a marker
## on the thing to look at and a tick when each step is done. Hands-on steps
## (move, shoot, build, sell, the lever, the wave, farming, the grapple, the
## market, the house upgrades, the Workshop) tick off from what you actually do;
## reading cards (guns, turret kinds, weather, scrap and chitin, gun upgrades)
## carry on with Enter once they've been up a moment. Then "You're Ready": Back
## to Menu or Keep Playing.
##
## Safe by design: Homesteads take no damage while it runs (GameState.god_mode),
## the first wave is six slow Dust Mites (wave_plan), and with GameState.tutorial
## set the run is never saved (RunSaver) and pays no Notches (Perks). Finishing
## marks Settings.tutorial_done so the first-wave hint cards stay away. The
## tutorial hands out what its steps need (scrap, a seed, corn, the house money,
## three turret parts), and grows its one crop fast.
##
## Test flags: --tutorialstep=N (or a step's name, e.g. =house) starts at that
## step, --tutorialrun does every step by itself (from that step) and quits at
## the end (smoke test; --tutorialstay keeps the game open after),
## --tutorialshots=<dir> saves a screenshot of every card and every tick along
## the way, and --tutorialshot=<png> saves one screenshot --seconds (default 5)
## after the starting step shows, then quits (--tutorialaim points the camera
## near the step's marker for it).

const Step := TutorialPlan.Step
const STEPS := TutorialPlan.STEPS
const SLOW_MITE := TutorialPlan.SLOW_MITE
const PRACTICE := 3
const DWELL := TutorialPlan.DWELL
const LOOK_MIN := TutorialPlan.LOOK_MIN
const READ_MIN := TutorialPlan.READ_MIN
## Seconds before a stuck step offers a skip.
const SKIP_AFTER := 45.0
## Seconds the finished card stays (all ticked) before the next one.
const TICK_HOLD := 1.3
## Scrap the tutorial makes sure you have (two Gatling Posts and change).
const SCRAP_FLOOR := 160
## What --tutorialrun puts up in the Gatling Post's place on the sell step.
const SWAP_TURRET := &"scattergun_post"
## The farm step's crop grows this many times faster (corn in about eight seconds).
const GROW_FAST := 15.0
## Seconds on the rope that count as a swing or a reel.
const ROPE_TIME := 0.35
const HOUSE_UPGRADES := TutorialPlan.HOUSE_UPGRADES
const PARTS := TutorialPlan.PARTS


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
var _grow_sync := 0.0
var _gatling_id := 0 # the first Gatling Post (the one to sell)
var _swing_t := 0.0
var _reel_t := 0.0
var _rope0 := INF
var _corn0 := 0
## The design the Workshop step's three parts make.
var _craft_id: StringName = &""
var _auto := false
var _frozen := false
var _auto_t := 0.0
## Seconds into this step when its line has been said (voice gating).
var _line_end := 0.0
var _waiting := false
var _shots := "" # --tutorialshots: a folder for a picture of every card and tick
var _shot_n := 0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	GameState.god_mode = false


func _ready() -> void:
	_auto = GameState.has_flag("--tutorialrun")
	_shots = GameState.flag_value("--tutorialshots")
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	_craft_id = CraftTable.design_id(&"swivel", &"scatter", &"fire")
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
		var at: Variant = _marker()
		if at != null and GameState.has_flag("--tutorialaim"): # (a little above the marker, so it shows)
			_aim_at((at as Vector3) + Vector3.UP * 2.5)
		card.set_marker(at, caption())
		return
	if _hold >= 0.0:
		_hold = maxf(_hold - delta, 0.0)
		if _hold <= 0.0:
			# Done, but the radio's still talking: show it ticked and wait for the line.
			var talking := _t < _line_end
			if talking != _waiting:
				_waiting = talking
				card.set_waiting(talking)
				if talking:
					print("[tutorial] step %d done, waiting on the radio (%.1f s)" % [step, _line_end - _t])
					_snap("waiting", 0.3)
			if not talking:
				_enter(step + 1)
		return
	_check(delta)
	if _auto:
		_auto_t += delta
		if _auto_t > 1.0:
			_auto_step()
	card.set_marker(_marker(), caption())
	card.show_skip(_t > SKIP_AFTER and not STEPS[step].get("read", false))


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
	_cell = _free_lip_cell(&"gatling_post")
	var first := TutorialPlan.step_from_flag(GameState.flag_value("--tutorialstep"))
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


## A free lip cell for `id`, near the middle of the plateau.
func _free_lip_cell(id: StringName) -> Vector2i:
	for c: Vector2i in [Vector2i(0, 10), Vector2i(0, 9), Vector2i(0, 11), Vector2i(0, 8), Vector2i(0, 12), Vector2i(0, 7),
			Vector2i(0, 13), Vector2i(0, 6), Vector2i(0, 14), Vector2i(0, 5)]:
		if Buildable.cell_ok_for(id, c) and BuildManager.instance.is_free_for(id, me, c):
			return c
	return Vector2i(0, 10)


# ------------------------------------------------------------------ steps

func _enter(s: int) -> void:
	step = s
	_t = 0.0
	_hold = -1.0
	_dwell = 0.0
	_auto_t = 0.0
	_waiting = false
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
		Step.FARM:
			_water0 = Economy.amount(me, &"water")
			_prepare_farm()
		Step.GRAPPLE:
			_swing_t = 0.0
			_reel_t = 0.0
			_rope0 = INF
		Step.AIRSHIP:
			if Economy.amount(me, &"corn") <= 0:
				Economy.earn(me, {&"corn": 4}) # (started here, or the corn got eaten)
			_corn0 = Economy.amount(me, &"corn")
		Step.ECONOMY, Step.UPGRADES:
			if not _aboard():
				_board() # (started here by --tutorialstep)
		Step.SALVAGE:
			if _aboard():
				player.respawn() # off the ship and back on your porch
			var pile := _salvage()
			if pile != null and not pile.available and multiplayer.is_server():
				pile._set_available.rpc(true) # (picked over earlier: a fresh heap for the lesson)
		Step.HOUSE:
			if _aboard():
				player.respawn()
			_fund(_house_cost())
		Step.WORKSHOP:
			if _aboard():
				player.respawn()
			var home := Homestead.of(me)
			if home != null and not home.workshop:
				_fund(Homestead.UPGRADES[_upgrade_index(&"workshop")]["cost"])
			var got := {}
			for p: StringName in PARTS:
				if Economy.amount(me, p) <= 0:
					got[p] = 1
			if not got.is_empty() and Economy.amount(me, _craft_id) <= 0:
				Economy.earn(me, got)
	var said := TutorialPlan.line_of(STEPS[s])
	_line_end = TutorialPlan.line_time(said[0], said[1])
	print("[tutorial] step %d: %s (line %.1f s)" % [s, STEPS[s]["title"], _line_end])
	if STEPS[s].get("paper", false):
		card.show_paper()
	else:
		card.show_step(s - 1, Step.DONE - 1, STEPS[s], _task_words()) # (the paper isn't counted as a step)
	card.say(said[0], said[1])
	_snap("card", 1.0)


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
		Step.IDEA:
			# A deliberate look: held on the wall (looking away starts it over),
			# and never before the card has had time to be read.
			_dwell = _dwell + delta if _looking_at(_marker()) else 0.0
			if TutorialPlan.look_done(_dwell, _t):
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
			# Sell the Gatling Post, then put up a different kind of turret (Logan).
			var g := _my_gatling()
			var gid := g.get_instance_id() if g != null else 0
			if _gatling_id == 0:
				_gatling_id = gid # (it went up a moment after the step began)
			elif not _tasks[0] and gid != _gatling_id:
				_tasks[0] = true
			if _tasks[0] and _my_other_turret() != null:
				_tasks[1] = true
		Step.LEVER:
			if GameState.lever_thrown(me) or GameState.phase != GameState.Phase.BUILD:
				_tasks[0] = true
		Step.WAVE:
			if GameState.phase == GameState.Phase.BUILD and GameState.wave >= 2:
				_tasks[0] = true
		Step.FARM:
			_check_farm(delta)
		Step.GRAPPLE:
			_check_grapple(delta)
		Step.AIRSHIP:
			if _aboard():
				_tasks[0] = true
			var corn := Economy.amount(me, &"corn")
			if corn < _corn0:
				_tasks[1] = true
			_corn0 = maxi(_corn0, corn)
		Step.SALVAGE:
			var pile := _salvage()
			if pile != null and not pile.available and _t > 0.5:
				_tasks[0] = true
		Step.HOUSE:
			var home := Homestead.of(me)
			if home != null:
				for i in HOUSE_UPGRADES.size():
					if _house_has(home, HOUSE_UPGRADES[i]):
						_tasks[i] = true
		Step.WORKSHOP:
			var home := Homestead.of(me)
			if home != null and home.workshop:
				_tasks[0] = true
			if _crafted() != null:
				_tasks = [true, true, true]
			elif home != null and home.workshop and Economy.amount(me, _craft_id) > 0:
				_tasks[1] = true
	if _tasks != before:
		card.set_tasks(_tasks)
		if not _tasks.has(false):
			_hold = TICK_HOLD
			card.tick()
			print("[tutorial] step %d done (%.1f s)" % [step, _t])
			_snap("done", 0.4)


func _check_farm(delta: float) -> void:
	# The seeds come out of the house chest first (Logan).
	if Economy.amount(me, CropPlot.seed_res(&"corn")) > 0:
		_tasks[0] = true
	var water := Economy.amount(me, &"water")
	if water > _water0:
		_tasks[1] = true
	_water0 = mini(_water0, water) # watering spends some first: still counts the fill
	if _plot == null or not is_instance_valid(_plot):
		return
	var g := _plot.growth
	if g.stage != CropGrowth.Stage.EMPTY:
		_tasks[0] = true
		_tasks[2] = true
	if g.stage >= CropGrowth.Stage.GROWING:
		_tasks[1] = true # (had water to spare: that counts as filled)
		_tasks[3] = true
	if _tasks[3] and g.stage == CropGrowth.Stage.EMPTY:
		_tasks[4] = true # picked
	# Just this once, the corn shoots up.
	if g.stage == CropGrowth.Stage.GROWING and multiplayer.is_server():
		g.tick(delta * (GROW_FAST - 1.0))
		_grow_sync -= delta
		if _grow_sync <= 0.0 or g.stage == CropGrowth.Stage.RIPE:
			_grow_sync = 0.5
			_plot._broadcast()


func _check_grapple(delta: float) -> void:
	var g := player.grapple
	if player.gun.holding == &"grapple":
		_tasks[0] = true
	if g == null:
		return
	match g.mode:
		Grapple.Mode.SWING:
			_swing_t += delta
			if g._rope_len < _rope0 - 0.01: # reeling in on the swing (left click held)
				_reel_t += delta
			_rope0 = g._rope_len
		Grapple.Mode.PULL:
			_reel_t += delta
			_rope0 = INF
		_:
			_rope0 = INF
	if _swing_t >= ROPE_TIME:
		_tasks[1] = true
	if _reel_t >= ROPE_TIME:
		_tasks[2] = true


## Enter / pad A: carries on from a reading card (once it has been up a
## moment), takes you aboard the airship, or skips a stuck step. A "look at it"
## step only finishes from the look itself.
func accept_pressed() -> void:
	if step < 0 or step >= Step.DONE or _hold >= 0.0:
		return
	if step == Step.AIRSHIP and not _tasks[0] and _t > 0.5:
		_board()
		return
	var read: bool = STEPS[step].get("read", false)
	if (read and _t > READ_MIN) or _t > SKIP_AFTER:
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


func _my_turret(id: StringName) -> Node3D:
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t != null and not t.is_queued_for_deletion() and t.cliff_id == me and t.def != null and t.def.id == id:
			return t
	return null


func _my_gatling() -> Node3D:
	return _my_turret(&"gatling_post")


## Any of your turrets that isn't the Gatling Post (the sell step's swap).
func _my_other_turret() -> Node3D:
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t != null and not t.is_queued_for_deletion() and t.cliff_id == me and t.def != null 				and t.def.id != &"gatling_post" and t.def.id != _craft_id and not t.def.anti_air:
			return t
	return null


## The turret on your lip after the swap (or the Gatling Post if there's no other).
func _main_turret() -> Node3D:
	var t := _my_other_turret()
	return t if t != null else _my_gatling()


## The crafted turret placed on your cliff, if it's up.
func _crafted() -> Node3D:
	return _my_turret(_craft_id)


func _build_gatling() -> void:
	if _my_gatling() == null:
		BuildManager.instance.build(&"gatling_post", me, _cell)


## Farm step: an empty plot near the well with a corn seed to plant, and some
## water in the trough (the wave's pumping usually filled it already).
func _prepare_farm() -> void:
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
	if _plot != null and multiplayer.is_server() and _plot.has_crop():
		_plot.growth.clear() # a fresh plot to plant
		_plot._broadcast()
	CropPlot.selected_seed = 0 # corn first on F
	# The starting seeds wait in the house chest, not in your pockets.
	var seed := CropPlot.seed_res(&"corn")
	var have := Economy.amount(me, seed)
	if have > 0:
		Economy.spend(me, {seed: have})
	var chest := _chest()
	if chest != null and multiplayer.is_server():
		for k: StringName in TutorialPlan.CHEST_SEEDS:
			chest.items[k] = maxi(int(chest.items.get(k, 0)), int(TutorialPlan.CHEST_SEEDS[k]))
		chest._sync.rpc(chest.items, chest.weapons)
	elif chest == null:
		Economy.earn(me, {seed: 1}) # (no house chest: hand it over as before)


## The chest inside your house.
func _chest() -> StorageChest:
	var home := Homestead.of(me)
	return home.get_node_or_null("Chest") as StorageChest if home != null else null


func _well() -> WaterSource:
	for n: Node in get_tree().get_nodes_in_group("water_sources"):
		if n is MechWell and (n as MechWell).cliff_id == me:
			return n as WaterSource
	return null


## Your cliff's scrap heap (WorldDressing puts one by each house).
func _salvage() -> SalvagePile:
	for n: Node in world.find_children("Salvage*", "SalvagePile", true, false):
		var p := n as SalvagePile
		if p != null and p.cliff_id == me:
			return p
	return null


func _airship() -> Node3D:
	return world.get_node_or_null("Airship") as Node3D


## On the airship's deck?
func _aboard() -> bool:
	var ship := _airship()
	if ship == null:
		return false
	var local := ship.to_local(player.global_position)
	return absf(local.x) < AirshipBuilder.DECK_W * 0.5 + 1.0 and absf(local.z) < AirshipBuilder.DECK_L * 0.5 + 2.5 \
			and local.y > -1.5 and local.y < 8.0


## Up onto the deck between the market and the gunsmith, facing them.
func _board() -> void:
	var ship := _airship()
	if ship == null:
		return
	if player.grapple != null:
		player.grapple._release()
	player.global_position = ship.to_global(Vector3(0, 0.3, 6.0))
	player.velocity = Vector3.ZERO
	player.cancel_fall()
	_aim_at(ship.to_global(Vector3(0, 1.4, 9.5)))
	print("[tutorial] aboard the airship")


func _upgrade_index(id: StringName) -> int:
	for i in Homestead.UPGRADES.size():
		if Homestead.UPGRADES[i]["id"] == id:
			return i
	return -1


static func _house_has(home: Homestead, id: StringName) -> bool:
	match id:
		&"board":
			return home.boarded
		&"reinforce":
			return home.reinforced
		&"porch":
			return home.porch
		&"floor2":
			return home.floors >= 2
		&"floor3":
			return home.floors >= 3
		&"tower":
			return home.tower
		&"workshop":
			return home.workshop
	return false


## What the house upgrades still to buy cost, all told.
func _house_cost() -> Dictionary:
	var home := Homestead.of(me)
	var owned: Array[StringName] = []
	for id: StringName in HOUSE_UPGRADES:
		if home != null and _house_has(home, id):
			owned.append(id)
	return TutorialPlan.house_cost(Homestead.UPGRADES, owned)


## Tops your stock up so `cost` is affordable (the tutorial pays).
func _fund(cost: Dictionary) -> void:
	var add := {}
	for k: StringName in cost:
		var short := int(cost[k]) - Economy.amount(me, k)
		if short > 0:
			add[k] = short
	if not add.is_empty():
		Economy.earn(me, add)


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
		Step.SELL, Step.TURRETS:
			var g := _my_gatling() if step == Step.SELL else _main_turret()
			if g != null and (step == Step.TURRETS or (_tasks.size() > 0 and not _tasks[0])):
				return g.global_position + Vector3.UP * 2.0
			return _lip_point() + Vector3.UP * 1.2 if step == Step.SELL else null
		Step.LEVER:
			var gen := Generator.of(me)
			return gen.global_position + Vector3.UP * 1.6 if gen != null else null
		Step.FARM:
			if _tasks.size() > 0 and not _tasks[0]:
				var c := _chest()
				return c.global_position + Vector3.UP * 1.0 if c != null else null
			if _tasks.size() > 1 and not _tasks[1]:
				var w := _well()
				return w.global_position + Vector3.UP * 1.5 if w != null else null
			return _plot.global_position + Vector3.UP * 0.8 if _plot != null and is_instance_valid(_plot) else null
		Step.GRAPPLE:
			var tower := WaterTower.of(me)
			return tower.global_position + Vector3.UP * 7.0 if tower != null else null
		Step.AIRSHIP, Step.ECONOMY, Step.UPGRADES:
			var ship := _airship()
			if ship == null:
				return null
			if step == Step.AIRSHIP and not _aboard():
				return Airship.ring_position()
			var shop := ship.get_node_or_null("GunShop" if step == Step.UPGRADES else "Vendor") as Node3D
			return shop.global_position + Vector3.UP * 2.0 if shop != null else null
		Step.SALVAGE:
			var pile := _salvage()
			return pile.global_position + Vector3.UP * 3.0 if pile != null else null
		Step.HOUSE, Step.WORKSHOP:
			var home := Homestead.of(me)
			if home == null:
				return null
			if step == Step.WORKSHOP and home.workshop:
				if _tasks.size() > 1 and _tasks[1]:
					return Buildable.footprint_center(cliffs, me, _craft_id, _free_lip_cell(_craft_id)) + Vector3.UP * 1.2
				var bench := home.get_node_or_null("Workshop") as Node3D
				return bench.global_position + Vector3.UP * 1.2 if bench != null else null
			var ledger := home.get_node_or_null("Ledger") as Node3D
			return ledger.global_position + Vector3.UP * 1.2 if ledger != null else null
	return null


## The marker's caption for this step (some move on as the step goes).
func caption() -> String:
	var words := str(STEPS[step].get("marker", "")) if step >= 0 and step < Step.DONE else ""
	if step == Step.SELL and _tasks.size() > 0 and _tasks[0]:
		words = "Your Lip" # sold: the marker now points at where the new turret goes
	match step:
		Step.FARM:
			if _tasks.size() > 1 and _tasks[1]:
				return "Farm Plot"
			if _tasks.size() > 0 and _tasks[0]:
				return "Well"
		Step.AIRSHIP:
			if not _aboard():
				return "Airship Ring"
		Step.WORKSHOP:
			var home := Homestead.of(me)
			if home != null and home.workshop:
				return "Your Lip" if _tasks.size() > 1 and _tasks[1] else "Workshop Bench"
	return words


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
	card.show_finish()
	_snap("finish", 1.2)
	if _auto and not GameState.has_flag("--tutorialstay"):
		print("[tutorial] smoke run complete: every step done")
		get_tree().create_timer(3.0).timeout.connect(func() -> void: get_tree().quit())


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


## --tutorialshots: a picture of the screen a moment from now.
func _snap(what: String, after: float) -> void:
	if _shots == "":
		return
	_shot_n += 1
	var path := "%s/%02d_s%02d_%s.png" % [_shots, _shot_n, step, what]
	get_tree().create_timer(after).timeout.connect(func() -> void:
		get_viewport().get_texture().get_image().save_png(path)
		print("[tutorial] saved ", path))


# ------------------------------------------------------------------ --tutorialrun

## Points the camera at `pos`.
func _aim_at(pos: Vector3) -> void:
	var to := pos - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Does the current step by itself (smoke test).
func _auto_step() -> void:
	var uid := multiplayer.get_unique_id()
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
		Step.PAPER, Step.GUNS, Step.PELL, Step.TURRETS, Step.WEATHER, Step.ECONOMY, Step.UPGRADES:
			if _t > READ_MIN + 1.0:
				accept_pressed()
		Step.IDEA:
			# Look at the wall, the way a player would (the key alone doesn't do it).
			var at: Variant = _marker()
			if at != null:
				_aim_at(at as Vector3)
			_auto_t = 0.8
		Step.BUILD:
			_build_gatling()
			_auto_t = -2.0
		Step.SELL:
			var g := _my_gatling()
			if not _tasks[0] and g != null:
				BuildManager.instance.demolish_node(g)
			elif _tasks[0] and _my_other_turret() == null:
				BuildManager.instance.build(SWAP_TURRET, me, _cell)
			_auto_t = -1.0
		Step.LEVER:
			if not GameState.lever_thrown(me):
				GameState.toggle_ready()
			_auto_t = -5.0
		Step.WAVE:
			# Let the turret do the work; after two minutes, finish the stragglers.
			if _t > 120.0:
				for c: Node in WaveDirector.bug_manager.get_children():
					var b := c as Bug
					if b != null and b.is_alive():
						b.receive_hit(999.0, b.global_position, Vector3.FORWARD, true, 1.0, "revolver", me)
			_auto_t = -4.0
		Step.FARM:
			var w := _well()
			var chest := _chest()
			if not _tasks[0] and chest != null:
				chest._host(uid, &"take_item", CropPlot.seed_res(&"corn"), 99)
			elif not _tasks[1] and w != null:
				w._use(uid)
			elif _plot != null and _plot.growth.stage != CropGrowth.Stage.GROWING:
				_plot._use(uid, &"corn")
			_auto_t = 0.0
		Step.GRAPPLE:
			var g := player.grapple
			var tower := WaterTower.of(me)
			if g == null or tower == null:
				return
			if not _tasks[0]:
				player.hotbar_use_grapple()
			elif not _tasks[1]:
				g.attach(Grapple.Mode.SWING, tower.global_position + Vector3.UP * 7.0)
				_swing_t = ROPE_TIME # (a test can't hold right click; the hook did go on)
			elif not _tasks[2]:
				g.test_mode = true # (holds the pull without a held left click)
				g.attach(Grapple.Mode.PULL, tower.global_position + Vector3.UP * 7.0)
			_auto_t = 0.0
		Step.AIRSHIP:
			if not _tasks[0]:
				accept_pressed()
			else:
				var ship := _airship()
				var v := ship.get_node_or_null("Vendor") as VendorCart if ship != null else null
				if v != null:
					v._sell(uid, &"corn")
			_auto_t = 0.0
		Step.SALVAGE:
			var pile := _salvage()
			if pile != null and _t > 1.0:
				pile._collect(uid)
		Step.HOUSE:
			if player.grapple != null:
				player.grapple.test_mode = false
			var home := Homestead.of(me)
			for i in HOUSE_UPGRADES.size():
				if not _tasks[i] and home != null:
					home.buy(uid, _upgrade_index(HOUSE_UPGRADES[i]))
					break
			_auto_t = 0.2
		Step.WORKSHOP:
			var home := Homestead.of(me)
			if home == null:
				return
			if not home.workshop:
				home.buy(uid, _upgrade_index(&"workshop"))
			elif Economy.amount(me, _craft_id) <= 0 and _crafted() == null:
				var bench := home.get_node_or_null("Workshop") as Workshop
				if bench != null:
					bench._craft(uid, _craft_id)
			elif _crafted() == null:
				BuildManager.instance.build(_craft_id, me, _free_lip_cell(_craft_id))
			_auto_t = -0.5
