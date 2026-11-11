class_name CrewedTurret
extends Turret
## Crewed: a 2 x 2 gun with a seat (Big Bertha, The Whaler, Thunder Mule, Sky Hound).
## Tap E to take the seat: your view moves behind the gun, the mouse aims it within
## its arcs, LMB fires (RMB reels on the Whaler), E or jump leaves. Left alone it
## still fires on its own, at half rate and half damage (CrewRules.UNMANNED_MULT).
##
## Networking follows the turrets: the host owns firing and damage. The gunner's
## peer sends its aim point and trigger state every tick (_crew_input); the host
## clamps the aim to the gun's arcs, fires, and replicates aim_point / shots plus
## the crewed state below, from which every peer draws the shots.

const MOUNT_GRACE := 0.3
## Host: a gunner whose input stops arriving this long is taken off the seat.
const INPUT_TIMEOUT := 2.0
## Unmanned Whaler: a lighter pin (fraction of the manned chain time).
const AUTO_CHAIN := 0.5
const SHOT_MASK := WorldLayout.LAYER_WORLD | WorldLayout.LAYER_BUG
const CHAIN_COLOR := Color("#3A3C44")

# Replicated (added to the turret's synchronizer).
var crew_peer := 0
var heat := 0.0
var overheated := false
var spin_up := 0.0
var chain_on := false
var chain_end := Vector3.ZERO
var reeling := false
var burst_at := Vector3.ZERO

# Host: the gunner's latest input.
var _in_aim := Vector3.ZERO
var _in_fire := false
var _in_alt := false
var _in_age := 99.0
# Host: the Whaler's chained bug.
var _chained: Bug
var _chain_left := 0.0
var _reeled := 0.0
var _barrel := 0

# Local gunner.
var _me: Player
var _mount_t := 0.0
var _pending_mount := false
var _rel_yaw := 0.0
var _seat_eye := Vector3(0, 1.4, 1.1)
var _aim_ok := true
## What of the gunner was showing before they sat (restored when they leave).
var _was_visible := {}
## Debug views (scenes/debug/crewed_views.gd): hold the triggers without a mouse.
var debug_fire := false
var debug_alt := false

# Looks.
var _drawn := 0
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _chain_mi: MeshInstance3D
var _hook_mi: MeshInstance3D
var _preview: MeshInstance3D
var _preview_im: ImmediateMesh
var _preview_mat: StandardMaterial3D
var _hot_hiss := 0.0


func setup(d: TurretDef, cid: int, c: Vector2i, pos: Vector3, owner_label: String, _stack_level: int = 0) -> void:
	super.setup(d, cid, c, pos, owner_label, _stack_level) # the tower gun gets the third level's reach
	if _stack_level > 0:
		# Crewed: up on the tower over the lower crewed gun (CrewedTower), which
		# also lets you take this seat from the ground.
		var tower := CrewedTower.new()
		tower.name = "Tower"
		tower.gun = self
		add_child(tower)
	add_to_group("crewed_turrets")
	_seat_eye = CrewedBuilder.seat(d.id)
	if not RiggedTurret.has(d.id): # (the fal models swivel about their own centre)
		_head.position.z = float(CrewedBuilder.HEAD_Z.get(d.id, 0.0))
	# One box over the whole 2 x 2 footprint instead of the post's cylinder.
	for ch in get_children():
		var cs := ch as CollisionShape3D
		if cs != null:
			var box := BoxShape3D.new()
			box.size = Vector3(3.3, 1.7, 3.3)
			cs.shape = box
			cs.position.y = 0.85
	if d.id == &"big_bertha" and _spin != null:
		# Barrels glow orange as they heat up.
		_glow = MeshInstance3D.new()
		_glow.mesh = _spin.mesh
		_glow.scale = Vector3.ONE * 1.04
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.albedo_color = Color(1.0, 0.35, 0.05, 0.0)
		_glow.material_override = _glow_mat
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.visible = false
		_spin.add_child(_glow)
	if d.id == &"whaler":
		_chain_mi = MeshInstance3D.new()
		_chain_mi.material_override = Materials.toon(0.01)
		_chain_mi.top_level = true
		_chain_mi.visible = false
		add_child(_chain_mi)
		_hook_mi = MeshInstance3D.new()
		_hook_mi.mesh = _hook_mesh()
		_hook_mi.material_override = Materials.toon(0.01)
		_hook_mi.top_level = true
		_hook_mi.visible = false
		add_child(_hook_mi)


func _make_synchronizer() -> MultiplayerSynchronizer:
	var sync := super._make_synchronizer()
	var cfg := sync.replication_config
	for p: String in [".:crew_peer", ".:heat", ".:overheated", ".:spin_up", ".:chain_on", ".:chain_end", ".:reeling", ".:burst_at"]:
		var path := NodePath(p)
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	return sync


func _exit_tree() -> void:
	if _me != null and is_instance_valid(_me):
		_leave_seat(false)


# ------------------------------------------------------------------ per tick

