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
## Slide-hop: jumping out of a slide kicks you forward and raises your top
## speed for a few seconds. Chain slide-jumps to stack it (up to SLIDE_HOP_MAX).
const SLIDE_HOP_KICK := 2.2
const SLIDE_HOP_SPEED := 1.3
const SLIDE_HOP_TIME := 3.0
const SLIDE_HOP_MAX := 3
const MANTLE_REACH := 0.9
const MANTLE_MAX_HEIGHT := 1.9
const STAND_HEIGHT := 1.8
const SLIDE_HEIGHT := 1.0
const EYE_STAND := 1.62
const EYE_SLIDE := 0.85
const RESPAWN_DELAY := 3.0
## Additions: sitting on a campfire log (see scenes/extras/campfire.gd).
const EYE_SEATED := 1.05
var seated := false
# Crewed: the crewed gun you're sitting in (CrewedTurret drives you while set).
var crewing: CrewedTurret = null

@export var cliff_id: int = WorldLayout.WEST

var spawn_transform: Transform3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _sliding := false
var _slide_left := 0.0
var _mantling := false
var _fall_left := -1.0
var _bob_t := 0.0
var _body_vel := Vector3.ZERO
var _feel_floor := true
var _feel_vy := 0.0
var _cam_land := 0.0
var _cam_land_vel := 0.0
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
## First-person hands for interactions (owner only).
var fp_hands: FpHands
var _remote_sliding := false
var _last_pos := Vector3.ZERO
var _last_y := 0.0
var _vy_smooth := 0.0
@onready var vitals: PlayerVitals = $Vitals
var grapple: Grapple
var lighter: Lighter
var whip: Whip
## Set by the world for the local player.
var build_mode: BuildMode


