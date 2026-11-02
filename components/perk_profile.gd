class_name PerkProfile
extends RefCounted
## One player's Rancher's Ledger between runs: Brands banked, perk ranks
## unlocked, wardrobe items bought, the loadout picked for the next run, and a
## few lifetime tallies. Pure logic (no nodes) so it can be unit-tested; the
## Perks autoload owns the live copy and saves it to user://profile.json.

const VERSION := 1

var brands: int = 0
## perk id -> rank unlocked (1..max).
var ranks: Dictionary = {}
## Perk ids taken into the next run (at most PerkTable.MAX_LOADOUT).
var loadout: Array[StringName] = []
## Wardrobe keys bought ("slot:option").
var cosmetics: Array[String] = []
var lifetime_brands: int = 0
var runs: int = 0
var wins: int = 0
var best_wave: int = 0


func rank(id: StringName) -> int:
	return int(ranks.get(id, 0))


func is_unlocked(id: StringName) -> bool:
	return rank(id) > 0


func in_loadout(id: StringName) -> bool:
	return loadout.has(id)


## Brands for this perk's next rank, or -1 when it's maxed (or unknown).
func next_cost(id: StringName) -> int:
	return PerkTable.cost_of_rank(id, rank(id) + 1)


## "" if the next rank can be bought, else the reason.
func unlock_block(id: StringName) -> String:
	if not PerkTable.has(id):
		return "Unknown perk."
	var c := next_cost(id)
	if c < 0:
		return "Fully ranked."
	if brands < c:
		return "Needs %d more Brands." % (c - brands)
	return ""


## Buys the next rank. Returns true if it went through.
func unlock(id: StringName) -> bool:
	if unlock_block(id) != "":
		return false
	brands -= next_cost(id)
	ranks[id] = rank(id) + 1
	return true


## "" if the perk can go into the loadout now, else the reason.
func add_block(id: StringName) -> String:
	if not is_unlocked(id):
		return "Unlock it first."
	if in_loadout(id):
		return ""
	if loadout.size() >= PerkTable.MAX_LOADOUT:
		return "Loadout full (%d)." % PerkTable.MAX_LOADOUT
	return ""


## Puts a perk in or takes it out. Returns true if the loadout changed.
func toggle(id: StringName) -> bool:
	if in_loadout(id):
		loadout.erase(id)
		return true
	if add_block(id) != "":
		return false
	loadout.append(id)
	return true


## The loadout as {id: rank}, what the run actually uses.
func loadout_ranks() -> Dictionary:
	var out: Dictionary = {}
	for id in loadout:
		if is_unlocked(id):
			out[id] = rank(id)
	return out


## A loadout dictionary from anywhere (a peer's RPC, an old save) cut down to
## known perks, legal ranks and at most MAX_LOADOUT entries.
static func sanitize(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for k: Variant in raw:
		var id := StringName(str(k))
		if not PerkTable.has(id) or out.size() >= PerkTable.MAX_LOADOUT:
			continue
		var r := clampi(int((raw as Dictionary)[k]), 0, PerkTable.max_rank(id))
		if r > 0:
			out[id] = r
	return out


## Drops loadout entries that aren't unlocked, unknown or over the limit.
func validate() -> void:
	var clean: Array[StringName] = []
	for id in loadout:
		if PerkTable.has(id) and is_unlocked(id) and not clean.has(id) and clean.size() < PerkTable.MAX_LOADOUT:
			clean.append(id)
	loadout = clean
	for id: StringName in ranks.keys():
		if not PerkTable.has(id):
			ranks.erase(id)
		else:
			ranks[id] = clampi(int(ranks[id]), 0, PerkTable.max_rank(id))
	brands = maxi(brands, 0)


func owns_cosmetic(slot: String, option: String) -> bool:
	return PerkTable.cosmetic_price(slot, option) <= 0 or cosmetics.has(PerkTable.cosmetic_key(slot, option))


func buy_cosmetic(slot: String, option: String) -> bool:
	var price := PerkTable.cosmetic_price(slot, option)
	if owns_cosmetic(slot, option) or brands < price:
		return false
	brands -= price
	cosmetics.append(PerkTable.cosmetic_key(slot, option))
	return true


## Banks a run's Brands and tallies.
func bank_run(earned: int, wave_reached: int, won: bool) -> void:
	brands += maxi(earned, 0)
	lifetime_brands += maxi(earned, 0)
	runs += 1
	if won:
		wins += 1
	best_wave = maxi(best_wave, wave_reached)


func to_dict() -> Dictionary:
	var r: Dictionary = {}
	for id: StringName in ranks:
		r[String(id)] = int(ranks[id])
	var lo: Array = []
	for id in loadout:
		lo.append(String(id))
	return {"version": VERSION, "brands": brands, "ranks": r, "loadout": lo, "cosmetics": cosmetics.duplicate(),
		"lifetime_brands": lifetime_brands, "runs": runs, "wins": wins, "best_wave": best_wave}


static func from_dict(d: Variant) -> PerkProfile:
	var p := PerkProfile.new()
	if not (d is Dictionary):
		return p
	var dict := d as Dictionary
	p.brands = int(dict.get("brands", 0))
	var r: Variant = dict.get("ranks", {})
	if r is Dictionary:
		for k: Variant in r:
			p.ranks[StringName(str(k))] = int((r as Dictionary)[k])
	var lo: Variant = dict.get("loadout", [])
	if lo is Array:
		for k: Variant in lo:
			p.loadout.append(StringName(str(k)))
	var c: Variant = dict.get("cosmetics", [])
	if c is Array:
		for k: Variant in c:
			p.cosmetics.append(str(k))
	p.lifetime_brands = int(dict.get("lifetime_brands", 0))
	p.runs = int(dict.get("runs", 0))
	p.wins = int(dict.get("wins", 0))
	p.best_wave = int(dict.get("best_wave", 0))
	p.validate()
	return p


func save(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


static func load_from(path: String) -> PerkProfile:
	if not FileAccess.file_exists(path):
		return PerkProfile.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PerkProfile.new()
	return from_dict(JSON.parse_string(f.get_as_text()))
