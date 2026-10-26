class_name PauseMenu
extends CanvasLayer
## Esc menu: Resume, Controls (remapping), Graphics, Audio, Social (invite/join), Quit.
## In multiplayer the game keeps running behind the menu; your character just stops.
## `in_main_menu = true` turns it into a plain Settings window for the title screen.

signal closed

var in_main_menu := false
var _root: Control
var _tabs: TabContainer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.visible = true
	GameState.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func select_tab(index: int) -> void:
	_tabs.current_tab = clampi(index, 0, _tabs.get_tab_count() - 1)


func close() -> void:
	_root.visible = false
	GameState.menu_open = false
	if not in_main_menu:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if in_main_menu:
		return
	if event.is_action_pressed("pause_menu"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var poster := PanelContainer.new()
	poster.add_theme_stylebox_override("panel", UiStyle.poster())
	poster.custom_minimum_size = Vector2(760, 560)
	center.add_child(poster)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	poster.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)
	var title := UiStyle.label("SETTINGS" if in_main_menu else "PAUSED", 30, Palette.OUTLINE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)
	var resume := UiStyle.button("Back" if in_main_menu else "Resume")
	resume.custom_minimum_size.x = 140
	resume.pressed.connect(close)
	header.add_child(resume)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_add_tab("Controls", ControlsTab.new())
	_add_tab("Graphics", GraphicsTab.new())
	_add_tab("Audio", AudioTab.new())
	if not in_main_menu:
		_add_tab("Social", SocialTab.new())

	if not in_main_menu:
		var footer := HBoxContainer.new()
		footer.alignment = BoxContainer.ALIGNMENT_END
		footer.add_theme_constant_override("separation", 10)
		col.add_child(footer)
		var to_menu := UiStyle.button("Leave to main menu")
		to_menu.pressed.connect(_leave_to_menu)
		footer.add_child(to_menu)
		var quit := UiStyle.button("Quit game")
		quit.pressed.connect(func() -> void: get_tree().quit())
		footer.add_child(quit)


func _add_tab(tab_name: String, content: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_tabs.add_child(scroll)


func _leave_to_menu() -> void:
	GameState.menu_open = false
	NetworkManager.leave()
	GameState.reset()
	get_tree().change_scene_to_file(NetworkManager.MENU_SCENE)
