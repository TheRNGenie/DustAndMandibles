class_name SitePlan
extends RefCounted
## Canyon Expeditions, the sites: which raid sites a run has on the canyon floor
## (picked from the map's bug tunnels by a run seed, nothing hand-placed), what
## loot each one holds after every refill, what sleeps there, the egg-smash cut
## to a tunnel's next wave and the railroad wreck's collapse clock. Pure logic
## (no nodes) so it can be unit-tested; SiteManager builds the world from it.

enum Kind { MOUTH, BONEYARD, CAMP, NEST, WRECK }
const KIND_IDS: Array[StringName] = [&"mouth", &"boneyard", &"camp", &"nest", &"wreck"]
const NAMES: Array[String] = ["Tunnel Mouth", "Bone Yard", "Old Survey Camp", "Bug Nest", "Railroad Wreck"]
## Map marker colours (overview map, compass).
const COLORS: Array[Color] = [Color("#C98A5A"), Color("#F2E3C2"), Color("#7BB0D8"), Color("#B6E06A"), Color("#E0A040")]

const MIN_SITES := 3
const MAX_SITES := 5
## Site centres stand this far out from their tunnel's mouth, and at least
## this far from each other.
const OUT_FROM_MOUTH := 9.0
const MIN_SEPARATION := 17.0
## How far a site's props and loot spread from its centre.
const RADIUS := 6.5
## A site may slide this far along its wall (either way) to clear a neighbour.
const SLIDES: Array[float] = [0.0, 3.5, -3.5, 6.0, -6.0]

## Egg smash: that tunnel sends this share of its bugs next wave.
const SMASH_KEEP := 0.8

## Railroad wreck: seconds of somebody inside before it creaks, then collapses.
const WRECK_WARN := 18.0
const WRECK_COLLAPSE := 28.0
## Unattended, the clock runs back down this much slower.
const WRECK_SETTLE := 0.5


class Site:
	extends RefCounted
	var index := 0
	var kind: int = Kind.MOUTH
	## Which of the map's bug tunnels it sits by.
	var tunnel := 0
	## Centre on the floor (y from the tunnel mouth; SiteManager drops it onto the ground).
	var pos := Vector3.ZERO
	## Horizontal way out of the tunnel (the site's local +Z).
	var out := Vector3.BACK
	var seed := 0

	func yaw() -> float:
		return atan2(out.x, out.z)

	func basis() -> Basis:
		return Basis(Vector3.UP, yaw())

	## World point at local (x across, z out from the wall) on the site's plane.
	func at(local: Vector2) -> Vector3:
		return pos + basis() * Vector3(local.x, 0.0, local.y)

	func kind_id() -> StringName:
		return KIND_IDS[kind]

	func display_name() -> String:
		return NAMES[kind]


# ------------------------------------------------------------------ generation

## A fresh run seed (host).
static func roll_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & 0x7FFFFFFF


## The run's sites: 3-5 of them, each by a different tunnel, every kind at most
## once. `tunnels` is [[mouth, out], ...] (CliffBuilder.tunnel(i)).
static func generate(tunnels: Array, run_seed: int) -> Array[Site]:
	var out: Array[Site] = []
	if tunnels.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "sites"])
	var want := clampi(MIN_SITES + rng.randi_range(0, MAX_SITES - MIN_SITES), 1, tunnels.size())
	var order: Array[int] = []
	for i in tunnels.size():
		order.append(i)
	_shuffle(order, rng)
	var kinds: Array[int] = [Kind.MOUTH, Kind.BONEYARD, Kind.CAMP, Kind.NEST, Kind.WRECK]
	_shuffle(kinds, rng)
	for ti: int in order:
		if out.size() >= want:
			break
		var t: Array = tunnels[ti]
		var mouth: Vector3 = t[0]
		var way: Vector3 = t[1]
		way.y = 0.0
		way = way.normalized() if way.length() > 0.01 else Vector3.BACK
		var kind := kinds[out.size() % kinds.size()]
		# The tunnel mouth site sits right in the mouth; the rest out on the floor,
		# slid along the wall if that clears a neighbour.
		var side := way.cross(Vector3.UP).normalized()
		var c := Vector3.INF
		for slide: float in ([0.0] if kind == Kind.MOUTH else SLIDES):
			var p := mouth + way * (4.5 if kind == Kind.MOUTH else OUT_FROM_MOUTH) + side * slide
			# Clear of the invisible walls at the canyon's ends (z +-90).
			var clear := absf(p.z) <= WorldLayout.WORLD_HALF_Z - RADIUS - 1.5
			for s in out:
				if Vector2(s.pos.x - p.x, s.pos.z - p.z).length() < MIN_SEPARATION:
					clear = false
					break
			if clear:
				c = p
				break
		if c == Vector3.INF:
			continue
		var site := Site.new()
		site.index = out.size()
		site.kind = kind
		site.tunnel = ti
		site.out = way
		site.seed = hash([run_seed, ti, site.kind])
		site.pos = c
		out.append(site)
	return out


