class_name RunSave
extends RefCounted
## A run saved as plain data (Continue last run). The host autosaves at the start
## of every build phase (RunSaver gathers the world into this shape); the main
## menu's "Continue last run" loads it back. Everything here is pure data in and
## out (no nodes), so the round trip is unit-tested, and decode() fills in
## defaults for anything missing so an older or hand-edited file still loads.
##
## Shape (VERSION 1):
##   wave, phase, endless, weather, cpu_quality, saved_at
##   homesteads: [{hp, max, floors, boarded, reinforced, tower}] (west, east)
##   builds: [{type, cliff, row, col, level, owner, hp, tier, levels, armed,
##             perk: [range, rate, hp], stored, crop: {id, stage, progress, watered}}]
##   wells: [{path, stored}]  (the homestead wells; older saves also have "working", ignored)
##   economy: {stock: {cliff: {res: n}, -1: {scrap: n}}, cpu_mode, gained, cpu_spent: {name: {res: n}}, cpu_share}
##     (-1 = the team pot: scrap is shared, the rest per cliff. Older saves kept
##     scrap per cliff, and a CPU game's old 'shared' pool under cliff 0: both convert.)
##   players: {cliff: {food, water}}
##   perks: {cliff: {loadout: {perk: rank}, free_used}}  (the locked loadout; Barn Raising spent)
##   guns: {cliff: {weapon: mod code}}
##   bosses_seen: [boss id, ...]  (oldest first, so Continue never repeats a boss early)
##   brands: {cliff: brand id}  (each rider's brand, the CPU partner's too; BrandTable ids)
##   waterworks: {cliff: {tank, lever}}  (each water tower's level, each generator lever)

const VERSION := 1
const DIR := "user://saves"
const PATH := "user://saves/run.json"
## Debug/test launches save here instead, so they never overwrite a real run.
const DEBUG_PATH := "user://saves/run_debug.json"

## Set by the main menu: the run the next game should rebuild (empty = new run).
static var pending: Dictionary = {}


static func path() -> String:
	return DEBUG_PATH if Engine.get_main_loop() != null and _debug_launch() else PATH


## Debug and automated launches (--debug, --fast) keep their own save file.
static func _debug_launch() -> bool:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	return "--debug" in args or "--fast" in args


# ------------------------------------------------------------------ pure data

## The data as JSON text.
static func encode(data: Dictionary) -> String:
	var d := data.duplicate(true)
	d["version"] = VERSION
	return JSON.stringify(_plain(d), "\t")


