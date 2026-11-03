class_name DummyRig
extends Node3D
## The player's body: a crash-test dummy dressed for the frontier. Bright test-lab
## paint, black rubber joints, quartered target markers on the head, chest and
## thighs, a ribbed neck and mitten hands, topped with a cowboy hat. The rest is
## up to you (DummyLook): hair poking out from the hat, a moustache, an outfit,
## something round the neck, boots and spurs. Built from rounded primitives and
## animated procedurally: legs walk with your speed, the gun arm follows your aim,
## coat tails flap, the body crouches when sliding, and it can be knocked about.
## In first person you see your own legs; the upper body only casts a shadow.

const JOINT := Color("#26262C")

## A foot came down (world position of the boot, 0..1 how hard).
signal stepped(at: Vector3, strength: float)
## Touched down after being in the air (0..1 how hard).
signal landed(strength: float)
const MARK_DARK := Color("#1E1E22")
const MARK_LIGHT := Color("#F2C230")
const HAT := Color("#6B4A2E")
const HAT_DARK := Color("#4E3420")
const VEST := Color("#4A2E20")
const COAT := Color("#8A6C4A")
const COAT_DARK := Color("#6E5438")
const SHIRT := Color("#D8C8A2")
const BOOT := Color("#4A2C1C")
const BELT := Color("#3A2416")
const BRASS := Color("#D6A74A")
const THIGH := 0.44
const SHIN := 0.44
const UPPER_ARM := 0.3
const FOREARM := 0.28

static var _meshes: Dictionary = {}

var first_person := false
var look: Dictionary = DummyLook.default_look()
var _mat: ShaderMaterial
var _team: Color
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _tails: Node3D
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _hand: Node3D
var _gun_mi: MeshInstance3D
var _weapon: StringName = &"-"
var _phase := 0.0
var _slide := 0.0
var _tail_swing := 0.0
## Ragdoll-ish wobble from being hit (rocks): a tilt that springs back.
var _wobble := Vector3.ZERO
var _life := randf() * 10.0
var _air := 0.0
var _two := 0.0
var _look_t := 3.0
var _look_yaw := 0.0
var _head_yaw := 0.0
var _wobble_vel := Vector3.ZERO
var _ankles: Array[Node3D] = []
var _land := 0.0
var _accel := 0.0
var _last_speed := 0.0
var _strafe := 0.0
var _idle_t := 0.0
var _fidget_t := 0.0
## Velocity in the body's own frame (set by the owner before animate()).
var move_local := Vector3.ZERO
## The interaction being acted out (DummyActions), and how far into it we are.
var action: StringName = &""
var action_t := 0.0
var _action_w := 0.0
## The Meshy body worn over the pivots (null = the code-built dummy is shown).
var _model: ModelBody
## Moves the hat to sit on the model's head.
const MODEL_HAT_OFFSET := Vector3(0, -0.02, 0.0)
## Debug screenshots: hold the action at this point (0..1); -1 plays normally.
var action_freeze := -1.0
## NPC use: the right arm hangs and swings instead of aiming.
var relaxed := false
## 0..1: raises the right arm and waves (shopkeepers greeting you).
var wave := 0.0


