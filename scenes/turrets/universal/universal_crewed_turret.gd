class_name UniversalCrewedTurret
extends CrewedTurret
## A universal crop-fed crewed gun (the handoff's Crewed Turrets): a CrewedTurret
## you sit in (E takes the seat, the mouse aims, LMB fires; left alone it fires
## at half rate), loaded like every universal turret with any of the nine crops
## (Q opens the crop wheel; one sack a wave), and every hit carries the crop.
##   Iron Mule      six barrels you crank: spins up over 2 s, overheats after 8 s
##                  of fire and cools for 2 s
##   Crop Howitzer  a volley of four crop shells, then the rack refills
##   Sky Hound      one heavy round; RMB scopes in (+25% damage, a closer view)
##   Vortex Engine  throws a vortex onto the far wall: bugs in it are held and
##                  take the crop every second
##   Thunder Mule   cycles itself: a 3-shell salvo, then a heavy round, then a salvo
## Its model is UniversalBuilder's parts as live nodes (UniRig), like the other
## universal turrets'.

# Replicated.
var crop: StringName = &""
var last_crop: StringName = &""
## Thunder Mule: 0 the salvo fires next, 1 the heavy round. Sky Hound: 1 scoped.
var mode: int = 0
var vortex_at := Vector3.ZERO
var vortex_on := false

var rig: UniRig
var ctx := UniCtx.new()
var spec: Dictionary = {}
var look: UniLook
var _shown_crop: StringName = &"-"
var _glow_k := 0.0
var _rest_pitch := UniKit.REST_UP
# Host.
var _volley_left := 0
var _volley_t := 0.0
var _volley_at := Vector3.ZERO
var _volley_mult := 1.0
var _vortex_left := 0.0
var _vortex_tick := 0.0
var _vortex_mult := 1.0
var _fire_t := 0.0
# Every peer: the vortex funnel.
var _funnel: CPUParticles3D
var _scoped_fov := false

const MULE_HEAT_TIME := 8.0
const MULE_COOL_TIME := 2.0
const MULE_SPIN_TIME := 2.0
const SCOPE_BONUS := 1.25
const VOLLEY_GAP := 0.28


func setup(d: TurretDef, cid: int, c: Vector2i, pos: Vector3, owner_label: String, _stack_level: int = 0) -> void:
	super.setup(d, cid, c, pos, owner_label, _stack_level)
	for ch in get_children():
		if ch is MeshInstance3D:
			ch.queue_free() # the merged ghost model: the live parts replace it
			break
	spec = UniversalBuilder.spec(d.id, Palette.team_color(cid))
	rig = UniRig.make(spec, self, _head, _gun)
	if spec.has("seat"):
		_seat_eye = spec["seat"]
	_head.position.z = float(spec.get("head_z", 0.0))
	if not rig.muzzles.is_empty():
		_muzzle = rig.muzzles[0]
	_rest_pitch = float(spec.get("rest_pitch", UniKit.REST_UP))
	_gun.rotation.x = _rest_pitch
	look = UniLook.new(self, spec, _head, _gun, _muzzle)
	if _pip != null:
		_pip.visible = false
	add_to_group("universal_turrets")


func _make_synchronizer() -> MultiplayerSynchronizer:
	var sync := super._make_synchronizer()
	for p: String in [".:crop", ".:last_crop", ".:mode", ".:vortex_at", ".:vortex_on"]:
		var path := NodePath(p)
		sync.replication_config.add_property(path)
		sync.replication_config.property_set_spawn(path, true)
		sync.replication_config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	return sync


# ------------------------------------------------------------------ host: firing

func _think_auto(delta: float) -> void:
	_cooldown -= delta
	_retarget -= delta
	reeling = false
	_tick_volley(delta)
	_tick_vortex(delta)
	_cool_barrels(0, false, delta)
	var lost := _target != null and (not is_instance_valid(_target) or not _target.is_alive() or _target.untargetable())
	if _retarget <= 0.0 or lost:
		_retarget = RETARGET_TIME + randf() * 0.1
		_target = _pick_target()
	if _target == null:
		return
	aim_point = _target.global_position
	_idle_t = 0.0
	if _cooldown > 0.0 or _aim_error_deg() > ALIGN_TOLERANCE_DEG * 2.0 or _volley_left > 0:
		return
	var mult := CrewRules.UNMANNED_MULT
	_cooldown = def.interval_at(tier) * perk_rate / mult
	_fire_at(aim_point, mult, false)


