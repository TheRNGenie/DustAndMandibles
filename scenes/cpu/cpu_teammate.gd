class_name CpuTeammate
extends Node3D
## A computer-controlled partner on the cliff no human took. Host only. It
## plays like a person within its quality (Low / Medium / High):
##  - build phase: tends its crops, builds turrets on its own plateau (which
##    cover YOUR cliff, the cross-defense rule), then waits at the lip;
##  - wave: stands at its lip and shoots bugs, yours first, with aim, reaction
##    time and fire rate set by quality.
## Scrap comes from the team pot, but never more than its fair share of all the
## scrap the team has had (Economy.cpu_spend / CpuBudget); its chitin, water,
## seeds and crops are its own cliff's. It never gambles or visits the airship.

enum Task { IDLE, WALK, FARM, BUILD, GUARD }

## Per quality: aim (hit chance at 40 m), reaction (s), shot interval (s),
## walk speed (m/s), think interval (s), how keen it is to farm, how it picks
## turret spots ("random" / "spread" / "smart") and how often it goes for weak spots.
const QUALITY := [
	{"name": "Low", "hit": 0.35, "react": 1.1, "shot": 0.95, "speed": 3.2, "think": 3.0, "farm": 0.35, "place": "random", "weak": 0.05},
	{"name": "Medium", "hit": 0.6, "react": 0.6, "shot": 0.6, "speed": 4.8, "think": 1.6, "farm": 0.75, "place": "spread", "weak": 0.2},
	{"name": "High", "hit": 0.85, "react": 0.3, "shot": 0.42, "speed": 6.2, "think": 0.9, "farm": 1.0, "place": "smart", "weak": 0.45},
	# Hyper: High's head, plus a real body it flies by grapple and slide-hop (HyperPilot).
	{"name": "Hyper", "hit": 0.88, "react": 0.25, "shot": 0.4, "speed": 6.2, "think": 0.8, "farm": 1.0, "place": "smart", "weak": 0.5},
]
const HYPER := 3
const LOOK := {"hat": "gambler", "facial": "walrus", "hair": "none", "hair_color": "brown", "outfit": "duster",
		"neck": "bandana", "extra": "bandolier", "paint": "white"}
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
	quality = clampi(q, 0, QUALITY.size() - 1)
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
	_rig.build(Palette.team_color(cliff_id), false, LOOK)
	if force_gun != &"" and Gun.weapon(force_gun) != null:
		gun_id = force_gun
	_rig.set_weapon(gun_id)
	_z = Buildable.HOUSE_Z + 3.0
	_d = Buildable.HOUSE_D - 6.0
	_goal = Vector2(_d, _z)
	_place()
	_yaw = WorldLayout.facing_canyon_yaw(cliff_id)
	GameState.phase_changed.connect(func(_p: GameState.Phase) -> void: _think = 0.0)


