class_name ControlsTab
extends VBoxContainer
## Controls tab: mouse sensitivity, invert Y, and click-to-remap for each action.

var _waiting_action := ""
var _buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiStyle.row("Mouse sensitivity", UiStyle.slider(0.2, 3.0, 0.05,
			Settings.mouse_sensitivity / 0.0022, "%.2fx",
			func(v: float) -> void: Settings.set_value("mouse_sensitivity", v * 0.0022))))
	add_child(UiStyle.row("Invert mouse Y", UiStyle.check(Settings.invert_y,
			func(on: bool) -> void: Settings.set_value("invert_y", on))))
	add_child(HSeparator.new())
	add_child(UiStyle.label("Click a binding, then press the new key or mouse button. Esc cancels.", 14, Palette.WOOD_DARK))
	for action: String in Settings.REMAPPABLE:
		var b := UiStyle.button("")
		b.pressed.connect(_start_rebind.bind(action))
		_buttons[action] = b
		add_child(UiStyle.row(str(Settings.REMAPPABLE[action]), b))
	var reset := UiStyle.button("Reset all to defaults")
	reset.pressed.connect(func() -> void:
		Settings.reset_bindings()
		_refresh())
	add_child(reset)
	_refresh()


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
