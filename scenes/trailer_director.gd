class_name TrailerDirector
extends Node
## Stages one shot of the trailer (--trailer=<shot>): sets the time of day and
## weather, spawns bugs and builds, flies a camera along keyframes (or uses the
## player's own view for first-person shots), hides the HUD, then quits.
## Record with Godot's movie maker for frame-perfect video and audio:
##   godot --path . --write-movie out.avi --fixed-fps 30 res://scenes/world.tscn -- --trailer=opener
## tools/trailer/make_trailer.py records every shot and edits the trailer.

const WARM := 1.5

var world: Node3D
var shot := ""
var _cam: Camera3D
var _keys: Array = [] # [time, from, look_at]
var _dur := 4.0
var _t := -WARM
var _events: Array = [] # [time, Callable]
var _player: Player


func _ready() -> void:
	shot = GameState.flag_value("--trailer")
	Audio.play_music(&"")
	await get_tree().process_frame
	await get_tree().process_frame
	_player = world.call("local_player") as Player
	(world.get("hud") as CanvasLayer).visible = false
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 900.0
	world.add_child(_cam)
	call("_shot_" + shot)
	if not _keys.is_empty():
		_cam.current = true
		if shot != "dummies":
			_hide_player()
	_place_camera(0.0)


func _process(delta: float) -> void:
	_t += delta
	for e: Array in _events.duplicate():
		if _t >= float(e[0]):
			_events.erase(e)
			(e[1] as Callable).call()
	if not _keys.is_empty():
		_place_camera(maxf(_t, 0.0))
	if _t >= _dur and GameState.flag_value("--shot") == "":
		get_tree().quit()


func _place_camera(t: float) -> void:
	if _keys.is_empty():
		return
	var a: Array = _keys[0]
	var b: Array = _keys[_keys.size() - 1]
	for i in _keys.size() - 1:
		if t >= float(_keys[i][0]) and t <= float(_keys[i + 1][0]):
			a = _keys[i]
			b = _keys[i + 1]
			break
	var span := maxf(float(b[0]) - float(a[0]), 0.001)
	var k := clampf((t - float(a[0])) / span, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var pos := (a[1] as Vector3).lerp(b[1], k)
	var look := (a[2] as Vector3).lerp(b[2], k)
	_cam.global_transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)


func _hide_player() -> void:
	if _player != null:
		_player.rig.visible = false
		_player.gun.visible = false
		_player.global_position = Vector3(-75, 61, 30)


func _at(t: float, f: Callable) -> void:
	_events.append([t, f])


func _set_time(hour: float) -> void:
	DayCycle.instance.clock = hour
	DayCycle.instance.set("_target", hour)
	DayCycle.instance.set("_rate", 0.0)


func _set_weather(k: int) -> void:
	GameState._sync_phase(GameState.phase, GameState.time_left, GameState.wave, k)
	# Skip the slow weather blend: the shot starts in full weather.
	DayCycle.instance.set("_tint", DayCycle._weather_tint(k))
	DayCycle.instance.set("_fog_mult", [1.0, 1.0, 1.0, 1.0, 1.0, 9.0, 1.4, 11.0, 1.6][k])
	DayCycle.instance.set("_storm", [0.0, 0.25, 0.6, 0.95, 0.7, 0.4, 0.0, 0.5, 0.0][k])


func _bm() -> BugManager:
	return world.get("bugs") as BugManager


func _tools() -> DebugTools:
	return world.get_node("DebugTools") as DebugTools


func _swarm(cliff: int, ids: Array, low: float, high: float) -> void:
	var lane := 0
	for id: StringName in ids:
		_bm().spawn_group(id, 2, cliff, lane % 5, randf_range(low, high))
		lane += 1


# ------------------------------------------------------------------ shots

