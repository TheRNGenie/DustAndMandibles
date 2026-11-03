extends BossBrain
## The Locust Swarm Lord: flies out of a tunnel, rises over the middle of the
## canyon and drifts there in slow loops, just above the lips. Every ~8 s his
## swarm sac swells and glows (1.5 s telegraph) and he looses a cloud of six
## locusts that go for the crops and water. He never lands: anti-air turrets
## and players' guns have to bring him down, and the clouds stop when he falls.

const INTERVAL := 8.0
const CHARGE := 1.5
const CLOUD := 6
const MAX_LOCUSTS := 30
const HOVER := 7.0
## The swarm sac under his abdomen (body units).
const SAC := Vector3(0, -0.12, 0.55)

var _cd := 5.0
var _charge := 0.0
var _clock := 0.0
var _glow: MeshInstance3D
var _side := 0


func _attach() -> void:
	_glow = BossFx.glow_blob(0.55, Color("#FFB347"))
	bug.add_child(_glow)
	_glow.position = local(SAC)
	BossFx.set_glow(_glow, 0.0)
	_clock = randf() * 10.0


func think(delta: float) -> bool:
	if bug.state != Bug.State.FLYING:
		return false
	_clock += delta
	# Drift in a slow figure eight over the middle of the gap.
	var z := sin(_clock * 0.11) * 13.0
	var w := Bug.cliffs.plateau_point(WorldLayout.WEST, 0.0, z)
	var e := Bug.cliffs.plateau_point(WorldLayout.EAST, 0.0, z)
	var mid := (w + e) * 0.5
	var across := (e - w).normalized()
	var goal := mid + across * sin(_clock * 0.22) * 5.0
	goal.y = WorldLayout.CLIFF_HEIGHT + HOVER + sin(_clock * 0.7) * 1.2
	var to := goal - bug.ground_pos
	var step := bug.def.walk_speed * bug.speed() * delta
	bug.ground_pos += to.normalized() * minf(step, to.length())
	# Up out of the canyon first, he climbs quicker.
	if bug.ground_pos.y < WorldLayout.CLIFF_HEIGHT:
		bug.ground_pos.y += step * 1.5
	if bug.ground_pos.y < WorldLayout.CLIFF_HEIGHT - 10.0:
		return true
	if _charge > 0.0:
		_charge -= delta
		if _charge <= 0.0:
			_release()
	else:
		_cd -= delta
		if _cd <= 0.0:
			_cd = INTERVAL
			if count_alive(&"locust") < MAX_LOCUSTS:
				_charge = CHARGE
				send(&"charge", [CHARGE])
	return true


func _release() -> void:
	if not bug.is_alive():
		return
	send(&"burst", [world(SAC)])
	var bm := BugManager.instance
	for i in CLOUD:
		# Half the cloud goes for each cliff.
		_side += 1
		var cliff := _side % 2
		var p := world(SAC) + Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 0.5), randf_range(-1.5, 1.5))
		bm.spawn_at(&"locust", cliff, randi() % WorldLayout.LANE_Z.size(), p.z, 0.0, Bug.State.FLYING, p)


func on_event(kind: StringName, args: Array) -> void:
	match kind:
		&"charge":
			_charge = float(args[0])
			Audio.play_at(&"rustle", world(SAC), 4.0, 0.6)
		&"burst":
			_charge = 0.0
			var at: Vector3 = args[0]
			if fx() != null:
				fx().pop(at, Color("#9DAA3C"), 2.4)
			Audio.play_at(&"rustle", at, 6.0, 1.3)
			Audio.play_at(&"skitter", at, 4.0, 1.4)


func visual(delta: float) -> void:
	age += delta
	if not host() and _charge > 0.0:
		_charge = maxf(_charge - delta, 0.0)
	var k := 0.0
	if _charge > 0.0:
		k = 1.0 - _charge / CHARGE
	BossFx.set_glow(_glow, 0.2 + k * (0.6 + 0.2 * sin(age * 24.0)))
	if _glow != null:
		_glow.scale = Vector3.ONE * (0.8 + k * 0.7 + sin(age * 3.0) * 0.05)


func hud_status() -> String:
	return "SWARM COMING" if _charge > 0.0 else ""