func _physics_process(delta: float) -> void:
	if cliffs == null:
		return
	if not multiplayer.is_server():
		_puppet(delta)
		_follow_body()
		return
	_watch_threats()
	_think -= delta
	if _think <= 0.0 and _task != Task.WALK and not _tripping:
		_think = float(_q["think"]) * _rng.randf_range(0.8, 1.2)
		_decide()
	if _hyper_body() != null:
		_hyper_walk()
	else:
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
			if _salvage_task():
				return
			if _load_task(): # Turret ammo: arm the crop-fed turrets first
				return
			if _trip_task():
				return
			if not _carry.is_empty() and _deposit_task():
				return
			if _water_task():
				return
			if _rng.randf() < float(_q["farm"]) and _farm_task():
				return
			if _build_task():
				return
			if _upgrade_task():
				return
			if _lever_task():
				return
			_go(Vector2(_rng.randf_range(2.0, 6.0), clampf(_z + _rng.randf_range(-6.0, 6.0), -16.0, 16.0)), Task.IDLE)
		GameState.Phase.WARNING, GameState.Phase.WAVE:
			if GameState.phase == GameState.Phase.WARNING and _load_task(): # last-second loading
				return
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
	if need == 0 or Economy.cpu_can_spend(display_name, {&"water": need}, cliff_id):
		return false
	# Stand at the trough's far side, facing the spout.
	var at := well.global_transform * Vector3(0, 0, WellJackBuilder.TROUGH_Z - 1.0)
	_go(cliffs.plateau_coords(cliff_id, at), Task.FARM, func() -> void:
		if not is_instance_valid(well):
			return
		_face(well.global_transform * Vector3(0, 0, WellJackBuilder.TROUGH_Z))
		_act(&"water")
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
	if _follow_body():
		return
	if _ship_pos != Vector3.INF:
		global_position = _ship_pos
		return
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
				if plot.crop_def != null and not AmmoStore.can_harvest(cliff_id, plot.crop_def, -1):
					continue # its sacks of that are full: leave it on the plot
				best = plot
				act = "harvest"
			CropGrowth.Stage.PLANTED:
				if plot.crop_def != null and Economy.cpu_can_spend(display_name, {&"water": plot.crop_def.water_cost}, cliff_id):
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
	# Turret ammo: the crops its hungriest crop-fed turrets eat come first.
	for seed_id: StringName in _wanted_crops():
		var want_res: StringName = CropPlot.seed_res(seed_id)
		if Economy.amount(cliff_id, want_res) > 0 and Economy.cpu_can_spend(display_name, {want_res: 1}, cliff_id):
			return seed_id
	for seed_id: StringName in CropPlot.SEEDS:
		var res: StringName = CropPlot.seed_res(seed_id)
		if Economy.amount(cliff_id, res) > 0 and Economy.cpu_can_spend(display_name, {res: 1}, cliff_id):
			return seed_id
	# Out of seeds: it buys more on its next trip to the airship market.
	_need_seeds = true
	return &""


func _farm(plot: CropPlot, act: String) -> void:
	if not is_instance_valid(plot):
		return
	_face(plot.global_position)
	_act(&"harvest" if act == "harvest" else (&"water" if act == "water" else &"plant"))
	match act:
		"harvest":
			# Picks it itself: crops its turrets burn as upkeep go to the pool,
			# the rest it carries to its chest for you to sell.
			var crop := plot.crop_def
			var got: Dictionary = plot.growth.harvest()
			plot.call("_broadcast")
			# Turret ammo: it has no carry or workbench trips, so it makes the sacks
			# straight away, the bench's rate (3 a crop) into its cliff's bins.
			if crop != null and crop.load_item != &"":
				var raw := int(got.get(PlayerCarry.item_of(crop.id), 0))
				var sacks := mini(raw * HarvestRules.SACKS_PER_CROP, AmmoStore.room(cliff_id, crop.load_item))
				if sacks > 0:
					Economy.earn(cliff_id, {crop.load_item: sacks})
			var keep := _upkeep_crops()
			for res: StringName in got:
				if String(res).ends_with("_load"):
					# Turret ammo: loads go straight to the stockpile for its turrets.
					Economy.earn(cliff_id, {res: int(got[res])})
				elif res == PartnerTonic.ITEM:
					# Sarsaparilla is grown for the partner: brew it straight into tonics.
					Economy.earn(cliff_id, {res: int(got[res])})
					for k in int(got[res]):
						Economy.send_tonic(-1, cliff_id)
				elif keep.has(res):
					Economy.earn(cliff_id, {res: int(got[res])})
				else:
					_carry[res] = int(_carry.get(res, 0)) + int(got[res])
		"water":
			# The plot charges the pool itself; we just count it against our share.
			var cost := {&"water": plot.crop_def.water_cost}
			if Economy.cpu_can_spend(display_name, cost, cliff_id):
				plot.call("_use", -1, &"corn")
				Economy.cpu_record(display_name, cost)
		"plant":
			var seed_id := _seed_for()
			if seed_id != &"":
				plot.call("_use", -1, seed_id)
				Economy.cpu_record(display_name, {CropPlot.seed_res(seed_id): 1})


# ------------------------------------------------------------------ turret ammo

## Crops its crop-fed turrets need, most short of loads first (crop ids).
func _wanted_crops() -> Array[StringName]:
	var short := {}
	for t: Node in _my_turrets():
		var tt := t as Turret
		if tt == null or not tt.def.is_crop_fed():
			continue
		short[tt.def.crop_type] = int(short.get(tt.def.crop_type, 0)) + 1
	for c: StringName in short.keys():
		var crop := Defs.crop(c)
		if crop != null:
			short[c] = int(short[c]) - Economy.amount(cliff_id, crop.load_item)
	var out: Array[StringName] = []
	for c: StringName in short.keys():
		if int(short[c]) > 0:
			out.append(c)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return int(short[a]) > int(short[b]))
	return out