func _think_manned(delta: float) -> void:
	_cooldown -= delta
	_target = null
	aim_point = clamp_aim(_in_aim)
	_idle_t = 0.0
	_tick_volley(delta)
	_tick_vortex(delta)
	mode = 1 if (def.id == &"cf_sky_hound" and _in_alt) else (mode if def.id == &"cf_thunder_mule" else 0)
	if def.id == &"cf_iron_mule":
		# Crank it: the barrels spin up over 2 s, fire faster as they go, and
		# overheat after 8 s of fire (2 s to cool).
		var cranking := _in_fire and not overheated
		spin_up = move_toward(spin_up, 1.0 if cranking else 0.0, delta / (MULE_SPIN_TIME if cranking else 1.0))
		var rounds := 0
		if cranking and spin_up >= CrewRules.SPIN_FIRE_MIN:
			var iv := def.interval_at(tier) * perk_rate / maxf(spin_up, 0.25)
			_cooldown = maxf(_cooldown, -delta)
			while _cooldown <= 0.0 and rounds < 4:
				_cooldown += iv
				rounds += 1
				_round(aim_point, 1.0)
		_cool_barrels(rounds, cranking, delta)
		shots += rounds
		return
	if _in_fire and _cooldown <= 0.0 and _volley_left <= 0:
		_cooldown = def.interval_at(tier) * perk_rate
		_fire_at(aim_point, 1.0, true)


## Iron Mule's heat: climbs over 8 s of fire, then 2 s to cool before it turns again.
func _cool_barrels(rounds: int, firing: bool, delta: float) -> void:
	if def.id != &"cf_iron_mule":
		return
	if crew_peer == 0:
		spin_up = move_toward(spin_up, 0.0, delta)
	if overheated:
		heat = maxf(heat - delta / MULE_COOL_TIME, 0.0)
		if heat <= 0.0:
			overheated = false
	elif firing and rounds >= 0 and spin_up > CrewRules.SPIN_FIRE_MIN:
		heat = minf(heat + delta / MULE_HEAT_TIME, 1.0)
		if heat >= 1.0:
			overheated = true
	else:
		heat = maxf(heat - delta / (MULE_HEAT_TIME * 0.5), 0.0)


## One shot (or a volley, a vortex, a salvo) at `at`, by kind.
func _fire_at(at: Vector3, mult: float, manned: bool) -> void:
	match def.id:
		&"cf_iron_mule":
			shots += 1
			_round(at, mult)
		&"cf_crop_howitzer":
			_volley_left = maxi(def.special_count, 1)
			_volley_t = 0.0
			_volley_at = at
			_volley_mult = mult
		&"cf_sky_hound":
			shots += 1
			_round(at, mult * (SCOPE_BONUS if manned and mode == 1 else 1.0), true)
		&"cf_vortex_engine":
			shots += 1
			vortex_at = at
			vortex_on = true
			_vortex_left = def.special_pin * CropEffects.strength(tier)
			_vortex_tick = 0.0
			_vortex_mult = mult
		&"cf_thunder_mule":
			shots += 1
			if mode == 0:
				var offs := CrewRules.salvo_offsets(shots)
				var from := muzzle_position()
				for i in mini(offs.size(), maxi(def.special_count, 1)):
					var land := at + Vector3(0, offs[i].y, offs[i].x)
					UniHits.delayed_splash(self, crop, 0.15 * i + CrewRules.lob_time(from.distance_to(land)), land,
							def.effect_size * range_multiplier(), def.damage_at(tier) * mult, _source(), WorldLayout.other_cliff(cliff_id), true, false)
				mode = 1
			else:
				_round(at, mult, true, def.heavy_damage * TurretDef.UNI_DAMAGE[clampi(tier, 0, 2)])
				mode = 0
			_cooldown += 0.2 # the linkage swapping over


