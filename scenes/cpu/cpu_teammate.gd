class_name CpuTeammate
extends Node3D
## A computer-controlled partner on the cliff no human took. Host only. It
## plays like a person within its quality (Low / Medium / High):
##  - build phase: tends its crops, builds turrets on its own plateau (which
##    cover YOUR cliff, the cross-defense rule), then waits at the lip;
##  - wave: stands at its lip and shoots bugs, yours first, with aim, reaction
##    time and fire rate set by quality.
## It spends from the shared team pool but never more than its share
## (Economy.cpu_spend / CpuBudget). It never gambles or visits the airship.

enum Task { IDLE, WALK, FARM, BUILD, GUARD }

## Per quality: aim (hit chance at 40 m), reaction (s), shot interval (s),
## walk speed (m/s), think interval (s), how keen it is to farm, how it picks
## turret spots ("random" / "spread" / "smart") and how often it goes for weak spots.
const QUALITY := [
	{"name": "Low", "hit": 0.35, "react": 1.1, "shot": 0.95, "speed": 3.2, "think": 3.0, "farm": 0.35, "place": "random", "weak": 0.05},
	{"name": "Medium", "hit": 0.6, "react": 0.6, "shot": 0.6, "speed": 4.8, "think": 1.6, "farm": 0.75, "place": "spread", "weak": 0.2},
	{"name": "High", "hit": 0.85, "react": 0.3, "shot": 0.42, "speed": 6.2, "think": 0.9, "farm": 1.0, "place": "smart", "weak": 0.45},
]
const RANGE := 85.0
const NAME := "Dusty"

var quality := 1
var cliff_id := WorldLayout.EAST
var cliffs: CliffBuilder
var vfx: VfxPool
var display_name := NAME

var _q: Dictionary
var _rig: DummyRig
var _d := 12.0 # plateau coords: metres back from the lip
var _z := 0.0 # along the canyon
var _goal := Vector2(12.0, 0.0)
var _task := Task.IDLE
var _then: Callable = Callable()
var _think := 0.0
var _speed := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _target: Bug
var _react := 0.0
var _shot_cd := 0.0
var _rng := RandomNumberGenerator.new()
## Where bugs have topped the HUMAN's cliff (z), for High-quality placement.
var _threat_z: Array[float] = []


## CPU teammates' names, in order (one per empty cliff).
const NAMES := ["Dusty", "Rusty", "Sandy"]


func setup(q: int, cid: int, world_cliffs: CliffBuilder, pool: VfxPool, index: int = 0) -> void:
	quality = clampi(q, 0, 2)
	cliff_id = cid
	cliffs = world_cliffs
	vfx = pool
	_q = QUALITY[quality]
	display_name = "%s (CPU)" % NAMES[clampi(index, 0, NAMES.size() - 1)]
	_rng.seed = 7331 + quality + index * 101


func _ready() -> void:
	add_to_group("cpu_teammates")
	_rig = DummyRig.new()
	add_child(_rig)
	_rig.build(Palette.team_color(cliff_id), false, {"hat": "gambler", "facial": "walrus", "hair": "none",
			"hair_color": "brown", "outfit": "duster", "neck": "bandana", "extra": "bandolier", "paint": "white"})
	_rig.set_weapon(&"revolver")
	_z = Buildable.HOUSE_Z + 3.0
	_d = Buildable.HOUSE_D - 6.0
	_goal = Vector2(_d, _z)
	_place()
	_yaw = WorldLayout.facing_canyon_yaw(cliff_id)
	GameState.phase_changed.connect(func(_p: GameState.Phase) -> void: _think = 0.0)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or cliffs == null:
		return
	_watch_threats()
	_think -= delta
	if _think <= 0.0 and _task != Task.WALK:
		_think = float(_q["think"]) * _rng.randf_range(0.8, 1.2)
		_decide()
	_walk(delta)
	if GameState.phase in [GameState.Phase.WAVE, GameState.Phase.WARNING] or _hostile_on_plateau():
		_fight(delta)
	else:
		_target = null
	_animate(delta)


# ------------------------------------------------------------------ deciding

func _decide() -> void:
	match GameState.phase:
		GameState.Phase.BUILD:
			if not _carry.is_empty() and _deposit_task():
				return
			if _water_task():
				return
			if _rng.randf() < float(_q["farm"]) and _farm_task():
				return
			if _build_task():
				return
			if _lever_task():
				return
			_go(Vector2(_rng.randf_range(2.0, 6.0), clampf(_z + _rng.randf_range(-6.0, 6.0), -16.0, 16.0)), Task.IDLE)
		GameState.Phase.WARNING, GameState.Phase.WAVE:
			# Hold the lip, roughly across from where bugs top your partner's cliff.
			var z := _busiest_z() if quality == 2 else _z
			_go(Vector2(2.2, clampf(z, -17.0, 17.0)), Task.GUARD)
		_:
			pass