func _shot_opener() -> void:
	_set_time(6.8)
	_tools()._autobuild()
	_swarm(WorldLayout.EAST, [&"dust_mite", &"wolf_spider", &"rattler_beetle", &"dust_mite", &"spitter_scorpion"], 6.0, 30.0)
	_swarm(WorldLayout.WEST, [&"wolf_spider", &"dust_mite", &"dust_mite", &"rattler_beetle", &"wolf_spider"], 6.0, 30.0)
	_dur = 6.0
	_keys = [[0.0, Vector3(0, 12, 72), Vector3(0, 20, 20)], [3.0, Vector3(2, 32, 42), Vector3(-6, 40, 0)],
		[6.0, Vector3(6, 74, 24), Vector3(-34, 58, -2)]]


func _shot_crossfire() -> void:
	_set_time(17.2)
	_tools()._autobuild()
	_swarm(WorldLayout.EAST, [&"dust_mite", &"wolf_spider", &"dust_mite", &"rattler_beetle", &"wolf_spider", &"dust_mite"], 18.0, 42.0)
	_swarm(WorldLayout.EAST, [&"dust_mite", &"dust_mite", &"wolf_spider", &"dust_mite", &"spitter_scorpion"], 25.0, 45.0)
	_dur = 4.5
	_keys = [[0.0, Vector3(-31, 64, -15), Vector3(22, 42, -2)], [4.5, Vector3(-31, 64.5, 8), Vector3(22, 46, 2)]]


func _shot_faces() -> void:
	_set_time(10.0)
	var cl := Bug.cliffs
	var spots := [[&"wolf_spider", 0.0], [&"rattler_beetle", 3.6], [&"dust_mite", -3.0]]
	for s: Array in spots:
		# The beetle is the one with the cigarette.
		BugManager.smoke_override = 1 if s[0] == &"rattler_beetle" else 0
		_bm().spawn_at(s[0], WorldLayout.WEST, 2, s[1], 0.0, Bug.State.BREACHING, cl.plateau_point(WorldLayout.WEST, 6.0, s[1]))
	BugManager.smoke_override = -1
	# Let them turn toward the house (and the camera), then hold still for their close-up.
	_at(-0.6, func() -> void:
		for b: Node in get_tree().get_nodes_in_group("bugs"):
			(b as Bug).speed_mult = 0.0)
	_dur = 3.5
	_keys = [[0.0, Vector3(-40, 61.9, -1.0), Vector3(-29, 60.7, 0.3)], [3.5, Vector3(-36.5, 61.3, 0.2), Vector3(-29, 60.7, 0.3)]]


func _shot_boss() -> void:
	_set_time(18.6)
	_tools()._autobuild()
	_bm().spawn_group(&"iron_tumble", 1, WorldLayout.WEST, 2, 18.0)
	_swarm(WorldLayout.WEST, [&"dust_mite", &"dust_mite", &"wolf_spider"], 10.0, 30.0)
	_dur = 3.0
	_keys = [[0.0, Vector3(4, 14, -8), Vector3(-21, 24, 0)], [3.0, Vector3(1, 22, -3), Vector3(-21, 30, 0)]]


func _shot_storm() -> void:
	_set_time(15.5)
	_tools()._autobuild()
	_set_weather(Weather.Kind.THUNDERSTORM)
	_swarm(WorldLayout.EAST, [&"dust_mite", &"wolf_spider", &"dust_mite", &"rattler_beetle"], 10.0, 40.0)
	_at(0.4, func() -> void: WeatherFx.instance._strike())
	_at(1.5, func() -> void: WeatherFx.instance._strike())
	_dur = 2.6
	_keys = [[0.0, Vector3(-12, 72, -22), Vector3(40, 60, 0)], [2.6, Vector3(-6, 72, -10), Vector3(40, 60, 2)]]


func _shot_snow() -> void:
	_set_time(9.0)
	_set_weather(Weather.Kind.SNOW)
	_dur = 2.2
	_keys = [[0.0, Vector3(-27, 70, 22), Vector3(-46, 61, 3)], [2.2, Vector3(-29, 68.5, 15), Vector3(-46, 61, 2)]]