func _physics_process(delta: float) -> void:
	_drive_local(delta)
	super._physics_process(delta)
	_after_visual(delta)


func _process(_delta: float) -> void:
	# A short tap of E takes the seat; holding it repairs instead.
	if _pending_mount and not Input.is_action_pressed("interact"):
		_pending_mount = false
		_take_seat()


## Host: manned or not, fire this gun.
func _think(delta: float) -> void:
	_in_age += delta
	if crew_peer != 0 and (_in_age > INPUT_TIMEOUT or not _peer_present(crew_peer)):
		crew_peer = 0
	if crew_peer == 0:
		_in_fire = false
		_in_alt = false
	_tick_chain(delta)
	# Boss: webbed (Queen Spider) or stunned (Thunder Cicada) guns hold fire, as Turret._think does.
	if BossFx.holds_fire(self):
		return
	if not can_fire(): # Turret ammo: a crewed gun needs its sarsaparilla load
		return
	if crew_peer != 0:
		_think_manned(delta)
	else:
		_think_auto(delta)


func _peer_present(peer: int) -> bool:
	return peer == multiplayer.get_unique_id() or multiplayer.get_peers().has(peer)


## Host, nobody in the seat: pick targets like any turret, at half rate and damage.
func _think_auto(delta: float) -> void:
	_cooldown -= delta
	_retarget -= delta
	reeling = false
	_cool_barrels(0, false, delta)
	var lost := _target != null and (not is_instance_valid(_target) or not _target.is_alive() or _target.untargetable()) # a fading Mirage Mantis drops off
	if _retarget <= 0.0 or lost:
		_retarget = RETARGET_TIME + randf() * 0.1
		_target = _pick_target()
	if _target == null:
		return
	aim_point = _target.global_position
	_idle_t = 0.0
	if _cooldown > 0.0 or _aim_error_deg() > ALIGN_TOLERANCE_DEG * 2.0:
		return
	if def.id == &"whaler" and chain_on:
		return
	var mult := CrewRules.UNMANNED_MULT
	_cooldown = def.interval_at(tier) * Weather.turret_fire_interval(GameState.weather) * perk_rate / mult
	match def.id:
		&"big_bertha":
			shots += 1
			if randf() <= def.hit_chance * weather_hit(_target):
				TurretEffects.apply(self, _target, aim_point, def.damage_at(tier, TurretDef.is_heavy(_target.def)) * mult)
		&"whaler":
			shots += 1
			chain_end = _target.global_position
			if randf() <= def.hit_chance * weather_hit(_target):
				_attach(_target, _target.global_position, mult)
		&"thunder_mule":
			# Lead the crowd a little: they keep climbing while the shells fly.
			aim_point = _target.global_position + _target.velocity_hint() * CrewRules.lob_time(muzzle_position().distance_to(aim_point))
			shots += 1
			_salvo(aim_point, shots, mult)
		&"sky_hound":
			var burst := _target.global_position + _target.velocity_hint() * def.flight_time
			burst_at = burst
			shots += 1
			_flak(burst, mult)


## Host, someone in the seat: fire where they aim.
func _think_manned(delta: float) -> void:
	_cooldown -= delta
	_target = null
	aim_point = clamp_aim(_in_aim)
	_idle_t = 0.0
	match def.id:
		&"big_bertha":
			spin_up = CrewRules.spin_step(spin_up, _in_fire and not overheated, delta)
			var rounds := 0
			var firing := _in_fire and not overheated and spin_up >= CrewRules.SPIN_FIRE_MIN
			if firing:
				var iv := CrewRules.spin_interval(def.interval_at(tier) * perk_rate, spin_up)
				_cooldown = maxf(_cooldown, -delta)
				while _cooldown <= 0.0 and rounds < 4:
					_cooldown += iv
					rounds += 1
					_hitscan_round()
			_cool_barrels(rounds, firing, delta)
			shots += rounds
		&"whaler":
			reeling = chain_on and _in_alt
			if _in_fire and _cooldown <= 0.0 and not chain_on:
				_cooldown = def.interval_at(tier) * perk_rate
				shots += 1
				_harpoon_shot()
		&"thunder_mule":
			if _in_fire and _cooldown <= 0.0 and in_mortar_range(aim_point):
				_cooldown = def.interval_at(tier) * perk_rate
				shots += 1
				_salvo(aim_point, shots, 1.0)
		&"sky_hound":
			if _in_fire and _cooldown <= 0.0:
				_cooldown = def.interval_at(tier) * perk_rate
				_barrel = 1 - _barrel
				burst_at = _fuse_point(aim_point)
				shots += 1
				_flak(burst_at, 1.0)


## Big Bertha's heat and spin when she isn't being worked by a gunner, or after a burst.
func _cool_barrels(rounds: int, firing: bool, delta: float) -> void:
	if def.id != &"big_bertha":
		return
	if crew_peer == 0:
		spin_up = CrewRules.spin_step(spin_up, false, delta)
	var h := CrewRules.heat_step(heat, overheated, rounds, firing, delta)
	heat = h[0]
	overheated = h[1]


