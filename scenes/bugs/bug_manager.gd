class_name BugManager
extends Node3D
## Spawns and tracks bugs (host decides, MultiplayerSpawner replicates), pays out
## loot when they die, runs area effects (splash, burning patches), and draws
## deaths, acid spit and fire on every peer.

signal bug_killed(bug_name: String, bug_cliff: int, source: String, source_cliff: int, loot: Dictionary)

## Chance a bug spawns with a cigarette (twice as fast).
const SMOKER_CHANCE := 0.01
## Trailer/testing: -1 = roll as normal, 0 = never smoke, 1 = always smoke.
static var smoke_override := -1

var vfx: VfxPool
var _spawner: MultiplayerSpawner
var _next_id := 0
static var instance: BugManager
var _next_loot := 0
var _loot: Dictionary = {} # loot id -> LootDrop (every peer)
var _stolen_loot: Dictionary = {} # host: loot id -> [cliff, {res: amount}] a thief dropped
## Burning chili patches: {cliff, center, radius, dps, left, source, source_cliff}
var _fires: Array[Dictionary] = []


func _ready() -> void:
	instance = self
	# Hands out update turns before the bugs run each tick.
	process_physics_priority = -10
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "BugSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(self)
	_spawner.spawn_function = _spawn_bug
	LaneClimber.spit_requested = _on_spit
	Bug.brood_burst = _on_brood_burst


## Host only: spawns `count` bugs of a type at the bottom of a lane.
var _tunnel_spin := 0
## Big bugs (brutes, the boss) announced at a tunnel mouth but not out yet.
var _pending := 0

## Seconds of dust and rumble at a tunnel mouth before a big bug comes out.
const TELEGRAPH_TIME := 3.0
const TunnelRumble := preload("res://scenes/bugs/tunnel_rumble.gd")


func spawn_group(bug_id: StringName, count: int, cliff: int, lane: int, start_y: float = 0.0) -> void:
	if not multiplayer.is_server():
		return
	_tunnel_spin += 1
	# Out of a tunnel down the canyon (a group's lane picks which).
	# Maps: [mouth, way out] from the map's tunnels (the canyon's are in either wall).
	var tunnel: Array = Bug.cliffs.tunnel((lane * 3 + cliff * 5 + _tunnel_spin) % Bug.cliffs.tunnel_count()) if Bug.cliffs != null else [Vector3.ZERO, Vector3.RIGHT]
	var def := Defs.bug(bug_id)
	if start_y <= 0.0 and is_big(def) and Bug.cliffs != null:
		# Brutes and the boss are heard before they're seen: dust and a rumble
		# at the tunnel mouth, then they come out of that same tunnel.
		_rumble.rpc(tunnel[0], tunnel[1], def.size) # Maps:
		_pending += count
		get_tree().create_timer(TELEGRAPH_TIME, false).timeout.connect(_spawn_heralded.bind(bug_id, count, cliff, lane, tunnel))
		return
	_spawn_from(bug_id, count, cliff, lane, start_y, tunnel)


## Telegraphed bugs that haven't left their tunnel yet (the wave isn't over while any wait).
func pending_count() -> int:
	return _pending


## Bugs worth a warning before they leave their tunnel.
static func is_big(def: BugDef) -> bool:
	return def != null and def.behavior in [BugDef.Behavior.TANK, BugDef.Behavior.BROOD, BugDef.Behavior.BOSS]


func _spawn_heralded(bug_id: StringName, count: int, cliff: int, lane: int, tunnel: Array) -> void:
	_pending = maxi(_pending - count, 0)
	if GameState.phase == GameState.Phase.GAME_OVER or GameState.phase == GameState.Phase.LOBBY:
		return
	_spawn_from(bug_id, count, cliff, lane, 0.0, tunnel)