func _shot_dust() -> void:
	_set_time(13.0)
	_set_weather(Weather.Kind.DUST_STORM)
	_swarm(WorldLayout.WEST, [&"wolf_spider", &"dust_mite"], 40.0, 52.0)
	_dur = 2.2
	_keys = [[0.0, Vector3(-30, 62.5, -14), Vector3(-45, 62, 1)], [2.2, Vector3(-32, 62.2, -9), Vector3(-45, 62, 1)]]


func _shot_bloodmoon() -> void:
	_set_time(0.5)
	_tools()._autobuild()
	_set_weather(Weather.Kind.BLOOD_MOON)
	_swarm(WorldLayout.EAST, [&"wolf_spider", &"dust_mite", &"rattler_beetle", &"wolf_spider", &"dust_mite"], 5.0, 30.0)
	_swarm(WorldLayout.EAST, [&"dust_mite", &"dust_mite", &"wolf_spider", &"spitter_scorpion", &"dust_mite"], 2.0, 20.0)
	_dur = 2.8
	_keys = [[0.0, Vector3(-4, 5, 14), Vector3(21, 40, 2)], [2.8, Vector3(-3, 8, 4), Vector3(21, 46, 0)]]


func _shot_homestead() -> void:
	_set_time(8.0)
	var home := Homestead.of(WorldLayout.WEST)
	home._set_state(3, true, true)
	Economy.earn(0, {&"scrap": 900})
	for i in home.mount_count():
		BuildManager.instance._do_build(1, &"porch_repeater" if i % 2 == 0 else &"rooftop_cannon", 0, Vector2i(-1, i))
	for n: Node in get_tree().get_nodes_in_group("crops"):
		var plot := n as CropPlot
		if plot.cliff_id == 0:
			var crop := Defs.crop([&"corn", &"prickly_pear", &"firecracker_chili", &"herbs"][randi() % 4])
			plot.growth.clear()
			if plot.growth.plant(crop):
				plot.crop_def = crop
				plot.growth.water()
				plot.growth.tick(crop.grow_time * randf_range(0.6, 1.0))
				plot._broadcast()
	var c := Vector3(-45.5, 61.0, 1.0)
	_dur = 3.0
	_keys = []
	for i in 4:
		var a := lerpf(-0.2, 1.1, float(i) / 3.0)
		_keys.append([_dur * float(i) / 3.0, c + Vector3(cos(a) * 17.0, 7.0 - i * 0.6, sin(a) * 17.0), c + Vector3(0, 4, 0)])


func _shot_airship() -> void:
	_set_time(15.0)
	var ship := world.get_node("Airship") as Airship
	ship.visible = true
	ship.set("_state", 2)
	ship.set("_t", 3.0)
	ship.position = ship.get("_hover_pos")
	ship._set_deck_active(true)
	_dur = 3.0
	_keys = [[0.0, Vector3(9, 63, -18), Vector3(-4, 70, -40)], [3.0, Vector3(14, 70, -24), Vector3(-4, 72, -40)]]


func _shot_reload() -> void:
	_set_time(11.0)
	_tools()._autobuild()
	_swarm(WorldLayout.EAST, [&"dust_mite", &"wolf_spider", &"dust_mite", &"rattler_beetle"], 20.0, 45.0)
	_player.gun.grant(&"lever_rifle", 1)
	_player.gun.equip(&"lever_rifle")
	_player.global_position = Bug.cliffs.plateau_point(WorldLayout.WEST, 2.5, 3.0) + Vector3.UP * 0.2
	_player.rotation.y = -PI * 0.5
	_player.head.rotation.x = deg_to_rad(-8.0)
	var shoot := func() -> void:
		if _player.gun.trigger(_player.camera):
			_player.net.fire(_player.camera.global_position, -_player.camera.global_transform.basis.z)
	_at(-0.3, shoot)
	_at(0.35, shoot)
	_at(1.0, func() -> void: _player.gun.reload())
	_dur = 3.6


