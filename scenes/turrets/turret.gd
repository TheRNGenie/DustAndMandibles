class_name Turret
extends StaticBody3D
## A turret on its owner's cliff edge. It only ever targets bugs climbing the
## cliff its grid spot covers (the OTHER cliff on the canyon; MapDef.covered_cliff,
## Targeting.cliff_allows), within its pitch limit and range, with a
## clear line of sight over the far lip. The host aims and rolls hits; clients get
## the aim point and a shot counter, and draw muzzle flashes and tracers themselves.

const RETARGET_TIME := 0.2
const ALIGN_TOLERANCE_DEG := 4.0

static var bug_manager: BugManager
static var vfx: VfxPool

var def: TurretDef
var cliff_id: int = 0
var cell: Vector2i
## The cliff whose climbers this turret shoots (from its grid column, see MapDef).
var covers: int = 1
## Straight across to the wall it covers (flat); its aiming cone is centred on it.
var _aim := Vector3.ZERO
var owner_name: String = ""
## Scaffold level this turret stands on (0 = ground): +5 degrees look-down and
## +5% range per level (TurretDef.RANGE_PER_LEVEL).
var level: int = 0
const LOOK_DOWN_PER_LEVEL := 5.0
## Casino prize: pays for one turret upgrade instead of chitin.
const UPGRADE_TOKEN := &"upgrade_token"
var radius: float = 0.9
var health: Health

# Replicated.
var aim_point: Vector3 = Vector3.ZERO
var shots: int = 0
## Upgrade tier 0-2 (bought with chitin): more damage, range, fire rate and HP.
var tier: int = 0
## False while the owner's stockpile can't pay this special turret's upkeep.
var has_ammo: bool = true
## Turret ammo: a crop-fed turret (TurretDef.crop_type) fires only while loaded.
## E with that crop's load in your stockpile loads it; the load is spent when the
## wave ends (host). Self-powered turrets ignore it.
var loaded: bool = false
# Perk: the builder's Engineer perks (Perks.apply_turret): range, fire interval, HP multipliers.
var perk_range := 1.0
var perk_rate := 1.0
var perk_hp := 1.0
## Perk: Overtime, share of max HP patched when a wave ends.
var perk_mend := 0.0

var _head: Node3D
var _gun: Node3D
var _muzzle: Node3D
var _target: Bug
var _retarget := 0.0
var _cooldown := 0.0
var _seen_shots := 0
var _gun_mi: MeshInstance3D
var _spin: MeshInstance3D
## Tiers: a second barrel cluster (Twin Gatling) and a second muzzle that shots alternate with.
var _spin_b: MeshInstance3D
var _muzzle_b: Node3D
var _spin_speed := 0.0
var _recoil := 0.0
var _recoil_len := 0.06
var _stars: Node3D
var _brass: MeshInstance3D
var _empty_sign: Label3D
var _shown_tier := -1
var _shown_ammo := true
var _idle_t := 0.0
## Last aim point seen: a moving aim point means there's a target (clients too).
var _last_aim := Vector3.ZERO


