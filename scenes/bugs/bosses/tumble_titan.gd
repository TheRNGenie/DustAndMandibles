extends BossBrain
## The Tumble Titan: a scarab rolling a boulder up the wall ahead of its head.
## The boulder has its own HP: player shots hit it (it shields the Titan from
## the lip above), and splash (mortars, dynamite) near it chips it. Cracked
## through, it breaks loose and rolls back over the Titan: a big hit and a slide
## down the wall. If the Titan reaches the lip with it, the boulder rolls across
## the plateau and flattens whatever is in its way.

const BOULDER_SHARE := 0.2
## Boulder radius, in body units (scaled with the bug).
const R := 0.95
const CRUSH_SHARE := 0.3
const CRUSH_SLIDE := 7.0
const ROLL_LENGTH := 26.0
const ROLL_DAMAGE := 260.0

var _boulder: Node3D
var _mesh: MeshInstance3D
var _body: StaticBody3D
var hp := 0.0
var max_hp := 1.0
var _intact := true
var _roll := 0.0
var _last_hitter := ""
var _last_cliff := -1
var _warned := false
var _prev := Vector3.ZERO


func _attach() -> void:
	_boulder = Node3D.new()
	_boulder.name = "Boulder"
	bug.add_child(_boulder)
	_boulder.position = _rest()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BossBuilder.boulder_mesh()
	_mesh.material_override = Materials.toon(0.02)
	_mesh.scale = Vector3.ONE * local(Vector3(R, 0, 0)).x
	_boulder.add_child(_mesh)
	_body = BoulderBody.new()
	_body.brain = self
	_body.collision_layer = WorldLayout.LAYER_BUG
	_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = local(Vector3(R, 0, 0)).x
	col.shape = sh
	_body.add_child(col)
	_boulder.add_child(_body)
	max_hp = bug.health.max_hp * BOULDER_SHARE
	hp = max_hp


## Where the boulder sits: ahead of the head (up the wall), resting on the rock.
func _rest() -> Vector3:
	var clear := float(bug.spec["clearance"])
	var r := local(Vector3(R, 0, 0)).x
	return Vector3(0, r - clear, 0) + local(Vector3(0, 0, -1.35 - R))


class BoulderBody extends StaticBody3D:
	var brain: BossBrain

	func apply_hit(damage: float, _point: Vector3, _dir: Vector3, _pierce: bool = false,
			source: String = "", source_cliff: int = -1) -> void:
		if brain != null:
			brain.call("hit_boulder", damage, source, source_cliff)


## Host: a hit on the boulder.
func hit_boulder(damage: float, source: String, source_cliff: int) -> void:
	if not host() or not _intact or not bug.is_alive():
		return
	hp -= damage
	_last_hitter = source
	_last_cliff = source_cliff
	send(&"chip", [hp / max_hp])
	if hp <= 0.0:
		_crush()


func on_splash(_cliff: int, center: Vector3, radius: float, damage: float, source: String, source_cliff: int) -> void:
	if not _intact or _boulder == null:
		return
	var d := center.distance_to(_boulder.global_position)
	var r := local(Vector3(R, 0, 0)).x
	if d <= radius + r:
		hit_boulder(damage * lerpf(1.0, 0.4, clampf((d - r) / radius, 0.0, 1.0)), source, source_cliff)
	elif center.distance_to(bug.global_position) <= radius + float(bug.spec["body_radius"]):
		# A blast on the Titan itself shakes the boulder it's shouldering too.
		hit_boulder(damage * 0.5, source, source_cliff)


func _crush() -> void:
	_intact = false
	send(&"crush", [])
	bug.health.take_damage(bug.health.max_hp * CRUSH_SHARE, _last_hitter if _last_hitter != "" else "the Titan's own boulder", _last_cliff)
	if bug.is_alive() and bug.is_climbing():
		bug.climb_y = maxf(bug.climb_y - CRUSH_SLIDE, 0.0)
		bug.status.root(2.5)
	if _last_hitter != "":
		Economy.notify_cliff(bug.cliff_id, "%s cracked the boulder: it rolled right over the Tumble Titan!" % _last_hitter)


func think(_delta: float) -> bool:
	if _intact and not _warned and bug.is_climbing() and bug.climb_y > WorldLayout.CLIFF_HEIGHT * 0.7:
		_warned = true
		Economy.notify_cliff(bug.cliff_id, "The Tumble Titan's boulder is nearly over your lip! Shoot the boulder!")
	return false


