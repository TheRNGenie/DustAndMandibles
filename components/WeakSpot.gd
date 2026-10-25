class_name WeakSpot
extends RefCounted
## The glowing weak spot every bug has: a Hitbox that takes double damage.

const MULTIPLIER := 2.0


static func make(owner_node: Node, radius: float, offset: Vector3) -> Hitbox:
	var hb := Hitbox.make(owner_node, radius, offset, MULTIPLIER)
	hb.name = "WeakSpot"
	return hb
