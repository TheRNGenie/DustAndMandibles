class_name Hitbox
extends StaticBody3D
## A shootable collision volume that forwards hits to its owner (a bug).
## The owner implements receive_hit(damage, point, dir, pierce, multiplier, source, source_cliff).
## A bug's hitbox is one body with two spheres: the shell (multiplier) and the
## glowing weak spot (weak_multiplier). Which one a shot struck is read from the
## hit point (multiplier_at), so callers keep passing just the point.

@export var multiplier: float = 1.0
var target: Node
## The weak-spot sphere, in this body's local space (radius 0 = none).
var weak_center := Vector3.ZERO
var weak_radius := 0.0
var weak_multiplier := 1.0


static func make(owner_node: Node, radius: float, offset: Vector3, mult: float = 1.0) -> Hitbox:
	var hb := Hitbox.new()
	hb.target = owner_node
	hb.multiplier = mult
	hb.collision_layer = WorldLayout.LAYER_BUG
	hb.collision_mask = 0
	hb.position = offset
	hb.add_child(_sphere(radius, Vector3.ZERO))
	return hb


## One body for a whole bug: the shell sphere at `body_offset` and the weak
## spot sphere at `weak_offset` (both relative to the bug).
static func make_bug(owner_node: Node, body_radius: float, body_offset: Vector3,
		weak_r: float, weak_offset: Vector3) -> Hitbox:
	var hb := Hitbox.new()
	hb.name = "Hitbox"
	hb.target = owner_node
	hb.collision_layer = WorldLayout.LAYER_BUG
	hb.collision_mask = 0
	hb.add_child(_sphere(body_radius, body_offset))
	hb.add_child(_sphere(weak_r, weak_offset))
	hb.weak_center = weak_offset
	hb.weak_radius = weak_r
	hb.weak_multiplier = WeakSpot.MULTIPLIER
	return hb


static func _sphere(radius: float, at: Vector3) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	col.position = at
	return col


## The damage multiplier for a hit at world point `point`: the weak spot if the
## point lies on (or in) its sphere, the shell otherwise.
func multiplier_at(point: Vector3) -> float:
	if weak_radius > 0.0:
		var local := (global_transform if is_inside_tree() else transform).affine_inverse() * point
		if local.distance_to(weak_center) <= weak_radius * 1.05 + 0.02:
			return weak_multiplier
	return multiplier


## Host only.
func apply_hit(damage: float, point: Vector3, dir: Vector3, pierce: bool = false,
		source: String = "", source_cliff: int = -1) -> void:
	if target != null and target.has_method("receive_hit"):
		target.call("receive_hit", damage, point, dir, pierce, multiplier_at(point), source, source_cliff)
