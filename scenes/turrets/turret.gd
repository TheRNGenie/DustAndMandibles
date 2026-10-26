class_name Turret
extends StaticBody3D
## A turret on its owner's cliff edge. It only ever targets bugs climbing the
## OTHER cliff (Targeting.cliff_allows), within its pitch limit and range, with a
## clear line of sight over the far lip. The host aims and rolls hits; clients get
## the aim point and a shot counter, and draw muzzle flashes and tracers themselves.

const RETARGET_TIME := 0.2
const ALIGN_TOLERANCE_DEG := 4.0

static var bug_manager: BugManager
static var vfx: VfxPool

var def: TurretDef
var cliff_id: int = 0
var cell: Vector2i
var owner_name: String = ""
## Scaffold level this turret stands on (0 = ground): +5 degrees look-down per level.
var level: int = 0
const LOOK_DOWN_PER_LEVEL := 5.0
var radius: float = 0.9
var health: Health

# Replicated.
var aim_point: Vector3 = Vector3.ZERO
var shots: int = 0
## Upgrade tier 0-3 (bought with chitin): more damage, range and fire rate.
var tier: int = 0
## False while the owner's stockpile can't pay this turret's ammo (water, chili).
var has_ammo: bool = true

var _head: Node3D
var _gun: Node3D
var _muzzle: Node3D
var _target: Bug
var _retarget := 0.0
var _cooldown := 0.0
var _seen_shots := 0


func setup(d: TurretDef, cid: int, c: Vector2i, pos: Vector3, owner_label: String, stack_level: int = 0) -> void:
	def = d
	cliff_id = cid
	cell = c
	level = stack_level
	owner_name = owner_label
	position = pos
	rotation.y = WorldLayout.facing_canyon_yaw(cid)
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var parts := TurretBuilder.build(d.id, Palette.team_color(cid))
	var base := MeshInstance3D.new()
	base.mesh = parts["base"]
	base.material_override = Materials.toon(0.025)
	add_child(base)
	_head = Node3D.new()
	_head.position.y = float(parts["head_y"])
	add_child(_head)
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = parts["head"]
	head_mi.material_override = Materials.toon(0.02)
	_head.add_child(head_mi)
	_gun = Node3D.new()
	_gun.position.y = float(parts["gun_y"])
	_head.add_child(_gun)
	var gun_mi := MeshInstance3D.new()
	gun_mi.mesh = parts["gun"]
	gun_mi.material_override = Materials.toon(0.015)
	_gun.add_child(gun_mi)
	_muzzle = Node3D.new()
	_muzzle.position = parts["muzzle"]
	_gun.add_child(_muzzle)
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
	aim_point = pos + Vector3(-WorldLayout.side_sign(cid) * 20.0, 0.0, 0.0)


func _make_synchronizer() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:aim_point", ".:shots", ".:tier", ".:has_ammo", "Health:hp"]:
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
		_think(delta)
	_aim_visual(delta)
	if shots != _seen_shots:
		_seen_shots = shots
		_draw_shot()


func _think(delta: float) -> void:
	_cooldown -= delta
	_retarget -= delta
	if _retarget <= 0.0 or _target == null or not is_instance_valid(_target) or not _valid(_target):
		_retarget = RETARGET_TIME
		_target = _pick_target()
	if _target == null:
		return
	aim_point = _target.global_position
	if _cooldown > 0.0 or _aim_error_deg() > ALIGN_TOLERANCE_DEG:
		return
	# Water Cannons and Chili Mortars burn your farm's output as ammo.
	if not def.ammo_cost.is_empty():
		has_ammo = Economy.spend(cliff_id, def.ammo_cost)
		if not has_ammo:
			_cooldown = 1.0
			return
	_cooldown = def.fire_interval * (1.0 - 0.08 * tier) * Weather.turret_fire_interval(GameState.weather)
	shots += 1
	if randf() <= def.hit_chance * Weather.turret_accuracy(GameState.weather):
		TurretEffects.apply(self, _target, aim_point, def.damage * (1.0 + 0.25 * tier))


func _pick_target() -> Bug:
	if bug_manager == null:
		return null
	var best: Bug = null
	var best_score := -INF
	if def.guards_plateau:
		for n: Node in bug_manager.get_children():
			var g := n as Bug
			if g == null or not _valid(g):
				continue
			var gscore := -g.global_position.distance_to(global_position)
			if gscore > best_score:
				best = g
				best_score = gscore
		return best
	for b in bug_manager.climbers_on(WorldLayout.other_cliff(cliff_id)):
		if not _valid(b):
			continue
		var score := Targeting.priority(b.climb_y, b.global_position.distance_to(global_position))
		if score > best_score:
			best = b
			best_score = score
	return best


