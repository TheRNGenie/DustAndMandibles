class_name ViewModel
extends Node3D
## One first-person gun with its moving parts and both hands, posed every frame
## by Gun from a few numbers (how far into the reload posture, progress of the
## round being loaded, the lever cycle, the cylinder angle). Reloads follow
## Hunt: Showdown's rhythm: the gun tips over, the support hand fetches one
## round at a time and thumbs it home, and you can fire between rounds.
##   revolver:  tilt left to the loading gate; a cartridge per chamber; the
##              cylinder clicks round one chamber each time.
##   lever rifle: roll right to the side gate; rounds pushed in one by one; the
##              lever is worked after every shot.
##   shotgun:   barrels drop open, the empties fly, two shells go in, snap shut.

var id: StringName
var drum: MeshInstance3D
var lever: Node3D
var barrels: Node3D
var left: Node3D
var _right_mi: MeshInstance3D
var _left_mi: MeshInstance3D
var _round: MeshInstance3D
var _flyer: MeshInstance3D
var _mat: Material
var _team: Color


func build(weapon_id: StringName, team: Color, look: Dictionary, mat: Material) -> void:
	id = weapon_id
	_mat = mat
	_team = team
	var body := _mi(self, null)
	match id:
		&"revolver":
			body.mesh = WeaponBuilder.revolver_body()
			drum = _mi(self, WeaponBuilder.revolver_drum())
			drum.position = Vector3(0, 0.018, -0.005)
		&"lever_rifle":
			body.mesh = WeaponBuilder.rifle_body()
			lever = Node3D.new()
			lever.position = WeaponBuilder.LEVER_PIVOT
			add_child(lever)
			_mi(lever, WeaponBuilder.rifle_lever())
		_:
			body.mesh = WeaponBuilder.shotgun_action()
			barrels = Node3D.new()
			barrels.position = WeaponBuilder.HINGE
			add_child(barrels)
			_mi(barrels, WeaponBuilder.shotgun_barrels())
	_right_mi = _mi(self, null)
	left = Node3D.new()
	left.position = WeaponBuilder.LEFT_FIST[id]
	add_child(left)
	_left_mi = _mi(left, null)
	_round = _mi(left, WeaponBuilder.shell() if id == &"coach_shotgun" else WeaponBuilder.cartridge())
	_round.position = Vector3(0.012, 0.02, -0.02)
	_round.visible = false
	if id == &"lever_rifle":
		_flyer = MeshInstance3D.new()
		_flyer.mesh = WeaponBuilder.cartridge()
		_flyer.material_override = _mat
		_flyer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flyer.visible = false
		add_child(_flyer)
	set_look(look)


func set_look(look: Dictionary) -> void:
	_right_mi.mesh = WeaponBuilder.arm_right(id, look)
	_left_mi.mesh = WeaponBuilder.arm_left(id, look, true)