func setup(d: TurretDef, cid: int, c: Vector2i, pos: Vector3, owner_label: String, stack_level: int = 0) -> void:
	def = d
	cliff_id = cid
	cell = c
	covers = WorldLayout.map().covered_cliff(cid, maxi(c.y, 0))
	level = stack_level
	owner_name = owner_label
	position = pos
	rotation.y = WorldLayout.facing_canyon_yaw(cid)
	var m := WorldLayout.map()
	if not m.is_canyon() and covers >= 0 and c.x >= 0:
		# Bigger maps: rest facing the cliff this spot covers.
		var to := m.cliff(covers).origin - pos
		rotation.y = atan2(-to.x, -to.z)
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var parts := TurretBuilder.build(d.id, Palette.team_color(cid))
	_textured = bool(parts.get("textured", false)) # fal models keep their own textures (RiggedTurret)
	_fixed_yaw = bool(parts.get("fixed_yaw", false))
	var base := MeshInstance3D.new()
	base.mesh = parts["base"]
	_paint(base, 0.025)
	add_child(base)
	_head = Node3D.new()
	_head.position.y = float(parts["head_y"])
	add_child(_head)
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = parts["head"]
	_paint(head_mi, 0.02)
	_head.add_child(head_mi)
	_gun = Node3D.new()
	_gun.position.y = float(parts["gun_y"])
	_head.add_child(_gun)
	_gun_mi = MeshInstance3D.new()
	_gun_mi.mesh = parts["gun"]
	_paint(_gun_mi, 0.015)
	_gun.add_child(_gun_mi)
	_recoil_len = float(parts.get("recoil", 0.06))
	if parts.has("spin"):
		_spin = MeshInstance3D.new()
		_spin.mesh = parts["spin"]
		_paint(_spin, 0.012)
		_spin.position = parts["spin_at"]
		if parts.has("spin_basis"):
			_spin.basis = parts["spin_basis"]
		_gun_mi.add_child(_spin)
	if parts.has("spin_b"): # Tiers: twin barrel clusters spin about their own axes
		_spin_b = MeshInstance3D.new()
		_spin_b.mesh = parts["spin_b"]
		_paint(_spin_b, 0.012)
		_spin_b.position = parts["spin_b_at"]
		if parts.has("spin_b_basis"):
			_spin_b.basis = parts["spin_b_basis"]
		_gun_mi.add_child(_spin_b)
	# Brass stars on the head show the upgrade tier.
	_stars = Node3D.new()
	_stars.position = Vector3(0, 0.05, 0.28)
	_head.add_child(_stars)
	_muzzle = Node3D.new()
	_muzzle.position = parts["muzzle"]
	_gun.add_child(_muzzle)
	if parts.has("muzzle_b"): # Tiers: twin barrels fire in turn
		_muzzle_b = Node3D.new()
		_muzzle_b.position = parts["muzzle_b"]
		_gun.add_child(_muzzle_b)
	if d.has_upkeep() or d.is_crop_fed():
		_empty_sign = _make_empty_sign(float(parts["head_y"]) + 1.3)
		add_child(_empty_sign)
	if d.is_crop_fed():
		_pip = _make_pip(float(parts["head_y"]) + 1.05)
		add_child(_pip)
		_in_wave = GameState.phase == GameState.Phase.WAVE
		GameState.phase_changed.connect(_on_phase_changed)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.8
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	health = Health.new()
	health.name = "Health"
	health.setup(d.max_hp)
	add_child(health)
	health.died.connect(_on_destroyed)
	add_child(_make_synchronizer())
	add_to_group("turrets")
	add_to_group("structures")
	aim_point = pos + WorldLayout.inward(cid) * 20.0


func _make_synchronizer() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:aim_point", ".:shots", ".:tier", ".:has_ammo", ".:loaded", "Health:hp"]:
		var path := NodePath(p)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 0.1
	return sync


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		var t0 := Time.get_ticks_usec()
		_think(delta)
		if CpuProf.on:
			CpuProf.add(&"turrets", Time.get_ticks_usec() - t0)
	_aim_visual(delta)
	_show_jam(delta)
	if shots != _seen_shots:
		_seen_shots = shots
		_draw_shot()


## Every peer: a flickering "JAMMED" over the gun while a latch bug clamps under it.
var _jam_tag: Label3D
var _jam_t := 0.0


func _show_jam(delta: float) -> void:
	_jam_t -= delta
	if _jam_t > 0.0 and _jam_tag == null:
		return
	if _jam_t <= 0.0:
		_jam_t = 0.4
		var jammed := LatchDirector.jam_mult(cliff_id, global_position) > 1.0
		if jammed and _jam_tag == null:
			_jam_tag = Label3D.new()
			_jam_tag.text = "JAMMED"
			_jam_tag.font_size = 44
			_jam_tag.pixel_size = 0.006
			_jam_tag.outline_size = 12
			_jam_tag.modulate = Color(1.0, 0.55, 0.2)
			_jam_tag.outline_modulate = Palette.OUTLINE
			_jam_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_jam_tag.position = Vector3.UP * 2.6
			add_child(_jam_tag)
		elif not jammed and _jam_tag != null:
			_jam_tag.queue_free()
			_jam_tag = null
	if _jam_tag != null:
		_jam_tag.visible = fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.35


