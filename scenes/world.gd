extends Node3D
## Root of the game world. Generates the canyon, lighting and dressing at load,
## then the host spawns one player per peer once everyone has loaded.
## Running this scene directly (no lobby) plays offline; --east spawns you on the east cliff.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")
const WORLD_SEED := 1234

var cliffs: CliffBuilder
var vfx: VfxPool
var hud: Hud
var bridge: RopeBridge
var players_root: Node3D
var spawner: MultiplayerSpawner
var _loaded_peers: Dictionary = {}
var _env: Environment
var _sun: DirectionalLight3D
var _started := false


func _ready() -> void:
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
	bridge = RopeBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	bridge.setup(cliffs)
	vfx = VfxPool.new()
	vfx.name = "Vfx"
	add_child(vfx)
	hud = Hud.new()
	add_child(hud)
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)

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

	if multiplayer.is_server():
		_on_peer_loaded(1)
	else:
		_client_loaded.rpc_id(1)

	var shot := GameState.flag_value("--shot")
	if shot != "":
		_take_screenshot(shot)


# ------------------------------------------------------------------ spawning (host decides)

@rpc("any_peer", "reliable")
func _client_loaded() -> void:
	if multiplayer.is_server():
		_on_peer_loaded(multiplayer.get_remote_sender_id())


func _on_peer_loaded(id: int) -> void:
	_loaded_peers[id] = true
	if _started:
		return
	var roster := _roster()
	for peer_id: int in roster:
		if not _loaded_peers.has(peer_id):
			return
	_started = true
	for peer_id: int in roster:
		spawner.spawn({"peer": peer_id, "cliff": int((roster[peer_id] as Dictionary)["cliff"])})
	GameState.start_run()


## Lobby roster, or a single offline player when the scene runs on its own.
func _roster() -> Dictionary:
	if NetworkManager.is_online():
		return NetworkManager.players
	var cid := WorldLayout.EAST if GameState.has_flag("--east") else WorldLayout.WEST
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
	player.position = cliffs.plateau_point(cid, 6.0, 0.0) + Vector3.UP * 0.5
	player.rotation.y = WorldLayout.facing_canyon_yaw(cid)
	print("[peer %d] spawned player %d on cliff %d" % [multiplayer.get_unique_id(), peer_id, cid])
	player.ready.connect(func() -> void:
		player.revolver.vfx = vfx
		if peer_id == multiplayer.get_unique_id():
			hud.bind_player(player), CONNECT_ONE_SHOT)
	return player


func local_player() -> Player:
	return players_root.get_node_or_null(str(multiplayer.get_unique_id())) as Player


func _on_player_left(id: int) -> void:
	if multiplayer.is_server():
		var p := players_root.get_node_or_null(str(id))
		if p != null:
			p.queue_free()


func _return_to_menu() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.menu_open:
		return
	if event.is_action_pressed("ready_up"):
		GameState.vote_skip()
	elif event.is_action_pressed("debug_skip_phase") and GameState.has_flag("--debug"):
		GameState.debug_skip()


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
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Palette.SKY_HORIZON
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
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
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	add_child(sun)
	_sun = sun
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	_env.adjustment_enabled = true
	_env.adjustment_brightness = Settings.brightness
	_sun.shadow_enabled = Settings.shadows
	if players_root == null:
		return
	var p := local_player()
	if p != null:
		p.camera.fov = Settings.fov


# ------------------------------------------------------------------ debug screenshots

## `--shot=<path.png> [--pos=d,z] [--look=yaw,pitch] [--frames=N]` saves a frame and quits.
func _take_screenshot(path: String) -> void:
	var frames := int(GameState.flag_value("--frames")) if GameState.flag_value("--frames") != "" else 90
	for i in 20:
		await get_tree().process_frame
	var player := local_player()
	var pos := GameState.flag_value("--pos")
	if player != null and pos != "":
		var p := pos.split(",")
		player.global_position = cliffs.plateau_point(player.cliff_id, p[0].to_float(), p[1].to_float()) + Vector3.UP * 0.2
		player.spawn_transform = player.global_transform
	var look := GameState.flag_value("--look")
	if player != null and look != "":
		var parts := look.split(",")
		player.rotation.y += deg_to_rad(parts[0].to_float())
		player.head.rotation.x = deg_to_rad(parts[1].to_float())
	for i in frames:
		await get_tree().process_frame
		if i == 30 and GameState.has_flag("--autoskip"):
			GameState.vote_skip()
		if player != null and GameState.has_flag("--autofire") and i % 40 == 0 and i < frames - 60:
			if player.revolver.trigger(player.camera):
				player.net.fire(player.camera.global_position, -player.camera.global_transform.basis.z)
	print("[peer %d] phase %d wave %d, players %d, bridge lowered %s" % [multiplayer.get_unique_id(),
			GameState.phase, GameState.wave, players_root.get_child_count(), bridge.is_lowered()])
	for p: Node in players_root.get_children():
		print("[peer %d]   player %s at %s" % [multiplayer.get_unique_id(), p.name, str((p as Node3D).global_position.snapped(Vector3.ONE * 0.1))])
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved screenshot to ", path)
	get_tree().quit()
