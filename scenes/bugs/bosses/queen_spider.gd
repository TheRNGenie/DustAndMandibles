extends BossBrain
## The Queen Spider: while she climbs, every ~9 s her spinnerets glow and she
## rears up (1.4 s telegraph), then spits a glob of silk at one of the turrets
## shooting her. A webbed turret holds fire for 8 s, or until players shoot the
## cocoon apart. Counter: keep a gun near your turrets and free them.

const INTERVAL := 9.0
const CHARGE := 1.4
const FLIGHT := 0.9
const WEB_SECONDS := 8.0
const WEB_HP := 60.0
const MAX_WEBS := 3
## Spinneret tip on the body (unscaled body units).
const TIP := Vector3(0, 0.42, 1.55)

var _cd := 6.0
var _charge := 0.0
var _glow: MeshInstance3D
var _rear := 0.0


func _attach() -> void:
	_glow = BossFx.glow_blob(0.75, Color(1.0, 0.97, 0.9))
	bug.add_child(_glow)
	_glow.position = local(TIP)
	BossFx.set_glow(_glow, 0.0)


func think(delta: float) -> bool:
	if not bug.is_climbing() or bug.climb_y < 6.0:
		return false
	if _charge > 0.0:
		_charge -= delta
		if _charge <= 0.0:
			_spit()
		return false
	_cd -= delta
	if _cd <= 0.0:
		var target := _pick()
		if target == null:
			_cd = 2.0
			return false
		_cd = INTERVAL
		_charge = CHARGE
		bug.set_meta("queen_target", target.get_path())
		send(&"charge", [CHARGE])
	return false


func _pick() -> Turret:
	var fx := fx()
	if fx == null:
		return null
	var webbed := 0
	var options: Array[Turret] = []
	for t in far_turrets(110.0):
		if fx.is_webbed(t):
			webbed += 1
		else:
			options.append(t)
	if options.is_empty() or webbed >= MAX_WEBS:
		return null
	# The nearest free turret: the one hurting her most.
	options.sort_custom(func(a: Turret, b: Turret) -> bool:
		return a.global_position.distance_squared_to(bug.global_position) < b.global_position.distance_squared_to(bug.global_position))
	return options[0]


func _spit() -> void:
	var path: NodePath = bug.get_meta("queen_target", NodePath())
	var t := bug.get_node_or_null(path) as Turret
	if t == null or not bug.is_alive():
		return
	send(&"spit", [t.global_position + Vector3.UP * 1.0])
	var ref: WeakRef = weakref(t)
	bug.get_tree().create_timer(FLIGHT).timeout.connect(func() -> void:
		var tt := ref.get_ref() as Turret
		if tt != null and is_instance_valid(tt) and fx() != null:
			fx().web(tt, WEB_SECONDS, WEB_HP))


func on_event(kind: StringName, args: Array) -> void:
	match kind:
		&"charge":
			_charge = float(args[0]) # every peer animates the wind-up
			Audio.play_at(&"spider_screech", world(TIP), 2.0, 0.7)
		&"spit":
			_charge = 0.0
			_rear = 1.0
			if fx() != null:
				fx().lob(world(TIP), args[0], FLIGHT, BossFx.WEB_COLOR)
			Audio.play_at(&"harpoon", world(TIP), 0.0, 0.8)


func visual(delta: float) -> void:
	age += delta
	if not host() and _charge > 0.0:
		_charge = maxf(_charge - delta, 0.0)
	# The wind-up: spinnerets glow brighter and pulse, she rears her abdomen.
	var k := 0.0
	if _charge > 0.0:
		k = 1.0 - _charge / CHARGE
	BossFx.set_glow(_glow, k * (0.65 + 0.35 * sin(age * 30.0)))
	if _glow != null:
		_glow.scale = Vector3.ONE * (0.6 + k * 0.9)
	_rear = move_toward(_rear, 0.0, delta * 2.0)


func hud_status() -> String:
	return "SPINNING SILK" if _charge > 0.0 else ""
