extends Node
## Debug camera views for checking the polish effects (started by VfxPool when
## --vfxview=<name> is given). Places a camera, stages the scene, saves
## screenshots at the listed times, then quits:
##   godot --path . res://scenes/world.tscn -- --vfxview=deaths --vfxshot=C:/tmp/d.png --vfxat=2.2,4
## Views: tunnels, deaths, turrets, sky, life, airship, stress (adds --vfxbugs=N climbing bugs).
## --vfxhour=H holds the clock at H.

var world: Node
var _cam: Camera3D
var _t := 0.0
var _shots: Array[float] = []
var _taken := 0
var _hour := -1.0
var _events: Array = [] # [time, Callable]
var _view := ""


func _ready() -> void:
	_view = GameState.flag_value("--vfxview")
	var at := GameState.flag_value("--vfxat")
	for s in (at if at != "" else "3").split(","):
		_shots.append(s.to_float())
	if GameState.flag_value("--vfxhour") != "":
		_hour = GameState.flag_value("--vfxhour").to_float()
	await get_tree().process_frame
	await get_tree().process_frame
	world = get_tree().current_scene
	var hud := world.get("hud") as CanvasLayer
	if hud != null:
		hud.visible = false
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 900.0
	world.add_child(_cam)
	_cam.current = true
	if has_method("_view_" + _view):
		call("_view_" + _view)
	else:
		push_error("vfx_views: no view " + _view)


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	if _hour >= 0.0 and DayCycle.instance != null:
		DayCycle.instance.clock = _hour
		DayCycle.instance.set("_target", _hour)
		DayCycle.instance.set("_rate", 0.0)
	_cam.current = true
	for e: Array in _events.duplicate():
		if _t >= float(e[0]):
			_events.erase(e)
			(e[1] as Callable).call()
	if _taken < _shots.size() and _t >= _shots[_taken]:
		var path := GameState.flag_value("--vfxshot")
		if path != "":
			if _shots.size() > 1:
				path = path.get_basename() + "_%d.png" % _taken
			get_viewport().get_texture().get_image().save_png(path)
			print("[vfxview] saved ", path, " at t=%.1f fps %d" % [_t, Engine.get_frames_per_second()])
		_taken += 1
		if _taken >= _shots.size():
			get_tree().quit()


func _at(t: float, f: Callable) -> void:
	_events.append([t, f])


func _look(eye: Vector3, target: Vector3) -> void:
	_cam.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


func _bm() -> BugManager:
	return world.get("bugs") as BugManager


func _cliffs() -> CliffBuilder:
	return Bug.cliffs


# ------------------------------------------------------------------ views

## Bugs pouring out of the north tunnels across the floor.
func _view_tunnels() -> void:
	_look(Vector3(2.0, 9.0, 34.0), Vector3(-6.0, 1.0, 64.0))
	for k in 6:
		_at(0.3 + k * 0.5, func() -> void:
			for lane in 5:
				_bm().spawn_group(&"dust_mite", 3, WorldLayout.WEST, lane))


## A column of bugs on the west wall, all killed at once at t=2.
func _view_deaths() -> void:
	var cl := _cliffs()
	var target := cl.face_point(WorldLayout.WEST, 20.0, 0.0)
	_look(target + Vector3(16.0, 6.0, 9.0), target + Vector3(0, 0, 0))
	var ids: Array[StringName] = [&"rattler_beetle", &"wolf_spider", &"dust_mite", &"spitter_scorpion", &"brood_mother"]
	for i in 20:
		_bm().spawn_group(ids[i % ids.size()], 1, WorldLayout.WEST, 2, 14.0 + float(i % 5) * 3.0)
	_at(2.0, func() -> void:
		for b: Node in get_tree().get_nodes_in_group("bugs"):
			var bug := b as Bug
			if bug.is_alive():
				bug.health.take_damage(99999.0, "debug", -1))


## Turrets firing at a wave, some badly damaged (soot, smoke, embers).
func _view_turrets() -> void:
	var builds := world.get("builds") as BuildManager
	Economy.earn(WorldLayout.EAST, {&"scrap": 3000})
	for col: int in [4, 6, 8, 10, 12]:
		builds.build(&"gatling_post" if col % 4 == 0 else &"buffalo_rifle", WorldLayout.EAST, Vector2i(0, col))
	var cl := _cliffs()
	var p := cl.plateau_point(WorldLayout.EAST, 1.0, 8.0)
	_look(p + Vector3(5.0, 3.0, -9.0), p + Vector3(-2.0, 0.5, 0.0))
	for i in 40:
		_bm().spawn_group(&"rattler_beetle" if i % 3 == 0 else &"dust_mite", 1, WorldLayout.WEST, i % 5, 5.0 + float(i % 8) * 4.0)
	_at(1.0, func() -> void:
		var k := 0
		for t: Node in get_tree().get_nodes_in_group("turrets"):
			k += 1
			var h := t.get("health") as Health
			if k % 3 == 1:
				h.hp = h.max_hp * 0.45
			elif k % 3 == 2:
				h.hp = h.max_hp * 0.2)