func _think(delta: float) -> void:
	_cooldown -= delta
	_retarget -= delta
	# Boss: webbed (Queen Spider) or stunned (Thunder Cicada) turrets hold fire.
	if BossFx.holds_fire(self):
		return
	# Turret ammo: an unloaded crop-fed turret rests, barrel skyward.
	if not can_fire():
		_target = null
		return
	# Re-pick on a timer (not every tick when there's nothing to shoot), or at once
	# when the current target dies or leaves the arc.
	var lost := _target != null and (not is_instance_valid(_target) or not _target.is_alive() or _target.untargetable()) # Boss: Mirage Mantis fading
	if _retarget <= 0.0 or lost:
		_retarget = RETARGET_TIME + randf() * 0.1
		_target = _pick_target()
	if _target == null:
		# Restocked while idle: clear the empty sign without waiting for a shot.
		if not has_ammo and Economy.can_afford(cliff_id, def.ammo_cost):
			has_ammo = true
		return
	aim_point = _target.aim_for(global_position) # Boss: a boss may offer parts to aim at (Stilt Strider legs)
	_idle_t = 0.0 # tracking a target: never drift into the idle sweep
	if _cooldown > 0.0 or _aim_error_deg() > ALIGN_TOLERANCE_DEG:
		return
	# Special turrets pay their upkeep per shot (chili, scrap); basic ones never do.
	if def.has_upkeep():
		has_ammo = Economy.spend(cliff_id, def.ammo_cost)
		if not has_ammo:
			_cooldown = 1.0
			return
	_cooldown = def.interval_at(tier) * Weather.turret_fire_interval(GameState.weather) * perk_rate * Economy.tonic_interval_mult(cliff_id) 			* LatchDirector.jam_mult(cliff_id, global_position) # a latch bug clamped under it # Perk: Well Oiled; Sarsaparilla tonic from the partner
	shots += 1
	if randf() <= def.hit_chance * weather_hit(_target):
		var dmg := def.damage_at(tier, TurretDef.is_heavy(_target.def))
		if def.anti_air and _target.state != Bug.State.FLYING:
			dmg *= def.ground_mult # (an anti-air gun turned on a climber)
		TurretEffects.apply(self, _target, aim_point, dmg)



func _pick_target() -> Bug:
	if bug_manager == null:
		return null
	# Every rule but line of sight first (cheap), then rays only for the best
	# few in score order: the same pick as testing every bug, without a ray per
	# bug in range.
	var muzzle := _sight_point()
	var seen := weather_range()
	var pitch := pitch_limit()
	var max_range := def.range * range_multiplier()
	var cands: Array[Bug] = []
	var scores: Array[float] = []
	if def.guards_plateau or def.anti_air:
		# Only bugs that can pass the rules: those over a lip or flying, plus the
		# climbers an anti-air gun may turn on (ground_mult).
		var pool: Array[Bug] = bug_manager.topside_bugs()
		if def.anti_air and def.ground_mult > 0.0:
			pool = pool.duplicate()
			for c in WorldLayout.cliff_count():
				if Targeting.cliff_allows(cliff_id, c, true, covers):
					pool.append_array(bug_manager.climbers_on(c))
		for g in pool:
			if not _valid_cheap(g, muzzle, seen, pitch, max_range):
				continue
			cands.append(g)
			# (Anti-air that also takes climbers: any flier before any climber.)
			var flier_first := 1000.0 if def.anti_air and g.state == Bug.State.FLYING else 0.0
			scores.append(Targeting.marked_priority(-g.global_position.distance_to(global_position) + flier_first, g.status.is_marked())) # Signal Flare
	else:
		for b in bug_manager.climbers_on(covers):
			if not _valid_cheap(b, muzzle, seen, pitch, max_range):
				continue
			cands.append(b)
			scores.append(Targeting.marked_priority(Targeting.priority(b.climb_y, b.global_position.distance_to(global_position)), b.status.is_marked())) # Signal Flare
		# Canyon Expeditions: bugs out on the floor hunting a partner who's down.
		for b: Bug in Bug.floor_bugs:
			if not is_instance_valid(b) or not _valid_cheap(b, muzzle, seen, pitch, max_range):
				continue
			cands.append(b)
			scores.append(Targeting.floor_priority(b.global_position.distance_to(global_position)))
	while not cands.is_empty():
		# The first best score (as a plain scan would keep it).
		var top := 0
		for i in range(1, scores.size()):
			if scores[i] > scores[top]:
				top = i
		if _clear_shot(cands[top], muzzle):
			return cands[top]
		cands.remove_at(top)
		scores.remove_at(top)
	return null


## The cross-defense rule plus pitch limit, range and line of sight.
func _valid(b: Bug) -> bool:
	var muzzle := _sight_point() # Crewed: crewed guns look from the gun, not their low turntable
	return _valid_cheap(b, muzzle, weather_range(), pitch_limit(), def.range * range_multiplier()) and _clear_shot(b, muzzle)


