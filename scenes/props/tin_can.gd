class_name TinCan
extends RigidBody3D
## Target-practice can. Shooting it knocks it flying (impulse comes from the weapon).

static var _mesh: ArrayMesh


func _ready() -> void:
	if _mesh == null:
		_mesh = PropBuilder.tin_can()
	mass = 0.2
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = Materials.toon(0.006)
	add_child(mi)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.06
	shape.height = 0.16
	col.shape = shape
	add_child(col)


func apply_hit(_damage: float, _point: Vector3, dir: Vector3) -> void:
	apply_central_impulse((dir + Vector3.UP * 0.6) * 0.6)
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02)
