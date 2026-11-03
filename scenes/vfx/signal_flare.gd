class_name SignalFlare
extends Node3D
## A burning signal flare (the Signal Flare Gun): a hot red-pink star that
## sputters sparks and lights the ground round it for GunRules.MARK_TIME.
## Stuck on a marked bug it rides along; landed on rock it burns where it lies;
## fired into the sky it hangs and sinks slowly. Every peer makes its own (the
## host sends where). It counts as a lantern: turrets see through dust storms
## and the dark near it (Turret._lit_near).

var life := GunRules.MARK_TIME
## Metres a second it sinks (fired into open sky: a parachute flare).
var sink := 0.0
var _light: OmniLight3D
var _star: MeshInstance3D
var _sparks: GPUParticles3D
var _t := 0.0
static var _star_mat: Material


static func make(seconds: float) -> SignalFlare:
	var f := SignalFlare.new()
	f.life = seconds
	return f


func _ready() -> void:
	add_to_group("lanterns")
	_light = OmniLight3D.new()
	_light.light_color = Color("#FF5A48")
	_light.light_energy = 4.0
	_light.omni_range = GunRules.FLARE_LIGHT_RADIUS
	_light.omni_attenuation = 0.8
	_light.shadow_enabled = false
	add_child(_light)
	if _star_mat == null:
		_star_mat = Materials.star(Color("#FF6A50"), 4.0)
	_star = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	quad.material = _star_mat
	_star.mesh = quad
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_star)
	_sparks = GPUParticles3D.new()
	_sparks.amount = 24
	_sparks.lifetime = 0.7
	_sparks.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color("#FFC890")
	_sparks.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.08, 0.08)
	dot.material = _star_mat
	_sparks.draw_pass_1 = dot
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


## For Turret._lit_near and the bugs that shy from light: how far it shows things.
func reveal_radius() -> float:
	return GunRules.FLARE_LIGHT_RADIUS


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	if sink > 0.0:
		global_position.y -= sink * delta
	# Sputter, and gutter out over the last second.
	var fade := clampf(life - _t, 0.0, 1.0)
	var flick := 0.8 + 0.2 * sin(_t * 31.0) * sin(_t * 17.0)
	_light.light_energy = 4.0 * flick * fade
	_star.scale = Vector3.ONE * (0.75 + 0.35 * flick) * maxf(fade, 0.2)
	_sparks.emitting = fade > 0.3
