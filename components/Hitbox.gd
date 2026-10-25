class_name Hitbox
extends StaticBody3D
## A shootable collision volume that forwards hits to its owner (a bug).
## The owner implements receive_hit(damage, point, dir, pierce, multiplier, source, source_cliff).

@export var multiplier: float = 1.0
var target: Node


static func make(owner_node: Node, radius: float, offset: Vector3, mult: float = 1.0) -> Hitbox:
	var hb := Hitbox.new()
	hb.target = owner_node
	hb.multiplier = mult
	hb.collision_layer = WorldLayout.LAYER_BUG
	hb.collision_mask = 0
	hb.position = offset
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	hb.add_child(col)
	return hb


## Host only.
func apply_hit(damage: float, point: Vector3, dir: Vector3, pierce: bool = false,
		source: String = "", source_cliff: int = -1) -> void:
	if target != null and target.has_method("receive_hit"):
		target.call("receive_hit", damage, point, dir, pierce, multiplier, source, source_cliff)