## Unmanned target choice: the Whaler wants the biggest heavy bug (and ignores small fry), Thunder Mule the
## thickest crowd near the top; the others pick like ordinary turrets.
func _pick_target() -> Bug:
	if bug_manager == null or not (def.id in [&"whaler", &"thunder_mule"]):
		return super._pick_target()
	var climbers := bug_manager.climbers_on(WorldLayout.other_cliff(cliff_id))
	var crowd := {}
	if def.id == &"thunder_mule":
		for b in climbers:
			var k := Vector2i(floori(b.lane_z / 4.0), floori(b.climb_y / 4.0))
			crowd[k] = int(crowd.get(k, 0)) + 1
	var best: Bug = null
	var best_score := -INF
	for b in climbers:
		var score := 0.0
		if def.id == &"whaler":
			if not TurretDef.is_heavy(b.def):
				continue # left alone it saves its slow harpoon for big bugs
			score = b.def.max_hp + b.climb_y
		else:
			var k := Vector2i(floori(b.lane_z / 4.0), floori(b.climb_y / 4.0))
			var n := 0
			for dz in range(-1, 2):
				for dy in range(-1, 2):
					n += int(crowd.get(k + Vector2i(dz, dy), 0))
			score = n * 20.0 + b.climb_y * 2.0
		score = Targeting.marked_priority(score, b.status.is_marked()) # Signal Flare
		if score > best_score and _valid(b):
			best = b
			best_score = score
	return best


func _sight_point() -> Vector3:
	return _gun.global_position + Vector3.UP * 0.2


## Mortar tubes point up at a lob, so only the heading has to line up.
func _aim_error_deg() -> float:
	if def.id != &"thunder_mule":
		return super._aim_error_deg()
	var want := to_local(aim_point)
	var have := global_basis.inverse() * -_head.global_basis.z
	return rad_to_deg(absf(angle_difference(atan2(-want.x, -want.z), atan2(-have.x, -have.z))))


# ------------------------------------------------------------------ host: shots

func _source() -> String:
	return "%s's %s" % [owner_name, def.display_name]


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, SHOT_MASK)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


## Big Bertha, manned: one round down the gunner's aim with a little spread.
func _hitscan_round() -> void:
	var from := muzzle_position()
	var dir := _spread((aim_point - from).normalized(), def.spread_deg)
	var hit := _ray(from, from + dir * def.range * range_multiplier())
	var hb := hit.get("collider") as Hitbox
	if hb == null:
		return
	var bug := hb.target as Bug
	var heavy := bug != null and TurretDef.is_heavy(bug.def)
	Gun.apply_hit_result(hit, dir, def.damage_at(tier, heavy), def.armor_pierce, _source(), cliff_id)


static func _spread(dir: Vector3, deg: float) -> Vector3:
	var r := deg_to_rad(deg)
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up := side.cross(dir).normalized()
	return (dir + side * randf_range(-r, r) + up * randf_range(-r, r)).normalized()


## The Whaler, manned: throw the harpoon down the aim; a bug it strikes is chained.
func _harpoon_shot() -> void:
	var from := muzzle_position()
	var dir := _spread((aim_point - from).normalized(), def.spread_deg)
	var hit := _ray(from, from + dir * def.range * range_multiplier())
	chain_end = hit["position"] if not hit.is_empty() else from + dir * def.range * range_multiplier()
	var hb := hit.get("collider") as Hitbox
	var bug := hb.target as Bug if hb != null else null
	if bug != null and is_instance_valid(bug) and bug.is_alive():
		_attach(bug, hit["position"], 1.0)


## Host: harpoon a bug: the strike's damage, then it's held on the chain.
func _attach(bug: Bug, at: Vector3, mult: float) -> void:
	var dir := (at - muzzle_position()).normalized()
	bug.receive_hit(def.damage_at(tier, TurretDef.is_heavy(bug.def)) * mult, at, dir, true, 1.0, _source(), cliff_id)
	if not bug.is_alive():
		return
	_chained = bug
	chain_on = true
	chain_end = bug.global_position
	_reeled = 0.0
	_chain_left = def.effect_size * (1.0 if mult >= 1.0 else AUTO_CHAIN)
	bug.status.root(0.3)


## Host, each tick: hold the chained bug, reel it while the gunner holds RMB, and
## let go when the chain time runs out, it hits the canyon floor, or it dies.
func _tick_chain(delta: float) -> void:
	if not chain_on:
		reeling = false
		return
	if _chained == null or not is_instance_valid(_chained) or not _chained.is_alive():
		_release(false)
		return
	_chained.status.root(0.25)
	chain_end = _chained.global_position
	_chain_left -= delta
	reeling = crew_peer != 0 and _in_alt and _chained.is_climbing()
	if reeling:
		var pull := CrewRules.reel_step(_chained.climb_y, delta)
		_chained.climb_y -= pull
		_reeled += pull
	var floored := _reeled > 0.0 and _chained.climb_y <= 0.05
	var too_far := chain_end.distance_to(muzzle_position()) > def.range * range_multiplier() * 1.3
	if _chain_left <= 0.0 or floored or too_far or not _chained.is_climbing():
		_release(true)


