class_name HeavyRules
extends RefCounted
## The universal crop-loaded heavies (Nov 2026 heavy weapons handoff): ten base
## designs in the heavy slot that fire whatever crop sack you load into them.
## The crop decides what each hit does (CropEffects' nine effects, HeavyCrop on
## the host); the gun decides how it gets there (WeaponDef.special):
##   uh_mortar     Crop Mortar: a shell lobbed in a high arc, a 4 m blast
##   uh_cannon     Hand Cannon: one enormous armour-piercing round
##   uh_spray      Crop Sprayer: a 45 deg, 12 m cone, every bug in it
##   uh_spike      Spike Driver: a spike into the wall, a shockwave across it, climbers knocked off
##   uh_drum       Drum Launcher: grenades in a lower, quicker arc, 2.5 m blasts
##   uh_gatling    Harvest Gatling: cranked fire, spread widening as it heats
##   uh_crossbow   Crop Crossbow: a visible bolt that flies, then hits
##   uh_bola       Bola Launcher: wraps one bug (held fast), clips one or two beside it
##   uh_keg        Powder Keg Launcher: sticky kegs, a fuse or a bug close by sets them off
##   uh_shot       Crop Blunderbuss: twenty pellets in a wide fan
## One sack (CropDef.load_item, from the cliff's shared ammo stores) fills the
## gun (WeaponDef.mag_size shots). Shots stay in it between waves, and a
## dropped gun keeps them. Loading a different crop throws the rest away.
## Pure maths and numbers only (the tests load this without the game).

## The host helper (projectiles in flight, kegs) and the visuals, loaded by path.
const HOST_PATH := "res://scenes/fx/heavy_host.gd"
const HOST_NAME := "HeavyHost"

const SPECIALS: Array[StringName] = [&"uh_mortar", &"uh_cannon", &"uh_spray", &"uh_spike", &"uh_drum", &"uh_gatling",
	&"uh_crossbow", &"uh_bola", &"uh_keg", &"uh_shot"]
## The seven older crop-fed heavies, archived (D:/DustAndMandibles-archive/retired/weapons):
## an old save that still holds one is paid back its price.
const ARCHIVED_PRICES: Dictionary = {&"mortar_tube": 80, &"fire_lance": 70, &"organ_gun": 110, &"harpoon_ballista": 90,
	&"acid_drencher": 75, &"congreve_rocket": 100, &"bear_trap_launcher": 85}

## The ten guns, in gunsmith order.
const IDS: Array[StringName] = [&"crop_mortar", &"hand_cannon", &"crop_sprayer", &"spike_driver", &"drum_launcher",
	&"harvest_gatling", &"crop_crossbow", &"bola_launcher", &"powder_keg_launcher", &"crop_blunderbuss"]

## Each crop's colour on a heavy: its ring, its shots, its bursts (the handoff's table).
const COLORS: Dictionary = {&"corn": Color("#FFD23F"), &"firecracker_chili": Color("#FF5533"),
	&"prickly_pear": Color("#5DAA3E"), &"cotton": Color("#E8E0D4"), &"herbs": Color("#7FAD71"),
	&"sulfur_root": Color("#C4B014"), &"barrel_cactus": Color("#2E8B7A"), &"tumbleweed_vine": Color("#B8965A"),
	&"sarsaparilla": Color("#D4920B")}
## An empty gun's ring: dark brass.
const EMPTY_RING := Color("#5A4626")
## The HUD's low-ammo amber.
const LOW_AMBER := Color("#D4920B")

## Hold R this long with a heavy out and the crop wheel opens; a quicker tap
## reloads the last crop.
const WHEEL_HOLD := 0.28
## The last tenth of a sack: the counter pulses amber.
const LOW_SHARE := 0.1

## Hand Cannon: you walk a little slower carrying it; the Gatling halves your
## pace while it's cranking.
const CANNON_WALK := 0.95
const GATLING_WALK := 0.5

# ------------------------------------------------------------------ crop strength

