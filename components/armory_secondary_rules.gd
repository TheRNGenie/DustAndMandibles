class_name ArmorySecondaryRules
extends RefCounted
## Host-side rules for the new secondaries' specials (see ArmoryEffects): the
## crowd control of the Weapon Slots Redesign. Instant effects happen here; the
## lasting ones (scatter, knock-back, lures, caltrops, phosphor fire, berserk
## bugs off the wall) are ticked by one helper node (armory_secondary_zones.gd).
## Visuals go to every peer through PlayerNet.armory_fx (ArmorySecondaryFx):
##   sec_tar / sec_rust   a = muzzle, b = direction (unit), x = reach (m)
##   sec_scream           a = burst point, b = surface normal (or zero), x = radius
##   sec_flash            a = burst point, b = surface normal (or zero), x = radius
##   sec_pepper           a = burst point, b = surface normal (or zero), x = radius
##   sec_concuss          a = muzzle, b = direction (unit), x = reach (m)
##   sec_chain            a, b = the two ends of one chain link, x = seconds bound
##   sec_lure             a = grub, b = surface normal (or zero), x = seconds
##   sec_caltrops         a = patch centre, b = normal * radius, x = seconds
##   sec_caltrops_clear   a = centre of a patch lifted early
##   sec_phosphor         a = fire centre, b = normal * radius, x = seconds
## Rarity (WeaponMods.level) and the gunsmith's "effect" / "radius" mods scale
## durations, strength and areas (effect_k / radius_k).

const Zones := preload("res://scenes/fx/armory_secondary_zones.gd")

## Rarity: each level above Common adds this share to durations / to radii.
const DUR_STEP := 0.12
const RAD_STEP := 0.05

## Screamer Pistol: scatter radius, how long they flee, how fast (m/s; heavies slower).
const SCREAM_RADIUS := 12.0
const SCREAM_TIME := 2.5
const SCATTER_GROUND := 6.0
const SCATTER_WALL := 3.5
const SCATTER_DOWN := 1.0
const SCATTER_HEAVY := 0.6
## Scattered bugs' own movement is slowed to this, so the panic carries them.
const SCATTER_SLOW := 0.4

## Tar Sprayer / Rust Duster: the cone's half-angle (the Bee Smoker's).
const SPRAY_HALF_ANGLE := 24.0
## Tar: speed left (0.4 = 60% slower), bosses keep more; seconds coated.
const TAR_SLOW := 0.4
const TAR_BOSS_SLOW := 0.75
const TAR_TIME := 6.0
## Rust: seconds the armour is gone (bosses: this share of it).
const RUST_TIME := 8.0
const RUST_BOSS := 0.5
## Sprays: at most one puff visual every this many ms per shooter.
const PUFF_FX_MS := 110

## Flashbang: stun radius and time (bosses resist).
const FLASH_RADIUS := 10.0
const FLASH_TIME := 2.0
const FLASH_BOSS_TIME := 0.5

## Pepper-Bomb: cloud radius and berserk time (no effect on bosses).
const PEPPER_RADIUS := 8.0
const PEPPER_TIME := 3.0

## Concussion Pistol: the blast cone's half-angle (the doc's "15 degree cone"),
## metres ground bugs tumble back (heavies half), over this many seconds, and
## metres a heavy climber slips down the face.
const CONCUSS_HALF_ANGLE := 15.0
const CONCUSS_PUSH := 8.0
const CONCUSS_HEAVY_PUSH := 0.5
const CONCUSS_PUSH_TIME := 0.35
const CONCUSS_HEAVY_SLIP := 3.0

## Chain Binder: most bugs on one chain, how wide the chain sweeps, bind times.
const CHAIN_COUNT := 4
const CHAIN_WIDTH := 1.0
const CHAIN_TIME := 5.0
const CHAIN_BOSS_TIME := 1.0

## Glow-Worm Launcher: pull radius and seconds it glows.
const LURE_RADIUS := 15.0
const LURE_TIME := 5.0

## Caltrops: patch radius (8 m across) and seconds it lasts.
const CALTROP_RADIUS := 4.0
const CALTROP_TIME := 12.0

## Phosphor Grenade: fire radius (10 m across) and seconds it burns.
const PHOSPHOR_RADIUS := 5.0
const PHOSPHOR_TIME := 6.0

## Shots that miss in the air: lures, caltrops and fire drop to whatever is below, up to this far.
const DROP_REACH := 90.0
## Plateau bugs pushed toward the lip stop this far back from it.
const LIP_MARGIN := 0.8

static var _zones: Node


## Durations and strength: rarity plus the "effect" mod.
static func effect_k(def: WeaponDef, level: int) -> float:
	return (1.0 + DUR_STEP * WeaponMods.level(level)) * WeaponMods.mult(def.id, level, "effect")


