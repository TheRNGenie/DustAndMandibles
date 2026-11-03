extends BossBrain
## The Bone Collector, a burying beetle. It stops at the corpse pile at the foot
## of its cliff to eat the husks there, and snatches up bugs killed near it:
## every meal heals it (1.75% of its health) and it grows, up to 1.35x (growth is
## replicated). The counter: clear the pile before it arrives (shoot it apart,
## blasts and fire burn husks) and don't kill swarms right next to it.

const Rules := preload("res://scenes/bugs/bosses/_rules_b.gd")
const MEAL_HEAL := 0.0175
## Husks within this of it are in reach at the cliff foot.
const PILE_REACH := 6.0
## Bugs killed this close are snatched up.
const KILL_REACH := 9.0
const EAT_EVERY := 0.7
const KILL_MEAL_CD := 0.4
## It gives up on the pile after feeding this long (so it can't stall forever).
const MAX_FEED := 14.0

## Host.
var _eat_cd := 0.0
var _kill_cd := 0.0
var _fed := 0.0
var _meals := 0
## Every peer.
var _chew := 0.0


func think(delta: float) -> bool:
	if not bug.is_alive():
		return false
	_kill_cd -= delta
	var at_foot := bug.state == Bug.State.CROSSING or (bug.state == Bug.State.CLIMBING and bug.climb_y < 2.5)
	var pile := CorpsePile.instance
	if not at_foot or pile == null or _fed >= MAX_FEED:
		return false
	var foot := bug.global_position
	foot.y = Bug.cliffs.floor_height(foot.x, foot.z) if Bug.cliffs != null else 0.0
	if pile.count_near(bug.cliff_id, foot, PILE_REACH) <= 0:
		return false
	# Husks in reach: it stops and eats.
	_fed += delta
	_eat_cd -= delta
	if _eat_cd <= 0.0:
		_eat_cd = EAT_EVERY
		pile.clear_near.rpc(bug.cliff_id, foot, PILE_REACH, 1, true)
		_meal(foot)
	return true


func on_bug_died(dead: Bug) -> void:
	if _kill_cd > 0.0 or not is_instance_valid(dead) or dead.boss != null:
		return
	if dead.global_position.distance_to(bug.global_position) > KILL_REACH:
		return
	_kill_cd = KILL_MEAL_CD
	_meal(dead.global_position)


func _meal(at: Vector3) -> void:
	_meals += 1
	bug.health.heal(bug.health.max_hp * MEAL_HEAL)
	bug.grow = Rules.grown(bug.grow)
	send(&"eat", [at, bug.grow])


func on_event(kind: StringName, args: Array) -> void:
	if kind != &"eat":
		return
	var at: Vector3 = args[0]
	bug.grow = float(args[1])
	var mouth := world(Vector3(0, 0.02, -1.08))
	if fx() != null:
		fx().lob(at + Vector3.UP * 0.3, mouth, 0.3, Palette.BONE)
	Audio.play_at(&"hook_bite", mouth, 0.0, 0.7)
	_chew = 0.6


func visual(delta: float) -> void:
	age += delta
	if _chew > 0.0:
		_chew -= delta
		if _chew <= 0.0:
			# A crunch of bone and a heal flash as it swallows.
			var mouth := world(Vector3(0, 0.02, -1.08))
			if fx() != null:
				fx().pop(mouth, Palette.BONE, 0.7)
			Audio.play_at(&"loot_crack", mouth, -4.0, 0.6)


func hud_status() -> String:
	if bug.grow > 1.001:
		return "FED x%.2f" % bug.grow
	return ""
