class_name ControlsTab
extends VBoxContainer
## Controls tab: mouse sensitivity, invert Y, and click-to-remap for each action.

var _waiting_action := ""
var _buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiStyle.section("Mouse"))
	add_child(UiStyle.row("Mouse sensitivity", UiStyle.slider(0.2, 3.0, 0.05,
			Settings.mouse_sensitivity / 0.0022, "%.2fx",
			func(v: float) -> void: Settings.set_value("mouse_sensitivity", v * 0.0022))))
	add_child(UiStyle.row("Invert mouse Y", UiStyle.check(Settings.invert_y,
			func(on: bool) -> void: Settings.set_value("invert_y", on))))
	add_child(UiStyle.section("Camera"))
	var cam := OptionButton.new()
	cam.add_item("First Person")
	cam.add_item("Third Person")
	cam.selected = 1 if Settings.build_cam_third else 0
	cam.item_selected.connect(func(i: int) -> void: Settings.set_value("build_cam_third", i == 1))
	add_child(UiStyle.row("Build Camera", cam))
	add_child(UiStyle.note("Remembered: switching views in build mode (%s) changes this too." % KeyHints.key_for("build_camera")))
	add_child(UiStyle.section("Grapple"))
	var swing := OptionButton.new()
	swing.add_item("Hold")
	swing.add_item("Toggle")
	swing.selected = 1 if Settings.grapple_swing_toggle else 0
	swing.item_selected.connect(func(i: int) -> void: Settings.set_value("grapple_swing_toggle", i == 1))
	add_child(UiStyle.row("Right-Click Swing", swing))
	add_child(UiStyle.note("Hold: swing while the button's down. Toggle: click to hook on and swing, click again (or jump) to let go."))
	add_child(UiStyle.section("Key Bindings"))
	add_child(UiStyle.note("Click a binding, then press the new key or mouse button. Esc cancels."))
	for action: String in Settings.REMAPPABLE:
		var b := UiStyle.button("")
		b.pressed.connect(_start_rebind.bind(action))
		_buttons[action] = b
		add_child(UiStyle.row(str(Settings.REMAPPABLE[action]), b))
	var reset := UiStyle.button("Reset All to Defaults")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.pressed.connect(func() -> void:
		Settings.reset_bindings()
		_refresh())
	add_child(reset)
	_add_progress_reset()
	_refresh()


## The very bottom: wipe the Rancher's Ledger (Notches, perks, bought wardrobe items)
## and every secret code entered (Perks.reset_progress). Two clicks, menu only.
func _add_progress_reset() -> void:
	add_child(UiStyle.section("Progress"))
	add_child(UiStyle.note("Reset Progress clears your Notches, every perk and wardrobe item bought with them, and every secret code you've entered. Story chapters and run records stay. It can't be undone."))
	var status := UiStyle.note("", 14)
	var wipe := UiStyle.button("Reset Progress")
	wipe.size_flags_horizontal = Control.SIZE_SHRINK_END
	var armed := [false]
	wipe.pressed.connect(func() -> void:
		if not Perks.loadout_editable():
			status.text = "Finish or leave the run first: progress can only be reset from the main menu."
			return
		if not armed[0]:
			armed[0] = true
			wipe.text = "Click Again to Reset Everything"
			status.text = "Are you sure? This wipes your Notches, perks, bought wardrobe items and codes."
			get_tree().create_timer(5.0).timeout.connect(func() -> void:
				if is_instance_valid(wipe) and armed[0]:
					armed[0] = false
					wipe.text = "Reset Progress"
					status.text = "")
			return
		armed[0] = false
		wipe.text = "Reset Progress"
		status.text = "Progress reset: 0 Notches, no perks, no codes." if Perks.reset_progress() else "Couldn't reset during a run."
	)
	add_child(wipe)
	add_child(status)


func _start_rebind(action: String) -> void:
	_waiting_action = action
	(_buttons[action] as Button).text = "Press a key..."


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not is_visible_in_tree():
		return
	var accept := false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_waiting_action = ""
			_refresh()
			get_viewport().set_input_as_handled()
			return
		accept = true
	elif event is InputEventMouseButton and event.is_pressed():
		accept = true
	if accept:
		Settings.rebind(_waiting_action, event)
		_waiting_action = ""
		_refresh()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for action: String in _buttons:
		(_buttons[action] as Button).text = Settings.binding_label(action)