## Parses saved JSON into a complete, typed run (defaults for anything missing).
## Returns {} if the text isn't a run at all.
static func decode(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return normalize(parsed as Dictionary)


## Fills in defaults and fixes types (JSON numbers are floats, keys are strings).
static func normalize(raw: Dictionary) -> Dictionary:
	var out := {
		"version": _i(raw, "version", VERSION),
		"wave": maxi(_i(raw, "wave", 1), 1),
		"phase": _i(raw, "phase", 1),
		"endless": _b(raw, "endless", false),
		"weather": _i(raw, "weather", 0),
		"cpu_quality": clampi(_i(raw, "cpu_quality", -1), -1, 2),
		"saved_at": _i(raw, "saved_at", 0),
		"map": str(raw.get("map", "canyon")) if MapDef.IDS.has(StringName(str(raw.get("map", "canyon")))) else "canyon",
	}
	var cliffs := MapDef.players_of(StringName(str(out["map"]))) # Maps: one house / stockpile per cliff
	var homes: Array = []
	var raw_homes: Array = raw.get("homesteads", []) if raw.get("homesteads") is Array else []
	for cid in cliffs:
		var h: Dictionary = raw_homes[cid] if cid < raw_homes.size() and raw_homes[cid] is Dictionary else {}
		var mx := _f(h, "max", 0.0)
		homes.append({"hp": _f(h, "hp", mx), "max": mx, "floors": clampi(_i(h, "floors", 1), 1, 3),
				"boarded": _b(h, "boarded", false), "reinforced": _b(h, "reinforced", false), "tower": _b(h, "tower", false)})
	out["homesteads"] = homes
	var builds: Array = []
	for b: Variant in (raw.get("builds", []) if raw.get("builds") is Array else []):
		if not (b is Dictionary) or str((b as Dictionary).get("type", "")) == "":
			continue
		builds.append(_build(b as Dictionary, cliffs))
	out["builds"] = builds
	var wells: Array = []
	for w: Variant in (raw.get("wells", []) if raw.get("wells") is Array else []):
		if w is Dictionary and str((w as Dictionary).get("path", "")) != "":
			wells.append({"path": str(w["path"]), "stored": _i(w, "stored", 0)})
	out["wells"] = wells
	var eco: Dictionary = raw.get("economy", {}) if raw.get("economy") is Dictionary else {}
	var stock := {}
	var raw_stock: Dictionary = eco.get("stock", {}) if eco.get("stock") is Dictionary else {}
	for cid in cliffs:
		stock[cid] = _amounts(raw_stock.get(str(cid), raw_stock.get(cid, {})))
	var team_key: Variant = str(EconomyLedger.TEAM) if raw_stock.has(str(EconomyLedger.TEAM)) else EconomyLedger.TEAM
	if raw_stock.has(team_key):
		stock[EconomyLedger.TEAM] = _amounts(raw_stock[team_key])
	elif _b(eco, "shared", false):
		# An older save with a CPU teammate pooled everything under cliff 0:
		# give each cliff its even part of the personal resources back.
		stock = fit_stock(stock, true, false)
	# Older saves kept scrap per cliff: sum it into the team pot.
	stock = EconomyLedger.pool_shared(stock)
	var spent := {}
	var raw_spent: Dictionary = eco.get("cpu_spent", {}) if eco.get("cpu_spent") is Dictionary else {}
	for who: Variant in raw_spent:
		spent[str(who)] = _amounts(raw_spent[who])
	out["economy"] = {"stock": stock, "cpu_mode": _b(eco, "cpu_mode", _b(eco, "shared", false)), "gained": _amounts(eco.get("gained", {})),
			"cpu_spent": spent, "cpu_share": _f(eco, "cpu_share", 0.0)}
	var players := {}
	var raw_players: Dictionary = raw.get("players", {}) if raw.get("players") is Dictionary else {}
	for key: Variant in raw_players:
		var p: Variant = raw_players[key]
		if p is Dictionary and str(key).is_valid_int():
			players[int(str(key))] = {"food": clampf(_f(p, "food", 1.0), 0.0, 1.0), "water": clampf(_f(p, "water", 1.0), 0.0, 1.0)}
	out["players"] = players
	var perks := {}
	var guns := {}
	var raw_perks: Dictionary = raw.get("perks", {}) if raw.get("perks") is Dictionary else {}
	for key: Variant in raw_perks:
		var p: Variant = raw_perks[key]
		if p is Dictionary and str(key).is_valid_int():
			perks[int(str(key))] = {"loadout": _amounts((p as Dictionary).get("loadout", {})), "free_used": _b(p, "free_used", false)}
	var raw_guns: Dictionary = raw.get("guns", {}) if raw.get("guns") is Dictionary else {}
	for key: Variant in raw_guns:
		if str(key).is_valid_int():
			guns[int(str(key))] = _amounts(raw_guns[key])
	out["perks"] = perks
	out["guns"] = guns
	var seen: Array = []
	for id: Variant in (raw.get("bosses_seen", []) if raw.get("bosses_seen") is Array else []):
		if (id is String or id is StringName) and str(id) != "":
			seen.append(StringName(str(id)))
	out["bosses_seen"] = seen
	# Brand: older saves have none (everyone rides unbranded).
	var brands := {}
	var raw_brands: Dictionary = raw.get("brands", {}) if raw.get("brands") is Dictionary else {}
	for key: Variant in raw_brands:
		if str(key).is_valid_int():
			brands[int(str(key))] = String(BrandTable.valid(raw_brands[key]))
	out["brands"] = brands
	# Waterworks: older saves have empty towers and every lever up.
	out["waterworks"] = Waterworks.normalize_saved(raw.get("waterworks", {}), cliffs)
	return out


static func _build(b: Dictionary, cliffs: int = 2) -> Dictionary:
	var out := {"type": StringName(str(b["type"])), "cliff": clampi(_i(b, "cliff", 0), 0, maxi(cliffs - 1, 0)), # Maps: any cliff of the map
			"row": _i(b, "row", 0), "col": _i(b, "col", 0), "level": maxi(_i(b, "level", 0), 0),
			"owner": str(b.get("owner", "")), "hp": _f(b, "hp", -1.0), "tier": maxi(_i(b, "tier", 0), 0),
			"levels": clampi(_i(b, "levels", 1), 1, 3), "paid": maxi(_i(b, "paid", 1), 0), "armed": _b(b, "armed", true), "stored": _i(b, "stored", 0)}
	var perk: Array = b.get("perk", []) if b.get("perk") is Array else []
	out["perk"] = [float(perk[0]) if perk.size() > 0 else 1.0, float(perk[1]) if perk.size() > 1 else 1.0,
			float(perk[2]) if perk.size() > 2 else 1.0,
			float(perk[3]) if perk.size() > 3 else 0.0, # Overtime mend share
			float(perk[4]) if perk.size() > 4 else 1.0] # Scrap Scavenger multiplier
	if b.get("crop") is Dictionary:
		var c: Dictionary = b["crop"]
		out["crop"] = {"id": StringName(str(c.get("id", ""))), "stage": clampi(_i(c, "stage", 0), 0, 3),
				"progress": _f(c, "progress", 0.0), "watered": _b(c, "watered", false)}
	return out


## Stockpiles saved with a CPU partner share one pool (cliff 0); played without
## one, they're separate. Moves the resources to fit how this game is set up.
static func fit_stock(stock: Dictionary, was_shared: bool, now_shared: bool) -> Dictionary:
	# Maps: one stockpile per cliff (2, 3 or 4), plus the team pot if any.
	var out := {}
	var n := 0
	for k: Variant in stock:
		if int(k) != EconomyLedger.TEAM:
			n += 1
	n = maxi(n, 2)
	for cid in n:
		out[cid] = (stock.get(cid, {}) as Dictionary).duplicate()
	if stock.get(EconomyLedger.TEAM) is Dictionary:
		out[EconomyLedger.TEAM] = (stock[EconomyLedger.TEAM] as Dictionary).duplicate()
	if was_shared and not now_shared:
		# Split the team pool evenly (cliff 0 keeps any odd ones).
		var pool: Dictionary = out[0]
		for r: StringName in pool.keys():
			var each := int(pool[r]) / n
			pool[r] = int(pool[r]) - each * (n - 1)
			for cid in range(1, n):
				out[cid][r] = int((out[cid] as Dictionary).get(r, 0)) + each
	elif now_shared and not was_shared:
		for cid in range(1, n):
			for r: StringName in out[cid]:
				out[0][r] = int((out[0] as Dictionary).get(r, 0)) + int(out[cid][r])
				out[cid][r] = 0
	return out


## A saved stockpile fitted to this map's cliff count: missing cliffs start
## empty, and the team pot is always there.
static func fit_cliffs(stock: Dictionary, cliffs: int) -> Dictionary:
	var out := {}
	for cid in cliffs:
		out[cid] = (stock.get(cid, {}) as Dictionary).duplicate()
	out[EconomyLedger.TEAM] = (stock.get(EconomyLedger.TEAM, {}) as Dictionary).duplicate()
	return EconomyLedger.pool_shared(out)


static func _amounts(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k: Variant in v:
			out[StringName(str(k))] = int(v[k])
	return out


static func _i(d: Variant, key: String, def: int) -> int:
	var v: Variant = (d as Dictionary).get(key, def) if d is Dictionary else def
	return int(v) if (v is int or v is float or (v is String and (v as String).is_valid_float())) else def


static func _f(d: Variant, key: String, def: float) -> float:
	var v: Variant = (d as Dictionary).get(key, def) if d is Dictionary else def
	return float(v) if (v is int or v is float or (v is String and (v as String).is_valid_float())) else def


static func _b(d: Variant, key: String, def: bool) -> bool:
	var v: Variant = (d as Dictionary).get(key, def) if d is Dictionary else def
	return bool(v) if (v is bool or v is int or v is float) else def


## StringNames and int keys to plain JSON-friendly values.
static func _plain(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[str(k)] = _plain(v[k])
		return out
	if v is Array:
		var arr: Array = []
		for x: Variant in v:
			arr.append(_plain(x))
		return arr
	if v is StringName:
		return str(v)
	return v


# ------------------------------------------------------------------ files

static func exists() -> bool:
	return FileAccess.file_exists(path())


## Writes the run (to a temp file first, so a crash mid-write keeps the old save).
static func write(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var tmp := path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(encode(data))
	f.close()
	return DirAccess.rename_absolute(tmp, path()) == OK


## The saved run, or {} if there is none (or it can't be read).
static func read() -> Dictionary:
	if not exists():
		return {}
	var text := FileAccess.get_file_as_string(path())
	return decode(text) if text != "" else {}


static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(path())
