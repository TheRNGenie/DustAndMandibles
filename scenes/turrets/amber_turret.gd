class_name AmberTurret
extends Turret
## The three hive amber turrets (AmberRules; meshes in gen/amber_builder.gd).
## Same rules as every turret (the cliff they cover, the thirty-degree look-down
## law, range, line of sight; the host aims and decides), with their own shots:
##   Amber Kiln      lobs molten amber: splash, and every non-boss bug it leaves
##                   below half health is ENTOMBED (Bug.entomb): a statue on the
##                   wall that turrets leave alone and climbers must go round.
##                   Any other hit shatters a statue for a small loot burst; the
##                   amber turrets' own shots never do. Bosses are slowed instead.
##   Queen's Bell    tolls (no aim needed) whenever something's in reach: every
##                   ordinary climber in range on the partner's wall turns on its
##                   neighbours for 6 s (Bug.frenzy), fliers in range drop out of
##                   the air (Bug.drop_from_sky), bosses are stunned 2 s.
##   Mandible Lance  one continuous beam onto the partner's wall: everything in
##                   the beam's spot or along its line burns, and the spot drags
##                   from bug to bug leaving a burning trail. 8 s of fire overheats
##                   it; it vents for 10 s.
## Every peer draws them: an amber glow and embers, the kiln's lob and splat, the
## bell's hammer and toll rings, the lance's beam (beam_on / heat are synced).

# Replicated (the lance).
var beam_on := false
var heat := 0.0
var venting := false

var _glow: OmniLight3D
var _embers: GPUParticles3D
var _beam: MeshInstance3D
var _beam_core: MeshInstance3D
var _spot_light: OmniLight3D
var _spark_t := 0.0
var _trail_t := 0.0
var _trail_from := Vector3.INF
var _dmg_acc := 0.0
var _vent_t := 0.0
var _rail_x := 0.0
var _was_beam := false
## Debug (--amberview): what the turret did this run.
var stats: Dictionary = {}


func setup(d: TurretDef, cid: int, c: Vector2i, pos: Vector3, owner_label: String, stack_level: int = 0) -> void:
	super.setup(d, cid, c, pos, owner_label, stack_level)
	add_to_group("amber_turrets")
	_glow = OmniLight3D.new()
	_glow.light_color = AmberRules.GLOW
	_glow.light_energy = 1.4
	_glow.omni_range = 4.5
	_glow.position = Vector3(0, 1.4, 0)
	add_child(_glow)
	_embers = _make_embers()
	_embers.position = Vector3(0, 1.2, 0)
	add_child(_embers)
	if d.special == TurretDef.SPECIAL_BELL:
		# The steam hammer stands in front of the bell (canyon side), striking back into it.
		_head.position.z = -0.9
	if d.special == TurretDef.SPECIAL_LANCE:
		_beam = _beam_mesh(false)
		_beam_core = _beam_mesh(true)
		_spot_light = OmniLight3D.new()
		_spot_light.light_color = AmberRules.GLOW
		_spot_light.light_energy = 0.0
		_spot_light.omni_range = 7.0
		add_child(_spot_light)
		_spot_light.top_level = true


func _make_synchronizer() -> MultiplayerSynchronizer:
	var sync := super._make_synchronizer()
	for p: String in [".:beam_on", ".:heat", ".:venting"]:
		var path := NodePath(p)
		sync.replication_config.add_property(path)
		sync.replication_config.property_set_spawn(path, true)
		sync.replication_config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	return sync


func _source() -> String:
	return "%s's %s" % [owner_name, def.display_name]


# ------------------------------------------------------------------ host brains

func _think(delta: float) -> void:
	match def.special:
		TurretDef.SPECIAL_BELL:
			_think_bell(delta)
		TurretDef.SPECIAL_LANCE:
			_think_lance(delta)
		_:
			super._think(delta) # the kiln aims and fires like a mortar; amber_shot() is its landing