func _spawn_from(bug_id: StringName, count: int, cliff: int, lane: int, start_y: float, tunnel: Array) -> void:
	var cfg := Defs.WAVE_CONFIG
	var def := Defs.bug(bug_id)
	for i in count:
		if alive_count() >= cfg.max_active_bugs:
			return
		# Out of the tunnel, each bug makes for its own spot at the foot of the
		# wall and picks its own way up from there.
		var half := WorldLayout.PLATEAU_WIDTH * 0.5 - 2.0
		var z := clampf(WorldLayout.LANE_Z[lane] + randf_range(-9.0, 9.0), -half, half)
		var y := start_y - float(i) * 0.9 # stagger groups so they climb in a column
		var st := Bug.State.CLIMBING
		var pos := Vector3.ZERO
		# Climbers crawl out of a tunnel in the opposite wall, one behind another,
		# and cross the canyon floor first (unless a test starts them up the face).
		if start_y <= 0.0:
			st = Bug.State.CROSSING
			pos = (tunnel[0] as Vector3) - (tunnel[1] as Vector3) * (1.2 + float(i) * 1.5) # Maps:
		match def.behavior:
			BugDef.Behavior.BURROWER:
				# Tunnels in: pops up somewhere inside the plateau, never climbs.
				st = Bug.State.BURROWED
				pos = Bug.cliffs.plateau_point(cliff, randf_range(5.0, 12.0), z)
			BugDef.Behavior.FLIER:
				st = Bug.State.FLYING
				# Flies out of the same tunnels down the canyon, low over the floor.
				pos = (tunnel[0] as Vector3) + (tunnel[1] as Vector3) * (1.5 + float(i) * 1.2) + Vector3(0, 1.8, 0) # Maps:
			BugDef.Behavior.BOSS:
				# Boss: some bosses leave the tunnel another way (the Locust Swarm Lord flies out).
				if start_y <= 0.0:
					var o := BossBrain.spawn_override(def.id, tunnel[0] as Vector3, tunnel[1] as Vector3) # Maps: mouth + way out
					if not o.is_empty():
						st = int(o["state"])
						pos = o["pos"]
		spawn_at(bug_id, cliff, lane, z, y, st, pos)


## Every peer: dust boils out of a tunnel mouth and the ground rumbles.
@rpc("authority", "call_local", "reliable")
func _rumble(mouth: Vector3, way_out: Vector3, size: float) -> void: # Maps: direction, not wall
	TunnelRumble.play(get_parent(), mouth, way_out, size, TELEGRAPH_TIME)
	if vfx != null:
		vfx.shake_requested.emit(mouth, 0.15 * size)


## Host: spawns one bug in any state (used for spiderlings and special bugs).
func spawn_at(bug_id: StringName, cliff: int, lane: int, z: float, y: float, st: int, pos: Vector3) -> void:
	_next_id += 1
	_spawner.spawn({"id": _next_id, "bug": bug_id, "cliff": cliff, "lane": lane,
			"z": z, "y": y, "hp": Defs.WAVE_CONFIG.hp_scale(GameState.wave), "state": st, "pos": pos,
			"smoke": (randf() < SMOKER_CHANCE or GameState.has_flag("--smokers")) if smoke_override < 0 else smoke_override == 1})


func _spawn_bug(data: Variant) -> Node:
	var d := data as Dictionary
	var bug := Bug.new()
	bug.name = "Bug%d" % int(d["id"])
	bug.net_id = int(d["id"])
	_by_id[bug.net_id] = bug
	bug.tree_exited.connect(_forget.bind(bug.net_id, bug))
	bug.smoker = bool(d.get("smoke", false))
	bug.setup(Defs.bug(StringName(d["bug"])), int(d["cliff"]), int(d["lane"]),
			float(d["z"]), float(d["y"]), float(d["hp"]), int(d.get("state", Bug.State.CLIMBING)),
			d.get("pos", Vector3.ZERO))
	# Dust rolls out of the tunnel mouth as bugs pour out (every peer; VfxPool throttles it).
	var st0 := int(d.get("state", Bug.State.CLIMBING))
	if vfx != null and (st0 == Bug.State.CROSSING or st0 == Bug.State.FLYING):
		vfx.tunnel_dust(d.get("pos", Vector3.ZERO))
	if multiplayer.is_server():
		bug.died.connect(_on_bug_died)
		bug.fled.connect(_on_bug_fled)
	return bug


