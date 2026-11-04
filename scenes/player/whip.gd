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
## Level and mods (WeaponMods code); set by the gunsmith.
var code := 0:
	set(value):
		var was_gold := WeaponMods.is_golden(code)
		code = value
		if is_inside_tree() and WeaponMods.is_golden(code) != was_gold:
			_build_look()
var _cd := 0.0
var _t := -1.0
var _move := 0
var _last := -1
var _hit_done := false
## Waiting for the gun to duck out of view before the lash starts (seconds left, -1 = not waiting).
var _wait := -1.0
var _hand: MeshInstance3D
var _segs: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_look()


## (Re)builds the hand, handle and lash: plaited leather, or all gold once gilded.
func _build_look() -> void:
	for c in get_children():
		c.queue_free()
	_segs.clear()
	var gold := WeaponMods.is_golden(code)
	var mat := Materials.toon(0.006)
	_hand = MeshInstance3D.new()
	var st := MeshKit.begin()
	WeaponBuilder.fist(st, Vector3.ZERO, Vector3(0, 0, -1), Vector3(-1, 0.4, 0), DummyLook.paint(Settings.look))
	# Braided leather handle with a brass cap.
	WeaponBuilder.rod(st, Vector3(0, 0, 0.06), Vector3(0, 0, -0.16), 0.014, 0.012, 8, Color("#E8B83A") if gold else Color("#5C351D"))
	if gold:
		# Engraved rings and a ruby in the pommel.
		for z: float in [-0.12, -0.04, 0.03]:
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, z)), 0.016, 0.016, 0.006, 8, Color("#FFF0A0"))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0, 0.085)), Vector3.ONE * 0.012, 3, 6, Color("#E0283C"), 0.0, null, 0.4)
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
		if gold:
			col = Color("#E8B83A").lerp(Color("#FFE27A"), float(i % 2)) if i < SEGMENTS - 1 else Color("#FFF6D0")
		MeshKit.add_cylinder(seg, Transform3D(), r, r * 0.9, SEG_LEN, 6, col, false, 0.25 if gold else 0.0)
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
	return _cd <= 0.0 and _t < 0.0 and _wait < 0.0


## Owner: start a lash (picks the swing, plays the crack, asks the host to hit).
func lash() -> void:
	if not can_lash():
		return
	_cd = COOLDOWN * WeaponMods.mult(&"whip", code, "fire_interval") * (0.8 if WeaponMods.is_golden(code) else 1.0)
	_t = 0.0
	_hit_done = false
	var pick := randi() % 3
	if pick == _last:
		pick = (pick + 1 + randi() % 2) % 3
	_move = pick
	_last = pick
	# The held weapon ducks away first, so the whip hand never makes a third arm.
	_t = -1.0
	_wait = 0.12
	if player != null and player.gun != null:
		player.gun.tuck_for_melee(true)


func _process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	if _wait >= 0.0:
		_wait -= delta
		var ready := _wait <= 0.0 or player == null or player.gun == null or player.gun.is_tucked()
		if ready:
			_wait = -1.0
			_t = 0.0
			_show(true)
		return
	if _t < 0.0:
		return
	_t += delta
	var k := _t / SWING_TIME
	if k >= 1.0:
		_t = -1.0
		_show(false)
		if player != null and player.gun != null:
			player.gun.tuck_for_melee(false)
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
		var stretch := reach_for(code) / REACH
		var next := p + dir * SEG_LEN * stretch
		_segs[i].global_transform = Transform3D(MeshKit.basis_from_y(dir) * Basis.from_scale(Vector3(1.0, stretch * 1.05, 1.0)), (p + next) * 0.5)
		p = next


## Lash stats for a whip code (level and mods).
static func damage_for(c: int) -> float:
	var gold := 1.6 if WeaponMods.is_golden(c) else 1.0
	return DAMAGE * (1.0 + 0.25 * WeaponMods.level(c)) * WeaponMods.mult(&"whip", c, "damage") * gold


static func reach_for(c: int) -> float:
	return REACH * WeaponMods.mult(&"whip", c, "reach") * (1.15 if WeaponMods.is_golden(c) else 1.0)


static func stun_for(c: int) -> float:
	return STUN * WeaponMods.mult(&"whip", c, "stun")


## Host: who did this lash catch? Bugs in front within reach, with a clear line.
static func targets(tree: SceneTree, origin: Vector3, dir: Vector3, exclude: Array[RID], reach_m: float = REACH) -> Array[Bug]:
	var out: Array[Bug] = []
	var cos_max := cos(deg_to_rad(CONE_DEG))
	for n: Node in tree.get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden():
			continue
		var to := b.global_position - origin
		var reach := reach_m + float(b.spec["body_radius"])
		if to.length() > reach or to.normalized().dot(dir.normalized()) < cos_max:
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, b.global_position, WorldLayout.LAYER_WORLD, exclude)
		if b.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			out.append(b)
	return out
