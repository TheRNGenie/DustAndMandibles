class_name Bug
extends Node3D
## A giant bug. The host runs its brain (LaneClimber on the cliff face, Breacher on
## the plateau, Flier in the air) and owns its HP. Clients only get state + climb
## height + lane position (or ground/air position) + HP at 10 Hz (BugManager packs
## every bug into a few packets) and rebuild the transform from the shared cliff
## surface, so climbing bugs cost almost no bandwidth.
## Cheap to have hundreds of: the body, legs and wings are slots in shared
## MultiMeshes (LegBatch), the face is only worn by the nearest few (BugFace
## pool), and one Hitbox body holds both the shell and weak-spot spheres.

signal died(bug: Bug, source: String, source_cliff: int)
signal fled(bug: Bug)

enum State { CLIMBING, CRESTING, BREACHING, DEAD, BURROWED, FLYING, CROSSING, SLEEPING, HUNTING }

const CREST_TIME := 0.8
const KillMethod := preload("res://scenes/bugs/kill_method.gd")

static var cliffs: CliffBuilder
## This peer runs the bugs' brains (set each tick by BugManager: cheaper than
## asking the multiplayer API from every bug).
static var host := true
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
## Host: loot a breaching thief grabbed from its cliff's stockpile (dropped if it's killed).
var stolen: Dictionary = {}
## 1 in 100 bugs spawn smoking a cigarette and move twice as fast.
var smoker := false
## Crowd disc radius and weight (BugCrowd), worked out once.
var crowd_r := 0.0
var crowd_w := 1.0
## Network id (BugManager's batched state sync finds bugs by it).
var net_id := 0
## Canyon Expeditions (host): the player this floor hunter is after (peer id),
## -1 once it's been called home, 0 for every other bug (see FloorHunt).
var hunt_peer := 0
## Where a hunter goes back into the ground (its tunnel mouth).
var hunt_home := Vector3.ZERO
## A bug out on the canyon floor in the build phase (hunters, and the floor
## sites' sleepers): turrets may shoot it within their pitch and range.
var floor_bug := false:
	set(v):
		floor_bug = v
		if v and not floor_bugs.has(self):
			floor_bugs.append(self)
		elif not v:
			floor_bugs.erase(self)
## Every floor_bug alive (host; turrets look here instead of at every bug).
static var floor_bugs: Array[Bug] = []
## Canyon Expeditions: the raid site this bug sleeps at (-1: a wave bug).
var site := -1
## Host brain while it sleeps or hunts on the floor (site bugs only).
var hunter: FloorHunter
var _zzz: Label3D
var _sleep_k := 0.0
var _face: BugFace
## Bosses: the mechanic (scenes/bugs/bosses/<id>.gd), on every peer. Null for other bugs.
var boss: BossBrain
## Boss growth (the Bone Collector swells as it feeds): scales the drawn body.
var grow := 1.0
## Bosses drawn on their own (not in the shared MultiMesh), e.g. the Mirage
## Mantis whose shimmer needs its own material.
var _solo: MeshInstance3D

# Replicated state.
var state: int = State.CLIMBING
var climb_y: float = 0.0
var lane_z: float = 0.0
## Ducked flat to let a much bigger bug crawl over (0..1), and how high this bug
## is riding up over a smaller one (m). Set by BugManager.separate().
var crouch := 0.0
var ride := 0.0
var ground_pos: Vector3 = Vector3.ZERO
var crest_t: float = 0.0

var _climber: LaneClimber
var _breacher: Breacher
var _flier: Flier
var _legs: LegRig
var _hitbox: Hitbox
## The body's slot in its kind's MultiMesh, and its animated local transform.
var _body_b: LegBatch
var _body_slot := -1
var _body_local := Transform3D()
## Fliers' four wings (slots in the shared wing MultiMesh).
var _wing_b: LegBatch
var _wing_slots: Array[int] = []
static var _wing_mesh: ArrayMesh
static var _wing_mat: ShaderMaterial
var _heading := Vector3.FORWARD
var _last_pos := Vector3.ZERO
## Metres per second at the last update (velocity_hint).
var _vel := Vector3.ZERO
var _placed := false
## spec["clearance"] / spec["scale"] and the detail-check radius, read once (hot paths).
var _clear := 0.0
var _scale := 1.0
var _lod_r := 1.0


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
	_clear = float(spec["clearance"])
	_scale = float(spec["scale"])
	_lod_r = float(spec["body_radius"]) + float(spec["upper"]) + float(spec["lower"])
	health = Health.new()
	health.name = "Health"
	health.setup(d.max_hp * hp_mult)
	add_child(health)
	_body_local = Transform3D(Basis.from_scale(Vector3.ONE * float(spec["scale"])), Vector3.ZERO)
	_legs = LegRig.new()
	_legs.name = "Legs"
	_legs.setup(spec)
	_legs.set_clearance(float(spec["clearance"]))
	crowd_r = float(spec["body_radius"]) * 0.85
	crowd_w = BugCrowd.weight(d.size, d.behavior == BugDef.Behavior.BOSS)
	add_child(_legs)
	health.changed.connect(_on_hp_changed)
	_hitbox = Hitbox.make_bug(self, float(spec["body_radius"]), Vector3(0, float(spec.get("hit_lift", float(spec["clearance"]) * 0.3)), 0),
			float(spec["weak_radius"]), spec["weak_spot"])
	add_child(_hitbox)
	status = BugStatus.new(self)
	_climber = LaneClimber.new(self)
	_breacher = Breacher.new(self)
	_flier = Flier.new(self)
	health.died.connect(_on_died)
	add_to_group("bugs")
	if d.behavior == BugDef.Behavior.BOSS:
		boss = BossBrain.make(self)
	if start_state == State.SLEEPING or start_state == State.HUNTING:
		hunter = FloorHunter.new(self)
		_sleep_k = 1.0 if start_state == State.SLEEPING else 0.0


