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
## The revolver's cylinder, or the pepperbox's barrel cluster (turns about Z).
var drum: Node3D
var lever: Node3D
var barrels: Node3D
## Crank Gatling: the spinning barrel cluster and the crank handle.
var spinner: Node3D
var crank: Node3D
var left: Node3D
var _right_mi: MeshInstance3D
var _left_mi: MeshInstance3D
var _round: MeshInstance3D
var _flyer: MeshInstance3D
var _mat: Material
var _team: Color
var _posture := 0.0
# Frontier guns (gen/frontier_guns.gd): the rifle's bolt, the salt gun's pump,
# the harpoon's spool and loaded dart, the smoker's bellows and leather, and
# the derringers' second pistol (in the left hand) with its own barrels.
var bolt: Node3D
var pump: Node3D
var reel: Node3D
var dart: Node3D
var bellows: Node3D
var pleats: Node3D
var left_gun: Node3D
var left_barrels: Node3D
var _reel_spin := 0.0
var _reel_angle := 0.0
var _puff_phase := 0.0
## Derringers: the recoil of the last shot, per hand (0 right, 1 left).
var _hand_kick := Vector2.ZERO


func build(weapon_id: StringName, team: Color, look: Dictionary, mat: Material) -> void:
	id = weapon_id
	_mat = mat
	_team = team
	var body := _mi(self, null)
	if FrontierGuns.has(id):
		_build_frontier(body)
	else:
		_build_classic(body)
	_right_mi = _mi(self, null)
	left = Node3D.new()
	left.position = WeaponBuilder.LEFT_FIST[id]
	add_child(left)
	_left_mi = _mi(left, null)
	var held_round: Mesh = WeaponBuilder.cartridge()
	if _rv:
		held_round = _rv_mesh("cartridge").mesh
	match id:
		&"coach_shotgun":
			held_round = WeaponBuilder.shell()
		&"blunderbuss":
			held_round = WeaponBuilder.powder_horn()
		&"crank_gatling":
			held_round = WeaponBuilder.gatling_drum()
		&"flare_gun", &"salt_shotgun", &"punt_gun", &"harpoon_pistol", &"telescope_rifle", &"pepperbox":
			held_round = FrontierGuns.held_round(id)
	_round = _mi(left, held_round)
	if FrontierGuns.has(id) or _rv:
		_round.material_override = null
	_round.position = Vector3(0.012, 0.02, -0.02)
	_round.visible = false
	if id == &"revolver":
		_make_twirl_pivot()
	if id == &"derringer_pair":
		# The second pistol sits in the left fist the way the first sits in the right.
		left_gun = Node3D.new()
		left_gun.name = "LeftPistol"
		left_gun.position = -(WeaponBuilder.RIGHT_HAND[id][0] as Vector3)
		left.add_child(left_gun)
		var lb := _mi(left_gun, FrontierGuns.parts(id)["body"])
		lb.material_override = null
		left_barrels = FrontierGuns.part_node(id, "barrels")
		left_gun.add_child(left_barrels)
	if id == &"lever_rifle":
		_flyer = MeshInstance3D.new()
		_flyer.mesh = WeaponBuilder.cartridge()
		_flyer.material_override = _mat
		_flyer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flyer.visible = false
		add_child(_flyer)
	set_look(look)


## A frontier gun: its body (own materials, no toon override) and each moving
## part on its pivot (FrontierGuns.PIVOTS).
func _build_frontier(body: MeshInstance3D) -> void:
	body.mesh = FrontierGuns.parts(id)["body"]
	body.material_override = null
	for part: String in FrontierGuns.parts(id):
		if part == "body":
			continue
		var n := FrontierGuns.part_node(id, part)
		add_child(n)
		match part:
			"barrels":
				barrels = n
			"drum":
				drum = n
			"bolt":
				bolt = n
			"pump":
				pump = n
			"reel":
				reel = n
			"dart":
				dart = n
			"bellows":
				bellows = n
			"pleats":
				pleats = n
	if bellows != null:
		bellows.rotation.x = FrontierGuns.BELLOWS_OPEN
		pleats.rotation.x = FrontierGuns.BELLOWS_OPEN * 0.6