## How strong each crop's effect is at each upgrade (GunRarity: Common, then
## Uncommon = the handoff's Level 1, Rare = Level 2, and on in the same steps).
## A multiplier on CropEffects' base number for that crop.
const CROP_STEPS: Dictionary = {
	&"corn": [1.0, 1.1, 1.2, 1.3, 1.4], # ricochet share 50 / 55 / 60%
	&"firecracker_chili": [1.0, 1.15, 1.3, 1.45, 1.6], # splash radius
	&"prickly_pear": [1.0, 1.1, 1.2, 1.3, 1.4], # armour ignored 50 / 55 / 60%
	&"cotton": [1.0, 1.12, 1.2, 1.28, 1.36], # slow 25 / 28 / 30%
	&"herbs": [1.0, 1.15, 1.3, 1.45, 1.6], # poison a tick
	&"sulfur_root": [1.0, 1.1, 1.2, 1.3, 1.4], # burst 30 / 33 / 36% of max HP
	&"barrel_cactus": [1.0, 1.1, 1.2, 1.3, 1.4], # stagger 0.5 / 0.55 / 0.6 s
	&"tumbleweed_vine": [1.0, 1.1333, 1.3333, 1.4667, 1.6], # root chance 15 / 17 / 20%
	&"sarsaparilla": [1.0, 1.1, 1.25, 1.35, 1.45], # mark +20 / 22 / 25%
}


static func crop_strength(crop: StringName, rarity: int) -> float:
	var steps: Array = CROP_STEPS.get(crop, [1.0])
	return float(steps[clampi(rarity, 0, steps.size() - 1)])


static func color_of(crop: StringName) -> Color:
	return COLORS.get(crop, EMPTY_RING)


## The crop a hotbar item (slots 4-6: carried harvest) stands for, so picking it
## and then pressing R on a heavy loads that crop's sack (&"" if none).
static func crop_of_item(item: StringName) -> StringName:
	var c: StringName = {&"chili": &"firecracker_chili"}.get(item, item)
	return c if CROPS.has(c) else &""


## Is `id` one of the universal crop-loaded heavies?
static func is_heavy(id: StringName) -> bool:
	return IDS.has(id)


static func handles(special: StringName) -> bool:
	return SPECIALS.has(special)


## Is a gun with `left` of `full` shots in the low-ammo pulse?
static func is_low(left: int, full: int) -> bool:
	return full > 0 and left > 0 and float(left) <= ceilf(full * LOW_SHARE)


## What loading `crop` into a gun holding `held` with `left` shots does: the
## shots it then has (`full`) and how many were thrown away (a different crop,
## or the rest of the same one: a fresh sack replaces what's in it).
static func load_result(held: StringName, left: int, crop: StringName, full: int) -> Dictionary:
	return {"shots": full, "lost": left if held != &"" else 0, "swap": held != &"" and held != crop}


## Walk speed share with this gun in hand (`spin` the gatling's wind-up 0..1).
static func walk_mult(id: StringName, spin: float) -> float:
	if id == &"hand_cannon":
		return CANNON_WALK
	if id == &"harvest_gatling" and spin > 0.05:
		return GATLING_WALK
	return 1.0

# ------------------------------------------------------------------ the guns' numbers

## Crop Mortar: blast radius, the shortest lob, damage at the edge.
const MORTAR_RADIUS := 4.0
const MORTAR_MIN := 8.0
const MORTAR_EDGE := 0.5
const MORTAR_FLIGHT := Vector2(1.1, 2.2)
## Cluster Shell mod: bomblets, their damage share and radius, how far they scatter.
const CLUSTER_COUNT := 3
const CLUSTER_SHARE := 0.4
const CLUSTER_RADIUS := 2.0
const CLUSTER_SCATTER := 2.6

## Hand Cannon: unsteadied it sways (a small spread, none when aimed or with Rifled Bore).
const CANNON_SWAY_DEG := 1.6

## Crop Sprayer: the cone's full angle (the Wider Nozzle / Concentrated Mix mods add or take degrees).
const SPRAY_CONE := 45.0

