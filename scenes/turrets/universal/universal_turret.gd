class_name UniversalTurret
extends Turret
## A universal crop-fed turret (the Nov 2026 turret handoff): it takes any of the
## nine crop sacks (CropEffects), and the crop sets what each hit does. One sack
## lasts one wave: it's spent when the wave ends and the turret goes back to
## idle, barrel up. Unloaded it doesn't fire.
##
## Loading (every peer, the local player): E reloads the crop it had last (if you
## have a sack of it), Q opens the crop wheel (CropWheel). In the build phase you
## can swap (the sack you swap out comes back); in a wave only an empty turret
## can be loaded (an emergency load, still spent at the wave's end).
##
## Its model is UniversalBuilder's parts as live nodes (UniRig), moved every frame
## by its group's animate() from a UniCtx this fills. Shots are drawn in the
## crop's colour. Upgrades: Tier 2 from wave 5, Tier 3 from wave 10
## (TurretDef.UNI_*), paid in your own scrap at 85% of that tier's build price.

## Replicated: the crop it's loaded with (&"" empty), the last one it had, and
## the hybrids' mode (0 quick, 1 heavy).
var crop: StringName = &""
var last_crop: StringName = &""
var mode: int = 0

var rig: UniRig
var ctx := UniCtx.new()
var spec: Dictionary = {}

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_col := CropEffects.EMPTY_COLOR
var _idle_fx: CPUParticles3D
var _idle_crop: StringName = &"-"
var _shown_crop: StringName = &"-"
var _load_dur := 1.0
var _glow := 0.0
var _burst_n := 0
var _rest_pitch := UniKit.REST_UP
var _loaded_pitch := 0.0
var _no_aim := false
var _vis_tier := -1

## Loading animation lengths: a full load through the wheel, a quick reload.
const UNI_LOAD_TIME := 1.0
const RELOAD_TIME := 0.5
## Wave end: the crop drains and the barrel goes back up over this long.
const DRAIN_TIME := 1.0
## Idle sway of a loaded turret: half a degree over a two-second cycle.
const SWAY := 0.5 * PI / 180.0
const SWAY_PERIOD := 2.0


func setup(d: TurretDef, cid: int, c: Vector2i, pos: Vector3, owner_label: String, stack_level: int = 0) -> void:
	super.setup(d, cid, c, pos, owner_label, stack_level)
	spec = UniversalBuilder.spec(d.id, Palette.team_color(cid))
	if UniversalBuilder.rigged(d.id):
		# Its fal model (Nov 2026): Turret.setup built it under the pivots; the
		# code spec still gives the rest angles, its other places don't fit it.
		rig = UniRig.wrap(self, _recoil_len)
		spec = UniversalBuilder.rigged_spec(spec, rig.rigged_ring_r())
		if _empty_sign != null: # over the model, whatever its height
			_empty_sign.position.y = rig.rigged_top(self) + 0.35
	else:
		# Turret.setup put the merged model (the build ghost's) on as the base: the
		# live parts replace it.
		for ch in get_children():
			if ch is MeshInstance3D:
				ch.queue_free()
				break
		rig = UniRig.make(spec, self, _head, _gun)
	_rest_pitch = float(spec.get("rest_pitch", UniKit.REST_UP))
	_loaded_pitch = float(spec.get("loaded_pitch", 0.0))
	_no_aim = bool(spec.get("no_aim", false)) or d.obstruction
	if not rig.muzzles.is_empty():
		_muzzle = rig.muzzles[0]
	_gun.rotation.x = 0.0 if (_no_aim or rig.no_pitch) else _rest_pitch
	_make_ring(float(spec.get("ring_r", 0.85)))
	if _pip != null:
		_pip.visible = false
	add_to_group("universal_turrets")


func _make_synchronizer() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:aim_point", ".:shots", ".:tier", ".:has_ammo", ".:loaded", "Health:hp", ".:crop", ".:last_crop", ".:mode"]:
		var path := NodePath(p)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 0.1
	return sync


# ------------------------------------------------------------------ host: firing