func _ready() -> void:
	# Each player needs its own capsule so sliding doesn't resize the other player.
	add_to_group("players")
	_capsule = (collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	collision.shape = _capsule
	spawn_transform = global_transform
	camera.fov = Settings.fov
	camera.far = GraphicsQuality.VIEW_FAR[GraphicsQuality.level(Settings.view_distance)]
	body.visible = false
	grapple = Grapple.new()
	grapple.name = "Grapple"
	grapple.player = self
	grapple.position = Vector3(0.22, -0.2, -0.4)
	camera.add_child(grapple)
	whip = Whip.new()
	whip.name = "Whip"
	whip.player = self
	camera.add_child(whip)
	lighter = Lighter.new()
	lighter.name = "Lighter"
	lighter.player = self
	gun.add_child(lighter)
	# Built after world.gd set our authority, so they'd default to the host's (1):
	# a client's grapple rope and zippo RPCs were refused on every other peer.
	for n: Node in [grapple, whip, lighter]:
		n.set_multiplayer_authority(get_multiplayer_authority())
	rig = DummyRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(Palette.team_color(cliff_id), is_multiplayer_authority() and not GameState.has_flag("--thirdperson"),
			Settings.look if is_multiplayer_authority() else {})
	net.prime()
	rig.stepped.connect(_on_step)
	rig.landed.connect(_on_body_landed)
	if is_multiplayer_authority():
		cigarette = Cigarette.new()
		cigarette.name = "Cigarette"
		cigarette.player = self
		camera.add_child(cigarette)
		fp_hands = FpHands.new()
		fp_hands.name = "FpHands"
		fp_hands.gun = gun
		camera.add_child(fp_hands)
		gun.flourished.connect(act_body)
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
	return _sliding or seated or crewing != null # seated by a campfire (or on a crewed gun) reads as a crouch to others


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


## Footstep: boots on porch boards and floors (structures) or on dirt.
func _on_step(at: Vector3, strength: float) -> void:
	var wood := _on_wood(at)
	var vol := lerpf(-24.0, -14.0, strength) + (-4.0 if is_multiplayer_authority() else 0.0)
	Audio.play_at(&"step_wood" if wood else &"step_dirt", at, vol)
	# Spurs jingle now and then, more often at a run.
	if randf() < 0.08 + 0.1 * strength:
		Audio.play_at(&"spur", at + Vector3.UP * 0.1, vol - 6.0)


## Remote players: landing heard from the body pose (the owner uses real floor contact).
func _on_body_landed(strength: float) -> void:
	if strength < 0.8 or is_multiplayer_authority():
		return
	var at := global_position
	Audio.play_at(&"land_wood" if _on_wood(at) else &"land_dirt", at, lerpf(-10.0, -2.0, strength))


func _on_wood(at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 0.6,
			WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var c: Object = hit["collider"]
	if c is Homestead:
		return true
	return c is CollisionObject3D and ((c as CollisionObject3D).collision_layer & WorldLayout.LAYER_STRUCTURE) != 0


## Owner: act out using something (see DummyActions), in first person and
## on your body for everyone else.
func act(id: StringName, prop: StringName = &"") -> void:
	if id == &"" or not is_multiplayer_authority():
		return
	if fp_hands != null:
		# Reach for what's under the crosshair.
		var from := camera.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 3.5,
				WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE | WorldLayout.LAYER_TRAP)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var target := camera.to_local(hit["position"]) if not hit.is_empty() else Vector3(0.1, -0.25, -0.5)
		fp_hands.play(id, prop, target)
	rig.play_action(id)
	_act_remote.rpc(id)


## Owner: a body-only flourish (the revolver twirl, a reload) others see on
## your body; first person already shows it on the viewmodel.
func act_body(id: StringName) -> void:
	if not is_multiplayer_authority() or not DummyActions.has(id):
		return
	rig.play_action(id)
	if multiplayer.has_multiplayer_peer():
		_act_remote.rpc(id)


@rpc("authority", "call_remote", "unreliable")
func _act_remote(id: StringName) -> void:
	rig.play_action(id)


## What using `target` looks like: [move, prop held]. Empty move = nothing to act.
static func action_for(target: Object) -> Array:
	if target is CropPlot:
		var plot := target as CropPlot
		match plot.growth.stage:
			CropGrowth.Stage.EMPTY:
				return [&"plant", &"seed"]
			CropGrowth.Stage.RIPE:
				return [&"harvest", &"crop"]
		return [&"water", &"water"]
	if target is WaterSource:
		return [&"pump", &""]
	if target is Generator or target is TowerTap: # Waterworks: the breaker lever, the tower tap
		return [&"pump", &""]
	if target is SalvagePile:
		return [&"salvage", &""] if (target as SalvagePile).available else [&"", &""]
	if target is LootDrop:
		return [&"loot", &""]
	if target is StorageChest:
		return [&"chest", &""]
	if target is HouseLedger:
		return [&"ledger", &""]
	if target is GunShop or target is VendorCart:
		return [&"buy", &""]
	if target is WeaponPickup:
		return [&"pickup", &""]
	if target is ZipHandle:
		return [&"zip", &""]
	if target is Turret or target is StructureNode or target is ScaffoldNode:
		return [&"hammer", &""]
	return [&"", &""]


## Remote players: a quick bright flash on the body when they fire.
func flash_body() -> void:
	rig.flash()


func _process(delta: float) -> void:
	# Body animation for everyone: walk with speed, aim with pitch, crouch when sliding.
	var moved := global_position - _last_pos
	_last_pos = global_position
	moved.y = 0.0
	# Your own body uses your real velocity; others are smoothed from how far they
	# moved, since render frames and network/physics ticks don't line up.
	var raw_vel := moved / maxf(delta, 0.0001)
	if is_multiplayer_authority():
		raw_vel = Vector3(velocity.x, 0.0, velocity.z)
	_body_vel = _body_vel.lerp(raw_vel, clampf(delta * (30.0 if is_multiplayer_authority() else 8.0), 0.0, 1.0))
	var speed := _body_vel.length()
	var sliding := (_sliding or seated or crewing != null) if is_multiplayer_authority() else _remote_sliding # Crewed
	var vy := (global_position.y - _last_y) / maxf(delta, 0.0001)
	_last_y = global_position.y
	_vy_smooth = lerpf(_vy_smooth, vy, clampf(delta * 10.0, 0.0, 1.0))
	rig.move_local = global_basis.inverse() * _body_vel
	rig.animate(delta, minf(speed, 12.0), sliding, head.rotation.x, _vy_smooth if not is_on_floor() or not is_multiplayer_authority() else 0.0)
	# Downed: the body topples backwards onto its back (and gets up again).
	_down_k = move_toward(_down_k, 1.0 if is_downed() else 0.0, delta * (2.2 if is_downed() else 1.6))
	var fall := _down_k * _down_k * (3.0 - 2.0 * _down_k)
	rig.rotation.x = fall * PI * 0.5
	rig.position.y = fall * 0.12


func _unhandled_input(event: InputEvent) -> void:
	if crewing != null and (event.is_action_pressed("melee") or event.is_action_pressed("throw_rock") or event.is_action_pressed("smoke")):
		return # Crewed: hands are on the gun
	if event.is_action_pressed("melee") and not GameState.menu_open and not vitals.downed and whip != null:
		whip.lash()
		get_viewport().set_input_as_handled()
		return
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
		gun.look_delta += motion.relative
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * sens * y_sign, -1.5, 1.5)
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not GameState.menu_open \
			and not (build_mode != null and build_mode.menu_open):
		if (event as InputEventMouseButton).pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _mantling:
		return
	if seated or crewing != null:
		# Additions hook: sitting at a campfire (Campfire moves you and stands you up),
		# or in a crewed gun's seat (CrewedTurret places you and aims through your view).
		velocity = Vector3.ZERO
		_update_camera(delta, false)
		return
	if _zip_line != null:
		_ride_zip(delta)
		return
	if _rope != null: # Canyon Expeditions: on the rope winch's chair
		_ride_rope(delta)
		return
	if _haul_t >= 0.0: # Canyon Expeditions: the airship's hook
		_ride_haul(delta)
		return
	_update_trip()
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

	_hop_left = maxf(_hop_left - delta, 0.0)
	if _hop_left <= 0.0:
		hop_stacks = 0
	if not blocked and Input.is_action_just_pressed("jump"):
		if on_floor:
			velocity.y = JUMP_VELOCITY
			Audio.play_at(&"jump", global_position + Vector3.UP, -8.0)
			if _sliding:
				_slide_hop()
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

	var grappling := grapple != null and is_multiplayer_authority() and grapple.physics(delta)
	if grappling:
		pass # the grapple drives velocity this tick
	elif _sliding:
		_process_slide(delta)
	else:
		var target_speed := SPRINT_SPEED * vitals.sprint_mult() if sprinting else WALK_SPEED
		target_speed += SLIDE_HOP_SPEED * hop_stacks
		if cigarette != null:
			target_speed *= cigarette.speed_multiplier()
		target_speed *= Expedition.local_speed_mult() # Canyon Expeditions: a heavy backpack slows you
		if gun.aiming:
			target_speed *= 0.6
		var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
		if _stagger > 0.0:
			accel *= 0.12
		# In the air with no input, keep your momentum (swings, knock-backs).
		if on_floor or wish != Vector3.ZERO:
			var horiz := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * target_speed, accel * delta)
			velocity.x = horiz.x
			velocity.z = horiz.z

	_step_up(delta)
	move_and_slide()
	_update_camera(delta, sprinting)
	_handle_weapon()