func _ready() -> void:
	# Every bug announces itself when it appears, so you can hear the lane.
	var cue := &"skitter"
	match def.behavior:
		BugDef.Behavior.TANK, BugDef.Behavior.BROOD, BugDef.Behavior.BOSS:
			cue = &"beetle_hiss"
		BugDef.Behavior.LEAPER:
			cue = &"spider_screech"
		BugDef.Behavior.FLIER:
			cue = &"wing_buzz"
	if def.group_size == 1 or name.hash() % 4 == 0:
		Audio.play_at.call_deferred(cue, target_transform().origin)
	if bool(spec.get("solo", false)):
		_solo = MeshInstance3D.new()
		_solo.name = "Body"
		_solo.mesh = spec["body"]
		add_child(_solo)
	if boss != null:
		boss.attach()
	_update_visibility()


func _enter_tree() -> void:
	if _body_slot >= 0 or not _wing_slots.is_empty():
		return
	var root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	# Bodies of a kind share one mesh, so they draw as one MultiMesh (with shadows).
	if not bool(spec.get("solo", false)):
		# Painted chitin (assets/skins); the Hive Queen and Hive Mother wear their own.
		var skin: int = {&"hive_queen": 1, &"hive_mother": 2}.get(def.id, 0)
		var body_mat := Materials.toon_glide(0.03) if skin == 0 else Materials.toon_glide_skin(0.03, skin)
		_body_b = LegBatch.of(spec["body"], body_mat, root, true)
		_body_slot = _body_b.take()
	if bool((spec.get("face", {}) as Dictionary).get("wings", false)):
		_wing_b = LegBatch.of(_wings_mesh(), _wing_mat, root)
		for i in 4:
			_wing_slots.append(_wing_b.take())


func _exit_tree() -> void:
	floor_bugs.erase(self)
	if _body_slot >= 0:
		_body_b.give_back(_body_slot)
		_body_slot = -1
	for s: int in _wing_slots:
		_wing_b.give_back(s)
	_wing_slots.clear()
	if boss != null:
		boss.detach()
	# A bug that died hands its face back; the world closing just frees them.
	if is_queued_for_deletion():
		set_face(false)


## Where the body is drawn this frame (its MultiMesh slot, plus the glide
## offset the shader adds); debug/measuring only.
func drawn_position() -> Vector3:
	if not is_inside_tree():
		return Vector3.ZERO
	if _body_slot < 0:
		return global_position
	var o := _body_b.mm.get_instance_transform(_body_slot).origin
	if _body_b.mm.use_custom_data:
		o += LegBatch.glide_offset(_body_b.mm.get_instance_custom_data(_body_slot))
	return o


## Wears a face (pupils, brows, mandibles...) or hands it back to the pool.
## BugManager gives faces to the nearest few bugs only.
func set_face(on: bool) -> void:
	if on == (_face != null):
		return
	if on:
		_face = BugFace.acquire(self)
		add_child(_face)
		_face.visible = not is_hidden()
		_place_face()
	else:
		BugFace.release(_face)
		_face = null


func has_face() -> bool:
	return _face != null


func _on_hp_changed(_hp: float, _mx: float) -> void:
	if _face != null:
		_face.wince()


func _place_face() -> void:
	var s := float(spec["scale"])
	_face.transform = _body_local.scaled_local(Vector3.ONE / s) if s > 0.0 else Transform3D()
	_face_at = _face.position
	glide_face()


## The face is a node of the bug, not a batch slot: it follows the body's
## glide here, every frame (BugManager, only for the few bugs wearing one).
var _face_at := Vector3.ZERO


func glide_face() -> void:
	if _face == null or not is_inside_tree():
		return
	var off := LegBatch.glide_offset(_glide)
	_face.position = _face_at + (global_basis.inverse() * off if off != Vector3.ZERO else Vector3.ZERO)


## Writes the body (and wings) into their MultiMesh slots at the bug's transform.
func _write_body() -> void:
	if _solo != null:
		_solo.transform = _body_local
	elif _body_slot < 0:
		return
	var g := global_transform
	if _body_slot >= 0:
		_body_b.put(_body_slot, g * _body_local)
	if _wing_slots.is_empty():
		return
	var s := _scale * grow
	var face := g * (_body_local.scaled_local(Vector3.ONE / s) if s > 0.0 else Transform3D())
	var k := 0
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.25, 0.1]:
			var flap := side * sin(_anim_t * 55.0 + (0.0 if z < 0.0 else 1.4)) * 0.55
			var pivot := Transform3D(Basis(Vector3.BACK, flap), Vector3(side * 0.08, 0.12, z) * s)
			_wing_b.put(_wing_slots[k], face * pivot * Transform3D(Basis.from_scale(Vector3(side, 1.0, 1.0) * s), Vector3.ZERO))
			k += 1