func _think(delta: float) -> void:
	# Hybrids: the heavy barrel for heavy bugs, the quick one for the rest.
	if def.heavy_damage > 0.0 and _target != null and is_instance_valid(_target):
		var want := 1 if TurretDef.is_heavy(_target.def) else 0
		if want != mode:
			mode = want
			_cooldown = maxf(_cooldown, 0.2) # the switch takes a moment
	if def.special == &"fog":
		_fog_think(delta)
		return
	var before := shots
	super._think(delta)
	if shots != before:
		_after_shot()


## Bursts (Thresher Post) and the hybrids' heavy barrel set their own pace.
func _after_shot() -> void:
	if def.burst > 0:
		_burst_n += 1
		if _burst_n >= def.burst:
			_burst_n = 0
			_cooldown += def.burst_pause
	if mode == 1 and def.heavy_interval > 0.0:
		_cooldown *= def.heavy_interval / maxf(def.fire_interval, 0.01)


## Host (TurretEffects.apply): one shot lands on `target`. The crop's effect goes
## on every bug the shot hurts.
func universal_hit(target: Bug, aim: Vector3, damage: float) -> void:
	var source := "%s's %s" % [owner_name, def.display_name]
	var heavy := mode == 1 and def.heavy_damage > 0.0
	if heavy:
		damage = def.heavy_damage * TurretDef.UNI_DAMAGE[clampi(tier, 0, 2)]
	var dir := (aim - muzzle_position()).normalized()
	var pierce := def.armor_pierce or heavy
	match def.effect:
		TurretDef.Effect.SPLASH:
			var r := def.effect_size * (1.0 if def.anti_air or def.guards_plateau else range_multiplier())
			var c := crop
			var tgt_ref: WeakRef = weakref(target) # (it may die in flight)
			var flight := def.flight_time
			if flight <= 0.0:
				_splash(target, aim, r, damage, source, c)
			else:
				var me: WeakRef = weakref(self)
				var lead := aim + (target.velocity_hint() * flight if def.anti_air else Vector3.ZERO)
				get_tree().create_timer(flight).timeout.connect(func() -> void:
					var t := me.get_ref() as UniversalTurret
					if t != null:
						t._splash(tgt_ref.get_ref() as Bug, lead, r, damage, source, c))
		TurretDef.Effect.KNOCKBACK:
			_hit(target, aim, dir, damage, pierce, source)
			BossFx.on_water(self, target) # Boss: the blast washes Acid Matriarch acid off nearby turrets
			if target.is_alive():
				if TurretDef.is_heavy(target.def):
					if target.is_climbing():
						target.climb_y = maxf(target.climb_y - SpecialShotRules.slip_for(target, TurretEffects.HEAVY_SLIP), 0.0)
				else:
					target.knock_off(source, cliff_id)
		TurretDef.Effect.PIN:
			_hit(target, aim, dir, damage, pierce, source)
			if target.is_alive():
				target.status.root(def.effect_size * CropEffects.strength(tier))
				if def.anti_air:
					target.show_net.rpc(def.effect_size)
		_:
			_hit(target, aim, dir, damage, pierce, source)
			if def.special == TurretDef.SPECIAL_PIERCE:
				_pierce_on(target, aim, dir, damage, source)


## Host: one bug takes a hit and the crop's effect; a corn ricochet is drawn.
func _hit(b: Bug, at: Vector3, dir: Vector3, damage: float, pierce: bool, source: String, crop_on: bool = true) -> void:
	if b == null or not is_instance_valid(b) or not b.is_alive():
		return
	b.note_crop_hit(crop, source) # (the kill tallies)
	b.receive_hit(damage, at, dir, pierce, 1.0, source, cliff_id, CropEffects.armour_ignored(crop, tier))
	if crop_on and crop != &"":
		var to := CropEffects.on_hit(crop, self, b, damage, b.global_position, source)
		if to != Vector3.INF:
			crop_arc.rpc(b.global_position, to)


