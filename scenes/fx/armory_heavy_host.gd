extends Node
## Blast kills read as "<name>'s blast" so KillMethod counts them as explosives.
const ARMORY_BLAST := "'s blast"
## Host only: the heavies' (and two primaries') specials as they play out in the
## world (ArmoryHeavyRules has the numbers). One of these sits under the current
## scene while anything is pending: delayed blasts (mortar shells and rockets in
## flight), bear traps waiting for a bug, and each bug's acid exposure. It frees
## itself when idle, and goes with the scene when that changes.
## Visuals go to every peer through PlayerNet.armory_fx (kinds in ArmoryHeavyFx).

## Bear trap source suffix: KillMethod counts "... Bear Trap" as a trap kill.
const TRAP_SOURCE := "%s's Bear Trap"
## Acid exposure entries older than this (seconds) are forgotten.
const ACID_FORGET := 4.0

## Pending blasts: {at, center, radius, damage, source, cliff, target (WeakRef or null)}.
var _blasts: Array[Dictionary] = []
## Live traps, oldest first: {id, pos, peer, damage, gun, level, source, cliff}.
var _traps: Array[Dictionary] = []
## Acid exposure: bug instance id -> [seconds of exposure, time of the last puff].
var _acid: Dictionary = {}
var _next_trap := 1
var _was_wave := false
## The last shooter's PlayerNet (sends the fx of traps that spring later).
var _net_ref: WeakRef


func _ready() -> void:
	_was_wave = _in_wave()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		queue_free()
		return
	var now := _now()
	_run_blasts(now)
	_run_traps()
	var wave := _in_wave()
	if ArmoryHeavyRules.traps_clear(_was_wave, wave):
		_clear_traps()
	_was_wave = wave
	for k: Variant in _acid.keys():
		if now - float((_acid[k] as Array)[1]) > ACID_FORGET:
			_acid.erase(k)
	if _blasts.is_empty() and _traps.is_empty() and _acid.is_empty():
		queue_free()


# ------------------------------------------------------------------ entry points

## One puff of a spray heavy (Fire Lance, Acid Drencher).
func spray(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, level: int) -> void:
	var reach := Gun.range_for(def.id, level) * ArmoryHeavyRules.radius_scale(def.id, level)
	var dmg := Gun.damage_for(def.id, level)
	_net_ref = weakref(net)
	# "<name>'s Fire Lance": KillMethod counts the lance's kills as fire.
	var source := "%s's %s" % [net.player.display_name(), def.display_name] if def.special == &"fire" else net.player.display_name()
	var cliff := net.player.cliff_id
	var acid := def.special == &"acid"
	var now := _now()
	for b in _bugs():
		var p := b.global_position
		if acid:
			if not ArmoryHeavyRules.in_acid(origin, dir, p, reach):
				continue
		elif not ArmoryHeavyRules.in_flame(origin, dir, p, reach):
			continue
		b.receive_hit(dmg, p, dir, false, 1.0, source, cliff)
		if not b.is_alive():
			continue
		if acid:
			_acid_puff(net, b, def, level, now)
		else:
			b.status.burn(ArmoryHeavyRules.burn_dps(level), ArmoryHeavyRules.burn_time(def.id, level), source, cliff)
	net.armory_fx.rpc(&"hv_acid" if acid else &"hv_flame", _muzzle(net, origin, dir), dir, reach)


## What a heavy's shot does where the first ray stopped (ArmoryEffects.impact).
func impact(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, normal: Vector3,
		hit: Dictionary, level: int) -> void:
	_net_ref = weakref(net)
	match def.special:
		&"mortar":
			_mortar(net, def, origin, dir, point, normal, hit, level)
		&"rocket":
			_rocket(net, def, origin, dir, point, level)
		&"ballista":
			_ballista(net, def, origin, dir, point, hit, level)
		&"beartrap":
			_beartrap(net, def, point, normal, hit, level)
		&"ricochet":
			_ricochet(net, def, origin, dir, point, normal, hit, level)
		&"pierce_line":
			_pierce(net, def, origin, dir, point, hit, level)


# ------------------------------------------------------------------ heavies