func _forget(id: int, bug: Bug) -> void:
	_climbers_tick = -1 # never hand out a freed bug
	if _by_id.get(id) == bug:
		_by_id.erase(id)


func _exit_tree() -> void:
	BugFace.clear_pool()


func alive_count() -> int:
	var n := 0
	for c in get_children():
		if c is Bug and (c as Bug).is_alive():
			n += 1
	return n


## Living bugs climbing a given cliff (for turret targeting). Sorted out once
## per tick for every cliff and shared (read-only!): a bug may have died or
## crested since, so callers still check each one.
func climbers_on(cliff: int) -> Array[Bug]:
	var pf := Engine.get_physics_frames()
	var f := Engine.get_process_frames()
	if pf != _climbers_tick or f != _climbers_frame:
		_climbers_tick = pf
		_climbers_frame = f
		_climbers.clear()
		for c in get_children():
			var b := c as Bug
			if b != null and b.state == Bug.State.CLIMBING and b.is_alive():
				var list: Variant = _climbers.get(b.cliff_id)
				if list == null:
					var fresh: Array[Bug] = [b]
					_climbers[b.cliff_id] = fresh
				else:
					(list as Array[Bug]).append(b)
	var got: Variant = _climbers.get(cliff)
	return got if got != null else _NO_BUGS


var _climbers: Dictionary = {} # cliff -> Array[Bug], this tick's climbers_on()
var _climbers_tick := -1
var _climbers_frame := -1
const _NO_BUGS: Array[Bug] = []


func _on_bug_died(bug: Bug, source: String, source_cliff: int) -> void:
	# Loot lands on the cliff the bug was climbing: your turrets earn for your partner.
	WaveDirector.note_kill(bug.def, source)
	BossFx.on_bug_died(bug) # Boss: the Bone Collector eats the dead near it
	var loot := {&"scrap": bug.def.scrap_drop, &"chitin": bug.def.chitin_drop * Weather.chitin_mult(GameState.weather)}
	loot = Brand.kill_loot(loot, source_cliff) # Theme: Crossed Irons brand, more per kill
	loot[&"scrap"] = roundi(float(loot[&"scrap"]) * Perks.kill_scrap_mult(source)) # Perk: Scrap Scavenger
	Economy.earn(bug.cliff_id, loot)
	_corpse.rpc(get_path_to(bug))
	# Bugs that made it up off the cliff wall leave something to loot.
	var was := bug.died_in
	if was == Bug.State.BREACHING or was == Bug.State.CRESTING or (was == Bug.State.FLYING and _over_plateau(bug)):
		_next_loot += 1
		var extra := maxi(bug.def.chitin_drop, 1) + int(bug.def.size)
		var at := bug.global_position
		if was != Bug.State.FLYING:
			at.y = Bug.cliffs.ground_height_at(bug.cliff_id, at) if Bug.cliffs != null else at.y
		else:
			at.y = Bug.cliffs.ground_height_at(bug.cliff_id, at) if Bug.cliffs != null else at.y - 3.0
		_spawn_loot.rpc(_next_loot, at, extra, bug.def.display_name, bug.def.shell_color)
		# [Gameplay hook] A thief killed on its way out drops what it stole.
		if not bug.stolen.is_empty():
			_stolen_loot[_next_loot] = [bug.cliff_id, bug.stolen]
			_mark_stolen.rpc(_next_loot, bug.stolen)
	_pop.rpc(bug.global_position, bug.def.shell_color, float(bug.spec["scale"]))
	_announce_kill.rpc(bug.def.display_name, bug.cliff_id, source, source_cliff, bug.def.scrap_drop)
	bug.queue_free()


## Every peer leaves a flipping, twitching corpse where the bug died.
@rpc("authority", "call_local", "reliable")
func _corpse(path: NodePath) -> void:
	var bug := get_node_or_null(path) as Bug
	if bug != null and bug.is_inside_tree():
		BugCorpse.from_bug(bug)


