class_name ArmoryHeavyRules
extends RefCounted
## Rules for the heavies' (and two primaries') specials (see ArmoryEffects):
##   mortar       Mortar Tube: a shell lobbed in a high arc, a 6 m blast where it lands
##   fire         Fire Lance: a 15 m flame cone, damage each puff plus a 4 s burn
##   ballista     Harpoon Ballista: a climber it hits is pinned to the cliff 3 s
##   acid         Acid Drencher: an 18 m cone; 2 s of spray strips a bug's armour 10 s
##   rocket       Congreve Rocket: flies straight, then curves to the nearest bug in 30 deg
##   beartrap     Bear Trap Launcher: traps on any surface; a bug crossing one is hurt and held
##   ricochet     Ricochet Rifle: off rock (or a heavy shell) once, 60% damage on the bounce
##   pierce_line  Trapdoor Springfield: through every bug in line
## The host-side work (bug loops, raycasts, delayed blasts, traps) lives in the
## host helper node (HOST_PATH), loaded at run time so these pure rules load in
## the tests without the game's autoloads. This file is only maths.

## The host helper node (one under the current scene, on the host).
const HOST_PATH := "res://scenes/fx/armory_heavy_host.gd"
const HOST_NAME := "ArmoryHeavyHost"

## The specials these rules handle (see ArmoryEffects.HEAVY).
const HANDLED: Array[StringName] = [&"mortar", &"fire", &"ballista", &"acid", &"rocket", &"beartrap", &"ricochet",
	&"pierce_line"]

## Effect strength (radius, duration) grows this much per rarity level.
const SCALE_PER_LEVEL := 0.1

## Mortar Tube: blast radius, flight time range (short and long lobs), the
## distance a full-length lob covers, and the edge of the blast's damage.
const MORTAR_RADIUS := 6.0
const MORTAR_FLIGHT_MIN := 0.9
const MORTAR_FLIGHT_MAX := 1.6
const MORTAR_FLIGHT_FAR := 200.0
## Blast damage at the edge of the radius, as a share of the centre's.
const BLAST_EDGE := 0.4

## Fire Lance: cone half-angle, the burn's damage per second (Common) and length.
const FIRE_HALF_ANGLE := 20.0
const FIRE_BURN_DPS := 8.0
const FIRE_BURN_TIME := 4.0

## Acid Drencher: cone half-angle, seconds of spray that strip armour, how long
## it stays stripped, and how exposure fades between puffs (grace, then per second).
const ACID_HALF_ANGLE := 20.0
const ACID_STRIP_AFTER := 2.0
const ACID_STRIP_TIME := 10.0
const ACID_GRACE := 0.45
const ACID_DECAY := 1.0

## Harpoon Ballista: pin time on a climber (bosses shrug it off sooner).
const BALLISTA_PIN := 3.0
const BALLISTA_PIN_BOSS := 1.0
## How long a bolt stays stuck in rock (seconds, visual only).
const BALLISTA_WALL_LINGER := 4.0

## Congreve Rocket: speed, the straight first leg (seconds), lock-on cone, blast.
const ROCKET_SPEED := 70.0
const ROCKET_STRAIGHT := 0.5
const ROCKET_LOCK_DEG := 30.0
const ROCKET_RADIUS := 5.0
## A homing rocket bursts on its bug if it is still this close to where it aimed.
const ROCKET_FOLLOW := 10.0

## Bear Trap Launcher: trigger reach, hold time (bosses sooner), traps per shooter.
const TRAP_REACH := 1.3
const TRAP_ROOT := 3.0
const TRAP_ROOT_BOSS := 1.0
const TRAP_CAP := 6

## Ricochet Rifle: damage share on the bounce.
const RICOCHET_MULT := 0.6
## Trapdoor Springfield: most bugs one bullet goes through (after the first).
const PIERCE_MAX := 6

## Direction packing for the rocket's fx number (yaw and pitch steps).
const PACK_YAW := 1024
const PACK_PITCH := 512


## Host: one puff of the Fire Lance or Acid Drencher.
static func spray(net: Node, def: WeaponDef, origin: Vector3, dir: Vector3, level: int) -> void:
	var h := host(net)
	if h != null:
		h.call("spray", net, def, origin, dir, level)


## Host: what a heavy's shot does where the first ray stopped (see ArmoryEffects.impact).
static func impact(net: Node, def: WeaponDef, origin: Vector3, dir: Vector3, point: Vector3, normal: Vector3,
		hit: Dictionary, level: int) -> void:
	var h := host(net)
	if h != null:
		h.call("impact", net, def, origin, dir, point, normal, hit, level)


## Does this file handle `special`?
static func handled(special: StringName) -> bool:
	return HANDLED.has(special)


## The host helper under the current scene (made the first time it's needed).
static func host(net: Node) -> Node:
	if net == null or not net.is_inside_tree():
		return null
	var scene := net.get_tree().current_scene
	if scene == null:
		return null
	var h := scene.get_node_or_null(HOST_NAME)
	if h != null and not h.is_queued_for_deletion():
		return h
	var script := load(HOST_PATH) as GDScript
	if script == null:
		return null
	h = script.new() as Node
	h.name = HOST_NAME
	scene.add_child(h)
	return h


