extends BossBrain
## The Acid Matriarch: climbs to about halfway, clings there for up to 30 s
## spitting, then climbs on. Every ~7 s her tail bulb swells and glows (1.2 s
## telegraph) and she spits acid at one of the turrets shooting her: the acid
## sticks and eats the turret for 14 s. A Water Cannon washes acid off every
## turret near it whenever it fires, and a Water Cannon hit on her rinses out her
## sac (her next spit is put off).

const INTERVAL := 7.0
const CHARGE := 1.2
const FLIGHT := 1.1
const ACID_SECONDS := 14.0
const ACID_DPS := 3.5
const CLING_AT := 0.5
const CLING_TIME := 30.0

var _cd := 4.0
var _charge := 0.0
var _clung := 0.0
var _glow: MeshInstance3D
var _bulb := Vector3.ZERO
var _last_target: NodePath


func _attach() -> void:
	_bulb = bug.spec.get("bulb", Vector3(0, 1.3, 0.3)) # body units (BugBuilder leaves extra keys unscaled)
	_glow = BossFx.glow_blob(0.34, Palette.ACID_GREEN)
	bug.add_child(_glow)
	_glow.position = local(_bulb)
	BossFx.set_glow(_glow, 0.0)


func think(delta: float) -> bool:
	if not bug.is_climbing() or bug.climb_y < 8.0:
		return false
	var clinging := bug.climb_y >= WorldLayout.CLIFF_HEIGHT * CLING_AT and _clung < CLING_TIME
	if clinging:
		_clung += delta
	if _charge > 0.0:
		_charge -= delta
		if _charge <= 0.0:
			_spit()
	else:
		_cd -= delta
		if _cd <= 0.0:
			if far_turrets(115.0).is_empty():
				_cd = 2.0
			else:
				_cd = INTERVAL
				_charge = CHARGE
				send(&"charge", [CHARGE])
	# Clinging: she holds still (the usual climber is skipped).
	return clinging


func _spit() -> void:
	var fx := fx()
	if fx == null or not bug.is_alive():
		return
	var options := far_turrets(115.0)
	if options.is_empty():
		return
	# Prefer a turret that isn't already dripping, and not the last one.
	var clean := options.filter(func(t: Turret) -> bool: return not fx.has_acid(t) and t.get_path() != _last_target)
	var pool: Array = clean if not clean.is_empty() else options
	var t := pool[randi() % pool.size()] as Turret
	_last_target = t.get_path()
	send(&"spit", [t.global_position + Vector3.UP])
	var ref: WeakRef = weakref(t)
	var dps := ACID_DPS * Defs.WAVE_CONFIG.damage_scale(GameState.wave)
	bug.get_tree().create_timer(FLIGHT).timeout.connect(func() -> void:
		var tt := ref.get_ref() as Turret
		if tt != null and is_instance_valid(tt) and BossFx.instance != null:
			BossFx.instance.acid(tt, ACID_SECONDS, dps))


## Host: a Water Cannon hit rinses her acid sac: the spit she's winding up is
## lost, and the next one comes later.
func on_water_hit(_t: Turret) -> void:
	if _charge > 0.0 or _cd < 3.0:
		_charge = 0.0
		_cd = maxf(_cd, 4.0)
		send(&"rinse", [])


func on_event(kind: StringName, args: Array) -> void:
	match kind:
		&"charge":
			_charge = float(args[0])
			Audio.play_at(&"beetle_hiss", world(_bulb), 2.0, 1.35)
		&"spit":
			_charge = 0.0
			if fx() != null:
				fx().lob(world(_bulb), args[0], FLIGHT, Palette.ACID_GREEN)
			Audio.play_at(&"acid_spit", world(_bulb), 3.0, 0.75)
		&"rinse":
			_charge = 0.0
			if fx() != null:
				fx().dust(world(_bulb), Vector3.UP, 0.8)
			Audio.play_at(&"water_pour", world(_bulb), 0.0, 1.3)


func visual(delta: float) -> void:
	age += delta
	if not host() and _charge > 0.0:
		_charge = maxf(_charge - delta, 0.0)
	var k := 0.0
	if _charge > 0.0:
		k = 1.0 - _charge / CHARGE
	BossFx.set_glow(_glow, 0.15 + k * (0.6 + 0.25 * sin(age * 26.0)))
	if _glow != null:
		_glow.scale = Vector3.ONE * (0.7 + k * 0.8)


func hud_status() -> String:
	return "SPITTING" if _charge > 0.0 else ""