@rpc("authority", "call_local", "reliable")
func _pop(pos: Vector3, color: Color, size: float) -> void:
	if vfx != null:
		vfx.pop(pos, color, size)
	# A light chitin crunch (the old "boing" pop is gone). Bigger shells crack a touch
	# lower and louder; Audio caps how many play at once and drops far-off ones.
	var s := clampf(size, 0.5, 3.0)
	Audio.play_crunch(pos, -6.0 + 2.0 * (s - 1.0), clampf(1.12 - 0.12 * s, 0.8, 1.1))


@rpc("authority", "call_local", "reliable")
func _announce_kill(bug_name: String, bug_cliff: int, source: String, source_cliff: int, scrap: int) -> void:
	bug_killed.emit(bug_name, bug_cliff, source, source_cliff, {&"scrap": scrap})


func _on_bug_fled(bug: Bug) -> void:
	if not bug.stolen.is_empty():
		_announce_line.rpc("A %s got over the lip with %s!" % [bug.def.display_name, Economy.describe(bug.stolen)])
	else:
		_announce_line.rpc("A %s got away with its loot!" % bug.def.display_name)
	bug.queue_free()


@rpc("authority", "call_local", "reliable")
func _announce_line(text: String) -> void:
	bug_killed.emit(text, -1, "", -2, {})


## Host: a Brood Mother bursts into six spiderlings where she is.
func _on_brood_burst(mother: Bug) -> void:
	for i in 6:
		var z := mother.lane_z + randf_range(-2.0, 2.0)
		if mother.state == Bug.State.CLIMBING:
			spawn_at(&"spiderling", mother.cliff_id, mother.lane, z, maxf(mother.climb_y - randf_range(0.0, 2.0), 0.0), Bug.State.CLIMBING, Vector3.ZERO)
		else:
			var p := mother.ground_pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			spawn_at(&"spiderling", mother.cliff_id, mother.lane, z, 0.0, Bug.State.BREACHING, p)


# ------------------------------------------------------------------ area effects (host)

## Damages every climbing bug on `cliff` within `radius` of `center` (falloff to 40% at the edge).
func splash(cliff: int, center: Vector3, radius: float, damage: float, source: String, source_cliff: int) -> void:
	for b in climbers_on(cliff):
		if b.cliff_id != cliff or not b.is_climbing():
			continue
		var d := b.global_position.distance_to(center)
		if d <= radius:
			b.receive_hit(damage * lerpf(1.0, 0.4, d / radius), center, (b.global_position - center).normalized(), true, 1.0, source, source_cliff)
	BossFx.on_splash(cliff, center, radius, damage, source, source_cliff) # Boss: Tumble Titan's boulder, corpse piles
	_explode.rpc(center, radius)


## A burning patch on the cliff face that hurts climbers passing through it.
func add_fire(cliff: int, center: Vector3, radius: float, dps: float, seconds: float, source: String, source_cliff: int) -> void:
	_fires.append({"cliff": cliff, "center": center, "radius": radius, "dps": dps, "left": seconds,
			"source": source, "source_cliff": source_cliff})
	BossFx.on_fire(cliff, center, radius) # Boss: fire burns husks the Bone Collector would eat
	_draw_fire.rpc(center, radius, seconds)


## Script time per tick the bugs that take turns may use (the nearest
## FULL_DETAIL_BUDGET update every tick on top of this). Set by the Bug Detail
## graphics setting (GraphicsQuality), like the budgets below.
static var TURN_BUDGET_US := 5000.0
var _turn := 0
## Running average cost of one bug update (microseconds).
static var _avg_us := 60.0


static func note_update(us: int) -> void:
	_avg_us = lerpf(_avg_us, float(us), 0.01)
	if CpuProf.on:
		CpuProf.add(&"bugs", us)


