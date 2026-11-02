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
	var tunnel: Array = WorldLayout.TUNNELS[(lane * 3 + cliff * 5 + _tunnel_spin) % WorldLayout.TUNNELS.size()]
	var def := Defs.bug(bug_id)
	if start_y <= 0.0 and is_big(def) and Bug.cliffs != null:
		# Brutes and the boss are heard before they're seen: dust and a rumble
		# at the tunnel mouth, then they come out of that same tunnel.
		var wall := int(tunnel[0])
		_rumble.rpc(Bug.cliffs.tunnel_mouth(wall, float(tunnel[1])), wall, def.size)
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
			var wall := int(tunnel[0])
			pos = Bug.cliffs.tunnel_mouth(wall, float(tunnel[1])) + Vector3(WorldLayout.side_sign(wall) * (1.2 + float(i) * 1.5), 0, 0)
		match def.behavior:
			BugDef.Behavior.BURROWER:
				# Tunnels in: pops up somewhere inside the plateau, never climbs.
				st = Bug.State.BURROWED
				pos = Bug.cliffs.plateau_point(cliff, randf_range(5.0, 12.0), z)
			BugDef.Behavior.FLIER:
				st = Bug.State.FLYING
				# Flies out of the same tunnels down the canyon, low over the floor.
				var wall := int(tunnel[0])
				pos = Bug.cliffs.tunnel_mouth(wall, float(tunnel[1])) + Vector3(-WorldLayout.side_sign(wall) * (1.5 + float(i) * 1.2), 1.8, 0)
		spawn_at(bug_id, cliff, lane, z, y, st, pos)


## Every peer: dust boils out of a tunnel mouth and the ground rumbles.
@rpc("authority", "call_local", "reliable")
func _rumble(mouth: Vector3, wall: int, size: float) -> void:
	TunnelRumble.play(get_parent(), mouth, wall, size, TELEGRAPH_TIME)
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


func alive_count() -> int:
	var n := 0
	for c in get_children():
		if c is Bug and (c as Bug).is_alive():
			n += 1
	return n


## Living bugs climbing a given cliff (for turret targeting).
func climbers_on(cliff: int) -> Array[Bug]:
	var out: Array[Bug] = []
	for c in get_children():
		var b := c as Bug
		if b != null and b.is_alive() and b.is_climbing() and b.cliff_id == cliff:
			out.append(b)
	return out


func _on_bug_died(bug: Bug, source: String, source_cliff: int) -> void:
	# Loot lands on the cliff the bug was climbing: your turrets earn for your partner.
	WaveDirector.note_kill(bug.def, source)
	var loot := {&"scrap": bug.def.scrap_drop, &"chitin": bug.def.chitin_drop * Weather.chitin_mult(GameState.weather)}
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
	Audio.play_at(&"bug_pop", pos)


@rpc("authority", "call_local", "reliable")
func _announce_kill(bug_name: String, bug_cliff: int, source: String, source_cliff: int, scrap: int) -> void:
	bug_killed.emit(bug_name, bug_cliff, source, source_cliff, {&"scrap": scrap})


func _on_bug_fled(bug: Bug) -> void:
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
		var d := b.global_position.distance_to(center)
		if d <= radius:
			b.receive_hit(damage * lerpf(1.0, 0.4, d / radius), center, (b.global_position - center).normalized(), true, 1.0, source, source_cliff)
	_explode.rpc(center, radius)


## A burning patch on the cliff face that hurts climbers passing through it.
func add_fire(cliff: int, center: Vector3, radius: float, dps: float, seconds: float, source: String, source_cliff: int) -> void:
	_fires.append({"cliff": cliff, "center": center, "radius": radius, "dps": dps, "left": seconds,
			"source": source, "source_cliff": source_cliff})
	_draw_fire.rpc(center, radius, seconds)


## Script time per tick the bugs that take turns may use (the nearest
## FULL_DETAIL_BUDGET update every tick on top of this).
const TURN_BUDGET_US := 5000.0
var _turn := 0
## Running average cost of one bug update (microseconds).
static var _avg_us := 60.0


static func note_update(us: int) -> void:
	_avg_us = lerpf(_avg_us, float(us), 0.01)