## Walk to the nearest of its unloaded crop-fed turrets that it has a load for and
## load it (BuildManager.cpu_load).
func _load_task() -> bool:
	var best: Turret = null
	var best_d := INF
	for t: Node in _my_turrets():
		var tt := t as Turret
		var sack: StringName = tt.call("cpu_sack") if tt != null and tt.has_method("cpu_sack") else (tt.def.load_item() if tt != null else &"") # universal turrets: any crop
		if tt == null or not tt.wants_load() or sack == &"" or Economy.amount(cliff_id, sack) <= 0:
			continue
		var d := global_position.distance_squared_to(tt.global_position)
		if d < best_d:
			best_d = d
			best = tt
	if best == null:
		return false
	var target := best
	var pc := cliffs.plateau_coords(cliff_id, target.global_position)
	_go(Vector2(pc.x + 1.4, pc.y), Task.FARM, func() -> void:
		if not is_instance_valid(target):
			return
		_face(target.global_position)
		_act(&"chest")
		var ok: bool = target.call("cpu_load_any") if target.has_method("cpu_load_any") else BuildManager.instance.cpu_load(target)
		if ok and GameState.has_flag("--cpulog"):
			print("[cpu] %s loaded the %s" % [display_name, target.def.display_name]))
	return true


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
		_act(&"chest")
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
## Balance tests (--simturret / --simgun): only this turret (Gatling Posts
## until it unlocks), only this gun (upgraded, never swapped).
static var force_turret := &""
static var force_gun := &""


func _turret_choice() -> StringName:
	if force_turret != &"":
		var pick := force_turret if Defs.is_unlocked(force_turret, GameState.tier_wave()) else &"gatling_post"
		return pick if Economy.cpu_can_spend(display_name, {&"scrap": Defs.cost_of(pick)}, cliff_id) else &""
	# Crewed: categories by name (a "Crewed Guns" tab now sits after Cliff Turrets).
	var cliff_turrets: Array = best_first(Defs.category_items("Cliff Turrets").filter(func(id: StringName) -> bool: return id != &"scaffold"))
	var air: Array = best_first(Defs.category_items("Air Defense"))
	var options: Array = []
	match quality:
		0:
			options = cliff_turrets.slice(0, 4)
			options.shuffle()
			options.append_array(cliff_turrets.slice(4)) # Tiers: can't afford the new ones yet? an older one
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
				options.append_array(best_first([&"buffalo_rifle", &"big_fifty", &"long_tom_rifle"]))
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
			# Control, area and pin turrets by their role, once the basics stand: a
			# Twin Mortar for swarms, a Bola Launcher to hold heavies for the rifles,
			# a Steam Cannon for crowds near the top, and a Flood Gate for a long line.
			var mine := _my_turrets()
			var have := func(id: StringName) -> bool:
				return mine.any(func(t: Node) -> bool: return t.get("def") != null and (t.get("def") as TurretDef).id == id)
			if mine.size() >= 4:
				if total - big >= 20 and not have.call(&"twin_mortar"):
					options.append(&"twin_mortar")
				if big > 0 and not have.call(&"bola_launcher"):
					options.append(&"bola_launcher")
				if not have.call(&"steam_cannon"):
					options.append(&"steam_cannon")
			if mine.size() >= 8 and not have.call(&"flood_gate"):
				options.append(&"flood_gate")
			options.append_array(cliff_turrets)
	var can_feed := _can_feed_another()
	for id: StringName in options:
		if Defs.RETIRED_TURRETS.has(id):
			continue # off the build menu for everyone (the universal crop-fed redesign)
		if Defs.is_turret(id) and Defs.turret(id).is_crop_fed() and not can_feed:
			continue # Turret ammo: no more crop-fed guns than its farm can load
		if Defs.is_turret(id) and Defs.is_unlocked(id, GameState.tier_wave()) and Economy.cpu_can_spend(display_name, {&"scrap": Defs.cost_of(id)}, cliff_id):
			return id
	return &""


