extends BossBrain
## The Burrowing Beetle: crosses the canyon floor, digs in at the foot of its
## cliff and tunnels up under the plateau (a trail of dust puffs shows where),
## making for the busiest scaffold tower. There it stops: cracks spread over the
## ground for 3 s, then it bursts up, bringing down the top level of every
## scaffold nearby (the turret on top is wrecked, the rest shaken). It fights on
## the surface for a while (the only time it can be hurt), then digs down and
## goes for another tower. Lantern light flushes it up early, before it gets
## where it was going, and wrecks nothing.

const RADIUS := 4.5
const WARN := 3.0
const UP_TIME := 11.0
const TUNNEL_TIME := 4.0

var _phase := &"cross"
var _t := 0.0
var _goal := Vector3.ZERO
var _last_goal := Vector3(INF, INF, INF)
var _wreck := true
var _puff := 0.0
var _prev := Vector3.ZERO


func think(delta: float) -> bool:
	match _phase:
		&"cross":
			if bug.state == Bug.State.CROSSING:
				return false
			# At the foot of the wall (or started on it): dig in.
			_dig(bug.global_position)
			_phase = &"tunnel"
			_t = TUNNEL_TIME
		&"tunnel":
			_t -= delta
			if _t <= 0.0:
				_seek()
		&"seek":
			if _lit():
				_wreck = false
				_surface_warning()
				return true
			var to := _goal - bug.ground_pos
			to.y = 0.0
			var step := bug.def.walk_speed * 1.4 * bug.speed() * delta
			if to.length() <= step + 0.5:
				_surface_warning()
			else:
				bug.ground_pos += to.normalized() * step
				bug.ground_pos.y = Bug.cliffs.ground_height_at(bug.cliff_id, bug.ground_pos)
		&"warn":
			_t -= delta
			if _t <= 0.0:
				_erupt()
		&"up":
			_t -= delta
			bug._breacher.update(delta)
			if _t <= 0.0 and bug.state == Bug.State.BREACHING:
				_dig(bug.global_position)
				_seek()
	return true


func _dig(at: Vector3) -> void:
	bug.state = Bug.State.BURROWED
	send(&"dig", [at])
	if _phase == &"cross":
		bug.ground_pos = Bug.cliffs.plateau_point(bug.cliff_id, 2.5, bug.lane_z)


## Picks the scaffold tower (or turret cluster) it will come up under.
func _seek() -> void:
	_phase = &"seek"
	_wreck = true
	_goal = _pick_goal()
	_last_goal = _goal


func _pick_goal() -> Vector3:
	var spots: Array[Vector3] = []
	var bm := BuildManager.instance
	if bm != null:
		for n in bm.find_children("*", "", true, false):
			var sc := n as ScaffoldNode
			if sc != null and sc.cliff_id == bug.cliff_id and not sc.is_queued_for_deletion():
				spots.append(sc.global_position)
	if spots.is_empty():
		for n: Node in bug.get_tree().get_nodes_in_group("turrets"):
			var t := n as Turret
			if t.cliff_id == bug.cliff_id:
				spots.append(t.global_position)
	if spots.is_empty():
		var home := Homestead.of(bug.cliff_id)
		return home.global_position if home != null else bug.ground_pos
	var best := spots[0]
	var best_score := -INF
	for p in spots:
		var score := 0.0
		for n: Node in bug.get_tree().get_nodes_in_group("turrets"):
			var t := n as Turret
			if t.cliff_id == bug.cliff_id and t.global_position.distance_to(p) < RADIUS:
				score += 1.0 + t.level
		# Never the same spot twice in a row; nearer is a little better.
		if p.distance_to(_last_goal) < 3.0:
			score -= 100.0
		score -= p.distance_to(bug.ground_pos) * 0.02
		if score > best_score:
			best_score = score
			best = p
	return best


func _lit() -> bool:
	for l: Node in bug.get_tree().get_nodes_in_group("lanterns"):
		var n := l as Node3D
		if n.global_position.distance_to(bug.ground_pos) < float(n.call("reveal_radius")):
			return true
	return false


func _surface_warning() -> void:
	_phase = &"warn"
	_t = WARN
	var at := bug.ground_pos
	at.y = Bug.cliffs.ground_height_at(bug.cliff_id, at)
	send(&"cracks", [at, RADIUS if _wreck else 2.0, WARN])
	Economy.notify_cliff(bug.cliff_id, "The ground's cracking near your %s! The Burrowing Beetle is coming up!" % ("scaffolds" if _wreck else "lantern"))