## Four see-through wings that buzz (dragonfly bandits): one mesh for every flier.
static func _wings_mesh() -> ArrayMesh:
	if _wing_mesh == null:
		# (A shader, not a StandardMaterial3D: the wings glide with the body.)
		_wing_mat = ShaderMaterial.new()
		_wing_mat.shader = preload("res://shaders/bug_wing.gdshader")
		var st := MeshKit.begin()
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0.7, 0, 0)), Vector3(0.7, 0.012, 0.16), 3, 10, Color(1, 1, 1))
		for k in 4:
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0.35 + k * 0.25, 0.013, 0)), Vector3(0.01, 0.004, 0.24 - k * 0.04), Color(0.4, 0.5, 0.6))
		_wing_mesh = MeshKit.finish(st)
	return _wing_mesh


func is_climbing() -> bool:
	return state == State.CLIMBING


func is_alive() -> bool:
	return state != State.DEAD and not health.dead


## Burrowed bugs are underground: they can't be seen or hit.
func is_hidden() -> bool:
	return state == State.BURROWED


## Story (The Reckoning): while the Iron Mandible's amber furnace burns, bugs
## near it (ReckoningRules.FRENZY_RADIUS) move faster. Set on every peer.
static var frenzy_lit := false
static var frenzy_at := Vector3.ZERO


## Current movement multiplier (status effects).
func speed() -> float:
	var boss_k := boss.speed_mult() if boss != null else 1.0
	var frenzy := 1.0
	if frenzy_lit:
		frenzy = ReckoningRules.frenzy(Vector2(global_position.x - frenzy_at.x, global_position.z - frenzy_at.z).length(), true)
	return status.speed_multiplier() * (2.0 if smoker else 1.0) * _env_speed() * boss_k * frenzy


static var _env_frame := -1
static var _env_k := 1.0


## Weather and temperature on bug speed: the same for every bug, so worked out
## once per physics tick (temperature() asks the day cycle).
static func _env_speed() -> float:
	var f := Engine.get_physics_frames()
	if f != _env_frame:
		_env_frame = f
		_env_k = Weather.bug_speed(GameState.weather) * Weather.bug_temp_speed(GameState.temperature())
	return _env_k


## All bugs' update time this rendered frame (us), and the most it may take.
static var _frame_id := -1
static var _frame_us := 0
static var FRAME_BUDGET_US := 5500
var _moved_frame := -1


func _physics_process(delta: float) -> void:
	# Far-off and off-screen bugs update less often (with the time they missed),
	# so hundreds of bugs fit in a tick. Up close every tick.
	_tick_acc += delta
	# (Bosses always update: there are one or two, and their telegraphs must be smooth.)
	if detail != 0 and not due and state != State.DEAD and _tick_acc < 0.5 and boss == null:
		return
	# One rendered frame's budget for every bug together: when a slow frame makes
	# the engine run several physics ticks to catch up, a bug that already moved
	# this frame waits for the next one (with the time it missed), and once the
	# frame's budget is spent the rest wait too. A big crowd then costs a steady
	# slice of each frame instead of snowballing.
	var frame := Engine.get_process_frames()
	if frame != _frame_id:
		_frame_id = frame
		_frame_us = 0
	# (Sped-up headless sims run many ticks a frame on purpose: no frame budget there.)
	if boss == null and state != State.DEAD and Engine.time_scale <= 1.01 			and (_moved_frame == frame or _frame_us > FRAME_BUDGET_US):
		return
	_moved_frame = frame
	due = false
	var t0 := Time.get_ticks_usec()
	# All the time since its last update (a bug that waited longer than a
	# quarter second thinks in quarter-second steps, so it never loses ground).
	_pp(minf(_tick_acc, 1.0))
	_tick_acc = 0.0
	var took := Time.get_ticks_usec() - t0
	_frame_us += took
	BugManager.note_update(took)