func _view_sky() -> void:
	var cl := _cliffs()
	var p := cl.plateau_point(WorldLayout.EAST, 8.0, 0.0) + Vector3.UP * 2.0
	var yaw := float(GameState.flag_value("--vfxyaw")) if GameState.flag_value("--vfxyaw") != "" else 0.0
	var pitch := float(GameState.flag_value("--vfxpitch")) if GameState.flag_value("--vfxpitch") != "" else 12.0
	var dir := Vector3(0, 0, -1).rotated(Vector3.RIGHT, deg_to_rad(pitch)).rotated(Vector3.UP, deg_to_rad(yaw))
	_look(p, p + dir * 10.0)
	if GameState.flag_value("--vfxcam") == "moon":
		# Face the moon (the sun light doubles as it): look back along the light.
		_at(0.5, func() -> void:
			var to_moon := DayCycle.instance.sun.global_basis.z.normalized()
			_look(p, p + (to_moon - Vector3.UP * 0.25) * 10.0))


## Tumbleweeds, vultures, a dust devil and the birds scattering.
func _view_life() -> void:
	var cl := _cliffs()
	var p := cl.plateau_point(WorldLayout.WEST, 2.0, -20.0) + Vector3.UP * 4.0
	_look(p, Vector3(0.0, 40.0, 20.0))
	var life := (world.get("vfx") as Node).get("canyon_life") as Node
	_at(0.5, func() -> void:
		life.call("scatter_birds")
		life.set("_devil_next", 0.0))
	_at(2.5, func() -> void:
		_look(p + Vector3(0, 0, 0), Vector3(0.0, 2.0, 10.0)))


func _view_airship() -> void:
	var ring := Airship.ring_position()
	var at := GameState.flag_value("--vfxcam")
	if at == "shadow":
		_look(ring + Vector3(60.0, 20.0, 60.0), Vector3(ring.x, 30.0, ring.z - 20.0))
	elif at == "close":
		_look(ring + Vector3(40.0, 5.0, 30.0), ring + Vector3(0, 6.0, -20.0))
	else:
		var cl := _cliffs()
		_look(cl.plateau_point(WorldLayout.EAST, 12.0, -5.0) + Vector3.UP * 2.0, ring + Vector3(0, 10.0, -20.0))


## Lots of bugs climbing plus turrets killing them (perf check with all effects).
func _view_stress() -> void:
	var n := int(GameState.flag_value("--vfxbugs")) if GameState.flag_value("--vfxbugs") != "" else 300
	var builds := world.get("builds") as BuildManager
	for cid in 2:
		Economy.earn(cid, {&"scrap": 3000})
		for col: int in [3, 6, 9, 12, 15]:
			builds.build(&"gatling_post", cid, Vector2i(0, col))
	var ids: Array = Defs.active_bug_ids()
	ids = ids.filter(func(id: StringName) -> bool: return Defs.bug(id).behavior != BugDef.Behavior.BOSS and not [&"locust", &"hive_drone"].has(id)) # every boss (and their minions) out: the same mix as before the bosses
	for i in n:
		_bm().spawn_group(ids[i % ids.size()], 1, i % 2, i % 5, float(i % 7) * 4.0)
	var cl := _cliffs()
	var p := cl.plateau_point(WorldLayout.EAST, 3.0, 0.0) + Vector3.UP * 2.0
	_look(p, cl.face_point(WorldLayout.WEST, 25.0, 0.0))
	var frames := [0, 0.0]
	_at(3.0, func() -> void:
		frames[0] = Engine.get_frames_drawn()
		frames[1] = Time.get_ticks_msec())
	_at(9.0, func() -> void:
		var fps := float(Engine.get_frames_drawn() - int(frames[0])) / ((Time.get_ticks_msec() - float(frames[1])) / 1000.0)
		print("[vfxview] stress %d bugs (alive %d): avg fps %.0f" % [n, get_tree().get_nodes_in_group("bugs").size(), fps]))


## The east homestead after dark: porch lanterns, lit windows, lantern posts.
func _view_house() -> void:
	var builds := world.get("builds") as BuildManager
	Economy.earn(WorldLayout.EAST, {&"scrap": 3000})
	var house: Node3D = null
	for h: Node in get_tree().get_nodes_in_group("homesteads"):
		if int(h.get("cliff_id")) == WorldLayout.EAST:
			house = h as Node3D
	for c: Vector2i in [Vector2i(7, 6), Vector2i(7, 14), Vector2i(1, 8)]:
		builds.build(&"lantern_post", WorldLayout.EAST, c)
	if house == null:
		return
	var front := -house.global_basis.z
	var side := house.global_basis.x
	_look(house.global_position + front * 15.0 + side * 6.0 + Vector3.UP * 4.0, house.global_position + Vector3.UP * 2.5)


## Down the length of the canyon from the east lip (long shadows at golden hour).
func _view_canyon() -> void:
	var cl := _cliffs()
	var p := cl.plateau_point(WorldLayout.EAST, 2.0, -40.0) + Vector3.UP * 6.0
	_look(p, cl.face_point(WorldLayout.WEST, 6.0, 40.0))


## Big bugs and a boss climbing the west wall: rock chips off the face.
func _view_rocks() -> void:
	var cl := _cliffs()
	var target := cl.face_point(WorldLayout.WEST, 18.0, 0.0)
	_look(target + Vector3(18.0, 4.0, 10.0), target)
	for i in 4:
		_bm().spawn_group(&"brood_mother" if i % 2 == 0 else &"rattler_beetle", 1, WorldLayout.WEST, 1 + i % 3, 6.0 + float(i) * 3.0)