func _build_classic(body: MeshInstance3D) -> void:
	match id:
		&"revolver":
			if has_parts_revolver():
				_build_rv(body)
				return
			body.mesh = WeaponBuilder.revolver_body()
			drum = _mi(self, WeaponBuilder.revolver_drum())
			drum.position = Vector3(0, 0.018, -0.005)
		&"lever_rifle":
			body.mesh = WeaponBuilder.rifle_body()
			lever = Node3D.new()
			lever.position = WeaponBuilder.LEVER_PIVOT
			add_child(lever)
			_mi(lever, WeaponBuilder.rifle_lever())
		&"blunderbuss":
			body.mesh = WeaponBuilder.blunderbuss()
		&"crank_gatling":
			body.mesh = WeaponBuilder.gatling_body()
			spinner = Node3D.new()
			spinner.position = WeaponBuilder.GATLING_AXIS
			add_child(spinner)
			_mi(spinner, WeaponBuilder.gatling_barrels())
			crank = Node3D.new()
			crank.position = WeaponBuilder.GATLING_CRANK
			add_child(crank)
			_mi(crank, WeaponBuilder.gatling_crank())
		_:
			body.mesh = WeaponBuilder.shotgun_action()
			barrels = Node3D.new()
			barrels.position = WeaponBuilder.HINGE
			add_child(barrels)
			_mi(barrels, WeaponBuilder.shotgun_barrels())
	if GunModels.has(id):
		_use_model(body)


## Swap the code-built gun for the Meshy model: the body goes on this node, and
## each moving part goes on its pivot (moved to the model's own hinge point).
func _use_model(body: MeshInstance3D) -> void:
	body.mesh = null
	add_child(GunModels.make(id))
	for pair: Array in [[lever, "lever"], [barrels, "barrels"], [spinner, "barrels"], [crank, "crank"]]:
		var node: Node3D = pair[0]
		if node == null:
			continue
		for c in node.get_children():
			c.queue_free()
		var part := GunModels.make(id, pair[1])
		if part != null:
			node.position = GunModels.pivot(id, pair[1])
			part.position = -node.position
			node.add_child(part)
	_glass = GunModels.glass(id, 0, 0.004)
	if _glass != null:
		add_child(_glass)
	# The model's cylinder is part of its body (it doesn't turn).
	if drum != null:
		drum.visible = false


## Revolver: the gun itself (not the hand) hangs on a pivot through the
## trigger guard, so it can spin round the trigger finger.
const TWIRL_PIVOT := Vector3(0.0, -0.017, 0.022)
var _twirl: Node3D


func _make_twirl_pivot() -> void:
	_twirl = Node3D.new()
	_twirl.name = "Twirl"
	_twirl.position = TWIRL_PIVOT
	var parts: Array[Node] = []
	for c in get_children():
		if c != _right_mi and c != left:
			parts.append(c)
	add_child(_twirl)
	for c in parts:
		remove_child(c)
		_twirl.add_child(c)
		if c is Node3D:
			(c as Node3D).position -= TWIRL_PIVOT


## Spins the revolver round the trigger finger (radians, about its side axis;
## negative rolls the muzzle down and under).
func twirl(angle: float) -> void:
	if _twirl != null:
		_twirl.rotation.x = angle


## Dino Rifle: moves the tied-on glass to this gun's fit (DinoGlass variant).
func set_glass(variant: int) -> void:
	if _glass != null and variant != _glass_variant:
		_glass_variant = variant
		GunModels.place_glass(_glass, id, variant)


var _glass: Node3D
var _glass_variant := 0
var _finish := false
static var _finish_mat: StandardMaterial3D