func _pp(delta: float) -> void:
	if state == State.DEAD:
		return
	if host:
		var left := delta
		while true:
			var step := minf(left, 0.25)
			status.tick(step)
			_think(step)
			left -= step
			if left <= 0.0001:
				break
	var target := target_transform()
	# Riding up over a small bug, or ducked flat under a big one.
	target.origin += target.basis.y * (ride - _clear * 0.55 * crouch)
	if not _placed or host:
		global_transform = target
		_placed = true
	else:
		# Client: straight from where the bug was when the last state arrived
		# to where that state puts it, over the time between states (a steady
		# pace, ~one sync interval behind the host), not an ease that lurches
		# every packet.
		if _net_from.origin.distance_to(target.origin) > 15.0:
			global_transform = target # knocked off the cliff, or swapped cliffs: snap
			_net_from = target
		else:
			# (Timed from the tick the state arrived, not this bug's turn, which
			# may have started before it.)
			var since := float(Engine.get_physics_frames() - _net_tick) / float(Engine.physics_ticks_per_second)
			var k := clampf(since / _net_dur, 0.0, 1.0)
			global_transform = Transform3D(_net_from.basis.orthonormalized().slerp(target.basis.orthonormalized(), k),
					_net_from.origin.lerp(target.origin, k))
	var spd := global_position.distance_to(_last_pos) / maxf(delta, 0.0001)
	# Remember the velocity before _last_pos moves on (turrets lead shots with it).
	if delta > 0.0001 and _last_pos != Vector3.ZERO:
		_vel = (global_position - _last_pos) / delta
	_last_pos = global_position
	_update_visibility()
	if boss != null:
		boss.visual(delta)
	if is_hidden():
		return
	# Level of detail: legs and body animation run every update on screen, and
	# not at all off-screen (they catch up on return); the body still follows.
	# (detail is set by BugManager.assign_detail, a few times a second)
	_anim_acc += delta
	# Everything written below glides from where it was last drawn (LegBatch).
	LegBatch.motion = _glide_motion()
	if detail != 2:
		_legs.set_lite(detail != 0)
		# Feet only need the ground's shape off the cliff face (else: the plane under the body).
		var walk := state == State.BREACHING or state == State.CROSSING or state == State.SLEEPING or state == State.HUNTING
		_legs.update(_anim_acc, global_transform, spd, _project if walk else Callable())
		_animate_body(_anim_acc, spd)
		_anim_acc = 0.0
	_write_body()
	LegBatch.motion = Color()
	if _face != null:
		glide_face()


## Glide (see LegBatch): a bug updated every few ticks is drawn sliding from
## where it was drawn at its last update to where it is now, arriving as long
## after as its updates are apart (smoothed). Never across a state or
## cliff change, a jump, a long wait, or for bosses (their parts are nodes).
const GLIDE_MAX_TICKS := 30
const GLIDE_SNAP := 3.0
## Off with --noglide (A/B testing): bugs drawn where they are, stepping.
static var glide_on := true
var _glide := Color()
var _glide_at := Vector3.ZERO
var _glide_tick := -1
## Smoothed ticks between updates: how long each glide lasts.
var _glide_gap := 1.0
var _glide_state := -1
var _glide_cliff := -1


func _glide_motion() -> Color:
	var now := LegBatch.glide_tick()
	var p := global_position
	var ticks := now - _glide_tick
	if ticks == 0:
		return _glide
	var out := Color()
	if _glide_tick >= 0 and ticks <= GLIDE_MAX_TICKS and glide_on and state == _glide_state and cliff_id == _glide_cliff and boss == null:
		var d := p - (_glide_at + LegBatch.glide_offset(_glide, float(now)))
		var dd := d.length_squared()
		_glide_gap = LegBatch.next_gap(_glide_gap, ticks)
		if dd < GLIDE_SNAP * GLIDE_SNAP and dd > 0.0000001:
			out = LegBatch.glide_from(p - d, p, now, roundi(_glide_gap))
	else:
		_glide_gap = float(clampi(ticks, 1, GLIDE_MAX_TICKS))
	_glide = out
	_glide_at = p
	_glide_tick = now
	_glide_state = state
	_glide_cliff = cliff_id
	return out


## Where the body is drawn relative to where the bug is (corpses start there).
func glide_offset() -> Vector3:
	return LegBatch.glide_offset(_glide)


## Client: a new state arrived (BugManager._apply_states): glide on from here.
var _net_from := Transform3D()
var _net_tick := 0
var _net_dur := 0.1
var _net_last_ms := -1


func net_received() -> void:
	var ms := Time.get_ticks_msec()
	if _net_last_ms >= 0:
		# Time between states, smoothed (a little over, so a late packet doesn't stall it).
		_net_dur = lerpf(_net_dur, clampf(float(ms - _net_last_ms) / 1000.0 * 1.1, 0.05, 0.3), 0.3)
	_net_last_ms = ms
	if is_inside_tree():
		_net_from = global_transform
	_net_tick = Engine.get_physics_frames()


## 0 = close and on screen, 1 = far but on screen, 2 = off screen (no camera: full),
## 3 = close but over the full-detail budget (a big crowd): updated like 2 but animated.
var detail := 0
var _anim_acc := 0.0
const LOD_FAR := 18.0
## Distance to the camera at the last detail check (faces only animate close up).
var cam_dist := 0.0
## Physics ticks between updates for each detail level.
var _tick_acc := 0.0
## Set by BugManager when it's this bug's turn (bugs other than the nearest
## few take turns, a fixed number per tick, so a big crowd can't stall a tick).
var due := false


func detail_level() -> int:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 0
	return detail_from(cam.global_position, cam.get_frustum())


## detail_level() with the camera position and frustum worked out once for the crowd.
func detail_from(cam_pos: Vector3, frustum: Array[Plane]) -> int:
	var r := _lod_r
	var p := global_position
	var dist := cam_pos.distance_to(p)
	cam_dist = dist
	if dist < r * 2.0 + 3.0:
		return 0
	for plane: Plane in frustum:
		if plane.distance_to(p) > r:
			return 2
	return 0 if dist < LOD_FAR else 1