## Host: the chain lets go. A bug dragged down the wall takes a hard fall.
func _release(drop: bool) -> void:
	var b := _chained
	_chained = null
	chain_on = false
	reeling = false
	# The reload starts when the chain is free again.
	_cooldown = maxf(_cooldown, def.interval_at(tier) * perk_rate * (1.0 if crew_peer != 0 else 1.0 / CrewRules.UNMANNED_MULT))
	if drop and b != null and is_instance_valid(b) and b.is_alive() and _reeled > 0.5:
		b.health.take_damage(CrewRules.drop_damage(_reeled, tier), _source(), cliff_id)
		_drop_fx.rpc(b.global_position, _reeled)
	_reeled = 0.0


@rpc("authority", "call_local", "reliable")
func _drop_fx(pos: Vector3, metres: float) -> void:
	if vfx != null:
		vfx.dust_burst(pos, Vector3.UP, clampf(metres / 6.0, 0.6, 2.0))
		vfx.pop(pos, Palette.ROCK_C, 1.0)
	Audio.play_at(&"dynamite", pos, -8.0)


## Thunder Mule: three shells, a beat apart, onto the wall around `center`.
func _salvo(center: Vector3, seed_value: int, mult: float) -> void:
	var offs := CrewRules.salvo_offsets(seed_value)
	var radius := def.effect_size * range_multiplier()
	var from := muzzle_position()
	for i in offs.size():
		var land := center + Vector3(0, offs[i].y, offs[i].x)
		var t := CrewRules.SALVO_GAP * i + CrewRules.lob_time(from.distance_to(land))
		_delayed_splash(get_tree(), bug_manager, t, WorldLayout.other_cliff(cliff_id), land, radius,
				def.damage_at(tier) * mult, _source(), cliff_id)


static func _delayed_splash(tree: SceneTree, bugs: BugManager, t: float, cliff: int, at: Vector3, radius: float,
		damage: float, source: String, owner_cliff: int) -> void:
	var bugs_ref: WeakRef = weakref(bugs) # weak: the world can be freed mid-flight
	tree.create_timer(t).timeout.connect(func() -> void:
		var bm := bugs_ref.get_ref() as BugManager
		if bm != null:
			bm.splash(cliff, at, radius, damage, source, owner_cliff))


## Sky Hound, manned: the shell's proximity fuse bursts it beside the first
## flier along the aim; otherwise it bursts where you aimed (or at full range).
func _fuse_point(aim: Vector3) -> Vector3:
	var from := muzzle_position()
	var dir := (aim - from).normalized()
	var reach := def.range * range_multiplier()
	var fliers: Array = []
	var bugs: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and b.state == Bug.State.FLYING:
			fliers.append(b.global_position)
			bugs.append(b)
	var i := CrewRules.fuse_index(from, dir, fliers, reach)
	if i >= 0:
		return bugs[i].global_position + bugs[i].velocity_hint() * def.flight_time
	return from + dir * minf(from.distance_to(aim), reach)


## Host: a flak burst after the shell's flight, then a cloud that keeps stinging.
func _flak(at: Vector3, mult: float) -> void:
	_flak_damage(get_tree(), at, def.effect_size * range_multiplier(), def.damage_at(tier) * mult, _source(), cliff_id, def.flight_time)


static func _flak_damage(tree: SceneTree, at: Vector3, radius: float, damage: float, source: String, owner_cliff: int, flight: float) -> void:
	var ticks := int(CrewRules.CLOUD_TIME / CrewRules.CLOUD_TICK)
	for k in ticks + 1:
		var cloud := k > 0
		tree.create_timer(flight + k * CrewRules.CLOUD_TICK).timeout.connect(func() -> void:
			var r := radius * (0.8 if cloud else 1.0)
			for n: Node in tree.get_nodes_in_group("bugs"):
				var b := n as Bug
				if b == null or not b.is_alive() or b.state != Bug.State.FLYING:
					continue
				var d := b.global_position.distance_to(at)
				if d <= r:
					var dmg := damage * CrewRules.CLOUD_DAMAGE if cloud else damage * lerpf(1.0, 0.5, d / r)
					b.receive_hit(dmg, at, (b.global_position - at).normalized(), true, 1.0, source, owner_cliff))


# ------------------------------------------------------------------ aiming

## The aim point pulled inside the gun's traverse and elevation arcs (same on every peer).
func clamp_aim(p: Vector3) -> Vector3:
	var pivot := _head.global_position
	var local := global_basis.inverse() * (p - pivot)
	var dist := local.length()
	if dist < 0.5:
		return pivot - global_basis.z * 20.0
	var yaw := atan2(-local.x, -local.z)
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())
	var lob := def.id == &"thunder_mule"
	var c := CrewRules.clamp_aim(yaw, pitch, def.crew_yaw_arc_deg, 89.0 if lob else pitch_limit(), 89.0 if lob else def.crew_pitch_up_deg)
	if is_equal_approx(c.x, yaw) and is_equal_approx(c.y, pitch):
		return p
	var dir := Vector3(-sin(c.x) * cos(c.y), sin(c.y), -cos(c.x) * cos(c.y))
	return pivot + global_basis * dir * dist