## Host: a splash of radius `r` at `at`: every bug of the same kind as the target
## (climbers on that wall, bugs on that ground, fliers) takes the hit and the crop.
func _splash(target: Bug, at: Vector3, r: float, damage: float, source: String, c: StringName) -> void:
	var climbing := target != null and target.is_climbing()
	var flying := def.anti_air
	var cliff := target.cliff_id if target != null else covers
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden():
			continue
		if flying != (b.state == Bug.State.FLYING):
			continue
		if not flying and (b.cliff_id != cliff or b.is_climbing() != climbing):
			continue
		var d := b.global_position.distance_to(at)
		if d > r:
			continue
		var keep := crop
		crop = c # (the shell carries the crop it was fired with)
		_hit(b, b.global_position, (b.global_position - at).normalized(), damage * lerpf(1.0, 0.45, d / maxf(r, 0.01)), true,
				source, b == target or c != &"corn")
		crop = keep
	splash_fx.rpc(at, r, CropEffects.color_of(c))


## Host: the Rail Driver's spike carries on through the bugs lined up behind the target.
func _pierce_on(target: Bug, aim: Vector3, dir: Vector3, damage: float, source: String) -> void:
	var from := muzzle_position()
	var line := (aim - from).normalized()
	var reach := def.range * range_multiplier()
	var hit: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or b == target or not b.is_alive() or b.is_hidden():
			continue
		var rel := b.global_position - from
		var along := rel.dot(line)
		if along <= aim.distance_to(from) - 0.5 or along > reach:
			continue
		if (rel - line * along).length() <= def.special_radius:
			hit.append(b)
	hit.sort_custom(func(a: Bug, b: Bug) -> bool: return a.global_position.distance_to(from) < b.global_position.distance_to(from))
	var dmg := damage
	var end := aim
	for i in mini(hit.size(), def.special_count):
		dmg *= def.special_falloff
		_hit(hit[i], hit[i].global_position, dir, dmg, true, source)
		end = hit[i].global_position
	if end != aim:
		crop_arc.rpc(aim, end)


## Host, Porch Fog: every second, every bug in the fog round it takes a little
## damage and the crop. Only while loaded.
var _fog_t := 0.0


func _fog_think(delta: float) -> void:
	if not can_fire():
		return
	_fog_t -= delta
	if _fog_t > 0.0:
		return
	_fog_t = def.interval_at(tier)
	var source := "%s's %s" % [owner_name, def.display_name]
	var r := def.effect_size * (1.0 + 0.15 * tier)
	var any := false
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden() or b.is_climbing() or b.cliff_id != cliff_id:
			continue
		if b.state == Bug.State.FLYING or b.global_position.distance_to(global_position) > r:
			continue
		b.status.slow(0.8, 1.2)
		_hit(b, b.global_position, Vector3.UP, def.damage_at(tier), true, source)
		any = true
	if any:
		shots += 1


# ------------------------------------------------------------------ every peer: drawing

## Every peer: a corn ricochet's golden arc, or a rail spike's line on.
@rpc("authority", "call_local", "unreliable")
func crop_arc(a: Vector3, b: Vector3) -> void:
	if vfx == null:
		return
	var col := CropEffects.color_of(crop)
	var mid := (a + b) * 0.5 + Vector3.UP * a.distance_to(b) * 0.25
	vfx.tracer(a, mid, col, 0.05)
	vfx.tracer(mid, b, col, 0.05)
	vfx.spark(b, (a - b).normalized(), col)


## Every peer: a splash's burst in the crop's colour.
@rpc("authority", "call_local", "unreliable")
func splash_fx(at: Vector3, r: float, col: Color) -> void:
	if vfx == null:
		return
	vfx.pop(at, col, r * 0.7)
	if def.effect == TurretDef.Effect.SPLASH and def.flight_time > 0.5:
		Audio.play_at(&"dynamite", at, -8.0, 1.25)