func _physics_process(delta: float) -> void:
	Bug.host = multiplayer.is_server()
	var t0 := Time.get_ticks_usec()
	_hand_out_turns(delta)
	if CpuProf.on:
		CpuProf.add(&"bm_turns", Time.get_ticks_usec() - t0)
	if not multiplayer.is_server():
		return
	_sync_t += delta
	if _sync_t >= SYNC_INTERVAL:
		_sync_t = 0.0
		t0 = Time.get_ticks_usec()
		send_states()
		if CpuProf.on:
			CpuProf.add(&"bm_sync", Time.get_ticks_usec() - t0)
	# Every other tick is plenty for keeping bugs apart.
	_sep_tick = not _sep_tick
	if _sep_tick:
		t0 = Time.get_ticks_usec()
		separate()
		if CpuProf.on:
			CpuProf.add(&"bm_separate", Time.get_ticks_usec() - t0)
	if _fires.is_empty():
		return
	for f in _fires:
		f["left"] = float(f["left"]) - delta
		for b in climbers_on(int(f["cliff"])):
			if b.is_climbing() and b.cliff_id == int(f["cliff"]) and b.global_position.distance_to(f["center"]) <= float(f["radius"]):
				b.status.burn(float(f["dps"]), 1.5, str(f["source"]), int(f["source_cliff"]))
	_fires = _fires.filter(func(f: Dictionary) -> bool: return float(f["left"]) > 0.0)


@rpc("authority", "call_local", "reliable")
func _explode(center: Vector3, radius: float) -> void:
	Audio.play_at(&"dynamite", center)
	if vfx != null:
		vfx.pop(center, Palette.GLOW_YELLOW, radius * 0.8)
		vfx.pop(center, Palette.ROCK_C, radius * 0.5)


@rpc("authority", "call_local", "reliable")
func _draw_fire(center: Vector3, radius: float, seconds: float) -> void:
	if vfx != null:
		vfx.fire_patch(center, radius, seconds)


# ------------------------------------------------------------------ spitter acid

## Host: a spitter lobs acid at a random turret on the cliff it faces.
func _on_spit(bug: Bug, damage: float, max_range: float) -> void:
	var targets: Array[Node3D] = []
	for s: Node in get_tree().get_nodes_in_group("turrets"):
		var t := s as Node3D
		if int(t.get("cliff_id")) != bug.cliff_id and t.global_position.distance_to(bug.global_position) < max_range:
			targets.append(t)
	if targets.is_empty():
		return
	var target := targets[randi() % targets.size()]
	var flight := 1.2
	_draw_spit.rpc(bug.global_position, target.global_position + Vector3.UP, flight)
	var target_ref: WeakRef = weakref(target)
	get_tree().create_timer(flight).timeout.connect(func() -> void:
		var t := target_ref.get_ref() as Node3D
		if t != null and t.has_method("structure_damage"):
			t.call("structure_damage", damage, "Spitter acid"))


@rpc("authority", "call_local", "reliable")
func _draw_spit(from: Vector3, to: Vector3, flight: float) -> void:
	Audio.play_at(&"acid_spit", from)
	if vfx != null:
		vfx.acid_blob(from, to, flight)


## Host: no two bugs overlap; heavier bugs shove lighter ones aside (BugCrowd).

## At most this many bugs get full-detail updates (every tick) at once; the rest
## of a close crowd updates every few ticks. The nearest ones win.
static var FULL_DETAIL_BUDGET := 40
## Faces aren't drawn past this: bugs further away don't wear one.
static var FACE_RANGE := 17.0
const FACES_PER_PASS := 8
static var FAR_BUDGET := 100
## Least time between turns (s) for a bug on screen / off screen (GraphicsQuality Hz).
static var TURN_GAP_ON := 1.0 / 30.0
static var TURN_GAP_OFF := 1.0 / 6.0


## Bug Detail setting: 0 Low, 1 Medium, 2 High (GraphicsQuality).
static func set_detail_level(lvl: int) -> void:
	FULL_DETAIL_BUDGET = GraphicsQuality.BUG_FULL_DETAIL[lvl]
	FAR_BUDGET = GraphicsQuality.BUG_FAR_BUDGET[lvl]
	TURN_BUDGET_US = GraphicsQuality.BUG_TURN_BUDGET_US[lvl]
	FACE_RANGE = GraphicsQuality.BUG_FACE_RANGE[lvl]
	TURN_GAP_ON = 1.0 / GraphicsQuality.BUG_ON_SCREEN_HZ[lvl]
	TURN_GAP_OFF = 1.0 / GraphicsQuality.BUG_OFF_SCREEN_HZ[lvl]