## Hive amber: Lucky Moreau's finish: a warm gold-and-amber sheen over the gun.
func set_finish(on: bool) -> void:
	if on == _finish:
		return
	_finish = on
	if _finish_mat == null:
		_finish_mat = StandardMaterial3D.new()
		_finish_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_finish_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_finish_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_finish_mat.albedo_color = Color(AmberRules.COLOR, 0.32)
	for c in find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi == _right_mi or mi == _left_mi or mi == _round:
			continue
		mi.material_overlay = _finish_mat if on else null


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
	_posture = e
	match id:
		&"revolver":
			transform = Transform3D(Basis.from_euler(Vector3(0.35 * e, 0.3 * e, 0.95 * e)), Vector3(-0.07, 0.06, 0.04) * e)
		&"lever_rifle":
			transform = Transform3D(Basis.from_euler(Vector3(0.22 * e, -0.15 * e, -0.8 * e)), Vector3(-0.02, 0.07, 0.07) * e)
		&"blunderbuss":
			# Muzzle up to pour the charge and ram it home.
			transform = Transform3D(Basis.from_euler(Vector3(1.05 * e, 0.1 * e, 0.15 * e)), Vector3(-0.03, -0.02, 0.12) * e)
		&"crank_gatling":
			# Tip it right to swap the drum on top.
			transform = Transform3D(Basis.from_euler(Vector3(0.15 * e, 0.0, -0.55 * e)), Vector3(-0.04, 0.05, 0.05) * e)
		&"derringer_pair":
			# Both pistols come up, muzzles high, and the barrels flick open.
			transform = Transform3D(Basis.from_euler(Vector3(0.55 * e, 0.0, 0.25 * e)), Vector3(0.0, 0.05, 0.02) * e)
		&"pepperbox", &"harpoon_pistol":
			# Tipped up and left to thumb rounds into the back of the block / slide a dart in.
			transform = Transform3D(Basis.from_euler(Vector3(0.5 * e, 0.25 * e, 0.6 * e)), Vector3(-0.06, 0.06, 0.03) * e)
		&"flare_gun", &"punt_gun":
			# Muzzle down, breech up toward you.
			transform = Transform3D(Basis.from_euler(Vector3(-0.35 * e, 0.15 * e, 0.35 * e)), Vector3(-0.05, 0.08, 0.06) * e)
		&"salt_shotgun":
			# Rolled over to thumb shells into the loading port underneath.
			transform = Transform3D(Basis.from_euler(Vector3(0.2 * e, -0.1 * e, 1.6 * e)), Vector3(-0.05, 0.08, 0.06) * e)
		&"telescope_rifle":
			# Canted right, bolt open, rounds pressed down into the magazine.
			transform = Transform3D(Basis.from_euler(Vector3(0.25 * e, -0.15 * e, -0.55 * e)), Vector3(-0.03, 0.07, 0.07) * e)
		_:
			transform = Transform3D(Basis.from_euler(Vector3(0.4 * e, 0.12 * e, 0.3 * e)), Vector3(-0.04, 0.06, 0.06) * e)
	if drum != null:
		drum.rotation.z = drum_angle
	if _rv:
		_pose_rv(get_process_delta_time(), e, load_t, loading)
	if lever != null:
		lever.rotation.x = 0.95 * sin(clampf(cycle, 0.0, 1.0) * PI)
	if barrels != null:
		barrels.rotation.x = (0.9 if id == &"derringer_pair" else -0.75) * e
	if left_barrels != null:
		left_barrels.rotation.x = 0.9 * e
	if bolt != null:
		_pose_bolt(cycle, e)
	if pump != null:
		# Racked back and forward after each shot.
		pump.position = FrontierGuns.pivot(id, "pump") + Vector3(0, 0, 0.075 * sin(clampf(cycle, 0.0, 1.0) * PI))
	if id == &"derringer_pair":
		_pose_derringers(e, load_t, loading)
		return
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
	_round.visible = holding and not (_rv and speedload)
	if holding and _round.visible:
		# The round points the way it goes in, pinched at the fingertips.
		var parent_basis := (get_parent() as Node3D).global_transform.basis
		var dir := (parent_basis * push).normalized()
		var up := parent_basis * Vector3.UP
		# A touch oversized so it reads on screen.
		_round.global_transform = Transform3D(Basis.looking_at(dir, up).scaled(Vector3.ONE * 1.6), left.global_position + dir * 0.045 + up * 0.02)


## Telescope Rifle bolt: lift the handle, draw it back, push it home, turn it
## down (cycle 0..1 after a shot); held open while reloading.
func _pose_bolt(cycle: float, open: float) -> void:
	var c := clampf(cycle, 0.0, 1.0)
	var lift := 0.0
	var back := 0.0
	if c < 1.0:
		lift = _ease(c / 0.2) if c < 0.8 else 1.0 - _ease((c - 0.8) / 0.2)
		back = _ease((c - 0.2) / 0.25) if c < 0.5 else 1.0 - _ease((c - 0.5) / 0.25)
	lift = maxf(lift, open)
	back = maxf(back, open * 0.8)
	bolt.rotation.z = 1.25 * lift
	bolt.position = FrontierGuns.pivot(id, "bolt") + Vector3(0, 0, 0.07 * back)