## Every spot a site could take on this map (any seed): world dressing keeps
## clear of them so a site never lands in a hoodoo or a pile of webs.
static var _zones: Array[Vector3] = []


static func reserve_zones(tunnels: Array) -> void:
	_zones.clear()
	for t: Array in tunnels:
		var way: Vector3 = t[1]
		way.y = 0.0
		way = way.normalized() if way.length() > 0.01 else Vector3.BACK
		var side := way.cross(Vector3.UP).normalized()
		_zones.append((t[0] as Vector3) + way * 4.5)
		for slide: float in SLIDES:
			_zones.append((t[0] as Vector3) + way * OUT_FROM_MOUTH + side * slide)


static func in_site_zone(pos: Vector3, pad: float = 1.0) -> bool:
	for z in _zones:
		if Vector2(pos.x - z.x, pos.z - z.z).length() < RADIUS + pad:
			return true
	return false


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


# ------------------------------------------------------------------ loot

## One pickup at a site. `items` goes into the backpack as one lot; `walk`
## pickups are taken by walking over them, the rest with E.
class Loot:
	extends RefCounted
	var slot := 0
	var items: Dictionary = {}
	var label := ""
	## What it looks like: &"scrap", &"chitin", &"part", &"page", &"specimen",
	## &"egg", &"blueprint", &"trophy".
	var look: StringName = &"scrap"
	var walk := false
	## Local (x across, z out) in the site's frame.
	var local := Vector2.ZERO


## Items that are new with expeditions (stockpile keys).
## (The key the expedition core's backpack weighs at 2.)
const NEST_EGG := &"egg"
const SPECIMEN := &"specimen"
const JOURNAL_PAGE := &"journal_page"
const NEW_ITEMS: Array[StringName] = [NEST_EGG, SPECIMEN, JOURNAL_PAGE]


static func item_name(key: StringName) -> String:
	match key:
		NEST_EGG:
			return "Nest Egg"
		SPECIMEN:
			return "Specimen Jar"
		JOURNAL_PAGE:
			return "Journal Page"
		&"upgrade_token":
			return "Upgrade Token"
	if CraftTable.is_part(key):
		return CraftTable.part_name(key)
	return String(key).replace("_", " ").capitalize()


