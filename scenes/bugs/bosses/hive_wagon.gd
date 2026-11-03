extends BossBrain
## The Hive Wagon: a stagecoach of a bug with a wasp hive strapped on its back.
## While it's under fire the hive lets loose up to 3 drones every ~2.2 s, and a
## last swarm of 6 when it dies (never more than ~36 drones alive). The counter:
## kill it fast, then clear the drones with splash and fire.

const Rules := preload("res://scenes/bugs/bosses/_rules_b.gd")
const DRONE := &"hive_drone"
const BURST_EVERY := 2.2
const PER_BURST := 3
const ON_DEATH := 6
const CAP := 36
## Counts as "under fire" this long after a hit.
const HIT_WINDOW := 1.2
const HONEY := Color("#F2A93B")

## Host.
var _since_hit := 99.0
var _cd := 1.0
## Every peer: the hive glows and rattles while it's being hurt.
var _angry := 0.0
var _last_hp := -1.0
var _glow: MeshInstance3D


func _attach() -> void:
	_glow = BossFx.glow_blob(0.5, HONEY)
	_glow.name = "HiveGlow"
	bug.add_child(_glow)
	_glow.position = local(Vector3(0, 1.15, 0.12))
	BossFx.set_glow(_glow, 0.0)


func body_damage(damage: float, _point: Vector3, _source: String, _source_cliff: int) -> float:
	_since_hit = 0.0
	return damage


func think(delta: float) -> bool:
	_since_hit += delta
	_cd -= delta
	if _since_hit < HIT_WINDOW and _cd <= 0.0 and bug.is_alive() and not bug.is_hidden():
		_cd = BURST_EVERY
		_release(Rules.burst_size(count_alive(DRONE), PER_BURST, CAP))
	return false


func on_death(_source: String, _source_cliff: int) -> void:
	_release(Rules.burst_size(count_alive(DRONE), ON_DEATH, CAP))


func _release(n: int) -> void:
	if n <= 0:
		return
	spawn_minions(DRONE, n, 2.5)
	send(&"burst", [n])


func on_event(kind: StringName, args: Array) -> void:
	if kind != &"burst":
		return
	var top := world(Vector3(0, 1.5, 0.12))
	if fx() != null:
		fx().pop(top, HONEY, 0.9 + 0.15 * float(args[0]))
		fx().dust(top, Vector3.UP, 0.8)
	Audio.play_at(&"rustle", top, 0.0, 1.5)
	Audio.play_at(&"skitter", top, -2.0, 1.6)
	_angry = 1.0


func visual(delta: float) -> void:
	age += delta
	var hp := bug.health.hp
	if _last_hp >= 0.0 and hp < _last_hp - 0.01:
		_angry = minf(_angry + 0.25, 1.0)
	_last_hp = hp
	_angry = maxf(_angry - delta * 0.6, 0.0)
	if _glow != null:
		_glow.position = local(Vector3(0, 1.15, 0.12))
		# Pulsing honey light and a rattle while it's being hurt: the hive is stirring.
		BossFx.set_glow(_glow, _angry * (0.35 + 0.25 * sin(age * 18.0)))
		_glow.position += Vector3(sin(age * 41.0), 0, cos(age * 37.0)) * 0.05 * _angry


func hud_status() -> String:
	return "HIVE STIRRING" if _angry > 0.3 else ""