## Turret ammo: room for one more crop-fed turret? About one and a half per farm
## plot (a plot ripens roughly once a build phase and gives 2-4 loads).
func _can_feed_another() -> bool:
	var fed := _my_turrets().filter(func(t: Node) -> bool: return t is Turret and (t as Turret).def.is_crop_fed()).size()
	return fed < int(_my_plots() * 1.5)


## Tiers: the unlocked ones of `ids`, newest tier first (Late, Mid, Early), so a
## CPU moves on to Mid and Late turrets once their wave comes (TierRules.best_first).
static func best_first(ids: Array) -> Array:
	return TierRules.best_first(ids, GameState.tier_wave())


## The junk heap by our house: pick it over once each build phase (our own scrap).
func _salvage_task() -> bool:
	var pile := get_tree().current_scene.find_child("Salvage%d" % cliff_id, true, false) as SalvagePile
	if pile == null or not pile.available:
		return false
	var pc := cliffs.plateau_coords(cliff_id, pile.global_position)
	_go(Vector2(pc.x - 2.6, pc.y), Task.FARM, func() -> void:
		_face(pile.global_position)
		_act(&"harvest")
		var got := pile.cpu_collect()
		if GameState.has_flag("--cpulog"):
			print("[cpu] %s salvaged the junk heap: +%d scrap" % [display_name, got]))
	return true


## Our own scrap buys turret upgrades: the cheapest one we can afford first.
func _upgrade_task() -> bool:
	var own := Economy.amount(cliff_id, ResNames.PERSONAL_ID)
	var best: Turret = null
	for n: Node in _my_turrets():
		var t := n as Turret
		if t == null or t.is_queued_for_deletion():
			continue
		var c := t.upgrade_cost()
		if c > 0 and c <= own and (best == null or c < best.upgrade_cost()):
			best = t
	if best == null:
		return false
	var pc := cliffs.plateau_coords(cliff_id, best.global_position)
	_go(Vector2(pc.x + 1.5, pc.y), Task.BUILD, func() -> void:
		if not is_instance_valid(best) or best.upgrade_cost() <= 0:
			return
		_face(best.global_position)
		_act(&"hammer")
		var cost := best.upgrade_cost()
		if Economy.spend(cliff_id, {ResNames.PERSONAL_ID: cost}):
			best.upgrade()
			if GameState.has_flag("--cpulog"):
				print("[cpu] %s upgraded the %s to tier %d (%d scrap)" % [display_name, best.def.display_name, best.tier, cost]))
	return true


func _my_turrets() -> Array:
	return get_tree().get_nodes_in_group("turrets").filter(func(t: Node) -> bool: return int(t.get("cliff_id")) == cliff_id)


## Farm plots to keep: one or two, plus one for every two crop-fed turrets (up to 5).
func _plots_wanted() -> int:
	var fed := _my_turrets().filter(func(t: Node) -> bool: return t is Turret and (t as Turret).def.is_crop_fed()).size()
	return mini(maxi(quality, quality + fed / 2), 5)


