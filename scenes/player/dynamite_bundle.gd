class_name DynamiteBundle
extends Node3D
## A lit bundle of dynamite in flight (every peer makes its own from the host's
## launch). It flies the same lob on every screen (DynamiteRules.arc_point from
## one origin and velocity), tumbling end over end with its fuse spitting, and
## stops where it first meets rock, a structure or a bug (riding along on a bug
## it lands on). The host's copy decides when it goes up: a moment after it
## lands, or when the fuse runs out; the others wait for the host's blast.

signal went_off(bundle: DynamiteBundle, pos: Vector3, normal: Vector3)

var id := 0
var origin := Vector3.ZERO
var vel := Vector3.ZERO
## The host's copy: it decides when to go up.
var authoritative := false
## Players' bodies are left out of its flight (no bouncing it off your partner).
var skip: Array[RID] = []
var _t := 0.0
var _landed := false
var _settle := 0.0
var _normal := Vector3.UP
var _rider: Node3D
var _ride_off := Vector3.ZERO
var _spin := Vector3.ZERO
var _done := false
var _model: Node3D
var _fuse: FuseFx
static var _mesh: ArrayMesh


func _ready() -> void:
	top_level = true
	if _mesh == null:
		_mesh = WeaponBuilder.dynamite_bundle()
	_model = Node3D.new()
	_model.scale = Vector3.ONE * 1.5 # a little bigger than in the hand, so it reads in the air
	add_child(_model)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = Materials.toon(0.012)
	_model.add_child(mi)
	_fuse = FuseFx.new()
	_fuse.position = WeaponBuilder.DYNAMITE_FUSE_TIP
	_model.add_child(_fuse)
	_fuse.lit = true
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + 13
	_spin = Vector3(rng.randf_range(5.0, 9.0), rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0))
	global_position = origin


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if not _landed:
		var from := global_position
		var to := DynamiteRules.arc_point(origin, vel, _t)
		var q := PhysicsRayQueryParameters3D.create(from, to,
				WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE | WorldLayout.LAYER_BUG, skip)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			global_position = to
			_model.rotation += _spin * delta
		else:
			_land(hit)
	else:
		_settle += delta
		if _rider != null and is_instance_valid(_rider):
			global_position = _rider.global_position + _ride_off
	if authoritative and ((_landed and _settle >= DynamiteRules.SETTLE_FUSE) or _t >= DynamiteRules.MAX_FUSE):
		go_off()
	elif _t > DynamiteRules.MAX_FUSE + 3.0:
		queue_free() # a client whose blast message never came


func _land(hit: Dictionary) -> void:
	_landed = true
	_normal = hit["normal"]
	global_position = (hit["position"] as Vector3) + _normal * 0.08
	var col := hit["collider"] as Object
	if col is Hitbox and (col as Hitbox).target is Node3D:
		_rider = (col as Hitbox).target as Node3D
		_ride_off = global_position - _rider.global_position
	# Settle on its side, the fuse still spitting.
	_model.basis = MeshKit.basis_from_y(_normal.cross(Vector3.RIGHT if absf(_normal.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized())
	Audio.play_at(&"hit_tick", global_position, -4.0, 0.6)


func is_landed() -> bool:
	return _landed


## The host: it goes up here (DynamiteRules damage, noise, the blast on every peer).
func go_off() -> void:
	if _done:
		return
	_done = true
	went_off.emit(self, global_position, _normal if _landed else Vector3.UP)


## Every peer: the blast's here, the bundle's gone.
func remove() -> void:
	_done = true
	queue_free()