var _detail_t := 0.0
var _sep_tick := false


func _process(delta: float) -> void:
	_detail_t -= delta
	if _detail_t > 0.0:
		return
	_detail_t = 0.25
	var t0 := Time.get_ticks_usec()
	assign_detail()
	if CpuProf.on:
		CpuProf.add(&"p:bm_detail", Time.get_ticks_usec() - t0)


func _hand_out_turns(delta: float) -> void:
	var n := get_child_count()
	if n == 0:
		return
	var given := 0
	var looked := 0
	var turns := clampi(int(TURN_BUDGET_US / maxf(_avg_us, 5.0)), 20, 400)
	# A bug that had a turn very recently waits (its brain catches up on the
	# time when it next runs), so a small wave doesn't update every bug every tick.
	var gap_on := TURN_GAP_ON - delta - 0.0001
	var gap_off := TURN_GAP_OFF - delta - 0.0001
	while given < turns and looked < n:
		_turn = (_turn + 1) % n
		looked += 1
		var b := get_child(_turn) as Bug
		if b != null and b.detail != 0 and not b.due and b._tick_acc >= (gap_off if b.detail == 2 else gap_on):
			b.due = true
			given += 1


func assign_detail() -> void:
	var cam := get_viewport().get_camera_3d()
	var seen: Array[Bug] = []
	var dists := PackedFloat32Array()
	var cam_pos := cam.global_position if cam != null else Vector3.ZERO
	var frustum: Array[Plane] = cam.get_frustum() if cam != null else ([] as Array[Plane])
	for c in get_children():
		var b := c as Bug
		if b == null or not b.is_alive():
			continue
		b.detail = b.detail_from(cam_pos, frustum) if cam != null else 0
		if b.detail < 2:
			seen.append(b)
			dists.append(b.cam_dist)
	if seen.size() > FULL_DETAIL_BUDGET:
		# The nearest FULL_DETAIL_BUDGET stay full detail, the next FAR_BUDGET far,
		# the rest of a close crowd take turns (cut-offs from a native sort).
		var sorted := dists.duplicate()
		sorted.sort()
		var near_cut := sorted[FULL_DETAIL_BUDGET - 1]
		var far_cut := sorted[mini(FULL_DETAIL_BUDGET + FAR_BUDGET - 1, sorted.size() - 1)]
		for i in seen.size():
			var d := dists[i]
			if d > near_cut:
				seen[i].detail = 1 if d <= far_cut else 3
	# Faces (pupils, brows, mandibles) only on full-detail bugs close enough to
	# see them; a few new ones per pass so a rush of bugs can't stall a frame.
	var handed := 0
	for c in get_children():
		var b := c as Bug
		if b == null:
			continue
		var want := cam != null and b.is_alive() and b.detail == 0 and b.cam_dist < (FACE_RANGE + 3.0 if b.has_face() else FACE_RANGE)
		if want and not b.has_face():
			if handed >= FACES_PER_PASS:
				continue
			handed += 1
		b.set_face(want)