## Host: a hitscan round down the aim: the first bug (or flier) it meets.
func _round(at: Vector3, mult: float, heavy: bool = false, dmg_override: float = -1.0) -> void:
	var from := muzzle_position()
	var dir := _spread((at - from).normalized(), def.spread_deg * (0.3 if heavy else 1.0))
	var hit := _ray(from, from + dir * def.range * range_multiplier() * 1.2)
	var hb := hit.get("collider") as Hitbox
	if hb == null:
		return
	var bug := hb.target as Bug
	if bug == null:
		return
	var dmg := dmg_override if dmg_override > 0.0 else def.damage_at(tier, TurretDef.is_heavy(bug.def))
	var end := UniHits.hit(self, crop, bug, hit["position"], dir, dmg * mult, def.armor_pierce or heavy, _source())
	if end != Vector3.INF:
		crop_arc.rpc(bug.global_position, end)


## Host: the howitzer's volley, one shell every VOLLEY_GAP.
func _tick_volley(delta: float) -> void:
	if _volley_left <= 0:
		return
	_volley_t -= delta
	if _volley_t > 0.0:
		return
	_volley_t = VOLLEY_GAP
	_volley_left -= 1
	shots += 1
	var land := _volley_at + Vector3(0, randf_range(-1.5, 1.5), randf_range(-2.5, 2.5))
	UniHits.delayed_splash(self, crop, def.flight_time, land, def.effect_size * range_multiplier(), def.damage_at(tier) * _volley_mult,
			_source(), WorldLayout.other_cliff(cliff_id), true, false)
	if _volley_left <= 0:
		_cooldown = maxf(_cooldown, def.interval_at(tier) * perk_rate / _volley_mult)


## Host: the vortex holds every climber in it and gives it the crop once a second.
func _tick_vortex(delta: float) -> void:
	if not vortex_on:
		return
	_vortex_left -= delta
	if _vortex_left <= 0.0:
		vortex_on = false
		_cooldown = maxf(_cooldown, def.interval_at(tier) * perk_rate / _vortex_mult)
		return
	_vortex_tick -= delta
	if _vortex_tick > 0.0:
		return
	_vortex_tick = 1.0
	var r := def.effect_size * (1.0 + 0.15 * tier)
	var far := WorldLayout.other_cliff(cliff_id)
	for b: Bug in bug_manager.climbers_on(far):
		if not b.is_alive() or b.global_position.distance_to(vortex_at) > r:
			continue
		b.status.root(1.15)
		b.status.slow(0.4, 1.5)
		UniHits.hit(self, crop, b, b.global_position, (vortex_at - b.global_position).normalized(), def.damage_at(tier) * _vortex_mult, true, _source())


# ------------------------------------------------------------------ loading (as UniversalTurret)

func can_fire() -> bool:
	return loaded and crop != &""


func wants_load() -> bool:
	return crop == &""


func can_load_now() -> bool:
	if GameState.phase == GameState.Phase.GAME_OVER or health == null or health.hp <= 0.0:
		return false
	return GameState.phase != GameState.Phase.WAVE or crop == &""


func sacks_of(c: StringName) -> int:
	var item := CropEffects.sack_of(c)
	if item == &"":
		return 0
	return Economy.amount(Economy.payer_cliff(multiplayer.get_unique_id(), cliff_id), item)


func request_load(c: StringName) -> void:
	if multiplayer.is_server():
		_host_load(multiplayer.get_unique_id(), c)
	else:
		_request_load.rpc_id(1, c)


@rpc("any_peer", "reliable")
func _request_load(c: StringName) -> void:
	if multiplayer.is_server():
		_host_load(multiplayer.get_remote_sender_id(), c)


