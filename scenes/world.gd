extends Node3D
## Root of the game world. Generates the canyon, lighting and dressing at load,
## then the host spawns one player per peer once everyone has loaded.
## Running this scene directly (no lobby) plays offline; --east spawns you on the east cliff,
## --cliff=N on cliff N, --map=canyon|mesa|buttes picks the map.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")
const WORLD_SEED := 1234

var cliffs: CliffBuilder
var vfx: VfxPool
var hud: Hud
var bugs: BugManager
var builds: BuildManager
var players_root: Node3D
var spawner: MultiplayerSpawner
var _loaded_peers: Dictionary = {}
var _env: Environment
var _sun: DirectionalLight3D
var _started := false
var saver: RunSaver


func _ready() -> void:
	# Maps: build the lobby's map (offline runs: --map=).
	var map_id := NetworkManager.map_id
	if not NetworkManager.is_online() and GameState.flag_value("--map") != "":
		map_id = StringName(GameState.flag_value("--map").to_lower())
	if GameState.tutorial:
		map_id = MapDef.CANYON # the tutorial is always the two-cliff canyon
	MapDef.select(map_id)
	print("[map] %s (%d cliffs)" % [WorldLayout.map().display_name, WorldLayout.cliff_count()])
	_build_environment()
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	add_child(terrain)
	cliffs = CliffBuilder.new(WORLD_SEED)
	cliffs.build(terrain)
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	add_child(dressing)
	WorldDressing.new(cliffs, dressing, WORLD_SEED + 1).build()
	vfx = VfxPool.new()
	vfx.name = "Vfx"
	add_child(vfx)
	Bug.cliffs = cliffs
	bugs = BugManager.new()
	bugs.name = "Bugs"
	bugs.vfx = vfx
	add_child(bugs)
	# Boss mechanics' shared effects and their RPC channel (same path on every peer).
	var boss_fx := BossFx.new()
	boss_fx.name = "BossFx"
	add_child(boss_fx)
	var weather := WeatherFx.new()
	weather.name = "WeatherFx"
	add_child(weather)
	var menu := MenuScreen.new()
	menu.name = "MenuScreen"
	add_child(menu)
	var airship := Airship.new()
	airship.name = "Airship"
	add_child(airship)
	# Wind, the climbing swarm's chitter and the airship's creaks (local only, no sync).
	var ambience := Ambience.new()
	ambience.name = "Ambience"
	ambience.bugs = bugs
	ambience.airship = airship
	add_child(ambience)
	# Canyon Expeditions: the raid sites on the canyon floor.
	var sites := SiteManager.new()
	sites.name = "Sites"
	add_child(sites)
	var pickups := PickupManager.new()
	pickups.name = "Pickups"
	add_child(pickups)
	builds = BuildManager.new()
	builds.name = "Builds"
	builds.cliffs = cliffs
	add_child(builds)
	# Additions: coverage table, wanted posters, corpse piles, campfires.
	var extras := WorldExtras.new()
	extras.name = "Extras"
	extras.cliffs = cliffs
	add_child(extras)
	Turret.bug_manager = bugs
	Turret.vfx = vfx
	StructureNode.vfx = vfx
	WaveDirector.bug_manager = bugs
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	# Pings draw on the HUD layer but live here so their RPCs line up on every peer.
	var pings := Pings.new()
	pings.name = "Pings"
	hud.add_child(pings)
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	var vote := PauseVote.new()
	vote.name = "PauseVote"
	add_child(vote)

	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	spawner = MultiplayerSpawner.new()
	spawner.name = "PlayerSpawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(players_root)
	spawner.spawn_function = _spawn_player

	NetworkManager.server_closed.connect(_return_to_menu)
	NetworkManager.player_left.connect(_on_player_left)
	print("World ready: %d nodes" % get_tree().get_node_count())

	# [Foundation hook] autosaves the run each build phase (host) and resumes saved runs.
	saver = RunSaver.new()
	saver.name = "RunSaver"
	saver.world = self
	add_child(saver)
	# Tutorial: the guided first run (steps, cards, the scripted wave).
	if GameState.tutorial:
		var tut := TutorialRun.new()
		tut.name = "TutorialRun"
		tut.world = self
		add_child(tut)
	# Story: the chapter's director (objectives, radio, the noticeboard telegram).
	if Story.active():
		var story := StoryDirector.new()
		story.name = "StoryDirector"
		story.world = self
		add_child(story)

	if multiplayer.is_server():
		_on_peer_loaded(1)
	else:
		# Clients build the CPU teammates as puppets of the host's (same node paths,
		# so their pose / shot / action RPCs land, and the HUD knows their names).
		if NetworkManager.has_cpu():
			_spawn_cpus()
		_client_loaded.rpc_id(1)
		# If the host was still loading, that word is lost (no World there yet):
		# keep saying it until our own player has arrived.
		var again := Timer.new()
		again.name = "LoadedAgain"
		again.wait_time = 1.5
		again.autostart = true
		add_child(again)
		again.timeout.connect(func() -> void:
			if local_player() != null or not NetworkManager.is_online():
				again.queue_free()
			else:
				_client_loaded.rpc_id(1))

	var tools := DebugTools.new()
	tools.name = "DebugTools"
	tools.world = self
	add_child(tools)
	if GameState.flag_value("--trailer") != "":
		var director := TrailerDirector.new()
		director.name = "TrailerDirector"
		director.world = self
		add_child(director)
	# --leaveafter=S (crash tests): back to the menu after S seconds, as the pause
	# menu's Leave does (with --host --startafter the menu then starts a new game).
	if GameState.flag_value("--leaveafter") != "":
		get_tree().create_timer(GameState.flag_value("--leaveafter").to_float()).timeout.connect(_test_leave)
		# --orphans: what earlier games left behind, 2 s into each new one.
		if GameState.flag_value("--orphans") != "":
			get_tree().create_timer(2.0).timeout.connect(_print_leftovers)

	# --fstoggle=S (crash tests): flip fullscreen/windowed every S seconds (not saved).
	if GameState.flag_value("--fstoggle") != "":
		var ft := Timer.new()
		ft.wait_time = maxf(GameState.flag_value("--fstoggle").to_float(), 0.5)
		ft.autostart = true
		ft.timeout.connect(_test_toggle_fullscreen)
		add_child(ft)