## Water: a crop on our cliff wants watering and we can't pay for it: fill a
## bucket at our well's trough (MechWell; it always works, faster while pumping).
func _water_task() -> bool:
	var well := _well()
	if well == null or well.stored < 2:
		return false
	var need := 0
	for n: Node in get_tree().get_nodes_in_group("crops"):
		var plot := n as CropPlot
		if plot != null and plot.cliff_id == cliff_id and plot.growth.stage == CropGrowth.Stage.PLANTED and plot.crop_def != null:
			need = maxi(need, plot.crop_def.water_cost)
	if need == 0 or Economy.cpu_can_spend(display_name, {&"water": need}):
		return false
	# Stand at the trough's far side, facing the spout.
	var at := well.global_transform * Vector3(0, 0, WellJackBuilder.TROUGH_Z - 1.0)
	_go(cliffs.plateau_coords(cliff_id, at), Task.FARM, func() -> void:
		if not is_instance_valid(well):
			return
		_face(well.global_transform * Vector3(0, 0, WellJackBuilder.TROUGH_Z))
		_rig.play_action(&"water")
		var got := well.draw_for_cpu()
		if GameState.has_flag("--cpulog"):
			print("[cpu] %s drew %d water at the well" % [display_name, got]))
	return true


func _well() -> MechWell:
	for n: Node in get_tree().get_nodes_in_group("water_sources"):
		if n is MechWell and (n as MechWell).cliff_id == cliff_id:
			return n as MechWell
	return null


## Waterworks: nothing left to do this build phase: walk to our generator and
## throw its lever (CPU teammates never hold the wave up; this is for show).
func _lever_task() -> bool:
	if GameState.lever_thrown(cliff_id) or Generator.of(cliff_id) == null:
		return false
	var g := Buildable.GENERATOR
	var spot := g + (Buildable.WATERWORKS_FACE - g).normalized() * 1.7
	_go(spot, Task.IDLE, func() -> void:
		_face(Generator.of(cliff_id).global_position if Generator.of(cliff_id) != null else global_position)
		GameState.throw_cpu_lever(cliff_id)
		Audio.play_at(&"slot_lever", global_position + Vector3(0, 1.3, 0), -2.0, 0.7)
		if GameState.has_flag("--cpulog"):
			print("[cpu] %s threw the generator lever" % display_name))
	return true


## Walk to plateau coords `to`, then run `then` (if any).
func _go(to: Vector2, task: Task, then: Callable = Callable()) -> void:
	_goal = to
	_task = Task.WALK if (Vector2(_d, _z) - to).length() > 0.6 else task
	_then = then
	if _task != Task.WALK and then.is_valid():
		then.call()
		_then = Callable()


func _walk(delta: float) -> void:
	var here := Vector2(_d, _z)
	var to := _goal - here
	var step := float(_q["speed"]) * delta
	if to.length() <= step:
		_d = _goal.x
		_z = _goal.y
		_speed = move_toward(_speed, 0.0, delta * 8.0)
		if _task == Task.WALK:
			_task = Task.IDLE
			if _then.is_valid():
				var f := _then
				_then = Callable()
				f.call()
	else:
		var dir := to.normalized()
		_d += dir.x * step
		_z += dir.y * step
		_speed = float(_q["speed"])
		if _target == null:
			var world_dir := _world(Vector2(_d, _z) + dir) - global_position
			_yaw = lerp_angle(_yaw, atan2(-world_dir.x, -world_dir.z), clampf(delta * 8.0, 0.0, 1.0))
	_place()


func _place() -> void:
	global_position = _world(Vector2(_d, _z))
	rotation.y = _yaw


func _world(pc: Vector2) -> Vector3:
	return cliffs.plateau_point(cliff_id, maxf(pc.x, 0.6), pc.y)


# ------------------------------------------------------------------ farming

