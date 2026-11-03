class_name Grapple
extends Node3D
## The grappling hook launcher every player carries (hotbar slot 9).
##   Hold left:   fire the hook at what you're aiming at and get reeled in fast;
##                let go of the button and the rope lets go at once.
##   Hold right:  hook on and swing from that point on a fixed-length rope;
##                let go of the button to drop off with your momentum. Hold
##                left as well to reel in: the rope shortens and pulls you up it.
## Jump also lets go. Runs on the owning peer; other peers see the rope through
## a small RPC. Catches on anything solid in the world: the canyon walls and
## cliff faces, plateaus, arches, buildings and structures; never bugs or players.
## Works mid-fall too: hook a wall on the way down and the fall's called off.
## Only once you've hit the canyon floor is it out of reach.

## Long enough to reach the opposite canyon wall from your own lip on every map
## (the Mesa and Buttes gaps put it 60-80 m away).
const RANGE := 90.0
const PULL_SPEED := 26.0
const PULL_ACCEL := 90.0
const PULL_MAX_TIME := 2.5
const ARRIVE_DIST := 2.2
## Shortest rope you can swing on (so you don't wrap around the anchor).
const MIN_ROPE := 2.0
## Seconds after a miss or letting go before the hook can fly again (ring on the crosshair).
const COOLDOWN := 0.4
const SWING_EXTRA_GRAVITY := 1.2
## Reeling in while swinging (hold left click): metres of rope per second, and
## the extra pull toward the hook.
const REEL_SPEED := 9.0
const REEL_PULL := 22.0
const MASK := WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE

enum Mode { NONE, PULL, SWING }

var player: Player
## Automated tests drive the grapple without a captured mouse.
var test_mode := false
## Tests: reel in as if left click were held.
var reel_test := false
var mode: Mode = Mode.NONE
var anchor := Vector3.ZERO
var _rope_len := 0.0
var _pull_t := 0.0
## How long this pull may last (long hooks, like the casino's ring, need longer).
var _pull_limit := PULL_MAX_TIME
var _cd := 0.0
var _rope: MeshInstance3D
var _hook: MeshInstance3D
## Harpoon Pistol: a pull started by a harpoon shot (no launcher in hand, no
## button to hold; it runs until you arrive, jump, or time runs out).
var _harpoon := false
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


## For the crosshair: 0 = ready, 1 = just fired.
func cooldown_fraction() -> float:
	return clampf(_cd / COOLDOWN, 0.0, 1.0)


## For the crosshair: the launcher's out and idle (show the ring and range tint).
func aiming() -> bool:
	return player != null and _holding() and mode == Mode.NONE and not player.is_downed()


## For the crosshair: something hookable sits within rope length where you're aiming.
## One ray, at most once a physics tick, only while the launcher's out.
func aim_in_range() -> bool:
	var f := Engine.get_physics_frames()
	if f != _aim_frame:
		_aim_frame = f
		var cam := player.camera
		var from := cam.global_position
		var hit := cast(from, from - cam.global_transform.basis.z * RANGE)
		_aim_ok = not hit.is_empty() and not (Airship.ring_up and _on_airship(hit["collider"] as Node))
	return _aim_ok


var _aim_frame := -1
var _aim_ok := false


## The hook's flight: the first solid thing on the line. Players stand on the
## world layer too, so every player is left out (no hooking your partner).
func cast(from: Vector3, to: Vector3) -> Dictionary:
	var skip: Array[RID] = []
	for p: Node in player.get_tree().get_nodes_in_group("players"):
		if p is CollisionObject3D:
			skip.append((p as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK, skip)
	return player.get_world_3d().direct_space_state.intersect_ray(q)


func _holding() -> bool:
	return player.gun.holding == &"grapple"


## Called by Player._physics_process (owner only) after normal movement maths
## and before move_and_slide. Returns true when it took over the velocity.
func physics(delta: float) -> bool:
	_cd = maxf(_cd - delta, 0.0)
	var can_use := (_holding() or _harpoon) and not GameState.menu_open and not player.is_downed() \
			and not player.is_down_in_canyon() and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or test_mode)
	if not can_use:
		_release()
		return false
	if mode == Mode.NONE and _cd <= 0.0 and _holding():
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
	_pull_limit = maxf(PULL_MAX_TIME, _rope_len / PULL_SPEED * 1.5 + 0.6)
	player.cancel_fall()
	_show_rope.rpc(anchor)