func separate() -> void:
	# One pass: every bug eases out of last pass's duck/ride, and the ones on a
	# surface are grouped by it; then each group is resolved on packed arrays.
	var groups: Dictionary = {} # surface key -> Array of bugs
	for c in get_children():
		var b := c as Bug
		if b == null:
			continue
		b.crouch = move_toward(b.crouch, 0.0, 0.1)
		b.ride = move_toward(b.ride, 0.0, 0.05)
		var st := b.state
		if st == Bug.State.DEAD or st == Bug.State.BURROWED or b.health.dead:
			continue
		var key := -1
		if st == Bug.State.CLIMBING:
			key = b.cliff_id
		elif st == Bug.State.CROSSING:
			key = 20
		elif st == Bug.State.BREACHING or st == Bug.State.FLYING:
			key = 10 + b.cliff_id
		else:
			continue
		var g: Variant = groups.get(key)
		if g == null:
			groups[key] = [b]
		else:
			(g as Array).append(b)
	var lo_z := -WorldLayout.PLATEAU_WIDTH * 0.5 + 1.0
	var hi_z := WorldLayout.PLATEAU_WIDTH * 0.5 - 1.0
	for key: int in groups:
		var bugs: Array = groups[key]
		var n := bugs.size()
		if n < 2:
			continue
		var pos := PackedVector2Array()
		pos.resize(n)
		var rad := PackedFloat32Array()
		rad.resize(n)
		var wt := PackedFloat32Array()
		wt.resize(n)
		for i in n:
			var b: Bug = bugs[i]
			pos[i] = Vector2(b.lane_z, b.climb_y) if key < 10 else Vector2(b.ground_pos.x, b.ground_pos.z)
			rad[i] = b.crowd_r
			wt[i] = b.crowd_w
		var res := BugCrowd.resolve_packed(pos, rad, wt)
		var push: PackedVector2Array = res["push"]
		var crouch: PackedFloat32Array = res["crouch"]
		var ride: PackedFloat32Array = res["ride"]
		for i in n:
			var b: Bug = bugs[i]
			b.crouch = move_toward(b.crouch, crouch[i], 0.25)
			b.ride = move_toward(b.ride, ride[i], 0.08)
			var d := push[i]
			if d == Vector2.ZERO:
				continue
			if key < 10:
				b.lane_z = clampf(b.lane_z + d.x, lo_z, hi_z)
				# Shoved down or up the face, but never back below the bottom or over the lip.
				b.climb_y = clampf(b.climb_y + d.y, 0.0, WorldLayout.CLIFF_HEIGHT - 0.05)
			else:
				b.ground_pos += Vector3(d.x, 0.0, d.y)


# ------------------------------------------------------------------ loot

func _over_plateau(bug: Bug) -> bool:
	if not WorldLayout.map().is_canyon(): # Maps:
		return WorldLayout.map().cliff_at(bug.global_position) >= 0
	return absf(bug.global_position.x) > WorldLayout.HALF_GAP + 1.0


@rpc("authority", "call_local", "reliable")
func _spawn_loot(id: int, at: Vector3, chitin: int, bug_name: String, shell: Color) -> void:
	var drop := LootDrop.new()
	drop.loot_id = id
	drop.chitin = chitin
	drop.bug_name = bug_name
	drop.color = shell
	drop.name = "Loot%d" % id
	get_parent().add_child(drop)
	drop.global_position = at
	_loot[id] = drop


## Every peer: this heap also holds stolen goods (shown in its prompt).
@rpc("authority", "call_local", "reliable")
func _mark_stolen(id: int, amounts: Dictionary) -> void:
	var drop := _loot.get(id) as LootDrop
	if drop != null and is_instance_valid(drop):
		drop.stolen = amounts


## Local player pressed E on a loot heap.
func request_loot(id: int) -> void:
	if multiplayer.is_server():
		_take_loot(multiplayer.get_unique_id(), id)
	else:
		_request_loot.rpc_id(1, id)


@rpc("any_peer", "reliable")
func _request_loot(id: int) -> void:
	if multiplayer.is_server():
		_take_loot(multiplayer.get_remote_sender_id(), id)


func _take_loot(peer_id: int, id: int) -> void:
	var drop := _loot.get(id) as LootDrop
	if drop == null or not is_instance_valid(drop):
		return
	var cid := NetworkManager.cliff_of(peer_id) if NetworkManager.is_online() else WorldLayout.WEST
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id:
			cid = (n as Player).cliff_id
	var got := Brand.heap_loot(peer_id, drop.chitin) # Theme: Crossed Irons brand, richer loot
	Economy.earn(cid, got)
	Economy.notify(peer_id, "Looted the %s: +%s." % [drop.bug_name.to_lower(), Economy.describe(got)])
	# [Gameplay hook] Stolen goods go back to the stockpile they were taken from.
	if _stolen_loot.has(id):
		var back: Array = _stolen_loot[id]
		_stolen_loot.erase(id)
		Economy.earn(int(back[0]), back[1])
		Economy.notify_cliff(int(back[0]), "Got back the stolen %s." % Economy.describe(back[1]))
	_remove_loot.rpc(id)