func build(team: Color, is_first_person: bool, dummy_look: Dictionary = {}) -> void:
	first_person = is_first_person
	_team = team
	look = DummyLook.clean(dummy_look if not dummy_look.is_empty() else look)
	for c in get_children():
		c.queue_free()
	_thighs.clear()
	_shins.clear()
	_shoulders.clear()
	_elbows.clear()
	_ankles.clear()
	action = &""
	_mat = Materials.toon_unique(0.022)
	_hips = _pivot(self, Vector3(0, 0.95, 0))
	var pelvis := _part(_hips, "pelvis")
	_tails = _pivot(_hips, Vector3(0, 0.02, 0.06))
	var tails := _part(_tails, "tails")
	_torso = _pivot(_hips, Vector3(0, 0.08, 0))
	var torso := _part(_torso, "torso")
	_head = _pivot(_torso, Vector3(0, 0.6, 0))
	var head_mi := _part(_head, "head")
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var thigh := _pivot(_hips, Vector3(side * 0.11, -0.05, 0))
		_part(thigh, "thigh_l" if i == 0 else "thigh_r")
		var shin := _pivot(thigh, Vector3(0, -THIGH, 0))
		_part(shin, "shin")
		var ankle := _pivot(shin, Vector3(0, -SHIN, 0))
		var foot := _part(ankle, "foot")
		foot.position = Vector3(0, SHIN, 0)
		_ankles.append(ankle)
		_thighs.append(thigh)
		_shins.append(shin)
		var shoulder := _pivot(_torso, Vector3(side * 0.25, 0.46, 0))
		var upper := _part(shoulder, "upper_arm")
		var elbow := _pivot(shoulder, Vector3(0, -UPPER_ARM, 0))
		var fore := _part(elbow, "forearm")
		_shoulders.append(shoulder)
		_elbows.append(elbow)
		if first_person:
			upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			fore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# The right hand holds whatever gun you have out (third person only).
	_hand = _pivot(_elbows[1], Vector3(0, -FOREARM - 0.05, 0))
	_gun_mi = MeshInstance3D.new()
	_gun_mi.material_override = Materials.toon(0.008)
	_gun_mi.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.0, -0.01))
	_hand.add_child(_gun_mi)
	if first_person:
		_gun_mi.visible = false
		for mi: MeshInstance3D in [head_mi, torso, pelvis, tails]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		# Set back a little so looking down shows the chest and legs, not the inside of them.
		position.z = 0.26
	_model = null
	var outfit := StringName(str(look.get("outfit")))
	if ModelBody.has_model(outfit) and not GameState.has_flag("--oldbody"):
		_wear_model(outfit)
	var w := _weapon
	_weapon = &"-"
	set_weapon(w if w != &"-" else &"revolver")


## Swaps the code-built body for the rigged model: the pivots stay (invisible)
## and drive the model's bones; the gun stays in the pivot hand and the hat on
## the pivot head, which line up with the model's.
func _wear_model(outfit: StringName) -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi != _gun_mi:
			mi.visible = false
	_model = ModelBody.new()
	_model.name = "Model"
	add_child(_model)
	_model.setup(self, outfit, first_person)
	var meshy_hat := ModelBody.hat(StringName(str(look.get("hat"))), first_person)
	if meshy_hat != null:
		_head.add_child(meshy_hat)
	elif str(look.get("hat")) != "none":
		var hat := MeshInstance3D.new()
		hat.mesh = DummyBuilder.hat_mesh(_team, look)
		hat.material_override = _mat
		hat.position = MODEL_HAT_OFFSET
		if first_person:
			hat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_head.add_child(hat)


## Re-dresses the dummy (keeps team and first-person setting).
func apply_look(new_look: Dictionary) -> void:
	var cleaned := DummyLook.clean(new_look)
	if DummyLook.key(cleaned) == DummyLook.key(look) and _hips != null:
		return
	build(_team, first_person, cleaned)


## Shows gun `id` in the right hand ("" = empty hand).
func set_weapon(id: StringName) -> void:
	if id == _weapon:
		return
	_weapon = id
	for c in _gun_mi.get_children():
		c.queue_free()
	var model := GunModels.whole(id, 0.006, not first_person) if id != &"" else null
	if model != null:
		_gun_mi.mesh = null
		_gun_mi.add_child(model)
	else:
		_gun_mi.mesh = WeaponBuilder.gun(id) if id != &"" else null


## A shove (rock hit, explosion): the body tips away from `dir` and springs back.
func knock(dir: Vector3, strength: float) -> void:
	var local := global_transform.basis.inverse() * dir
	_wobble_vel += Vector3(local.z, 0.0, -local.x).normalized() * strength * 9.0 + Vector3(0, randf_range(-1, 1), 0) * strength * 4.0