## Spike Driver: the spike's speed, shockwave and knock-off radii, shockwave damage share.
const SPIKE_SPEED := 140.0
const SPIKE_WAVE := 5.0
const SPIKE_KNOCK := 3.0
const SPIKE_WAVE_SHARE := 0.5
## Resonant Spike mod: a second pulse this long after the first, at this share.
const SPIKE_PULSE_DELAY := 1.0
const SPIKE_PULSE_SHARE := 0.5
const SPIKE_LINGER := 3.0

## Drum Launcher: blast radius and edge; flight a little quicker and flatter than the mortar's.
const DRUM_RADIUS := 2.5
const DRUM_EDGE := 0.5
const DRUM_FLIGHT := Vector2(0.45, 1.1)

## Harvest Gatling: base spread, the most it widens to, and the rounds of steady fire it takes.
const GATLING_SPREAD := 3.0
const GATLING_SPREAD_MAX := 6.0
const GATLING_HEAT_ROUNDS := 75.0
## Heat bleeds off this many rounds' worth a second off the trigger.
const GATLING_COOL := 40.0

## Crop Crossbow: bolt speed, the aim zoom, how long a bolt stays stuck in.
const BOLT_SPEED := 170.0
const CROSSBOW_ZOOM := 2.5
const BOLT_LINGER := 3.0
## Broadhead Tips mod: the bleed's damage over its time.
const BLEED_DAMAGE := 30.0
const BLEED_TIME := 3.0

## Bola Launcher: flight speed, hold time (bosses resist), adjacent reach and how many it clips.
const BOLA_SPEED := 60.0
const BOLA_HOLD := 1.5
const BOLA_HOLD_BOSS := 0.5
const BOLA_SIDE_SHARE := 0.5
const BOLA_SWING := 3.0
const BOLA_CLIPS := 2

## Powder Keg Launcher: blast, edge, the fuse, the bug-close trigger, how many,
## how long one waits, how close a bug must be when it lands to light the fuse.
const KEG_RADIUS := 3.0
const KEG_EDGE := 0.5
const KEG_FUSE := 2.0
const KEG_PROX := 1.5
const KEG_CAP := 8
const KEG_LIFE := 60.0
const KEG_LIGHT_NEAR := 8.0
const KEG_FLIGHT := Vector2(0.5, 1.2)

## Crop Blunderbuss: pellets that hit rock bounce on with Scatter Bore, at this share.
const SCATTER_BOUNCE_SHARE := 0.6