## Areas and cone reach: rarity plus the "radius" mod.
static func radius_k(def: WeaponDef, level: int) -> float:
	return (1.0 + RAD_STEP * WeaponMods.level(level)) * WeaponMods.mult(def.id, level, "radius")


## A slow factor made stronger by `k` (1 = as is): the part taken away grows.
static func slow_with(factor: float, k: float) -> float:
	return clampf(1.0 - (1.0 - factor) * k, 0.1, 1.0)


## The host's helper node for lasting effects (made on first use, frees itself when idle).
static func zones(net: Node) -> Zones:
	if is_instance_valid(_zones) and not _zones.is_queued_for_deletion() and _zones.is_inside_tree():
		return _zones as Zones
	var z := Zones.new()
	z.name = "ArmorySecondaryZones"
	Zones.lane_of = _lane_of
	Zones.keep_on_plateau = _keep_on_plateau
	net.get_tree().current_scene.add_child(z)
	_zones = z
	return z


static func _lane_of(cliff: int, p: Vector3) -> float:
	return Bug.cliffs.plateau_coords(cliff, p).y if Bug.cliffs != null else p.z


## A plateau bug pushed toward the lip stays LIP_MARGIN back from it, on the ground.
static func _keep_on_plateau(b: Object, p: Vector3) -> Vector3:
	var cl := Bug.cliffs
	if cl == null:
		return p
	var c := int(b.get("cliff_id"))
	var pc := cl.plateau_coords(c, p)
	if pc.x < LIP_MARGIN:
		var q := cl.plateau_point(c, LIP_MARGIN, pc.y)
		p = Vector3(q.x, p.y, q.z)
	p.y = cl.ground_height_at(c, p)
	return p


static func _bugs(net: Node) -> Array:
	return net.get_tree().get_nodes_in_group("bugs")


# ------------------------------------------------------------------ sprays

## Host: one puff of the Tar Sprayer or Rust Duster from `origin` along `dir`.
static func spray(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, level: int) -> void:
	var reach := Gun.range_for(def.id, level) * WeaponMods.mult(def.id, level, "radius")
	var k := effect_k(def, level)
	for b: Object in Zones.in_cone(_bugs(net), origin, dir, SPRAY_HALF_ANGLE, reach):
		var st: BugStatus = b.get("status")
		match def.special:
			&"tar":
				st.tar(slow_with(TAR_BOSS_SLOW if Zones.is_boss(b) else TAR_SLOW, minf(k, 1.5)), TAR_TIME * k)
			&"rust":
				st.strip(RUST_TIME * k * (RUST_BOSS if Zones.is_boss(b) else 1.0))
	var now := Time.get_ticks_msec()
	if now - int(net.get_meta(&"sec_puff_ms", -100000)) >= PUFF_FX_MS:
		net.set_meta(&"sec_puff_ms", now)
		net.armory_fx.rpc(&"sec_tar" if def.special == &"tar" else &"sec_rust", origin, dir, reach)


# ------------------------------------------------------------------ impacts

## Host: once per shot, where the first ray stopped (see ArmoryEffects.impact).
static func impact(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, normal: Vector3,
		hit: Dictionary, level: int) -> void:
	var src := net.player.display_name()
	var cliff := net.player.cliff_id
	var at := point + normal * 0.15
	match def.special:
		&"scream":
			_scream(net, def, at, normal, level, src, cliff)
		&"flash":
			_flash(net, def, at, normal, level, src, cliff)
		&"pepper":
			_pepper(net, def, at, normal, level, src, cliff)
		&"concuss":
			_concuss(net, def, origin, dir, level, src, cliff)
		&"chain":
			_chain(net, def, origin, dir, point, hit, level, src, cliff)
		&"lure":
			var spot := _landing(net, at, normal, hit)
			var t := LURE_TIME * effect_k(def, level)
			zones(net).add_lure(spot[0], LURE_RADIUS * radius_k(def, level), t)
			net.armory_fx.rpc(&"sec_lure", spot[0], spot[1], t)
		&"caltrops":
			var spot := _landing(net, at, normal, hit)
			var r := CALTROP_RADIUS * radius_k(def, level)
			var t := CALTROP_TIME * effect_k(def, level)
			var most := Zones.CALTROP_MAX + WeaponMods.add(def.id, level, "patches")
			var lifted := zones(net).add_caltrops(spot[0], spot[1], r, Gun.damage_for(def.id, level), t,
					net.get_instance_id(), src, cliff, most)
			for c in lifted:
				net.armory_fx.rpc(&"sec_caltrops_clear", c, Vector3.ZERO, 0.0)
			net.armory_fx.rpc(&"sec_caltrops", spot[0], (spot[1] as Vector3) * r, t)
		&"phosphor":
			var spot := _landing(net, at, normal, hit)
			var r := PHOSPHOR_RADIUS * radius_k(def, level)
			var t := PHOSPHOR_TIME * effect_k(def, level)
			zones(net).add_fire(spot[0], spot[1], r, Gun.damage_for(def.id, level), t, src, cliff)
			net.armory_fx.rpc(&"sec_phosphor", spot[0], (spot[1] as Vector3) * r, t)


