class_name Grapple
extends Node3D
## The grappling hook launcher every player carries (hotbar slot 9).
##   Left click:  fire the hook at what you're aiming at and get reeled in fast.
##   Hold right:  hook on and swing from that point on a fixed-length rope;
##                let go of the button to drop off with your momentum.
## Jump also lets go. Runs on the owning peer; other peers see the rope through
## a small RPC. Doesn't work while you're already plummeting into the canyon.

const RANGE := 60.0
const PULL_SPEED := 26.0
const PULL_ACCEL := 90.0
const PULL_MAX_TIME := 2.5
const ARRIVE_DIST := 2.2
## Shortest rope you can swing on (so you don't wrap around the anchor).
const MIN_ROPE := 2.0
const COOLDOWN := 0.35
const SWING_EXTRA_GRAVITY := 1.2
const MASK := WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE

enum Mode { NONE, PULL, SWING }

var player: Player
## Automated tests drive the grapple without a captured mouse.
var test_mode := false
var mode: Mode = Mode.NONE
var anchor := Vector3.ZERO
var _rope_len := 0.0
var _pull_t := 0.0
var _cd := 0.0
var _rope: MeshInstance3D
var _hook: MeshInstance3D
## Rope shown for a remote player (anchor), or empty.
var _remote_anchor: Variant = null


func _ready() -> void:
	_rope = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	_rope.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#B8955A")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope.material_override = mat
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)
	_hook = MeshInstance3D.new()
	_hook.mesh = WeaponBuilder.grapple_hook()
	_hook.material_override = Materials.toon(0.01)
	_hook.top_level = true
	_hook.visible = false
	add_child(_hook)


func is_active() -> bool:
	return mode != Mode.NONE


func _holding() -> bool:
	return player.gun.holding == &"grapple"


## Called by Player._physics_process (owner only) after normal movement maths
## and before move_and_slide. Returns true when it took over the velocity.
func physics(delta: float) -> bool:
	_cd = maxf(_cd - delta, 0.0)
	var can_use := _holding() and not GameState.menu_open and not player.is_downed() \
			and not player.is_plummeting() and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or test_mode)
	if not can_use:
		_release()
		return false
	if mode == Mode.NONE and _cd <= 0.0:
		if Input.is_action_just_pressed("fire"):
			_launch(Mode.PULL)
		elif Input.is_action_just_pressed("alt_fire"):
			_launch(Mode.SWING)
	match mode:
		Mode.PULL:
			return _pull(delta)
		Mode.SWING:
			return _swing(delta)
	return false


## Tests: hook straight onto `point`.
func attach(new_mode: Mode, point: Vector3) -> void:
	anchor = point
	mode = new_mode
	_pull_t = 0.0
	_rope_len = maxf((player.global_position + Vector3.UP * 0.9).distance_to(anchor), MIN_ROPE)
	_show_rope.rpc(anchor)


func _launch(new_mode: Mode) -> void:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	Audio.play_at(&"harpoon", from, -6.0)
	_cd = COOLDOWN
	if hit.is_empty():
		Economy.notice.emit("Nothing to hook onto there (range %d m)." % int(RANGE))
		return
	anchor = hit["position"]
	mode = new_mode
	_pull_t = 0.0
	_rope_len = maxf(player.global_position.distance_to(anchor), MIN_ROPE)
	Audio.play_at(&"reload", anchor, -4.0)
	_show_rope.rpc(anchor)


func _pull(delta: float) -> bool:
	_pull_t += delta
	var to := anchor - (player.global_position + Vector3.UP * 0.9)
	if to.length() < ARRIVE_DIST or _pull_t > PULL_MAX_TIME or Input.is_action_just_pressed("jump"):
		# Arrive with a little hop so you land on top of ledges.
		# Keep some of the flight's momentum, so a pull carries you over a rim.
		var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
		player.velocity = flat * 0.5 + Vector3.UP * 4.5
		_release()
		return true
	var want := to.normalized() * PULL_SPEED
	player.velocity = player.velocity.move_toward(want, PULL_ACCEL * delta)
	return true


func _swing(delta: float) -> bool:
	if not Input.is_action_pressed("alt_fire") or Input.is_action_just_pressed("jump"):
		# Let go: keep the momentum, with a small upward pop if jumping.
		if Input.is_action_just_pressed("jump"):
			player.velocity.y += 3.0
		_release()
		return false
	# Snappier, game-feel swings: extra pull downward while on the rope, so long
	# ropes don't swing in slow motion.
	player.velocity.y -= 9.8 * SWING_EXTRA_GRAVITY * delta
	# Gravity and air control already ran; now keep the rope taut.
	var pos := player.global_position + Vector3.UP * 0.9
	var off := pos - anchor
	var dist := off.length()
	# Where this tick's velocity would take us; if that's past the rope's length,
	# steer onto the circle instead, keeping the speed (so swings don't bleed
	# energy and you can actually make it across).
	var next := pos + player.velocity * delta
	var off2 := next - anchor
	if off2.length() > _rope_len and dist > 0.001:
		var proj := anchor + off2.normalized() * _rope_len
		var steer := (proj - pos) / maxf(delta, 0.001)
		var speed := player.velocity.length()
		player.velocity = steer.normalized() * speed if steer.length() > 0.001 else steer
	# Forward/back pumps the swing a little.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input != Vector2.ZERO:
		var wish := (player.transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
		player.velocity += wish * 6.0 * delta
	return true


func _release() -> void:
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	_show_rope.rpc(null)


@rpc("authority", "call_local", "unreliable_ordered")
func _show_rope(point: Variant) -> void:
	_remote_anchor = point


func _process(_delta: float) -> void:
	var on := _remote_anchor != null
	_rope.visible = on
	_hook.visible = on
	if not on:
		return
	var a: Vector3 = _remote_anchor
	var from := global_position
	var v := a - from
	var length := v.length()
	if length < 0.05:
		_rope.visible = false
		return
	_rope.global_transform = Transform3D(MeshKit.basis_from_y(v / length) * Basis.from_scale(Vector3(1, length, 1)), (from + a) * 0.5)
	_hook.global_transform = Transform3D(MeshKit.basis_from_y(v / length), a)
