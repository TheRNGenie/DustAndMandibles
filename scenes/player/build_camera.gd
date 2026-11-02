class_name BuildCamera
extends Camera3D
## Build mode's raised view (Tab): an over-the-shoulder camera lifted above and
## behind your rider, looking where you look, so you can judge how a turret
## will sit against the far cliff. The build ghost aims through its crosshair.
## Leaving build mode (or Tab again) drops you back into first person.

const BACK := 6.0
const UP := 3.4
const SIDE := 0.9
## Extra look-down so the plateau edge and the far wall share the frame.
const TILT := 0.2
const BLEND := 10.0

var player: Player
var raised := false
## Body parts the first-person rig draws as shadows only, shown while raised.
var _shadow_parts: Array[GeometryInstance3D] = []
var _hidden: Array[Node3D] = []


func _ready() -> void:
	top_level = true
	current = false
	if GameState.has_flag("--raisedview"):
		# Debug (screenshots): start in the raised view once build mode is up.
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if player != null and player.build_mode != null and player.build_mode.active:
				set_raised(true))


func set_raised(on: bool) -> void:
	if on == raised or player == null:
		return
	raised = on
	if on:
		fov = player.camera.fov
		far = player.camera.far
		global_transform = _target()
		current = true
		_show_body(true)
	else:
		current = false
		player.camera.current = true
		_show_body(false)
	Audio.play_ui(&"rustle", -10.0)


## Where the camera wants to be: up, back and a little to the right of the eye.
func _target() -> Transform3D:
	var cam := player.camera
	var b := cam.global_basis.orthonormalized()
	var flat_fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	if flat_fwd.length_squared() < 0.01:
		flat_fwd = -player.global_basis.z
	var right := flat_fwd.cross(Vector3.UP).normalized()
	var eye := cam.global_position
	var want := eye - flat_fwd * BACK + Vector3.UP * UP + right * SIDE
	# Don't sink into walls or the house: stop just short of whatever's in the way.
	var q := PhysicsRayQueryParameters3D.create(eye, want, WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = eye + (Vector3(hit["position"]) - eye) * 0.85
	var look := b.rotated(right, -TILT)
	return Transform3D(look, want)


func _process(delta: float) -> void:
	if not raised or player == null:
		return
	if not player.build_mode.active or player.is_downed():
		set_raised(false)
		return
	var t := _target()
	global_position = global_position.lerp(t.origin, clampf(delta * BLEND, 0.0, 1.0))
	global_basis = t.basis
	fov = player.camera.fov


func _show_body(on: bool) -> void:
	# The rigged body folds its head away in first person: unfold it while raised.
	var model: Object = player.rig.get("_model") if player.rig != null else null
	if model != null and is_instance_valid(model) and model.get("_first_person") != null:
		model.set("_first_person", not on)
	if on:
		_shadow_parts.clear()
		_hidden.clear()
		if player.rig != null:
			for n: Node in player.rig.find_children("*", "GeometryInstance3D", true, false):
				var g := n as GeometryInstance3D
				if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					_shadow_parts.append(g)
		# First-person props hang off the eye camera: they'd float in the raised view.
		for c: Node in player.camera.get_children():
			var n3 := c as Node3D
			if n3 != null and n3.visible:
				n3.visible = false
				_hidden.append(n3)
	else:
		for g in _shadow_parts:
			if is_instance_valid(g):
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for n3 in _hidden:
			if is_instance_valid(n3):
				n3.visible = true
		_shadow_parts.clear()
		_hidden.clear()