func _test_toggle_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	print("[test] fullscreen -> %s" % (not fs))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _print_leftovers() -> void:
	print("[leftovers] mem %.1f MB  nodes %d  objects %d  resources %d  orphans %d  video %.0f MB" % [
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	for top: Node in get_tree().root.get_children():
		print("    %5d  %s" % [top.find_children("*", "", true, false).size(), top.name])
	DebugTools.print_orphan_summary("new world")


func _test_leave() -> void:
	print("[test] leaving to the menu")
	GameState.menu_open = false
	NetworkManager.leave()
	_return_to_menu()


# ------------------------------------------------------------------ spawning (host decides)

@rpc("any_peer", "reliable")
func _client_loaded() -> void:
	if multiplayer.is_server():
		_on_peer_loaded(multiplayer.get_remote_sender_id())


func _on_peer_loaded(id: int) -> void:
	_loaded_peers[id] = true
	if _started:
		# A client still without its player (its first word got lost): spawn it now.
		var roster_now := _roster()
		if roster_now.has(id) and players_root.get_node_or_null(str(id)) == null:
			print("[net] late spawn for peer %d" % id)
			spawner.spawn({"peer": id, "cliff": int((roster_now[id] as Dictionary)["cliff"])})
		return
	var roster := _roster()
	for peer_id: int in roster:
		if not _loaded_peers.has(peer_id):
			return
	_started = true
	for peer_id: int in roster:
		spawner.spawn({"peer": peer_id, "cliff": int((roster[peer_id] as Dictionary)["cliff"])})
	if NetworkManager.has_cpu():
		_spawn_cpus()
	else:
		Economy.cpu_mode = false # no CPU this run: no CPU budgets
	# [Foundation hook] Continue last run: rebuild the saved run instead of a new one.
	var resume := RunSave.pending
	RunSave.pending = {}
	if not saver.resume(resume):
		GameState.start_run(StoryDirector.instance.start_wave() if StoryDirector.instance != null else 1)


## CPU teammates take every empty cliff; each may spend 1 / team size of the
## team's scrap (see CpuBudget), and keeps its own chitin. Host: the real ones;
## clients: puppets that follow the host's.
func _spawn_cpus() -> void:
	var free := NetworkManager.cpu_cliffs()
	for i in free.size():
		var cpu := CpuTeammate.new()
		cpu.name = "CPU" if i == 0 else "CPU%d" % (i + 1)
		cpu.setup(NetworkManager.cpu_quality, free[i], cliffs, vfx, i)
		add_child(cpu)
		print("[cpu] %s teammate %s on cliff %d (%s)" % [NetworkManager.CPU_QUALITY_NAMES[NetworkManager.cpu_quality], cpu.display_name, cpu.cliff_id, WorldLayout.map().name_of(cpu.cliff_id)])
	if not multiplayer.is_server():
		return
	Economy.enable_cpu_budget(NetworkManager.players.size() + free.size(), free.size())


## Lobby roster, or a single offline player when the scene runs on its own.
func _roster() -> Dictionary:
	if NetworkManager.is_online():
		return NetworkManager.players
	var cid := WorldLayout.EAST if GameState.has_flag("--east") else WorldLayout.WEST
	if GameState.flag_value("--cliff") != "":
		cid = clampi(int(GameState.flag_value("--cliff")), 0, WorldLayout.cliff_count() - 1)
	return {1: {"name": "Rancher", "cliff": cid, "ready": true}}


## Runs on every peer (MultiplayerSpawner spawn function).
func _spawn_player(data: Variant) -> Node:
	var d := data as Dictionary
	var peer_id := int(d["peer"])
	var cid := int(d["cliff"])
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = str(peer_id)
	player.cliff_id = cid
	player.set_multiplayer_authority(peer_id)
	player.position = cliffs.plateau_point(cid, 11.0, 0.0) + Vector3.UP * 0.5
	player.rotation.y = WorldLayout.facing_canyon_yaw(cid)
	print("[peer %d] spawned player %d on cliff %d" % [multiplayer.get_unique_id(), peer_id, cid])
	player.ready.connect(func() -> void:
		player.gun.vfx = vfx
		if peer_id == multiplayer.get_unique_id():
			var bm := BuildMode.new()
			bm.name = "BuildMode"
			bm.player = player
			bm.cliffs = cliffs
			player.build_mode = bm
			player.add_child(bm)
			var hb := Hotbar.new()
			hb.name = "Hotbar"
			hb.player = player
			player.add_child(hb)
			hud.hotbar.bind(hb)
			vfx.shake_requested.connect(func(pos: Vector3, strength: float) -> void:
				var dist := pos.distance_to(player.global_position)
				if dist < 40.0:
					player.add_shake(strength * (1.0 - dist / 40.0)))
			hud.bind_player(player, bugs, builds), CONNECT_ONE_SHOT)
	return player


func local_player() -> Player:
	return players_root.get_node_or_null(str(multiplayer.get_unique_id())) as Player


func _on_player_left(id: int) -> void:
	if multiplayer.is_server():
		var p := players_root.get_node_or_null(str(id))
		if p != null:
			p.queue_free()
		if not _started and not _loaded_peers.is_empty():
			_on_peer_loaded(1) # someone left while loading: start with everyone else


func _return_to_menu() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.menu_open:
		return
	if event.is_action_pressed("ready_up"):
		GameState.toggle_ready()


# ------------------------------------------------------------------ environment

func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("cloud_noise", Materials.noise_texture(42, 0.012, 512))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#B08AB8")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = not GameState.has_flag("--nofog")
	env.fog_light_color = Palette.SKY_HORIZON
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_hdr_threshold = 1.2
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_env = env

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#FFE8C2")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	# Blend between shadow cascades and push shadows off surfaces a bit more, so
	# there's no hard-edged ring on the ground a few metres around the camera.
	sun.directional_shadow_blend_splits = true
	sun.shadow_normal_bias = 2.5
	sun.shadow_bias = 0.08
	sun.directional_shadow_fade_start = 0.6
	sun.shadow_blur = 1.5
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	add_child(sun)
	_sun = sun
	var cycle := DayCycle.new()
	cycle.name = "DayCycle"
	cycle.env = env
	cycle.sun = sun
	cycle.sky = sky_mat
	add_child(cycle)
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	_env.adjustment_enabled = true
	_env.adjustment_brightness = Settings.brightness
	# (The OpenGL renderer draws a shadowed sun in an extra additive pass that
	# doubles up the ambient light and washes everything out, and it costs a
	# second pass over the whole scene: weak GPUs go without sun shadows there.)
	_sun.shadow_enabled = Settings.shadows and not GameState.has_flag("--noshadow") and not Settings.is_compatibility()
	var sd := GraphicsQuality.level(Settings.shadow_detail)
	_sun.directional_shadow_max_distance = GraphicsQuality.SHADOW_DISTANCE[sd]
	_sun.directional_shadow_mode = GraphicsQuality.SHADOW_SPLITS[sd] as DirectionalLight3D.ShadowMode
	_env.glow_enabled = Settings.effects >= GraphicsQuality.MEDIUM
	if players_root == null:
		return
	var p := local_player()
	if p != null:
		p.camera.fov = Settings.fov
		p.camera.far = GraphicsQuality.VIEW_FAR[GraphicsQuality.level(Settings.view_distance)]
