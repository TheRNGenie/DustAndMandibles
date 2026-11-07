class_name FloorSwarm
extends Node
## Far-off bugs on the canyon floor, cheap (Logan): a bug that leaves its
## tunnel more than PROMOTE_DIST from the foot of the cliff it will climb isn't
## a Bug node yet. It's a row of numbers walking a straight line to that spot,
## drawn as a body instance in its kind's shared MultiMesh: no node, no
## physics, no crowd pushing, no legs. PROMOTE_DIST out it becomes a real bug
## (BugManager.spawn_at, crossing the last stretch as usual) once the cap of
## full bugs (max_active_bugs) has room; until then it waits on that line.
## Up to MAX_WALKERS wait or walk at once (Logan; more than that are dropped).
## Walkers count as alive, so the wave isn't over while any are out.
## Host decides; every peer walks the same lines from the same start (one RPC
## to add a batch, one to drop each when it turns real).

const PROMOTE_DIST := 30.0
## Same pace as a crossing bug (Bug: walk_speed x 2.2).
const PACE := 2.2
## Real bugs made per tick at most (a burst of node spawns would hitch the frame;
## the rest wait a tick on the line).
const PROMOTE_PER_TICK := 12
const MAX_WALKERS := 5000
## Walkers slow down over this many metres before the hold line, to this share of their pace.
const EASE_DIST := 45.0
const EASE_MIN := 0.2

## Off for now (Logan, 2026-11-07): 1,500 full bugs instead, refilled as they die.
static var enabled := false

var bm: BugManager
var _next := 0
## id -> {bug, cliff, lane, z, pos, goal, speed, slot, batch, xf}
var _walkers: Dictionary = {}


func count() -> int:
	return _walkers.size()


## Walkers by kind (debug).
func kinds() -> Dictionary:
	var out := {}
	for id: int in _walkers:
		var k: StringName = _walkers[id]["bug"]
		out[k] = int(out.get(k, 0)) + 1
	return out


## Host: should this crossing bug start in the swarm?
func wants(def: BugDef, pos: Vector3, goal: Vector3) -> bool:
	return enabled and def.behavior != BugDef.Behavior.BOSS and Vector2(goal.x - pos.x, goal.z - pos.z).length() > PROMOTE_DIST + 2.0


## Host: a far-off crossing bug joins the swarm (and on every peer).
func add(bug_id: StringName, cliff: int, lane: int, z: float, pos: Vector3, goal: Vector3) -> void:
	_next += 1
	_add.rpc(_next, bug_id, cliff, lane, z, pos, goal)


@rpc("authority", "call_local", "reliable")
func _add(id: int, bug_id: StringName, cliff: int, lane: int, z: float, pos: Vector3, goal: Vector3) -> void:
	var def := Defs.bug(bug_id)
	if def == null:
		return
	var spec := BugBuilder.build(def)
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var batch := LegBatch.of(spec["body"], Materials.toon_glide(0.03), root, true)
	var s := float(spec["scale"])
	# A straight line: the heading, the floor's slope along it, all worked out once.
	var flat := Vector3(goal.x - pos.x, 0.0, goal.z - pos.z)
	var dir := flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	var lift := float(spec["clearance"])
	var y0 := (Bug.cliffs.floor_height(pos.x, pos.z) if Bug.cliffs != null else pos.y) + lift
	var y1 := (Bug.cliffs.floor_height(goal.x, goal.z) if Bug.cliffs != null else goal.y) + lift
	_walkers[id] = {"bug": bug_id, "cliff": cliff, "lane": lane, "z": z, "pos": pos, "goal": goal,
			"left": flat.length(), "len": maxf(flat.length(), 0.001), "dir": dir, "y0": y0, "y1": y1,
			"speed": def.walk_speed * PACE, "slot": batch.take(), "batch": batch,
			"basis": Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3.ONE * s)} # (-Z forward, as Bug._ground_transform)


@rpc("authority", "call_local", "reliable")
func _drop(id: int) -> void:
	var w: Variant = _walkers.get(id)
	if w == null:
		return
	var batch := (w as Dictionary)["batch"] as LegBatch
	if batch != null:
		batch.give_back(int(w["slot"]))
	_walkers.erase(id)


func _physics_process(delta: float) -> void:
	if _walkers.is_empty():
		return
	var host := multiplayer.is_server()
	var promote: Array[int] = []
	# Room for this many more full bugs this tick (the cap counts full bugs only).
	var room := mini(PROMOTE_PER_TICK, Defs.WAVE_CONFIG.max_active_bugs - bm.real_count()) if host else 0
	LegBatch.motion = Color()
	for id: int in _walkers:
		var w: Dictionary = _walkers[id]
		# Easing off over the last stretch before the hold line, so a queue strings
		# out along the canyon floor instead of bunching at the foot of the wall
		# (the same on every peer: it only depends on how far each has to go).
		var ease := clampf((float(w["left"]) - PROMOTE_DIST) / EASE_DIST, EASE_MIN, 1.0)
		var left := maxf(float(w["left"]) - float(w["speed"]) * ease * delta, PROMOTE_DIST - 0.01)
		w["left"] = left
		var pos: Vector3 = (w["goal"] as Vector3) - (w["dir"] as Vector3) * left
		pos.y = lerpf(float(w["y1"]), float(w["y0"]), left / float(w["len"]))
		w["pos"] = pos
		(w["batch"] as LegBatch).put(int(w["slot"]), Transform3D(w["basis"] as Basis, pos))
		if host and left <= PROMOTE_DIST and promote.size() < room:
			promote.append(id)
	for id in promote:
		var w: Dictionary = _walkers[id]
		var at: Vector3 = w["pos"]
		at.y = Bug.cliffs.floor_height(at.x, at.z) if Bug.cliffs != null else at.y
		bm.spawn_at(w["bug"], int(w["cliff"]), int(w["lane"]), float(w["z"]), 0.0, Bug.State.CROSSING, at)
		_drop.rpc(id)


## Host: a wave ended badly or the run reset: everyone walking goes.
func clear() -> void:
	for id: int in _walkers.keys():
		_drop.rpc(id)
