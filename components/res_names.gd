class_name ResNames
extends RefCounted
## What the players call the two currencies (DECISIONS 162). Internally the
## ids never changed, so saves, the network and tests keep working:
##   &"scrap"  = the TEAM POT. Players see it as CHITIN (bug pieces: every kill,
##               shell, bounty and sale pays into it; turrets, seeds and house
##               upgrades come out of it).
##   &"chitin" = each cliff's PERSONAL stock. Players see it as SCRAP (the junk
##               heap by the house and chilies pay it; guns and upgrades cost it).
## Every player-facing word, label and icon for them comes from here.

const TEAM_ID := &"scrap"
const PERSONAL_ID := &"chitin"

## Player-facing words, lower case ("40 chitin"). UiStyle.tc() capitalises.
const TEAM_WORD := "chitin"
const PERSONAL_WORD := "scrap"


## "chitin": what the team pot is called.
static func team() -> String:
	return TEAM_WORD


## "scrap": what your own stock is called.
static func personal() -> String:
	return PERSONAL_WORD


## "Chitin" / "Scrap", capitalised for labels.
static func team_cap() -> String:
	return TEAM_WORD.capitalize()


static func personal_cap() -> String:
	return PERSONAL_WORD.capitalize()


## The player-facing word for any resource id (other ids: underscores to spaces).
static func of(res: StringName) -> String:
	match res:
		TEAM_ID:
			return TEAM_WORD
		PERSONAL_ID:
			return PERSONAL_WORD
	return String(res).replace("_", " ")


## Swaps the two currency words in a lower-case resource word ("scrap" -> "chitin",
## "team scrap" -> "team chitin"); anything else is left alone. For UiStyle.cost().
static func word(resource: String) -> String:
	var parts := resource.split(" ")
	for i in parts.size():
		var p := parts[i].to_lower()
		if p == String(TEAM_ID):
			parts[i] = TEAM_WORD
		elif p == String(PERSONAL_ID):
			parts[i] = PERSONAL_WORD
	return " ".join(parts)


## Back from a shown word to the resource id ("Chitin" -> &"scrap", "Scrap" ->
## &"chitin", "Seed Corn" -> &"seed_corn"), for parsing price text.
static func id_of(shown: String) -> StringName:
	var w := shown.strip_edges().to_lower()
	if w == TEAM_WORD:
		return TEAM_ID
	if w == PERSONAL_WORD:
		return PERSONAL_ID
	return StringName(w.replace(" ", "_"))


## The painted icon (assets/icons/<key>.png) a resource shows: the team pot
## wears the chitin shell, your own stock the scrap.
static func icon_key(res: StringName) -> StringName:
	match res:
		TEAM_ID:
			return &"chitin"
		PERSONAL_ID:
			return &"scrap"
	return res
