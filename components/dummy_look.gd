class_name DummyLook
extends RefCounted
## Player customization: what your crash-test dummy wears. A look is a plain
## Dictionary {slot: option id}, saved in Settings and sent to the other player.
## To add an option, add it here and draw it in DummyRig._mesh().

## slot -> [label, [[option id, option label], ...]]. The first option is the default.
const SLOTS: Dictionary = {
	"hat": ["Hat", [["cattleman", "Cattleman"], ["ten_gallon", "Ten-gallon"], ["gambler", "Flat gambler"], ["bowler", "Bowler"], ["sombrero", "Sombrero"], ["none", "Bare head"]]],
	"hair": ["Hair", [["none", "None (it's a dummy)"], ["mullet", "Mullet"], ["ponytail", "Ponytail"], ["long", "Long and wild"], ["mohawk", "Mohawk"]]],
	"facial": ["Facial hair", [["handlebar", "Handlebar"], ["none", "Clean"], ["horseshoe", "Horseshoe"], ["walrus", "Walrus"], ["pencil", "Pencil"], ["goatee", "Goatee"], ["beard", "Full beard"], ["chops", "Mutton chops"]]],
	"hair_color": ["Hair colour", [["brown", "Brown"], ["black", "Black"], ["blonde", "Blonde"], ["ginger", "Ginger"], ["grey", "Grey"]]],
	"outfit": ["Outfit", [["vest", "Leather vest"], ["none", "Just the dummy"], ["duster", "Duster coat"], ["poncho", "Poncho"], ["lawman", "Lawman"]]],
	"neck": ["Neck", [["bandana", "Bandana"], ["mask", "Bandana mask"], ["bolo", "Bolo tie"], ["none", "Nothing"]]],
	"extra": ["Extras", [["spurs", "Boots and spurs"], ["none", "Dummy feet"], ["bandolier", "Bandolier"], ["both", "Boots, spurs and bandolier"]]],
	"paint": ["Paint", [["yellow", "Test-lab yellow"], ["orange", "Safety orange"], ["white", "Lab white"]]],
}

const HAIR_COLORS: Dictionary = {"brown": Color("#5A3A22"), "black": Color("#24201E"), "blonde": Color("#E2C26A"),
	"ginger": Color("#C2602A"), "grey": Color("#A8A4A0")}
const PAINTS: Dictionary = {"yellow": Color("#F2C230"), "orange": Color("#F08A24"), "white": Color("#E8E4DA")}


static func default_look() -> Dictionary:
	var out: Dictionary = {}
	for slot: String in SLOTS:
		out[slot] = (SLOTS[slot][1] as Array)[0][0]
	return out


## Fills in missing or unknown options with the defaults.
static func clean(look: Variant) -> Dictionary:
	var out := default_look()
	if look is Dictionary:
		for slot: String in SLOTS:
			var v := str((look as Dictionary).get(slot, ""))
			for opt: Array in SLOTS[slot][1]:
				if opt[0] == v:
					out[slot] = v
	return out


static func hair_color(look: Dictionary) -> Color:
	return HAIR_COLORS.get(look.get("hair_color", "brown"), HAIR_COLORS["brown"])


static func paint(look: Dictionary) -> Color:
	return PAINTS.get(look.get("paint", "yellow"), PAINTS["yellow"])


static func has_boots(look: Dictionary) -> bool:
	return look.get("extra") == "spurs" or look.get("extra") == "both"


static func has_bandolier(look: Dictionary) -> bool:
	return look.get("extra") == "bandolier" or look.get("extra") == "both"


static func key(look: Dictionary) -> String:
	var parts: PackedStringArray = []
	for slot: String in SLOTS:
		parts.append(str(look.get(slot, "")))
	return "|".join(parts)
