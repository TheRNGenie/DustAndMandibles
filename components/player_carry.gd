class_name PlayerCarry
extends Node
## The crops a player carries (playtest fixes, Nov 2026): up to CAP of each
## kind. Harvests, crop drops you pick up and market buys go in here (not the
## cliff's stock); eating, medicine, the tonic, dropping and selling take from
## it; the ammo workbench in the root cellar (CropWorkbench) turns them into
## turret sacks, three a crop.
##
## Keyed by crop id (&"corn", &"firecracker_chili", ...). The food items the rest
## of the game names (&"chili" etc.) map with crop_of_item() / item_of().
## The host owns every player's carry and sends the owner a copy (_sync).
## The carry is kept when you're downed or die.

signal changed

const CAP := 25

var player: Player
## crop id -> count. On the host: the truth. On the owner: the host's last copy.
var items: Dictionary = {}
## Medicine everyone starts a run with (it used to be the cliff's 3 herbs).
const START := {&"herbs": 3}


func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and items.is_empty():
		for c: StringName in START:
			items[c] = int(START[c])
		_push.call_deferred()


## Crops you carry, {crop: n} (the HUD's carried-crops strip, HudCarry).
func carried() -> Dictionary:
	var out := {}
	for c: StringName in items:
		if int(items[c]) > 0:
			out[c] = int(items[c])
	return out


func amount(c: StringName) -> int:
	return int(items.get(c, 0))


## Host: put up to `n` of crop `c` in; returns how many fit (the rest is left).
func add(c: StringName, n: int) -> int:
	if n <= 0 or c == &"":
		return 0
	var fit := mini(n, CAP - amount(c))
	if fit <= 0:
		return 0
	items[c] = amount(c) + fit
	_push()
	return fit


## Host: take `n` of crop `c` (all or nothing).
func take(c: StringName, n: int) -> bool:
	if n <= 0 or amount(c) < n:
		return false
	items[c] = amount(c) - n
	_push()
	return true


## Host: set the whole carry (a saved run coming back).
func restore(d: Dictionary) -> void:
	items.clear()
	for k: Variant in d:
		var c := StringName(str(k))
		items[c] = clampi(int(d[k]), 0, CAP)
	_push()


func _push() -> void:
	changed.emit()
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or player == null:
		return
	var owner := player.get_multiplayer_authority()
	if owner != multiplayer.get_unique_id() and owner > 0 and NetworkManager.players.has(owner):
		_sync.rpc_id(owner, items)


@rpc("authority", "reliable")
func _sync(d: Dictionary) -> void:
	items = d.duplicate()
	changed.emit()


# ------------------------------------------------------------------ helpers

## The food item a crop gives (most share their crop's id).
const ITEM_OF: Dictionary = {&"firecracker_chili": &"chili"}


static func item_of(c: StringName) -> StringName:
	return ITEM_OF.get(c, c)


## The crop a food item comes from (&"chili" -> &"firecracker_chili"); &"" if it isn't a crop.
static func crop_of_item(item: StringName) -> StringName:
	for c: StringName in ITEM_OF:
		if ITEM_OF[c] == item:
			return c
	return item if Defs.crop(item) != null else &""


## Host: the carry of peer `peer_id`'s player (null for the CPU or nobody).
static func of(tree: SceneTree, peer_id: int) -> PlayerCarry:
	if tree == null or peer_id <= 0:
		return null
	for n: Node in tree.get_nodes_in_group("players"):
		var p := n as Player
		if p != null and p.get_multiplayer_authority() == peer_id and not p.bot:
			return p.carry
	return null