## Where a lure, canister or grenade comes to rest: [point, surface normal]. A
## shot that flew to full range drops to whatever is under the end of it.
static func _landing(net: PlayerNet, at: Vector3, normal: Vector3, hit: Dictionary) -> Array:
	if not hit.is_empty() and normal.length() > 0.01:
		return [at, normal.normalized()]
	var down := net.player.gun.raycast(at, Vector3.DOWN, [net.player.get_rid()], DROP_REACH)
	if down.is_empty():
		return [at, Vector3.UP]
	return [(down["position"] as Vector3) + (down["normal"] as Vector3) * 0.1, (down["normal"] as Vector3).normalized()]


## Damage from a burst (no direct hit), from the burst point outward.
static func _hurt(b: Object, dmg: float, from: Vector3, src: String, cliff: int) -> void:
	if dmg <= 0.0 or not Zones.hittable(b):
		return
	var p := Zones.pos_of(b)
	(b as Bug).receive_hit(dmg, p, (p - from).normalized(), false, 1.0, src, cliff)


## Screamer Pistol: every bug in the radius takes a little and flees outward in a
## panic (climbers sideways along the wall and a little down). Bosses only take the damage.
static func _scream(net: PlayerNet, def: WeaponDef, at: Vector3, normal: Vector3, level: int, src: String,
		cliff: int) -> void:
	var r := SCREAM_RADIUS * radius_k(def, level)
	var t := SCREAM_TIME * effect_k(def, level)
	var z := zones(net)
	for b: Object in Zones.in_radius(_bugs(net), at, r):
		_hurt(b, Gun.damage_for(def.id, level), at, src, cliff)
		if Zones.is_boss(b):
			continue
		scatter(z, b, at, t)
	net.armory_fx.rpc(&"sec_scream", at, normal, r)


## One bug scattered from `at` for `seconds` (the zones node shoves it).
static func scatter(z: Zones, b: Object, at: Vector3, seconds: float) -> void:
	var k := SCATTER_HEAVY if Zones.is_heavy(b) else 1.0
	match Zones.where(b):
		Zones.Where.WALL:
			var side := Zones.away_lane(float(b.get("lane_z")), Zones.lane_of.call(int(b.get("cliff_id")), at))
			z.add_drift(b, Vector2(side * SCATTER_WALL * k, -SCATTER_DOWN), Vector3.ZERO, seconds)
		Zones.Where.GROUND:
			z.add_drift(b, Vector2.ZERO, Zones.away_flat(Zones.pos_of(b), at) * SCATTER_GROUND * k, seconds)
		Zones.Where.AIR:
			var out := Zones.pos_of(b) - at
			out.y = maxf(out.y, 0.0)
			out = out.normalized() if out.length() > Zones.EPS else Vector3.UP
			z.add_drift(b, Vector2.ZERO, out * SCATTER_GROUND * k, seconds)
		_:
			return
	(b.get("status") as BugStatus).slow(SCATTER_SLOW, seconds)


## Flashbang: everything in the radius is stunned (rooted) where it stands.
static func _flash(net: PlayerNet, def: WeaponDef, at: Vector3, normal: Vector3, level: int, src: String,
		cliff: int) -> void:
	var r := FLASH_RADIUS * radius_k(def, level)
	var k := effect_k(def, level)
	for b: Object in Zones.in_radius(_bugs(net), at, r):
		_hurt(b, Gun.damage_for(def.id, level), at, src, cliff)
		if Zones.hittable(b):
			(b.get("status") as BugStatus).stun(FLASH_BOSS_TIME if Zones.is_boss(b) else FLASH_TIME * k)
	net.armory_fx.rpc(&"sec_flash", at, normal, r)


