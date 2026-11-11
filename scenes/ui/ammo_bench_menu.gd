class_name AmmoBenchMenu
extends RefCounted
## The ammo workbench's menu (playtest fixes, Nov 2026): in the root cellar, E
## on the bench turns the crops you carry into turret ammo sacks, always 3 sacks
## a crop. One row per crop (the ones you carry first): what you carry, the
## cellar's sacks of it against the bin's room, what the crop does in a turret,
## and a slider with one "Convert N" button that says how many sacks it makes.
##
## The gameplay is the bench's (scenes/structures/crop_workbench.gd): it opens
## MenuScreen.instance.open(AmmoBenchMenu.new(self)) and answers, duck-typed:
##   cliff_id() -> int                 whose cellar
##   raw_of(crop) -> int                crops of that kind you carry
##   sacks_of(crop) -> int              sacks of it in the cellar
##   sack_cap() -> int                  a bin's room (AmmoStore.CELLAR_CAP)
##   request_convert(crop, n)           turn n carried crops into 3n sacks (host)
##   signal changed (optional)          redraw after a conversion lands

const PER_CROP := 3

var bench: Object

signal menu_changed


func _init(b: Object) -> void:
	bench = b
	if bench != null and bench.has_signal("changed"):
		bench.connect("changed", func() -> void: menu_changed.emit())


func menu_title() -> String:
	return "Ammo Workbench"


func menu_tagline() -> String:
	return "Every crop you carry down here makes %d sacks of turret ammo for the bins. The crop bag (9) and the turrets load from the bins." % PER_CROP


func menu_stock() -> Array:
	return [] # (the rows show each crop's own counts)


func menu_items(_tab: int) -> Array:
	var out: Array = []
	if bench == null or not is_instance_valid(bench):
		return out
	var cap := int(bench.call("sack_cap"))
	for crop: StringName in CropEffects.IDS:
		var raw := int(bench.call("raw_of", crop))
		var sacks := int(bench.call("sacks_of", crop))
		var room := maxi(cap - sacks, 0) / PER_CROP
		var most := mini(raw, room)
		var why := ""
		if raw <= 0:
			why = "You aren't carrying any %s." % CropEffects.short_name(crop)
		elif room <= 0:
			why = "The %s bin is full (%d)." % [CropEffects.short_name(crop), cap]
		var sack_tex: Texture2D = UiStyle.painted_icon(CropEffects.sack_of(crop))
		var row := {"id": "convert:" + String(crop),
			"name": "%s  ›  %s Sacks" % [CropEffects.short_name(crop), CropEffects.short_name(crop)],
			"icon": sack_tex if sack_tex != null else &"hammer",
			"desc": "You carry %d. Each makes %d sacks: %s in a crop-fed turret.\nIn the cellar: %d / %d sacks." % [
				raw, PER_CROP, CropEffects.effect_name(crop), sacks, cap],
			"price": "", "price_ok": true, "disabled": why, "disabled_kind": "info",
			"note": UiStyle.held(raw), "_raw": raw}
		if why == "":
			row["quantity"] = {"min": 1, "max": maxi(most, 1), "action": "convert", "verb": "Convert",
				"unit_cost": PER_CROP, "total_text": "Makes %d Sacks"}
		out.append(row)
	# The crops you carry first, then the rest, each in seed order.
	var have := out.filter(func(r: Dictionary) -> bool: return int(r["_raw"]) > 0)
	have.append_array(out.filter(func(r: Dictionary) -> bool: return int(r["_raw"]) <= 0))
	for r: Dictionary in have:
		r.erase("_raw")
	return have


func menu_press(id: Variant, action: StringName) -> void:
	var a := String(action)
	if not str(id).begins_with("convert:") or not a.begins_with("convert:"):
		return
	var crop := StringName(str(id).trim_prefix("convert:"))
	var n := int(a.get_slice(":", 1))
	if CropEffects.is_crop(crop) and n > 0 and bench != null and is_instance_valid(bench):
		bench.call("request_convert", crop, n)


## A stand-in bench for the gallery (its numbers only; converting moves them).
class DemoBench extends RefCounted:
	signal changed
	var raw: Dictionary = {&"corn": 12, &"firecracker_chili": 5, &"cotton": 8, &"herbs": 2}
	var sacks: Dictionary = {&"corn": 40, &"firecracker_chili": 498, &"cotton": 0, &"sulfur_root": 15}

	func cliff_id() -> int:
		return 0

	func raw_of(c: StringName) -> int:
		return int(raw.get(c, 0))

	func sacks_of(c: StringName) -> int:
		return int(sacks.get(c, 0))

	func sack_cap() -> int:
		return 500

	func request_convert(c: StringName, n: int) -> void:
		var k := mini(n, raw_of(c))
		raw[c] = raw_of(c) - k
		sacks[c] = sacks_of(c) + k * 3
		changed.emit()