## Breathing, a bob in the stride, and a little lean into the walk.
var _anim_t := randf() * 10.0


func _animate_body(delta: float, spd: float) -> void:
	if _amber_shell != null: # Hive amber: frozen mid-stride inside the statue
		return
	_anim_t += delta
	var s := _scale * grow
	# Canyon Expeditions: asleep at a site it lies low, breathing slow and deep.
	_sleep_k = move_toward(_sleep_k, 1.0 if state == State.SLEEPING else 0.0, delta * 2.5)
	var breathe := sin(_anim_t * lerpf(2.2, 0.9, _sleep_k)) * lerpf(0.03, 0.06, _sleep_k)
	var stride := clampf(spd * 0.4, 0.0, 1.0)
	# Ducking: squashed flat and a little wider, legs splayed (the leg rig follows the body).
	var duck := 1.0 - 0.45 * maxf(crouch, _sleep_k)
	var scl := Vector3(s * (1.0 - breathe * 0.5) * (1.0 + 0.12 * crouch), s * (1.0 + breathe) * duck, s * (1.0 - breathe * 0.3) * (1.0 + 0.08 * crouch))
	var pos := Vector3(0, absf(sin(_anim_t * (6.0 + spd * 2.0))) * 0.05 * s * stride, 0)
	var rot := Vector3(sin(_anim_t * (3.0 + spd)) * 0.04 * stride, 0, sin(_anim_t * (6.0 + spd * 2.0)) * 0.03 * stride)
	rot.z += 0.22 * _sleep_k # rolled a little onto its side
	_body_local = Transform3D(Basis.from_euler(rot).scaled_local(scl), pos)
	if _face != null:
		_place_face()
	_show_zzz()


var _was_hidden := -1


func _update_visibility() -> void:
	var hidden := is_hidden()
	if int(hidden) == _was_hidden:
		return
	_was_hidden = int(hidden)
	if hidden and _body_slot >= 0:
		_body_b.hide(_body_slot)
	if hidden:
		for s: int in _wing_slots:
			_wing_b.hide(s)
	if _solo != null:
		_solo.visible = not hidden
	_legs.set_shown(not hidden)
	if _face != null:
		_face.visible = not hidden
	_hitbox.collision_layer = 0 if hidden else WorldLayout.LAYER_BUG


func _think(delta: float) -> void:
	if latched:
		return # clamped to the face (LatchDirector)
	if entombed > 0.0: # Hive amber: set solid on the wall (Amber Kiln)
		entombed -= delta
		statue_blocked = 0.0
		if entombed <= 0.0:
			_end_entomb(false, _entomb_source, _entomb_cliff)
		return
	if boss != null and boss.think(delta):
		return
	match state:
		State.SLEEPING, State.HUNTING:
			if hunter != null:
				hunter.update(delta)
		State.CROSSING:
			if hunt_peer != 0: # Canyon Expeditions: hunting a player on the floor
				FloorHunt.think(self, delta)
				return
			# Out of the tunnel in the far wall and across the canyon floor to the
			# foot of the cliff it will climb.
			var goal := cliffs.tunnel_mouth(cliff_id, lane_z)
			var to := Vector3(goal.x - ground_pos.x, 0.0, goal.z - ground_pos.z)
			var step := def.walk_speed * 2.2 * speed() * delta
			# Crowd pushes keep big bugs with the same goal shoving each other off
			# it, so "arrived" allows for the bug's own body width.
			if to.length() <= step + 0.4 + crowd_r * 1.5:
				state = State.CLIMBING
				climb_y = 0.0
			else:
				ground_pos += to.normalized() * step
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
	# The boss crests the lip and rams the Homestead with its horn.
	if def.behavior == BugDef.Behavior.BOSS:
		GameState.damage_homestead(cliff_id, 150.0)
		if boss != null:
			boss.on_crest()


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
	var clear := _clear
	match state:
		State.CLIMBING, State.DEAD:
			return _face_transform(climb_y, clear)
		State.CRESTING:
			var a := _face_transform(WorldLayout.CLIFF_HEIGHT - 0.4, clear)
			var b := _ground_transform(_plateau_entry(), -_outward(), clear)
			var t := crest_t
			var pos := a.origin.lerp(b.origin, t) + Vector3.UP * sin(t * PI) * 0.8
			return Transform3D(a.basis.slerp(b.basis, t), pos)
		State.CROSSING, State.SLEEPING, State.HUNTING:
			_update_heading()
			var h := _heading if _heading.length() > 0.01 else -_outward()
			var zc := -Vector3(h.x, 0, h.z).normalized()
			var xc := Vector3.UP.cross(zc).normalized()
			return Transform3D(Basis(xc, Vector3.UP, zc), Vector3(ground_pos.x, _floor_y(ground_pos) + clear, ground_pos.z))
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
	return cliffs.face_frame(cliff_id, y, lane_z, clear)