func _handle_weapon() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or GameState.menu_open or vitals.downed \
			or (build_mode != null and build_mode.active):
		gun.set_aiming(false)
		gun.trigger_held = false
		return
	gun.set_aiming(Input.is_action_pressed("alt_fire") and not _sliding)
	gun.trigger_held = Input.is_action_pressed("fire")
	var pull := Input.is_action_pressed("fire") if gun.def != null and gun.def.automatic else Input.is_action_just_pressed("fire")
	# Where you were aiming when you pulled: trigger() kicks the view up with the
	# recoil at once, which should push the NEXT shot high, not this one.
	var aim_from := camera.global_position
	var aim_dir := -camera.global_transform.basis.z
	if pull and gun.trigger(camera):
		net.fire(aim_from, aim_dir)
		kick_back(gun.def.kickback)
	if Input.is_action_just_pressed("reload"):
		gun.reload()


# ------------------------------------------------------------------ steps

## Tallest ledge you walk straight up without jumping (porch steps, thresholds,
## trap bases).
const STEP_HEIGHT := 0.36


## Walking into a low ledge: lift onto it instead of getting stuck against it.
func _step_up(delta: float) -> void:
	if not is_on_floor() or _sliding:
		return
	var h := Vector3(velocity.x, 0.0, velocity.z) * delta
	if h.length() < 0.001:
		return
	# Look a little further ahead than one tick so slow walking still steps.
	var probe := h.normalized() * maxf(h.length(), 0.25)
	if not test_move(global_transform, probe):
		return
	# How tall is the ledge? Drop a probe onto it from step height.
	var hit := KinematicCollision3D.new()
	var over := global_transform.translated(Vector3.UP * STEP_HEIGHT + probe)
	if not test_move(over, Vector3.DOWN * STEP_HEIGHT, hit):
		return
	var rise := STEP_HEIGHT - hit.get_travel().length() + 0.02
	if rise < 0.03 or rise > STEP_HEIGHT or hit.get_normal().y < 0.3:
		return
	# Room to stand up there? (only as high as the step itself, so low roofs are fine)
	var up := Vector3.UP * rise
	if test_move(global_transform, up) or test_move(global_transform.translated(up), probe):
		return # a wall, not a step
	global_position += up