## Amber Kiln (from TurretEffects.apply): the gobbet lands after the flight.
func amber_shot(target: Bug, aim: Vector3, _damage: float) -> void:
	var base := def.damage_at(tier) # per bug: the heavy bonus is worked out for each one it splashes
	var cliff := target.cliff_id
	var radius := def.effect_size * range_multiplier()
	var source := _source()
	var owner_cliff := cliff_id
	var normal := target.global_basis.y if target.is_climbing() else Vector3.UP
	var self_ref: WeakRef = weakref(self)
	var bugs_ref: WeakRef = weakref(Turret.bug_manager)
	get_tree().create_timer(def.flight_time).timeout.connect(func() -> void:
		var bugs := bugs_ref.get_ref() as BugManager
		if bugs == null:
			return
		var entombed := 0
		for b: Bug in bugs.climbers_on(cliff).duplicate():
			if not is_instance_valid(b) or not b.is_alive() or b.cliff_id != cliff or b.is_entombed():
				continue # amber on amber: the kiln's own splash never breaks its statues
			var d := b.global_position.distance_to(aim)
			if d > radius:
				continue
			b.receive_hit(base * (def.heavy_mult if TurretDef.is_heavy(b.def) else 1.0) * lerpf(1.0, 0.45, d / radius),
					aim, (b.global_position - aim).normalized(), true, 1.0, source, owner_cliff)
			if not b.is_alive():
				continue
			if b.boss != null:
				b.status.slow(AmberRules.BOSS_SET_SLOW, AmberRules.BOSS_SET_TIME)
			elif AmberRules.should_entomb(false, true, b.health.fraction()):
				if b.entomb(AmberRules.STATUE_TIME, source, owner_cliff):
					entombed += 1
		var me := self_ref.get_ref() as AmberTurret
		if me != null:
			me.stats["shots"] = int(me.stats.get("shots", 0)) + 1
			me.stats["entombed"] = int(me.stats.get("entombed", 0)) + entombed
			me._kiln_land.rpc(aim, normal, radius))


## Queen's Bell: tolls whenever something's in reach and the hammer's ready.
func _think_bell(delta: float) -> void:
	_cooldown -= delta
	_retarget -= delta
	if BossFx.holds_fire(self) or _cooldown > 0.0 or _retarget > 0.0:
		return
	_retarget = 0.25
	var caught := _bell_reach()
	if (caught[0] as Array).is_empty() and (caught[1] as Array).is_empty():
		return
	_cooldown = def.interval_at(tier) * Weather.turret_fire_interval(GameState.weather) * perk_rate * Economy.tonic_interval_mult(cliff_id)
	var centre := Vector3.ZERO
	for b: Bug in caught[0]:
		centre += b.global_position
	aim_point = centre / float((caught[0] as Array).size()) if not (caught[0] as Array).is_empty() else (caught[1][0] as Bug).global_position
	_idle_t = 0.0
	_toll(caught[0], caught[1])


## [climbers in range on the partner's wall, fliers in range] (statues left out).
func _bell_reach() -> Array:
	var climbers: Array[Bug] = []
	var fliers: Array[Bug] = []
	if bug_manager == null:
		return [climbers, fliers]
	var muzzle := _sight_point()
	var reach := def.range * range_multiplier() * weather_range()
	var pitch := pitch_limit()
	for b in bug_manager.climbers_on(covers):
		if b.is_alive() and not b.is_hidden() and not b.is_entombed() and Targeting.in_arc(muzzle, b.global_position, pitch, reach):
			climbers.append(b)
	for n: Node in bug_manager.get_children():
		var f := n as Bug
		if f != null and f.state == Bug.State.FLYING and f.is_alive() and f.global_position.distance_to(muzzle) <= reach:
			fliers.append(f)
	return [climbers, fliers]


func _toll(climbers: Array, fliers: Array) -> void:
	var source := _source()
	var jolt := def.damage_at(tier)
	var turned := 0
	var stunned := 0
	for b: Bug in climbers:
		if not is_instance_valid(b) or not b.is_alive():
			continue
		b.receive_hit(jolt, b.global_position, Vector3.DOWN, true, 1.0, source, cliff_id)
		if not b.is_alive():
			continue
		if b.boss != null:
			b.status.root(AmberRules.BOSS_STUN)
			stunned += 1
		elif b.frenzy(def.effect_size, source, cliff_id):
			turned += 1
	var dropped := 0
	for f: Bug in fliers:
		if not is_instance_valid(f) or not f.is_alive():
			continue
		if f.boss != null:
			f.status.root(AmberRules.BOSS_STUN)
			stunned += 1
		elif f.drop_from_sky(source, cliff_id):
			dropped += 1
	stats["tolls"] = int(stats.get("tolls", 0)) + 1
	stats["turned"] = int(stats.get("turned", 0)) + turned
	stats["dropped"] = int(stats.get("dropped", 0)) + dropped
	stats["stunned"] = int(stats.get("stunned", 0)) + stunned
	shots += 1


