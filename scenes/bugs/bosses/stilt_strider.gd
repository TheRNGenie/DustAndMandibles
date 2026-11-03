extends BossBrain
## The Stilt Strider: a harvestman on eight stilt legs. It holds its body far out
## from the wall and steps straight over the lip without a full climb. Its legs
## can be shot (each has 7% of its health); every third broken leg drops it down
## to the canyon floor, and each drop slows it and makes it take +12% damage.
## Turrets aim at a knee half the time. Host decides hits and breaks; every peer
## draws them and keeps the leg hitboxes in place.

const Rules := preload("res://scenes/bugs/bosses/_rules_b.gd")
## A leg's share of the boss's max health.
const LEG_SHARE := 0.07
## A hit on a leg still hurts the body this much.
const LEG_BLEED := 0.5
## Every this many broken legs it falls.
const PER_DROP := 3
## It always keeps a couple of legs.
const MAX_BROKEN := 6
const DROP_VULN := 0.12
const DROP_SLOW := 0.2
## It steps over the lip from this far below it.
const STEP_UP := 7.0
const FALL_SPEED := 45.0
## How much faster it covers the last few metres.
const STRIDE := 3.0

## Host.
var _leg_hp: Array[float] = []
## Every peer.
var _broken := 0
var _drops := 0
var _falling := false
var _hit: Hitbox
var _shapes: Array[CollisionShape3D] = []


func _attach() -> void:
	var n := bug._legs.leg_count()
	for i in n:
		_leg_hp.append(bug.health.max_hp * LEG_SHARE)
	# One shootable body for every leg: an upper and a lower capsule each, laid
	# along the leg in world space every frame.
	_hit = Hitbox.new()
	_hit.name = "LegHitbox"
	_hit.target = bug
	_hit.collision_layer = WorldLayout.LAYER_BUG
	_hit.collision_mask = 0
	_hit.top_level = true
	for i in n * 2:
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = _thick()
		cap.height = 2.0
		col.shape = cap
		col.disabled = true
		_hit.add_child(col)
		_shapes.append(col)
	bug.add_child(_hit)
	_hit.global_transform = Transform3D()


func think(delta: float) -> bool:
	if _falling:
		# Down the wall in a tumble of legs.
		bug.climb_y = move_toward(bug.climb_y, 0.0, FALL_SPEED * delta)
		if bug.climb_y <= 0.0:
			_falling = false
			send(&"landed", [bug.global_position])
		return true
	match bug.state:
		Bug.State.CLIMBING:
			# Long legs: near the top it reaches over the lip and strides up
			# (the climber still runs; this adds the long steps).
			if bug.climb_y >= WorldLayout.CLIFF_HEIGHT - STEP_UP:
				bug.climb_y += bug.def.climb_speed * bug.speed() * STRIDE * delta
		Bug.State.CRESTING:
			# ...and strides over quicker than a climber hauls itself up.
			bug.crest_t = minf(bug.crest_t + delta / Bug.CREST_TIME, 1.0)
	return false


func speed_mult() -> float:
	return maxf(1.0 - DROP_SLOW * _drops, 0.5)


func body_damage(damage: float, point: Vector3, source: String, _source_cliff: int) -> float:
	var vuln := 1.0 + DROP_VULN * _drops
	var i := _leg_at(point)
	if i < 0 or _broken >= MAX_BROKEN:
		return damage * vuln
	_leg_hp[i] -= damage
	if _leg_hp[i] <= 0.0:
		_break(i, source)
	return damage * LEG_BLEED * vuln


## The unbroken leg a hit at `point` struck, or -1 (the body).
func _leg_at(point: Vector3) -> int:
	var body := bug.global_transform
	var best := -1
	var best_d := 0.75 * maxf(float(bug.spec["scale"]) * 0.4, 1.0)
	for i in bug._legs.leg_count():
		if bug._legs.is_broken(i):
			continue
		var p := bug._legs.leg_points(i, body)
		if (p[1] as Vector3) == Vector3.ZERO:
			continue
		var d := minf(Geometry3D.get_closest_point_to_segment(point, p[0], p[1]).distance_to(point),
				Geometry3D.get_closest_point_to_segment(point, p[1], p[2]).distance_to(point))
		# Shots that land right by the hip hit the body.
		if d < best_d and point.distance_to(p[0]) > 0.6:
			best_d = d
			best = i
	return best


func _break(i: int, source: String) -> void:
	_broken += 1
	var drop := _broken % PER_DROP == 0
	send(&"leg", [i, drop])
	if source != "":
		notify_defenders("%s shot a leg off the Stilt Strider!" % source)
	if drop:
		_drops += 1
		if bug.state == Bug.State.CLIMBING and bug.climb_y > 1.0:
			_falling = true


func on_event(kind: StringName, args: Array) -> void:
	match kind:
		&"leg":
			var i := int(args[0])
			var p := bug._legs.leg_points(i, bug.global_transform)
			bug._legs.break_leg(i)
			if not host():
				_broken += 1
				if bool(args[1]):
					_drops += 1
			if fx() != null:
				fx().pop(p[1], bug.def.shell_color.darkened(0.3), 1.2)
				fx().dust(p[1], Vector3.UP, 0.6)
			Audio.play_at(&"loot_crack", p[1], 2.0, 0.6)
			if bool(args[1]):
				Audio.play_at(&"spider_screech", bug.global_position, 2.0, 0.6)
				if fx() != null:
					fx().shake(bug.global_position, 0.4)
		&"landed":
			var at: Vector3 = args[0]
			if fx() != null:
				fx().rocks(at, 2.0)
				fx().shake(at, 0.6)
			Audio.play_at(&"land_dirt", at, 4.0, 0.5)
			Audio.play_at(&"hammer_hit", at, 0.0, 0.5)


## Turrets aim at a knee half the time (each turret takes turns of a few seconds).
func aim_for(from: Vector3) -> Vector3:
	if _broken >= MAX_BROKEN or not Rules.knee_turn(from, age):
		return bug.global_position
	var best := bug.global_position
	var best_d := INF
	for i in bug._legs.leg_count():
		if bug._legs.is_broken(i):
			continue
		var k: Vector3 = bug._legs.knees[i]
		if k == Vector3.ZERO:
			continue
		var d := k.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = k
	return best


func visual(delta: float) -> void:
	age += delta
	if _hit == null:
		return
	var body := bug.global_transform
	var shown := not bug.is_hidden() and bug.is_alive()
	var thick := _thick()
	for i in bug._legs.leg_count():
		var p := bug._legs.leg_points(i, body)
		var off := bug._legs.is_broken(i) or not shown or (p[1] as Vector3) == Vector3.ZERO
		for s in 2:
			var col := _shapes[i * 2 + s]
			col.disabled = off
			if off:
				continue
			var a: Vector3 = p[s]
			var b: Vector3 = p[s + 1]
			var len := a.distance_to(b)
			if len < 0.05:
				col.disabled = true
				continue
			var y := (b - a) / len
			var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
			var cap := col.shape as CapsuleShape3D
			var h := maxf(len, thick * 2.0 + 0.01)
			if absf(cap.height - h) > 0.1:
				cap.height = h
			col.global_transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)


## Leg hitbox radius: a bit fatter than the drawn stilt, so they can be hit from across.
func _thick() -> float:
	return maxf(float(bug.spec["scale"]) * 0.08, 0.35)


func hud_status() -> String:
	var n := bug._legs.leg_count()
	return "LEGS %d/%d" % [n - _broken, n] if _broken > 0 else ""
