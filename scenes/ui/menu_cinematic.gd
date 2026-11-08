class_name MenuCinematic
extends Node3D
## The title screen's backdrop: the first canyon, built for show (no run, no
## bugs, no combat) and filmed in slow drifting shots that cut between the
## homestead at three stages of a run: a bare claim at dawn, a few turrets and
## a green field by midday, then the fully built fort (three floors, tower,
## turret line, sky guns, ripe crops) under the casino airship at sunset.
## Vultures, tumbleweeds and birds come from CanyonLife. MainMenu adds this
## behind its left-hand column; `fade` is a full-screen black ColorRect the menu
## puts under its UI so shots dip to black between cuts.

const WORLD_SEED := 1234
const FADE := 0.7
const SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")

## Turret line columns (row 0) per stage, and the sky guns / last resorts of the fort.
const STAGE_TURRETS: Array = [
	[],
	[[&"gatling_post", 6], [&"buffalo_rifle", 10], [&"gatling_post", 14]],
	[[&"gatling_post", 2], [&"buffalo_rifle", 4], [&"chili_mortar", 6], [&"water_cannon", 8], [&"gatling_post", 10],
		[&"dynamite_lobber", 12], [&"buffalo_rifle", 14], [&"lasso_harpoon", 16], [&"gatling_post", 18]],
]
const FORT_EXTRAS: Array = [[&"duck_gun", Vector2i(3, 3)], [&"sky_sweeper", Vector2i(3, 17)], [&"sharpshooter_tower", Vector2i(5, 1)],
	[&"scattergun_post", Vector2i(5, 19)]]

var fade: ColorRect
var ready_to_film := false
var _cliffs: CliffBuilder
var _cam: Camera3D
var _cycle: DayCycle
var _stage_nodes: Array[Node3D] = []
var _ship: Node3D
var _shots: Array = []
var _shot := -1
var _t := 0.0
var _dur := 1.0
var _keys: Array = []


func _ready() -> void:
	# The backdrop is its own little offline world: its crop plots, turrets and
	# the rest never send network messages to players joining the real game
	# (they don't have these nodes, and the flood of bad packets broke joins).
	var offline := SceneMultiplayer.new()
	offline.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().set_multiplayer(offline, get_path())
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_environment()
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 900.0
	_cam.position = Vector3(0, 80, 60)
	add_child(_cam)
	_cam.current = true
	# The canyon takes a moment to build: let the menu draw first.
	await get_tree().process_frame
	if not is_inside_tree():
		return # the menu closed already (a game started at once): build nothing
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if not await _build_world():
		return # the menu closed while the set went up
	_shots = _make_shots()
	LoadTimes.mark("(film) shots")
	LoadTimes.watch_frames(20)
	ready_to_film = true
	if GameState.flag_value("--cineshot") != "": # screenshots: jump to a shot (1-based) and a moment in it
		_shot = int(GameState.flag_value("--cineshot")) - 2
	_next_shot()
	_t = GameState.flag_value("--cinet").to_float()


func _process(delta: float) -> void:
	if not ready_to_film:
		return
	_t += delta
	_place_camera(_t)
	if _ship != null:
		_ship.position.z = 26.0 + sin(Time.get_ticks_msec() / 9000.0) * 6.0
		_ship.rotation.z = sin(Time.get_ticks_msec() / 2300.0) * 0.015
	# Fade in at the start of a shot, out at its end.
	var a := 1.0 - clampf(_t / FADE, 0.0, 1.0)
	a = maxf(a, clampf((_t - (_dur - FADE)) / FADE, 0.0, 1.0))
	fade.color.a = a
	if _t >= _dur:
		_next_shot()


# ------------------------------------------------------------------ the set

func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("sky_noise", DayCycle.SKY_NOISE)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#B08AB8")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Palette.SKY_HORIZON
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.0
	env.glow_enabled = Settings.effects >= GraphicsQuality.MEDIUM
	env.glow_intensity = 0.65
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_brightness = Settings.brightness
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#FFE8C2")
	sun.light_energy = 1.25
	sun.shadow_enabled = Settings.shadows and not Settings.is_compatibility()
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_normal_bias = 2.5
	sun.shadow_bias = 0.08
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	add_child(sun)
	_cycle = DayCycle.new()
	_cycle.env = env
	_cycle.sun = sun
	_cycle.sky = sky_mat
	add_child(_cycle)


