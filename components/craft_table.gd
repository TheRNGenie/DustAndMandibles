class_name CraftTable
extends RefCounted
## Turret crafting at the Workshop (a homestead upgrade). A crafted turret is
## made from three parts, one of each kind: a mount, a barrel and a load. Each
## combination is its own design with its own name, stats and look. Crafting
## uses up the parts and gives a turret ITEM (one of that design) that goes into
## the cliff's stockpile; the build menu's Crafted tab places it on the grid for
## free, using up the item.
##
## Parts and crafted items live in Economy's stockpile like scrap or chitin:
## parts as &"part_<id>", crafted items under their design id
## (&"craft_<mount>_<barrel>_<load>"). Design ids double as turret ids:
## Defs.turret() builds their TurretDef here.

const PREFIX := "craft_"
const PART_PREFIX := "part_"

## Mounts: what the gun sits on. hp/turn are multipliers or overrides on the barrel's base.
const MOUNTS: Dictionary = {
	&"post": {"name": "Post", "desc": "A plain timber post: steady, no changes to the barrel.", "hp": 1.0, "turn": 1.0, "range": 1.0, "pitch": 0.0},
	&"swivel": {"name": "Swivel", "desc": "A greased swivel: turns 2x as fast, 20% less HP, 5% less range.", "hp": 0.8, "turn": 2.0, "range": 0.95, "pitch": 0.0},
	&"tripod": {"name": "Tripod", "desc": "An iron tripod: +70% HP, turns at 60% speed, aims 12° further down the wall.", "hp": 1.7, "turn": 0.6, "range": 1.0, "pitch": 12.0},
}

## Barrels: how it shoots. These set the base stats.
const BARRELS: Dictionary = {
	&"rifle": {"name": "Rifle", "noun": "Long Tom", "desc": "One heavy round at a time, far and true.",
		"damage": 32.0, "interval": 0.95, "range": 110.0, "hp": 140.0, "effect": TurretDef.Effect.HITSCAN, "flight": 0.0, "size": 0.0,
		"heavy": 1.4, "spread": 0.5, "hit": 0.92, "model": &"buffalo_rifle"},
	&"scatter": {"name": "Scatter", "noun": "Peppergun", "desc": "A hail of small shot: shreds swarms, tickles big bugs.",
		"damage": 5.0, "interval": 0.13, "range": 72.0, "hp": 150.0, "effect": TurretDef.Effect.HITSCAN, "flight": 0.0, "size": 0.0,
		"heavy": 0.5, "spread": 3.0, "hit": 0.8, "model": &"gatling_post"},
	&"cannon": {"name": "Cannon", "noun": "Thumper", "desc": "Lobs a fat shell that bursts on the wall.",
		"damage": 44.0, "interval": 2.6, "range": 95.0, "hp": 170.0, "effect": TurretDef.Effect.SPLASH, "flight": 1.1, "size": 3.0,
		"heavy": 1.0, "spread": 1.5, "hit": 1.0, "model": &"chili_mortar"},
	&"nozzle": {"name": "Nozzle", "noun": "Hose", "desc": "A short-range spray that soaks a patch of wall.",
		"damage": 7.0, "interval": 0.35, "range": 55.0, "hp": 160.0, "effect": TurretDef.Effect.KNOCKBACK, "flight": 0.0, "size": 0.0,
		"heavy": 1.0, "spread": 2.0, "hit": 0.95, "model": &"water_cannon"},
}

## Loads: what it fires. These change the effect.
const LOADS: Dictionary = {
	&"lead": {"name": "Lead", "word": "", "desc": "Plain lead: no change to the barrel.", "color": Color("#8A8F96")},
	&"explosive": {"name": "Explosive", "word": "Dynamite", "desc": "Every hit bursts: 1.6 m splash, 15% less damage (cannon shells burst 50% wider).", "color": Color("#D8572A")},
	&"fire": {"name": "Fire", "word": "Brush", "desc": "Sets the wall alight: a burning patch of 2.2 m or more, 30% less damage.", "color": Color("#F2A33A")},
	&"acid": {"name": "Acid", "word": "Etching", "desc": "Eats armour: pierces plates, 15% more damage.", "color": Color("#8BC34A")},
}

## Every part's stockpile key, for drops and the Parts list.
static func part_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for d: Dictionary in [MOUNTS, BARRELS, LOADS]:
		for id: StringName in d:
			out.append(StringName(PART_PREFIX + String(id)))
	return out


static func part_key(id: StringName) -> StringName:
	return StringName(PART_PREFIX + String(id))


## "Swivel mount", "Scatter barrel", "Fire load".
static func part_name(key: StringName) -> String:
	var id := StringName(String(key).substr(PART_PREFIX.length()))
	if MOUNTS.has(id):
		return "%s mount" % MOUNTS[id]["name"]
	if BARRELS.has(id):
		return "%s barrel" % BARRELS[id]["name"]
	if LOADS.has(id):
		return "%s load" % LOADS[id]["name"]
	return String(key)