## Scrap and chitin on the floor beat what the cliff pays: these are per pile.
static func _scrap_pile(wave: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(14, 22) + 3 * wave


static func _chitin_pile(wave: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(4, 7) + wave / 2


## A rare part: mounts and barrels (the scarce kinds), never a load.
static func _rare_part(rng: RandomNumberGenerator) -> StringName:
	var keys: Array[StringName] = []
	for k: StringName in CraftTable.MOUNTS:
		keys.append(CraftTable.part_key(k))
	for k: StringName in CraftTable.BARRELS:
		keys.append(CraftTable.part_key(k))
	return keys[rng.randi() % keys.size()]


## The loot a site holds after a refill (deterministic for its seed and wave).
static func loot_for(site_kind: int, site_seed: int, wave: int) -> Array[Loot]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site_seed, wave, "loot"])
	var out: Array[Loot] = []
	var add := func(items: Dictionary, look: StringName, label: String, walk: bool) -> void:
		var l := Loot.new()
		l.slot = out.size()
		l.items = items
		l.look = look
		l.label = label
		l.walk = walk
		out.append(l)
	match site_kind:
		Kind.MOUTH:
			for i in 2:
				add.call({&"chitin": _chitin_pile(wave, rng)}, &"chitin", "Chitin", true)
			for i in rng.randi_range(1, 2):
				var p := CraftTable.random_part(rng)
				add.call({p: 1}, &"part", CraftTable.part_name(p), false)
			if rng.randf() < 0.75:
				add.call({JOURNAL_PAGE: 1}, &"page", "Doc Whitlow's Journal Page", false)
		Kind.BONEYARD:
			for i in 3:
				add.call({&"chitin": _chitin_pile(wave, rng) + 4}, &"chitin", "Chitin", true)
			var rare := _rare_part(rng)
			add.call({rare: 1}, &"part", CraftTable.part_name(rare), false)
			add.call({&"upgrade_token": 1, &"chitin": 10 + wave}, &"trophy", "Boss Trophy", false)
		Kind.CAMP:
			var designs := CraftTable.all_designs()
			var design: StringName = designs[rng.randi() % designs.size()]
			add.call(CraftTable.recipe(design), &"blueprint", "Blueprint: " + CraftTable.name_of(design), false)
			add.call({SPECIMEN: 1}, &"specimen", "Specimen Jar", false)
			add.call({JOURNAL_PAGE: 1}, &"page", "Doc Whitlow's Journal Page", false)
			add.call({&"scrap": _scrap_pile(wave, rng)}, &"scrap", "Supply Crate", false)
		Kind.NEST:
			for i in rng.randi_range(3, 4):
				add.call({NEST_EGG: rng.randi_range(2, 3)}, &"egg", "Nest Eggs", false)
			add.call({&"chitin": _chitin_pile(wave, rng)}, &"chitin", "Chitin", true)
		Kind.WRECK:
			for i in 3:
				add.call({&"scrap": _scrap_pile(wave, rng) * 2}, &"scrap", "Cartload of Scrap", false)
			add.call({&"scrap": _scrap_pile(wave, rng)}, &"scrap", "Scrap", true)
			if rng.randf() < 0.6:
				var p := CraftTable.random_part(rng)
				add.call({p: 1}, &"part", CraftTable.part_name(p), false)
	_place(out, site_kind, rng)
	return out


## Where loot can lie at each kind of site (local x across, z out from the
## wall), clear of the props SiteProps puts down.
const SPOTS: Array = [
	[Vector2(-1.5, -2.0), Vector2(1.6, -2.2), Vector2(0.0, 0.5), Vector2(-2.2, 2.6), Vector2(2.9, 1.0), Vector2(-0.5, 3.8), Vector2(3.6, -2.8)],
	[Vector2(-5.0, -2.0), Vector2(-5.0, 2.6), Vector2(0.0, -0.5), Vector2(4.8, 3.2), Vector2(1.8, 6.3), Vector2(-2.5, -5.6)],
	[Vector2(-3.8, -0.8), Vector2(3.0, -1.6), Vector2(-0.2, -4.2), Vector2(0.9, -1.0), Vector2(4.0, 2.6), Vector2(-4.6, 3.8)],
	[Vector2(0.0, 0.0), Vector2(1.8, 1.2), Vector2(-1.9, 0.9), Vector2(0.6, -2.2), Vector2(-1.0, 2.6), Vector2(2.5, -1.5)],
	[Vector2(0.0, 1.6), Vector2(2.8, 4.2), Vector2(-1.6, 4.6), Vector2(-5.4, 0.6), Vector2(1.6, 5.4), Vector2(4.8, -3.6)],
]


## Puts each loot on its own spot (shuffled per refill), with a little jitter.
static func _place(loot: Array[Loot], site_kind: int, rng: RandomNumberGenerator) -> void:
	var spots: Array = (SPOTS[site_kind] as Array).duplicate()
	_shuffle(spots, rng)
	for i in loot.size():
		var s: Vector2 = spots[i % spots.size()]
		loot[i].local = s + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))


## Total units of each item in a loot list ({key: units}).
static func totals(loot: Array[Loot]) -> Dictionary:
	var t: Dictionary = {}
	for l in loot:
		for k: StringName in l.items:
			t[k] = int(t.get(k, 0)) + int(l.items[k])
	return t


# ------------------------------------------------------------------ sleepers