func _build_task() -> bool:
	# Medium and High keep a farm plot or two going (Low doesn't bother).
	if quality >= 1 and _my_plots() < _plots_wanted() and Economy.cpu_can_spend(display_name, {&"scrap": Defs.cost_of(&"farm_plot")}, cliff_id) 			and _my_turrets().size() >= 2:
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
		_act(&"hammer")
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
	var w := Gun.weapon(gun_id)
	if w.automatic:
		if _mag_left < 0:
			_mag_left = w.mag_size
		_shot_cd = shot_interval() # (the trigger's held: no hesitation between rounds)
		_mag_left -= 1
		if _mag_left <= 0:
			_shot_cd += w.reload_time
			_mag_left = w.mag_size
	else:
		_shot_cd = shot_interval() * _rng.randf_range(0.9, 1.15)
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


## Its own gun (bought and upgraded at the gunsmith on airship trips).
var gun_id := &"revolver"
var gun_code := 0


## Seconds between its shots: its quality's pace, never faster than the gun allows.
## Automatic guns (Crank Gatling, Bee Smoker) fire at the gun's own rate, held
## down like a player would, with the reload when the magazine runs dry.
func shot_interval() -> float:
	var w := Gun.weapon(gun_id)
	if w.automatic:
		return w.fire_interval
	return maxf(float(_q["shot"]), w.fire_interval)


## Rounds left in an automatic gun's magazine (-1: full, not started).
var _mag_left := -1


func _shoot(b: Bug) -> void:
	var muzzle := global_position + Vector3(0, 1.45, 0) + (b.global_position - global_position).normalized() * 0.5
	var dist := muzzle.distance_to(b.global_position)
	var hit_p := clampf(float(_q["hit"]) * (1.15 - dist / RANGE * 0.5), 0.05, 0.97)
	var aim := b.global_position + Vector3(0, 0.4, 0)
	var hit := _rng.randf() < hit_p
	if not hit:
		aim += Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.0, 1.5), _rng.randf_range(-1.5, 1.5))
	# Every peer: clients build this CPU as a puppet (World._spawn_cpus), same path.
	if NetworkManager.is_online():
		_shot_fx.rpc(muzzle, aim)
	else:
		_shot_fx(muzzle, aim)
	_shots += 1
	if GameState.has_flag("--cpulog") and _shots % 25 == 0:
		print("[cpu] %d shots, %d hits" % [_shots, _hits])
	if not hit:
		return
	var weak := _rng.randf() < float(_q["weak"])
	var dmg := Gun.damage_for(gun_id, gun_code) * float(Gun.weapon(gun_id).pellets)
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
	var pitch := _pitch if _target != null else 0.0
	_rig.animate(delta, _speed, false, pitch)
	# Clients: they build the same CPU (World._spawn_cpus) as a puppet of this one.
	_pose_t -= delta
	if _pose_t <= 0.0 and multiplayer.has_multiplayer_peer() and NetworkManager.is_online():
		_pose_t = POSE_INTERVAL
		_pose.rpc(Vector3(_d, _z, _yaw), pitch, _speed)


# ------------------------------------------------------------------ clients (puppet)

const POSE_INTERVAL := 1.0 / 15.0
var _pose_t := 0.0
var _net := Vector3.ZERO # d, z, yaw from the host
var _net_set := false


## Host -> clients: where the CPU stands, which way it faces, how fast it walks.
@rpc("authority", "call_remote", "unreliable")
func _pose(dzy: Vector3, pitch: float, speed: float) -> void:
	_net = dzy
	_pitch = pitch
	_speed = speed
	if not _net_set or Vector2(_d - dzy.x, _z - dzy.y).length() > 6.0:
		_d = dzy.x # first word from the host (or a big jump): snap
		_z = dzy.y
		_net_set = true


func _puppet(delta: float) -> void:
	if not _net_set:
		return
	var k := clampf(delta * 12.0, 0.0, 1.0)
	_d = lerpf(_d, _net.x, k)
	_z = lerpf(_z, _net.y, k)
	_yaw = _net.z
	global_position = _ship_pos if _ship_pos != Vector3.INF else _world(Vector2(_d, _z))
	rotation.y = lerp_angle(rotation.y, _yaw, clampf(delta * 10.0, 0.0, 1.0))
	_rig.animate(delta, _speed, false, _pitch)


