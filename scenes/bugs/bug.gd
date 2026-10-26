class_name Bug
extends Node3D
## A giant bug. The host runs its brain (LaneClimber on the cliff face, Breacher on
## the plateau, Flier in the air) and owns its HP. Clients only get state + climb
## height + lane position (or ground/air position) + HP at 10 Hz and rebuild the
## transform from the shared cliff surface, so climbing bugs cost almost no bandwidth.

signal died(bug: Bug, source: String, source_cliff: int)
signal fled(bug: Bug)

enum State { CLIMBING, CRESTING, BREACHING, DEAD, BURROWED, FLYING }

const CREST_TIME := 0.8
const SMOOTHING := 10.0

static var cliffs: CliffBuilder
## Set by BugManager: called when a Brood Mother should drop her spiderlings.
static var brood_burst: Callable

var def: BugDef
var cliff_id: int = 0
var lane: int = 0
var spec: Dictionary
var health: Health
var status: BugStatus
## Debug showcase used to freeze bugs; kept for compatibility (0 = frozen).
var speed_mult: float = 1.0:
	set(v):
		speed_mult = v
		if status != null:
			status.frozen = v <= 0.0
var brood_done := false

# Replicated state.
var state: int = State.CLIMBING
var climb_y: float = 0.0
var lane_z: float = 0.0
var ground_pos: Vector3 = Vector3.ZERO
var crest_t: float = 0.0

var _climber: LaneClimber
var _breacher: Breacher
var _flier: Flier
var _legs: LegRig
var _body: MeshInstance3D
var _heading := Vector3.FORWARD
var _last_pos := Vector3.ZERO
var _placed := false


## Called by the spawn function on every peer, before the bug enters the tree.
func setup(d: BugDef, cid: int, lane_index: int, start_z: float, start_y: float, hp_mult: float,
		start_state: int = State.CLIMBING, start_pos: Vector3 = Vector3.ZERO) -> void:
	def = d
	cliff_id = cid
	lane = lane_index
	lane_z = start_z
	climb_y = start_y
	state = start_state
	ground_pos = start_pos
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
	status = BugStatus.new(self)
	_climber = LaneClimber.new(self)
	_breacher = Breacher.new(self)
	_flier = Flier.new(self)
	health.died.connect(_on_died)
	add_to_group("bugs")


func _ready() -> void:
	# Every bug announces itself when it appears, so you can hear the lane.
	var cue := &"skitter"
	match def.behavior:
		BugDef.Behavior.TANK, BugDef.Behavior.BROOD:
			cue = &"beetle_hiss"
		BugDef.Behavior.LEAPER, BugDef.Behavior.FLIER:
			cue = &"spider_screech"
	if def.group_size == 1 or name.hash() % 4 == 0:
		Audio.play_at.call_deferred(cue, target_transform().origin)
	_update_visibility()


func _make_synchronizer() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:state", ".:climb_y", ".:lane_z", ".:ground_pos", ".:crest_t", ".:cliff_id", "Health:hp"]:
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


## Burrowed bugs are underground: they can't be seen or hit.
func is_hidden() -> bool:
	return state == State.BURROWED