## _valid() without the line-of-sight ray (`seen`: weather_range(), `max_range`
## before the weather: def.range * range_multiplier()).
func _valid_cheap(b: Bug, muzzle: Vector3, seen: float, pitch: float, max_range: float) -> bool:
	if not b.is_alive() or b.is_hidden() or b.untargetable(): # Boss: untargetable = Mirage Mantis fading
		return false
	if def.anti_air:
		if b.state != Bug.State.FLYING and not (def.ground_mult > 0.0 and b.is_climbing() and Targeting.cliff_allows(cliff_id, b.cliff_id, true, covers)):
			return false
	elif def.guards_plateau:
		# Last resorts wake only for bugs that made it over YOUR lip (or fly overhead).
		var on_plateau := b.state == Bug.State.BREACHING or b.state == Bug.State.CRESTING or b.state == Bug.State.FLYING
		if not Targeting.guard_allows(cliff_id, b.cliff_id, on_plateau):
			return false
		if def.guards_house and not def.yard_wide: # Tiers: the Gatling Porch Turret sweeps the whole yard
			var home := Homestead.of(cliff_id)
			if home == null or b.global_position.distance_to(home.global_position) > Homestead.GUARD_RADIUS:
				return false
	elif not Targeting.cliff_allows(cliff_id, b.cliff_id, b.is_climbing(), covers) 			and not Targeting.floor_allows(b.floor_bug, b.state == Bug.State.CROSSING or b.state == Bug.State.BURROWED): # Canyon Expeditions
		return false
	# The arc first (cheap); the lantern scan only for a bug the murk hides.
	var aim := Vector3.ZERO
	var half := 180.0
	if not (def.anti_air or def.guards_plateau):
		if _aim == Vector3.ZERO:
			_aim = Targeting.wall_aim(Bug.cliffs, covers, muzzle)
		aim = _aim
		half = def.aim_half_deg() # universal turrets: 15, 30 or 45 degree cones
	if Targeting.in_arc(muzzle, b.global_position, pitch, max_range * seen, aim, half):
		return true
	# A lantern or a lit lighter shows this bug through the murk.
	return seen < 1.0 and Targeting.in_arc(muzzle, b.global_position, pitch, max_range, aim, half) and _lit_near(b.global_position)