@rpc("authority", "call_local", "reliable")
func _remove_loot(id: int) -> void:
	var drop := _loot.get(id) as LootDrop
	_loot.erase(id)
	if drop != null and is_instance_valid(drop):
		Audio.play_at(&"coin", drop.global_position, -4.0)
		drop.queue_free()


# ------------------------------------------------------------------ state sync

## Every peer: bugs by network id (the batched state sync finds them by it).
var _by_id: Dictionary = {}
var _sync_t := 0.0
var _net_packets := 0
var _net_bugs := 0
var _net_log_t := 0
## How often the host sends every bug's state, and how many bugs per packet
## (kept under one MTU, so a lost packet only costs those bugs a tick).
const SYNC_INTERVAL := 0.1
const SYNC_PER_PACKET := 48


## Host: packs every bug's replicated state (see Bug) into a few unreliable
## packets: one batched sync for the whole crowd instead of a synchronizer each.
func send_states() -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.get_peers().is_empty():
		return
	var buf := PackedByteArray()
	var count := 0
	for c in get_children():
		var b := c as Bug
		if b == null or b.net_id == 0:
			continue
		BugSync.pack_into(buf, b.net_id, b.state, b.cliff_id, b.crouch, b.ride, b.health.hp,
				b.climb_y, b.lane_z, b.crest_t, b.ground_pos)
		count += 1
		if count >= SYNC_PER_PACKET:
			_bug_states.rpc(buf)
			buf = PackedByteArray()
			count = 0
	if count > 0:
		_bug_states.rpc(buf)


## Clients: apply a batch of bug states from the host (Bug smooths toward them).
@rpc("authority", "call_remote", "unreliable")
func _bug_states(buf: PackedByteArray) -> void:
	var t0 := Time.get_ticks_usec()
	var n := _apply_states(buf)
	if CpuProf.on:
		CpuProf.add(&"p:bm_sync_in", Time.get_ticks_usec() - t0)
	if GameState.has_flag("--netlog"):
		_net_packets += 1
		_net_bugs += n
		if Time.get_ticks_msec() - _net_log_t > 5000:
			_net_log_t = Time.get_ticks_msec()
			print("[net] bug sync: %d packets, %d bug states, %d bugs known here" % [_net_packets, _net_bugs, _by_id.size()])


## Clients: BugSync.unpack_states() written straight onto the bugs, without
## a Dictionary per bug. Returns how many states the packet held.
func _apply_states(buf: PackedByteArray) -> int:
	var n := 0
	var o := 0
	var size := buf.size()
	while o + 13 <= size:
		var st := buf.decode_u8(o + 4)
		var face := st == 0 or st == 1 or st == 3
		if o + (19 if face else 25) > size:
			break
		n += 1
		var b := _by_id.get(buf.decode_u32(o)) as Bug
		if b == null or not is_instance_valid(b):
			o += 19 if face else 25
			continue
		b.state = st
		b.cliff_id = buf.decode_u8(o + 5)
		b.crouch = float(buf.decode_u8(o + 6)) / 255.0
		b.ride = buf.decode_half(o + 7)
		var hp := buf.decode_float(o + 9)
		if face:
			b.climb_y = buf.decode_half(o + 13)
			b.lane_z = buf.decode_half(o + 15)
			b.crest_t = float(buf.decode_u16(o + 17)) / 65535.0
			o += 19
		else:
			b.ground_pos = Vector3(buf.decode_float(o + 13), buf.decode_float(o + 17), buf.decode_float(o + 21))
			o += 25
		if not is_equal_approx(b.health.hp, hp):
			b.health.hp = hp
	return n