func _build_world() -> bool:
	var terrain := Node3D.new()
	add_child(terrain)
	# Maps: the title screen always flies over the canyon (the world selects the run's map).
	MapDef.select(MapDef.CANYON)
	_cliffs = CliffBuilder.new(WORLD_SEED)
	Bug.cliffs = _cliffs
	var dressing := Node3D.new()
	add_child(dressing)
	# One piece a frame, so the menu in front keeps answering while the set goes up
	# (behind the black fade: nothing shows until the first shot).
	LoadTimes.mark("(film) frames before build")
	if not await _run_steps(_cliffs.build_steps(terrain)):
		return false
	LoadTimes.mark("(film) CliffBuilder.build")
	if not await _run_steps(WorldDressing.new(_cliffs, dressing, WORLD_SEED + 1).build_steps()):
		return false
	LoadTimes.mark("(film) WorldDressing.build")
	var vfx := VfxPool.new() # brings the CanyonLife (vultures, birds, tumbleweeds, dust devils)
	add_child(vfx)
	LoadTimes.mark("(film) vfx pool")
	for stage in 3:
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		_stage_nodes.append(root)
		for cid in 2:
			for t: Array in STAGE_TURRETS[stage]:
				_turret(root, t[0], cid, Vector2i(0, int(t[1])))
			if stage == 2:
				for t: Array in FORT_EXTRAS:
					_turret(root, t[0], cid, t[1])
	LoadTimes.mark("(film) stage turrets")
	_ship = _airship()
	LoadTimes.mark("(film) airship")
	return true


## Runs build steps one per frame, each on the film's own canyon map (whatever
## a lobby has picked meanwhile is put back after). False if the menu closed.
func _run_steps(steps: Array[Callable]) -> bool:
	for step in steps:
		var was := MapDef.current
		MapDef.current = _cliffs.map
		step.call()
		MapDef.current = was
		await get_tree().process_frame
		if not is_inside_tree():
			return false
	MapDef.current = _cliffs.map
	return true


func _turret(root: Node3D, id: StringName, cid: int, cell: Vector2i) -> void:
	var parts := TurretBuilder.build(id, Palette.team_color(cid))
	var t := Node3D.new()
	root.add_child(t)
	t.global_position = Buildable.cell_center(_cliffs, cid, cell)
	t.rotation.y = WorldLayout.facing_canyon_yaw(cid)
	var base := MeshInstance3D.new()
	base.mesh = parts["base"]
	base.material_override = Materials.toon(0.025)
	t.add_child(base)
	var head := MeshInstance3D.new()
	head.mesh = parts["head"]
	head.material_override = Materials.toon(0.02)
	head.position.y = float(parts["head_y"])
	head.rotation.y = randf_range(-0.4, 0.4)
	t.add_child(head)
	var gun := MeshInstance3D.new()
	gun.mesh = parts["gun"]
	gun.material_override = Materials.toon(0.02)
	gun.position.y = float(parts["gun_y"])
	gun.rotation.x = randf_range(0.0, 0.25)
	head.add_child(gun)
	if parts.has("spin"):
		var spin := MeshInstance3D.new()
		spin.mesh = parts["spin"]
		spin.material_override = Materials.toon(0.02)
		spin.position = parts["spin_at"]
		gun.add_child(spin)


## The casino airship, hung over the canyon (just its meshes: no deck, no games).
func _airship() -> Node3D:
	var ship := Node3D.new()
	ship.visible = false
	add_child(ship)
	ship.position = Vector3(0, WorldLayout.CLIFF_HEIGHT + 50.0, 26.0)
	for m: Array in [[AirshipBuilder.hull(), Vector3.ZERO], [AirshipBuilder.envelope(), Vector3.ZERO],
			[AirshipBuilder.bulbs(), Vector3.ZERO], [AirshipBuilder.railing(), Vector3.ZERO]]:
		var mi := MeshInstance3D.new()
		mi.mesh = m[0]
		mi.material_override = Materials.toon(0.02)
		mi.position = m[1]
		ship.add_child(mi)
	ship.rotation.y = PI * 0.5
	return ship