func _farm_task() -> bool:
	var best: CropPlot = null
	var act := ""
	for n: Node in get_tree().get_nodes_in_group("crops"):
		var plot := n as CropPlot
		if plot == null or plot.cliff_id != cliff_id:
			continue
		match plot.growth.stage:
			CropGrowth.Stage.RIPE:
				best = plot
				act = "harvest"
			CropGrowth.Stage.PLANTED:
				if plot.crop_def != null and Economy.cpu_can_spend(display_name, {&"water": plot.crop_def.water_cost}):
					best = plot
					act = "water"
			CropGrowth.Stage.EMPTY:
				if _seed_for() != &"":
					best = plot
					act = "plant"
		if act == "harvest":
			break
	if best == null:
		return false
	var plot := best
	var a := act
	var pc := cliffs.plateau_coords(cliff_id, plot.global_position)
	_go(Vector2(pc.x - 1.2, pc.y), Task.FARM, func() -> void: _farm(plot, a))
	return true


func _seed_for() -> StringName:
	for seed_id: StringName in CropPlot.SEEDS:
		var res: StringName = CropPlot.seed_res(seed_id)
		if Economy.amount(cliff_id, res) > 0 and Economy.cpu_can_spend(display_name, {res: 1}):
			return seed_id
	return &""


func _farm(plot: CropPlot, act: String) -> void:
	if not is_instance_valid(plot):
		return
	_face(plot.global_position)
	_rig.play_action(&"harvest" if act == "harvest" else (&"water" if act == "water" else &"plant"))
	match act:
		"harvest":
			# Picks it itself: crops its turrets burn as upkeep go to the pool,
			# the rest it carries to its chest for you to sell.
			var got: Dictionary = plot.growth.harvest()
			plot.call("_broadcast")
			var keep := _upkeep_crops()
			for res: StringName in got:
				if keep.has(res):
					Economy.earn(cliff_id, {res: int(got[res])})
				else:
					_carry[res] = int(_carry.get(res, 0)) + int(got[res])
		"water":
			# The plot charges the pool itself; we just count it against our share.
			var cost := {&"water": plot.crop_def.water_cost}
			if Economy.cpu_can_spend(display_name, cost):
				plot.call("_use", -1, &"corn")
				Economy.cpu_record(display_name, cost)
		"plant":
			var seed_id := _seed_for()
			if seed_id != &"":
				plot.call("_use", -1, seed_id)
				Economy.cpu_record(display_name, {CropPlot.seed_res(seed_id): 1})


## What it has picked and not yet put in the chest.
var _carry: Dictionary = {}


## Crops that turrets on its cliff use as upkeep (TurretDef.ammo_cost).
func _upkeep_crops() -> Dictionary:
	var keep := {}
	for t: Node in _my_turrets():
		var def: TurretDef = t.get("def")
		if def == null:
			continue
		for res: StringName in def.ammo_cost:
			keep[res] = true
	return keep


## Walk to its house's shared deposit box and leave the harvest for the players.
func _deposit_task() -> bool:
	var home := Homestead.of(cliff_id)
	if home == null:
		return false
	var box := home.get_node_or_null("DepositBox") as DepositBox
	if box == null:
		return false
	var pc := cliffs.plateau_coords(cliff_id, box.global_position)
	_go(Vector2(pc.x - 1.2, pc.y), Task.FARM, func() -> void:
		_face(box.global_position)
		_rig.play_action(&"chest")
		if GameState.has_flag("--cpulog"):
			print("[cpu] put %s in the deposit box" % str(_carry))
		box.deposit(_carry.duplicate())
		_carry.clear()
		# Maps: tell every human (on the canyon that's just the partner).
		for pid: int in NetworkManager.players:
			Economy.notify(pid, "%s left a harvest in %s's deposit box." % [display_name, WorldLayout.map().name_of(cliff_id)]))
	return true


# ------------------------------------------------------------------ building