## The ten guns' gunsmith mods (WeaponMods.list falls back to this table). fx keys
## beyond WeaponMods' own: cone (deg added), wave/knock/swing (m added), clips
## (added), cluster/pulse/bleed/steady/bounce (flags), keg_life/fuse/prox/boss_hold (multipliers).
const MODS: Dictionary = {
	&"crop_mortar": [
		{"name": "Extended Tube", "desc": "+30% range, a tighter blast: +15% damage in the middle, 20% smaller.", "cost": 20,
			"fx": {"range": 1.3, "damage": 1.15, "radius": 0.8}},
		{"name": "Cluster Shell", "desc": "Each shell splits into three bomblets where it lands (40% damage, 2 m each).", "cost": 25,
			"fx": {"cluster": true}},
		{"name": "Quick Breach", "desc": "Shells and sacks go in 35% faster.", "cost": 20, "fx": {"reload": 0.65, "fire_interval": 0.65}},
	],
	&"hand_cannon": [
		{"name": "Rifled Bore", "desc": "No sway even from the hip, and +20% range.", "cost": 30, "fx": {"steady": true, "range": 1.2}},
		{"name": "Hollow Charge", "desc": "+25% damage.", "cost": 35, "fx": {"damage": 1.25}},
		{"name": "Percussion Cap", "desc": "Reloads 30% faster.", "cost": 25, "fx": {"reload": 0.7}},
	],
	&"crop_sprayer": [
		{"name": "Wider Nozzle", "desc": "A 60 degree fan, 2 m shorter.", "cost": 15, "fx": {"cone": 15, "range": 0.8333}},
		{"name": "Double Pump", "desc": "Pumps nearly twice as fast.", "cost": 20, "fx": {"fire_interval": 0.5833}},
		{"name": "Concentrated Mix", "desc": "+40% damage in a 35 degree fan.", "cost": 20, "fx": {"damage": 1.4, "cone": -10}},
	],
	&"spike_driver": [
		{"name": "Deeper Bore", "desc": "The shockwave runs 2 m further and shakes bugs loose 1 m further.", "cost": 25,
			"fx": {"wave": 2, "knock": 1}},
		{"name": "Quick Chamber", "desc": "Reloads 35% faster.", "cost": 30, "fx": {"reload": 0.65, "fire_interval": 0.65}},
		{"name": "Resonant Spike", "desc": "A second, weaker shockwave a second later catches the ones that held on.", "cost": 25,
			"fx": {"pulse": true}},
	],
	&"drum_launcher": [
		{"name": "Rifled Tubes", "desc": "+25% range, a tighter blast with more in the middle.", "cost": 20,
			"fx": {"range": 1.25, "radius": 0.8, "damage": 1.15}},
		{"name": "Heavy Charges", "desc": "+30% damage.", "cost": 25, "fx": {"damage": 1.3}},
		{"name": "Speed Loader", "desc": "Reloads 30% faster, and the drum turns quicker between shots.", "cost": 20,
			"fx": {"reload": 0.7, "fire_interval": 0.75}},
	],
	&"harvest_gatling": [
		{"name": "Extra Barrels", "desc": "Six barrels: fires 25% faster, a little longer to wind up.", "cost": 25,
			"fx": {"fire_interval": 0.8, "spin_up": 1.25}},
		{"name": "Tightened Crank", "desc": "40% less spread, and it widens less.", "cost": 20, "fx": {"spread": 0.6}},
		{"name": "Heavy Rounds", "desc": "+35% damage, fires 15% slower.", "cost": 30, "fx": {"damage": 1.35, "fire_interval": 1.15}},
	],
	&"crop_crossbow": [
		{"name": "Longer Arms", "desc": "+30% range and +15% damage.", "cost": 20, "fx": {"range": 1.3, "damage": 1.15}},
		{"name": "Quick Winch", "desc": "Draws 30% faster.", "cost": 25, "fx": {"fire_interval": 0.714}},
		{"name": "Broadhead Tips", "desc": "Bolts make bugs bleed: 30 more damage over 3 seconds.", "cost": 20, "fx": {"bleed": true}},
	],
	&"bola_launcher": [
		{"name": "Heavier Weights", "desc": "Holds 2 seconds, +20% damage, bosses held a little longer.", "cost": 25,
			"fx": {"effect": 1.3333, "damage": 1.2, "boss_hold": 1.5}},
		{"name": "Wider Swing", "desc": "Clips up to three bugs as far as 5 m away.", "cost": 20, "fx": {"swing": 2, "clips": 1}},
		{"name": "Quick Drum", "desc": "Fires 30% faster and reloads 25% faster.", "cost": 20, "fx": {"fire_interval": 0.7, "reload": 0.75}},
	],
	&"powder_keg_launcher": [
		{"name": "Sticky Tar", "desc": "Kegs wait twice as long, and their fuse is shorter.", "cost": 20, "fx": {"keg_life": 2.0, "fuse": 0.75}},
		{"name": "Big Barrels", "desc": "+25% blast radius and +20% damage, a little slower to fire.", "cost": 25,
			"fx": {"radius": 1.25, "damage": 1.2, "fire_interval": 1.3}},
		{"name": "Hair Trigger", "desc": "A bug 3 m away sets a keg off, and fuses burn in a second.", "cost": 20, "fx": {"prox": 2.0, "fuse": 0.5}},
	],
	&"crop_blunderbuss": [
		{"name": "Tighter Choke", "desc": "A 12 degree spread that carries 10 m further.", "cost": 20, "fx": {"spread": 0.6, "range": 1.2}},
		{"name": "Double Load", "desc": "Thirty pellets (a little lighter each) and a quicker second blast.", "cost": 30,
			"fx": {"pellets": 10, "damage": 0.8333, "fire_interval": 0.75}},
		{"name": "Scatter Bore", "desc": "A 30 degree spread, and pellets that hit rock bounce on.", "cost": 20, "fx": {"spread": 1.5, "bounce": true}},
	],
}


