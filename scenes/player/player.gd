class_name Player
extends CharacterBody3D
## First-person controller: walk, sprint, jump, slide, mantle, guns.
## Falling into the canyon hauls you back home after a short delay.

signal fell_into_canyon(delay: float)
signal respawned

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.5
const JUMP_VELOCITY := 6.2
const ACCEL_GROUND := 60.0
const ACCEL_AIR := 14.0
const SLIDE_BOOST := 4.5
const SLIDE_TIME := 0.75
const SLIDE_FRICTION := 7.0
const MANTLE_REACH := 0.9
const MANTLE_MAX_HEIGHT := 1.9
const STAND_HEIGHT := 1.8
const SLIDE_HEIGHT := 1.0
const EYE_STAND := 1.62
const EYE_SLIDE := 0.85
const RESPAWN_DELAY := 3.0

@export var cliff_id: int = WorldLayout.WEST

var spawn_transform: Transform3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _sliding := false
var _slide_left := 0.0
var _mantling := false
var _fall_left := -1.0
var _bob_t := 0.0
var _capsule: CapsuleShape3D
var _shake := 0.0
## Ladder volumes the player is inside (the airship's rope ladder): forward climbs.
var ladder_count := 0
## Knocked about (rock hit): less control for a moment, the camera rolls.
var _stagger := 0.0
var _roll := 0.0
var _roll_vel := 0.0
var _rock_cd := 0.0
const ROCK_COOLDOWN := 0.8
## Local player only: T lights one up (see Cigarette).
var cigarette: Cigarette
## World height of the ladder's top (the deck): you step off forward once above it.
var ladder_top_y := 0.0
const CLIMB_SPEED := 4.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var collision: CollisionShape3D = $Collision
@onready var gun: Gun = $Head/Camera/Gun
@onready var net: PlayerNet = $Net
@onready var body: MeshInstance3D = $Body
var rig: DummyRig
var _remote_sliding := false
var _last_pos := Vector3.ZERO
var _last_y := 0.0
var _vy_smooth := 0.0
@onready var vitals: PlayerVitals = $Vitals
## Set by the world for the local player.
var build_mode: BuildMode


func _ready() -> void:
	# Each player needs its own capsule so sliding doesn't resize the other player.
	add_to_group("players")
	_capsule = (collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	collision.shape = _capsule
	spawn_transform = global_transform
	camera.fov = Settings.fov
	body.visible = false
	rig = DummyRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(Palette.team_color(cliff_id), is_multiplayer_authority() and not GameState.has_flag("--thirdperson"),
			Settings.look if is_multiplayer_authority() else {})
	net.prime()
	if is_multiplayer_authority():
		cigarette = Cigarette.new()
		cigarette.name = "Cigarette"
		cigarette.player = self
		camera.add_child(cigarette)
		camera.current = true
		if GameState.flag_value("--shot") == "": # automated screenshots ignore the mouse
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.current = false
		gun.visible = false
		gun.set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)


func is_sliding() -> bool:
	return _sliding


func is_downed() -> bool:
	return vitals.downed if is_multiplayer_authority() else net.sync_downed


func display_name() -> String:
	var id := get_multiplayer_authority()
	if NetworkManager.players.has(id):
		return str((NetworkManager.players[id] as Dictionary)["name"])
	return NetworkManager.local_name


## Remote players: the replicated slide state drives the body pose.
func set_remote_pose(sliding: bool) -> void:
	_remote_sliding = sliding


## Remote players: a quick bright flash on the body when they fire.
func flash_body() -> void:
	rig.flash()


