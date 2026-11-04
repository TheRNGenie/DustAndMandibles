extends BossBrain
## The Hive Queen (Story, chapter 8: The Queen). The mother of the Hive climbs
## with everything she has, in three phases by her health:
## 1. Every ~16 s her brood sac glows amber through her plates (2 s telegraph) and she
##    calls a brood up the wall beside her (wolf spiders). Every ~10 s her mouth
##    glows (1.2 s) and she spits amber resin at one of the turrets shooting
##    her: it gums the turret shut like the Queen Spider's silk (shoot it free).
## 2. Below 60%: faster, scorpions join the brood, and every ~18 s she rears and
##    SHRIEKS: a ring glows round the tightest bunch of turrets on the far
##    cliff for 2.5 s, then every turret inside is stunned for 3.5 s. She stops
##    climbing while she shrieks (pour it in).
## 3. Below 30%: she sheds her plates: climbs 60% faster, takes 30% more
##    damage, broods of hive drones every ~9 s, shrieks every ~13 s.
## Her crown jewel is the weak spot; the front of her abdomen is plated
## (BugDef.front_armor). Pure numbers in _rules_queen.gd.

const Rules := preload("res://scenes/bugs/bosses/_rules_queen.gd")
const Cicada := preload("res://scenes/bugs/bosses/_rules_b.gd")
const BROOD_CHARGE := 2.0
const SPIT_CHARGE := 1.2
const SPIT_FLIGHT := 1.0
const RESIN_SECONDS := 7.0
const RESIN_HP := 90.0
const MAX_GUMMED := 3
const SHRIEK_CHARGE := 2.5
const SHRIEK_RADIUS := 7.0
const SHRIEK_STUN := 3.5
const REACH := 130.0
const AMBER := Color("#FFB238")
const RESIN := Color("#E8A33A")
const SHRIEK := Color("#FF6A3D")

## Host.
var _phase := 1
var _brood_cd := 7.0
var _spit_cd := 5.0
var _shriek_cd := 6.0
var _charging := &""
var _charge := 0.0
var _center := Vector3.ZERO
var _target: NodePath
## Every peer (from the host's events).
var _show := &""
var _show_t := 0.0
var _enraged := false
var _crown: MeshInstance3D
var _belly: MeshInstance3D
var _mouth: MeshInstance3D


func _attach() -> void:
	_crown = BossFx.glow_blob(0.3, AMBER)
	bug.add_child(_crown)
	_belly = BossFx.glow_blob(1.4, AMBER)
	bug.add_child(_belly)
	_mouth = BossFx.glow_blob(0.4, RESIN)
	bug.add_child(_mouth)
	_place_glows()
	BossFx.set_glow(_belly, 0.0)
	BossFx.set_glow(_mouth, 0.0)


func _place_glows() -> void:
	_crown.position = local(bug.spec.get("crown", Vector3.ZERO))
	_belly.position = local(bug.spec.get("belly", Vector3.ZERO))
	_mouth.position = local(bug.spec.get("mouth_at", Vector3.ZERO))


# ------------------------------------------------------------------ host

