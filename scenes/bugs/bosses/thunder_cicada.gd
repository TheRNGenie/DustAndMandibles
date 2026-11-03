extends BossBrain
## The Thunder Cicada. Every ~20 s it stops and drums its tymbals: a ring glows
## for 3 s round the densest cluster of turrets on the far cliff, then the
## screech stuns every turret inside it (8 m) for 4 s. It doesn't climb while it
## drums. The counter: spread turrets out so one ring can't catch them all, and
## pour fire in while it sits still drumming.

const Rules := preload("res://scenes/bugs/bosses/_rules_b.gd")
const EVERY := 20.0
const FIRST := 8.0
const TELEGRAPH := 3.0
const RADIUS := 8.0
const STUN := 4.0
const REACH := 140.0
const AMBER := Color("#FFD23F")

## Host.
var _cd := FIRST
var _drum := 0.0
var _center := Vector3.ZERO
## Every peer.
var _drum_left := 0.0
var _tick := 0.0
var _glows: Array[MeshInstance3D] = []


func _attach() -> void:
	for p: Vector3 in bug.spec.get("tymbals", []):
		var g := BossFx.glow_blob(0.32, AMBER)
		bug.add_child(g)
		g.position = local(p)
		BossFx.set_glow(g, 0.0)
		_glows.append(g)


func think(delta: float) -> bool:
	if not bug.is_alive():
		return false
	if _drum > 0.0:
		_drum -= delta
		if _drum <= 0.0:
			_screech()
		return true # sits still while it drums
	if not (bug.state in [Bug.State.CLIMBING, Bug.State.CRESTING, Bug.State.BREACHING]):
		return false
	_cd -= delta
	if _cd <= 0.0:
		var pts: Array[Vector3] = []
		for t in far_turrets(REACH):
			pts.append(t.global_position)
		if pts.is_empty():
			_cd = 3.0
			return false
		_cd = EVERY
		_center = Rules.densest(pts, RADIUS)
		_drum = TELEGRAPH
		send(&"drum", [_center])
		return true
	return false


func _screech() -> void:
	var n := 0
	for t in far_turrets(REACH + RADIUS):
		if t.global_position.distance_to(_center) <= RADIUS and fx() != null:
			fx().stun(t, STUN)
			n += 1
	send(&"screech", [_center])
	if n > 0:
		notify_defenders("The Thunder Cicada's screech stunned %d turret%s!" % [n, "" if n == 1 else "s"])


func on_event(kind: StringName, args: Array) -> void:
	var at: Vector3 = args[0]
	match kind:
		&"drum":
			_drum_left = TELEGRAPH
			_tick = 0.0
			if fx() != null:
				fx().ground_ring(at, RADIUS, AMBER, TELEGRAPH)
			Audio.play_at(&"thunder", bug.global_position, -8.0, 1.6)
			Audio.play_at(&"bell", at, -4.0, 0.7)
		&"screech":
			_drum_left = 0.0
			var head := world(Vector3(0, 0.3, -0.8))
			if fx() != null:
				fx().shockwave(head, at + Vector3.UP * 1.0, RADIUS, AMBER)
				fx().shake(at, 0.5)
			Audio.play_at(&"thunder", at, 4.0, 1.3)
			Audio.play_at(&"spider_screech", head, 4.0, 0.7)


func visual(delta: float) -> void:
	age += delta
	if _drum_left > 0.0:
		_drum_left -= delta
		# The drumming speeds up toward the screech.
		_tick -= delta
		if _tick <= 0.0:
			var k := 1.0 - _drum_left / TELEGRAPH
			_tick = lerpf(0.28, 0.08, k)
			Audio.play_at(&"hammer_hit", bug.global_position, -6.0 + 4.0 * k, 0.45 + 0.3 * k)
	var k2 := 0.0
	if _drum_left > 0.0:
		k2 = 0.55 + 0.45 * sin(age * lerpf(18.0, 50.0, 1.0 - _drum_left / TELEGRAPH))
	for i in _glows.size():
		var p: Vector3 = (bug.spec.get("tymbals", []) as Array)[i]
		_glows[i].position = local(p)
		BossFx.set_glow(_glows[i], k2)


func hud_status() -> String:
	return "DRUMMING" if _drum_left > 0.0 else ""
