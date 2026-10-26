class_name Hotbar
extends Node
## The local player's hotbar, keys 1-8: 1 revolver, 2 lever-action rifle,
## 3 coach shotgun (once bought), 4 water bucket, 5 corn, 6 prickly pear,
## 7 chili, 8 herbs. Counts come from your stockpile. Selecting the bucket or a
## vegetable puts your gun away and shows it in your hand; herbs heal you when
## used (press 8 again while holding them, or once if you're hurt).
## While the build tool (B) is open, number keys pick what to build instead.

signal changed

const SLOTS: Array[Dictionary] = [
	{"kind": "weapon", "id": &"revolver", "label": "Revolver"},
	{"kind": "weapon", "id": &"lever_rifle", "label": "Lever rifle"},
	{"kind": "weapon", "id": &"coach_shotgun", "label": "Shotgun"},
	{"kind": "item", "id": &"water", "label": "Bucket"},
	{"kind": "item", "id": &"corn", "label": "Corn"},
	{"kind": "item", "id": &"prickly_pear", "label": "Pear"},
	{"kind": "item", "id": &"chili", "label": "Chili"},
	{"kind": "item", "id": &"herbs", "label": "Herbs"},
]

var player: Player
var selected := 0


func _ready() -> void:
	player.gun.loadout_changed.connect(func() -> void: changed.emit())
	Economy.resources_changed.connect(func(_c: int) -> void: changed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if GameState.menu_open or player.is_downed() or player.build_mode.active:
		return
	for i in SLOTS.size():
		if event.is_action_pressed("select_%d" % (i + 1)):
			use_slot(i)
			get_viewport().set_input_as_handled()
			return


func use_slot(i: int) -> void:
	var slot: Dictionary = SLOTS[i]
	var id: StringName = slot["id"]
	if str(slot["kind"]) == "weapon":
		if player.gun.owns(id):
			player.gun.equip(id)
			selected = i
		else:
			Economy.notice.emit("You don't own the %s yet: buy it at the Oasis gunsmith." % str(slot["label"]).to_lower())
	else:
		if id == &"herbs" and (selected == i or player.vitals.hp < PlayerVitals.MAX_HP - 1.0):
			player.vitals.use_medicine()
		selected = i
		player.gun.hold_item(id)
	changed.emit()


## For the HUD: label, count text, available?, selected?
func slot_info(i: int) -> Dictionary:
	var slot: Dictionary = SLOTS[i]
	var id: StringName = slot["id"]
	var info := {"label": slot["label"], "count": "", "available": true, "selected": false}
	if str(slot["kind"]) == "weapon":
		info["available"] = player.gun.owns(id)
		info["selected"] = player.gun.holding == &"" and player.gun.def != null and player.gun.def.id == id
		var lvl := player.gun.level_of(id)
		if lvl > 0:
			info["count"] = "+%d" % lvl
	else:
		var n := Economy.amount(player.cliff_id, id)
		info["count"] = "x%d" % n
		info["available"] = n > 0
		info["selected"] = player.gun.holding == id
	return info