## Derringers: each hand kicks on its own shot; on a reload both pistols tip up,
## barrels open, and a flick of the wrists seats the new rounds.
func _pose_derringers(e: float, load_t: float, loading: bool) -> void:
	_round.visible = false
	var rest: Vector3 = WeaponBuilder.LEFT_FIST[id]
	var seat := sin(clampf(load_t, 0.0, 1.0) * PI) * 0.12 if loading else 0.0
	left.position = rest + Vector3(0.05, 0.05, 0.02) * e + Vector3(0, 0, 0.03 * _hand_kick.y)
	# (The left pistol hangs off this node, so cancel the right hand's kick on it.)
	left.rotation = Vector3(0.5 * _hand_kick.y - 0.5 * _hand_kick.x, 0.0, -0.5 * e)
	rotation.x += 0.5 * _hand_kick.x + seat


## Derringers: the pistol in hand `side` (0 right, 1 left) just fired.
func hand_kick(side: int) -> void:
	if side == 0:
		_hand_kick.x = 1.0
	else:
		_hand_kick.y = 1.0


## Harpoon: the dart shows in the muzzle only while one is loaded.
func set_loaded(on: bool) -> void:
	if dart != null:
		dart.visible = on


## Harpoon: the spool whirls as the line pays out (decays by itself).
func spin_reel(speed: float) -> void:
	_reel_spin = maxf(_reel_spin, speed)


## Frame update for the frontier guns' idle motion (spool, kicks).
func frontier_tick(delta: float) -> void:
	_hand_kick = _hand_kick.move_toward(Vector2.ZERO, delta * 7.0)
	if reel != null:
		_reel_angle += _reel_spin * delta
		_reel_spin = move_toward(_reel_spin, 0.0, delta * 30.0)
		reel.rotation.x = -_reel_angle


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


## Crank Gatling: barrels whirl and the crank turns with the wind-up.
var _spin_angle := 0.0


func turn_crank(amount: float, delta: float) -> void:
	if bellows != null:
		# Bee Smoker: the bellows pump while the trigger's held.
		if amount > 0.01:
			_puff_phase += delta * 11.0
		var squeeze := (0.5 + 0.5 * sin(_puff_phase)) * amount
		bellows.rotation.x = FrontierGuns.BELLOWS_OPEN * (1.0 - 0.85 * squeeze)
		pleats.rotation.x = bellows.rotation.x * 0.6
		var rest: Vector3 = WeaponBuilder.LEFT_FIST[id]
		left.position = rest + Vector3(0, 0, 0) # the can hand stays put
		_right_mi.position = Vector3(0, 0, -0.03 * squeeze)
		return
	if spinner == null:
		return
	_spin_angle += amount * 26.0 * delta
	spinner.rotation.z = _spin_angle
	crank.rotation.x = -_spin_angle * 0.5
	# The left hand stays on the crank handle and goes round with it (unless it's
	# off fetching a new drum).
	if left != null and _posture < 0.02:
		var rest: Vector3 = WeaponBuilder.LEFT_FIST[id]
		left.position = crank.position + crank.basis * (rest - crank.position)


## Where the round goes, in this node's parent space (the gun's resting frame).
func _load_point(round_index: int) -> Vector3:
	if id == &"coach_shotgun" and barrels != null:
		var side := 1.0 if round_index % 2 == 0 else -1.0
		var chamber := barrels.transform * (Vector3(side * 0.017, 0.012, -0.092) - barrels.position)
		return transform * chamber
	if _rv:
		# The next empty chamber's mouth on the swung-out cylinder (the loader: its back face).
		if speedload:
			return (get_parent() as Node3D).global_transform.affine_inverse() * drum.to_global(Vector3(0, 0, 0.065))
		return _rv_chamber_mouth()[0]
	return transform * (WeaponBuilder.LOAD_POINT[id] as Vector3)