## Mandible Lance: heat, the beam's spot dragging onto its target, the damage and the trail.
func _think_lance(delta: float) -> void:
	_retarget -= delta
	var held := BossFx.holds_fire(self)
	var lost := _target != null and (not is_instance_valid(_target) or not _target.is_alive() or _target.untargetable())
	if _retarget <= 0.0 or lost:
		_retarget = RETARGET_TIME + randf() * 0.1
		_target = _pick_target()
	var want := _target != null and not held and not venting
	var spot := aim_point
	if want:
		var goal := _target.aim_for(global_position)
		spot = spot.move_toward(goal, AmberRules.LANCE_DRAG * delta * (3.0 if spot.distance_to(goal) > 30.0 else 1.0))
		aim_point = spot
		_idle_t = 0.0
	var firing := want and Targeting.in_arc(_sight_point(), spot, pitch_limit(), def.range * range_multiplier() * weather_range()) \
			and _aim_error_deg() < 12.0
	var h := AmberRules.lance_heat(heat, venting, firing, delta)
	heat = h[0]
	var was_venting := venting
	venting = h[1]
	if venting and not was_venting:
		stats["overheats"] = int(stats.get("overheats", 0)) + 1
	beam_on = firing and not venting
	if not beam_on:
		_trail_from = Vector3.INF
		return
	stats["beam_time"] = float(stats.get("beam_time", 0.0)) + delta
	# Damage in ticks of 0.1 s (cheap: one pass over the bugs ten times a second).
	_dmg_acc += delta
	if _dmg_acc >= 0.1:
		_beam_damage(spot, _dmg_acc)
		_dmg_acc = 0.0
	# The burning trail: a patch every few metres the spot drags, or every so often.
	_trail_t -= delta
	if _trail_from == Vector3.INF or _trail_from.distance_to(spot) >= AmberRules.TRAIL_STEP or _trail_t <= 0.0:
		_trail_from = spot
		_trail_t = AmberRules.TRAIL_TIME
		var dps := def.damage_at(tier) * AmberRules.TRAIL_SHARE
		bug_manager.add_fire(covers, spot, AmberRules.TRAIL_RADIUS, dps, AmberRules.TRAIL_SECONDS, _source(), cliff_id)
		stats["trail"] = int(stats.get("trail", 0)) + 1


func _beam_damage(spot: Vector3, secs: float) -> void:
	if bug_manager == null:
		return
	var muzzle := muzzle_position()
	var source := _source()
	var dps := def.damage_at(tier)
	var dir := (spot - muzzle).normalized()
	var hit := 0
	for n: Node in bug_manager.get_children():
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden() or b.untargetable(): # statues and fading mantises are let be
			continue
		var p := b.global_position
		var in_spot := p.distance_to(spot) <= AmberRules.LANCE_SPOT + b.crowd_r * 0.5
		var in_line := not in_spot and AmberRules.seg_dist(p, muzzle, spot) <= AmberRules.LANCE_LINE + b.crowd_r * 0.5
		if not in_spot and not in_line:
			continue
		b.receive_hit(dps * secs * (def.heavy_mult if TurretDef.is_heavy(b.def) else 1.0), p, dir, true, 1.0, source, cliff_id)
		hit += 1
	stats["beam_hits"] = int(stats.get("beam_hits", 0)) + hit


# ------------------------------------------------------------------ every peer: looks

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if def.special == TurretDef.SPECIAL_LANCE:
		_draw_beam(delta)


func _process(delta: float) -> void:
	# The glow breathes; the lance's glows hotter as it heats, and goes red venting.
	var t := Time.get_ticks_msec() * 0.001
	var e := 1.2 + 0.35 * sin(t * 2.3 + float(cell.y))
	if def.special == TurretDef.SPECIAL_LANCE:
		e += heat * 0.25
		_glow.light_color = AmberRules.GLOW.lerp(Color("#FF5A2A"), clampf(heat / AmberRules.LANCE_HOT, 0.0, 1.0))
		# The carriage runs along its rail toward the side it's shooting.
		var local := to_local(aim_point)
		_rail_x = move_toward(_rail_x, clampf(local.x * 0.04, -0.55, 0.55), delta * 0.8)
		_head.position.x = _rail_x
		if venting:
			_vent_t -= delta
			if _vent_t <= 0.0 and vfx != null:
				_vent_t = 0.35
				vfx.dust_burst(_head.global_position + Vector3.UP * 0.9, Vector3.UP, 0.7)
				Audio.play_at(&"water_blast", _head.global_position, -14.0, 0.6)
	_glow.light_energy = e


