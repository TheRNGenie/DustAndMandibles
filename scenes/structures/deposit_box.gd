class_name DepositBox
extends StorageChest
## A small deposit box on the side of each house. Both boxes open the SAME
## shared inventory (everything lives in the first box made, `primary`), so
## anyone on either cliff can put crops in or take them out. CPU teammates leave
## their harvest here for the players to sell.

static var primary: DepositBox


func _ready() -> void:
	super._ready()
	add_to_group("deposit_boxes")
	scale = Vector3.ONE * 0.62
	if primary == null or not is_instance_valid(primary):
		primary = self


func _exit_tree() -> void:
	if primary == self:
		primary = null


func _box() -> DepositBox:
	return primary if primary != null and is_instance_valid(primary) else self


func interact_prompt() -> String:
	return "Shared deposit box\nE: open"


func menu_title() -> String:
	return "Deposit Box"


func menu_tagline() -> String:
	return "Shared by everyone on both cliffs. A CPU partner leaves its harvest here for you to sell."


## Crops and supplies only (weapons go in the house chest).
func menu_items(tab: int) -> Array:
	var b := _box()
	var out: Array = []
	for row: Dictionary in b._items_rows(tab):
		if not str(row["id"]).begins_with("w:"):
			out.append(row)
	return out


func _items_rows(tab: int) -> Array:
	return super.menu_items(tab)


func menu_press(id: Variant, action: StringName) -> void:
	if str(id).begins_with("w:"):
		return
	_peek = 0.8
	var b := _box()
	if b != self:
		b.menu_press(id, action)
		return
	super.menu_press(id, action)


## Host: drop items straight in (CPU teammates), and tell everyone.
func deposit(stuff: Dictionary) -> void:
	var b := _box()
	for res: StringName in stuff:
		b.items[res] = int(b.items.get(res, 0)) + int(stuff[res])
	b._sync.rpc(b.items, b.weapons)
