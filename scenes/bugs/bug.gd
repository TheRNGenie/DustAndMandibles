class_name Bug
extends Node3D
## A giant bug. The host runs its brain (LaneClimber on the cliff face, Breacher on
## the plateau) and owns its HP. Clients only get state + climb height + lane
## position + HP at 10 Hz and rebuild the transform from the shared cliff surface,
## so climbing bugs cost almost no bandwidth.

signal died(bug: Bug, source: String, source_cliff: int)

enum State { CLIMBING, CRESTING, BREACHING, DEAD }

const CREST_TIME := 0.8
const SMOOTHING := 10.0

static var cliffs: CliffBuilder

var def: BugDef
var cliff_id: int = 0
var lane: int = 0
var spec: Dictionary
var health: Health
var speed_mult: float = 1.0

# Replicated state.
var state: int = State.CLIMBING
var climb_y: float = 0.0
var lane_z: float = 0.0
var ground_pos: Vector3 = Vector3.ZERO
var crest_t: float = 0.0

var _climber: LaneClimber
var _breacher: Breacher
var _legs: LegRig
var _body: MeshInstance3D
var _heading := Vector3.FORWARD
var _last_pos := Vector3.ZERO
var _placed := false


## Called by the spawn function on every peer, before the bug enters the tree.
func setup(d: BugDef, cid: int, lane_index: int, start_z: float, start_y: float, hp_mult: float) -> void:
	def = d
	cliff_id = cid
	lane = lane_index
	lane_z = start_z
	climb_y = start_y
	spec = BugBuilder.build(d)
	health = Health.new()
	health.name = "Health"
	health.setup(d.max_hp * hp_mult)
	add_child(health)
	_body = MeshInstance3D.new()
	_body.mesh = spec["body"]
	_body.material_override = Materials.toon_unique(0.03)
	_body.scale = Vector3.ONE * float(spec["scale"])
	add_child(_body)
	_legs = LegRig.new()
	_legs.setup(spec)
	add_child(_legs)
	add_child(Hitbox.make(self, float(spec["body_radius"]), Vector3(0, float(spec["clearance"]) * 0.3, 0)))
	add_child(WeakSpot.make(self, float(spec["weak_radius"]), spec["weak_spot"]))
	add_child(_make_synchronizer())
	_climber = LaneClimber.new(self)
	_breacher = Breacher.new(self)
	health.died.connect(_on_died)
	add_to_group("bugs")


func _ready() -> void:
	# Every bug announces itself when it starts climbing, so you can hear the lane.
	var cue := &"skitter"
	match def.behavior:
		BugDef.Behavior.TANK:
			cue = &"beetle_hiss"
		BugDef.Behavior.LEAPER:
			cue = &"spider_screech"
	if def.group_size == 1 or name.hash() % 4 == 0:
		Audio.play_at.call_deferred(cue, target_transform().origin)


func _make_synchronizer() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:state", ".:climb_y", ".:lane_z", ".:ground_pos", ".:crest_t", "Health:hp"]:
		var path := NodePath(p)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 0.1
	return sync


func is_climbing() -> bool:
	return state == State.CLIMBING


func is_alive() -> bool:
	return state != State.DEAD and not health.dead


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if multiplayer.is_server():
		_think(delta)
	var target := target_transform()
	if not _placed or multiplayer.is_server():
		global_transform = target
		_placed = true
	else:
		var k := 1.0 - exp(-SMOOTHING * delta)
		global_position = global_position.lerp(target.origin, k)
		global_basis = global_basis.orthonormalized().slerp(target.basis.orthonormalized(), k)
	var speed := global_position.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	_legs.update(delta, global_transform, speed, _project)


func _think(delta: float) -> void:
	match state:
		State.CLIMBING:
			_climber.update(delta)
		State.CRESTING:
			crest_t = minf(crest_t + delta / CREST_TIME, 1.0)
			if crest_t >= 1.0:
				state = State.BREACHING
				ground_pos = _plateau_entry()
		State.BREACHING:
			_breacher.update(delta)


func begin_crest() -> void:
	state = State.CRESTING
	crest_t = 0.0


## Where the bug should be right now, from the replicated state.
func target_transform() -> Transform3D:
	var clear := float(spec["clearance"])
	match state:
		State.CLIMBING, State.DEAD:
			return _face_transform(climb_y, clear)
		State.CRESTING:
			var a := _face_transform(WorldLayout.CLIFF_HEIGHT - 0.4, clear)
			var entry := _plateau_entry()
			var b := _ground_transform(entry, -_outward(), clear)
			var t := crest_t
			var pos := a.origin.lerp(b.origin, t) + Vector3.UP * sin(t * PI) * 0.8
			return Transform3D(a.basis.slerp(b.basis, t), pos)
		_:
			var moved := ground_pos - _last_pos
			moved.y = 0.0
			if moved.length() > 0.02:
				_heading = _heading.lerp(moved.normalized(), 0.2).normalized()
			return _ground_transform(ground_pos, _heading, clear)


func _face_transform(y: float, clear: float) -> Transform3D:
	var n := cliffs.face_normal(cliff_id, y, lane_z)
	var p := cliffs.face_point(cliff_id, y, lane_z)
	var up_face := (cliffs.face_point(cliff_id, y + 0.5, lane_z) - cliffs.face_point(cliff_id, y - 0.5, lane_z)).normalized()
	var z_axis := -(up_face - n * up_face.dot(n)).normalized()
	var x_axis := n.cross(z_axis).normalized()
	return Transform3D(Basis(x_axis, n, z_axis), p + n * clear)


func _ground_transform(pos: Vector3, heading: Vector3, clear: float) -> Transform3D:
	var h := heading
	h.y = 0.0
	if h.length() < 0.01:
		h = -_outward()
	var z_axis := -h.normalized()
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	var ground := Vector3(pos.x, cliffs.ground_height_at(cliff_id, pos) + clear, pos.z)
	return Transform3D(Basis(x_axis, Vector3.UP, z_axis), ground)


func _plateau_entry() -> Vector3:
	return cliffs.plateau_point(cliff_id, 1.5, lane_z)


## Direction from the cliff into the canyon.
func _outward() -> Vector3:
	return Vector3(-WorldLayout.side_sign(cliff_id), 0.0, 0.0)


## Projects a point onto the surface under the bug (for foot placement).
func _project(point: Vector3, up: Vector3) -> Vector3:
	if state == State.BREACHING:
		return Vector3(point.x, cliffs.ground_height_at(cliff_id, point), point.z)
	var base := global_position - up * float(spec["clearance"])
	return point - up * (point - base).dot(up)


## Host only: a hit from a player or turret, via a Hitbox.
func receive_hit(damage: float, _point: Vector3, dir: Vector3, pierce: bool, multiplier: float,
		source: String, source_cliff: int) -> void:
	if not multiplayer.is_server() or not is_alive():
		return
	var dmg := damage * multiplier
	# The armour plate faces away from the cliff: shots from the canyon side bounce off it.
	if def.front_armor > 0.0 and not pierce and state == State.CLIMBING:
		if dir.normalized().dot(global_basis.y) < -0.3:
			dmg *= 1.0 - def.front_armor
	health.take_damage(dmg, source, source_cliff)


func _on_died(source: String, source_cliff: int) -> void:
	state = State.DEAD
	died.emit(self, source, source_cliff)
