class_name PauseMenu
extends CanvasLayer
## Esc menu: Resume, Controls (remapping), Graphics, Audio, Social (invite/join), Quit.
## In multiplayer the game keeps running behind the menu; your character just stops.
## `in_main_menu = true` turns it into a plain Settings window for the title screen.

signal closed

var in_main_menu := false
var _root: Control
var _tabs: TabContainer
var _vote_btn: Button


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_refresh_vote()
	if PauseVote.instance != null and not PauseVote.instance.votes_changed.is_connected(_refresh_vote):
		PauseVote.instance.votes_changed.connect(_refresh_vote)
	_root.visible = true
	GameState.menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The vote button shows how many have voted and whether you have.
func _refresh_vote() -> void:
	if _vote_btn == null or PauseVote.instance == null:
		return
	var v := PauseVote.instance
	_vote_btn.text = ("Cancel Pause Vote" if v.has_voted() else "Vote to Pause") + "  (%s)" % v.vote_count_text()


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
	UiStyle.fit(_root) # Theme: bigger on 1440p and up
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	# Theme: the set's frame, a header strap with the title, then the paper card.
	var frame := PanelContainer.new()
	frame.theme_type_variation = "FramePanel"
	frame.custom_minimum_size = Vector2(900, 620)
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)
	var head := PanelContainer.new()
	head.theme_type_variation = "HeaderPanel"
	outer.add_child(head)
	var header := HBoxContainer.new()
	head.add_child(header)
	var title := UiStyle.title("Settings" if in_main_menu else "Paused", 34, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)
	var resume := UiStyle.button("Back" if in_main_menu else "Resume")
	resume.custom_minimum_size.x = 150
	resume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(close)
	header.add_child(resume)
	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 16)
	col.add_child(_tabs)
	_add_tab("Controls", ControlsTab.new())
	_add_tab("Graphics", GraphicsTab.new())
	_add_tab("Audio", AudioTab.new())
	_add_tab("Debug", DebugTab.new())
	if not in_main_menu:
		_add_tab("Social", SocialTab.new())

	if not in_main_menu:
		var footer := HBoxContainer.new()
		footer.alignment = BoxContainer.ALIGNMENT_END
		footer.add_theme_constant_override("separation", 8)
		col.add_child(footer)
		var vote_btn := UiStyle.button("Vote to Pause")
		vote_btn.pressed.connect(func() -> void:
			if PauseVote.instance != null:
				PauseVote.instance.toggle_vote())
		footer.add_child(vote_btn)
		_vote_btn = vote_btn
		var wardrobe := UiStyle.button("Wardrobe")
		wardrobe.pressed.connect(func() -> void:
			close()
			Wardrobe.open())
		footer.add_child(wardrobe)
		var guide := UiStyle.button("Field Guide (J)")
		guide.pressed.connect(func() -> void:
			close()
			FieldGuide.open())
		footer.add_child(guide)
		var to_menu := UiStyle.button("Leave to Main Menu")
		to_menu.pressed.connect(_leave_to_menu)
		footer.add_child(to_menu)
		var quit := UiStyle.button("Quit Game")
		quit.pressed.connect(func() -> void: get_tree().quit())
		footer.add_child(quit)
	for b: Node in col.find_children("*", "Button", true, false):
		(b as Button).add_theme_font_size_override("font_size", 16)


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