## Host: over the lip with the boulder: it rolls across the plateau.
func on_crest() -> void:
	if not _intact:
		return
	_intact = false
	var start := bug.cliffs.plateau_point(bug.cliff_id, 1.0, bug.lane_z)
	var dir := -WorldLayout.inward(bug.cliff_id) # inland, away from the gap (Maps: any cliff)
	var end := start + dir * ROLL_LENGTH
	end.y = Bug.cliffs.ground_height_at(bug.cliff_id, end)
	send(&"roll", [start, end])
	var dmg := ROLL_DAMAGE * Defs.WAVE_CONFIG.damage_scale(GameState.wave)
	var hit := 0
	for n: Node in bug.get_tree().get_nodes_in_group("structures"):
		var s := n as Node3D
		if s == null or int(s.get("cliff_id")) != bug.cliff_id or not s.has_method("structure_damage"):
			continue
		var p := Geometry3D.get_closest_point_to_segment(s.global_position, start, end)
		if Vector2(p.x - s.global_position.x, p.z - s.global_position.z).length() < 2.8:
			s.call("structure_damage", dmg, "The Tumble Titan's boulder")
			hit += 1
	var home := Homestead.of(bug.cliff_id)
	if home != null:
		var p := Geometry3D.get_closest_point_to_segment(home.global_position, start, end)
		if p.distance_to(home.global_position) < 6.0:
			GameState.damage_homestead(bug.cliff_id, 120.0)
	Economy.notify_cliff(bug.cliff_id, "The Tumble Titan's boulder rolled across your plateau%s!" % (" and smashed %d things" % hit if hit > 0 else ""))


func on_event(kind: StringName, args: Array) -> void:
	match kind:
		&"chip":
			if _mesh != null:
				# A shudder, and it darkens as it cracks.
				var tw := _mesh.create_tween()
				var s := _mesh.scale
				tw.tween_property(_mesh, "scale", s * 0.95, 0.04)
				tw.tween_property(_mesh, "scale", s, 0.08)
			hp = float(args[0]) * max_hp
			if fx() != null and _boulder != null:
				fx().dust(_boulder.global_position, Vector3.UP, 0.4)
		&"crush":
			_intact = false
			hp = 0.0
			_crush_anim()
		&"roll":
			_intact = false
			_roll_anim(args[0], args[1])


## Every peer: the boulder breaks loose and rolls back down over the Titan.
func _crush_anim() -> void:
	if _boulder == null or not is_instance_valid(_boulder):
		return
	_body.queue_free()
	var start := _boulder.global_transform
	var down := bug.global_basis.z.normalized() # +Z on the wall is down the rock
	var root := bug.get_parent()
	_boulder.reparent(root)
	_boulder.global_transform = start
	var drop := start.origin
	var over := start.origin + down * local(Vector3(0, 0, 3.4)).z + bug.global_basis.y.normalized() * 0.6
	Audio.play_at(&"dynamite", start.origin, 2.0, 0.7)
	Audio.play_at(&"thunder", start.origin, 0.0, 1.3)
	if fx() != null:
		fx().shake(start.origin, 0.6)
		fx().dust(start.origin, Vector3.UP, 1.6)
	var b := _boulder
	var tw := b.create_tween()
	tw.tween_method(func(t: float) -> void:
		b.global_position = drop.lerp(over, t) + Vector3.UP * sin(t * PI) * 1.0
		b.rotate(bug.global_basis.x.normalized() if is_instance_valid(bug) else Vector3.RIGHT, 0.25), 0.0, 1.0, 0.7)
	tw.tween_callback(func() -> void:
		if fx() != null:
			fx().rocks(b.global_position, 2.2)
			fx().dust(b.global_position, Vector3.UP, 2.0)
		Audio.play_at(&"dynamite", b.global_position, 0.0, 0.6)
		b.queue_free())
	_boulder = null


## Every peer: the boulder rolls across the plateau from the lip.
func _roll_anim(start: Vector3, end: Vector3) -> void:
	if _boulder == null or not is_instance_valid(_boulder):
		return
	_body.queue_free()
	var b := _boulder
	_boulder = null
	var r := _mesh.scale.x
	b.reparent(bug.get_parent())
	var dir := (end - start).normalized()
	var axis := dir.cross(Vector3.UP).normalized()
	Audio.play_at(&"thunder", start, 2.0, 0.8)
	var tw := b.create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start.lerp(end, t)
		p.y = Bug.cliffs.ground_height_at(bug.cliff_id if is_instance_valid(bug) else 0, p) + r if Bug.cliffs != null else p.y + r
		b.global_position = p
		b.rotate(axis, -0.12)
		if fx() != null and int(t * 40.0) % 4 == 0:
			fx().dust(p - Vector3.UP * r, Vector3.UP, 0.6), 0.0, 1.0, 3.0)
	tw.tween_callback(func() -> void:
		if fx() != null:
			fx().rocks(b.global_position, 2.5)
			fx().shake(b.global_position, 0.5)
		Audio.play_at(&"dynamite", b.global_position)
		b.queue_free())


func visual(delta: float) -> void:
	age += delta
	if _boulder == null or not _intact:
		return
	# Rolls as the Titan climbs (and on the canyon floor).
	_roll += bug.global_position.distance_to(_prev) / maxf(_mesh.scale.x, 0.1)
	_prev = bug.global_position
	_boulder.position = _rest()
	_mesh.rotation = Vector3(-_roll, 0, 0)
	# Cracks show as it darkens.
	var k := clampf(hp / max_hp, 0.0, 1.0)
	_mesh.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (1.0 - k) * 0.03


func _detach() -> void:
	if _boulder != null and is_instance_valid(_boulder) and _boulder.get_parent() != bug:
		_boulder.queue_free()


func hud_status() -> String:
	if _intact:
		return "BOULDER %d%%" % int(ceil(clampf(hp / max_hp, 0.0, 1.0) * 100.0))
	return "BOULDER GONE"