## Direction the round is pushed (parent space).
func _push_dir() -> Vector3:
	if _rv and drum != null:
		return _rv_chamber_mouth()[1]
	match id:
		&"lever_rifle":
			return transform.basis * Vector3(-0.5, 0.1, -1.0).normalized()
		&"blunderbuss", &"crank_gatling", &"bee_smoker":
			return transform.basis * Vector3(0, -1, 0)
		&"salt_shotgun":
			return transform.basis * Vector3(0, 1, -0.3).normalized()
		&"telescope_rifle":
			return transform.basis * Vector3(-0.2, -1, 0).normalized()
		&"flare_gun", &"punt_gun":
			return transform.basis * Vector3(0, -0.45, -1).normalized()
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
	Audio.play_at(&"shell_eject", global_position, -6.0)


# ------------------------------------------------------------------ the parts revolver

## Logan's Meshy revolver in parts (tools/rig/prep_revolver.py writes rv_*.glb):
## the cylinder turns, each chamber shows its round, the hammer and trigger
## move, and with the Speed loader mod all six go in at once.
const RV_AXIS := Vector3(0.0, 0.018, -0.005)
const RV_HAMMER := Vector3(0.0, 0.0086, 0.0361)
const RV_TRIGGER := Vector3(0.0, -0.0138, 0.0156)
## Chambers sit this far off the axis, the first straight up (under the hammer).
const RV_CHAMBER_R := 0.0164
const RV_CHAMBER_Z := 0.002
## The chamber the loading gate opens onto (slot 5: 30 degrees, upper right).
const RV_GATE_SLOT := 5
const RV_HAMMER_COCK := 0.6
## The crane's hinge (parallel to the barrel) and how far the cylinder swings out (rad).
const RV_CRANE := Vector3(-0.012, -0.008, -0.005)
const RV_SWING := 1.7
var crane: Node3D
## The swing, eased with a little overshoot (a flick of the wrist).
var _swing := 0.0
var hammer: Node3D
var trig: Node3D
var _rv := false
var _chambers: Array[Node3D] = []
var _full: Array[bool] = [true, true, true, true, true, true]
var _steps := 0
var _shot_t := 1.0
var _loader: Node3D
## Gun sets this before pose(): the Speed loader mod is on (all six at once).
var speedload := false


static func has_parts_revolver() -> bool:
	return ResourceLoader.exists(GunModels.DIR + "rv_frame.glb")


## One part as its own MeshInstance3D (the glb's mesh with its own materials).
static func _rv_mesh(part: String) -> MeshInstance3D:
	var n := GunModels.make(&"rv", part)
	var mi := MeshInstance3D.new()
	if n == null:
		return mi
	var src := n.find_children("*", "MeshInstance3D", true, false)
	if not src.is_empty():
		mi.mesh = (src[0] as MeshInstance3D).mesh
		# Meshy sometimes exports alpha blending: these parts are solid.
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m != null and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				var solid := m.duplicate() as BaseMaterial3D
				solid.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				mi.set_surface_override_material(i, solid)
	n.free()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_rv(body: MeshInstance3D) -> void:
	_rv = true
	body.mesh = null
	for part in ["frame", "barrel", "grip_r", "grip_l"]:
		add_child(_rv_mesh(part))
	# The cylinder rides a crane hinged below-left of it, so it can swing out.
	crane = Node3D.new()
	crane.name = "Crane"
	crane.position = RV_CRANE
	add_child(crane)
	drum = Node3D.new()
	drum.name = "Cylinder"
	drum.position = RV_AXIS - RV_CRANE
	crane.add_child(drum)
	var cyl := _rv_mesh("cylinder")
	cyl.position = -RV_AXIS
	drum.add_child(cyl)
	for i in 6:
		var a := PI * 0.5 + TAU * float(i) / 6.0
		var c := _rv_mesh("cartridge")
		c.position = Vector3(cos(a) * RV_CHAMBER_R, sin(a) * RV_CHAMBER_R, RV_CHAMBER_Z)
		drum.add_child(c)
		_chambers.append(c)
	hammer = Node3D.new()
	hammer.position = RV_HAMMER
	add_child(hammer)
	var h := _rv_mesh("hammer")
	h.position = -RV_HAMMER
	hammer.add_child(h)
	trig = Node3D.new()
	trig.position = RV_TRIGGER
	add_child(trig)
	var t := _rv_mesh("trigger")
	t.position = -RV_TRIGGER
	trig.add_child(t)
	_loader = _rv_mesh("speed_loader")
	_loader.visible = false
	add_child(_loader)


