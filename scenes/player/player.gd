class_name Player
extends CharacterBody3D
## First-person controller: walk, sprint, jump, slide, mantle, revolver.
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

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var collision: CollisionShape3D = $Collision
@onready var revolver: Revolver = $Head/Camera/Revolver
@onready var net: PlayerNet = $Net
@onready var body: MeshInstance3D = $Body
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
	body.mesh = CharacterBuilder.cowboy(Palette.team_color(cliff_id))
	body.material_override = Materials.toon_unique(0.025)
	net.prime()
	if is_multiplayer_authority():
		camera.current = true
		# Your own body only casts a shadow.
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if GameState.flag_value("--shot") == "": # automated screenshots ignore the mouse
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.current = false
		revolver.visible = false
		revolver.set_process(false)
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


## Remote players: crouch the body while sliding.
func set_remote_pose(sliding: bool) -> void:
	var target := 0.55 if sliding else 1.0
	body.scale.y = lerpf(body.scale.y, target, 0.3)


## Remote players: a quick bright flash on the body when they fire.
func flash_body() -> void:
	var mat := body.material_override as ShaderMaterial
	mat.set_shader_parameter("flash_color", Palette.GLOW_YELLOW)
	mat.set_shader_parameter("flash_amount", 0.6)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash_amount", v), 0.6, 0.0, 0.15)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := Settings.mouse_sensitivity
		var y_sign := -1.0 if Settings.invert_y else 1.0
		rotate_y(-motion.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * sens * y_sign, -1.5, 1.5)
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not GameState.menu_open:
		if (event as InputEventMouseButton).pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _mantling:
		return
	_update_fall(delta)
	var blocked := GameState.menu_open or vitals.downed
	var input_dir := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= _gravity * delta

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

	var sprinting := not blocked and vitals.can_sprint() and Input.is_action_pressed("sprint") and input_dir.y < -0.1 and not _sliding
	if not blocked and Input.is_action_just_pressed("slide") and on_floor and not _sliding:
		var speed := Vector2(velocity.x, velocity.z).length()
		if sprinting or speed > WALK_SPEED * 0.9:
			_start_slide()

	if _sliding:
		_process_slide(delta)
	else:
		var target_speed := SPRINT_SPEED if sprinting else WALK_SPEED
		var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
		var horiz := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * target_speed, accel * delta)
		velocity.x = horiz.x
		velocity.z = horiz.z

	move_and_slide()
	_update_camera(delta, sprinting)
	_handle_weapon()


func _handle_weapon() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or GameState.menu_open or vitals.downed:
		return
	if build_mode != null and build_mode.active:
		return
	if Input.is_action_just_pressed("fire") and revolver.trigger(camera):
		net.fire(camera.global_position, -camera.global_transform.basis.z)
	if Input.is_action_just_pressed("reload"):
		revolver.reload(vitals.reload_multiplier())


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

func _update_fall(delta: float) -> void:
	if _fall_left < 0.0:
		if global_position.y < WorldLayout.CANYON_FALL_Y:
			_fall_left = RESPAWN_DELAY
			fell_into_canyon.emit(RESPAWN_DELAY)
		return
	_fall_left -= delta
	if _fall_left <= 0.0:
		_fall_left = -1.0
		respawn()


func respawn() -> void:
	global_transform = spawn_transform
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
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 8.0, 0.0, 1.0))