func _mortar(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, normal: Vector3,
		hit: Dictionary, level: int) -> void:
	var land := point
	var up := normal
	if hit.is_empty():
		# Fired into the open sky: the shell comes down on whatever is under the end of the ray.
		var down := net.player.gun.raycast(point, Vector3.DOWN, [net.player.get_rid()], 400.0)
		if not down.is_empty():
			land = down["position"]
			up = down["normal"]
	var start := _muzzle(net, origin, dir)
	var flight := ArmoryHeavyRules.mortar_flight(start.distance_to(land))
	var center := land + up * 0.3
	var concussion := def.id == &"concussion_mortar"
	var radius := (ArmoryHeavyRules.CONCUSSION_RADIUS if concussion else ArmoryHeavyRules.MORTAR_RADIUS) 			* ArmoryHeavyRules.radius_scale(def.id, level)
	_queue_blast(net, flight, center, radius, Gun.damage_for(def.id, level), null)
	if concussion:
		_blasts[-1]["ring"] = ArmoryHeavyRules.CONCUSSION_RING
		_blasts[-1]["burn"] = WeaponMods.flag(def.id, level, "burn")
	net.armory_fx.rpc(&"hv_mortar", start, center, ArmoryHeavyRules.pack_blast(flight, radius))


func _rocket(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, level: int) -> void:
	var reach := Gun.range_for(def.id, level)
	var live := _bugs()
	var spots: Array[Vector3] = []
	for b in live:
		spots.append(_aim_point(b))
	var pick := ArmoryHeavyRules.rocket_pick(origin, dir, spots, reach)
	var start := _muzzle(net, origin, dir)
	var end := spots[pick] if pick >= 0 else point
	var path := ArmoryHeavyRules.rocket_path(start, dir, end, pick >= 0)
	var flight := ArmoryHeavyRules.rocket_flight(path)
	var radius := ArmoryHeavyRules.ROCKET_RADIUS * ArmoryHeavyRules.radius_scale(def.id, level)
	_queue_blast(net, flight, end, radius, Gun.damage_for(def.id, level), live[pick] if pick >= 0 else null)
	net.armory_fx.rpc(&"hv_rocket", start, end, ArmoryHeavyRules.pack_rocket(dir, pick >= 0))


func _ballista(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, hit: Dictionary, level: int) -> void:
	var linger := 0.0
	var bug := _bug_of(hit)
	if bug != null:
		if bug.is_alive() and bug.is_climbing():
			var pin := ArmoryHeavyRules.ballista_pin(bug.boss != null, def.id, level)
			bug.status.root(pin)
			linger = pin
	elif not hit.is_empty() and not (hit["collider"] is Hitbox):
		linger = ArmoryHeavyRules.BALLISTA_WALL_LINGER
	net.armory_fx.rpc(&"hv_bolt", _muzzle(net, origin, dir), point, linger)


func _beartrap(net: PlayerNet, def: WeaponDef, point: Vector3, normal: Vector3, hit: Dictionary, level: int) -> void:
	if hit.is_empty():
		return # into the sky: nothing to bite
	var source := TRAP_SOURCE % net.player.display_name()
	var dmg := Gun.damage_for(def.id, level)
	var bug := _bug_of(hit)
	if bug != null:
		# Straight onto a bug: it snaps shut there and then.
		if bug.is_alive():
			_spring(bug, def.id, dmg, level, source, net.player.cliff_id)
		net.armory_fx.rpc(&"hv_trap_snap", point, normal, -1.0)
		return
	if hit["collider"] is Hitbox:
		return # some other shootable thing: no surface to sit on
	var peer := net.player.get_multiplayer_authority()
	var mine: Array[Dictionary] = []
	for t in _traps:
		if int(t["peer"]) == peer:
			mine.append(t)
	var evict := ArmoryHeavyRules.trap_to_evict(mine.size(), ArmoryHeavyRules.trap_cap(def.id, level))
	if evict >= 0:
		_remove_trap(mine[evict], false)
	var id := _next_trap
	_next_trap += 1
	_traps.append({"id": id, "pos": point, "peer": peer, "damage": dmg, "gun": def.id, "level": level, "source": source,
			"cliff": net.player.cliff_id})
	net.armory_fx.rpc(&"hv_trap", point, normal, float(id))


# ------------------------------------------------------------------ primaries