## Turrets worth building, cheapest-first within each kind.
func _turret_choice() -> StringName:
	# Crewed: categories by name (a "Crewed Guns" tab now sits after Cliff Turrets).
	var cliff_turrets: Array = Defs.category_items("Cliff Turrets").filter(func(id: StringName) -> bool: return id != &"scaffold")
	var air: Array = Defs.category_items("Air Defense")
	var options: Array = []
	match quality:
		0:
			options = cliff_turrets.slice(0, 4)
			options.shuffle()
		1:
			var built := _my_turrets().size()
			options = [cliff_turrets[built % cliff_turrets.size()]]
			options.append_array(cliff_turrets)
		_:
			# Read the wave preview: fliers coming means air defence first.
			var fliers := 0
			var big := 0
			var total := 0
			for m: Array in WaveDirector.preview:
				var def := Defs.bug(StringName(str(m[0])))
				if def == null:
					continue
				total += int(m[1])
				if def.behavior == BugDef.Behavior.FLIER or def.id == &"locust_lord":
					fliers += int(m[1]) * (40 if def.id == &"locust_lord" else 1) # the Lord only falls to anti-air
				elif def.behavior in [BugDef.Behavior.TANK, BugDef.Behavior.BOSS]:
					big += int(m[1])
			var air_built := _my_turrets().filter(func(t: Node) -> bool: return Defs.turret(t.get("def").id).anti_air if t.get("def") != null else false).size()
			if total > 0 and float(fliers) / total > 0.15 and air_built < 2:
				options.append_array(air)
			if big > 0:
				options.append(&"buffalo_rifle")
			# Crewed: High builds a crewed gun or two once the line is up (it never
			# sits in one: they fire on their own at half power for it).
			var crewed_built := _my_turrets().filter(func(t: Node) -> bool: return t is CrewedTurret).size()
			if crewed_built < 2 and _my_turrets().size() >= 6:
				var pick := &"big_bertha"
				if total > 0 and float(fliers) / total > 0.15:
					pick = &"sky_hound"
				elif big > 0:
					pick = &"whaler"
				elif crewed_built == 1:
					pick = &"thunder_mule"
				options.push_front(pick)
			options.append_array(cliff_turrets)
	for id: StringName in options:
		if Defs.is_turret(id) and Economy.cpu_can_spend(display_name, {&"scrap": Defs.cost_of(id)}):
			return id
	return &""


func _my_turrets() -> Array:
	return get_tree().get_nodes_in_group("turrets").filter(func(t: Node) -> bool: return int(t.get("cliff_id")) == cliff_id)


func _build_task() -> bool:
	# Medium and High keep a farm plot or two going (Low doesn't bother).
	if quality >= 1 and _my_plots() < quality and Economy.cpu_can_spend(display_name, {&"scrap": Defs.cost_of(&"farm_plot")}) 			and _my_turrets().size() >= 2:
		return _build_at(&"farm_plot", _pick_cell(&"farm_plot"))
	var id := _turret_choice()
	if id == &"":
		return false
	return _build_at(id, _pick_cell(id))


func _my_plots() -> int:
	return get_tree().get_nodes_in_group("crops").filter(func(c: Node) -> bool: return int(c.get("cliff_id")) == cliff_id).size()


func _build_at(id: StringName, cell: Vector2i) -> bool:
	if cell == Vector2i(-1, -1):
		return false
	var pc := cliffs.plateau_coords(cliff_id, Buildable.cell_center(cliffs, cliff_id, cell))
	_go(Vector2(pc.x + 1.5, pc.y), Task.BUILD, func() -> void:
		_face(Buildable.cell_center(cliffs, cliff_id, cell))
		_rig.play_action(&"hammer")
		var ok := BuildManager.instance.cpu_build(display_name, id, cliff_id, cell)
		if GameState.has_flag("--cpulog"):
			print("[cpu] build %s at %s: %s  (scrap spent %s, team had %s)" % [id, str(cell), ok,
					str(Economy.cpu_spent.get(display_name, {}).get(&"scrap", 0)), str(Economy.gained.get(&"scrap", 0))]))
	return true


func _pick_cell(id: StringName) -> Vector2i:
	var bm := BuildManager.instance
	var used_cols: Array[int] = []
	for t: Node in _my_turrets():
		var c: Vector2i = t.get("cell") if t.get("cell") != null else Vector2i(-1, -1)
		used_cols.append(c.y)
	var best := Vector2i(-1, -1)
	var best_score := -1e9
	for row in Buildable.ROWS:
		for col in Buildable.COLS:
			var cell := Vector2i(row, col)
			if not Buildable.cell_ok_for(id, cell) or not bm.is_free_for(id, cliff_id, cell):
				continue
			var score := 0.0
			if id == &"farm_plot":
				# Plots go back near the house, out of the way of the turrets.
				score = -absf(float(row) - 6.0) - absf(float(col) - 15.0) * 0.5 + _rng.randf()
				if score > best_score:
					best_score = score
					best = cell
				continue
			match str(_q["place"]):
				"random":
					score = _rng.randf()
				"spread", "smart":
					# Near the lip, and away from turrets already built.
					score = -float(row) * 2.0
					var gap := 99.0
					for uc in used_cols:
						gap = minf(gap, absf(float(uc - col)))
					score += minf(gap, 6.0) * 1.5
					if str(_q["place"]) == "smart":
						var z := Buildable.cell_center(cliffs, cliff_id, cell).z
						score += _threat_near(z) * 3.0
					score += _rng.randf() * 0.5
			if score > best_score:
				best_score = score
				best = cell
	return best