func think(delta: float) -> bool:
	if not bug.is_alive():
		return false
	var p := Rules.phase(bug.health.hp / maxf(bug.health.max_hp, 1.0))
	if p != _phase:
		_phase = p
		send(&"phase", [p])
		match p:
			2:
				notify_defenders("The Hive Queen is hurt and angry! Watch for her shriek ring: spread your turrets.")
			3:
				notify_defenders("The Hive Queen sheds her plates! She's climbing fast: everything you have, now!")
	if _charging != &"":
		_charge -= delta
		if _charge <= 0.0:
			var what := _charging
			_charging = &""
			match what:
				&"brood":
					_call_brood()
				&"spit":
					_spit()
				&"shriek":
					_shriek()
		return what_holds()
	if not (bug.state in [Bug.State.CLIMBING, Bug.State.CRESTING, Bug.State.BREACHING]):
		return false
	_brood_cd -= delta
	_spit_cd -= delta
	if Rules.shriek_every(_phase) > 0.0:
		_shriek_cd -= delta
	if _shriek_cd <= 0.0 and Rules.shriek_every(_phase) > 0.0:
		var pts: Array[Vector3] = []
		for t in far_turrets(REACH):
			pts.append(t.global_position)
		if pts.is_empty():
			_shriek_cd = 3.0
		else:
			_shriek_cd = Rules.shriek_every(_phase)
			_center = Cicada.densest(pts, SHRIEK_RADIUS)
			_begin(&"shriek", SHRIEK_CHARGE, [_center])
			return true
	if _brood_cd <= 0.0:
		_brood_cd = Rules.brood_every(_phase)
		_begin(&"brood", BROOD_CHARGE, [])
		return false
	if _spit_cd <= 0.0 and (not bug.is_climbing() or bug.climb_y > 4.0):
		var t := _pick()
		if t == null:
			_spit_cd = 2.0
		else:
			_spit_cd = Rules.spit_every(_phase)
			_target = t.get_path()
			_begin(&"spit", SPIT_CHARGE, [])
	return false


## While she winds up a shriek she holds still on the wall.
func what_holds() -> bool:
	return _charging == &"shriek"


func _begin(what: StringName, seconds: float, args: Array) -> void:
	_charging = what
	_charge = seconds
	send(&"charge", [what, seconds] + args)


func _call_brood() -> void:
	var near := 0
	for c in bug.get_parent().get_children():
		var b := c as Bug
		if b != null and b != bug and b.is_alive() and b.cliff_id == bug.cliff_id and b.global_position.distance_to(bug.global_position) < 18.0:
			near += 1
	var called := 0
	for e: Array in Rules.brood(_phase):
		var n := Rules.room(near + called, int(e[1]))
		if n > 0:
			spawn_minions(e[0], n, 3.0)
			called += n
	send(&"brood", [called])
	if called > 0:
		notify_defenders("The Hive Queen called up a brood of %d!" % called)


func _pick() -> Turret:
	var f := fx()
	if f == null:
		return null
	var gummed := 0
	var options: Array[Turret] = []
	for t in far_turrets(110.0):
		if f.is_webbed(t):
			gummed += 1
		else:
			options.append(t)
	if options.is_empty() or gummed >= MAX_GUMMED:
		return null
	# The heaviest hitter near her: the nearest, with a little luck.
	options.sort_custom(func(a: Turret, b: Turret) -> bool:
		return a.global_position.distance_squared_to(bug.global_position) < b.global_position.distance_squared_to(bug.global_position))
	return options[mini(randi() % 2, options.size() - 1)]


func _spit() -> void:
	var t := bug.get_node_or_null(_target) as Turret
	if t == null or not bug.is_alive():
		return
	send(&"spit", [t.global_position + Vector3.UP * 1.0])
	var ref: WeakRef = weakref(t)
	var hp := RESIN_HP * Defs.WAVE_CONFIG.damage_scale(GameState.wave) * 0.5
	bug.get_tree().create_timer(SPIT_FLIGHT).timeout.connect(func() -> void:
		var tt := ref.get_ref() as Turret
		if tt != null and is_instance_valid(tt) and fx() != null:
			fx().web(tt, RESIN_SECONDS, hp))


func _shriek() -> void:
	var n := 0
	for t in far_turrets(REACH + SHRIEK_RADIUS):
		if t.global_position.distance_to(_center) <= SHRIEK_RADIUS and fx() != null:
			fx().stun(t, SHRIEK_STUN)
			n += 1
	send(&"shriek", [_center])
	if n > 0:
		notify_defenders("The Hive Queen's shriek stunned %d turret%s!" % [n, "" if n == 1 else "s"])


func body_damage(damage: float, _point: Vector3, _source: String, _source_cliff: int) -> float:
	return damage * Rules.damage_taken(_phase)


func speed_mult() -> float:
	return Rules.speed(_phase if host() else (3 if _enraged else 1))


func on_death(source: String, _source_cliff: int) -> void:
	notify_defenders("%s brought down THE HIVE QUEEN!" % who(source))
	send(&"dead", [])