## Host: play a rig action (water, plant, hammer...) here and on every client.
func _act(id: StringName) -> void:
	if NetworkManager.is_online():
		_act_rpc.rpc(id)
	else:
		_rig.play_action(id)


@rpc("authority", "call_local", "reliable")
func _act_rpc(id: StringName) -> void:
	_rig.play_action(id)


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


# ------------------------------------------------------------------ airship trips

## Where it stands aboard the Lucky Mandible (INF: at home on its plateau).
var _ship_pos := Vector3.INF
var _need_seeds := false
var _tripped_wave := -1
## Seeds it keeps in stock for its plots.
const SEED_STOCK := 3
const STOP_TIME := 2.5


## Once a build phase, while the ship's ring is down: grapple up to sell its
## harvest, restock seeds and see the gunsmith, then back to its lip.
func _trip_task() -> bool:
	if _tripped_wave == GameState.wave or Airship.ring_up or _ship() == null:
		return false
	if _carry.is_empty() and not _need_seeds and _gun_deal().is_empty():
		return false
	_tripped_wave = GameState.wave
	_go(Vector2(1.2, clampf(_z, -16.0, 16.0)), Task.BUILD, func() -> void: _do_trip())
	return true


func _ship() -> Node3D:
	return get_tree().current_scene.get_node_or_null("Airship") as Node3D


func _do_trip() -> void:
	var ship := _ship()
	if ship == null:
		return
	var vendor := ship.get_node_or_null("Vendor") as VendorCart
	var shop := ship.get_node_or_null("GunShop") as GunShop
	if _hyper_body() != null:
		await _hyper_trip(vendor, shop)
		return
	_act(&"hammer")
	Audio.play_at(&"hook_bite", global_position + Vector3.UP * 2.0, -4.0)
	await get_tree().create_timer(0.8).timeout
	if vendor != null:
		_board_at(vendor.global_position + vendor.global_basis.x * 1.8)
		await get_tree().create_timer(STOP_TIME).timeout
		_sell_and_restock(vendor)
	if shop != null:
		_board_at(shop.global_position + shop.global_basis.x * 1.8)
		await get_tree().create_timer(STOP_TIME).timeout
		_visit_gunsmith()
	_board_at(Vector3.INF)
	_go(Vector2(2.2, _z), Task.IDLE)


## Host and puppets: aboard at `p` (INF: back home).
func _board_at(p: Vector3) -> void:
	if NetworkManager.is_online():
		_board_rpc.rpc(p)
	else:
		_board_rpc(p)


@rpc("authority", "call_local", "reliable")
func _board_rpc(p: Vector3) -> void:
	_ship_pos = p
	_place()


func _sell_and_restock(vendor: VendorCart) -> void:
	var sold := {}
	for res: StringName in _carry.keys():
		if VendorCart.ITEMS.has(res):
			sold[res] = vendor.cpu_sell(cliff_id, res, int(_carry[res]))
			_carry.erase(res)
	# Seeds: chilies (they sell for its own scrap) when the pot allows, corn otherwise.
	var bought := 0
	# Turret ammo: seeds for the crops its crop-fed turrets eat, then chili and corn.
	var buy: Array[StringName] = []
	for c: StringName in _wanted_crops():
		var sr: StringName = CropPlot.seed_res(c)
		if VendorCart.SEEDS.has(sr):
			buy.append(sr)
	buy.append_array([&"seed_chili", &"seed_corn"] as Array[StringName])
	for seed_res: StringName in buy:
		while _seed_count() < SEED_STOCK:
			if not Economy.cpu_spend(display_name, {&"scrap": VendorCart.seed_cost(seed_res)}, cliff_id):
				break
			Economy.earn(cliff_id, {seed_res: 1})
			bought += 1
	_need_seeds = _seed_count() == 0
	if GameState.has_flag("--cpulog"):
		print("[cpu] %s at the market: sold %s, bought %d seeds" % [display_name, str(sold), bought])