func _draw_shot() -> void:
	_idle_t = 0.0
	if rig != null and rig.rigged:
		rig.rigged_shot()
	var age := ctx.shot_age
	ctx.shots = shots
	ctx.shot_age = 0.0
	ctx.firing = ctx.firing + age if age < 0.8 else 0.0001
	var mz := _shot_muzzle()
	var from := mz.global_position
	var dir := -mz.global_basis.z
	var col := CropEffects.color_of(crop) if crop != &"" else Palette.GLOW_YELLOW
	if def.special == &"fog" or def.obstruction:
		return
	var spread := deg_to_rad(def.spread_deg)
	var to := aim_point + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * from.distance_to(aim_point) * spread
	if vfx != null:
		if def.flight_time > 0.0:
			vfx.lob(from, to, def.flight_time, col)
		elif def.effect == TurretDef.Effect.KNOCKBACK:
			vfx.tracer(from, to, Color(col, 0.6), 0.22)
			vfx.pop(from + dir * 0.6, Color(col, 0.7), 0.9)
		elif def.effect == TurretDef.Effect.PIN:
			vfx.lob(from, to, 0.35, col)
		else:
			var heavy := mode == 1 or def.job == "ST"
			vfx.tracer(from, to, col, 0.09 if heavy else 0.05)
			vfx.spark(to, (from - to).normalized(), col)
			# The crop's impact (fast guns show it every third shot).
			if crop != &"" and (def.fire_interval >= 0.3 or shots % 3 == 0):
				_impact_fx(to, (from - to).normalized(), col)
		vfx.muzzle_flash(from, dir)
	var sound := def.sound
	if (sound == &"gatling" or not Audio.has_sound(sound)):
		sound = StringName("gatling_%d" % (randi() % 3 + 1))
	Audio.play_at(sound, from, -3.0 if def.fire_interval < 0.2 else 0.0)


## Every peer: each crop's impact on a hit: chili a small orange burst, cotton a
## white puff, herbs a green one, sulfur a yellow one, cactus a crunch of grit,
## tumbleweed dry fibres, sarsaparilla an amber splash, corn and pear sparks.
func _impact_fx(at: Vector3, back: Vector3, col: Color) -> void:
	match crop:
		&"firecracker_chili":
			vfx.pop(at, col, maxf(def.crop_splash * 0.45, 0.6))
		&"cotton", &"herbs", &"sulfur_root", &"sarsaparilla":
			vfx.pop(at, col, 0.45)
		&"barrel_cactus":
			vfx.dust_burst(at, back, 0.5)
		&"tumbleweed_vine":
			vfx.splinter_chip(at, back)
		_:
			vfx.spark(at, back, col.lightened(0.3))


## The muzzle this shot comes out of: the barrels take turns; hybrids in heavy
## mode use their heavy barrel.
func _shot_muzzle() -> Node3D:
	if rig == null:
		return _muzzle
	var list := rig.heavy_muzzles if (mode == 1 and not rig.heavy_muzzles.is_empty()) else rig.muzzles
	if list.is_empty():
		return _muzzle
	return list[(shots - 1 + list.size()) % list.size()]


func muzzle_position() -> Vector3:
	return _muzzle.global_position if _muzzle != null else global_position


