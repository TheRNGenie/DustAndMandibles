extends RefCounted
## The warning before a big bug leaves its tunnel: dust boils out of the mouth for
## a few seconds and the ground rumbles. One emitter per warning (only brutes and
## the boss get one), freed once the dust settles.
## Load with preload("res://scenes/bugs/tunnel_rumble.gd").

const PUFF_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void vertex() {
	// Face the camera, keep the particle's own scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * smoothstep(1.0, 0.35, d);
}
"""

static var _mesh: QuadMesh
static var _process: ParticleProcessMaterial


## Dust at `mouth` (a tunnel whose bugs come out along `way_out`) for `seconds`; bigger bugs, more dust.
static func play(parent: Node, mouth: Vector3, way_out: Vector3, size: float, seconds: float) -> void: # Maps: direction, not wall
	if parent == null or not parent.is_inside_tree():
		return
	_ensure()
	var e := GPUParticles3D.new()
	e.amount = clampi(int(24.0 * size), 24, 72)
	e.lifetime = 1.8
	e.local_coords = false
	e.process_material = _process
	e.draw_pass_1 = _mesh
	e.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	parent.add_child(e)
	# Emitters spray along local -Z: point it out of the tunnel, into the canyon.
	var out := Vector3(way_out.x, 0.35, way_out.z).normalized()
	e.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP), mouth + Vector3(0, 1.2, 0))
	e.emitting = true
	Audio.play_at(&"thunder", mouth, -6.0)
	var tree := parent.get_tree()
	tree.create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(e):
			e.emitting = false)
	tree.create_timer(seconds + e.lifetime + 0.2).timeout.connect(func() -> void:
		if is_instance_valid(e):
			e.queue_free())


static func _ensure() -> void:
	if _mesh != null:
		return
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PUFF_SHADER
	mat.shader = sh
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(1.4, 1.4)
	_mesh.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.0, 1.2, 0.6)
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 35.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 2.2))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var grad := Gradient.new()
	var dust := Palette.SAND.darkened(0.15)
	grad.set_color(0, Color(dust, 0.85))
	grad.set_color(1, Color(dust.lightened(0.2), 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	_process = pm