## Called every frame. speed = horizontal speed (m/s); pitch = aim pitch (radians);
## vy = vertical speed (m/s), for jump and fall poses. Set `move_local` first
## (velocity in the body's own frame) so strafing and backpedalling read right.
## Front is -Z: a positive X turn swings a limb forward, a knee bends negative.
func animate(delta: float, speed: float, sliding: bool, pitch: float, vy: float = 0.0) -> void:
	if _hips == null:
		return
	_life += delta
	var dt := clampf(delta, 0.0, 0.1)
	_slide = move_toward(_slide, 1.0 if sliding else 0.0, dt * 6.0)
	var air_target := clampf(absf(vy) / 4.0, 0.0, 1.0) if absf(vy) > 1.5 else 0.0
	# Landing: a squash when the air pose ends.
	if _air > 0.45 and air_target == 0.0:
		_land = maxf(_land, _air)
		landed.emit(_air)
	_air = move_toward(_air, air_target, dt * 5.0)
	_land = move_toward(_land, 0.0, dt * 3.2)
	# Acceleration lean (smoothed).
	_accel = lerpf(_accel, (speed - _last_speed) / maxf(dt, 0.001), clampf(dt * 4.0, 0.0, 1.0))
	_last_speed = speed
	var lean := clampf(_accel * 0.012, -0.12, 0.12)
	var k := clampf(speed / 6.0, 0.0, 1.6) * (1.0 - _air)
	# Which way the legs walk: forward, back or sideways (hips turn into a strafe).
	var mv := Vector2(move_local.x, -move_local.z)
	var dir := 1.0
	var strafe_yaw := 0.0
	if mv.length() > 0.5:
		dir = -1.0 if mv.y < -0.2 * absf(mv.x) else 1.0
		strafe_yaw = clampf(atan2(-mv.x, absf(mv.y) + 0.001) * dir, -0.75, 0.75) if absf(mv.x) > 0.3 else 0.0
	_strafe = lerpf(_strafe, strafe_yaw if k > 0.05 else 0.0, clampf(dt * 6.0, 0.0, 1.0))
	if speed > 0.3:
		var before := floori(_phase / PI)
		_phase += dt * (4.2 + speed * 0.85)
		# A footfall each half cycle (heel strike), not while sliding or airborne.
		if floori(_phase / PI) != before and _air < 0.3 and _slide < 0.3 and speed > 1.0:
			var foot: Node3D = _ankles[(floori(_phase / PI)) % 2] if _ankles.size() == 2 else self
			stepped.emit(foot.global_position + Vector3(0, -SHIN, 0) if foot != self else global_position, clampf(speed / 9.5, 0.2, 1.0))
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, clampf(dt * 6.0, 0.0, 1.0))
	# Idle: breathing, a slow weight shift, now and then a look around or a fidget.
	var idle := clampf(1.0 - speed / 1.5, 0.0, 1.0) * (1.0 - _slide) * (1.0 - _air)
	var breathe := sin(_life * 1.9) * 0.012 * idle
	var shift := sin(_life * 0.5) * 0.04 * idle
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = randf_range(3.0, 7.0)
		_look_yaw = randf_range(-0.6, 0.6) if randf() < 0.6 else 0.0
	_head_yaw = lerpf(_head_yaw, _look_yaw * idle, clampf(dt * 3.0, 0.0, 1.0))
	_idle_t = _idle_t + dt if idle > 0.9 and action == &"" else 0.0
	if _idle_t > 9.0 and _fidget_t <= 0.0:
		_fidget_t = 2.2
		_idle_t = randf_range(-6.0, 0.0)
	_fidget_t = maxf(_fidget_t - dt, 0.0)
	var fidget := sin(clampf(1.0 - _fidget_t / 2.2, 0.0, 1.0) * PI) if _fidget_t > 0.0 else 0.0
	fidget = smoothstep(0.0, 0.35, fidget)
	var land := sin(clampf(_land, 0.0, 1.0) * PI * 0.5)
	# ---------------------------------------------------------------- legs
	for i in 2:
		var p := _phase + float(i) * PI
		var s := sin(p)
		var c := cos(p)
		var thigh := s * 0.58 * k * dir + 0.06 * k
		var knee := -(maxf(c * dir, 0.0) * 1.15 + 0.14) * k
		# Airborne: knees tucked (rising) or legs dangling and kicking (falling).
		var air_thigh := 0.95 - i * 0.35 if vy > 0.0 else 0.3 + sin(_life * 9.0 + i * PI) * 0.35
		var air_shin := -1.35 + i * 0.3 if vy > 0.0 else -0.4 - cos(_life * 9.0 + i * PI) * 0.3
		# Slide: lead leg out straight, the other folded under (a baseball slide).
		var slide_thigh := 1.4 if i == 0 else 0.75
		var slide_shin := -0.12 if i == 0 else -1.5
		var th := lerpf(lerpf(thigh, air_thigh, _air), slide_thigh, _slide)
		var sh := lerpf(lerpf(knee, air_shin, _air), slide_shin, _slide)
		# Landing squash: knees give.
		th += 0.35 * land
		sh -= 0.75 * land
		_thighs[i].rotation = Vector3(th, -_strafe * 0.25, (shift if i == 1 else -shift) * 0.5 + (0.05 if i == 1 else -0.05) * _air)
		_shins[i].rotation.x = sh
		# Feet: level with the ground, heel strike in front, toe-off behind.
		var heel := maxf(s * dir, 0.0) * 0.3 * k * maxf(-c * dir + 0.3, 0.0)
		var toe := -maxf(-s * dir, 0.0) * 0.55 * k * maxf(c * dir + 0.2, 0.0)
		var flat := -(th + sh) * (1.0 - _air * 0.5)
		var air_foot := -0.35 if vy < 0.0 else 0.2
		_ankles[i].rotation.x = lerpf(lerpf(flat + heel + toe, air_foot, _air), -0.2 if i == 0 else 0.4, _slide)
	# ---------------------------------------------------------------- body
	var bob := (absf(cos(_phase)) - 0.6) * 0.05 * k
	var hip_y := 0.95 - 0.035 * k + bob + breathe * 0.5 - 0.17 * land
	_hips.position = Vector3(shift + sin(_phase) * 0.03 * k, lerpf(hip_y, 0.48, _slide), 0)
	var hip_twist := sin(_phase) * 0.14 * k * dir
	_hips.rotation = Vector3(_wobble.x, _wobble.y + hip_twist + _strafe, _wobble.z + cos(_phase) * 0.04 * k)
	var torso_x := -0.09 * k - lean + breathe - 0.18 * land
	_torso.rotation = Vector3(lerpf(torso_x, 0.42, _slide), -hip_twist * 1.6 - _strafe * 0.8, -shift * 0.6 - cos(_phase) * 0.035 * k)
	_torso.scale = Vector3(1.0 + breathe, 1.0 + breathe * 0.6 - land * 0.04, 1.0 + breathe)
	var want := -0.22 * k - absf(sin(_phase * 2.0)) * 0.08 * k - 0.6 * _air * (1.0 if vy < 0.0 else 0.25) + 0.25 * land
	_tail_swing = lerpf(_tail_swing, want, clampf(dt * 6.0, 0.0, 1.0))
	_tails.rotation = Vector3(lerpf(_tail_swing, -0.95, _slide), -hip_twist * 0.5, sin(_life * 2.3) * 0.03 * (1.0 - idle * 0.5))
	# ---------------------------------------------------------------- arms
	var aim := PI * 0.5 + clampf(pitch, -1.2, 1.2) * 0.9
	var run_bob := sin(_phase * 2.0) * 0.05 * k
	# Gun arm (right, index 1): out front along your aim, settling with the stride.
	var r_sh := Vector3(aim + run_bob - _torso.rotation.x, 0.0, 0.0)
	var r_el := 0.12
	if relaxed:
		var hang := -sin(_phase) * 0.55 * k + breathe * 2.0 + 0.08
		r_sh = Vector3(lerpf(hang, 2.75, wave), 0.0, lerpf(0.08, 0.35, wave))
		r_el = lerpf(0.3 + k * 0.4, 0.4 + sin(_life * 11.0) * 0.45, wave)
	var two_hands := 1.0 if _weapon in [&"lever_rifle", &"coach_shotgun", &"blunderbuss", &"crank_gatling", &"elephant_gun"] else 0.0
	_two = move_toward(_two, two_hands * (1.0 - _slide * 0.5), dt * 4.0)
	# Free arm (left, index 0): swings against the left leg, elbow bent to run.
	var swing := -sin(_phase) * 0.6 * k * dir
	var flail := sin(_life * 11.0) * 0.6 * _air * (1.0 if vy < 0.0 else 0.3)
	var l_sh := Vector3(swing + 0.05 + flail * 0.4, 0.0, -0.06 - _air * 0.7 - 0.25 * land)
	var l_el := 0.25 + k * 0.55 + maxf(swing, 0.0) * 0.6
	# Two-handed guns: the left hand comes across onto the forend.
	l_sh = l_sh.lerp(Vector3(aim - 0.05 - _torso.rotation.x, -0.55, -0.05), _two)
	l_el = lerpf(l_el, 0.55, _two)
	# Slide: free hand trails down to the ground.
	l_sh = l_sh.lerp(Vector3(-0.5, 0.0, -0.55), _slide * (1.0 - _two))
	# Idle fidget: touch the hat brim.
	l_sh = l_sh.lerp(Vector3(2.35, 0.25, -0.35), fidget * (1.0 - _two))
	l_el = lerpf(l_el, 2.0, fidget * (1.0 - _two))
	_shoulders[1].rotation = r_sh + Vector3(0, 0, absf(_wobble.x) * 1.5)
	_elbows[1].rotation = Vector3(r_el, 0, 0)
	_shoulders[0].rotation = l_sh + Vector3(0, 0, -absf(_wobble.z) * 2.0)
	_elbows[0].rotation = Vector3(l_el, 0, 0)
	# Head follows your aim and glances around; nods into the fidget.
	_head.rotation = Vector3(clampf(pitch, -0.7, 0.7) - _torso.rotation.x - 0.12 * fidget, _head_yaw - _torso.rotation.y - _hips.rotation.y * 0.6, 0.0)
	_apply_action(dt)
	# Wobble spring (damped): floppy dummy reaction to hits.
	_wobble_vel += (-_wobble * 60.0 - _wobble_vel * 7.0) * dt
	_wobble += _wobble_vel * dt
	_head.rotation.z = -_wobble.z * 1.4
	if _model != null and is_inside_tree():
		_model.apply()