## Pepper-Bomb: bugs in the cloud go berserk. Climbers use the Queen's Bell
## frenzy (they bite their neighbours on the wall); ground bugs and fliers slow
## to a thrash and go for the nearest bug (the zones node). Not bosses.
static func _pepper(net: PlayerNet, def: WeaponDef, at: Vector3, normal: Vector3, level: int, src: String,
		cliff: int) -> void:
	var r := PEPPER_RADIUS * radius_k(def, level)
	var t := PEPPER_TIME * effect_k(def, level)
	for b: Object in Zones.in_radius(_bugs(net), at, r):
		_hurt(b, Gun.damage_for(def.id, level), at, src, cliff)
		if Zones.is_boss(b):
			continue
		var bug := b as Bug
		match Zones.where(b):
			Zones.Where.WALL:
				bug.frenzy(t, src, cliff)
			Zones.Where.GROUND, Zones.Where.AIR:
				bug.status.slow(Zones.BERSERK_SLOW, t)
				bug.status.frenzy(t)
				zones(net).add_berserk(b, AmberRules.frenzy_dps(bug.def.breach_dps, bug.def.size), t, src, cliff)
				bug.show_frenzy.rpc(t)
	net.armory_fx.rpc(&"sec_pepper", at, normal, r)


## Concussion Pistol: a blank charge in a cone. Small climbers are knocked off the
## wall (fall damage, climb again), heavies slip down; ground bugs and fliers
## tumble back along the shot. Bosses stand firm.
static func _concuss(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, level: int, src: String,
		cliff: int) -> void:
	var reach := Gun.range_for(def.id, level) * WeaponMods.mult(def.id, level, "radius")
	var k := effect_k(def, level)
	var z := zones(net)
	for b: Object in Zones.in_cone(_bugs(net), origin, dir, CONCUSS_HALF_ANGLE, reach):
		if Zones.is_boss(b):
			continue
		var heavy := Zones.is_heavy(b)
		match Zones.where(b):
			Zones.Where.WALL:
				if heavy:
					b.set("climb_y", maxf(float(b.get("climb_y")) - CONCUSS_HEAVY_SLIP * k, 0.0))
				else:
					(b as Bug).knock_off(src, cliff)
			Zones.Where.GROUND:
				var flat := Vector3(dir.x, 0.0, dir.z)
				flat = flat.normalized() if flat.length() > Zones.EPS else Zones.away_flat(Zones.pos_of(b), origin)
				z.add_drift(b, Vector2.ZERO, concuss_push(flat, heavy, k), CONCUSS_PUSH_TIME)
			Zones.Where.AIR:
				z.add_drift(b, Vector2.ZERO, concuss_push(dir, heavy, k), CONCUSS_PUSH_TIME)
	net.armory_fx.rpc(&"sec_concuss", origin + dir * 0.8, dir, reach)


## The knock-back velocity (m/s, over CONCUSS_PUSH_TIME) along `dir` (unit).
static func concuss_push(dir: Vector3, heavy: bool, k: float = 1.0) -> Vector3:
	return dir * CONCUSS_PUSH * k * (CONCUSS_HEAVY_PUSH if heavy else 1.0) / CONCUSS_PUSH_TIME


## Chain Binder: the hitscan struck the first bug; the chain threads up to three
## more along the same line (no further than the rock it stopped on), hits each
## and binds them all where they stand.
static func _chain(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, hit: Dictionary,
		level: int, src: String, cliff: int) -> void:
	var reach := Gun.range_for(def.id, level)
	var bound: Array = []
	var first: Bug = null
	if not hit.is_empty():
		var hb := hit["collider"] as Hitbox
		first = hb.target as Bug if hb != null else null
		if first != null and is_instance_valid(first) and first.is_alive():
			bound.append(first)
		elif first == null:
			reach = minf(reach, origin.distance_to(point) + 0.5) # stopped on rock: the chain does too
	var more := Zones.along_line(_bugs(net), origin, dir, reach, CHAIN_WIDTH, CHAIN_COUNT - bound.size(), [first])
	var dmg := Gun.damage_for(def.id, level)
	for b: Object in more:
		var p := Zones.pos_of(b)
		(b as Bug).receive_hit(dmg, p, dir, Gun.pierce_for(def.id, level), 1.0, src, cliff)
		if Zones.hittable(b):
			bound.append(b)
	if bound.is_empty():
		return
	bound.sort_custom(func(x: Object, y: Object) -> bool:
		return (Zones.pos_of(x) - origin).dot(dir) < (Zones.pos_of(y) - origin).dot(dir))
	var t := CHAIN_TIME * effect_k(def, level)
	for b: Object in bound:
		(b.get("status") as BugStatus).root(CHAIN_BOSS_TIME if Zones.is_boss(b) else t)
	if bound.size() == 1:
		var p := Zones.pos_of(bound[0])
		net.armory_fx.rpc(&"sec_chain", p - dir * 0.9, p + dir * 0.9, t)
		return
	for i in bound.size() - 1:
		net.armory_fx.rpc(&"sec_chain", Zones.pos_of(bound[i]), Zones.pos_of(bound[i + 1]), t)