func _ground_transform(pos: Vector3, heading: Vector3, clear: float) -> Transform3D:
	var h := heading
	h.y = 0.0
	if h.length() < 0.01:
		h = -_outward()
	var z_axis := -h.normalized()
	var x_axis := Vector3.UP.cross(z_axis).normalized()
	var ground := Vector3(pos.x, cliffs.ground_height_fast(cliff_id, pos) + clear, pos.z)
	return Transform3D(Basis(x_axis, Vector3.UP, z_axis), ground)


func _plateau_entry() -> Vector3:
	return cliffs.plateau_point(cliff_id, 1.5, lane_z)


## Direction from the cliff into the canyon.
func _outward() -> Vector3:
	return WorldLayout.inward(cliff_id) # Maps:


## Projects a point onto the surface under the bug (for foot placement).
func _project(point: Vector3, up: Vector3) -> Vector3:
	if state == State.BREACHING:
		return Vector3(point.x, cliffs.ground_height_fast(cliff_id, point), point.z)
	if state == State.CROSSING or state == State.SLEEPING or state == State.HUNTING:
		return Vector3(point.x, _floor_y(point), point.z)
	var base := global_position - up * _clear
	return point - up * (point - base).dot(up)


## Below this a crossing bug walks a story set's floor (Down the Hole's tunnel,
## built far under the map) at its ground_pos.y instead of the canyon floor.
const UNDERGROUND_Y := -40.0


func _floor_y(p: Vector3) -> float:
	if ground_pos.y < UNDERGROUND_Y:
		return ground_pos.y
	return cliffs.floor_height(p.x, p.z)


## Turrets can't lock on to this bug right now (a boss mechanic, e.g. the Mirage Mantis fading).
func untargetable() -> bool:
	return (boss != null and boss.untargetable()) or entombed > 0.0 or latched # Hive amber: statues are left standing; latch bugs are tucked under the turrets


## Where a turret standing at `from` aims at this bug (a boss may offer parts, e.g. legs).
func aim_for(from: Vector3) -> Vector3:
	return boss.aim_for(from) if boss != null else global_position


## Rough world velocity of the bug (for leading shots).
func velocity_hint() -> Vector3:
	return _vel # (was read after _last_pos moved on, so it was always ~0)


## Every peer: a net wrapped round the bug for `seconds` (Net Thrower).
@rpc("authority", "call_local", "reliable")
func show_net(seconds: float) -> void:
	var net := MeshInstance3D.new()
	var st := MeshKit.begin()
	var r := float(spec["body_radius"]) * 1.25
	for i in 6:
		var a := PI * float(i) / 6.0
		var prev := Vector3(cos(a) * r, 0, sin(a) * r)
		for k in 8:
			var b := TAU * float(k + 1) / 8.0
			var p := Basis(Vector3.UP, a) * Vector3(cos(b) * r, sin(b) * r, 0)
			MeshKit.add_limb(st, Basis(Vector3.UP, a) * Vector3(cos(TAU * float(k) / 8.0) * r, sin(TAU * float(k) / 8.0) * r, 0), p, 0.02, Color("#C8A878"), 3)
	for k in 4:
		var y := -r + (k + 0.5) * r * 0.5
		var rr := sqrt(maxf(r * r - y * y, 0.01))
		var prev := Vector3(rr, y, 0)
		for j in 10:
			var a := TAU * float(j + 1) / 10.0
			var p := Vector3(cos(a) * rr, y, sin(a) * rr)
			MeshKit.add_limb(st, prev, p, 0.02, Color("#B8955A"), 3)
			prev = p
	net.mesh = MeshKit.finish(st)
	net.material_override = Materials.toon(0.0)
	net.position = Vector3(0, float(spec["clearance"]) * 0.3, 0)
	add_child(net)
	get_tree().create_timer(seconds).timeout.connect(net.queue_free)


## Every peer: a Signal Flare stuck in the bug, burning for `seconds` (the
## host marks it for every turret: BugStatus.mark).
@rpc("authority", "call_local", "reliable")
func show_flare(seconds: float) -> void:
	for c in get_children():
		if c is SignalFlare:
			(c as SignalFlare).life = (c as SignalFlare).get("_t") + seconds # re-marked: burn on
			return
	var f := SignalFlare.make(seconds)
	f.position = Vector3(0, float(spec["clearance"]) * 0.3 + float(spec["body_radius"]) * 0.9, 0)
	add_child(f)


## Every peer: bola ropes wound round the bug, weights hanging, for `seconds` (Bola Launcher).
@rpc("authority", "call_local", "reliable")
func show_bola(seconds: float) -> void:
	var tangle := MeshInstance3D.new()
	tangle.mesh = SpecialShotFx.bola_tangle_mesh(float(spec["body_radius"]))
	tangle.material_override = Materials.toon(0.01)
	tangle.position = Vector3(0, float(spec["clearance"]) * 0.3, 0)
	add_child(tangle)
	get_tree().create_timer(seconds).timeout.connect(tangle.queue_free)