## Every peer, every frame: aim, the loading and wave-end animations, the glow,
## the base ring, the idle wisps and the model's own moving parts.
func _aim_visual(delta: float) -> void:
	if rig == null:
		return
	ctx.t += delta
	ctx.shot_age += delta
	if ctx.shot_age > 0.8:
		ctx.firing = 0.0
	ctx.tier = tier
	ctx.in_wave = _in_wave
	ctx.mode = mode
	ctx.mode_k = move_toward(ctx.mode_k, float(mode), delta / 0.2)
	ctx.hp_frac = health.fraction() if health != null else 1.0
	ctx.pitch = _gun.rotation.x
	ctx.yaw = _head.rotation.y
	ctx.charge = clampf(ctx.shot_age / maxf(def.interval_at(tier) * (def.heavy_interval / def.fire_interval if mode == 1 and def.heavy_interval > 0.0 else 1.0), 0.05), 0.0, 1.0)
	# Loading and wave end.
	var is_loaded := loaded and crop != &""
	if crop != _shown_crop:
		var was := _shown_crop
		_shown_crop = crop
		if crop != &"":
			_load_dur = RELOAD_TIME if was == &"" and crop == last_crop and ctx.crop == crop else UNI_LOAD_TIME
			ctx.load_k = 0.0
			ctx.drain_k = 1.0
			_pour(crop)
		elif was != &"-":
			ctx.drain_k = 0.0
	if ctx.load_k < 1.0:
		ctx.load_k = minf(ctx.load_k + delta / _load_dur, 1.0)
	if ctx.drain_k < 1.0:
		ctx.drain_k = minf(ctx.drain_k + delta / DRAIN_TIME, 1.0)
	if crop != &"":
		ctx.crop = crop
		ctx.color = CropEffects.color_of(crop)
	ctx.loaded = is_loaded
	# Glow: fades in over the end of a load, out over half a second at wave end.
	var want_glow := 0.0
	if is_loaded:
		want_glow = smoothstep(0.6, 1.0, ctx.load_k)
	_glow = move_toward(_glow, want_glow, delta / (0.3 if want_glow > _glow else 0.5))
	var pulse := 0.85 + 0.15 * sin(ctx.t * 2.4)
	rig.set_crop(ctx.color, _glow * pulse, is_loaded or ctx.drain_k < 0.6)
	_update_ring(delta, is_loaded)
	_update_idle(is_loaded)
	# Aim: track while loaded; rest barrel-up while empty.
	ctx.tracking = false
	if not _no_aim:
		_aim_pose(delta, is_loaded)
	if rig.rigged:
		rig.rigged_tick(delta)
	else:
		UniversalBuilder.animate(def.id, rig, ctx, delta)
	if tier != _vis_tier:
		_vis_tier = tier
		_show_tier()
	# EMPTY over an unloaded turret during a wave (an emergency load is still possible),
	# and any time you have the crop bag out: bigger, and seen through the scaffold,
	# so it reads at the bag's reach (CropBagUI).
	var bag := CropBagUI.held
	var want_sign := 1.0 if ((_in_wave or bag) and not is_loaded and not def.obstruction) else 0.0
	_set_sign(move_toward(_sign_a, want_sign, delta / SIGN_FADE))
	if _empty_sign != null:
		_empty_sign.no_depth_test = bag
		_empty_sign.scale = _empty_sign.scale.move_toward(Vector3.ONE * (1.7 if bag else 1.0), delta * 4.0)


func _aim_pose(delta: float, is_loaded: bool) -> void:
	var local := to_local(aim_point) - _head.position
	var yaw := atan2(-local.x, -local.z)
	var horizontal := Vector2(local.x, local.z).length()
	var pitch := clampf(atan2(local.y, horizontal), -deg_to_rad(pitch_limit()), deg_to_rad(85.0 if def.anti_air else 40.0))
	var cone := deg_to_rad(def.aim_half_deg()) if not (def.anti_air or def.guards_plateau) else PI
	if aim_point.distance_squared_to(_last_aim) > 0.0001 or (_target != null and is_instance_valid(_target)):
		_idle_t = 0.0
	_last_aim = aim_point
	_idle_t += delta
	var step := deg_to_rad(maxf(def.turn_speed, 10.0)) * delta
	if not is_loaded or ctx.load_k < 0.35:
		# Empty: barrel up, body back to centre (and while the hopper opens).
		var k := ctx.drain_k if ctx.drain_k < 1.0 else 1.0
		yaw = 0.0
		pitch = lerpf(_gun.rotation.x, _rest_pitch, k) if ctx.drain_k < 1.0 else _rest_pitch
		step = maxf(step, deg_to_rad(60.0) * delta)
	elif _idle_t > 3.0:
		# Loaded and nothing to shoot: level, with a slow half-degree sway.
		yaw = rotate_toward(_head.rotation.y, 0.0, step * 0.25)
		pitch = _loaded_pitch + sin(ctx.t * TAU / SWAY_PERIOD) * SWAY
		if def.anti_air: # air guns idle raised (their own angle when the model gives one)
			pitch = (_loaded_pitch if spec.has("loaded_pitch") else deg_to_rad(45.0)) + sin(ctx.t * TAU / SWAY_PERIOD) * SWAY
	else:
		ctx.tracking = true
	yaw = clampf(wrapf(yaw, -PI, PI), -cone, cone)
	if _fixed_yaw: # a model on a fixed bed (no swivel in its rig)
		yaw = 0.0
	_head.rotation.y = rotate_toward(_head.rotation.y, yaw, step)
	_gun.rotation.x = 0.0 if rig.no_pitch else rotate_toward(_gun.rotation.x, pitch, step * 1.5)