# ------------------------------------------------------------------ slide

## Slide-hop chain: how many stacks of bonus speed are active, and for how long.
var hop_stacks := 0
var _hop_left := 0.0


func _slide_hop() -> void:
	hop_stacks = mini(hop_stacks + 1, SLIDE_HOP_MAX)
	_hop_left = SLIDE_HOP_TIME
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var dir := horiz.normalized() if horiz.length() > 0.1 else -transform.basis.z
	velocity += dir * SLIDE_HOP_KICK
	add_shake(0.08 * hop_stacks)


func _start_slide() -> void:
	_sliding = true
	Audio.play_at(&"slide", global_position, -6.0)
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
		# Swinging or reeling on the grapple dips below the lip: that's not a fall.
		# Nor is anything on a canyon expedition (you went down on purpose).
		if global_position.y < WorldLayout.CANYON_FALL_Y and not (grapple != null and grapple.is_active()) and not _trip and not ExpeditionApi.debug_floor:
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


## Debug/tests: take out the grapple launcher (hotbar slot 9).
func hotbar_use_grapple() -> void:
	gun.hold_item(&"grapple")


# ------------------------------------------------------------------ zip line

const ZIP_SPEED := 22.0
const ZIP_HANG := 1.9
var _zip_line: ZipLine
var _zip_t := 0.0
var _zip_dir := 1.0
var _zip_speed := 0.0
var _zip_land := Vector3.ZERO


## Grab the trolley and slide to the far tower (jump lets go mid-way).
func start_zip(line: ZipLine, from_west: bool, land: Vector3) -> void:
	_zip_line = line
	_zip_dir = 1.0 if from_west else -1.0
	_zip_t = 0.0 if from_west else 1.0
	_zip_speed = 4.0
	_zip_land = land
	_end_slide()
	Audio.play_at(&"zip_start", global_position + Vector3.UP * 2.0, -4.0)


func _ride_zip(delta: float) -> void:
	if not is_instance_valid(_zip_line):
		_zip_line = null # the tower went away mid-ride: drop with the momentum we had
		return
	var length := _zip_line.a.distance_to(_zip_line.b)
	_zip_speed = move_toward(_zip_speed, ZIP_SPEED, 14.0 * delta)
	var before := global_position
	_zip_t += _zip_dir * _zip_speed * delta / maxf(length, 1.0)
	var done := _zip_t <= 0.0 or _zip_t >= 1.0
	_zip_t = clampf(_zip_t, 0.0, 1.0)
	global_position = _zip_line.point(_zip_t) + Vector3.DOWN * ZIP_HANG
	velocity = (global_position - before) / maxf(delta, 0.001)
	var let_go := not GameState.menu_open and Input.is_action_just_pressed("jump") and is_multiplayer_authority()
	if done:
		global_position = _zip_land
		velocity = Vector3.ZERO
		_zip_line = null
		Audio.play_at(&"land_wood", global_position, -4.0)
	elif let_go or not is_instance_valid(_zip_line):
		_zip_line = null # keep the momentum and drop
	_update_camera(delta, false)


func is_ziplining() -> bool:
	return _zip_line != null


## True while dropping into the canyon or lying on its floor.
func is_plummeting() -> bool:
	return _falling or _fall_left >= 0.0


## Hit the canyon floor and waiting to be hauled home (no grapple then).
func is_down_in_canyon() -> bool:
	return _fall_left >= 0.0


## The grapple caught mid-fall: the plummet's off (it starts again if you let
## go still below the lip).
func cancel_fall() -> void:
	if not _falling:
		return
	_falling = false
	_fall_t = 0.0
	fall_intensity = 0.0
	# A late catch at full plummet speed would fling you round the rope.
	velocity = velocity.limit_length(24.0)


func respawn() -> void:
	_rope = null
	_haul_t = -1.0
	_falling = false
	fall_intensity = 0.0
	global_transform = _porch_transform()
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	_end_slide()
	if _trip:
		_trip = false
		_report_trip()
	respawned.emit()


# ------------------------------------------------------------------ Canyon Expeditions

