class_name WeatherFx
extends Node3D
## What the weather looks and feels like: rain, snow or blowing dust around the
## local camera, gusts that shove players along the canyon, and (host-driven)
## lightning strikes that can wreck a turret.

static var instance: WeatherFx

var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _dust: CPUParticles3D
var _bolt_t := 0.0
var _rng := RandomNumberGenerator.new()


## Which way the wind blows along the canyon (+1 or -1), fixed per wave.
static func wind_sign() -> float:
	return 1.0 if GameState.wave % 2 == 0 else -1.0


func _ready() -> void:
	instance = self
	_rng.randomize()
	_rain = _make(Color(0.8, 0.86, 0.98, 0.75), Vector3(0.04, 0.9, 0.04), 1800, 1.2, Vector3(0, -38, 0), 0.0)
	_snow = _make(Color(1, 1, 1, 0.95), Vector3(0.09, 0.09, 0.09), 1400, 7.0, Vector3(0, -2.2, 0), 1.2)
	_dust = _make(Color(0.86, 0.66, 0.42, 0.35), Vector3(1.4, 0.05, 0.05), 500, 1.6, Vector3.ZERO, 0.6)
	GameState.weather_changed.connect(func(_k: int) -> void: _bolt_t = _next_bolt())
	_bolt_t = 999.0


func _make(color: Color, size: Vector3, amount: int, life: float, gravity: Vector3, wander: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(28, 4, 28)
	p.direction = Vector3.DOWN
	p.spread = 5.0
	p.gravity = gravity
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = wander
	var quad := BoxMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	quad.material = mat
	p.mesh = quad
	p.emitting = false
	add_child(p)
	return p


func _process(delta: float) -> void:
	var w := GameState.weather
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var above := cam.global_position + Vector3.UP * 12.0
		for p: CPUParticles3D in [_rain, _snow]:
			p.global_position = above
		_dust.global_position = cam.global_position + Vector3(0, 2, -wind_sign() * 18.0)
	_rain.emitting = Weather.is_rain(w)
	_rain.amount = 2600 if w == Weather.Kind.THUNDERSTORM else 1400
	_snow.emitting = w == Weather.Kind.SNOW
	_dust.emitting = w == Weather.Kind.WINDY
	_dust.gravity = Vector3(0, -0.3, wind_sign() * 26.0)
	_snow.gravity = Vector3(0, -2.2, wind_sign() * (0.8 if w != Weather.Kind.WINDY else 4.0))
	if w == Weather.Kind.WINDY:
		_push_local_player(delta)
	if multiplayer.is_server() and w == Weather.Kind.THUNDERSTORM and GameState.phase == GameState.Phase.WAVE:
		_bolt_t -= delta
		if _bolt_t <= 0.0:
			_bolt_t = _next_bolt()
			_strike()


func _next_bolt() -> float:
	var r := Weather.lightning_interval(GameState.weather)
	return _rng.randf_range(r.x, r.y) if r.y > 0.0 else 999.0


## Gusts: a steady sideways shove that comes and goes.
func _push_local_player(delta: float) -> void:
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if not p.is_multiplayer_authority():
			continue
		var gust := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.0013)
		p.velocity.z += wind_sign() * Weather.WIND_PUSH * gust * delta * (3.0 if not p.is_on_floor() else 1.0)


## Host: pick a spot (often a turret) and call the bolt down.
func _strike() -> void:
	var turrets := get_tree().get_nodes_in_group("turrets")
	var target := Vector3.ZERO
	var victim := ""
	if not turrets.is_empty() and _rng.randf() < Weather.LIGHTNING_TURRET_CHANCE:
		var t := turrets[_rng.randi() % turrets.size()] as Turret
		target = t.global_position
		victim = t.get_path()
	else:
		var cid := _rng.randi() % 2
		var cl := Bug.cliffs
		if cl == null:
			return
		if _rng.randf() < 0.5:
			target = cl.plateau_point(cid, _rng.randf_range(2.0, 28.0), _rng.randf_range(-20.0, 20.0))
		else:
			target = cl.face_point(cid, _rng.randf_range(10.0, 55.0), _rng.randf_range(-20.0, 20.0))
	# Bugs caught in the blast are fried.
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b.is_alive() and b.global_position.distance_to(target) < 3.5:
			b.receive_hit(400.0, target, Vector3.DOWN, true, 1.0, "Lightning", -1)
	if victim != "":
		var t := get_node_or_null(victim) as Turret
		if t != null and t.health != null:
			t.health.take_damage(t.health.hp + 1.0, "Lightning", -1)
	if GameState.has_flag("--debug"):
		print("[weather] lightning at %s%s" % [str(target.snapped(Vector3.ONE)), " (turret wrecked)" if victim != "" else ""])
	_bolt.rpc(target, victim != "")


@rpc("authority", "call_local", "reliable")
func _bolt(target: Vector3, hit_turret: bool) -> void:
	var st := MeshKit.begin()
	var p := target + Vector3(randf_range(-8, 8), 120.0, randf_range(-8, 8))
	var pts: Array[Vector3] = [p]
	for i in 12:
		var t := float(i + 1) / 12.0
		var q := p.lerp(target, t) + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) * (1.0 - t)
		pts.append(q)
	pts[pts.size() - 1] = target
	for i in pts.size() - 1:
		WeaponBuilder.rod(st, pts[i], pts[i + 1], 0.35, 0.3, 5, Color(0.9, 0.95, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.85, 1.0)
	mat.emission_energy_multiplier = 6.0
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 0.88, 1.0)
	light.light_energy = 12.0
	light.omni_range = 40.0
	light.position = target + Vector3.UP * 4.0
	get_tree().current_scene.add_child(light)
	var tw := mi.create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(func() -> void: mi.visible = false)
	tw.tween_interval(0.06)
	tw.tween_callback(func() -> void: mi.visible = true)
	tw.tween_interval(0.1)
	tw.tween_callback(func() -> void:
		mi.queue_free()
		light.queue_free())
	if DayCycle.instance != null:
		DayCycle.instance.flash = 1.0
	Audio.play_at(&"thunder", target, 8.0)
	if hit_turret:
		Economy.notice.emit("Lightning struck a turret and wrecked it!")
	for n: Node in get_tree().get_nodes_in_group("players"):
		var pl := n as Player
		if pl.is_multiplayer_authority():
			pl.add_shake(clampf(1.0 - pl.global_position.distance_to(target) / 60.0, 0.15, 0.8))