## A puff of the crop pouring in where the model takes it (spec "pour").
func _pour(c: StringName) -> void:
	var at: Vector3 = spec.get("pour", Vector3(0, 0.9, 0))
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3.DOWN
	p.spread = 15.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.1
	p.color = CropEffects.color_of(c)
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.04
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	box.material = m
	p.mesh = box
	p.position = at + Vector3.UP * 0.3
	_head.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	Audio.play_at(&"crank_gatling_close", global_position, -4.0)


# ------------------------------------------------------------------ base ring

func _make_ring(r: float) -> void:
	var st := MeshKit.begin()
	MeshKit.add_rim(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), r, r - 0.1, 0.03, 40, Color.WHITE)
	_ring = MeshInstance3D.new()
	_ring.mesh = MeshKit.finish(st)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = CropEffects.EMPTY_COLOR
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


## Grey when empty, the crop's colour when loaded (0.3 s blend), a faint pulse.
func _update_ring(delta: float, is_loaded: bool) -> void:
	var want := ctx.color * 1.25 if is_loaded and ctx.load_k > 0.6 else CropEffects.EMPTY_COLOR
	_ring_col = _ring_col.lerp(want, clampf(delta / 0.3 * 2.5, 0.0, 1.0))
	_ring_mat.albedo_color = _ring_col * (1.0 + 0.08 * sin(ctx.t * 3.0) if is_loaded else 1.0)


# ------------------------------------------------------------------ idle wisps

## Each crop's idle particles off a loaded turret (faint: many turrets show them).
## [colour, from the base (else the muzzle), velocity, gravity, lifetime, amount, size]
const IDLE: Dictionary = {
	&"corn": [Color("#FFD700"), false, Vector3(0, -0.05, -0.1), Vector3(0, -0.15, 0), 2.0, 5, 0.035],
	&"firecracker_chili": [Color("#5A4A44"), false, Vector3(0, 0.25, 0), Vector3(0, 0.15, 0), 1.6, 6, 0.08],
	&"prickly_pear": [Color("#2FB5A5"), false, Vector3(0, 0.05, 0), Vector3(0, 0.02, 0), 2.0, 5, 0.09],
	&"cotton": [Color("#FFFDF0"), false, Vector3(0, 0.1, 0), Vector3(0, 0.05, 0), 3.0, 4, 0.06],
	&"herbs": [Color("#3E9E3E"), true, Vector3(0, 0.05, 0), Vector3(0, 0.0, 0), 2.4, 6, 0.14],
	&"sulfur_root": [Color("#D8D040"), false, Vector3(0, 0.3, 0), Vector3(0, 0.12, 0), 1.8, 6, 0.08],
	&"barrel_cactus": [Color("#8C8A60"), true, Vector3(0, 0.05, 0), Vector3(0, -0.05, 0), 1.2, 2, 0.08],
	&"tumbleweed_vine": [Color("#C8A878"), true, Vector3(0.3, 0.05, 0), Vector3(0, -0.4, 0), 2.0, 3, 0.07],
	&"sarsaparilla": [Color("#FFBF00"), false, Vector3(0, 0.08, 0), Vector3(0, 0.03, 0), 2.2, 5, 0.08],
}