func _process(delta: float) -> void:
	# Body animation for everyone: walk with speed, aim with pitch, crouch when sliding.
	var moved := global_position - _last_pos
	_last_pos = global_position
	moved.y = 0.0
	var speed := moved.length() / maxf(delta, 0.0001)
	var sliding := _sliding if is_multiplayer_authority() else _remote_sliding
	var vy := (global_position.y - _last_y) / maxf(delta, 0.0001)
	_last_y = global_position.y
	_vy_smooth = lerpf(_vy_smooth, vy, clampf(delta * 10.0, 0.0, 1.0))
	rig.animate(delta, minf(speed, 12.0), sliding, head.rotation.x, _vy_smooth if not is_on_floor() or not is_multiplayer_authority() else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw_rock") and not GameState.menu_open and not vitals.downed and _rock_cd <= 0.0:
		_rock_cd = ROCK_COOLDOWN
		net.throw_rock(camera.global_position - camera.global_transform.basis.z * 0.4 + camera.global_transform.basis.x * 0.15,
				-camera.global_transform.basis.z * 18.0 + Vector3.UP * 3.0 + velocity * 0.5)
		get_viewport().set_input_as_handled()
		return
	if cigarette != null and event.is_action_pressed("smoke") and not GameState.menu_open and not vitals.downed:
		cigarette.light()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := Settings.mouse_sensitivity / gun.zoom_factor()
		var y_sign := -1.0 if Settings.invert_y else 1.0
		rotate_y(-motion.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * sens * y_sign, -1.5, 1.5)
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not GameState.menu_open \
			and not (build_mode != null and build_mode.menu_open):
		if (event as InputEventMouseButton).pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _mantling:
		return
	_update_fall(delta)
	var blocked := GameState.menu_open or vitals.downed
	var input_dir := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_rock_cd = maxf(_rock_cd - delta, 0.0)
	if _stagger > 0.0:
		_stagger = maxf(_stagger - delta, 0.0)
		input_dir *= 0.25
	var wish := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var on_floor := is_on_floor()
	if ladder_count > 0 and not blocked:
		# On a ladder: forward/back climbs, sideways shuffles, no gravity.
		velocity.y = -input_dir.y * CLIMB_SPEED
		if global_position.y > ladder_top_y + 1.0:
			velocity.y = minf(velocity.y, 0.0)
		var side := transform.basis.x * input_dir.x * 2.0
		var push := Vector3.ZERO
		if global_position.y > ladder_top_y + 0.05:
			push = -transform.basis.z * maxf(-input_dir.y, 0.0) * 3.0
		velocity.x = side.x + push.x
		velocity.z = side.z + push.z
		if Input.is_action_just_pressed("jump"):
			velocity += transform.basis.z * 3.0 + Vector3.UP * 2.0
			ladder_count = 0
		move_and_slide()
		_update_camera(delta, false)
		_handle_weapon()
		return
	if not on_floor:
		velocity.y -= _gravity * delta
	if _fall_left >= 0.0:
		input_dir = Vector2.ZERO # flat on the canyon floor

	if not blocked and Input.is_action_just_pressed("jump"):
		if on_floor:
			velocity.y = JUMP_VELOCITY
			_end_slide()
		elif _try_mantle():
			return
	elif not blocked and not on_floor and Input.is_action_pressed("jump") and velocity.y < 1.0:
		# Holding jump against a ledge mantles onto it.
		if _try_mantle():
			return

	var sprinting := not blocked and Input.is_action_pressed("sprint") and input_dir.y < -0.1 and not _sliding and not gun.aiming
	if not blocked and Input.is_action_just_pressed("slide") and on_floor and not _sliding:
		var speed := Vector2(velocity.x, velocity.z).length()
		if sprinting or speed > WALK_SPEED * 0.9:
			_start_slide()

	if _sliding:
		_process_slide(delta)
	else:
		var target_speed := SPRINT_SPEED if sprinting else WALK_SPEED
		if cigarette != null:
			target_speed *= cigarette.speed_multiplier()
		if gun.aiming:
			target_speed *= 0.6
		var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
		if _stagger > 0.0:
			accel *= 0.12
		var horiz := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * target_speed, accel * delta)
		velocity.x = horiz.x
		velocity.z = horiz.z

	move_and_slide()
	_update_camera(delta, sprinting)
	_handle_weapon()


func _handle_weapon() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or GameState.menu_open or vitals.downed \
			or (build_mode != null and build_mode.active):
		gun.set_aiming(false)
		return
	gun.set_aiming(Input.is_action_pressed("alt_fire") and not _sliding)
	if Input.is_action_just_pressed("fire") and gun.trigger(camera):
		net.fire(camera.global_position, -camera.global_transform.basis.z)
	if Input.is_action_just_pressed("reload"):
		gun.reload()


# ------------------------------------------------------------------ slide

func _start_slide() -> void:
	_sliding = true
	_slide_left = SLIDE_TIME
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var dir := horiz.normalized() if horiz.length() > 0.1 else -transform.basis.z
	velocity += dir * SLIDE_BOOST
	_set_height(SLIDE_HEIGHT)


func _process_slide(delta: float) -> void:
	_slide_left -= delta
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	horiz = horiz.move_toward(Vector3.ZERO, SLIDE_FRICTION * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	if _slide_left <= 0.0 or horiz.length() < WALK_SPEED * 0.5:
		_end_slide()


func _end_slide() -> void:
	if not _sliding:
		return
	_sliding = false
	_set_height(STAND_HEIGHT)


func _set_height(h: float) -> void:
	_capsule.height = h
	collision.position.y = h * 0.5


# ------------------------------------------------------------------ mantle

func _try_mantle() -> bool:
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var chest := global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(chest, chest + fwd * MANTLE_REACH)
	q.exclude = [get_rid()]
	var wall := space.intersect_ray(q)
	if wall.is_empty():
		return false
	var wall_pos: Vector3 = wall["position"]
	var top_from := Vector3(wall_pos.x, global_position.y + MANTLE_MAX_HEIGHT + 0.4, wall_pos.z) + fwd * 0.4
	var q2 := PhysicsRayQueryParameters3D.create(top_from, top_from + Vector3.DOWN * (MANTLE_MAX_HEIGHT + 0.4))
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty():
		return false
	var top_normal: Vector3 = top["normal"]
	var target: Vector3 = top["position"]
	var rise := target.y - global_position.y
	if top_normal.y < 0.7 or rise < 0.4 or rise > MANTLE_MAX_HEIGHT:
		return false
	_mantling = true
	_end_slide()
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(global_position.x, target.y + 0.1, global_position.z), 0.16)
	tw.tween_property(self, "global_position", target + Vector3.UP * 0.1, 0.12)
	tw.finished.connect(func() -> void: _mantling = false)
	return true


