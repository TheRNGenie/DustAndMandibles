class_name Whip
extends Node3D
## Quick melee: a bullwhip in the left hand (key Z or the mouse thumb button).
## Each lash picks one of three swings at random (never the same twice running):
## an overhead crack, a sidearm sweep and a backhand flick. The lash is a chain
## of segments that unfurls behind the handle and snaps at the tip, with one of
## three crack sounds. Bugs within reach in front of you take a hit and are
## stunned for a moment (the host resolves it). Lives under the camera; the
## owner plays it, everyone hears it.

const REACH := 6.5
const CONE_DEG := 38.0
const DAMAGE := 22.0
const STUN := 0.5
const COOLDOWN := 0.7
const SWING_TIME := 0.42
const SEGMENTS := 14
const SEG_LEN := 0.32

var player: Player
var _cd := 0.0
var _t := -1.0
var _move := 0
var _last := -1
var _hit_done := false
var _hand: MeshInstance3D
var _segs: Array[MeshInstance3D] = []


func _ready() -> void:
	var mat := Materials.toon(0.006)
	_hand = MeshInstance3D.new()
	var st := MeshKit.begin()
	WeaponBuilder.fist(st, Vector3.ZERO, Vector3(0, 0, -1), Vector3(-1, 0.4, 0), DummyLook.paint(Settings.look))
	# Braided leather handle with a brass cap.
	WeaponBuilder.rod(st, Vector3(0, 0, 0.06), Vector3(0, 0, -0.16), 0.014, 0.012, 8, Color("#5C351D"))
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.07)), 0.017, 0.017, 0.02, 8, Color("#D6A74A"))
	WeaponBuilder.sleeve(st, Vector3(-0.01, -0.03, 0.05), Vector3(-0.09, -0.2, 0.3), Settings.look)
	_hand.mesh = MeshKit.finish(st)
	_hand.material_override = mat
	_hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hand)
	for i in SEGMENTS:
		var mi := MeshInstance3D.new()
		var k := 1.0 - float(i) / SEGMENTS
		var r := 0.004 + 0.009 * k
		var seg := MeshKit.begin()
		# Plaited brown leather, a pale cracker at the very tip.
		var col := Color("#6B4226").lerp(Color("#8A5A34"), float(i % 2)) if i < SEGMENTS - 1 else Color("#E8DCC0")
		MeshKit.add_cylinder(seg, Transform3D(), r, r * 0.9, SEG_LEN, 6, col)
		mi.mesh = MeshKit.finish(seg)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		_segs.append(mi)
	_show(false)


func _show(on: bool) -> void:
	_hand.visible = on
	for s in _segs:
		s.visible = on


func can_lash() -> bool:
	return _cd <= 0.0 and _t < 0.0


## Owner: start a lash (picks the swing, plays the crack, asks the host to hit).
func lash() -> void:
	if not can_lash():
		return
	_cd = COOLDOWN
	_t = 0.0
	_hit_done = false
	var pick := randi() % 3
	if pick == _last:
		pick = (pick + 1 + randi() % 2) % 3
	_move = pick
	_last = pick
	_show(true)


func _process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	if _t < 0.0:
		return
	_t += delta
	var k := _t / SWING_TIME
	if k >= 1.0:
		_t = -1.0
		_show(false)
		return
	_pose(k)
	if not _hit_done and k >= 0.55:
		_hit_done = true
		var cam := player.camera
		player.net.melee(cam.global_position, -cam.global_transform.basis.z, randi() % 3)


## Swing angle of the handle at time k (0..1): wind back, then lash through.
func _handle_angle(k: float) -> float:
	var back := [1.7, 1.5, -1.4][_move] as float
	var through := [-0.45, -0.7, 0.75][_move] as float
	if k < 0.3:
		return lerpf(0.4 * signf(back), back, _ease(k / 0.3))
	return lerpf(back, through, _ease((k - 0.3) / 0.45))


## Axis the swing turns around (camera space): overhead, sidearm, diagonal backhand.
func _axis() -> Vector3:
	match _move:
		0:
			return Vector3.RIGHT
		1:
			return Vector3.UP
	return Vector3(1, 1, 0).normalized()


static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _pose(k: float) -> void:
	# The hand: low left, moving with the swing.
	var a := _handle_angle(k)
	var axis := _axis()
	_hand.position = Vector3(-0.22, -0.2, -0.5) + Basis(axis, a * 0.25) * Vector3(0, 0.05, 0)
	_hand.rotation = Vector3.ZERO
	_hand.basis = Basis(axis, clampf(a, -1.0, 1.0) * 0.28)
	# The lash: each segment follows the handle's angle from a moment ago, so
	# the whip trails behind and then rolls out, snapping straight at the tip.
	var cam_xf := (get_parent() as Node3D).global_transform
	var p := cam_xf * (_hand.position + _hand.basis * Vector3(0, 0, -0.16))
	for i in SEGMENTS:
		var lag := float(i + 1) * 0.035
		var ki := clampf(k - lag / SWING_TIME, 0.0, 1.0)
		var ang := _handle_angle(ki) * (1.0 + float(i) * 0.04)
		var dir_local := (Basis(axis, ang) * Vector3(0, 0, -1)).normalized()
		var dir := (cam_xf.basis * dir_local).normalized()
		var next := p + dir * SEG_LEN
		_segs[i].global_transform = Transform3D(MeshKit.basis_from_y(dir), (p + next) * 0.5)
		p = next


## Host: who did this lash catch? Bugs in front within reach, with a clear line.
static func targets(tree: SceneTree, origin: Vector3, dir: Vector3, exclude: Array[RID]) -> Array[Bug]:
	var out: Array[Bug] = []
	var cos_max := cos(deg_to_rad(CONE_DEG))
	for n: Node in tree.get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden():
			continue
		var to := b.global_position - origin
		var reach := REACH + float(b.spec["body_radius"])
		if to.length() > reach or to.normalized().dot(dir.normalized()) < cos_max:
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, b.global_position, WorldLayout.LAYER_WORLD, exclude)
		if b.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			out.append(b)
	return out