## Owner: on a canyon expedition: went below the lip on purpose (the rope, or
## the grapple in the build phase), so the canyon fall doesn't haul you home.
var _trip := false
var _reported_down := false
var _rope: RopeAnchor
var _rope_down := true
var _rope_from := Vector3.ZERO
var _haul_t := -1.0
var _haul_from := Vector3.ZERO


func on_trip() -> bool:
	return _trip


func on_rope() -> bool:
	return _rope != null


func _update_trip() -> void:
	var below := global_position.y < WorldLayout.CANYON_FALL_Y
	if not _trip and below and not _falling and grapple != null and grapple.is_active() 			and GameState.phase == GameState.Phase.BUILD:
		_trip = true # grappled down the wall between waves
	elif _trip and not below and _rope == null and _haul_t < 0.0:
		_trip = false
	_report_trip()


func _report_trip() -> void:
	var down_now := _trip and global_position.y < WorldLayout.CANYON_FALL_Y
	if down_now != _reported_down:
		_reported_down = down_now
		Expedition.report_trip(down_now)


## Owner: take the chair down (from the top) or up (from the floor).
func start_rope(anchor: RopeAnchor, down: bool) -> void:
	if _rope != null or vitals.downed or is_plummeting() or not anchor.begin_ride(down):
		return
	_rope = anchor
	_rope_down = down
	_rope_from = global_position
	if down:
		_trip = true
	_end_slide()
	velocity = Vector3.ZERO
	# Face the wall (going down you watch the rock slide past; up, the lip coming).
	rotation.y = atan2(anchor.inward.x, anchor.inward.z)
	head.rotation.x = -0.35 if down else 0.25
	Audio.play_ui(&"zip_grab", -6.0)


func _ride_rope(delta: float) -> void:
	velocity = Vector3.ZERO
	var p := _rope.progress()
	if p < 0.0:
		# The empty chair's still on its way to you.
		global_position = _rope_from
		_update_camera(delta, false)
		return
	var land := _rope.foot_stand if _rope_down else _rope.top_stand
	var at := _rope.rider_point(_rope.seat_s())
	at = _rope_from.lerp(at, ExpeditionRules.ride_ease(p / 0.08))
	at = at.lerp(land, ExpeditionRules.ride_ease((p - 0.92) / 0.08))
	global_position = at
	if p >= 1.0 or not _rope.busy():
		global_position = land
		_rope = null
		Audio.play_at(&"land_dirt", global_position, -6.0)
	_report_trip()
	_update_camera(delta, false)
	_handle_weapon()


## Owner: hail the airship from the floor (the ready key while you're down).
func hail_airship() -> void:
	if not _trip or _rope != null or _haul_t >= 0.0 or vitals.downed:
		return
	if not Expedition.is_down(get_multiplayer_authority()):
		return
	Economy.notice.emit("You fire a flare at the airship (%d chitin for the haul)..." % ExpeditionRules.AIRSHIP_FARE)
	Expedition.request_hail()


## Owner: the host took the fare: the hook drops, then hauls you up and home.
func start_airship_haul() -> void:
	if _haul_t >= 0.0 or not _trip:
		return
	_haul_t = 0.0
	_haul_from = global_position
	_rope = null
	_haul_fx.rpc(_haul_from)
	Economy.notice.emit("The Lucky Mandible lowers its hook. Hold on!")


func _ride_haul(delta: float) -> void:
	_haul_t += delta
	velocity = Vector3.ZERO
	var lift := maxf(_haul_t - ExpeditionRules.HAIL_WAIT, 0.0) / ExpeditionRules.HAUL_TIME
	global_position = _haul_from + Vector3.UP * 80.0 * lift * lift
	_report_trip()
	_update_camera(delta, false)
	if lift >= 1.0:
		respawn()


## Every peer: the airship's hook line coming down to this player and lifting them.
@rpc("authority", "call_local", "reliable")
func _haul_fx(from: Vector3) -> void:
	var line := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	line.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#C9A66B")
	line.material_override = mat
	line.top_level = true
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	var sky := from + Vector3.UP * 140.0
	var total := ExpeditionRules.HAIL_WAIT + ExpeditionRules.HAUL_TIME
	var tw := line.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(line):
			return
		# The hook drops for HAIL_WAIT seconds, then rides up with the player.
		var drop := clampf(t / ExpeditionRules.HAIL_WAIT, 0.0, 1.0)
		var hook := sky.lerp(global_position + Vector3.UP * 2.1, drop * drop) if t < ExpeditionRules.HAIL_WAIT else global_position + Vector3.UP * 2.1
		var len := maxf(sky.distance_to(hook), 0.1)
		line.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(1, len, 1)), (sky + hook) * 0.5), 0.0, total, total)
	tw.tween_callback(line.queue_free)
	Audio.play_at(&"airship_creak", from + Vector3.UP * 6.0, 0.0)