## Act out an interaction (harvest, plant, slots...). See DummyActions.
func play_action(id: StringName) -> void:
	if not DummyActions.has(id):
		return
	action = id
	action_t = 0.0


func _apply_action(dt: float) -> void:
	# Hands are busy: the gun goes away while acting (third person only).
	if not first_person:
		_gun_mi.visible = action == &""
	if action == &"":
		return
	var prev_t := action_t
	action_t += dt
	var dur := DummyActions.duration(action)
	# Sounds timed to the move (heard by everyone nearby).
	for cue: Array in DummyActions.SFX.get(action, []):
		var at := float(cue[0]) * dur
		if prev_t <= at and action_t > at and action_freeze < 0.0:
			Audio.play_at(cue[1], global_position + Vector3.UP * 0.9 - global_basis.z * 0.5, float(cue[2]))
	if action_freeze >= 0.0:
		action_t = action_freeze * dur
	if action_t >= dur:
		action = &""
		return
	# Ease in over 0.15 s and out over the last 0.2 s.
	_action_w = minf(smoothstep(0.0, 0.15, action_t), 1.0 - smoothstep(dur - 0.25, dur, action_t))
	DummyActions.pose(self, action, action_t / dur, _action_w)


## A quick bright flash (firing).
func flash() -> void:
	_mat.set_shader_parameter("flash_color", Palette.GLOW_YELLOW)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_mat.set_shader_parameter("flash_amount", v)
		if _model != null:
			_model.set_flash(Palette.GLOW_YELLOW, v), 0.6, 0.0, 0.15)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, part: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(part, _team, look)
	mi.material_override = _mat
	parent.add_child(mi)
	return mi


## Builds (and caches per team colour and look) each body part. Front is -Z.
static func _mesh(part: String, team: Color, look: Dictionary) -> ArrayMesh:
	var key := "%s|%s|%s" % [part, team.to_html(), DummyLook.key(look)]
	if _meshes.has(key):
		return _meshes[key]
	# The detailed body lives in DummyBuilder.
	var mesh := DummyBuilder.part(part, team, look)
	_meshes[key] = mesh
	return mesh
