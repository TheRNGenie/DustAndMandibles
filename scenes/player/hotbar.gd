class_name Hotbar
extends Node
## The local player's hotbar, keys 1-8:
##   1-3  weapon slots: any weapons you carry, in the order you got them
##   4-6  pickup slots: whatever harvest you're carrying (corn, prickly pear, chili)
##   7    medicine: herbs (left click with them out heals 50 HP)
##   8    water bucket
##   9    Zippo lighter (always carried)
##   0    grappling hook launcher (always carried)
## Mouse wheel steps through the slots that hold something (left click with the
## medicine out takes a dose). Pressing the number
## of what you're already holding puts it away (empty hands).
## Q drops what's in your hand: a weapon, or one of the crop, medicine or water
## you're holding (it lands at your feet for anyone to pick up).
## While the build tool (B) is open, number keys pick what to build instead.

signal changed

const PICKUP_ITEMS: Array[StringName] = [&"corn", &"prickly_pear", &"chili"]
const NAMES: Dictionary = {&"corn": "Corn", &"prickly_pear": "Pear", &"chili": "Chili", &"herbs": "Medicine", &"water": "Bucket", &"grapple": "Grapple", &"lighter": "Zippo"}

const SLOTS := 10

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
	if event.is_action_pressed("fire") and player.gun.holding == &"herbs":
		player.vitals.use_medicine()
	if event.is_action_pressed("next_item") or event.is_action_pressed("prev_item"):
		_scroll(1 if event.is_action_pressed("next_item") else -1)
		get_viewport().set_input_as_handled()
		return
	for i in SLOTS:
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
	if i == 8:
		return &"lighter"
	if i == 9:
		return &"grapple"
	return &"herbs" if i == 6 else &"water"


## The next slot (either way) that holds something, wrapping round.
func _scroll(step: int) -> void:
	var start := selected if selected >= 0 else (0 if step > 0 else SLOTS - 1)
	for k in range(1, SLOTS + 1):
		var i := posmod(start + step * k, SLOTS)
		if slot_item(i) != &"":
			use_slot(i, false)
			return


func use_slot(i: int, toggle: bool = true) -> void:
	var id := slot_item(i)
	if id == &"":
		return
	# Pressing the slot you're already holding puts it away.
	if toggle and bool(slot_info(i)["selected"]):
		player.gun.hold_item(&"none")
		selected = -1
		changed.emit()
		return
	if i < 3:
		player.gun.equip(id)
	else:
		player.gun.hold_item(id)
	selected = i
	changed.emit()


func _drop() -> void:
	var gun := player.gun
	var held := gun.holding
	if held == &"none" or (held == &"" and gun.def == null):
		Economy.notice.emit("Your hands are empty.")
		return
	if held == &"grapple" or held == &"lighter":
		Economy.notice.emit("You always keep the %s." % NAMES[held].to_lower())
		return
	if held == &"":
		player.net.drop_weapon(gun.def.id)
	else:
		player.net.drop_item(held)
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
		var mods := WeaponMods.count(player.gun.code_of(id))
		info["count"] = ("+%d" % lvl if lvl > 0 else "") + "*".repeat(mods)
	else:
		info["label"] = NAMES.get(id, String(id))
		info["count"] = "" if id == &"grapple" or id == &"lighter" else "x%d" % Economy.amount(_cliff(), id)
		info["selected"] = player.gun.holding == id
	return info