func _ricochet(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, normal: Vector3,
		hit: Dictionary, level: int) -> void:
	if hit.is_empty():
		return
	var bug := _bug_of(hit)
	var on_bug := hit["collider"] is Hitbox
	if not ArmoryHeavyRules.bounces_off(on_bug, bug != null and TurretDef.is_heavy(bug.def)):
		return
	var left := Gun.range_for(def.id, level) - origin.distance_to(point)
	if left < 1.0:
		return
	var out := ArmoryHeavyRules.bounce_dir(dir, normal)
	var exclude: Array[RID] = [net.player.get_rid(), hit["rid"]]
	var from := point + normal.normalized() * 0.03
	var hit2 := net.player.gun.raycast(from, out, exclude, left)
	var end: Vector3 = hit2["position"] if not hit2.is_empty() else from + out * minf(left, 60.0)
	var struck := not hit2.is_empty() and hit2["collider"] is Hitbox
	if struck:
		Gun.apply_hit_result(hit2, out, Gun.damage_for(def.id, level) * ArmoryHeavyRules.RICOCHET_MULT,
				Gun.pierce_for(def.id, level), net.player.display_name(), net.player.cliff_id)
	net.armory_fx.rpc(&"hv_ricochet", point, end, 1.0 if struck else 0.0)


func _pierce(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, hit: Dictionary,
		level: int) -> void:
	if hit.is_empty() or not (hit["collider"] is Hitbox):
		return
	var reach := Gun.range_for(def.id, level)
	var exclude: Array[RID] = [net.player.get_rid(), hit["rid"]]
	var end := point
	var count := 0
	for i in ArmoryHeavyRules.PIERCE_MAX:
		var next := net.player.gun.raycast(origin, dir, exclude, reach)
		if next.is_empty():
			end = origin + dir * minf(reach, end.distance_to(origin) + 40.0)
			break
		end = next["position"]
		if not (next["collider"] is Hitbox):
			break
		var dist := origin.distance_to(end)
		Gun.apply_hit_result(next, dir, Gun.damage_at(def.id, level, dist), Gun.pierce_for(def.id, level),
				net.player.display_name(), net.player.cliff_id)
		exclude.append(next["rid"])
		count += 1
	net.armory_fx.rpc(&"hv_pierce", point, end, float(count))


# ------------------------------------------------------------------ blasts

func _queue_blast(net: PlayerNet, delay: float, center: Vector3, radius: float, damage: float, target: Bug) -> void:
	_blasts.append({"at": _now() + delay, "center": center, "radius": radius, "damage": damage,
			"source": net.player.display_name() + ARMORY_BLAST, "cliff": net.player.cliff_id, # (KillMethod: explosives)
			"target": weakref(target) if target != null else null})


func _run_blasts(now: float) -> void:
	var i := 0
	while i < _blasts.size():
		var bl := _blasts[i]
		if now < float(bl["at"]):
			i += 1
			continue
		_blasts.remove_at(i)
		var center: Vector3 = bl["center"]
		var ref: WeakRef = bl["target"]
		if ref != null:
			# A homing rocket bursts on its bug if that is still near where it aimed.
			var t := ref.get_ref() as Bug
			if t != null and t.is_alive() and _aim_point(t).distance_to(center) <= ArmoryHeavyRules.ROCKET_FOLLOW:
				center = _aim_point(t)
		_blast(center, float(bl["radius"]), float(bl["damage"]), String(bl["source"]), int(bl["cliff"]),
				float(bl.get("ring", -1.0)), bool(bl.get("burn", false)))


## Every bug in the radius (climbers, the plateau, the floor and the air) takes
## the blast, less toward the edge.
func _blast(center: Vector3, radius: float, damage: float, source: String, source_cliff: int,
		ring: float = -1.0, burn: bool = false) -> void:
	var hit_cliff := -1
	for b in _bugs():
		var share := ArmoryHeavyRules.blast_share(b.global_position.distance_to(center), radius, ring)
		if share <= 0.0:
			continue
		if hit_cliff < 0 and b.is_climbing():
			hit_cliff = b.cliff_id
		b.receive_hit(damage * share, center, (b.global_position - center).normalized(), true, 1.0, source, source_cliff)
		if burn and is_instance_valid(b) and b.is_alive():
			b.status.burn(ArmoryHeavyRules.CONCUSSION_BURN_DPS, ArmoryHeavyRules.CONCUSSION_BURN_TIME, source, source_cliff)
	# Bosses with breakable parts and corpse piles react as to any splash.
	BossFx.on_splash(hit_cliff if hit_cliff >= 0 else WorldLayout.other_cliff(source_cliff), center, radius, damage,
			source, source_cliff)