func _shot_fall() -> void:
	_set_time(14.0)
	var hud := world.get("hud") as CanvasLayer
	hud.visible = true
	for c in hud.get_children():
		(c as CanvasItem).visible = c is Hud.SpeedLines
	# Step off the lip at the start of the shot.
	_player.global_position = Vector3(-WorldLayout.HALF_GAP - 1.5, WorldLayout.CLIFF_HEIGHT + 0.3, 6.0)
	_player.rotation.y = -PI * 0.5
	_player.head.rotation.x = deg_to_rad(-40.0)
	_at(-0.1, func() -> void:
		_player.global_position = Vector3(-WorldLayout.HALF_GAP + 1.5, WorldLayout.CLIFF_HEIGHT + 1.0, 6.0)
		_player.velocity = Vector3(4, 2, 0))
	_dur = 2.9


func _shot_dummies() -> void:
	_set_time(16.5)
	Settings.look = DummyLook.clean({"hat": "ten_gallon", "facial": "handlebar", "outfit": "poncho", "neck": "bandana", "extra": "both"})
	_player.rig.apply_look(Settings.look)
	_player.rig.visible = true
	_player.gun.visible = false
	_player.global_position = Bug.cliffs.plateau_point(WorldLayout.WEST, 14.0, -6.0) + Vector3.UP * 0.2
	_player.rotation.y = PI * 0.15
	_at(0.9, func() -> void: _player.net._bonked(Vector3(1, 0, 0.3).normalized(), 1.0))
	var p := _player.global_position
	_cam.current = true
	_dur = 2.6
	_keys = [[0.0, p + Vector3(-1.2, 1.5, -3.2), p + Vector3(0, 1.1, 0)], [2.6, p + Vector3(-2.2, 1.7, -3.8), p + Vector3(0, 1.0, 0)]]
	_player.rig.visible = true
	await get_tree().process_frame
	_player.rig.visible = true


func _shot_endcard() -> void:
	_set_time(18.3)
	_tools()._autobuild()
	_swarm(WorldLayout.EAST, [&"dust_mite", &"wolf_spider", &"dust_mite"], 10.0, 35.0)
	_swarm(WorldLayout.WEST, [&"dust_mite", &"wolf_spider", &"dust_mite"], 10.0, 35.0)
	_dur = 4.5
	_keys = [[0.0, Vector3(0, 82, -55), Vector3(0, 48, 15)], [4.5, Vector3(0, 104, -105), Vector3(0, 48, 10)]]


## Crop line-up: each row is one crop, each column one growth stage (left to right).
func _shot_crops() -> void:
	_set_time(10.0)
	var crops: Array[StringName] = [&"corn", &"prickly_pear", &"firecracker_chili", &"herbs"]
	var origin := Bug.cliffs.plateau_point(WorldLayout.WEST, 12.0, 6.0)
	for r in crops.size():
		for c in CropBuilder.STAGES:
			var mi := MeshInstance3D.new()
			mi.mesh = CropBuilder.patch(crops[r], c)
			mi.material_override = Materials.toon(0.015)
			mi.scale = Vector3.ONE * 0.55
			world.add_child(mi)
			mi.global_position = origin + Vector3(-r * 1.9, 0.05, c * 1.9 - 3.8)
		var pk := MeshInstance3D.new()
		pk.mesh = CropBuilder.packet(crops[r])
		pk.material_override = Materials.toon(0.006)
		pk.scale = Vector3.ONE * 4.0
		world.add_child(pk)
		pk.global_position = origin + Vector3(-r * 1.9, 0.05, -5.8)
		pk.rotation.y = -PI * 0.5
	var c0 := origin + Vector3(-2.85, 0.4, 0)
	_dur = 1.0
	_keys = [[0.0, c0 + Vector3(5.5, 3.4, 0), c0], [1.0, c0 + Vector3(5.5, 3.4, 0), c0]]