## Thunder Mule: can the shells reach this point?
func in_mortar_range(p: Vector3) -> bool:
	return muzzle_position().distance_to(p) <= def.range * range_multiplier()


# ------------------------------------------------------------------ the seat

func interact_prompt() -> String:
	var text := super.interact_prompt()
	var key := KeyHints.key_for("interact")
	if crew_peer != 0 and crew_peer != multiplayer.get_unique_id():
		text += "\nManned by %s" % _crew_name()
	else:
		text += "\nUnmanned: fires at half rate and damage\n%s: take the seat" % key
	return text


func _crew_name() -> String:
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p != null and p.get_multiplayer_authority() == crew_peer:
			return p.display_name()
	return "your partner"


## What the prompt card shows while you're in the seat.
func crew_prompt() -> String:
	var leave := "%s: leave the seat" % KeyHints.key_for("interact")
	var fire := KeyHints.key_for("fire")
	var alt := KeyHints.key_for("alt_fire")
	var ready := _cooldown_left()
	match def.id:
		&"big_bertha":
			var state := "COOLING DOWN" if overheated else "heat %d%%" % (roundi(heat * 10.0) * 10)
			return "Big Bertha - %s\n%s: hold to spin up and fire   %s" % [state, fire, leave]
		&"whaler":
			var state := "chained: hold %s to reel it down" % alt if chain_on else ("reloading %d s" % ceili(ready) if ready > 0.05 else "harpoon ready")
			return "The Whaler - %s\n%s: fire harpoon   %s: hold to reel   %s" % [state, fire, alt, leave]
		&"thunder_mule":
			var state := ("reloading %d s" % ceili(ready)) if ready > 0.05 else ("salvo ready" if _aim_ok else "out of range")
			return "Thunder Mule - %s\n%s: fire a 3-shell salvo   %s" % [state, fire, leave]
	return "Sky Hound - flak bursts by whatever you aim at\n%s: fire   %s" % [fire, leave]


## Seconds until the gun can fire again, as the gunner sees it (host-accurate in
## solo; a client counts down its own copy from the shots it sees).
func _cooldown_left() -> float:
	return maxf(_local_cd, 0.0)


var _local_cd := 0.0
var _was_chained := false


func local_interact(holding: bool) -> void:
	if not holding and wants_load() and _load_count() > 0:
		super.local_interact(false) # Turret ammo: the first tap loads it
		return
	if holding:
		_pending_mount = false
		super.local_interact(true)
		return
	_pending_mount = true


func _local_player() -> Player:
	var world := get_tree().current_scene
	if world != null and world.has_method("local_player"):
		return world.call("local_player") as Player
	return null


func _take_seat() -> void:
	var me := _local_player()
	if me == null or me.is_downed() or me.crewing != null or me.seated:
		return
	var my_id := multiplayer.get_unique_id()
	if crew_peer != 0 and crew_peer != my_id:
		return
	_me = me
	_was_visible = {"rig": me.rig.visible, "gun": me.gun.visible, "hands": me.fp_hands.visible if me.fp_hands != null else true}
	me.crewing = self
	_mount_t = 0.0
	_rel_yaw = 0.0
	me.rotation.y = global_rotation.y
	me.head.rotation.x = deg_to_rad(-8.0)
	me.velocity = Vector3.ZERO
	if me.build_mode != null and me.build_mode.active:
		me.build_mode.toggle()
	if multiplayer.is_server():
		_host_mount(my_id)
	else:
		_req_mount.rpc_id(1)
	Audio.play_at(&"equip", global_position + Vector3.UP, -6.0)


@rpc("any_peer", "reliable")
func _req_mount() -> void:
	if multiplayer.is_server():
		_host_mount(multiplayer.get_remote_sender_id())


func _host_mount(peer: int) -> void:
	if crew_peer == 0 or crew_peer == peer:
		crew_peer = peer
		_in_age = 0.0
		_in_aim = aim_point
		_in_fire = false
		_in_alt = false


@rpc("any_peer", "reliable")
func _req_dismount() -> void:
	if multiplayer.is_server() and crew_peer == multiplayer.get_remote_sender_id():
		crew_peer = 0