# ------------------------------------------------------------------ canyon fall

## Off the lip: the fall plays out. Gravity keeps building (you just keep
## speeding up), the view widens, speed lines rush past the edges of the
## screen, and when you hit the canyon floor there's the crash of a guitar
## smashed into something. A moment to take it in, then you're hauled back up.
const FALL_GRAVITY_GROWTH := 2.2
const FALL_MAX_SPEED := 85.0
const SPLAT_HOLD := 1.6
signal fall_landed

## 0..1 how fast you're falling (HUD speed lines, FOV).
var fall_intensity := 0.0
var _falling := false
var _fall_t := 0.0


func _update_fall(delta: float) -> void:
	if _fall_left >= 0.0:
		# Landed: lie there for a beat, then respawn.
		_fall_left -= delta
		fall_intensity = move_toward(fall_intensity, 0.0, delta * 4.0)
		if _fall_left <= 0.0:
			_fall_left = -1.0
			respawn()
		return
	if not _falling:
		if global_position.y < WorldLayout.CANYON_FALL_Y:
			_falling = true
			_fall_t = 0.0
			fell_into_canyon.emit(0.0)
		return
	_fall_t += delta
	# Extra gravity on top of the normal pull, growing the longer you fall.
	velocity.y = maxf(velocity.y - _gravity * FALL_GRAVITY_GROWTH * _fall_t * delta, -FALL_MAX_SPEED)
	fall_intensity = clampf(-velocity.y / 45.0, 0.0, 1.0)
	var floor_y := Bug.cliffs.floor_height(global_position.x, global_position.z) if Bug.cliffs != null else 0.0
	if is_on_floor() or global_position.y < floor_y + 0.6 or global_position.y < -20.0:
		_land()


func _land() -> void:
	_falling = false
	_fall_left = SPLAT_HOLD
	velocity = Vector3.ZERO
	Audio.play_at(&"guitar_smash", global_position + Vector3.UP, 4.0)
	add_shake(1.0)
	rig.knock(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(), 2.5)
	_roll_vel += randf_range(-1.0, 1.0) * 14.0
	fall_landed.emit()
	fell_into_canyon.emit(SPLAT_HOLD)


## Back on your own house's porch, facing out over the yard. Falls back to the
## first spawn point if the house isn't there (tests, menus).
func _porch_transform() -> Transform3D:
	var home := Homestead.of(cliff_id)
	if home == null or not home.is_inside_tree():
		return spawn_transform
	var at := home.to_global(HouseBuilder.porch_spawn())
	var fwd := -home.global_basis.z
	fwd.y = 0.0
	return Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), at)


func respawn() -> void:
	_falling = false
	fall_intensity = 0.0
	global_transform = _porch_transform()
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	_end_slide()
	respawned.emit()


# ------------------------------------------------------------------ camera feel

func _update_camera(delta: float, sprinting: bool) -> void:
	var eye := EYE_SLIDE if _sliding else EYE_STAND
	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and not _sliding and speed > 0.5:
		_bob_t += delta * speed * 1.6
	var bob := sin(_bob_t) * 0.035 * clampf(speed / SPRINT_SPEED, 0.0, 1.0)
	head.position.y = lerpf(head.position.y, eye + bob, clampf(delta * 14.0, 0.0, 1.0))
	var target_fov := Settings.fov
	if _sliding:
		target_fov += 12.0
	elif sprinting:
		target_fov += 7.0
	target_fov /= gun.zoom_factor()
	target_fov += fall_intensity * 28.0
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 8.0, 0.0, 1.0))
	# Screen shake (gunfire, nearby explosions).
	_shake = move_toward(_shake, 0.0, delta * 2.5)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.08
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.08
	# Wobbly roll after a hit (springs back).
	_roll_vel += (-_roll * 70.0 - _roll_vel * 8.0) * delta
	_roll += _roll_vel * delta
	camera.rotation.z = _roll


## Hit by a rock (or similar): a shove, a stumble, a floppy dummy wobble.
func bonk(dir: Vector3, strength: float) -> void:
	rig.knock(dir, strength)
	if not is_multiplayer_authority():
		return
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	velocity += flat * 7.0 * strength + Vector3.UP * 3.5 * strength
	_stagger = 0.6 * strength
	var side := signf(flat.dot(global_transform.basis.x))
	_roll_vel += -side * 6.0 * strength
	add_shake(0.5 * strength)


## Local player: shake the camera (0..1).
func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)
