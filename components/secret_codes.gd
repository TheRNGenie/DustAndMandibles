class_name SecretCodes
extends RefCounted
## Secret codes (main menu > Secrets). Codes are never stored in the repo: TABLE
## maps the SHA-256 of the salted, normalised code to what it unlocks, each a
## typed entry {"kind": "cosmetic" | "weapon", "id": ...}:
##   cosmetic  id = "slot:option" (PerkTable.cosmetic_key; DummyLook.SLOTS) - a
##             hidden Wardrobe option that shows up once unlocked
##   weapon    id = a weapon id (data/weapons) - e.g. a secret gun the gunsmith
##             only stocks for riders who know the code
##   notches   id = how many Notches it pays (every time it's entered)
## Unlocks are saved in the profile (PerkProfile.secrets, plus cosmetics for
## looks). Query with SecretCodes.is_unlocked(kind, id) (this player) or
## Perks.has_secret(peer_id, kind, id) (host, any rider).
##
## To add a code:  python tools/ui/secret_hash.py "THE CODE" weapon:dino_rifle
## and paste the line it prints into TABLE.

const SALT := "dust&mandibles:"
const KINDS: Array[String] = ["cosmetic", "weapon", "notches"]
## sha256 hex -> Array of {"kind", "id"}. Empty until the owner picks codes.
const TABLE: Dictionary = {
	"a2bc441e9bd7ae562183d029f1224f0debf316ecbf147ef64753d6dea2f4c067": [{"kind": "weapon", "id": "dino_rifle"}],
	"0f581a4a1816b73337ada44143a18bf27f7a332afcbea5d3c0aab40985d30787": [{"kind": "notches", "id": "120"}],
}


## Upper case, letters and digits only ("gold-rush 77" == "GOLDRUSH77").
static func normalize(code: String) -> String:
	var out := ""
	for ch in code.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


static func hash_of(code: String) -> String:
	return (SALT + normalize(code)).sha256_text()


## The profile key of an unlock: "weapon:dino_rifle", "cosmetic:hat:bug_skull".
static func key(kind: String, id: String) -> String:
	return "%s:%s" % [kind, id]


## What a code unlocks (empty = wrong code): an Array of {"kind", "id"}.
static func rewards(code: String, table: Dictionary = TABLE) -> Array:
	if normalize(code) == "":
		return []
	var out: Array = []
	for e: Variant in table.get(hash_of(code), []):
		if e is Dictionary and KINDS.has(str((e as Dictionary).get("kind", ""))) and str((e as Dictionary).get("id", "")) != "":
			out.append({"kind": str(e["kind"]), "id": str(e["id"])})
	return out


## True when something is a secret (hidden until its code is entered).
static func is_secret(kind: String, id: String, table: Dictionary = TABLE) -> bool:
	for v: Variant in table.values():
		for e: Variant in v:
			if e is Dictionary and str((e as Dictionary).get("kind", "")) == kind and str((e as Dictionary).get("id", "")) == id:
				return true
	return false


## True when a wardrobe option is a secret look.
static func is_secret_look(slot: String, option: String, table: Dictionary = TABLE) -> bool:
	return is_secret("cosmetic", PerkTable.cosmetic_key(slot, option), table)


## This player: has the code for it been entered? (Reads the Perks profile.)
static func is_unlocked(kind: StringName, id: StringName) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var perks: Node = tree.root.get_node_or_null("Perks") if tree != null and tree.root != null else null
	if perks == null:
		return false
	var prof: PerkProfile = perks.get("profile")
	return prof != null and prof.has_secret(String(kind), String(id))
