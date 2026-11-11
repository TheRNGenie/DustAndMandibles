class_name CropBagUI
extends RefCounted
## The crop bag's UI (playtest fixes, Nov 2026: the bag replaces the Zippo on
## key 9). The gameplay side, CropBag (scenes/player/crop_bag.gd), owns the set
## crop and the left-click load; this file is what the player sees:
##   Wheel      the crop picker on the crop wheel (CropWheel, the emote wheel's
##              look): hold right click, flick to a crop, let go to set the bag
##   feed()     what a left click on this turret would do (the prompt and the
##              click share it, so they never disagree)
##   prompt()   the turret card while the bag is out ("@bag:" prompt for
##              HudPromptCard.show_bag)
##   held       true while the local player has the bag out: turrets' EMPTY
##              signs grow so they read at the bag's reach

const ITEM := &"crop_bag"
## How far the bag reaches (the E key reaches PlayerVitals.INTERACT_REACH, 3.5 m).
const REACH := 15.0

## The local player has the bag out (CropBag sets it on equip and stow).
static var held := false

## What a click would do: one of these, with the crop it's about.
enum Feed { NONE, UNSET, LOAD, SWAP, SAME, BUSY, NO_STOCK }


## What a left click with the bag set to `bag_crop` would do to turret `t`
## (a UniversalTurret or UniversalCrewedTurret on your own cliff; anything else
## is NONE). LOAD and SWAP are the ones that load: t.request_load(bag_crop).
static func feed(t: Node, bag_crop: StringName) -> Feed:
	if t == null or not is_instance_valid(t) or not t.has_method("request_load") or not t.has_method("sacks_of"):
		return Feed.NONE
	if bag_crop == &"":
		return Feed.UNSET
	var now := StringName(t.get("crop"))
	if now == bag_crop:
		return Feed.SAME
	if not bool(t.call("can_load_now")):
		return Feed.BUSY # loaded, and mid-wave only an empty turret takes a sack
	if int(t.call("sacks_of", bag_crop)) <= 0:
		return Feed.NO_STOCK
	return Feed.SWAP if now != &"" else Feed.LOAD


## The turret card while the bag is out: "@bag:" and the card's numbers as JSON
## (HudPromptCard.show_bag draws it). `t` as for feed().
static func prompt(t: Node, bag_crop: StringName) -> String:
	var f := feed(t, bag_crop)
	if f == Feed.NONE:
		return ""
	var d := t.get("def") as TurretDef
	var hp := t.get_node_or_null("Health")
	var now := StringName(t.get("crop"))
	var have := int(t.call("sacks_of", bag_crop)) if bag_crop != &"" else 0
	var info := {"name": d.display_name if d != null else "", "tier": int(t.get("tier")) + 1,
		"hp": "%d / %d" % [int(hp.get("hp")), int(hp.get("max_hp"))] if hp != null else "",
		"bag": String(bag_crop), "bag_name": CropEffects.short_name(bag_crop) if bag_crop != &"" else "",
		"have": have, "now": String(now), "now_name": CropEffects.short_name(now) if now != &"" else ""}
	var rmb := [KeyHints.key_for("alt_fire"), "Pick a Crop"]
	match f:
		Feed.UNSET:
			info["status"] = ["Your bag is empty: pick a crop first.", "info"]
			info["keys"] = [rmb]
		Feed.LOAD:
			info["status"] = ["", ""]
			info["keys"] = [[KeyHints.key_for("fire"), "Load %s" % info["bag_name"]], rmb]
		Feed.SWAP:
			info["status"] = ["Loaded with %s. The sack you swap out comes back." % info["now_name"], "info"]
			info["keys"] = [[KeyHints.key_for("fire"), "Swap to %s" % info["bag_name"]], rmb]
		Feed.SAME:
			info["status"] = ["Already loaded with %s." % info["bag_name"], "good"]
			info["keys"] = [rmb]
		Feed.BUSY:
			info["status"] = ["Already loaded with %s. Swap it once the wave is over." % info["now_name"], "info"]
			info["keys"] = [rmb]
		Feed.NO_STOCK:
			info["status"] = ["No %s sacks in the cellar." % info["bag_name"], "bad"]
			info["keys"] = [rmb]
	return "@bag:" + JSON.stringify(info)


## The bag's crop picker on the crop wheel: CropWheel.open_for(CropBagUI.Wheel.new(bag), &"alt_fire")
## while right click is held; letting go sets the bag (bag.call("set_bag_crop", c)).
## `bag` is the CropBag: set_crop (StringName), set_bag_crop(c), sacks_of(c), is_out().
class Wheel extends RefCounted:
	var bag: Object
	## The wheel reads the loaded crop from here: the bag's set crop (ringed).
	var crop: StringName:
		get:
			return StringName(bag.get("set_crop")) if bag != null and is_instance_valid(bag) else &""

	func _init(b: Object) -> void:
		bag = b

	func wheel_title() -> String:
		return "Crop Bag"

	func wheel_status() -> String:
		return "Set: %s" % CropEffects.short_name(crop) if crop != &"" else "Empty"

	func wheel_verb() -> String:
		return "set"

	func wheel_keys() -> String:
		return "Release: Set the Bag   ·   Esc: Close"

	## Sacks of `c` in your cellar (what a load takes from): the bag counts them.
	func sacks_of(c: StringName) -> int:
		return int(bag.call("sacks_of", c)) if bag != null and is_instance_valid(bag) else 0

	## Any crop can be set, stock or not (it loads once there's some).
	func can_pick(c: StringName) -> bool:
		return c != crop

	func can_load_now() -> bool:
		return bag != null and is_instance_valid(bag) and bool(bag.call("is_out"))

	func request_load(c: StringName) -> void:
		if bag != null and is_instance_valid(bag):
			bag.call("set_bag_crop", c)