func _host_load(peer_id: int, c: StringName) -> void:
	if not CropEffects.is_crop(c) or c == crop or not is_inside_tree() or GameState.phase == GameState.Phase.GAME_OVER:
		return
	if BuildManager.instance != null and peer_id > 0 and not BuildManager.instance.may_build(peer_id, cliff_id):
		return
	if GameState.phase == GameState.Phase.WAVE and crop != &"":
		Economy.notify(peer_id, "It's loaded until the wave ends.")
		return
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	var item := CropEffects.sack_of(c)
	if item == &"" or not Economy.spend(payer, {item: 1}):
		Economy.notify(peer_id, "No sacks of %s. Harvest some and store them in the root cellar." % CropEffects.short_name(c).to_lower())
		return
	if crop != &"" and GameState.phase != GameState.Phase.WAVE:
		Economy.earn(payer, {CropEffects.sack_of(crop): 1})
	crop = c
	last_crop = c
	loaded = true


func _on_phase_changed(p: GameState.Phase) -> void:
	var was := _in_wave
	_in_wave = p == GameState.Phase.WAVE
	if was and not _in_wave and multiplayer.is_server():
		loaded = false
		crop = &""
		vortex_on = false
		_volley_left = 0


func local_swap() -> bool:
	if not can_load_now():
		return false
	CropWheel.open_for(self)
	return true


func range_multiplier() -> float:
	return TurretDef.range_mult(0, level) * perk_range * (Homestead.LOOKOUT_RANGE if Homestead.lookout_cliffs.has(cliff_id) else 1.0)


func upgrade_cost() -> int:
	if tier >= 2 or GameState.tier_wave() < TurretDef.UNI_TIER_WAVES[tier + 1]:
		return -1
	return def.uni_upgrade_cost(tier + 1)


func interact_prompt() -> String:
	var keys: Array = []
	var notes: Array = []
	if crew_peer != 0 and crew_peer != multiplayer.get_unique_id():
		notes.append("Manned by %s" % _crew_name())
	else:
		keys.append([KeyHints.key_for("interact"), "Take the Seat"])
		notes.append("Unmanned: fires at half rate and damage")
	if can_load_now():
		keys.append(["Q", "Swap" if crop != &"" else "Pick Crop"])
	if needs_repair():
		keys.append(["Hold E", "Repair"])
	var up := upgrade_cost()
	if up > 0:
		keys.append(["U", "Tier %d (%s)" % [tier + 2, UiStyle.cost(up, ResNames.PERSONAL_ID)]])
	elif tier < 2:
		notes.append("Tier %d at wave %d" % [tier + 2, TurretDef.UNI_TIER_WAVES[tier + 1]])
	return "@turret:" + JSON.stringify({"name": def.display_name, "tier": tier + 1, "job": def.job,
		"crop": String(crop), "crop_name": CropEffects.short_name(crop) if crop != &"" else "",
		"effect": CropEffects.effect_name(crop), "color": CropEffects.color_of(crop).to_html(false),
		"last": CropEffects.short_name(last_crop) if last_crop != &"" else "None",
		"hp": "%d / %d" % [int(health.hp), int(health.max_hp)], "keys": keys, "notes": notes})


## In the seat: what the prompt card shows.
func crew_prompt() -> String:
	var leave := "%s: leave the seat" % KeyHints.key_for("interact")
	var fire := KeyHints.key_for("fire")
	var alt := KeyHints.key_for("alt_fire")
	var c := CropEffects.short_name(crop) + " (" + CropEffects.effect_name(crop) + ")" if crop != &"" else "EMPTY: load a crop first (Q outside the seat)"
	match def.id:
		&"cf_iron_mule":
			var state := "COOLING DOWN" if overheated else "heat %d%%" % (roundi(heat * 10.0) * 10)
			return "Iron Mule - %s - %s\n%s: hold to crank and fire   %s" % [c, state, fire, leave]
		&"cf_sky_hound":
			return "Sky Hound - %s\n%s: fire   %s: hold to scope in   %s" % [c, fire, alt, leave]
		&"cf_vortex_engine":
			return "Vortex Engine - %s%s\n%s: throw a vortex   %s" % [c, " - vortex up" if vortex_on else "", fire, leave]
		&"cf_thunder_mule":
			return "Thunder Mule - %s - next: %s\n%s: fire   %s" % [c, "heavy round" if mode == 1 else "salvo", fire, leave]
	return "%s - %s\n%s: fire a volley   %s" % [def.display_name, c, fire, leave]