func _mi(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## open: 0 = held normally, 1 = in the reload posture. load_t: progress of the
## round going in (only while `loading`). cycle: lever stroke 0..1 (1 = closed).
func pose(open: float, load_t: float, loading: bool, cycle: float, drum_angle: float, round_index: int = 0,
		catch_t: float = -1.0) -> void:
	var e := _ease(open)
	match id:
		&"revolver":
			transform = Transform3D(Basis.from_euler(Vector3(0.35 * e, 0.3 * e, 0.95 * e)), Vector3(-0.07, 0.06, 0.04) * e)
		&"lever_rifle":
			transform = Transform3D(Basis.from_euler(Vector3(0.22 * e, -0.15 * e, -0.8 * e)), Vector3(-0.02, 0.07, 0.07) * e)
		_:
			transform = Transform3D(Basis.from_euler(Vector3(0.4 * e, 0.12 * e, 0.3 * e)), Vector3(-0.04, 0.06, 0.06) * e)
	if drum != null:
		drum.rotation.z = drum_angle
	if lever != null:
		lever.rotation.x = 0.95 * sin(clampf(cycle, 0.0, 1.0) * PI)
	if barrels != null:
		barrels.rotation.x = -0.75 * e
	# Support hand: off to the cartridge pouch during the posture, then fetch,
	# thumb the round home, and back for the next one.
	var rest: Vector3 = WeaponBuilder.LEFT_FIST[id]
	# The cartridge pouch: low on the left, just out of view.
	var pouch := Vector3(-0.16, -0.3, 0.1)
	var gate := _load_point(round_index)
	var push := _push_dir()
	var p := rest.lerp(pouch, e)
	var holding := false
	if loading:
		if load_t < 0.4:
			p = pouch.lerp(gate - push * 0.05, _ease(load_t / 0.4))
			holding = true
		elif load_t < 0.6:
			p = (gate - push * 0.05).lerp(gate, _ease((load_t - 0.4) / 0.2))
			holding = load_t < 0.55
		else:
			p = gate.lerp(pouch, _ease((load_t - 0.6) / 0.4))
	if catch_t >= 0.0 and lever != null:
		var c := _catch(catch_t, rest, gate)
		p = c[0]
		holding = c[1]
	left.position = p
	left.rotation = Vector3(0.0, 0.0, 0.0) if open < 0.01 else Vector3(-0.3 * e, 0.4 * e, 0.0)
	if catch_t >= 0.0 and lever != null:
		# Tip the forearm down and out so it doesn't swing through the camera.
		var k := clampf(sin(clampf(catch_t, 0.0, 1.0) * PI) * 1.4, 0.0, 1.0)
		left.rotation = left.rotation.lerp(Vector3(1.1, -0.5, 0.6), k)
	_round.visible = holding
	if holding:
		# The round points the way it goes in, pinched at the fingertips.
		var parent_basis := (get_parent() as Node3D).global_transform.basis
		var dir := (parent_basis * push).normalized()
		var up := parent_basis * Vector3.UP
		# A touch oversized so it reads on screen.
		_round.global_transform = Transform3D(Basis.looking_at(dir, up).scaled(Vector3.ONE * 1.6), left.global_position + dir * 0.045 + up * 0.02)


## The lever-rifle flourish (Hunt: Showdown style): the lever flicks, the
## chambered round spins up out of the action, the support hand snaps up and
## catches it in mid-air, then carries it to the loading gate to thumb it back in.
## Returns [hand position, holding the round?] in parent space.
const CATCH_LEVER := 0.32
const CATCH_FLY := Vector2(0.12, 0.52)
const CATCH_GRAB := 0.52


func _catch(t: float, rest: Vector3, gate: Vector3) -> Array:
	lever.rotation.x = 0.95 * sin(clampf(t / CATCH_LEVER, 0.0, 1.0) * PI)
	var start := transform * Vector3(0.0, 0.04, -0.01)
	var apex := start + Vector3(-0.07, 0.16, -0.03)
	var grab := start + Vector3(-0.15, 0.06, -0.05)
	# The flying round: a spinning arc from the ejection port to the catch point.
	var ft := clampf((t - CATCH_FLY.x) / (CATCH_FLY.y - CATCH_FLY.x), 0.0, 1.0)
	var flying := t >= CATCH_FLY.x and t < CATCH_GRAB
	_flyer.visible = flying
	if flying:
		var q := start.lerp(apex, ft).lerp(apex.lerp(grab, ft), ft)
		var parent_basis := (get_parent() as Node3D).global_transform.basis
		_flyer.global_transform = Transform3D(parent_basis * Basis.from_euler(Vector3(ft * 9.0, ft * 4.0, 0.0)).scaled(Vector3.ONE * 1.3),
				(get_parent() as Node3D).global_transform * q)
	# The hand: waits low, then snaps up to meet the round, then takes it to the gate.
	var ready := rest + Vector3(-0.08, -0.03, 0.04)
	if t < 0.3:
		return [rest.lerp(ready, _ease(t / 0.3)), false]
	if t < CATCH_GRAB:
		return [ready.lerp(grab - Vector3(0, 0.03, 0), _ease((t - 0.3) / (CATCH_GRAB - 0.3))), false]
	if t < 0.7:
		return [grab - Vector3(0, 0.03, 0) + Vector3(0, -0.02, 0) * sin((t - CATCH_GRAB) / 0.18 * PI), true]
	return [(grab - Vector3(0, 0.03, 0)).lerp(gate - _push_dir() * 0.05, _ease((t - 0.7) / 0.3)), true]


## Where the round goes, in this node's parent space (the gun's resting frame).
func _load_point(round_index: int) -> Vector3:
	if id == &"coach_shotgun" and barrels != null:
		var side := 1.0 if round_index % 2 == 0 else -1.0
		var chamber := barrels.transform * (Vector3(side * 0.0172, 0.022, -0.059) - WeaponBuilder.HINGE)
		return transform * chamber
	return transform * (WeaponBuilder.LOAD_POINT[id] as Vector3)


## Direction the round is pushed (parent space).
func _push_dir() -> Vector3:
	match id:
		&"lever_rifle":
			return transform.basis * Vector3(-0.5, 0.1, -1.0).normalized()
		&"coach_shotgun":
			return (transform.basis * barrels.transform.basis * Vector3(0, 0, -1)).normalized() if barrels != null else Vector3.FORWARD
	return transform.basis * Vector3(0, 0, -1)


## The two empties flying out of the broken-open shotgun.
func eject_shells() -> void:
	if barrels == null:
		return
	for side: float in [-1.0, 1.0]:
		var s := MeshInstance3D.new()
		s.mesh = WeaponBuilder.shell()
		s.material_override = _mat
		get_tree().current_scene.add_child(s)
		var start := barrels.global_transform * (Vector3(side * 0.0172, 0.022, -0.06) - WeaponBuilder.HINGE)
		s.global_position = start
		var cam_basis := get_parent().global_transform.basis as Basis
		var fly := cam_basis * Vector3(side * 0.15 + 0.35, 0.25, 0.5)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "global_position", start + fly * 0.5, 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", Vector3(randf() * 6.0, randf() * 6.0, 0), 0.35)
		tw.chain().tween_property(s, "global_position", start + fly * 0.5 + Vector3.DOWN * 1.2, 0.35).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(s.queue_free)
	Audio.play_at(&"reload", global_position, -8.0)