## Harpoon Pistol: the dart bit into rock or a big bug at `point`; reel the
## shooter in to it with the launcher's pull.
func harpoon_pull(point: Vector3) -> void:
	if player.is_down_in_canyon():
		return
	attach(Mode.PULL, point)
	_harpoon = true
	Audio.play_at(&"hook_bite", point, -2.0)


func _launch(new_mode: Mode) -> void:
	var cam := player.camera
	var from := cam.global_position
	var hit := cast(from, from - cam.global_transform.basis.z * RANGE)
	Audio.play_at(&"harpoon", from, -6.0)
	_cd = COOLDOWN
	if hit.is_empty():
		Economy.notice.emit("Nothing to hook onto there (range %d m)." % int(RANGE))
		return
	# The casino ship hauls its ring up during waves: no hooking the ship then.
	if Airship.ring_up and _on_airship(hit["collider"] as Node):
		Economy.notice.emit("The ship's boarding ring is up until the wave is held.")
		return
	anchor = hit["position"]
	mode = new_mode
	_pull_t = 0.0
	# Measured from the same point _swing() keeps on the rope (0.9 m up), as attach() does.
	_rope_len = maxf((player.global_position + Vector3.UP * 0.9).distance_to(anchor), MIN_ROPE)
	_pull_limit = maxf(PULL_MAX_TIME, _rope_len / PULL_SPEED * 1.5 + 0.6)
	Audio.play_at(&"hook_bite", anchor, -2.0)
	# Hooked on the way down into the canyon: the rope's got you, no more fall.
	player.cancel_fall()
	_show_rope.rpc(anchor)


static func _on_airship(n: Node) -> bool:
	while n != null:
		if n is Airship:
			return true
		n = n.get_parent()
	return false


func _pull(delta: float) -> bool:
	_pull_t += delta
	# Let go of the button: the rope lets go at once, and you keep your speed.
	if not test_mode and not _harpoon and not Input.is_action_pressed("fire"):
		_release()
		return false
	var to := anchor - (player.global_position + Vector3.UP * 0.9)
	# Hooked the casino ship's boarding ring: step over the rail onto the deck.
	if to.length() < ARRIVE_DIST + 0.5 and anchor.distance_to(Airship.ring_position()) < 2.0:
		var ship := player.get_tree().current_scene.get_node_or_null("Airship") as Node3D
		if ship != null:
			player.global_position = ship.to_global(Vector3(0, 0.3, AirshipBuilder.DECK_L * 0.5 - 1.2))
			player.velocity = Vector3.ZERO
			_release()
			return true
	if to.length() < ARRIVE_DIST or _pull_t > _pull_limit or Input.is_action_just_pressed("jump"):
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
	# Holding left click as well reels you in: a shorter rope and a tug up it.
	var reeling := Input.is_action_pressed("fire") or reel_test
	if reeling:
		_rope_len = maxf(_rope_len - REEL_SPEED * delta, MIN_ROPE)
		var up_rope := (anchor - (player.global_position + Vector3.UP * 0.9)).normalized()
		player.velocity += up_rope * REEL_PULL * delta
	else:
		# Snappier, game-feel swings: extra pull downward while on the rope, so
		# long ropes don't swing in slow motion.
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
	_harpoon = false
	if mode == Mode.NONE:
		return
	mode = Mode.NONE
	_cd = COOLDOWN
	_show_rope.rpc(null)


# Reliable: it's a one-shot state change (hooked / let go). Unreliable could drop
# the "let go" and leave the rope hanging on the partner's screen.
@rpc("authority", "call_local", "reliable")
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