## Local: step down off the gun, behind it.
func _leave_seat(tell_host: bool = true) -> void:
	var me := _me
	_me = null
	if _preview != null:
		_preview.visible = false
	if me == null or not is_instance_valid(me):
		return
	me.crewing = null
	me.rig.visible = bool(_was_visible.get("rig", true))
	me.gun.visible = bool(_was_visible.get("gun", true))
	if me.fp_hands != null:
		me.fp_hands.visible = bool(_was_visible.get("hands", true))
	if is_inside_tree() and me.is_inside_tree() and not is_queued_for_deletion():
		# Off the back of the gun; from the tower, down the ladder to the ground.
		var drop := ScaffoldNode.turret_height(level) if level > 0 else 0.0
		me.global_position = global_position + global_basis.z * (2.9 if level > 0 else 2.4) + Vector3.UP * (0.3 - drop)
		me.velocity = Vector3.ZERO
	if tell_host:
		if multiplayer.is_server():
			if crew_peer == multiplayer.get_unique_id():
				crew_peer = 0
		else:
			_req_dismount.rpc_id(1)


## Host: the gunner's aim and triggers, every tick.
@rpc("any_peer", "unreliable")
func _crew_input(aim: Vector3, fire: bool, alt: bool) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == crew_peer:
		_set_input(aim, fire, alt)


func _set_input(aim: Vector3, fire: bool, alt: bool) -> void:
	_in_aim = aim
	_in_fire = fire
	_in_alt = alt
	_in_age = 0.0


## Local gunner, each tick: keep the view inside the arcs, aim through the
## crosshair, and send the triggers to the host.
func _drive_local(delta: float) -> void:
	_local_cd -= delta
	if _me == null:
		return
	if not is_instance_valid(_me):
		_me = null
		return
	_mount_t += delta
	var my_id := multiplayer.get_unique_id()
	var lost := _mount_t > 1.0 and crew_peer != my_id
	var leave := _mount_t > MOUNT_GRACE and not GameState.menu_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump"))
	if lost or leave or _me.is_downed() or _me.is_plummeting():
		_leave_seat()
		return
	# Traverse: the body's yaw, kept inside the gun's arc.
	var rel := wrapf(_me.rotation.y - global_rotation.y, -PI, PI)
	var arc := deg_to_rad(def.crew_yaw_arc_deg)
	_rel_yaw = clampf(rel, -arc, arc)
	_me.rotation.y = global_rotation.y + _rel_yaw
	var up := def.crew_pitch_up_deg + 6.0
	var down := pitch_limit() + 4.0 if def.id != &"thunder_mule" else 60.0
	_me.head.rotation.x = clampf(_me.head.rotation.x, -deg_to_rad(down), deg_to_rad(up))
	_me.velocity = Vector3.ZERO
	_me.gun.visible = false
	_me.rig.visible = false # your own body would poke into the gunner's view
	if _me.fp_hands != null:
		_me.fp_hands.visible = false
	# Aim through the crosshair.
	var cam := _me.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var reach := def.range * range_multiplier() * 1.4
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, SHOT_MASK)
	q.exclude = [get_rid(), _me.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var aim: Vector3 = hit["position"] if not hit.is_empty() else from + dir * reach
	aim = clamp_aim(aim)
	aim_point = aim
	_aim_ok = def.id != &"thunder_mule" or (not hit.is_empty() and in_mortar_range(aim))
	var can := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameState.menu_open and _mount_t > MOUNT_GRACE
	var fire := debug_fire or (can and Input.is_action_pressed("fire"))
	var alt := debug_alt or (can and Input.is_action_pressed("alt_fire"))
	if multiplayer.is_server():
		_set_input(aim, fire, alt)
	else:
		_crew_input.rpc_id(1, aim, fire, alt)
	_update_preview(hit)


## After the turret's own aiming and effects: snap the head to the gunner, sit
## them in the seat, and draw the heat glow, chain and mortar pitch.
func _after_visual(delta: float) -> void:
	if _was_chained and not chain_on:
		_local_cd = def.interval_at(tier) * perk_rate * (1.0 if crew_peer != 0 else 1.0 / CrewRules.UNMANNED_MULT)
	_was_chained = chain_on
	if def.id == &"thunder_mule":
		var flat := to_local(aim_point)
		var pitch := deg_to_rad(CrewRules.lob_pitch_deg(Vector2(flat.x, flat.z).length(), def.range))
		_gun.rotation.x = pitch if _me != null else rotate_toward(_gun.rotation.x, pitch, deg_to_rad(def.turn_speed) * delta)
	if _me != null and is_instance_valid(_me):
		_head.rotation.y = _rel_yaw
		if def.id != &"thunder_mule":
			var local := _head.to_local(aim_point) - _gun.position
			_gun.rotation.x = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -deg_to_rad(pitch_limit()), deg_to_rad(def.crew_pitch_up_deg))
		_me.global_position = _head.global_transform * _seat_eye - Vector3.UP * Player.EYE_SEATED
	if def.id == &"big_bertha":
		_spin_speed = maxf(_spin_speed, spin_up * 34.0)
		if _glow != null:
			var hot := clampf((heat - 0.25) / 0.75, 0.0, 1.0)
			if overheated:
				hot = maxf(hot, 0.35) * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.012))
			_glow.visible = hot > 0.01
			_glow_mat.albedo_color = Color(1.0, 0.3 + 0.25 * hot, 0.05, hot * 0.8)
		if overheated:
			_hot_hiss -= delta
			if _hot_hiss <= 0.0:
				_hot_hiss = 0.45
				if vfx != null:
					vfx.spark(muzzle_position(), Vector3.UP, Color(1.0, 0.5, 0.15))
	if _chain_mi != null:
		_chain_mi.visible = chain_on
		_hook_mi.visible = chain_on
		if chain_on:
			var a := muzzle_position()
			var b := chain_end
			if a.distance_to(b) > 0.2 and (a.distance_squared_to(_chain_a) > 0.0025 or b.distance_squared_to(_chain_b) > 0.0025):
				_chain_a = a
				_chain_b = b
				_chain_mi.global_transform = Transform3D.IDENTITY
				_chain_mi.mesh = _chain_mesh(a, b)
				_hook_mi.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), b)