## Rarity's share of the effect strength for a gun's packed code (rarity 0..4).
static func rarity_scale(level: int) -> float:
	return 1.0 + SCALE_PER_LEVEL * WeaponMods.level(level)


## Duration multiplier (burn, pin, strip, trap hold): rarity and the "effect" mods.
static func effect_scale(id: StringName, level: int) -> float:
	return rarity_scale(level) * WeaponMods.mult(id, level, "effect")


## Size multiplier (blast radii, spray reach): rarity and the "radius" mods.
static func radius_scale(id: StringName, level: int) -> float:
	return rarity_scale(level) * WeaponMods.mult(id, level, "radius")


## Fire Lance burn length for a gun.
static func burn_time(id: StringName, level: int) -> float:
	return FIRE_BURN_TIME * effect_scale(id, level)


## Where a heavy's projectile seems to leave from, given the eye ray.
static func muzzle_from(origin: Vector3, dir: Vector3) -> Vector3:
	return origin + dir * 0.8 + Vector3.DOWN * 0.25


# ------------------------------------------------------------------ blasts

## Mortar shell flight time over `dist` metres.
static func mortar_flight(dist: float) -> float:
	return lerpf(MORTAR_FLIGHT_MIN, MORTAR_FLIGHT_MAX, clampf(dist / MORTAR_FLIGHT_FAR, 0.0, 1.0))


## How high above the straight line a mortar shell's arc peaks.
static func mortar_peak(dist: float) -> float:
	return 10.0 + dist * 0.3


## Mortar shell position at `t` (0..1) of its arc from `from` to `to`.
static func mortar_at(from: Vector3, to: Vector3, t: float) -> Vector3:
	return from.lerp(to, t) + Vector3.UP * mortar_peak(from.distance_to(to)) * 4.0 * t * (1.0 - t)


## Share of a blast's damage at `dist` from its centre (0 outside the radius).
static func blast_share(dist: float, radius: float) -> float:
	if radius <= 0.0 or dist > radius:
		return 0.0
	return lerpf(1.0, BLAST_EDGE, dist / radius)


# ------------------------------------------------------------------ sprays

## Is `p` inside the Fire Lance's flame cone?
static func in_flame(origin: Vector3, dir: Vector3, p: Vector3, reach: float) -> bool:
	return SpecialShotRules.in_cone(origin, dir.normalized(), p, FIRE_HALF_ANGLE, reach)


## Is `p` inside the Acid Drencher's cone?
static func in_acid(origin: Vector3, dir: Vector3, p: Vector3, reach: float) -> bool:
	return SpecialShotRules.in_cone(origin, dir.normalized(), p, ACID_HALF_ANGLE, reach)


## Fire Lance burn damage per second for a gun's rarity.
static func burn_dps(level: int) -> float:
	return FIRE_BURN_DPS * GunRarity.damage_mult(WeaponMods.level(level))


## A bug's acid exposure (seconds) after a puff `gap` seconds since its last
## one: it fades once the spray has been off it longer than ACID_GRACE, then
## the puff adds its own `puff` seconds.
static func acid_exposure(exposure: float, gap: float, puff: float) -> float:
	if gap > ACID_GRACE:
		exposure = maxf(exposure - (gap - ACID_GRACE) * ACID_DECAY, 0.0)
	return exposure + puff


## Has this much exposure eaten the armour away?
static func acid_strips(exposure: float) -> bool:
	return exposure >= ACID_STRIP_AFTER - 0.001


## How long the armour stays off at this rarity.
static func acid_strip_time(id: StringName, level: int) -> float:
	return ACID_STRIP_TIME * effect_scale(id, level)


# ------------------------------------------------------------------ pins and traps

## Harpoon Ballista: how long a pinned climber is stuck.
static func ballista_pin(is_boss: bool, id: StringName, level: int) -> float:
	return (BALLISTA_PIN_BOSS if is_boss else BALLISTA_PIN) * effect_scale(id, level)


## Bear trap: how long a caught bug is held.
static func trap_root(is_boss: bool, id: StringName, level: int) -> float:
	return (TRAP_ROOT_BOSS if is_boss else TRAP_ROOT) * effect_scale(id, level)


## Bear trap: does a bug `dist` from the trap (body radius `body_r`) step in it?
static func trap_catches(dist: float, body_r: float) -> bool:
	return dist <= TRAP_REACH + body_r * 0.5


## Traps clear when a wave ends (placed in the build phase, they wait for it).
static func traps_clear(was_wave: bool, is_wave: bool) -> bool:
	return was_wave and not is_wave


## Bear traps a shooter may have down: TRAP_CAP plus the gun's "traps" mods.
static func trap_cap(id: StringName, level: int) -> int:
	return TRAP_CAP + WeaponMods.add(id, level, "traps")


## Bear traps: index of the trap to remove so a shooter with `owned` traps (in
## placing order, oldest first) can lay one more under `cap`, or -1 if under it.
static func trap_to_evict(owned: int, cap: int = TRAP_CAP) -> int:
	return 0 if owned >= maxi(cap, 1) else -1