## The mods' own fx: product of a multiplier key fitted on `code` (1 if none).
static func mod_mult(id: StringName, code: int, key: String) -> float:
	var m := 1.0
	var mods: Array = MODS.get(id, [])
	for i in mods.size():
		var fx: Dictionary = mods[i]["fx"]
		if (code >> (2 + i)) & 1 == 1 and fx.has(key):
			m *= float(fx[key])
	return m


static func mod_add(id: StringName, code: int, key: String) -> float:
	var a := 0.0
	var mods: Array = MODS.get(id, [])
	for i in mods.size():
		var fx: Dictionary = mods[i]["fx"]
		if (code >> (2 + i)) & 1 == 1 and fx.has(key):
			a += float(fx[key])
	return a


static func mod_flag(id: StringName, code: int, key: String) -> bool:
	var mods: Array = MODS.get(id, [])
	for i in mods.size():
		var fx: Dictionary = mods[i]["fx"]
		if (code >> (2 + i)) & 1 == 1 and bool(fx.get(key, false)):
			return true
	return false


## Blast and shockwave radius multiplier from the mods ("radius").
static func radius_mult(id: StringName, code: int) -> float:
	return mod_mult(id, code, "radius")

# ------------------------------------------------------------------ arcs

## Where a lob lands: `point` (what the eye ray hit), pushed out to `min_dist`
## along the ground if it's too close to `from`.
static func lob_target(from: Vector3, point: Vector3, min_dist: float) -> Vector3:
	var flat := Vector3(point.x - from.x, 0.0, point.z - from.z)
	if flat.length() >= min_dist or min_dist <= 0.0:
		return point
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	return Vector3(from.x, point.y, from.z) + dir * min_dist


## Seconds a lob takes over `dist` m: `span` is (shortest, longest), `far` the range.
static func lob_flight(dist: float, span: Vector2, far: float) -> float:
	return lerpf(span.x, span.y, clampf(dist / maxf(far, 1.0), 0.0, 1.0))


## How high a lob peaks above the straight line (`high` for the mortar's tall arc).
static func lob_peak(dist: float, high: bool) -> float:
	return (8.0 + dist * 0.35) if high else (2.0 + dist * 0.12)


## A lob's position at `t` (0..1 of its flight).
static func lob_at(from: Vector3, to: Vector3, t: float, high: bool) -> Vector3:
	return from.lerp(to, t) + Vector3.UP * lob_peak(from.distance_to(to), high) * 4.0 * t * (1.0 - t)


## Share of a blast's damage `dist` m from its centre (`edge` at the rim, 0 past it).
static func blast_share(dist: float, radius: float, edge: float) -> float:
	if radius <= 0.0 or dist > radius:
		return 0.0
	return lerpf(1.0, edge, dist / radius)

# ------------------------------------------------------------------ cone

## Is `p` inside a cone of full angle `deg` and length `reach` from `origin` along `dir`?
static func in_cone(origin: Vector3, dir: Vector3, p: Vector3, deg: float, reach: float) -> bool:
	var to := p - origin
	var d := to.length()
	if d > reach or d < 0.01:
		return d <= 0.01
	return dir.normalized().dot(to / d) >= cos(deg_to_rad(deg * 0.5))


## The sprayer's cone with its mods.
static func spray_cone(code: int) -> float:
	return clampf(SPRAY_CONE + mod_add(&"crop_sprayer", code, "cone"), 10.0, 120.0)

# ------------------------------------------------------------------ spike

## Shockwave and knock-off radii for a Spike Driver's code.
static func spike_wave(code: int) -> float:
	return SPIKE_WAVE + mod_add(&"spike_driver", code, "wave")


static func spike_knock(code: int) -> float:
	return SPIKE_KNOCK + mod_add(&"spike_driver", code, "knock")