# ------------------------------------------------------------------ camera feel

var _sway_t := 0.0
## Gun recoil still to ease back down (radians of pitch) and how fast.
var _recoil_back := 0.0
var _recoil_rate := 0.0


## Owner: a shot kicks the view up (and a touch sideways); most of it eases back.
## Shots follow the camera, so fast follow-ups from kicky guns land high.
func add_recoil(pitch_deg: float, yaw_deg: float, recover: float) -> void:
	pitch_deg *= Perks.local_less(&"steady_hand") # Perk: Steady Hand
	yaw_deg *= Perks.local_less(&"steady_hand")
	var up := deg_to_rad(pitch_deg)
	head.rotation.x = clampf(head.rotation.x + up, -1.5, 1.5)
	rotate_y(deg_to_rad(randf_range(-yaw_deg, yaw_deg)))
	_recoil_back += up * 0.75
	_recoil_rate = _recoil_back / maxf(recover, 0.05)


## 0..1: how far the body has gone over onto its back (downed).
var _down_k := 0.0


func _update_camera(delta: float, sprinting: bool) -> void:
	var eye := EYE_SLIDE if _sliding else EYE_STAND
	if seated or crewing != null: # Crewed
		eye = EYE_SEATED
	# On your back: the view drops to the ground, looking up at the sky.
	eye = lerpf(eye, 0.35, _down_k)
	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and not _sliding and speed > 0.5:
		_bob_t += delta * speed * 1.6
	var bob := sin(_bob_t) * 0.035 * clampf(speed / SPRINT_SPEED, 0.0, 1.0)
	# Landing: the view dips and springs back.
	if is_on_floor() and not _feel_floor and _feel_vy < -4.0:
		var hard := clampf((-_feel_vy - 4.0) / 10.0, 0.0, 1.0)
		_cam_land_vel -= 0.6 + hard * 1.6
		gun.land(0.3 + hard * 0.7)
		Audio.play_at(&"land_wood" if _on_wood(global_position) else &"land_dirt", global_position, lerpf(-10.0, -2.0, hard))
	_feel_floor = is_on_floor()
	_feel_vy = velocity.y
	_cam_land_vel += (-_cam_land * 110.0 - _cam_land_vel * 13.0) * delta
	_cam_land += _cam_land_vel * delta
	gun.feel(speed, sprinting, is_on_floor(), _sliding, delta)
	head.position.y = lerpf(head.position.y, eye + bob, clampf(delta * 14.0, 0.0, 1.0))
	camera.position.y = _cam_land * 0.08
	camera.rotation.x = (-fp_hands.dip if fp_hands != null else 0.0) + _down_k * 0.9 # downed: staring up
	# Hungry or thirsty: a slow, slight wander in your aim (shots follow the camera).
	var sway := vitals.sway() if vitals != null else 0.0
	_sway_t += delta
	if _recoil_back > 0.0:
		var down := minf(_recoil_back, _recoil_rate * delta)
		_recoil_back -= down
		head.rotation.x = clampf(head.rotation.x - down, -1.5, 1.5)
	camera.rotation.x += sin(_sway_t * 0.9) * cos(_sway_t * 0.37) * 0.006 * sway
	camera.rotation.y = sin(_sway_t * 0.63 + 1.3) * 0.008 * sway
	var target_fov := Settings.fov
	if _sliding:
		target_fov += 12.0
	elif sprinting:
		target_fov += 7.0
	target_fov += 2.5 * hop_stacks # slide-hop momentum widens the view a touch
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


## The Punt Gun's kick: shoved back along your aim, stumbling for a moment so
## your feet don't simply cancel it.
func kick_back(kickback: float) -> void:
	if kickback <= 0.0 or not is_multiplayer_authority():
		return
	velocity += GunRules.kick_velocity(-camera.global_transform.basis.z, kickback)
	_stagger = maxf(_stagger, 0.4)
	rig.knock(camera.global_transform.basis.z, 0.6)


## Local player: shake the camera (0..1).
func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)
