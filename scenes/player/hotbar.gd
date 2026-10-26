class_name Hotbar
extends Node
## The local player's hotbar, keys 1-8: 1 revolver, 2 lever-action rifle, 3 coach
## shotgun (once bought), 4 herbal remedy (heals with one herb), 5 build tool.
## 6-8 are free for later items. While the build tool is open, number keys pick
## what to build instead.

signal changed

const SLOTS: Array[Dictionary] = [
	{"kind": "weapon", "id": &"revolver", "label": "Revolver"},
	{"kind": "weapon", "id": &"lever_rifle", "label": "Lever rifle"},
	{"kind": "weapon", "id": &"coach_shotgun", "label": "Shotgun"},
	{"kind": "medicine", "id": &"herbs", "label": "Herbs"},
	{"kind": "build", "id": &"", "label": "Build"},
	{"kind": "empty", "id": &"", "label": ""},
	{"kind": "empty", "id": &"", "label": ""},
	{"kind": "empty", "id": &"", "label": ""},
]

var player: Player
var selected := 0


func _ready() -> void:
	player.gun.loadout_changed.connect(func() -> void: changed.emit())
	player.build_mode.changed.connect(func() -> void: changed.emit())
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
	match str(slot["kind"]):
		"weapon":
			if player.gun.owns(slot["id"]):
				player.gun.equip(slot["id"])
				selected = i
			else:
				Economy.notice.emit("You don't own the %s yet: buy it at the gunsmith." % str(slot["label"]).to_lower())
		"medicine":
			player.vitals.use_medicine()
		"build":
			player.build_mode.toggle()
	changed.emit()


## For the HUD: label, count text, available?, selected?
func slot_info(i: int) -> Dictionary:
	var slot: Dictionary = SLOTS[i]
	var info := {"label": slot["label"], "count": "", "available": true, "selected": false}
	match str(slot["kind"]):
		"weapon":
			info["available"] = player.gun.owns(slot["id"])
			info["selected"] = player.gun.def != null and player.gun.def.id == slot["id"]
			var lvl := player.gun.level_of(slot["id"])
			if lvl > 0:
				info["count"] = "+%d" % lvl
		"medicine":
			var cid := player.cliff_id
			var n := Economy.amount(cid, &"herbs")
			info["count"] = "x%d" % n
			info["available"] = n > 0
		"build":
			info["selected"] = player.build_mode.active
		"empty":
			info["available"] = false
	return info