# ------------------------------------------------------------------ looks

## Every peer, per new shot: muzzle flashes, tracers, shells and bursts.
func _draw_shot() -> void:
	var n := clampi(shots - _drawn, 1, 4)
	_drawn = shots
	_recoil = 1.0
	_idle_t = 0.0
	_local_cd = def.interval_at(tier) * perk_rate * (1.0 if crew_peer != 0 else 1.0 / CrewRules.UNMANNED_MULT)
	var from := muzzle_position()
	var fwd := -_gun.global_basis.z
	match def.id:
		&"big_bertha":
			_spin_speed = 40.0
			for k in n:
				var dir := _spread((aim_point - from).normalized(), def.spread_deg)
				if vfx != null:
					vfx.tracer(from, from + dir * from.distance_to(aim_point), Palette.GLOW_YELLOW, 0.06)
			if vfx != null:
				vfx.muzzle_flash(from, fwd)
			Audio.play_at(StringName("gatling_%d" % (randi() % 3 + 1)), from, -5.0)
		&"whaler":
			var to := chain_end if chain_end != Vector3.ZERO else aim_point
			if vfx != null:
				vfx.tracer(from, to, Palette.BONE.darkened(0.3), 0.14)
				vfx.muzzle_flash(from, fwd)
			Audio.play_at(&"harpoon", from, 2.0)
		&"thunder_mule":
			var offs := CrewRules.salvo_offsets(shots)
			for i in offs.size():
				var tube := _gun.global_transform * Vector3(CrewedBuilder.TUBES_X[i], 0.0, -0.58)
				var land := aim_point + Vector3(0, offs[i].y, offs[i].x)
				get_tree().create_timer(CrewRules.SALVO_GAP * i + 0.001).timeout.connect(_mule_shell.bind(tube, land))
		&"sky_hound":
			var bx: float = CrewedBuilder.HOUND_BARRELS_X[shots % 2]
			var muzzle := _gun.global_transform * Vector3(bx, 0.02, -1.75)
			if vfx != null:
				vfx.muzzle_flash(muzzle, fwd)
				vfx.tracer(muzzle, burst_at, Palette.GLOW_YELLOW.lightened(0.3), 0.07)
			Audio.play_at(&"cannon", muzzle, -3.0)
			get_tree().create_timer(def.flight_time).timeout.connect(_flak_cloud.bind(burst_at, def.effect_size * range_multiplier()))


func _mule_shell(tube: Vector3, land: Vector3) -> void:
	if vfx != null:
		vfx.lob(tube, land, CrewRules.lob_time(tube.distance_to(land)), Palette.METAL.darkened(0.4))
		vfx.muzzle_flash(tube, (CrewRules.lob_point(tube, land, 0.05) - tube).normalized())
	Audio.play_at(&"mortar", tube, -2.0)
	_recoil = 1.0


## Every peer: the flak burst, a flash and a black cloud that lingers and drifts.
func _flak_cloud(at: Vector3, radius: float) -> void:
	if vfx != null:
		vfx.pop(at, Palette.GLOW_YELLOW, radius * 0.35)
	Audio.play_at(&"dynamite", at, -6.0)
	var root := get_tree().current_scene
	if root == null:
		return
	var cloud := Node3D.new()
	root.add_child(cloud)
	cloud.global_position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.13, 0.12, 0.12, 0.75)
	var mesh := _puff_mesh()
	for i in 7:
		var p := MeshInstance3D.new()
		p.mesh = mesh
		p.material_override = mat
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var off := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * radius * 0.45
		p.position = off
		p.scale = Vector3.ONE * radius * 0.25
		cloud.add_child(p)
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "scale", Vector3.ONE * radius * randf_range(0.45, 0.6), CrewRules.CLOUD_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(p, "position", off * 1.4 + Vector3.UP * 1.2, CrewRules.CLOUD_TIME + 0.6)
	var fade := cloud.create_tween()
	fade.tween_interval(CrewRules.CLOUD_TIME * 0.6)
	fade.tween_property(mat, "albedo_color:a", 0.0, CrewRules.CLOUD_TIME * 0.6)
	fade.tween_callback(cloud.queue_free)


static var _puff: ArrayMesh