# ------------------------------------------------------------------ every peer

func on_event(kind: StringName, args: Array) -> void:
	var f := fx()
	match kind:
		&"phase":
			_enraged = int(args[0]) >= 3
			Audio.play_at(&"queen_shriek", world(bug.spec.get("mouth_at", Vector3.ZERO)), 4.0, 1.0)
			if f != null:
				f.shake(bug.global_position, 0.7)
				if _enraged:
					# Plates fly off: a burst of chips and gold.
					for k in 6:
						f.pop(bug.global_position + Vector3(randf_range(-2, 2), randf_range(0, 3), randf_range(-2, 2)), Color("#3B1A14"), 1.2)
					f.pop(world(bug.spec.get("crown", Vector3.ZERO)), AMBER, 2.0)
		&"charge":
			_show = args[0]
			_show_t = float(args[1])
			match _show:
				&"brood":
					Audio.play_at(&"beetle_hiss", bug.global_position, 4.0, 0.5)
				&"spit":
					Audio.play_at(&"queen_shriek", world(bug.spec.get("mouth_at", Vector3.ZERO)), -2.0, 1.15)
				&"shriek":
					if f != null:
						f.ground_ring(args[2], SHRIEK_RADIUS, SHRIEK, SHRIEK_CHARGE)
					Audio.play_at(&"bell", args[2], -2.0, 0.55)
		&"brood":
			_show = &""
			if f != null:
				f.pop(world(bug.spec.get("belly", Vector3.ZERO)), AMBER, 2.4)
				f.dust(bug.global_position, Vector3.UP, 2.5)
			Audio.play_at(&"beetle_hiss", bug.global_position, 6.0, 0.7)
		&"spit":
			_show = &""
			if f != null:
				f.lob(world(bug.spec.get("mouth_at", Vector3.ZERO)), args[0], SPIT_FLIGHT, RESIN)
			Audio.play_at(&"harpoon", bug.global_position, 2.0, 0.6)
		&"shriek":
			_show = &""
			var head := world(bug.spec.get("mouth_at", Vector3.ZERO))
			if f != null:
				f.shockwave(head, (args[0] as Vector3) + Vector3.UP, SHRIEK_RADIUS, SHRIEK)
				f.shake(args[0], 0.6)
			Audio.play_at(&"queen_shriek", head, 6.0, 0.95)
			Audio.play_at(&"thunder", args[0], 2.0, 1.2)
		&"dead":
			if f != null:
				f.shake(bug.global_position, 1.0)
				f.pop(world(bug.spec.get("crown", Vector3.ZERO)), AMBER, 3.0)
				f.rocks(bug.global_position, 2.0)
			Audio.play_at(&"queen_shriek", bug.global_position, 6.0, 0.85)


func visual(delta: float) -> void:
	age += delta
	if _show_t > 0.0:
		_show_t -= delta
		if _show_t <= 0.0 and not host():
			_show = &""
	if host() and _charging == &"":
		_show = &""
	if _crown == null:
		return
	_place_glows()
	# The crown jewel blazes when she's enraged or shrieking.
	var crown := 0.0
	if _enraged:
		crown = 0.55 + 0.25 * sin(age * 9.0)
	if _show == &"shriek":
		crown = 0.8 + 0.2 * sin(age * 40.0)
	BossFx.set_glow(_crown, crown)
	_crown.scale = Vector3.ONE * (0.8 + crown * 0.5)
	var belly := 0.0
	if _show == &"brood":
		belly = 0.55 + 0.45 * sin(age * 16.0)
	BossFx.set_glow(_belly, belly)
	_belly.scale = Vector3.ONE * (0.7 + belly * 0.6)
	var mouth := 0.0
	if _show == &"spit":
		mouth = 0.6 + 0.4 * sin(age * 30.0)
	BossFx.set_glow(_mouth, mouth)


func hud_status() -> String:
	match _show:
		&"brood":
			return "CALLING HER BROOD"
		&"spit":
			return "SPITTING RESIN"
		&"shriek":
			return "SHRIEKING"
	return "ENRAGED" if _enraged else ""