## Line of sight from the muzzle to the bug (rock and buildings block it).
func _clear_shot(b: Bug, muzzle: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(muzzle, b.global_position, WorldLayout.LAYER_WORLD)
	if def.guards_house:
		# House turrets sit on the porch, balcony and roof deck: their own house's
		# walls and roof never block them.
		var home := Homestead.of(cliff_id)
		if home != null:
			q.exclude = [home.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# Crewed: where range, arc and line of sight are measured from (CrewedTurret overrides).
func _sight_point() -> Vector3:
	return _head.global_position


## Look-down limit in degrees: the turret's own, plus 5 per scaffold level.
func pitch_limit() -> float:
	return def.pitch_limit_deg + look_down_bonus(level)


## Scaffold look-down: +5 deg per storey above the first. The bottom deck
## (level 1) keeps the plain 30 deg, like the ground (Logan).
static func look_down_bonus(lvl: int) -> float:
	return LOOK_DOWN_PER_LEVEL * maxi(lvl - 1, 0)


## The weather's say in whether a shot at `b` lands (Weather.turret_accuracy:
## fog and dust miss more the farther the bug, less near a lantern post).
func weather_hit(b: Node3D) -> float:
	var w := GameState.weather
	if Weather.murk_miss(w) <= 0.0 or b == null or not is_instance_valid(b):
		return Weather.turret_accuracy(w)
	var reach := maxf(def.range * range_multiplier(), 1.0)
	var lit := false
	for l: Array in _lights():
		if (l[0] as Vector3).distance_to(global_position) < Weather.LANTERN_FOG_RADIUS:
			lit = true
			break
	return Weather.turret_accuracy(w, muzzle_position().distance_to(b.global_position) / reach, lit)


## How far the weather lets this turret see (always full now: Weather.turret_range).
func weather_range() -> float:
	var w := GameState.weather
	if w != Weather.Kind.FOG and w != Weather.Kind.DUST_STORM:
		return Weather.turret_range(w)
	for l: Array in _lights():
		if (l[0] as Vector3).distance_to(global_position) < Weather.LANTERN_FOG_RADIUS:
			return Weather.turret_range(w, true)
	return Weather.turret_range(w)


## Is `pos` lit by a lantern post or someone's lit Zippo?
func _lit_near(pos: Vector3) -> bool:
	for l: Array in _lights():
		if (l[0] as Vector3).distance_to(pos) < float(l[1]):
			return true
	return false


## Every lantern and lit lighter as [position, reveal radius], gathered once a
## tick for all the turrets.
static var _lights_list: Array = []
static var _lights_tick := -1
static var _lights_frame := -1


func _lights() -> Array:
	var pf := Engine.get_physics_frames()
	var f := Engine.get_process_frames()
	if pf != _lights_tick or f != _lights_frame:
		_lights_tick = pf
		_lights_frame = f
		_lights_list.clear()
		for l: Node in get_tree().get_nodes_in_group("lanterns"):
			var n := l as Node3D
			_lights_list.append([n.global_position, float(n.call("reveal_radius"))])
	return _lights_list


## Range from the upgrade tier and the scaffold level it stands on.
func range_multiplier() -> float:
	return TurretDef.range_mult(tier, level) * perk_range * (Homestead.LOOKOUT_RANGE if Homestead.lookout_cliffs.has(cliff_id) else 1.0) # Perk: Long Sights; house lookout floor


func muzzle_position() -> Vector3:
	return _muzzle.global_position


## Chitin for the next tier, or -1 when fully upgraded.
func upgrade_cost() -> int:
	return Defs.UPGRADE_COSTS[tier] if tier < mini(Defs.UPGRADE_COSTS.size(), TurretDef.MAX_TIER) else -1


## Host: buy the next tier: more HP too, keeping the damage already taken.
func upgrade() -> void:
	if multiplayer.is_server() and upgrade_cost() > 0:
		var lost := health.max_hp - health.hp
		tier += 1
		health.setup(def.hp_at(tier) * perk_hp) # Perk: Reinforced Frames
		health.hp = maxf(health.max_hp - lost, 1.0)


func _aim_error_deg() -> float:
	var want := (aim_point - _gun.global_position).normalized()
	var have := -_gun.global_basis.z.normalized()
	return rad_to_deg(want.angle_to(have))


## Turns head (yaw) and gun (pitch) toward aim_point at the turret's turn speed.
func _aim_visual(delta: float) -> void:
	var local := to_local(aim_point) - _head.position
	var yaw := atan2(-local.x, -local.z)
	var horizontal := Vector2(local.x, local.z).length()
	var pitch := clampf(atan2(local.y, horizontal), -deg_to_rad(pitch_limit()), deg_to_rad(80.0 if def.anti_air else 40.0))
	var step := deg_to_rad(def.turn_speed) * delta
	# Nothing to shoot for a while: scan the far cliff in slow sweeps.
	# Idle only when nothing is being tracked: the host knows its target, clients
	# see the synced aim point move.
	if aim_point.distance_squared_to(_last_aim) > 0.0001 or (_target != null and is_instance_valid(_target)):
		_idle_t = 0.0
	_last_aim = aim_point
	_idle_t += delta
	if _idle_t > 3.0 and def.guards_plateau:
		# Last resorts stand down, barrel raised, until bugs reach your plateau.
		yaw = 0.0
		pitch = deg_to_rad(35.0)
		step *= 0.25
	elif _idle_t > 3.0:
		yaw = sin((_idle_t + float(cell.y)) * 0.45) * 0.95
		pitch = (0.65 if def.anti_air else -0.08) + sin((_idle_t + float(cell.y)) * 0.3) * 0.06
		step *= 0.25
	if def.is_crop_fed() and _crop_visual(delta):
		pass # resting skyward or lowering on a load: the barrel is busy
	else:
		_head.rotation.y = 0.0 if _fixed_yaw else rotate_toward(_head.rotation.y, yaw, step)
		_gun.rotation.x = rotate_toward(_gun.rotation.x, pitch, step)
	# Recoil kick, spinning barrels winding down, tier stars.
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	_gun_mi.position.z = _recoil_len * _recoil * _recoil
	_spin_speed = move_toward(_spin_speed, 0.0, delta * 12.0)
	if _spin != null:
		_spin.rotate_object_local(Vector3.BACK, _spin_speed * delta)
	if _spin_b != null:
		_spin_b.rotate_object_local(Vector3.BACK, -_spin_speed * delta)
	if tier != _shown_tier:
		_shown_tier = tier
		_show_tier()
	if _empty_sign != null and not def.is_crop_fed() and has_ammo != _shown_ammo:
		_shown_ammo = has_ammo
		_empty_sign.visible = not has_ammo


func _draw_shot() -> void:
	_recoil = 1.0
	_spin_speed = 28.0
	_idle_t = 0.0
	var from := _muzzle.global_position
	if _muzzle_b != null and shots % 2 == 1:
		from = _muzzle_b.global_position
	var spread := deg_to_rad(def.spread_deg) * (1.0 + 2.0 * Weather.murk_miss(GameState.weather)) # (fog and dust: wilder tracers)
	var to := aim_point + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * from.distance_to(aim_point) * spread
	if def.special != &"":
		# Steam cone, flood, twin shells, bolas (scenes/vfx/special_shot_fx.gd).
		if vfx != null:
			SpecialShotFx.draw(self, vfx)
		Audio.play_at(def.sound if Audio.has_sound(def.sound) else &"cannon", from)
		return
	if vfx != null:
		if def.flight_time > 0.0:
			vfx.lob(from, to, def.flight_time, TurretEffects.shot_color(def))
		else:
			vfx.tracer(from, to, TurretEffects.shot_color(def), 0.12 if def.effect == TurretDef.Effect.KNOCKBACK else 0.05)
		vfx.muzzle_flash(from, -_gun.global_basis.z)
	var sound := def.sound
	if sound == &"gatling" or not Audio.has_sound(sound):
		sound = StringName("gatling_%d" % (randi() % 3 + 1))
	Audio.play_at(sound, from, -4.0 if def.id == &"gatling_post" else 0.0)


## Tiers: every peer draws a special shot's extra path: a ricochet zig-zagging
## from bug to bug, a round punching on through, or a rail spike driven down the
## wall (left sticking out of the last bug for `pin` seconds).
@rpc("authority", "call_local", "unreliable")
func special_fx(kind: StringName, pts: PackedVector3Array, pin: float) -> void:
	if vfx == null or pts.size() < 2:
		return
	match kind:
		TurretDef.SPECIAL_CHAIN:
			for i in pts.size() - 1:
				vfx.tracer(pts[i], pts[i + 1], Color("#FFB23F"), 0.06)
				vfx.spark(pts[i + 1], (pts[i] - pts[i + 1]).normalized(), Color("#FFB23F"))
		TurretDef.SPECIAL_PIERCE:
			vfx.tracer(pts[0], pts[1], Palette.GLOW_YELLOW, 0.09)
			vfx.spark(pts[1], (pts[0] - pts[1]).normalized())
		TurretDef.SPECIAL_SPIKE:
			vfx.tracer(pts[0], pts[1], Color("#C9CED6"), 0.16)
			vfx.spark(pts[1], (pts[0] - pts[1]).normalized(), Color("#FFE2A0"))
			var along := (pts[1] - pts[0]).normalized() if pts[0].distance_to(pts[1]) > 0.1 else -_gun.global_basis.z
			_leave_spike(pts[1], along, pin)


## A railroad spike stuck in the rock where the last skewered bug is pinned.
func _leave_spike(at: Vector3, along: Vector3, seconds: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = TierBuilder.loose_spike()
	mi.material_override = Materials.toon(0.01)
	get_tree().current_scene.add_child(mi)
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(along, up), at - along * 0.4)
	get_tree().create_timer(maxf(seconds, 0.6) + 0.6).timeout.connect(mi.queue_free)


## Host: damage from spitter acid or breachers.
func structure_damage(amount: float, source: String) -> void:
	if multiplayer.is_server():
		health.take_damage(amount, source)


## Host: repairing heals HP.
func repair(amount: float) -> void:
	if multiplayer.is_server():
		health.heal(amount)


func needs_repair() -> bool:
	return health.hp < health.max_hp - 0.5


func interact_prompt() -> String:
	var text := "%s  %d/%d HP" % [def.display_name, int(health.hp), int(health.max_hp)]
	text += TurretTallies.prompt_suffix(self) # kill tally (scenes/ui/turret_tallies.gd)
	if tier > 0:
		text += "  - %s" % TurretDef.TIER_NAMES[tier]
	if level > 1: # (the bottom deck: no scaffold bonus to show)
		text += "\nScaffold level %d: +%d deg look-down, +%d%% range" % [level, int(look_down_bonus(level)),
				roundi(TurretDef.RANGE_PER_LEVEL * 100.0 * maxi(level - 1, 0))]
	if def.guards_plateau and (not def.guards_house or def.yard_wide):
		text += "\nStands by until bugs reach your plateau"
	if def.has_upkeep():
		text += ("\nUpkeep: %s a shot" if has_ammo else "\nEMPTY: needs %s a shot") % def.upkeep_text()
	text += _load_prompt()
	if needs_repair():
		text += "\nHold E: repair (1 %s per %d HP)" % [ResNames.team(), int(BuildManager.REPAIR_HP_PER_SCRAP)]
	if upgrade_cost() > 0:
		var payer := Economy.payer_cliff(multiplayer.get_unique_id(), cliff_id)
		var price := "1 upgrade token" if Economy.amount(payer, UPGRADE_TOKEN) > 0 else UiStyle.cost(Perks.discount(multiplayer.get_unique_id(), &"chitin_smith", upgrade_cost()), ResNames.PERSONAL_ID) # Perk: Chitin Smith (shown as Scrap Smith)
		text += "\nU: upgrade to %s (%s)" % [TurretDef.TIER_NAMES[tier + 1], price]
	var next := Defs.tier_up_of(def.id)
	if next != &"" and not (self is CrewedTurret):
		if Defs.is_unlocked(next, GameState.tier_wave()):
			text += "\n%s: step up to %s (%s)" % [KeyHints.key_for("tier_up"), Defs.name_of(next), UiStyle.cost(Defs.tier_up_cost(def.id), ResNames.TEAM_ID)]
		else:
			text += "\nSteps up to %s at wave %d" % [Defs.name_of(next), Defs.unlock_wave(next)]
	return text


func local_interact(holding: bool) -> void:
	if not holding and wants_load() and _load_count() > 0:
		BuildManager.instance.load_node(self)
		return
	if needs_repair():
		BuildManager.instance.repair_node(self)


## Turret ammo: loads of this turret's crop in the local player's stockpile.
func _load_count() -> int:
	var item := def.load_item()
	if item == &"":
		return 0
	return Economy.amount(Economy.payer_cliff(multiplayer.get_unique_id(), cliff_id), item)


## "E: load (Corn)" / "Loaded" / "EMPTY: needs a corn load" for the prompt.
func _load_prompt() -> String:
	if not def.is_crop_fed():
		return ""
	var crop := def.crop_name()
	if loaded:
		return "\nLoaded with %s: fires until the wave ends" % crop.to_lower()
	var have := _load_count()
	if have > 0:
		return "\nE: load (%s)  - %d load%s in stock" % [crop, have, "" if have == 1 else "s"]
	return "\nEMPTY: needs a %s load. Harvest %s to get some." % [crop.to_lower(), crop.to_lower()]


func _on_destroyed(_source: String, _source_cliff: int) -> void:
	if multiplayer.is_server():
		BuildManager.instance.on_structure_destroyed(self)


## Upgrade looks: a brass star per tier on the head, a brass collar on the gun at
## tier 1, and a bigger barrel with a second collar at tier 2.
func _show_tier() -> void:
	for c in _stars.get_children():
		c.queue_free()
	if _brass != null:
		_brass.queue_free()
		_brass = null
	_gun_mi.scale = Vector3.ONE * (1.15 if tier >= 2 else 1.0)
	health.max_hp = def.hp_at(tier) * perk_hp # max_hp isn't replicated; tier is (Perk: Reinforced Frames)
	if tier <= 0:
		return
	var st := MeshKit.begin()
	for i in tier:
		var c := Vector3((float(i) - (tier - 1) * 0.5) * 0.11, 0.0, 0.0)
		for k in 2:
			MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.BACK, k * PI / 3.0) * Basis(Vector3.RIGHT, PI * 0.5), c), 0.045, 0.045, 0.02, 3, Color("#E8C55A"), true, 0.3)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.006)
	_stars.add_child(mi)
	# Collars ring the gun along its length (the barrel points down -Z).
	var box := _gun_mi.mesh.get_aabb()
	var r := maxf(box.size.x, box.size.y) * 0.5 + 0.03
	var centre := Vector3(box.get_center().x, box.get_center().y, 0.0)
	var bst := MeshKit.begin()
	var spots: Array = [0.35] if tier == 1 else [0.35, 0.75]
	for f: float in spots:
		var z := box.position.z + box.size.z * (1.0 - f)
		MeshKit.add_cylinder(bst, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), centre + Vector3(0, 0, z)), r, r, 0.07, 10, Color("#E8C55A"), true, 0.25)
	_brass = MeshInstance3D.new()
	_brass.mesh = MeshKit.finish(bst)
	_brass.material_override = Materials.toon(0.01)
	_gun_mi.add_child(_brass)


