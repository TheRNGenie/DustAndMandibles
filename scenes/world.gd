extends Node3D
## Root of the game world. Generates the canyon, lighting and dressing at load,
## then spawns the local player. M0 runs solo; M1 adds networking and a lobby.
## Flags: --east spawns you on the east cliff.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")
const WORLD_SEED := 1234

var cliffs: CliffBuilder
var vfx: VfxPool
var hud: Hud


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
	vfx = VfxPool.new()
	vfx.name = "Vfx"
	add_child(vfx)
	hud = Hud.new()
	add_child(hud)
	var cid := WorldLayout.EAST if GameState.has_flag("--east") else WorldLayout.WEST
	_spawn_local_player(cid)
	print("World ready: %d nodes" % get_tree().get_node_count())
	var shot := GameState.flag_value("--shot")
	if shot != "":
		_take_screenshot(shot)


## Debug: `--shot=<path.png> [--look=yaw,pitch] [--pos=d,z]` saves a frame and quits.
func _take_screenshot(path: String) -> void:
	var player := get_node_or_null("Player") as Player
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
	for i in 90:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Saved screenshot to ", path)
	get_tree().quit()


func _spawn_local_player(cid: int) -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = "Player"
	player.cliff_id = cid
	var spawn := cliffs.plateau_point(cid, 6.0, 0.0) + Vector3.UP * 0.5
	player.position = spawn
	player.rotation.y = WorldLayout.facing_canyon_yaw(cid)
	add_child(player)
	player.revolver.vfx = vfx
	hud.bind_player(player)


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

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#FFE8C2")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	add_child(sun)
