class_name SpecialShotRules
extends RefCounted
## Host-side rules of the special shots (TurretDef.special) that TurretEffects
## applies: who a steam blast, flood or bola catches, and what it does to them.
## Kept free of autoloads and typed only loosely (any object with Bug's fields
## and methods), so tests can run them on stand-in bugs.

## Bosses only slip BOSS_SLIP metres, at most once every BOSS_SLIP_GAP seconds,
## whatever washes them (Water Cannon, Steam Cannon, Flood Gate share the gap),
## so control turrets can't hold a boss on the wall.
const BOSS_SLIP := 1.0
const BOSS_SLIP_GAP := 6.0
## Metres a heavy bug slips when a Water Cannon or Steam Cannon hits it.
const HEAVY_SLIP := 3.0

## Steam Cannon: half-angle of the scalding cone, and how hard and long it slows.
const STEAM_HALF_ANGLE_DEG := 9.0
const STEAM_SLOW := 0.5
const STEAM_SLOW_TIME := 3.0
## Bosses in the steam are only slowed this much.
const STEAM_BOSS_SLOW := 0.85

## Flood Gate: metres a heavy bug slips when the flood hits it, when the water
## reaches the far lip, and how fast the sheet runs down the wall (m/s).
const FLOOD_SLIP := 4.0
const FLOOD_ARRIVE := 0.55
const FLOOD_SPEED := 40.0

## Twin Mortar: the fire shell lands this far above the blast shell (the pack
## climbs up into it), and burns this much per second for this long at tier 0.
const TWIN_FIRE_ABOVE := 2.5
const TWIN_FIRE_DPS := 5.0
const TWIN_FIRE_TIME := 5.0
## Kill-feed source suffix of the fire shell (KillMethod counts it as fire).
const FIRE_SHELL := " Fire Shell"

## Bola Launcher: how far from the first bug the second bola may land, the share
## of the tangle time heavy bugs suffer, and bosses: a short tangle at most every gap.
const BOLA_REACH := 6.0
const BOLA_HEAVY := 0.6
const BOSS_BOLA := 1.0
const BOSS_BOLA_GAP := 6.0


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _heavy(b: Object) -> bool:
	return TurretDef.is_heavy(b.get("def") as BugDef)


static func _boss(b: Object) -> bool:
	return b.get("boss") != null


## Metres a heavy or boss bug slips when water hits it (0: a boss inside its gap).
static func slip_for(b: Object, heavy_slip: float = HEAVY_SLIP) -> float:
	if not _boss(b):
		return heavy_slip
	var now := _now()
	if now - float(b.get_meta(&"water_slip_t", -100.0)) < BOSS_SLIP_GAP:
		return 0.0
	b.set_meta(&"water_slip_t", now)
	return BOSS_SLIP


static func _slip(b: Object, heavy_slip: float) -> void:
	b.set("climb_y", maxf(float(b.get("climb_y")) - slip_for(b, heavy_slip), 0.0))


## Is `p` inside the cone from `muzzle` along `axis` (unit), within `reach` metres?
static func in_cone(muzzle: Vector3, axis: Vector3, p: Vector3, half_angle_deg: float, reach: float) -> bool:
	var to := p - muzzle
	var d := to.length()
	if d < 0.001:
		return true
	return d <= reach and axis.dot(to / d) >= cos(deg_to_rad(half_angle_deg))


## A steam blast on the climbers caught in its cone. The `knock` highest small
## bugs lose their grip and fall; heavy bugs slip (bosses a little, now and then)
## and everyone left on the wall is slowed. Returns how many were knocked off.
static func steam_wash(caught: Array, knock: int, source: String, source_cliff: int) -> int:
	var small: Array = caught.filter(func(b: Object) -> bool:
		return b.call("is_alive") and b.call("is_climbing") and not _boss(b) and not _heavy(b))
	small.sort_custom(func(a: Object, b: Object) -> bool: return float(a.get("climb_y")) > float(b.get("climb_y")))
	var falling: Array = small.slice(0, knock)
	for b: Object in falling:
		b.call("knock_off", source, source_cliff)
	for b: Object in caught:
		if not b.call("is_alive") or not b.call("is_climbing") or falling.has(b):
			continue
		if _boss(b) or _heavy(b):
			_slip(b, HEAVY_SLIP)
		b.get("status").call("slow", STEAM_BOSS_SLOW if _boss(b) else STEAM_SLOW, STEAM_SLOW_TIME)
	return falling.size()


## The climbers in a flood's band: within `half` metres of lane position `centre`.
static func flood_band(climbers: Array, centre: float, half: float) -> Array:
	return climbers.filter(func(b: Object) -> bool:
		return b.call("is_alive") and b.call("is_climbing") and absf(float(b.get("lane_z")) - centre) <= half)


## The flood hits these climbers: small bugs are washed off the wall, heavy bugs
## slip FLOOD_SLIP metres, bosses only a little and not every time. Returns how
## many were washed off.
static func flood_wash(caught: Array, source: String, source_cliff: int) -> int:
	var washed := 0
	for b: Object in caught:
		if not b.call("is_alive") or not b.call("is_climbing"):
			continue
		if _boss(b) or _heavy(b):
			_slip(b, FLOOD_SLIP)
		else:
			b.call("knock_off", source, source_cliff)
			washed += 1
	return washed


## Where the Twin Mortar's fire shell lands for a salvo aimed at `aim`.
static func twin_fire_point(aim: Vector3) -> Vector3:
	return aim + Vector3.UP * TWIN_FIRE_ABOVE


## The bugs one bola throw tangles: the target, then the nearest other climbers
## within BOLA_REACH of it that aren't held already, up to `count` in all.
## `pos` gives a bug's position (default: its global_position).
static func bola_pick(target: Object, climbers: Array, count: int, pos: Callable = Callable()) -> Array:
	if not pos.is_valid():
		pos = func(b: Object) -> Vector3: return b.get("global_position")
	var at: Vector3 = pos.call(target)
	var others: Array = climbers.filter(func(b: Object) -> bool:
		return b != target and b.call("is_alive") and b.call("is_climbing") and not b.get("status").call("is_rooted") \
				and (pos.call(b) as Vector3).distance_to(at) <= BOLA_REACH)
	others.sort_custom(func(a: Object, b: Object) -> bool:
		return (pos.call(a) as Vector3).distance_squared_to(at) < (pos.call(b) as Vector3).distance_squared_to(at))
	var out: Array = [target]
	out.append_array(others.slice(0, maxi(count - 1, 0)))
	return out


## Seconds a bola holds this bug: full for small bugs, less for heavy ones, and
## bosses only BOSS_BOLA, at most once every BOSS_BOLA_GAP seconds (0 = shrugged off).
static func bola_time(b: Object, seconds: float) -> float:
	if _boss(b):
		var now := _now()
		if now - float(b.get_meta(&"bola_t", -100.0)) < BOSS_BOLA_GAP:
			return 0.0
		b.set_meta(&"bola_t", now)
		return BOSS_BOLA
	return seconds * (BOLA_HEAVY if _heavy(b) else 1.0)