# ------------------------------------------------------------------ turret ammo

## Barrel tilt while a crop-fed turret waits for a load (up, in radians).
const REST_PITCH := PI / 4.0
## Idle sway either side of REST_PITCH, and its period.
const REST_SWAY := 2.0 * PI / 180.0
const REST_SWAY_PERIOD := 4.0
## Loading: the barrel lowers over this long (ease-in-out), thunk at the midpoint.
const LOAD_TIME := 0.4
## The EMPTY sign fades in over this long once the barrel is up.
const SIGN_FADE := 0.3

var _pip: MeshInstance3D
var _in_wave := false
var _shown_loaded := false
var _load_t := 0.0
var _load_from := 0.0
var _thunked := false
var _sign_a := 0.0


var _textured := false
var _fixed_yaw := false


## Toon material on code-built parts; the fal models keep their textures.
func _paint(mi: MeshInstance3D, outline: float) -> void:
	if not _textured:
		mi.material_override = Materials.toon(outline)


## Fires this wave: self-powered always, crop-fed only once loaded.
func can_fire() -> bool:
	return loaded or not def.is_crop_fed()


## Crop-fed and waiting for its crop.
func wants_load() -> bool:
	return def.is_crop_fed() and not loaded


## Host: arm a crop-fed turret for the rest of this wave (or the next one).
func load_turret() -> void:
	if multiplayer.is_server() and wants_load():
		loaded = true