# ------------------------------------------------------------------ fighting

func _fight(delta: float) -> void:
	_shot_cd -= delta
	if _target == null or not is_instance_valid(_target) or not _target.is_alive() or _target.global_position.distance_to(global_position) > RANGE:
		var t := _pick_target()
		if t != _target:
			_target = t
			_react = float(_q["react"]) * _rng.randf_range(0.8, 1.3)
	if _target == null:
		return
	_face(_target.global_position)
	_react -= delta
	if _react > 0.0 or _shot_cd > 0.0:
		return
	_shot_cd = float(_q["shot"]) * _rng.randf_range(0.9, 1.15)
	_shoot(_target)


## Bugs on your partner's cliff first (that's the deal), then any on ours.
func _pick_target() -> Bug:
	var best: Bug = null
	var best_score := -1e9
	var human_cliff := WorldLayout.other_cliff(cliff_id)
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive():
			continue
		var dist := b.global_position.distance_to(global_position)
		if dist > RANGE:
			continue
		var score := -dist * 0.2
		match b.state:
			Bug.State.CLIMBING:
				score += b.climb_y * 0.5
			Bug.State.CRESTING, Bug.State.BREACHING:
				score += 40.0
			Bug.State.FLYING:
				score += 10.0
			_:
				continue
		if b.cliff_id == human_cliff:
			score += 15.0
		if score > best_score:
			best_score = score
			best = b
	return best


func _shoot(b: Bug) -> void:
	var muzzle := global_position + Vector3(0, 1.45, 0) + (b.global_position - global_position).normalized() * 0.5
	var dist := muzzle.distance_to(b.global_position)
	var hit_p := clampf(float(_q["hit"]) * (1.15 - dist / RANGE * 0.5), 0.05, 0.97)
	var aim := b.global_position + Vector3(0, 0.4, 0)
	var hit := _rng.randf() < hit_p
	if not hit:
		aim += Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.0, 1.5), _rng.randf_range(-1.5, 1.5))
	_shot_fx.rpc(muzzle, aim)
	_shots += 1
	if GameState.has_flag("--cpulog") and _shots % 25 == 0:
		print("[cpu] %d shots, %d hits" % [_shots, _hits])
	if not hit:
		return
	var weak := _rng.randf() < float(_q["weak"])
	var dmg := Gun.weapon(&"revolver").damage
	# [Foundation] one hitbox per bug: a weak-spot hit is just the weak multiplier.
	b.receive_hit(dmg, aim, (aim - muzzle).normalized(), false, WeakSpot.MULTIPLIER if weak else 1.0, display_name, cliff_id)
	_hits += 1


var _hits := 0
var _shots := 0


@rpc("authority", "call_local", "unreliable")
func _shot_fx(from: Vector3, to: Vector3) -> void:
	if vfx != null:
		vfx.muzzle_flash(from, (to - from).normalized())
		vfx.tracer(from, to)
	Audio.play_at(&"revolver", from, -4.0)


# ------------------------------------------------------------------ helpers

func _face(p: Vector3) -> void:
	var to := p - global_position
	_yaw = atan2(-to.x, -to.z)
	_pitch = atan2(to.y - 1.4, Vector2(to.x, to.z).length())


func _animate(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _yaw, clampf(delta * 10.0, 0.0, 1.0))
	_rig.animate(delta, _speed, false, _pitch if _target != null else 0.0)


func _hostile_on_plateau() -> bool:
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and b.cliff_id == cliff_id and b.state == Bug.State.BREACHING:
			return true
	return false


## Remember where bugs top the human's cliff (High quality builds to cover them).
var _watch_t := 0.0


func _watch_threats() -> void:
	_watch_t -= get_physics_process_delta_time()
	if _watch_t > 0.0:
		return
	_watch_t = 1.0
	var human_cliff := WorldLayout.other_cliff(cliff_id)
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and b.cliff_id == human_cliff and b.state == Bug.State.CRESTING:
			_threat_z.append(b.global_position.z)
	while _threat_z.size() > 200:
		_threat_z.pop_front()


func _threat_near(z: float) -> float:
	if _threat_z.is_empty():
		return 0.0
	var n := 0
	for tz in _threat_z:
		if absf(tz - z) < 15.0:
			n += 1
	return float(n) / float(_threat_z.size())


func _busiest_z() -> float:
	var best := _z
	var best_n := -1.0
	for z in range(-16, 17, 4):
		var n := _threat_near(float(z))
		if n > best_n:
			best_n = n
			best = float(z)
	return best
