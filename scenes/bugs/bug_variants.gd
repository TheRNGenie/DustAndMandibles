extends RefCounted
## Kill-method variants: kill too many of one bug type the same way and the canyon
## answers with a variant that shrugs that method off but has a different weakness,
## its own shell colour and its own name (variety, not a blanket resistance).
## Ids look like "rattler_beetle@bullet" (the base bug @ the method it answers).
## Defs.bug() finds them, so they spawn, replicate and preview like any bug.
## Load with preload("res://scenes/bugs/bug_variants.gd").

## One variant per overused kill method: name prefix, shell tint, damage taken
## per method, and the counter the Field Guide and kill feed state.
const KINDS := {
	&"bullet": {"prefix": "Ironback", "tint": Color(0.27, 0.31, 0.38),
		"taken": {&"bullet": 0.5, &"fire": 1.5, &"blast": 1.5},
		"counter": "Iron plates turn bullets aside: burn it or blow it up.",
		"short": "shrugs off bullets, weak to fire and blasts"},
	&"fire": {"prefix": "Sootback", "tint": Color(0.13, 0.1, 0.09),
		"taken": {&"fire": 0.35, &"bullet": 1.5},
		"counter": "A fireproof soot crust, soft underneath: shoot it.",
		"short": "fireproof, weak to bullets"},
	&"blast": {"prefix": "Stoneshell", "tint": Color(0.88, 0.8, 0.62),
		"taken": {&"blast": 0.4, &"fire": 1.6},
		"counter": "A stony shell shrugs off blasts, but it cooks: use fire.",
		"short": "blast-proof, weak to fire"},
}
## How far the shell colour moves toward the variant's tint.
const TINT := 0.7
## Bugs that never get variants (the boss, spawned children, disabled bugs).
const NEVER: Array[StringName] = [&"iron_tumble", &"spiderling", &"burrow_tick"]

static var _made: Dictionary = {}


static func id_for(base: StringName, method: StringName) -> StringName:
	return StringName("%s@%s" % [base, method])


static func can_vary(base: StringName, method: StringName) -> bool:
	return KINDS.has(method) and not NEVER.has(base) and Defs.BUGS.has(base)


## The variant for an id like "rattler_beetle@bullet" (made once), or null.
static func get_def(id: StringName) -> BugDef:
	if _made.has(id):
		return _made[id]
	var s := String(id)
	var at := s.find("@")
	if at < 0:
		return null
	var base := StringName(s.left(at))
	var method := StringName(s.substr(at + 1))
	if not can_vary(base, method):
		return null
	var src := Defs.BUGS[base] as BugDef
	var k: Dictionary = KINDS[method]
	var d := src.duplicate() as BugDef
	d.id = id
	d.variant_of = base
	d.display_name = "%s %s" % [k["prefix"], src.display_name]
	d.shell_color = src.shell_color.lerp(k["tint"], TINT)
	d.damage_taken = (k["taken"] as Dictionary).duplicate()
	d.counter = str(k["counter"])
	_made[id] = d
	return d


## One line for the Field Guide: every variant and what it's weak to.
static func summary() -> String:
	var parts: PackedStringArray = []
	for m: StringName in KINDS:
		parts.append("%s (%s)" % [KINDS[m]["prefix"], KINDS[m]["short"]])
	return "Kill too many the same way and variants appear: " + ", ".join(parts) + "."