## The cross-defense rule plus pitch limit, range and line of sight.
func _valid(b: Bug) -> bool:
	if not b.is_alive() or b.is_hidden():
		return false
	if def.guards_plateau:
		var on_plateau := b.state == Bug.State.BREACHING or b.state == Bug.State.FLYING
		if not Targeting.guard_allows(cliff_id, b.cliff_id, on_plateau):
			return false
		if def.guards_house:
			var home := Homestead.of(cliff_id)
			if home == null or b.global_position.distance_to(home.global_position) > Homestead.GUARD_RADIUS:
				return false
	elif not Targeting.cliff_allows(cliff_id, b.cliff_id, b.is_climbing()):
		return false
	var muzzle := _head.global_position
	if not Targeting.in_arc(muzzle, b.global_position, pitch_limit(), def.range * range_multiplier() * weather_range()):
		return false
	var q := PhysicsRayQueryParameters3D.create(muzzle, b.global_position, WorldLayout.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Look-down limit in degrees: the turret's own, plus 5 per scaffold level.
func pitch_limit() -> float:
	return def.pitch_limit_deg + LOOK_DOWN_PER_LEVEL * level


## How far the weather lets this turret see (fog: unless a lantern is near).
func weather_range() -> float:
	var w := GameState.weather
	if w != Weather.Kind.FOG:
		return Weather.turret_range(w)
	for l: Node in get_tree().get_nodes_in_group("lanterns"):
		if (l as Node3D).global_position.distance_to(global_position) < Weather.LANTERN_FOG_RADIUS:
			return Weather.turret_range(w, true)
	return Weather.turret_range(w)


func range_multiplier() -> float:
	return 1.0 + 0.1 * tier


func muzzle_position() -> Vector3:
	return _muzzle.global_position


func upgrade_cost() -> int:
	return Defs.UPGRADE_COSTS[tier] if tier < Defs.UPGRADE_COSTS.size() else -1


## Host: buy the next tier.
func upgrade() -> void:
	if multiplayer.is_server() and upgrade_cost() > 0:
		tier += 1
		health.setup(def.max_hp * (1.0 + 0.2 * tier))


func _aim_error_deg() -> float:
	var want := (aim_point - _gun.global_position).normalized()
	var have := -_gun.global_basis.z.normalized()
	return rad_to_deg(want.angle_to(have))


## Turns head (yaw) and gun (pitch) toward aim_point at the turret's turn speed.
func _aim_visual(delta: float) -> void:
	var local := to_local(aim_point) - _head.position
	var yaw := atan2(-local.x, -local.z)
	var horizontal := Vector2(local.x, local.z).length()
	var pitch := clampf(atan2(local.y, horizontal), -deg_to_rad(pitch_limit()), deg_to_rad(40.0))
	var step := deg_to_rad(def.turn_speed) * delta
	_head.rotation.y = rotate_toward(_head.rotation.y, yaw, step)
	_gun.rotation.x = rotate_toward(_gun.rotation.x, pitch, step)


func _draw_shot() -> void:
	var from := _muzzle.global_position
	var spread := deg_to_rad(def.spread_deg)
	var to := aim_point + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * from.distance_to(aim_point) * spread
	if vfx != null:
		if def.flight_time > 0.0:
			vfx.lob(from, to, def.flight_time, TurretEffects.shot_color(def))
		else:
			vfx.tracer(from, to, TurretEffects.shot_color(def), 0.12 if def.effect == TurretDef.Effect.KNOCKBACK else 0.05)
		vfx.muzzle_flash(from, -_gun.global_basis.z)
	var sound := StringName("gatling_%d" % (randi() % 3 + 1))
	match def.id:
		&"buffalo_rifle", &"lasso_harpoon", &"sharpshooter_tower":
			sound = &"buffalo"
		&"scattergun_post":
			sound = &"dynamite"
		&"water_cannon":
			sound = &"acid_spit"
		&"chili_mortar", &"dynamite_lobber":
			sound = &"build"
	Audio.play_at(sound, from, -4.0 if def.id == &"gatling_post" else 0.0)


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
	var text := "%s (tier %d)  %d/%d HP" % [def.display_name, tier, int(health.hp), int(health.max_hp)]
	if level > 0:
		text += "  - scaffold level %d (+%d deg look-down)" % [level, int(LOOK_DOWN_PER_LEVEL * level)]
	if not has_ammo:
		var needs: PackedStringArray = []
		for k: Variant in def.ammo_cost.keys():
			needs.append(String(k))
		text += "\nOut of ammo: needs %s" % ", ".join(needs)
	if needs_repair():
		text += "\nHold E: repair (1 scrap per %d HP)" % int(BuildManager.REPAIR_HP_PER_SCRAP)
	if upgrade_cost() > 0:
		text += "\nU: upgrade to tier %d (%d chitin)" % [tier + 1, upgrade_cost()]
	return text


func local_interact(_holding: bool) -> void:
	if needs_repair():
		BuildManager.instance.repair_node(self)


func _on_destroyed(_source: String, _source_cliff: int) -> void:
	if multiplayer.is_server():
		BuildManager.instance.on_structure_destroyed(self)