## The bell never turns: its hammer just strikes and draws back.
func _aim_visual(delta: float) -> void:
	if def.special != TurretDef.SPECIAL_BELL:
		super._aim_visual(delta)
		return
	_recoil = move_toward(_recoil, 0.0, delta * 2.5)
	_gun_mi.position.z = _recoil_len * _recoil * _recoil
	if tier != _shown_tier:
		_shown_tier = tier
		_show_tier()


func _draw_shot() -> void:
	match def.special:
		TurretDef.SPECIAL_BELL:
			_recoil = 1.0
			_idle_t = 0.0
			var bell_at := _head.global_position + Vector3.UP * 0.9
			AmberFx.toll_ring(get_tree().current_scene, bell_at, 9.0, Vector3.UP, 1.2)
			# A ring rolls over the partner's wall where the bugs are.
			var wall_up := WorldLayout.inward(covers) if covers >= 0 else Vector3.UP
			AmberFx.toll_ring(get_tree().current_scene, aim_point, def.range * 0.35, wall_up, 1.6)
			Audio.play_at(&"bell", bell_at, 6.0, 0.55)
			Audio.play_at(&"bell", aim_point, 4.0, 0.5)
			Audio.play_at(&"hammer_hit", bell_at, 2.0, 0.7)
			if vfx != null:
				vfx.dust_burst(bell_at + Vector3.UP * 0.6, Vector3.UP, 0.8)
		TurretDef.SPECIAL_KILN:
			_recoil = 1.0
			_idle_t = 0.0
			var from := _muzzle.global_position
			if vfx != null:
				vfx.lob(from, aim_point, def.flight_time, AmberRules.COLOR)
				vfx.muzzle_flash(from, -_gun.global_basis.z)
				vfx.spark(from, -_gun.global_basis.z, AmberRules.GLOW)
			Audio.play_at(&"mortar", from, 0.0, 0.8)
		_:
			pass


@rpc("authority", "call_local", "unreliable")
func _kiln_land(at: Vector3, normal: Vector3, radius: float) -> void:
	AmberFx.splat(vfx, at, normal, radius)
	Audio.play_at(&"water_blast", at, -2.0, 0.55)


func _draw_beam(delta: float) -> void:
	var on := beam_on
	_beam.visible = on
	_beam_core.visible = on
	if on != _was_beam:
		_was_beam = on
		if on:
			Audio.play_at(&"zippo_strike", _muzzle.global_position, 4.0, 0.5)
	if not on:
		_spot_light.light_energy = 0.0
		return
	var from := _muzzle.global_position
	var to := aim_point
	var length := maxf(from.distance_to(to), 0.1)
	var flicker := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.05)
	var basis := Basis.looking_at(to - from, Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.RIGHT)
	var xf := Transform3D(basis * Basis(Vector3.RIGHT, -PI * 0.5), from.lerp(to, 0.5))
	_beam.global_transform = xf.scaled_local(Vector3(0.32 * flicker, length, 0.32 * flicker))
	_beam_core.global_transform = xf.scaled_local(Vector3(0.11, length, 0.11))
	_spot_light.global_position = to - (to - from).normalized() * 1.2
	_spot_light.light_energy = 4.0 * flicker
	_spark_t -= delta
	if _spark_t <= 0.0 and vfx != null:
		_spark_t = 0.07
		var back := (from - to).normalized()
		vfx.spark(to + back * 0.3, (back + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.8), randf_range(-0.6, 0.6))).normalized(), AmberRules.GLOW)
		if randf() < 0.3:
			vfx.spark(from, -back, Color("#FFF4C8"))


func _beam_mesh(core: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = AmberFx.beam_material(core)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return mi


## Little amber embers rising off the turret: these are special.
static func _make_embers() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.amount = 14
	e.lifetime = 1.8
	e.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.55
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = AmberRules.GLOW
	e.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = Materials.star(AmberRules.GLOW, 2.2)
	e.draw_pass_1 = quad
	e.emitting = true
	return e


func interact_prompt() -> String:
	var text := super.interact_prompt()
	if def.special == TurretDef.SPECIAL_LANCE:
		text += "\nHeat %d%%%s" % [roundi(heat / AmberRules.LANCE_HOT * 100.0), "  -  VENTING" if venting else ""]
	text += "\nHive amber: the team fields only one %s." % def.display_name
	return text
