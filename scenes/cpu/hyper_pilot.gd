class_name HyperPilot
extends Node
## The Hyper CPU's hands on a real Player body (Player.bot): every physics tick
## it decides what to press, and the body moves by exactly the rules a person's
## does (slide-hops, the grapple's pull and swing, the slingshot, air control).
## No teleports, no speed it didn't earn. How it flies a leg comes from a
## HyperPlan, learned by trial (HyperLearn) and kept in the route book.
##
##   pilot.go(goal)            fly to a point on the ground
##   pilot.go(deck, true)      fly up onto the airship (pull in on its ring)

signal arrived(seconds: float)
signal failed(why: String)

## Close enough, standing on the ground.
const ARRIVE := 3.0
const TIMEOUT := 40.0
## Don't hook anything nearer than this for a swing (it would just yank you).
const SWING_MIN := 9.0

var body: Player
var plan: Dictionary = HyperPlan.default()
var goal := Vector3.INF
var to_ship := false
## Give up after this long (the learner cuts hopeless tries short).
var timeout := TIMEOUT

## This leg, so far.
var t := 0.0
var hops := 0
var swings := 0
var slings := 0
var top_speed := 0.0
var path_len := 0.0

var _swing_t := 0.0
## --hypertrace: print where it is twice a second.
var trace := GameState.has_flag("--hypertrace")
var _trace_t := 0.0
var _final := false
var _stuck := 0.0
var _last := Vector3.ZERO


func setup(p: Player) -> void:
	body = p
	p.bot = true
	p.pilot = self
	p.ready.connect(func() -> void:
		p.grapple.slung.connect(func(_v: Vector3) -> void: slings += 1), CONNECT_ONE_SHOT)


func go(to: Vector3, ship: bool = false, with_plan: Dictionary = {}) -> void:
	goal = to if ship else ground(body, to)
	to_ship = ship
	if not with_plan.is_empty():
		plan = with_plan
	t = 0.0
	hops = 0
	swings = 0
	slings = 0
	top_speed = 0.0
	path_len = 0.0
	_final = false
	_last = body.global_position
	body.hotbar_use_grapple()


## The ground under (or over) `at`: goals and starts sit on it.
static func ground(p: Node3D, at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 30.0,
			WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE)
	if p is CollisionObject3D:
		q.exclude = [(p as CollisionObject3D).get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3) + Vector3.UP * 0.1 if not hit.is_empty() else at


func stop() -> void:
	goal = Vector3.INF
	body.intent.release_all()


func flying() -> bool:
	return goal != Vector3.INF


## Player._physics_process calls this first, every tick.
func tick(delta: float) -> void:
	var it := body.intent
	it.move = Vector2.ZERO
	for a: StringName in [&"jump", &"slide", &"sprint"]:
		it.release(a)
	if goal == Vector3.INF:
		it.release_all()
		return
	t += delta
	var p := body.global_position
	path_len += p.distance_to(_last)
	_last = p
	var v := body.velocity
	top_speed = maxf(top_speed, v.length())
	var flat := Vector3(goal.x - p.x, 0.0, goal.z - p.z)
	var dist := flat.length()
	var g := body.grapple
	var on_floor := body.is_on_floor()
	if trace:
		_trace_t -= delta
		if _trace_t <= 0.0:
			_trace_t = 0.5
			print("[hyper] t %.1f at %s v %.1f (vy %.1f) %s floor %s slide %s dist %.1f hops %d swings %d down %s mantle %s" % [t, str(p.snapped(Vector3.ONE * 0.1)), v.length(), v.y,
					["none", "PULL", "SWING"][g.mode], on_floor, body.is_sliding(), dist, hops, swings, body.is_downed(), body._mantling])
	if _arrived(p, on_floor, v):
		var took := t
		stop()
		arrived.emit(took)
		return
	if t > timeout or body.is_down_in_canyon():
		var why := "fell" if body.is_down_in_canyon() else "timeout"
		stop()
		failed.emit(why)
		return
	match g.mode:
		Grapple.Mode.PULL:
			it.hold(&"fire")
			return
		Grapple.Mode.SWING:
			_ride_swing(delta, flat)
			return
	it.release(&"fire")
	it.release(&"alt_fire")
	if g._cd <= 0.0:
		if _try_final(p, dist):
			return
		if _try_swing(dist, flat, on_floor):
			return
		if (body.is_plummeting() or p.y < goal.y - 5.0) and _rescue(flat):
			return
	if _unstick(delta, flat, v, on_floor):
		return
	if on_floor:
		_run(dist, flat, v)
	else:
		_air(flat, v)