## What sleeps at a site this wave: [[bug id, local x, local z], ...].
## A few to start; later waves add more and nastier ones.
static func sleepers_for(site_kind: int, site_seed: int, wave: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([site_seed, wave, "sleepers"])
	var extra := clampi(wave / 4, 0, 3)
	var ids: Array[StringName] = []
	match site_kind:
		Kind.MOUTH:
			for i in 2 + extra:
				ids.append(&"dust_mite")
			if wave >= 4:
				ids.append(&"wolf_spider")
		Kind.BONEYARD:
			# Scavenger beetles picking over the bones.
			for i in 1 + extra:
				ids.append(&"crop_weevil")
			ids.append(&"rattler_beetle")
		Kind.CAMP:
			for i in 1 + extra / 2:
				ids.append(&"dust_mite")
		Kind.NEST:
			# Brood guards and spiders.
			ids.append(&"rattler_beetle")
			for i in 2 + extra:
				ids.append(&"wolf_spider" if i % 2 == 0 else &"spiderling")
			if wave >= 8:
				ids.append(&"spitter_scorpion")
		Kind.WRECK:
			for i in 1 + extra / 2:
				ids.append(&"dust_mite")
	var out: Array = []
	for i in ids.size():
		var a := TAU * float(i) / float(ids.size()) + rng.randf_range(-0.4, 0.4)
		var r := rng.randf_range(2.0, RADIUS)
		out.append([ids[i], cos(a) * r, sin(a) * r])
	return out


## Sleepers wake when a player comes this close (metres), or on noise.
static func wake_range(bug_id: StringName) -> float:
	match bug_id:
		&"wolf_spider", &"spitter_scorpion":
			return 7.0
		&"rattler_beetle":
			return 4.5
	return 5.5


# ------------------------------------------------------------------ egg smash

## Host: tunnel -> the wave its next bugs come out cut (eggs smashed).
static var cuts: Dictionary = {}
## Fractional bugs carried per tunnel, so the cut works out at 80% over a wave.
static var _carry: Dictionary = {}


static func reset_cuts() -> void:
	cuts.clear()
	_carry.clear()


## Eggs at the site by `tunnel` were smashed: its next wave is cut.
static func smash(tunnel: int, next_wave: int) -> void:
	cuts[tunnel] = next_wave
	_carry[tunnel] = 0.0


static func is_cut(tunnel: int, wave: int) -> bool:
	return int(cuts.get(tunnel, -1)) == wave


## How many of `count` bugs that tunnel really sends in `wave`.
static func cut_count(tunnel: int, wave: int, count: int) -> int:
	if not is_cut(tunnel, wave) or count <= 0:
		return count
	var exact := float(count) * SMASH_KEEP + float(_carry.get(tunnel, 0.0))
	var n := int(floor(exact + 0.0001))
	_carry[tunnel] = exact - float(n)
	return n


## Clutches a nest needs smashed before its tunnel's next wave is cut (most of them).
static func smash_quota(clutches: int) -> int:
	return maxi(ceili(float(clutches) * 0.5), 1) if clutches > 0 else 0


# ------------------------------------------------------------------ journal

## Loose pages of Doc Whitlow's field journal, found in the tunnel mouths and
## the old camp (one line each, picked by `n`).
const JOURNAL: Array[String] = [
	"Day 3 below the rim. The mites sleep in heaps at the tunnel mouths, warm as kittens. Do not wake them. I woke them.",
	"The survey crew left in a hurry: tents up, theodolite still levelled. Whatever they saw, they saw it at night.",
	"Measured a rib from the great carcass in the bone yard: eleven feet. Whatever killed it is bigger still.",
	"The eggs hum when you put your ear to them. A low, contented hum. I find this more alarming than screaming.",
	"Number Seven came off the trestle in '89. The railroad says rockfall. The rails say otherwise: they're cut.",
	"Gunfire carries in this canyon like a church bell. Every bug for a quarter mile comes to see who rang it.",
	"The tunnels breathe. Warm air out by day, cold air in by night. Something very large is doing the breathing.",
	"Note to self: the wreck creaks before it falls. When it creaks, Whitlow, you LEAVE.",
]


static func journal_line(n: int) -> String:
	return JOURNAL[absi(n) % JOURNAL.size()]


# ------------------------------------------------------------------ wreck

## The railroad wreck groans while anyone is inside it, then comes down.
class WreckClock:
	extends RefCounted
	var t := 0.0
	var warned := false
	var collapsed := false

	## Returns &"creak" once when it starts to give, &"collapse" once when it
	## comes down, else &"".
	func tick(delta: float, occupied: bool) -> StringName:
		if collapsed:
			return &""
		if occupied:
			t += delta
		else:
			t = maxf(t - delta * SitePlan.WRECK_SETTLE, 0.0)
			if t < SitePlan.WRECK_WARN * 0.5:
				warned = false
		if t >= SitePlan.WRECK_COLLAPSE:
			collapsed = true
			return &"collapse"
		if t >= SitePlan.WRECK_WARN and not warned:
			warned = true
			return &"creak"
		return &""

	func reset() -> void:
		t = 0.0
		warned = false
		collapsed = false
