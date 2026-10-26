class_name Hotbar
extends Node
## The local player's hotbar, keys 1-8:
##   1-3  weapon slots: any weapons you carry, in the order you got them
##   4-6  pickup slots: whatever harvest you're carrying (corn, prickly pear, chili)
##   7    medicine: herbs (heal 50 HP)
##   8    water bucket
## Q drops the weapon in your hand (it lands at your feet for anyone to pick up).
## While the build tool (B) is open, number keys pick what to build instead.

signal changed

const PICKUP_ITEMS: Array[StringName] = [&"corn", &"prickly_pear", &"chili"]
const NAMES: Dictionary = {&"corn": "Corn", &"prickly_pear": "Pear", &"chili": "Chili", &"herbs": "Medicine", &"water": "Bucket"}

var player: Player
var selected := 0


func _ready() -> void:
	player.gun.loadout_changed.connect(func() -> void: changed.emit())
	Economy.resources_changed.connect(func(_c: int) -> void: changed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if GameState.menu_open or player.is_downed():
		return
	if event.is_action_pressed("drop_item"):
		_drop()
		get_viewport().set_input_as_handled()
		return
	if player.build_mode.active:
		return
	for i in 8:
		if event.is_action_pressed("select_%d" % (i + 1)):
			use_slot(i)
			get_viewport().set_input_as_handled()
			return


## The item id in slot i ("" when empty).
func slot_item(i: int) -> StringName:
	if i < 3:
		return player.gun.slots[i]
	if i < 6:
		var carried: Array[StringName] = []
		for item in PICKUP_ITEMS:
			if Economy.amount(_cliff(), item) > 0:
				carried.append(item)
		return carried[i - 3] if i - 3 < carried.size() else &""
	return &"herbs" if i == 6 else &"water"


func use_slot(i: int) -> void:
	var id := slot_item(i)
	if id == &"":
		return
	if i < 3:
		player.gun.equip(id)
	else:
		if id == &"herbs":
			player.vitals.use_medicine()
		player.gun.hold_item(id)
	selected = i
	changed.emit()


func _drop() -> void:
	var gun := player.gun
	if gun.holding != &"" or gun.def == null:
		Economy.notice.emit("Only weapons can be dropped. Switch to one first.")
		return
	player.net.drop_weapon(gun.def.id)
	changed.emit()


func _cliff() -> int:
	return player.cliff_id


## For the HUD: item id, label, count text, selected?
func slot_info(i: int) -> Dictionary:
	var id := slot_item(i)
	var info := {"id": id, "label": "", "count": "", "selected": false}
	if id == &"":
		return info
	if i < 3:
		info["label"] = Gun.weapon(id).display_name.split(" ")[0] if id != &"coach_shotgun" else "Shotgun"
		info["selected"] = player.gun.holding == &"" and player.gun.def != null and player.gun.def.id == id
		var lvl := player.gun.level_of(id)
		if lvl > 0:
			info["count"] = "+%d" % lvl
	else:
		info["label"] = NAMES.get(id, String(id))
		info["count"] = "x%d" % Economy.amount(_cliff(), id)
		info["selected"] = player.gun.holding == id
	return info