static func part_desc(key: StringName) -> String:
	var id := StringName(String(key).substr(PART_PREFIX.length()))
	if BARRELS.has(id):
		# A barrel sets the base numbers: show them the way the build menu does.
		var b: Dictionary = BARRELS[id]
		return "%s
%s" % [b["desc"], def_for(design_id(&"post", id, &"lead")).stat_line()]
	for d: Dictionary in [MOUNTS, LOADS]:
		if d.has(id):
			return str(d[id]["desc"])
	return ""


static func is_part(key: StringName) -> bool:
	return String(key).begins_with(PART_PREFIX)


static func is_craft(id: StringName) -> bool:
	return String(id).begins_with(PREFIX)


static func design_id(mount: StringName, barrel: StringName, load: StringName) -> StringName:
	return StringName("%s%s_%s_%s" % [PREFIX, mount, barrel, load])


## [mount, barrel, load] of a design id, or [] if it isn't one.
static func parse(id: StringName) -> Array:
	var s := String(id)
	if not s.begins_with(PREFIX):
		return []
	var p := s.substr(PREFIX.length()).split("_")
	if p.size() != 3 or not MOUNTS.has(StringName(p[0])) or not BARRELS.has(StringName(p[1])) or not LOADS.has(StringName(p[2])):
		return []
	return [StringName(p[0]), StringName(p[1]), StringName(p[2])]


## The parts one design uses up: {part key: 1, ...}.
static func recipe(id: StringName) -> Dictionary:
	var p := parse(id)
	if p.is_empty():
		return {}
	return {part_key(p[0]): 1, part_key(p[1]): 1, part_key(p[2]): 1}


## "Swivel Brush Peppergun".
static func name_of(id: StringName) -> String:
	var p := parse(id)
	if p.is_empty():
		return String(id)
	var word: String = LOADS[p[2]]["word"]
	var noun: String = BARRELS[p[1]]["noun"]
	var mount: String = MOUNTS[p[0]]["name"]
	return ("%s %s %s" % [mount, word, noun]) if word != "" else ("%s %s" % [mount, noun])


## Which existing turret's model a design borrows (by barrel).
static func model_of(id: StringName) -> StringName:
	var p := parse(id)
	return BARRELS[p[1]]["model"] if not p.is_empty() else &""


static func tint_of(id: StringName) -> Color:
	var p := parse(id)
	return LOADS[p[2]]["color"] if not p.is_empty() else Color.WHITE


static var _defs: Dictionary = {}


## The TurretDef for a design (built once, then cached).
static func def_for(id: StringName) -> TurretDef:
	if _defs.has(id):
		return _defs[id]
	var p := parse(id)
	if p.is_empty():
		return null
	var m: Dictionary = MOUNTS[p[0]]
	var b: Dictionary = BARRELS[p[1]]
	var l: StringName = p[2]
	var d := TurretDef.new()
	d.id = id
	d.display_name = name_of(id)
	d.cost_scrap = 0 # crafted: placing uses up the item, not scrap
	d.max_hp = float(b["hp"]) * float(m["hp"])
	d.range = float(b["range"]) * float(m["range"])
	d.fire_interval = float(b["interval"])
	d.damage = float(b["damage"])
	d.heavy_mult = float(b["heavy"])
	d.spread_deg = float(b["spread"])
	d.hit_chance = float(b["hit"])
	d.effect = b["effect"]
	d.flight_time = float(b["flight"])
	d.effect_size = float(b["size"])
	d.turn_speed = 180.0 * float(m["turn"])
	d.pitch_limit_deg = 30.0 + float(m["pitch"])
	match l:
		&"explosive":
			if d.effect == TurretDef.Effect.SPLASH:
				d.effect_size *= 1.5
			else:
				d.effect = TurretDef.Effect.SPLASH
				d.effect_size = 1.6
				d.damage *= 0.85
		&"fire":
			d.effect = TurretDef.Effect.BURN
			d.effect_size = maxf(d.effect_size, 2.2)
			d.damage *= 0.7
		&"acid":
			d.armor_pierce = true
			d.damage *= 1.15
	d.role = "Crafted: %s + %s + %s" % [m["name"], b["name"], LOADS[l]["name"]]
	d.weakness = "One of a kind: craft another at the Workshop"
	d.description = "%s %s %s" % [m["desc"], b["desc"], LOADS[l]["desc"]]
	_defs[id] = d
	return d


## Every design id (3 mounts x 4 barrels x 4 loads = 48).
static func all_designs() -> Array[StringName]:
	var out: Array[StringName] = []
	for m: StringName in MOUNTS:
		for b: StringName in BARRELS:
			for l: StringName in LOADS:
				out.append(design_id(m, b, l))
	return out


## A random part for a drop (weighted: loads common, mounts rarer).
static func random_part(rng: RandomNumberGenerator = null) -> StringName:
	var r := rng.randf() if rng != null else randf()
	var pool: Array
	if r < 0.4:
		pool = LOADS.keys()
	elif r < 0.75:
		pool = BARRELS.keys()
	else:
		pool = MOUNTS.keys()
	var i := (rng.randi() if rng != null else randi()) % pool.size()
	return part_key(pool[i])