static func _puff_mesh() -> ArrayMesh:
	if _puff == null:
		var st := MeshKit.begin()
		var rng := RandomNumberGenerator.new()
		rng.seed = 905
		MeshKit.add_ellipsoid(st, Transform3D(), Vector3.ONE, 5, 10, Color.WHITE, 0.15, rng)
		_puff = MeshKit.finish(st)
	return _puff


var _chain_a := Vector3.ZERO
var _chain_b := Vector3.ZERO


## The chain from `a` to `b` in world space: links turned alternately a quarter turn.
static func _chain_mesh(a: Vector3, b: Vector3) -> ArrayMesh:
	var st := MeshKit.begin()
	var span := a.distance_to(b)
	var look := Basis.looking_at(b - a, Vector3.UP)
	var link := 0.32
	var n := mini(int(span / link), 400)
	for i in n:
		var at := a.lerp(b, (float(i) + 0.5) / n)
		var turn := Basis(look.z, PI * 0.5 * (i % 2))
		MeshKit.add_box(st, Transform3D(turn * look, at), Vector3(0.13, 0.04, span / n * 1.15), CHAIN_COLOR.lightened(0.15 * (i % 2)))
	return MeshKit.finish(st)


## The harpoon head left in the bug, pointing along -Z.
static func _hook_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(CrewedBuilder.ALONG, Vector3(0, 0, 0.4)), 0.04, 0.04, 0.8, 6, CHAIN_COLOR)
	MeshKit.add_cylinder(st, Transform3D(CrewedBuilder.ALONG, Vector3(0, 0, -0.05)), 0.0, 0.12, 0.3, 8, Palette.METAL.lightened(0.3))
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		var d := Vector3(cos(a), sin(a), 0)
		MeshKit.add_limb(st, d * 0.05 + Vector3(0, 0, 0.05), d * 0.2 + Vector3(0, 0, 0.25), 0.02, Palette.METAL, 3)
	return MeshKit.finish(st)


## Thunder Mule, local gunner only: the shells' arc and where they'll land.
func _update_preview(hit: Dictionary) -> void:
	if def.id != &"thunder_mule":
		return
	if _preview == null:
		_preview_im = ImmediateMesh.new()
		_preview = MeshInstance3D.new()
		_preview.mesh = _preview_im
		_preview.top_level = true
		_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_preview_mat = StandardMaterial3D.new()
		_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_preview_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_preview_mat.vertex_color_use_as_albedo = true
		_preview_mat.no_depth_test = true # the ring stays whole on a jagged wall
		_preview_mat.render_priority = 2
		_preview.material_override = _preview_mat
		add_child(_preview)
		_preview.global_transform = Transform3D.IDENTITY
	_preview.visible = true
	_preview_im.clear_surfaces()
	var ready := _cooldown_left() <= 0.05
	var col := Palette.GLOW_YELLOW if (ready and _aim_ok) else (Color(1.0, 0.35, 0.3) if not _aim_ok else Palette.BONE)
	col.a = 0.9 if ready else 0.55
	var from := _gun.global_transform * Vector3(0, 0, -0.58)
	var to := aim_point
	var cam := _me.camera.global_position
	_preview_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dashed arc: a ribbon facing the camera, every other segment.
	var steps := 48
	for i in steps:
		if i % 3 != 0 or i < 3:
			continue # dashes, and none right under your nose
		var p0 := CrewRules.lob_point(from, to, float(i) / steps)
		var p1 := CrewRules.lob_point(from, to, float(i + 1) / steps)
		var side := (p1 - p0).cross(cam - p0).normalized() * 0.06
		_quad(p0 - side, p0 + side, p1 + side, p1 - side, col)
	# The splash ring on the wall, plus a small mark at the centre.
	var normal: Vector3 = hit.get("normal", Vector3(WorldLayout.side_sign(cliff_id), 0, 0))
	var r := def.effect_size * range_multiplier() + CrewRules.SALVO_SPREAD.x * 0.6
	var u := normal.cross(Vector3.UP).normalized()
	if u.length() < 0.1:
		u = Vector3.FORWARD
	var v := normal.cross(u).normalized()
	var c := to + normal * 0.35
	var segs := 40
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var o0 := u * cos(a0) + v * sin(a0)
		var o1 := u * cos(a1) + v * sin(a1)
		_quad(c + o0 * r, c + o1 * r, c + o1 * (r - 0.35), c + o0 * (r - 0.35), col)
	var next := CrewRules.salvo_offsets(shots + 1)
	for i in next.size():
		var p := c + Vector3(0, next[i].y, next[i].x)
		_quad(p - u * 0.25 - v * 0.25, p + u * 0.25 - v * 0.25, p + u * 0.25 + v * 0.25, p - u * 0.25 + v * 0.25, Color(col, col.a * 0.6))
	_preview_im.surface_end()


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for p: Vector3 in [a, b, c, a, c, d]:
		_preview_im.surface_set_color(col)
		_preview_im.surface_add_vertex(p)