## Not getting anywhere (a wall, a ledge, hung under a lip): jump it (a mantle
## if it's a ledge); still stuck, hook up and over it toward the goal.
func _unstick(delta: float, flat: Vector3, v: Vector3, on_floor: bool) -> bool:
	var hs := Vector2(v.x, v.z).length()
	var near := flat.length() < ARRIVE
	_stuck = _stuck + delta if hs < 1.5 and absf(v.y) < 6.0 and not (near and on_floor) else 0.0
	if _stuck < 0.3:
		return false
	var it := body.intent
	_look(flat)
	it.move = Vector2(0, -1)
	if _stuck < 0.7:
		it.press(&"jump") if on_floor else it.hold(&"jump") # (held against a ledge: a mantle)
		return true
	if body.grapple._cd > 0.0:
		return true
	for pitch: float in [40.0, 60.0, 25.0, 75.0, 10.0]:
		var dir := flat.normalized() * cos(deg_to_rad(pitch)) + Vector3.UP * sin(deg_to_rad(pitch))
		var hit := _probe(dir)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(_cam()) > 3.0:
			_look(dir)
			it.hold(&"fire")
			_stuck = 0.0
			return true
	_stuck = 0.0
	return false


func _arrived(p: Vector3, on_floor: bool, v: Vector3) -> bool:
	if to_ship:
		return on_floor and p.distance_to(goal) < 8.0
	# (at any speed: the ground brakes a runner in a few metres; a pull in is caught as it passes)
	return (on_floor or body.grapple.mode == Grapple.Mode.PULL) and Vector2(p.x - goal.x, p.z - goal.z).length() < ARRIVE 			and absf(p.y - goal.y) < 3.0


# ------------------------------------------------------------------ aiming

## Look along `dir` (yaw on the body, pitch on the head), as a mouse would.
func _look(dir: Vector3) -> void:
	var d := dir.normalized()
	body.rotation.y = atan2(-d.x, -d.z)
	body.head.rotation.x = clampf(asin(clampf(d.y, -1.0, 1.0)), -1.5, 1.5)


func _cam() -> Vector3:
	return body.camera.global_position


## What the hook would bite if fired along `dir` ({} = nothing in range).
func _probe(dir: Vector3) -> Dictionary:
	var from := _cam()
	return body.grapple.cast(from, from + dir.normalized() * Grapple.RANGE)


# ------------------------------------------------------------------ the moves

## In range of the goal: pull straight in on it (the ship: on its boarding ring).
func _try_final(p: Vector3, dist: float) -> bool:
	var target := Airship.ring_position() if to_ship else goal
	if not to_ship:
		var ahead := Vector3(goal.x - p.x, 0.0, goal.z - p.z).normalized()
		target = goal + ahead * 6.0 * float(plan.get("lead", 0.3)) + Vector3.UP * 0.3
	var reach := (target - _cam()).length()
	if reach > Grapple.RANGE - 1.0 or (not to_ship and dist > float(plan["hook_dist"])) or (not to_ship and dist < 7.0):
		return false
	var dir := target - _cam()
	var hit := _probe(dir)
	if hit.is_empty() or (hit["position"] as Vector3).distance_to(target) > 2.5:
		return false
	_look(dir)
	body.intent.hold(&"fire")
	_final = true
	return true


## On the way: hook up and swing, as the plan's next slot says.
func _try_swing(dist: float, flat: Vector3, on_floor: bool) -> bool:
	if _auto():
		return _try_chain(dist, flat)
	if swings >= int(plan["n_sw"]) or swings >= HyperPlan.SLOTS or dist < 10.0:
		return false
	if hops < int(plan["hops"]) and dist > float(plan["hop_min"]) and not body.is_plummeting():
		return false # hop up some speed first
	var slot: Dictionary = plan["swings"][swings]
	var bearing := flat.normalized()
	# Try the planned direction, then a few near it (a miss is a wasted cooldown).
	for k: Vector2 in [Vector2.ZERO, Vector2(0, 12), Vector2(15, 0), Vector2(-15, 0), Vector2(0, -12), Vector2(0, 25)]:
		var yaw := deg_to_rad(float(slot["yaw"]) + k.x)
		var pitch := deg_to_rad(clampf(float(slot["pitch"]) + k.y, 2.0, 85.0))
		var dir := bearing.rotated(Vector3.UP, yaw) * cos(pitch) + Vector3.UP * sin(pitch)
		var hit := _probe(dir)
		if hit.is_empty():
			continue
		var at: Vector3 = hit["position"]
		if at.distance_to(_cam()) < SWING_MIN or (Airship.ring_up and Grapple._on_airship(hit["collider"] as Node)):
			continue
		_look(dir)
		body.intent.hold(&"alt_fire")
		_swing_t = 0.0
		return true
	swings += 1 # nothing to hook that way: skip the slot
	return false


func _auto() -> bool:
	return float(plan.get("auto", 0.0)) > 0.5