func _set_stage(stage: int) -> void:
	for i in _stage_nodes.size():
		_stage_nodes[i].visible = i == stage
	for cid in 2:
		var home := Homestead.of(cid)
		if home != null:
			home._set_state([1, 2, 3][stage], stage >= 1, stage >= 2, stage >= 2)
	_ship.visible = stage == 2
	for n: Node in get_tree().get_nodes_in_group("crops"):
		var plot := n as CropPlot
		if plot == null:
			continue
		plot.growth.clear()
		if stage >= 1:
			var crop := Defs.crop([&"corn", &"prickly_pear", &"firecracker_chili", &"herbs"][posmod(plot.get_instance_id(), 4)])
			if plot.growth.plant(crop):
				plot.crop_def = crop
				plot.growth.water()
				plot.growth.tick(crop.grow_time * (0.45 if stage == 1 else 1.2))
		# Local only (a join may be connecting meanwhile: no RPC through a half-open peer).
		plot.call("_sync", plot.crop_def.id if plot.crop_def != null else &"", plot.growth.stage, plot.growth.progress, plot.growth.watered)


func _set_time(hour: float) -> void:
	_cycle.clock = hour
	_cycle.set("_target", hour)
	_cycle.set("_rate", 0.0)


# ------------------------------------------------------------------ the shots

func _make_shots() -> Array:
	var west := Vector3(-45.5, 61.0, 1.0)
	var east := Vector3(45.5, 61.0, 1.0)
	var top := WorldLayout.CLIFF_HEIGHT
	return [
		# Dawn: the bare claim. Drift along the canyon toward the west homestead.
		{"stage": 0, "hour": 7.0, "dur": 11.0, "keys": [[0.0, Vector3(2, top + 14, 40), west + Vector3(0, 2, 6)],
			[11.0, Vector3(-8, top + 11, 22), west + Vector3(0, 3, 0)]]},
		# Morning: a few turrets up, the field planted; orbit the house.
		{"stage": 1, "hour": 9.5, "dur": 11.0, "keys": _orbit(west, 20.0, 8.0, -0.35, 0.55, 11.0)},
		# Midday: from above the east homestead, across the canyon at both turret lines.
		{"stage": 1, "hour": 12.5, "dur": 10.0, "keys": [[0.0, Vector3(27, top + 9, -16), west + Vector3(6, 0, 4)],
			[10.0, Vector3(25, top + 10, 12), west + Vector3(6, 0, -4)]]},
		# Sunset: the finished fort under the airship.
		{"stage": 2, "hour": 17.4, "dur": 12.0, "keys": _orbit(west, 24.0, 11.0, 0.95, 1.85, 12.0)},
		# Dusk: pull back down the canyon, the airship lit over both forts.
		{"stage": 2, "hour": 18.0, "dur": 11.0, "keys": [[0.0, Vector3(0, top + 16, -40), Vector3(0, top + 40, 26)],
			[11.0, Vector3(0, top + 24, -70), Vector3(0, top + 38, 26)]]},
	]


func _orbit(c: Vector3, r: float, h: float, a0: float, a1: float, dur: float) -> Array:
	var keys: Array = []
	for i in 4:
		var a := lerpf(a0, a1, float(i) / 3.0)
		keys.append([dur * float(i) / 3.0, c + Vector3(cos(a) * r, h - i * 0.5, sin(a) * r), c + Vector3(0, 4, 0)])
	return keys


func _next_shot() -> void:
	_shot = (_shot + 1) % _shots.size()
	var s: Dictionary = _shots[_shot]
	_set_stage(int(s["stage"]))
	_set_time(float(s["hour"]))
	_dur = float(s["dur"])
	_keys = s["keys"]
	_t = 0.0
	_place_camera(0.0)


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


func _exit_tree() -> void:
	if is_inside_tree():
		get_tree().set_multiplayer(null, get_path())