# ------------------------------------------------------------------ gatling

## The gatling's spread after `heat` rounds of steady fire (deg).
static func gatling_spread(heat: float, code: int) -> float:
	var k := mod_mult(&"harvest_gatling", code, "spread")
	return lerpf(GATLING_SPREAD, GATLING_SPREAD_MAX, clampf(heat / GATLING_HEAT_ROUNDS, 0.0, 1.0)) * k


## The extra wobble on top of the base spread (which Gun.shot_dirs adds), in deg.
static func gatling_extra(heat: float, code: int) -> float:
	return maxf(gatling_spread(heat, code) - GATLING_SPREAD * mod_mult(&"harvest_gatling", code, "spread"), 0.0)


## A direction `dir` wobbled up to `deg` degrees (uniform over the disc) with `rng`.
static func wobble(dir: Vector3, deg: float, rng: RandomNumberGenerator) -> Vector3:
	if deg <= 0.0:
		return dir.normalized()
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var right := d.cross(up).normalized()
	var real_up := right.cross(d).normalized()
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * tan(deg_to_rad(deg))
	return (d + right * cos(a) * r + real_up * sin(a) * r).normalized()

# ------------------------------------------------------------------ bola

## How long a wrapped bug is held.
static func bola_hold(is_boss: bool, code: int) -> float:
	var k := mod_mult(&"bola_launcher", code, "effect")
	if is_boss:
		return BOLA_HOLD_BOSS * mod_mult(&"bola_launcher", code, "boss_hold")
	return BOLA_HOLD * k


static func bola_swing(code: int) -> float:
	return BOLA_SWING + mod_add(&"bola_launcher", code, "swing")


static func bola_clips(code: int) -> int:
	return BOLA_CLIPS + int(mod_add(&"bola_launcher", code, "clips"))

# ------------------------------------------------------------------ kegs

static func keg_fuse(code: int) -> float:
	return KEG_FUSE * mod_mult(&"powder_keg_launcher", code, "fuse")


static func keg_prox(code: int) -> float:
	return KEG_PROX * mod_mult(&"powder_keg_launcher", code, "prox")


static func keg_life(code: int) -> float:
	return KEG_LIFE * mod_mult(&"powder_keg_launcher", code, "keg_life")


## Kegs: index of the keg to set off so a shooter with `owned` kegs (oldest
## first) can lay one more, or -1 while under the cap.
static func keg_to_pop(owned: int) -> int:
	return 0 if owned >= KEG_CAP else -1


## What a waiting keg does this tick: "boom" (fuse burnt, or a bug close), "gone"
## (waited too long) or "" (keeps waiting). `lit_for` < 0: its fuse isn't lit.
## Outside a wave a keg's wait clock doesn't run, so kegs laid in the build
## phase are there for the wave.
static func keg_tick(lit_for: float, fuse: float, waited: float, life: float, nearest_bug: float, prox: float) -> String:
	if nearest_bug <= prox:
		return "boom"
	if lit_for >= 0.0 and lit_for >= fuse:
		return "boom"
	if lit_for < 0.0 and waited >= life:
		return "gone"
	return ""

# ------------------------------------------------------------------ fx numbers

## The nine crops in CropEffects.IDS's order (kept here so this file needs nothing else).
const CROPS: Array[StringName] = [&"corn", &"firecracker_chili", &"prickly_pear", &"cotton", &"herbs",
	&"sulfur_root", &"barrel_cactus", &"tumbleweed_vine", &"sarsaparilla"]


## Packs a crop (index in CROPS, -1 none) and a small number (0..999)
## into one float for an fx rpc: crop + 1 in the thousands.
static func pack(crop: StringName, n: float) -> float:
	return float((CROPS.find(crop) + 1) * 1000) + clampf(n, 0.0, 999.0)


static func unpack_crop(x: float) -> StringName:
	var i := int(floorf(x / 1000.0)) - 1
	return CROPS[i] if i >= 0 and i < CROPS.size() else &""


static func unpack_n(x: float) -> float:
	return fposmod(x, 1000.0)
