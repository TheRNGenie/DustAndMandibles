class_name BuildCamera
extends Camera3D
## Build mode's third-person camera (Tab, rebindable): pulled back about 4 m
## behind and above your rider, looking where you look, so you see your own
## dummy and can judge how a turret will sit against the far cliff. The build
## ghost aims through its crosshair. It rides on a spring arm: a sphere swept
## from your eye that stops short of rock, walls and the house, so it never
## clips inside them, and eases back out once the way is clear. Leaving build
## mode drops you back into first person. Settings.build_cam_third remembers
## which view you like (Settings > Controls > Build Camera).

## Extra look-down so the plateau edge and the far wall share the frame.
const TILT := 0.15
## The spring arm's probe: a sphere this big must fit where the camera sits.
const PROBE_RADIUS := 0.3

var player: Player
var raised := false
## Current spring-arm length (shortened by whatever's in the way).
var _arm := 0.0
## Body parts the first-person rig draws as shadows only, shown while raised.
var _shadow_parts: Array[GeometryInstance3D] = []
var _hidden: Array[Node3D] = []


## Full arm length, about 4 m (BuildCamArm holds the spring-arm maths).
static func full_arm() -> float:
	return BuildCamArm.full_arm()


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
		_arm = 0.0
		global_transform = _target(0.0)
		current = true
		_show_body(true)
	else:
		current = false
		player.camera.current = true
		_show_body(false)
	Audio.play_ui(&"rustle", -10.0)


## Where the camera sits this frame: on the spring arm behind your eye.
func _target(delta: float) -> Transform3D:
	var cam := player.camera
	var b := cam.global_basis.orthonormalized()
	var flat_fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	if flat_fwd.length_squared() < 0.01:
		flat_fwd = -player.global_basis.z
	var right := flat_fwd.cross(Vector3.UP).normalized()
	var eye := cam.global_position
	var dir := BuildCamArm.arm_dir(flat_fwd)
	var full := full_arm()
	# Sweep a sphere out along the arm; stop where it would touch rock or a build.
	var probe := SphereShape3D.new()
	probe.radius = PROBE_RADIUS
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.transform = Transform3D(Basis(), eye)
	q.motion = dir * full
	q.collision_mask = WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE
	q.exclude = [player.get_rid()]
	var free := 1.0
	var space := player.get_world_3d().direct_space_state
	var res := space.cast_motion(q)
	if res.size() >= 1:
		free = float(res[0])
	_arm = BuildCamArm.arm_length(full, free, _arm, delta)
	var look := b.rotated(right, -TILT)
	return Transform3D(look, eye + dir * _arm)


func _process(delta: float) -> void:
	if not raised or player == null:
		return
	if not player.build_mode.active or player.is_downed():
		set_raised(false)
		return
	global_transform = _target(delta)
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