func _seed_count() -> int:
	var n := 0
	for seed_id: StringName in CropPlot.SEEDS:
		n += Economy.amount(cliff_id, CropPlot.seed_res(seed_id))
	return n


## The best deal its own scrap can make at the gunsmith: a stronger gun, else
## the next upgrade for the one it carries. {} if nothing's worth it.
func _gun_deal() -> Dictionary:
	var own := Economy.amount(cliff_id, ResNames.PERSONAL_ID)
	var best := {}
	var best_dps := _dps(gun_id, gun_code) * 1.15 if force_gun == &"" else INF
	for item: Dictionary in GunShop.SHELF:
		if item["kind"] != "buy" or item["id"] == &"dino_rifle" or Gun.slot_of(item["id"]) != WeaponDef.Slot.PRIMARY:
			continue # (Weapon Slots: the partner sticks to its primary)
		var w := Gun.weapon(item["id"])
		if w == null or w.price_chitin > own:
			continue
		var d := _dps(item["id"], 0)
		if d > best_dps:
			best_dps = d
			best = {"kind": "buy", "id": item["id"], "cost": w.price_chitin}
	if not best.is_empty():
		return best
	var lvl := WeaponMods.level(gun_code)
	var gw := Gun.weapon(gun_id)
	var next := GunRarity.cost(gw.upgrade_costs, lvl)
	# Rarity: up to Epic on scrap; Legendary only with Meteor Iron in the stock.
	if next >= 0 and next <= own and (not GunRarity.needs_item(lvl) or Economy.amount(cliff_id, GunRarity.ITEM) > 0):
		return {"kind": "upgrade", "id": gun_id, "cost": next}
	return {}


static func _dps(id: StringName, code: int) -> float:
	var w := Gun.weapon(id)
	if w == null:
		return 0.0
	return Gun.damage_for(id, code) * float(w.pellets) / maxf(w.fire_interval, 0.05)


func _visit_gunsmith() -> void:
	var done: Array = []
	for i in 3:
		var deal := _gun_deal()
		if deal.is_empty() or not Economy.spend(cliff_id, {ResNames.PERSONAL_ID: int(deal["cost"])}):
			break
		if deal["kind"] == "buy":
			gun_id = deal["id"]
			_mag_left = -1
			gun_code = 0
			_rig.set_weapon(gun_id)
		else:
			if GunRarity.needs_item(WeaponMods.level(gun_code)):
				Economy.spend(cliff_id, {GunRarity.ITEM: 1})
			gun_code = WeaponMods.with_level(gun_code, WeaponMods.level(gun_code) + 1)
		done.append("%s %s" % [deal["kind"], deal["id"]])
	if GameState.has_flag("--cpulog") and not done.is_empty():
		print("[cpu] %s at the gunsmith: %s (now %s level %d)" % [display_name, ", ".join(done), gun_id, WeaponMods.level(gun_code)])


# ------------------------------------------------------------------ Hyper

## The Hyper CPU's body (a bot Player, World spawns it as "Hyper<cliff>"), or null.
var _hyper: Player = null
## Host: a flight to the current walk goal is under way.
var _flying := false
## Host: away on the airship (no other plans till it's home).
var _tripping := false


func _hyper_body() -> Player:
	if quality != HYPER:
		return null
	if _hyper == null or not is_instance_valid(_hyper):
		var root := get_tree().current_scene.get("players_root") as Node3D if get_tree().current_scene != null else null
		_hyper = root.get_node_or_null("Hyper%d" % cliff_id) as Player if root != null else null
		if _hyper != null and _rig != null:
			_rig.visible = false # (the body is what everyone sees)
	return _hyper


## Stand where the body is (host and puppets). False with no body.
func _follow_body() -> bool:
	var b := _hyper_body()
	if b == null or not b.is_node_ready():
		return false
	global_position = b.global_position
	if multiplayer.is_server() and not _flying:
		b.rotation.y = _yaw # (facing what it shoots at)
	return true