## Current movement multiplier (status effects).
func speed() -> float:
	return status.speed_multiplier()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if multiplayer.is_server():
		status.tick(delta)
		_think(delta)
	var target := target_transform()
	if not _placed or multiplayer.is_server():
		global_transform = target
		_placed = true
	else:
		var k := 1.0 - exp(-SMOOTHING * delta)
		if global_position.distance_to(target.origin) > 15.0:
			global_transform = target # knocked off the cliff: snap
		else:
			global_position = global_position.lerp(target.origin, k)
			global_basis = global_basis.orthonormalized().slerp(target.basis.orthonormalized(), k)
	var spd := global_position.distance_to(_last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	_update_visibility()
	if not is_hidden():
		_legs.update(delta, global_transform, spd, _project)


func _update_visibility() -> void:
	var hidden := is_hidden()
	_body.visible = not hidden
	_legs.visible = not hidden
	for c in get_children():
		if c is Hitbox:
			(c as Hitbox).collision_layer = 0 if hidden else WorldLayout.LAYER_BUG


func _think(delta: float) -> void:
	match state:
		State.CLIMBING:
			_climber.update(delta)
		State.CRESTING:
			crest_t = minf(crest_t + delta / CREST_TIME, 1.0)
			if crest_t >= 1.0:
				state = State.BREACHING
				ground_pos = _plateau_entry()
		State.BREACHING, State.BURROWED:
			_breacher.update(delta)
		State.FLYING:
			_flier.update(delta)


func begin_crest() -> void:
	state = State.CRESTING
	crest_t = 0.0
	# The boss's boulder rolls over the lip straight into the Homestead.
	if def.behavior == BugDef.Behavior.BOSS:
		GameState.damage_homestead(cliff_id, 150.0)


## Host: a Dragonfly Bandit got away with its loot.
func escaped() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	fled.emit(self)


## Host: a Water Cannon blast knocks a climber off the face. The fall hurts more the higher it was.
func knock_off(source: String, source_cliff: int) -> void:
	if state != State.CLIMBING:
		return
	var fall := climb_y
	climb_y = 0.0
	health.take_damage(fall * 2.0, source, source_cliff)


## Where the bug should be right now, from the replicated state.
func target_transform() -> Transform3D:
	var clear := float(spec["clearance"])
	match state:
		State.CLIMBING, State.DEAD:
			return _face_transform(climb_y, clear)
		State.CRESTING:
			var a := _face_transform(WorldLayout.CLIFF_HEIGHT - 0.4, clear)
			var b := _ground_transform(_plateau_entry(), -_outward(), clear)
			var t := crest_t
			var pos := a.origin.lerp(b.origin, t) + Vector3.UP * sin(t * PI) * 0.8
			return Transform3D(a.basis.slerp(b.basis, t), pos)
		State.FLYING:
			_update_heading()
			var z_axis := -_heading
			var x_axis := Vector3.UP.cross(z_axis).normalized()
			return Transform3D(Basis(x_axis, Vector3.UP, z_axis), ground_pos)
		_:
			_update_heading()
			var depth := -0.8 if state == State.BURROWED else clear
			return _ground_transform(ground_pos, _heading, depth)


func _update_heading() -> void:
	var moved := ground_pos - _last_pos
	moved.y = 0.0
	if moved.length() > 0.02:
		_heading = _heading.lerp(moved.normalized(), 0.2).normalized()


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


## Host only: a hit from a player, turret or blast, via a Hitbox.
func receive_hit(damage: float, _point: Vector3, dir: Vector3, pierce: bool, multiplier: float,
		source: String, source_cliff: int) -> void:
	if not multiplayer.is_server() or not is_alive() or is_hidden():
		return
	var dmg := damage * multiplier
	# The armour plate faces away from the cliff: shots from the canyon side bounce off it.
	if def.front_armor > 0.0 and not pierce and state == State.CLIMBING:
		if dir.normalized().dot(global_basis.y) < -0.3:
			dmg *= 1.0 - def.front_armor
	health.take_damage(dmg, source, source_cliff)
	_check_brood()


func _check_brood() -> void:
	# The Iron Tumble drops off at half health and re-climbs the other cliff.
	if def.behavior == BugDef.Behavior.BOSS and not brood_done and health.fraction() <= 0.5 and state == State.CLIMBING:
		brood_done = true
		cliff_id = WorldLayout.other_cliff(cliff_id)
		climb_y = 0.0
		if brood_burst.is_valid():
			brood_burst.call(self)
		return
	if def.behavior == BugDef.Behavior.BROOD and not brood_done and health.fraction() <= 0.5:
		brood_done = true
		if brood_burst.is_valid():
			brood_burst.call(self)


func _on_died(source: String, source_cliff: int) -> void:
	if def.behavior == BugDef.Behavior.BROOD and not brood_done:
		brood_done = true
		if brood_burst.is_valid():
			brood_burst.call(self)
	state = State.DEAD
	died.emit(self, source, source_cliff)