## The chamber now at `slot` (0 = under the hammer, counting the way the cylinder turns).
func _chamber_at(slot: int) -> int:
	return posmod(slot - _steps, 6)


func _show_chambers() -> void:
	for i in _chambers.size():
		_chambers[i].visible = _full[i]


## Gun: a shot went off (the chamber under the hammer is spent; the cylinder turns on).
func rv_fired() -> void:
	if not _rv:
		return
	_full[_chamber_at(0)] = false
	_steps += 1
	_shot_t = 0.0
	_show_chambers()


## Gun: one round thumbed through the gate (then the cylinder clicks round).
func rv_loaded_one() -> void:
	if not _rv:
		return
	var i := _full.find(false)
	if i >= 0:
		_full[i] = true
	_show_chambers()


## Gun: the speed loader dropped all six home.
func rv_loaded_all() -> void:
	if not _rv:
		return
	for i in 6:
		_full[i] = true
	_show_chambers()


## Gun: match the chambers to `rounds` loaded (equipping, a dropped gun picked up).
func rv_set_rounds(rounds: int) -> void:
	if not _rv:
		return
	for k in 6:
		_full[_chamber_at(k)] = k < rounds
	_show_chambers()


## The chamber the next round goes in (the first empty one), in parent space:
## its mouth on the swung-out cylinder's back face, and the way the round goes in.
func _rv_chamber_mouth() -> Array:
	var i := maxi(_full.find(false), 0)
	var a := PI * 0.5 + TAU * float(i) / 6.0
	var local := Vector3(cos(a) * RV_CHAMBER_R, sin(a) * RV_CHAMBER_R, 0.04)
	var to_parent := (get_parent() as Node3D).global_transform.affine_inverse()
	var mouth := to_parent * drum.to_global(local)
	var dir := (to_parent.basis * drum.global_transform.basis * Vector3(0, 0, -1)).normalized()
	return [mouth, dir]


func _pose_rv(delta_shot: float, e: float, load_t: float, loading: bool) -> void:
	_shot_t += delta_shot
	# Flick out with the posture, a quick overshoot, and snap home as it ends.
	var k := clampf(e * 1.25, 0.0, 1.0)
	var flick := 1.0 - pow(1.0 - k, 3.0) + sin(k * PI) * 0.12
	_swing = flick
	crane.rotation.z = RV_SWING * _swing
	# (The crane hangs off the twirl pivot like the rest of the gun.)
	crane.position = RV_CRANE + Vector3(-0.006 * _swing, 0, 0) - (TWIRL_PIVOT if crane.get_parent() == _twirl else Vector3.ZERO)
	# Hammer: falls on the shot, thumbed back again; trigger: squeezed and let go.
	var cock := _ease(_shot_t / 0.22) if _shot_t < 0.22 else 1.0
	hammer.rotation.x = RV_HAMMER_COCK * cock * (1.0 - e)
	trig.rotation.x = -0.35 * (1.0 - _ease(_shot_t / 0.12))
	_loader.visible = false
	if speedload and loading:
		# The loader comes up behind the cylinder, all six bullets first, and pushes home.
		# Lined up on the swung-out cylinder's back face, bullets first, pushed home.
		var lp := _loader.get_parent() as Node3D
		var back := lp.to_local(drum.to_global(Vector3(0, 0, 0.065)))
		var seat := lp.to_local(drum.to_global(Vector3(0, 0, 0.029)))
		var at := back
		if load_t < 0.45:
			at = lp.to_local(drum.to_global(Vector3(-0.06, -0.12, 0.14))).lerp(back, _ease(load_t / 0.45))
		elif load_t < 0.6:
			at = back.lerp(seat, _ease((load_t - 0.45) / 0.15))
		if load_t < 0.6:
			_loader.visible = true
			_loader.position = at
			_loader.basis = (lp.global_transform.basis.inverse() * drum.global_transform.basis).orthonormalized()