## Host only: a hit from a player, turret or blast, via a Hitbox.
func receive_hit(damage: float, _point: Vector3, dir: Vector3, pierce: bool, multiplier: float,
		source: String, source_cliff: int) -> void:
	if not multiplayer.is_server() or not is_alive() or is_hidden():
		return
	if entombed > 0.0: # Hive amber: any hit shatters a statue (a small loot burst)
		_end_entomb(true, source, source_cliff)
		return
	if latched: # Latch bugs: only a rider right on top of it pries it off
		if _rider_close(source):
			unlatch_kill(source, source_cliff)
		return
	var dmg := damage * multiplier
	if status.is_stripped():
		pierce = true # Rust Duster / Acid Drencher: the armour's eaten away
	# Kill-method variants take more or less from bullets, fire or explosives.
	if not def.damage_taken.is_empty():
		dmg *= def.damage_mult(KillMethod.of(source))
	if boss != null:
		dmg = boss.body_damage(dmg, _point, source, source_cliff)
	# The armour plate faces away from the cliff: shots from the canyon side bounce off it.
	if def.front_armor > 0.0 and not pierce and state == State.CLIMBING:
		if dir.normalized().dot(global_basis.y) < -0.3:
			dmg *= 1.0 - def.front_armor
	health.take_damage(dmg, source, source_cliff)
	if hunter != null:
		hunter.wake() # Canyon Expeditions: a shot wakes a sleeper
	_check_brood()


func _check_brood() -> void:
	# The Iron Tumbleweed drops off at half health and re-climbs the other cliff.
	if def.id == &"iron_tumble" and not brood_done and health.fraction() <= 0.5 and state == State.CLIMBING:
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


## What the bug was doing when it died (for loot: only plateau kills drop it).
var died_in := -1


func _on_died(source: String, source_cliff: int) -> void:
	if boss != null:
		boss.on_death(source, source_cliff)
	if def.behavior == BugDef.Behavior.BROOD and not brood_done:
		brood_done = true
		if brood_burst.is_valid():
			brood_burst.call(self)
	died_in = state
	state = State.DEAD
	died.emit(self, source, source_cliff)


# ------------------------------------------------------------------ hive amber

## Host: seconds left of this bug's amber statue (Amber Kiln). Frozen on the
## wall, left alone by turrets, and nothing climbs through it.
var entombed := 0.0
## Latch bugs (LatchDirector): clamped under a turret line, jamming it.
var latched := false
var _latch_mark: Node3D
var _entomb_source := ""
var _entomb_cliff := -1
## Host: set by BugManager.separate() while a statue shoves this bug back (LaneClimber steps round it).
var statue_blocked := 0.0
## Host: who rang the Queen's Bell this bug is frenzied by (kill credit for its bites).
var frenzy_source := ""
var frenzy_cliff := -1
var _amber_shell: MeshInstance3D
var _frenzy_mark: Label3D
## Debug (--amberview): statues entombed and shattered this run, frenzy bites.
static var amber_stats: Dictionary = {}


static func _tally(key: String, n: int = 1) -> void:
	amber_stats[key] = int(amber_stats.get(key, 0)) + n


func is_entombed() -> bool:
	return entombed > 0.0


## Host: the Amber Kiln's molten amber sets round this bug: a statue for
## `seconds`. Bosses and anything off the wall are never entombed.
func entomb(seconds: float, source: String, source_cliff: int) -> bool:
	if boss != null or not is_alive() or state != State.CLIMBING or entombed > 0.0:
		return false
	entombed = seconds
	_entomb_source = source
	_entomb_cliff = source_cliff
	crowd_w = BugCrowd.STATUE_WEIGHT
	status.root(seconds + 1.0)
	_tally("entombed")
	show_entomb.rpc(seconds)
	return true


## Host: the statue ends: shattered by a hit (`shattered`: a small loot burst
## for whoever broke it) or the bug suffocated inside and it crumbles. Either way the bug dies.
func _end_entomb(shattered: bool, source: String, source_cliff: int) -> void:
	entombed = 0.0
	crowd_w = BugCrowd.weight(def.size, false)
	_tally("shattered" if shattered else "crumbled")
	var cid := source_cliff if source_cliff >= 0 else _entomb_cliff
	if shattered and cid >= 0:
		Economy.earn(cid, AmberRules.shatter_loot(def.size))
	show_entomb.rpc(-1.0 if shattered else 0.0)
	health.take_damage(health.hp + 1.0, source if source != "" else _entomb_source, cid)


## Every peer: the amber shell round the bug (`seconds` > 0), or off again:
## 0 crumbles, -1 shatters (shards fly).
@rpc("authority", "call_local", "reliable")
func show_entomb(seconds: float) -> void:
	if seconds > 0.0:
		if _amber_shell == null:
			_amber_shell = MeshInstance3D.new()
			_amber_shell.name = "AmberShell"
			_amber_shell.mesh = AmberFx.shell_mesh(float(spec["body_radius"]), name.hash())
			_amber_shell.material_override = AmberFx.shell_material()
			_amber_shell.position = Vector3(0, float(spec["clearance"]) * 0.35, 0)
			add_child(_amber_shell)
			AmberFx.set_pulse(_amber_shell)
		return
	if _amber_shell != null:
		var at := _amber_shell.global_position
		_amber_shell.queue_free()
		_amber_shell = null
		AmberFx.shatter(self, at, float(spec["body_radius"]), seconds < 0.0)