# ------------------------------------------------------------------ acid

func _acid_puff(net: PlayerNet, b: Bug, def: WeaponDef, level: int, now: float) -> void:
	var key := b.get_instance_id()
	var entry: Array = _acid.get(key, [0.0, -1000.0])
	var exposure := ArmoryHeavyRules.acid_exposure(float(entry[0]), now - float(entry[1]), def.fire_interval)
	_acid[key] = [exposure, now]
	if ArmoryHeavyRules.acid_strips(exposure):
		var fresh := not b.status.is_stripped()
		b.status.strip(ArmoryHeavyRules.acid_strip_time(def.id, level))
		if fresh:
			net.armory_fx.rpc(&"hv_sizzle", _aim_point(b), Vector3.UP, 0.0)


# ------------------------------------------------------------------ traps

func _run_traps() -> void:
	if _traps.is_empty():
		return
	var live := _bugs()
	var i := 0
	while i < _traps.size():
		var t := _traps[i]
		var pos: Vector3 = t["pos"]
		var caught: Bug = null
		for b in live:
			if ArmoryHeavyRules.trap_catches(b.global_position.distance_to(pos), float(b.spec.get("body_radius", 0.0))):
				caught = b
				break
		if caught == null:
			i += 1
			continue
		_traps.remove_at(i)
		_spring(caught, StringName(t["gun"]), float(t["damage"]), int(t["level"]), String(t["source"]), int(t["cliff"]))
		_send_fx(&"hv_trap_snap", pos, Vector3.ZERO, float(t["id"]))


## A trap closes on a bug: damage, and it's held fast.
func _spring(b: Bug, gun: StringName, damage: float, level: int, source: String, source_cliff: int) -> void:
	b.receive_hit(damage, b.global_position, Vector3.DOWN, true, 1.0, source, source_cliff)
	if b.is_alive():
		b.status.root(ArmoryHeavyRules.trap_root(b.boss != null, gun, level))


func _remove_trap(t: Dictionary, _snapped: bool) -> void:
	_traps.erase(t)
	_send_fx(&"hv_trap_gone", t["pos"], Vector3.ZERO, float(t["id"]))


func _clear_traps() -> void:
	if _traps.is_empty():
		return
	_traps.clear()
	_send_fx(&"hv_trap_gone", Vector3.ZERO, Vector3.ZERO, -1.0)


# ------------------------------------------------------------------ helpers

## Sends an fx through the last shooter's PlayerNet (the rpc is the same on all
## of them); with none left, at least the host sees it.
func _send_fx(kind: StringName, a: Vector3, b: Vector3, x: float) -> void:
	var pn := _net_ref.get_ref() as PlayerNet if _net_ref != null else null
	if pn != null and pn.is_inside_tree():
		pn.armory_fx.rpc(kind, a, b, x)
	else:
		ArmoryEffects.play_fx(kind, a, b, x)


func _bugs() -> Array[Bug]:
	var out: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and not b.is_hidden():
			out.append(b)
	return out


func _bug_of(hit: Dictionary) -> Bug:
	if hit.is_empty():
		return null
	var hb := hit["collider"] as Hitbox
	if hb == null:
		return null
	var b := hb.target as Bug
	return b if b != null and is_instance_valid(b) else null


## The middle of a bug's body (where a homing shot aims).
static func _aim_point(b: Bug) -> Vector3:
	return b.global_position + b.global_basis.y * float(b.spec.get("clearance", 0.5)) * 0.5


## Where the shooter's projectile visibly leaves from: the host's own view-model
## muzzle, or a point just ahead of and below a client's eye.
static func _muzzle(net: PlayerNet, origin: Vector3, dir: Vector3) -> Vector3:
	if net.player.is_multiplayer_authority() and net.player.gun != null:
		var m := net.player.gun.muzzle_global()
		if m.distance_to(origin) < 2.0:
			return m
	return ArmoryHeavyRules.muzzle_from(origin, dir)


func _in_wave() -> bool:
	return GameState.phase == GameState.Phase.WAVE


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