func _physics_process(delta: float) -> void:
	_hand_out_turns()
	if not multiplayer.is_server():
		return
	# Every other tick is plenty for keeping bugs apart.
	_sep_tick = not _sep_tick
	if _sep_tick:
		separate()
	if _fires.is_empty():
		return
	for f in _fires:
		f["left"] = float(f["left"]) - delta
		for b in climbers_on(int(f["cliff"])):
			if b.global_position.distance_to(f["center"]) <= float(f["radius"]):
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
const FULL_DETAIL_BUDGET := 40
const FAR_BUDGET := 100
var _detail_t := 0.0
var _sep_tick := false


func _process(delta: float) -> void:
	_detail_t -= delta
	if _detail_t > 0.0:
		return
	_detail_t = 0.25
	assign_detail()


func _hand_out_turns() -> void:
	var n := get_child_count()
	if n == 0:
		return
	var given := 0
	var looked := 0
	var turns := clampi(int(TURN_BUDGET_US / maxf(_avg_us, 5.0)), 20, 400)
	while given < turns and looked < n:
		_turn = (_turn + 1) % n
		looked += 1
		var b := get_child(_turn) as Bug
		if b != null and b.detail != 0:
			b.due = true
			given += 1


func assign_detail() -> void:
	var seen: Array[Bug] = []
	for c in get_children():
		var b := c as Bug
		if b == null or not b.is_alive():
			continue
		b.detail = b.detail_level()
		if b.detail < 2:
			seen.append(b)
	if seen.size() <= FULL_DETAIL_BUDGET:
		return
	seen.sort_custom(func(x: Bug, y: Bug) -> bool: return x.cam_dist < y.cam_dist)
	for i in range(FULL_DETAIL_BUDGET, seen.size()):
		seen[i].detail = 1 if i < FULL_DETAIL_BUDGET + FAR_BUDGET else 3


func separate() -> void:
	var groups: Dictionary = {} # surface key -> Array[Bug]
	for c in get_children():
		var lone := c as Bug
		if lone != null:
			lone.crouch = move_toward(lone.crouch, 0.0, 0.1)
			lone.ride = move_toward(lone.ride, 0.0, 0.05)
	for c in get_children():
		var b := c as Bug
		if b == null or not b.is_alive() or b.is_hidden():
			continue
		var key := -1
		match b.state:
			Bug.State.CLIMBING:
				key = b.cliff_id
			Bug.State.CROSSING:
				key = 20
			Bug.State.BREACHING, Bug.State.FLYING:
				key = 10 + b.cliff_id
			_:
				continue
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(b)
	for key: int in groups:
		var bugs: Array = groups[key]
		if bugs.size() < 2:
			continue
		var pos: Array[Vector2] = []
		var rad: Array[float] = []
		var wt: Array[float] = []
		for b: Bug in bugs:
			pos.append(Vector2(b.lane_z, b.climb_y) if key < 10 else Vector2(b.ground_pos.x, b.ground_pos.z))
			rad.append(float(b.spec["body_radius"]) * 0.85)
			wt.append(BugCrowd.weight(b.def.size, b.def.behavior == BugDef.Behavior.BOSS))
		var res := BugCrowd.resolve(pos, rad, wt)
		var push: Array[Vector2] = res["push"]
		for i in bugs.size():
			var b: Bug = bugs[i]
			b.crouch = move_toward(b.crouch, float(res["crouch"][i]), 0.25)
			b.ride = move_toward(b.ride, float(res["ride"][i]), 0.08)
		for i in bugs.size():
			if push[i] == Vector2.ZERO:
				continue
			var b: Bug = bugs[i]
			if key < 10:
				b.lane_z = clampf(b.lane_z + push[i].x, -WorldLayout.PLATEAU_WIDTH * 0.5 + 1.0, WorldLayout.PLATEAU_WIDTH * 0.5 - 1.0)
				# Shoved down or up the face, but never back below the bottom or over the lip.
				b.climb_y = clampf(b.climb_y + push[i].y, 0.0, WorldLayout.CLIFF_HEIGHT - 0.05)
			else:
				b.ground_pos += Vector3(push[i].x, 0.0, push[i].y)


# ------------------------------------------------------------------ loot

func _over_plateau(bug: Bug) -> bool:
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
	Economy.earn(cid, {&"chitin": drop.chitin})
	Economy.notify(peer_id, "Looted the %s: +%d chitin." % [drop.bug_name.to_lower(), drop.chitin])
	_remove_loot.rpc(id)


@rpc("authority", "call_local", "reliable")
func _remove_loot(id: int) -> void:
	var drop := _loot.get(id) as LootDrop
	_loot.erase(id)
	if drop != null and is_instance_valid(drop):
		Audio.play_at(&"coin", drop.global_position, -4.0)
		drop.queue_free()