func _update_idle(is_loaded: bool) -> void:
	var want: StringName = crop if is_loaded and ctx.load_k >= 1.0 else &""
	if want == _idle_crop:
		if _idle_fx != null:
			_idle_fx.emitting = ctx.shot_age > 0.6 and ctx.drain_k >= 1.0
		return
	_idle_crop = want
	if _idle_fx != null:
		_idle_fx.queue_free()
		_idle_fx = null
	if want == &"" or not IDLE.has(want):
		return
	var s: Array = IDLE[want]
	var p := CPUParticles3D.new()
	p.amount = int(s[5])
	p.lifetime = float(s[4])
	p.direction = (s[2] as Vector3).normalized() if (s[2] as Vector3).length() > 0.0 else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = (s[2] as Vector3).length() * 0.5
	p.initial_velocity_max = (s[2] as Vector3).length()
	p.gravity = s[3]
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3 if bool(s[1]) else 0.06
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(s[0] as Color, 0.0))
	g.add_point(0.2, Color(s[0] as Color, 0.55))
	g.set_color(g.get_point_count() - 1, Color(s[0] as Color, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2.ONE * float(s[6]) * 2.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if ResourceLoader.exists("res://assets/fx/smoke.png") and float(s[6]) >= 0.08:
		m.albedo_texture = load("res://assets/fx/smoke.png")
	q.material = m
	p.mesh = q
	p.local_coords = false
	if bool(s[1]):
		p.position = Vector3(0, 0.15, 0)
		add_child(p)
	else:
		var at: Vector3 = spec.get("idle_at", Vector3.ZERO)
		if spec.has("idle_at"):
			p.position = at
			_gun.add_child(p)
		else:
			_muzzle.add_child(p)
	_idle_fx = p


# ------------------------------------------------------------------ tiers

func _show_tier() -> void:
	health.max_hp = def.hp_at(tier) * perk_hp
	if rig == null:
		return
	rig.show_tier(tier)
	var s := 1.0 + 0.1 * clampi(tier, 0, 2)
	for h in rig.holders:
		h.scale = Vector3.ONE * s


func range_multiplier() -> float:
	return TurretDef.range_mult(0, level) * perk_range * (Homestead.LOOKOUT_RANGE if Homestead.lookout_cliffs.has(cliff_id) else 1.0)


## Scrap (your own) for the next tier, or -1 at Tier 3 or before its wave.
func upgrade_cost() -> int:
	if tier >= 2 or GameState.tier_wave() < TurretDef.UNI_TIER_WAVES[tier + 1]:
		return -1
	return def.uni_upgrade_cost(tier + 1)


# ------------------------------------------------------------------ loading

## Fires this wave.
func can_fire() -> bool:
	return loaded and crop != &""


func wants_load() -> bool:
	return crop == &""


## Can the local player load or swap it right now? Build phase: always. In a
## wave: only an empty one (an emergency load).
func can_load_now() -> bool:
	if GameState.phase == GameState.Phase.GAME_OVER or health == null or health.hp <= 0.0:
		return false
	if def.obstruction and (crop != &"" or ctx.triggered):
		return false # one sack, once
	return GameState.phase != GameState.Phase.WAVE or crop == &""


## Sacks of `c` the local player can load from (this turret's cliff's stock).
func sacks_of(c: StringName) -> int:
	var item := CropEffects.sack_of(c)
	if item == &"":
		return 0
	return Economy.amount(Economy.payer_cliff(multiplayer.get_unique_id(), cliff_id), item)


## Local: ask the host to load crop `c`.
func request_load(c: StringName) -> void:
	if multiplayer.is_server():
		_host_load(multiplayer.get_unique_id(), c)
	else:
		_request_load.rpc_id(1, c)


@rpc("any_peer", "reliable")
func _request_load(c: StringName) -> void:
	if multiplayer.is_server():
		_host_load(multiplayer.get_remote_sender_id(), c)


## Host: spend one sack of `c` and load it (a swap in the build phase gives the
## old sack back).
func _host_load(peer_id: int, c: StringName) -> void:
	if not CropEffects.is_crop(c) or c == crop or not is_inside_tree():
		return
	if BuildManager.instance != null and peer_id > 0 and not BuildManager.instance.may_build(peer_id, cliff_id):
		return
	if GameState.phase == GameState.Phase.GAME_OVER:
		return
	if def.obstruction and crop != &"":
		return
	if GameState.phase == GameState.Phase.WAVE and crop != &"":
		Economy.notify(peer_id, "It's loaded until the wave ends.")
		return
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	var item := CropEffects.sack_of(c)
	if item == &"" or not Economy.spend(payer, {item: 1}):
		Economy.notify(peer_id, "No sacks of %s. Harvest some and make sacks at the root cellar's workbench." % CropEffects.short_name(c).to_lower())
		return
	if crop != &"" and GameState.phase != GameState.Phase.WAVE:
		Economy.earn(payer, {CropEffects.sack_of(crop): 1}) # swapped out before the wave: the sack comes back
	crop = c
	last_crop = c
	loaded = true
	_on_loaded()


## Host (the CPU partner): the sack it would load: its last crop if the cliff has
## one, else whichever crop the cliff has most of. &"" when there's none.
func cpu_sack() -> StringName:
	var c := _cpu_crop()
	return CropEffects.sack_of(c) if c != &"" else &""


func _cpu_crop() -> StringName:
	if last_crop != &"" and Economy.amount(cliff_id, CropEffects.sack_of(last_crop)) > 0:
		return last_crop
	var best: StringName = &""
	var most := 0
	for c: StringName in CropEffects.IDS:
		var n := Economy.amount(cliff_id, CropEffects.sack_of(c))
		if n > most:
			most = n
			best = c
	return best


## Host (the CPU partner): load it from the cliff's own stock.
func cpu_load_any() -> bool:
	var c := _cpu_crop()
	if c == &"" or not wants_load():
		return false
	_host_load(0, c)
	return crop == c


## Host: a hook for the obstructions (armed once loaded).
func _on_loaded() -> void:
	pass


## Host: a wave ending spends every loaded turret's sack (not the obstructions':
## theirs lasts until they go off).
func _on_phase_changed(p: GameState.Phase) -> void:
	var was := _in_wave
	_in_wave = p == GameState.Phase.WAVE
	if was and not _in_wave and multiplayer.is_server() and not def.obstruction:
		loaded = false
		crop = &""


func local_interact(holding: bool) -> void:
	if holding:
		if needs_repair() and not def.obstruction:
			BuildManager.instance.repair_node(self)
		return
	if can_load_now():
		if last_crop != &"" and last_crop != crop and sacks_of(last_crop) > 0:
			request_load(last_crop)
			return
		if crop == &"" or GameState.phase != GameState.Phase.WAVE:
			CropWheel.open_for(self)
			return
	if needs_repair() and not def.obstruction:
		BuildManager.instance.repair_node(self)


## Q on it (CropWheel takes the key while you look at one): the crop wheel.
func local_swap() -> bool:
	if not can_load_now():
		return false
	CropWheel.open_for(self)
	return true


## The turret card (HudPromptCard.show_turret reads this): name and tier, the
## crop and its effect in its colour, the last crop, and the keys that work now.
func interact_prompt() -> String:
	return "@turret:" + JSON.stringify(card_info())


func card_info() -> Dictionary:
	var keys: Array = []
	var notes: Array = []
	var me_ok := can_load_now()
	if me_ok:
		if last_crop != &"" and last_crop != crop and sacks_of(last_crop) > 0:
			keys.append(["E", "Reload %s" % CropEffects.short_name(last_crop)])
		elif crop == &"":
			keys.append(["E", "Load"])
		keys.append(["Q", "Swap" if crop != &"" else "Pick Crop"])
	elif _in_wave and crop != &"" and not def.obstruction:
		notes.append("Loaded until the wave ends")
	if def.obstruction and crop != &"":
		notes.append("Armed: goes off once")
	if needs_repair() and not def.obstruction:
		keys.append(["Hold E", "Repair"])
	var up := upgrade_cost()
	if up > 0:
		keys.append(["U", "Tier %d (%s)" % [tier + 2, UiStyle.cost(up, ResNames.PERSONAL_ID)]])
	elif tier < 2 and not def.obstruction:
		notes.append("Tier %d at wave %d" % [tier + 2, TurretDef.UNI_TIER_WAVES[tier + 1]])
	var kills: Array = [] # [[crop, n], ...] most first (the tally, by the crop that did it)
	var by: Dictionary = TurretTallies.crop_kills_of(self)
	for c: Variant in by:
		kills.append([String(c), int(by[c])])
	kills.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return {"name": def.display_name, "tier": tier + 1, "job": def.job, "kills": kills, "kills_total": TurretTallies.kills_of(self),
		"crop": String(crop), "crop_name": CropEffects.short_name(crop) if crop != &"" else "",
		"effect": CropEffects.effect_name(crop), "color": CropEffects.color_of(crop).to_html(false),
		"last": CropEffects.short_name(last_crop) if last_crop != &"" else "None",
		"hp": "%d / %d" % [int(health.hp), int(health.max_hp)], "keys": keys, "notes": notes}