# ------------------------------------------------------------------ rocket

## Index in `positions` of the nearest point within ROCKET_LOCK_DEG of `dir`
## from `origin` and within `reach`, or -1.
static func rocket_pick(origin: Vector3, dir: Vector3, positions: Array[Vector3], reach: float) -> int:
	var best := -1
	var best_d := INF
	var axis := dir.normalized()
	var cos_lock := cos(deg_to_rad(ROCKET_LOCK_DEG))
	for i in positions.size():
		var to: Vector3 = positions[i] - origin
		var d := to.length()
		if d < 0.5 or d > reach or d >= best_d:
			continue
		if axis.dot(to / d) >= cos_lock:
			best = i
			best_d = d
	return best


## The rocket's flight: [start, end of the straight leg, curve control, end].
## Without a lock (`homing` false) it flies a straight line to `end`.
static func rocket_path(start: Vector3, dir: Vector3, end: Vector3, homing: bool) -> PackedVector3Array:
	var axis := dir.normalized()
	if not homing:
		return PackedVector3Array([start, start, start.lerp(end, 0.5), end])
	var leg := minf(ROCKET_SPEED * ROCKET_STRAIGHT, start.distance_to(end) * 0.5)
	var bend := start + axis * leg
	var control := bend + axis * (bend.distance_to(end) * 0.5)
	return PackedVector3Array([start, bend, control, end])


## Approximate length of a rocket path (straight leg plus the sampled curve).
static func rocket_length(path: PackedVector3Array) -> float:
	var total := path[0].distance_to(path[1])
	var prev := path[1]
	for i in range(1, 9):
		var p := _bezier(path[1], path[2], path[3], float(i) / 8.0)
		total += prev.distance_to(p)
		prev = p
	return total


## Seconds a rocket takes to fly its path.
static func rocket_flight(path: PackedVector3Array) -> float:
	return maxf(rocket_length(path) / ROCKET_SPEED, 0.05)


## Rocket position at `t` (0..1 of its flight time).
static func rocket_at(path: PackedVector3Array, t: float) -> Vector3:
	var leg := path[0].distance_to(path[1])
	var total := rocket_length(path)
	var split := leg / total if total > 0.001 else 0.0
	if t <= split and split > 0.0:
		return path[0].lerp(path[1], t / split)
	var u := (t - split) / maxf(1.0 - split, 0.001)
	return _bezier(path[1], path[2], path[3], clampf(u, 0.0, 1.0))


static func _bezier(a: Vector3, c: Vector3, b: Vector3, u: float) -> Vector3:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


## Mortar fx number: flight seconds (under 10) and blast radius in one float.
static func pack_blast(flight: float, radius: float) -> float:
	return float(roundi(radius * 10.0)) * 10.0 + clampf(flight, 0.0, 9.99)


## The flight time pack_blast packed.
static func blast_flight(x: float) -> float:
	return fposmod(x, 10.0)


## The radius pack_blast packed.
static func blast_radius(x: float) -> float:
	return floorf(x / 10.0) / 10.0


## Rocket fx number: its launch direction, plus 0.5 if it locked on.
static func pack_rocket(dir: Vector3, homing: bool) -> float:
	return pack_dir(dir) + (0.5 if homing else 0.0)


static func rocket_dir(x: float) -> Vector3:
	return unpack_dir(floorf(x))


static func rocket_homing(x: float) -> bool:
	return fposmod(x, 1.0) > 0.25


## A direction as one float (yaw and pitch steps), for an fx rpc's number.
static func pack_dir(dir: Vector3) -> float:
	var d := dir.normalized()
	var yaw := atan2(d.x, d.z) # -PI..PI
	var pitch := asin(clampf(d.y, -1.0, 1.0)) # -PI/2..PI/2
	var yq := clampi(roundi((yaw + PI) / TAU * (PACK_YAW - 1)), 0, PACK_YAW - 1)
	var pq := clampi(roundi((pitch + PI * 0.5) / PI * (PACK_PITCH - 1)), 0, PACK_PITCH - 1)
	return float(yq * PACK_PITCH + pq)


## The direction pack_dir packed.
static func unpack_dir(x: float) -> Vector3:
	var n := roundi(x)
	var yaw := float(floori(float(n) / PACK_PITCH)) / (PACK_YAW - 1) * TAU - PI
	var pitch := float(posmod(n, PACK_PITCH)) / (PACK_PITCH - 1) * PI - PI * 0.5
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


# ------------------------------------------------------------------ bullets

## Ricochet Rifle: the direction a round leaves a surface with `normal`.
static func bounce_dir(dir: Vector3, normal: Vector3) -> Vector3:
	if normal.length() < 0.01:
		return dir
	return dir.bounce(normal.normalized()).normalized()


## Ricochet Rifle: does the round bounce off what it hit (rock, or a heavy shell)?
static func bounces_off(hit_bug: bool, heavy_shell: bool) -> bool:
	return not hit_bug or heavy_shell