## Host: a wave ending spends every crop-fed turret's load.
func _on_phase_changed(p: GameState.Phase) -> void:
	var was := _in_wave
	_in_wave = p == GameState.Phase.WAVE
	if was and not _in_wave and multiplayer.is_server():
		loaded = false


## Every peer: a crop-fed turret's barrel. Unloaded it rests 45 degrees skyward with
## a slow sway and the EMPTY sign fades in; loading lowers it to level with a thunk,
## a puff of the crop's colour at the muzzle and the green ammo pip. True while it
## holds the barrel (aiming waits).
func _crop_visual(delta: float) -> bool:
	if loaded != _shown_loaded:
		_shown_loaded = loaded
		if loaded:
			_load_t = LOAD_TIME
			_load_from = _gun.rotation.x
			_thunked = false
	_pip.visible = loaded and _load_t <= 0.0
	if loaded and _load_t > 0.0:
		_load_t = maxf(_load_t - delta, 0.0)
		var k := 1.0 - _load_t / LOAD_TIME
		_gun.rotation.x = lerpf(_load_from, 0.0, k * k * (3.0 - 2.0 * k))
		if not _thunked and k >= 0.5:
			_thunked = true
			Audio.play_at(&"crank_gatling_close", global_position)
		if _load_t <= 0.0 and vfx != null:
			var c := Defs.crop(def.crop_type)
			vfx.spark(_muzzle.global_position, -_gun.global_basis.z, c.color if c != null else Palette.GLOW_YELLOW)
		_set_sign(0.0)
		return true
	if loaded:
		_set_sign(0.0)
		return false
	var want := REST_PITCH + sin(Time.get_ticks_msec() / 1000.0 * TAU / REST_SWAY_PERIOD) * REST_SWAY
	_gun.rotation.x = lerp_angle(_gun.rotation.x, want, 1.0 - exp(-delta * 7.0)) # ease-out, about half a second
	var up := absf(_gun.rotation.x - want) < 0.05
	_set_sign(move_toward(_sign_a, 1.0 if up else 0.0, delta / SIGN_FADE))
	return true


func _set_sign(a: float) -> void:
	_sign_a = a
	if _empty_sign != null:
		_empty_sign.visible = a > 0.01
		_empty_sign.modulate.a = a
		_empty_sign.outline_modulate.a = a


## The green ammo pip over a loaded crop-fed turret.
func _make_pip(y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	sphere.radial_segments = 10
	sphere.rings = 5
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#5FE36A")
	mi.material_override = mat
	mi.position = Vector3(0, y, 0)
	mi.visible = false
	return mi


## A red "EMPTY" sign over a special turret that has run out of upkeep.
func _make_empty_sign(y: float) -> Label3D:
	var l := Label3D.new()
	l.text = "EMPTY"
	l.font_size = 64
	l.outline_size = 14
	l.modulate = Color("#E2483C")
	l.outline_modulate = Palette.OUTLINE
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, y, 0)
	l.visible = false
	return l