# ------------------------------------------------------------------ every peer: looks

@rpc("authority", "call_local", "unreliable")
func crop_arc(a: Vector3, b: Vector3) -> void:
	if vfx == null:
		return
	var col := CropEffects.color_of(crop)
	var mid := (a + b) * 0.5 + Vector3.UP * a.distance_to(b) * 0.25
	vfx.tracer(a, mid, col, 0.05)
	vfx.tracer(mid, b, col, 0.05)


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
	ctx.crewed = crew_peer != 0
	ctx.heat = heat
	ctx.overheated = overheated
	ctx.spin = spin_up
	ctx.pitch = _gun.rotation.x
	ctx.yaw = _head.rotation.y
	ctx.hp_frac = health.fraction()
	ctx.charge = clampf(ctx.shot_age / maxf(def.interval_at(tier), 0.05), 0.0, 1.0)
	var is_loaded := loaded and crop != &""
	if crop != _shown_crop:
		var was := _shown_crop
		_shown_crop = crop
		if crop != &"":
			ctx.load_k = 0.0
			ctx.drain_k = 1.0
			look.pour(crop)
		elif was != &"-":
			ctx.drain_k = 0.0
	ctx.load_k = minf(ctx.load_k + delta / UniversalTurret.UNI_LOAD_TIME, 1.0)
	ctx.drain_k = minf(ctx.drain_k + delta / UniversalTurret.DRAIN_TIME, 1.0)
	if crop != &"":
		ctx.crop = crop
		ctx.color = CropEffects.color_of(crop)
	ctx.loaded = is_loaded
	_glow_k = move_toward(_glow_k, smoothstep(0.6, 1.0, ctx.load_k) if is_loaded else 0.0, delta / 0.4)
	rig.set_crop(ctx.color, _glow_k * (0.85 + 0.15 * sin(ctx.t * 2.4)) + (heat * 0.6 if def.id == &"cf_iron_mule" else 0.0), is_loaded or ctx.drain_k < 0.6)
	look.update(delta, ctx, is_loaded, crop)
	# Unmanned aim (the seat's aim is set after, in _after_visual).
	if crew_peer == 0 or _me == null:
		var local := to_local(aim_point) - _head.position
		var yaw := clampf(atan2(-local.x, -local.z), -deg_to_rad(def.crew_yaw_arc_deg), deg_to_rad(def.crew_yaw_arc_deg))
		var pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), -deg_to_rad(pitch_limit()), deg_to_rad(def.crew_pitch_up_deg))
		if aim_point.distance_squared_to(_last_aim) > 0.0001 or (_target != null and is_instance_valid(_target)):
			_idle_t = 0.0
		_last_aim = aim_point
		_idle_t += delta
		if not is_loaded:
			yaw = 0.0
			pitch = _rest_pitch
		elif _idle_t > 3.0:
			yaw = 0.0
			pitch = 0.0 + sin(ctx.t * PI) * 0.01
		var step := deg_to_rad(maxf(def.turn_speed, 30.0)) * delta
		_head.rotation.y = rotate_toward(_head.rotation.y, yaw, step)
		_gun.rotation.x = rotate_toward(_gun.rotation.x, pitch, step)
	UniversalBuilder.animate(def.id, rig, ctx, delta)
	if tier != _shown_tier:
		_shown_tier = tier
		health.max_hp = def.hp_at(tier) * perk_hp
		rig.show_tier(tier)
		for h in rig.holders:
			h.scale = Vector3.ONE * (1.0 + 0.1 * tier)
	# The vortex funnel on the far wall.
	if vortex_on and _funnel == null:
		_funnel = _make_funnel()
		get_tree().current_scene.add_child(_funnel)
	if _funnel != null:
		_funnel.global_position = vortex_at
		if not vortex_on:
			_funnel.emitting = false
			get_tree().create_timer(1.2).timeout.connect(_funnel.queue_free)
			_funnel = null
	# Sky Hound: the scope closes the gunner's view in.
	if def.id == &"cf_sky_hound" and _me != null and is_instance_valid(_me):
		var want := Input.is_action_pressed("alt_fire") and not GameState.menu_open
		_me.camera.fov = lerpf(_me.camera.fov, 32.0 if want else Settings.fov, 1.0 - exp(-delta * 10.0)) if "fov" in Settings else _me.camera.fov
		_scoped_fov = want