## The slingshot chain: each time the launcher's ready, hook the best anchor
## ahead (high and toward the goal), until fast enough or nearly there.
func _try_chain(dist: float, flat: Vector3) -> bool:
	if swings >= 60 or dist < float(plan["chain_stop"]) or body.velocity.length() > float(plan["vmax"]):
		return false
	if hops < int(plan["hops"]) and dist > float(plan["hop_min"]) and not body.is_plummeting():
		return false
	var bearing := flat.normalized()
	var cam := _cam()
	var best_dir := Vector3.ZERO
	var best := -INF
	for yaw: float in [0.0, -15.0, 15.0, -30.0, 30.0]:
		for pitch: float in [15.0, 30.0, 45.0, 60.0, 75.0]:
			var dir := bearing.rotated(Vector3.UP, deg_to_rad(yaw)) * cos(deg_to_rad(pitch)) + Vector3.UP * sin(deg_to_rad(pitch))
			var hit := _probe(dir)
			if hit.is_empty():
				continue
			var off: Vector3 = (hit["position"] as Vector3) - cam
			var ahead := off.dot(bearing)
			if off.length() < 15.0 or ahead < 8.0 or (Airship.ring_up and Grapple._on_airship(hit["collider"] as Node)):
				continue
			var side := (off - bearing * ahead - Vector3.UP * off.y).length()
			var score := off.y * float(plan["c_up"]) + minf(ahead, dist) * 0.5 - side * 0.6
			if score > best:
				best = score
				best_dir = dir
	if best_dir == Vector3.ZERO:
		return false
	_look(best_dir)
	body.intent.hold(&"alt_fire")
	_swing_t = 0.0
	return true


func _ride_swing(delta: float, flat: Vector3) -> void:
	var it := body.intent
	_swing_t += delta
	var slot: Dictionary = plan["swings"][mini(swings, HyperPlan.SLOTS - 1)]
	if _auto():
		slot = {"rel": plan["c_rel"], "hold": plan["c_hold"], "max": 2.5, "jump": false}
	var v := body.velocity
	var s := v.length()
	var g := body.grapple
	var bearing := flat.normalized()
	# Pump the swing toward the goal (forward on the keys, facing it).
	_look(Vector3(bearing.x, 0.0, bearing.z) if bearing != Vector3.ZERO else -body.global_basis.z)
	it.move = Vector2(0, -1)
	var sling_ready := s >= Grapple.SLING_MIN_SPEED and s >= g._peak_speed * Grapple.SLING_PEAK
	var climbing := v.y >= float(slot["rel"]) * s
	var away := Vector3(v.x, 0.0, v.z).dot(bearing) < -2.0 and _swing_t > 0.5
	if (_swing_t > float(slot.get("hold", 0.18)) and sling_ready and climbing) or _swing_t > float(slot["max"]) or away:
		it.release(&"alt_fire")
		if bool(slot["jump"]):
			it.press(&"jump")
		swings += 1


## Below the goal (off the lip, or swung low): pull up the goal's side, aiming
## at its rim, whatever the plan said.
func _rescue(flat: Vector3) -> bool:
	var bearing := flat.normalized() if flat.length() > 0.1 else -body.global_basis.z
	var direct := rad_to_deg(atan2(goal.y + 1.0 - _cam().y, maxf(flat.length(), 0.1)))
	# (Hugging a wall the near rays bite the rock at your nose: straight up the
	# face, and leaning back off it, reach the rim.)
	for pitch: float in [direct, direct + 8.0, direct + 18.0, 55.0, 70.0, 80.0, 86.0, 89.0]:
		pitch = clampf(pitch, 5.0, 88.0)
		var dir := bearing * cos(deg_to_rad(pitch)) + Vector3.UP * sin(deg_to_rad(pitch))
		var hit := _probe(dir)
		if not hit.is_empty() and (hit["position"] as Vector3).y > body.global_position.y + 4.0:
			_look(dir)
			body.intent.hold(&"fire")
			return true
		if trace and false:
			print("[hyper]   rescue pitch %.0f: %s" % [pitch, "miss" if hit.is_empty() else str((hit["position"] as Vector3) - body.global_position)])
	return false


## On the ground: sprint and chain slide-hops at the goal; brake to stop on it.
func _run(dist: float, flat: Vector3, v: Vector3) -> void:
	var it := body.intent
	var hs := Vector2(v.x, v.z).length()
	_look(flat)
	var stop_at := hs * hs / (2.0 * Player.ACCEL_GROUND) + 1.0
	if dist <= stop_at:
		return # no keys: the ground brakes you
	it.move = Vector2(0, -1)
	if dist < 8.0:
		return # walk the last few metres
	it.hold(&"sprint")
	if hops >= int(plan["hops"]) or dist < float(plan["hop_min"]) or hs < Player.WALK_SPEED * 0.95:
		return
	if not body.is_sliding():
		it.press(&"slide") # slide the moment you land...
	else:
		it.press(&"jump") # ...and hop out of it the next tick (a slide-hop)
		hops += 1


## In the air: keep your momentum, unless you're flying well off line.
func _air(flat: Vector3, v: Vector3) -> void:
	var h := Vector3(v.x, 0.0, v.z)
	if h.length() < 0.5 or flat.length() < 0.5:
		return
	var off := rad_to_deg(h.angle_to(flat))
	if off > float(plan["steer"]):
		_look(flat)
		body.intent.move = Vector2(0, -1)
		body.intent.hold(&"sprint")