## Host: a Queen's Bell toll: this bug turns on its neighbours for `seconds`.
func frenzy(seconds: float, source: String, source_cliff: int) -> bool:
	if boss != null or not is_alive() or entombed > 0.0 or state != State.CLIMBING:
		return false
	status.frenzy(seconds)
	frenzy_source = source
	frenzy_cliff = source_cliff
	_tally("frenzied")
	show_frenzy.rpc(seconds)
	return true


## Every peer: the frenzied bug's angry amber mark for `seconds`.
@rpc("authority", "call_local", "reliable")
func show_frenzy(seconds: float) -> void:
	if _frenzy_mark == null:
		_frenzy_mark = AmberFx.frenzy_mark()
		_frenzy_mark.position = Vector3(0, float(spec["body_radius"]) * 1.7 + 0.5, 0)
		add_child(_frenzy_mark)
	_frenzy_mark.visible = true
	_frenzy_mark.set_meta(&"until", Time.get_ticks_msec() + int(seconds * 1000.0))
	AmberFx.pulse_mark(_frenzy_mark)


## Host: a Queen's Bell toll knocks a flier out of the air: the fall hurts, and
## it lies stunned where it lands before it takes off again.
func drop_from_sky(source: String, source_cliff: int) -> bool:
	if boss != null or not is_alive() or state != State.FLYING:
		return false
	_tally("dropped")
	health.take_damage(AmberRules.drop_damage(health.max_hp), source, source_cliff)
	if not is_alive():
		return true
	ground_pos.y = _ground_under(ground_pos) + _clear
	status.root(AmberRules.DROP_STUN)
	return true


## Ground height under a point: a plateau if it's over one, else the canyon floor.
func _ground_under(p: Vector3) -> float:
	if cliffs == null:
		return 0.0
	for cid in WorldLayout.cliff_count():
		var pc := cliffs.plateau_coords(cid, p)
		if pc.x >= 0.0 and pc.x <= WorldLayout.PLATEAU_DEPTH + 10.0:
			return cliffs.ground_height_fast(cid, p)
	return cliffs.floor_height(p.x, p.z)


## Canyon Expeditions: a little drifting "z z" over a sleeping site bug.
func _show_zzz() -> void:
	var on := state == State.SLEEPING and _sleep_k > 0.5
	if not on:
		if _zzz != null:
			_zzz.visible = false
		return
	if _zzz == null:
		_zzz = Label3D.new()
		_zzz.text = "z Z"
		_zzz.font_size = 72
		_zzz.pixel_size = 0.006
		_zzz.outline_size = 14
		_zzz.modulate = Color("#F2E3C2")
		_zzz.outline_modulate = Color("#2B1B17")
		_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_zzz.no_depth_test = false
		add_child(_zzz)
	_zzz.visible = true
	var lift := float(spec["body_radius"]) * 1.6 + 0.4
	_zzz.position = Vector3(sin(_anim_t * 0.7) * 0.15, lift + fmod(_anim_t * 0.25, 0.4), 0)
	_zzz.modulate.a = 0.6 + 0.4 * sin(_anim_t * 1.3)


# ------------------------------------------------------------------ latch bugs

## Host: scuttle to `z` along the face, `y` up it, and clamp on (LatchDirector).
func latch_at(z: float, y: float) -> void:
	if not multiplayer.is_server() or not is_alive() or state != State.CLIMBING:
		return
	lane_z = z
	climb_y = y
	show_latch.rpc(true, z, y)


## Host: pried off by a rider (or a CPU partner): it dies, paying as a kill.
func unlatch_kill(source: String, source_cliff: int) -> void:
	if not latched:
		return
	show_latch.rpc(false, lane_z, climb_y)
	health.take_damage(health.hp + 1.0, source, source_cliff)


## Host: is the rider named `source` close enough to touch this bug?
func _rider_close(source: String) -> bool:
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p != null and p.display_name() == source:
			return p.global_position.distance_to(global_position) <= LatchDirector.POINT_BLANK
	return false


## Every peer: clamped on (a pulsing red glow and a warning over it) or off.
@rpc("authority", "call_local", "reliable")
func show_latch(on: bool, z: float, y: float) -> void:
	latched = on
	lane_z = z
	climb_y = y
	if on and not LatchDirector.latched.has(self):
		LatchDirector.latched.append(self)
	elif not on:
		LatchDirector.latched.erase(self)
	if _latch_mark != null:
		_latch_mark.queue_free()
		_latch_mark = null
	if not on:
		return
	_latch_mark = Node3D.new()
	add_child(_latch_mark)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.25, 0.15)
	glow.light_energy = 2.0
	glow.omni_range = 3.5
	_latch_mark.add_child(glow)
	var tag := Label3D.new()
	tag.text = "LATCHED"
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.outline_size = 12
	tag.modulate = Color(1.0, 0.45, 0.3)
	tag.outline_modulate = Palette.OUTLINE
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3.UP * 1.6
	_latch_mark.add_child(tag)
