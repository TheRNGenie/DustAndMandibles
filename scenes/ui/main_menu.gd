extends Control
## Main menu and lobby: Host / Join by IP, player roster, Ready toggle.
## Flags: --host or --join[=ip] connect automatically and mark you ready. --name=X sets your name.

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: LineEdit
var _status: Label
var _roster: Label
var _ready_btn: CheckButton
var _connect_box: VBoxContainer
var _lobby_box: VBoxContainer
var _solo_btn: Button
var _auto_ready := false
var _settings: PauseMenu


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.reset()
	_build_ui()
	NetworkManager.players_changed.connect(_refresh)
	NetworkManager.connected_to_host.connect(_on_connected)
	NetworkManager.connection_failed.connect(func(reason: String) -> void: _show_connect(reason))
	NetworkManager.server_closed.connect(func() -> void: _show_connect("The host left the game."))
	var flag_name := GameState.flag_value("--name")
	if flag_name != "":
		_name_edit.text = flag_name
	if not NetworkManager.pending_join.is_empty():
		var pj := NetworkManager.pending_join
		NetworkManager.pending_join = {}
		_ip_edit.text = str(pj["address"])
		_port_edit.text = str(pj["port"])
		_on_join()
	elif GameState.has_flag("--host"):
		_auto_ready = true
		_on_host()
	elif GameState.has_flag("--join") or GameState.flag_value("--join") != "":
		_auto_ready = true
		var ip := GameState.flag_value("--join")
		if ip != "":
			_ip_edit.text = ip
		_on_join()
	else:
		_show_connect("")


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.SKY_HORIZON.lerp(Palette.ROCK_C, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var poster := PanelContainer.new()
	poster.add_theme_stylebox_override("panel", poster_style())
	poster.custom_minimum_size = Vector2(460, 0)
	center.add_child(poster)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	poster.add_child(col)

	col.add_child(_label("WANTED: HELP", 20, Palette.ROCK_B))
	col.add_child(_label("DUST & MANDIBLES", 40, Palette.OUTLINE))
	col.add_child(_label("Hold your cliff. Cover your partner's.", 16, Palette.WOOD_DARK))
	col.add_child(HSeparator.new())

	_name_edit = _line_edit("Your name", "Rancher")
	col.add_child(_name_edit)

	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 8)
	col.add_child(_connect_box)
	var host_btn := _button("Host game (west cliff)")
	host_btn.pressed.connect(_on_host)
	_connect_box.add_child(host_btn)
	var row := HBoxContainer.new()
	_ip_edit = _line_edit("Host IP or invite", NetworkManager.DEFAULT_ADDRESS)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_port_edit = _line_edit("Port", str(NetworkManager.DEFAULT_PORT))
	_port_edit.custom_minimum_size.x = 90
	row.add_child(_ip_edit)
	row.add_child(_port_edit)
	_connect_box.add_child(row)
	var join_btn := _button("Join game (east cliff)")
	join_btn.pressed.connect(_on_join)
	_connect_box.add_child(join_btn)
	var settings_btn := _button("Settings")
	settings_btn.pressed.connect(func() -> void: _settings.open())
	_connect_box.add_child(settings_btn)
	var quit_btn := _button("Quit")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_connect_box.add_child(quit_btn)

	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 8)
	col.add_child(_lobby_box)
	_roster = _label("", 18, Palette.OUTLINE)
	_roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_lobby_box.add_child(_roster)
	_ready_btn = CheckButton.new()
	_ready_btn.text = "Ready"
	_ready_btn.add_theme_color_override("font_color", Palette.OUTLINE)
	_ready_btn.toggled.connect(func(on: bool) -> void: NetworkManager.set_ready(on))
	_lobby_box.add_child(_ready_btn)
	_solo_btn = _button("Start alone (testing)")
	_solo_btn.pressed.connect(func() -> void: NetworkManager.start_game())
	_lobby_box.add_child(_solo_btn)
	var leave_btn := _button("Leave")
	leave_btn.pressed.connect(func() -> void:
		NetworkManager.leave()
		_show_connect(""))
	_lobby_box.add_child(leave_btn)

	_status = _label("", 15, Palette.ROCK_B)
	col.add_child(_status)

	_settings = PauseMenu.new()
	_settings.in_main_menu = true
	add_child(_settings)


func _on_host() -> void:
	NetworkManager.local_name = _player_name()
	var err := NetworkManager.host(int(_port_edit.text))
	if err != OK:
		_show_connect("Could not host on port %s (error %d)." % [_port_edit.text, err])
		return
	_show_lobby("Hosting on port %s. Waiting for your partner..." % _port_edit.text)
	if _auto_ready:
		_ready_btn.set_pressed_no_signal(true)
		NetworkManager.set_ready.call_deferred(true)
	if GameState.has_flag("--solo"):
		NetworkManager.start_game.call_deferred()


func _on_join() -> void:
	NetworkManager.local_name = _player_name()
	# The IP field also accepts a pasted invite ("IP:port").
	var parsed := NetworkManager.parse_invite(_ip_edit.text)
	if parsed.is_empty():
		_show_connect("Enter the host's IP address or paste their invite.")
		return
	if _ip_edit.text.contains(":"):
		_port_edit.text = str(parsed["port"])
		_ip_edit.text = str(parsed["address"])
	var err := NetworkManager.join(str(parsed["address"]), int(_port_edit.text))
	if err != OK:
		_show_connect("Could not start connecting (error %d)." % err)
		return
	_show_connect("Connecting to %s..." % _ip_edit.text)


func _on_connected() -> void:
	_show_lobby("Connected.")
	if _auto_ready:
		_ready_btn.button_pressed = true


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Rancher"


func _show_connect(message: String) -> void:
	_connect_box.visible = true
	_lobby_box.visible = false
	_ready_btn.set_pressed_no_signal(false)
	_status.text = message


func _show_lobby(message: String) -> void:
	_connect_box.visible = false
	_lobby_box.visible = true
	_status.text = message
	_refresh()


func _refresh() -> void:
	var lines: PackedStringArray = []
	for id: int in NetworkManager.players:
		var p: Dictionary = NetworkManager.players[id]
		var cliff := "West" if int(p["cliff"]) == WorldLayout.WEST else "East"
		var tick := "[ready]" if bool(p["ready"]) else "[not ready]"
		lines.append("%s cliff: %s %s" % [cliff, str(p["name"]), tick])
	if NetworkManager.players.size() < NetworkManager.MAX_PLAYERS:
		lines.append("(waiting for a partner...)")
	_roster.text = "\n".join(lines)
	_solo_btn.visible = multiplayer.is_server() and NetworkManager.is_online()


# ------------------------------------------------------------------ styling helpers

static func poster_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.BONE
	sb.border_color = Palette.WOOD_DARK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(6, 6)
	sb.set_content_margin_all(28)
	return sb


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _line_edit(placeholder: String, value: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	return e


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	var normal := Hud.wood_sign_style()
	normal.set_content_margin_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.WOOD.lightened(0.12)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", Palette.BONE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b
