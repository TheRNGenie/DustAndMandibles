class_name Lighter
extends Node3D
## The Zippo every player carries (hotbar slot 0).
##   Right click: flip the lid open or snap it shut (shutting puts the flame out).
##   Left click:  with the lid open, strike the wheel to light it (again to blow it out).
## A lit lighter is a little lantern: it lights the dark and the fog around you,
## turrets near it see as if a lantern stood there, and bugs near it can be seen
## by turrets through fog and dust. Owner drives it; every peer sees the flame.

const LIGHT_RANGE := 11.0
## Turrets within this distance of a lit lighter shrug off fog and most dust.
const TURRET_RADIUS := 14.0
## Bugs within this distance of a lit lighter can be targeted at full range.
const REVEAL_RADIUS := 10.0
const LID_SPEED := 9.0

var player: Player
var is_open := false
var lit := false
var _lid_t := 0.0
var _t := 0.0
var _model: Node3D
var _lid: Node3D
var _flame: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	_model = Node3D.new()
	_model.position = Vector3(0.012, -0.085, -0.035)
	_model.scale = Vector3.ONE * 1.35
	_model.rotation = Vector3(0.15, -0.35, 0.05)
	add_child(_model)
	var mat := Materials.toon(0.004)
	var body := MeshInstance3D.new()
	body.mesh = WeaponBuilder.zippo_body()
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(body)
	_lid = Node3D.new()
	_lid.position = WeaponBuilder.ZIPPO_HINGE
	_model.add_child(_lid)
	var lid := MeshInstance3D.new()
	lid.mesh = WeaponBuilder.zippo_lid()
	lid.material_override = mat
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lid.add_child(lid)
	_flame = MeshInstance3D.new()
	_flame.mesh = WeaponBuilder.zippo_flame()
	_flame.material_override = Materials.toon(0.0)
	_flame.position = WeaponBuilder.ZIPPO_WICK
	_flame.visible = false
	_model.add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = Color("#FFB45A")
	_light.light_energy = 0.0
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	# Ahead of the hand, so the arm and the lighter itself aren't blown out.
	_light.position = Vector3(-0.1, 0.35, -1.1)
	add_child(_light)
	visible = false


func _holding() -> bool:
	return player.gun.holding == &"lighter"


func _process(delta: float) -> void:
	_t += delta
	var mine := player.is_multiplayer_authority()
	var holding := _holding()
	# The first-person model only for the owner; the glow for everyone.
	_model.visible = mine and holding
	visible = true
	if mine:
		if not holding and (is_open or lit):
			_set_state.rpc(false, false)
		elif holding and not GameState.menu_open and not player.is_downed() \
				and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.grapple.test_mode):
			if Input.is_action_just_pressed("alt_fire"):
				_set_state.rpc(not is_open, false)
			elif Input.is_action_just_pressed("fire") and is_open:
				_set_state.rpc(true, not lit)
	# Lid swings open on its hinge; the flame flickers; the light breathes.
	_lid_t = move_toward(_lid_t, 1.0 if is_open else 0.0, delta * LID_SPEED)
	var e := _lid_t * _lid_t * (3.0 - 2.0 * _lid_t)
	_lid.rotation.x = e * 2.2
	_flame.visible = lit
	if lit:
		var f := 1.0 + sin(_t * 23.0) * 0.08 + sin(_t * 37.0) * 0.06
		_flame.scale = Vector3(1.0, f, 1.0)
		_light.light_energy = 1.3 + sin(_t * 17.0) * 0.12 + sin(_t * 41.0) * 0.08
	else:
		_light.light_energy = 0.0


@rpc("authority", "call_local", "reliable")
func _set_state(open_lid: bool, flame: bool) -> void:
	if open_lid != is_open:
		Audio.play_at(&"zippo_open" if open_lid else &"zippo_close", global_position, -6.0)
	if flame and not lit:
		Audio.play_at(&"zippo_strike", global_position, -6.0)
	is_open = open_lid
	lit = flame and open_lid
	if lit:
		add_to_group("lanterns")
	elif is_in_group("lanterns"):
		remove_from_group("lanterns")


## Breachers surface near lanterns; a lit lighter counts as a small one.
func reveal_radius() -> float:
	return REVEAL_RADIUS


## Debug/tests: open and light it.
func debug_light() -> void:
	_set_state(true, true)