## Host: walking is flying now. A walk goal becomes a flight; arriving finishes the walk.
func _hyper_walk() -> void:
	if _task != Task.WALK or _flying:
		return
	var b := _hyper_body()
	var at := _world(Vector2(maxf(_goal.x, 3.5), _goal.y))
	if Vector2(b.global_position.x - at.x, b.global_position.z - at.z).length() < HyperPilot.ARRIVE:
		_arrive_walk()
		return
	_flying = true
	var ok := await _fly(at, false, _plan_to(b.global_position, at))
	_flying = false
	if not ok:
		b.pilot_reset(Transform3D(b.global_basis, at + Vector3.UP * 0.5)) # (a fall: back on its feet there, as a respawn would)
	_arrive_walk()


func _arrive_walk() -> void:
	_d = _goal.x
	_z = _goal.y
	if _task == Task.WALK:
		_task = Task.IDLE
		if _then.is_valid():
			var f := _then
			_then = Callable()
			f.call()


## Fly the body to `to` (onto the ship's deck with `ship`); true once it's there.
func _fly(to: Vector3, ship: bool = false, plan: Dictionary = {}) -> bool:
	var b := _hyper_body()
	if b == null:
		return false
	var pl := b.pilot as HyperPilot
	var res := [false, false]
	var ok := func(_s: float) -> void:
		res[0] = true
		res[1] = true
	var fail := func(_why: String) -> void:
		res[0] = true
	pl.arrived.connect(ok, CONNECT_ONE_SHOT)
	pl.failed.connect(fail, CONNECT_ONE_SHOT)
	pl.go(to, ship, plan)
	while not res[0] and is_instance_valid(b):
		await get_tree().physics_frame
	if pl.arrived.is_connected(ok):
		pl.arrived.disconnect(ok)
	if pl.failed.is_connected(fail):
		pl.failed.disconnect(fail)
	if GameState.has_flag("--cpulog"):
		print("[cpu] %s flew %.0f m in %.1f s (top %.0f m/s, %d swings, %d slings)%s" % [display_name, pl.path_len, pl.t,
				pl.top_speed, pl.swings, pl.slings, "" if res[1] else " and missed"])
	return res[1]


## The route book's plan for this flight: the learned leg it's most like, or a
## short hop for a few metres.
func _plan_to(from: Vector3, to: Vector3) -> Dictionary:
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	var plan := HyperLearn.route("run") if dist > 30.0 else {}
	if plan.is_empty():
		plan = HyperPlan.default()
		plan["n_sw"] = 0 if dist < 30.0 else 1
		plan["hops"] = clampi(int(dist / 6.0), 0, 6)
		plan["hook_dist"] = minf(dist * 0.8, 40.0)
	return plan


## The airship by air: up onto the deck, along it to the stall and the gunsmith, home again.
func _hyper_trip(vendor: VendorCart, shop: GunShop) -> void:
	_tripping = true
	var home := _world(Vector2(4.0, _z))
	await _fly(HyperLearn.deck_point(get_tree().current_scene as Node3D), true, HyperLearn.route("ship"))
	var short := {"hops": 0, "n_sw": 0, "hook_dist": 0.0}
	var walk := HyperPlan.default()
	walk.merge(short, true)
	if vendor != null:
		await _fly(vendor.global_position + vendor.global_basis.x * 1.8, false, walk)
		await get_tree().create_timer(STOP_TIME * 0.5).timeout
		_sell_and_restock(vendor)
	if shop != null:
		await _fly(shop.global_position + shop.global_basis.x * 1.8, false, walk)
		await get_tree().create_timer(STOP_TIME * 0.5).timeout
		_visit_gunsmith()
	if not await _fly(home, false, HyperLearn.route("home")):
		var b := _hyper_body()
		b.pilot_reset(Transform3D(b.global_basis, home + Vector3.UP * 0.5))
	_d = 4.0
	_tripping = false
	_go(Vector2(2.2, _z), Task.IDLE)