func _erupt() -> void:
	_phase = &"up"
	_t = UP_TIME
	bug.state = Bug.State.BREACHING
	var at := bug.ground_pos
	send(&"erupt", [at, _wreck])
	if _wreck:
		_collapse(at)


## Host: the ground gives way: scaffolds near lose their top level.
func _collapse(at: Vector3) -> void:
	var bm := BuildManager.instance
	if bm == null:
		return
	var dmg := Defs.WAVE_CONFIG.damage_scale(GameState.wave)
	var wrecked := 0
	var shaken: Array[Turret] = []
	for n in bm.find_children("*", "", true, false):
		var sc := n as ScaffoldNode
		if sc == null or sc.cliff_id != bug.cliff_id or sc.is_queued_for_deletion():
			continue
		if Vector2(sc.global_position.x - at.x, sc.global_position.z - at.z).length() > RADIUS:
			continue
		var top := sc.levels
		var t := bm.turret_at(sc.cliff_id, sc.cell, top)
		if t != null:
			bm.on_structure_destroyed(t)
		for other in bm.turrets_on(sc.cliff_id, sc.cell):
			if other != t:
				shaken.append(other)
		if top <= 1:
			sc.queue_free()
		else:
			sc.set_levels(top - 1)
		wrecked += 1
	for n: Node in bug.get_tree().get_nodes_in_group("structures"):
		var s := n as Node3D
		if s == null or int(s.get("cliff_id")) != bug.cliff_id or not s.has_method("structure_damage") or s is Homestead:
			continue
		if s.global_position.distance_to(at) < RADIUS or shaken.has(s):
			s.call("structure_damage", 35.0 * dmg, "The Burrowing Beetle")
	if wrecked > 0:
		Economy.notify_cliff(bug.cliff_id, "The Burrowing Beetle brought down %d scaffold level%s!" % [wrecked, "" if wrecked == 1 else "s"])


func on_event(kind: StringName, args: Array) -> void:
	var f := fx()
	if f == null:
		return
	match kind:
		&"dig":
			var at: Vector3 = args[0]
			f.dust(at, Vector3.UP, 2.2)
			f.rocks(at, 1.6)
			Audio.play_at(&"plant_dig", at, 4.0, 0.6)
			Audio.play_at(&"thunder", at, -2.0, 1.4)
		&"cracks":
			var at: Vector3 = args[0]
			f.cracks(at, float(args[1]), float(args[2]))
			f.ground_ring(at, float(args[1]), Color("#FF9A3C"), float(args[2]))
			Audio.play_at(&"thunder", at, 4.0, 0.6)
			f.shake(at, 0.25)
			_rumble_puffs(at, float(args[2]))
		&"erupt":
			var at: Vector3 = args[0]
			f.dust(at, Vector3.UP, 3.0)
			f.rocks(at + Vector3.UP * 0.5, 3.0)
			f.shake(at, 0.9)
			Audio.play_at(&"dynamite", at, 4.0, 0.7)
			Audio.play_at(&"beetle_hiss", at, 6.0, 0.6)


## Dust spurting from the cracks while they spread.
func _rumble_puffs(at: Vector3, seconds: float) -> void:
	var tree := bug.get_tree()
	for k in int(seconds / 0.5):
		tree.create_timer(0.3 + k * 0.5).timeout.connect(func() -> void:
			if fx() != null:
				fx().dust(at + Vector3(randf_range(-2, 2), 0.2, randf_range(-2, 2)), Vector3.UP, 0.8))


func visual(delta: float) -> void:
	age += delta
	# Underground under the plateau: a trail of dust puffs and a low rumble.
	if bug.state != Bug.State.BURROWED or fx() == null:
		return
	_puff -= delta
	var moved := bug.ground_pos.distance_to(_prev)
	if _puff > 0.0 or moved < 0.2:
		return
	_prev = bug.ground_pos
	_puff = 0.45
	var p := bug.ground_pos
	if Bug.cliffs != null:
		p.y = Bug.cliffs.ground_height_at(bug.cliff_id, p)
	fx().dust(p, Vector3.UP, 0.9)
	if int(age * 2.0) % 3 == 0:
		Audio.play_at(&"thunder", p, -10.0, 1.6)


func hud_status() -> String:
	return "UNDERGROUND" if bug.state == Bug.State.BURROWED else "SURFACED"