func _make_funnel() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.FORWARD
	p.emission_ring_radius = def.effect_size
	p.emission_ring_inner_radius = def.effect_size * 0.3
	p.emission_ring_height = 0.5
	p.orbit_velocity_min = 0.6
	p.orbit_velocity_max = 0.9
	p.radial_accel_min = -6.0
	p.radial_accel_max = -4.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var col := CropEffects.color_of(crop)
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.add_point(0.3, Color(col, 0.7))
	g.set_color(g.get_point_count() - 1, Color(col.lightened(0.3), 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	if ResourceLoader.exists("res://assets/fx/smoke.png"):
		m.albedo_texture = load("res://assets/fx/smoke.png")
	q.material = m
	p.mesh = q
	p.local_coords = false
	p.emitting = true
	return p


func _leave_seat(tell_host: bool = true) -> void:
	if _scoped_fov and _me != null and is_instance_valid(_me) and "fov" in Settings:
		_me.camera.fov = Settings.fov
	_scoped_fov = false
	super._leave_seat(tell_host)


func _draw_shot() -> void:
	var n := clampi(shots - _drawn, 1, 4)
	_drawn = shots
	_idle_t = 0.0
	var age := ctx.shot_age
	ctx.shots = shots
	ctx.shot_age = 0.0
	ctx.firing = ctx.firing + age if age < 0.8 else 0.0001
	_local_cd = def.interval_at(tier) * perk_rate * (1.0 if crew_peer != 0 else 1.0 / CrewRules.UNMANNED_MULT)
	var list := rig.heavy_muzzles if (def.id == &"cf_thunder_mule" and mode == 0 and not rig.heavy_muzzles.is_empty()) else rig.muzzles
	var mz: Node3D = list[(shots - 1 + list.size()) % list.size()] if not list.is_empty() else _muzzle
	var from := mz.global_position
	var fwd := -mz.global_basis.z
	var col := CropEffects.color_of(crop) if crop != &"" else Palette.GLOW_YELLOW
	if vfx == null:
		return
	match def.id:
		&"cf_iron_mule":
			for k in n:
				var dir := _spread((aim_point - from).normalized(), def.spread_deg)
				vfx.tracer(from, from + dir * from.distance_to(aim_point), col, 0.06)
			vfx.muzzle_flash(from, fwd)
			Audio.play_at(StringName("gatling_%d" % (randi() % 3 + 1)), from, -5.0)
		&"cf_crop_howitzer", &"cf_thunder_mule":
			if def.id == &"cf_thunder_mule" and mode == 0: # (mode already flipped: this was the heavy round)
				vfx.tracer(from, aim_point, col, 0.12)
				vfx.muzzle_flash(from, fwd)
				Audio.play_at(&"cannon", from)
			else:
				vfx.lob(from, aim_point, def.flight_time if def.flight_time > 0.0 else 1.0, col)
				vfx.muzzle_flash(from, fwd)
				Audio.play_at(&"mortar", from, -2.0)
		&"cf_sky_hound":
			vfx.tracer(from, aim_point, col.lightened(0.2), 0.1)
			vfx.muzzle_flash(from, fwd)
			Audio.play_at(&"cannon", from, -2.0)
		&"cf_vortex_engine":
			vfx.tracer(from, vortex_at if vortex_at != Vector3.ZERO else aim_point, Color(col, 0.7), 0.3)
			Audio.play_at(&"steam", from)
