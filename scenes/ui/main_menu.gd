extends Control
## Main menu and lobby: Host / Join by IP, player roster, Ready toggle.
## Flags: --host or --join[=ip] connect automatically and mark you ready. --name=X sets your name.

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: LineEdit
var _status: Label
var _roster: Label
var _ready_btn: CheckButton
var _cpu_pick: OptionButton
var _connect_box: VBoxContainer
var _lobby_box: VBoxContainer
var _solo_btn: Button
var _auto_ready := false
var _settings: PauseMenu
var _ledger: LedgerScreen # Perk: Rancher's Ledger screen
var _brands: BrandScreen # Brand: the branding-iron pick screen
var _secrets: SecretsScreen
var _cinematic: MenuCinematic
var _brand_row: HBoxContainer
var _roster_box: VBoxContainer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.reset()
	# [Foundation] --continue (tests): resume the saved run on the automatic start.
	if GameState.has_flag("--continue"):
		RunSave.pending = RunSave.read()
	_build_ui()
	NetworkManager.players_changed.connect(_refresh)
	NetworkManager.connected_to_host.connect(_on_connected)
	NetworkManager.connection_failed.connect(func(reason: String) -> void: _show_connect(reason))
	NetworkManager.server_closed.connect(func() -> void: _show_connect("The host left the game."))
	var flag_name := GameState.flag_value("--name")
	if flag_name != "":
		_name_edit.text = flag_name
	if GameState.flag_value("--port") != "": # Perk (test aid): pick the port for --host / --join
		_port_edit.text = GameState.flag_value("--port")
	if not NetworkManager.pending_join.is_empty():
		var pj := NetworkManager.pending_join
		NetworkManager.pending_join = {}
		_ip_edit.text = str(pj["address"])
		_port_edit.text = str(pj["port"])
		_on_join()
	elif GameState.has_flag("--host") or _test_launch():
		_auto_ready = true
		_on_host()
		# --cpu=low|medium|high: start with a CPU partner (tests).
		var cq := ["low", "medium", "high"].find(GameState.flag_value("--cpu").to_lower())
		if cq >= 0:
			NetworkManager.set_cpu(cq)
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
	UiStyle.fit(self) # Theme: bigger on 1440p and up
	# Theme: the canyon on film (no run, no bugs) fills the screen behind a menu column on the left.
	if not GameState.has_flag("--nocinematic") and not _test_launch():
		_cinematic = MenuCinematic.new()
		add_child(_cinematic)
		add_child(_cinematic.fade)
	else:
		add_child(UiStyle.backdrop())
	var column := PanelContainer.new()
	column.theme_type_variation = "FramePanel"
	column.anchor_left = 0.0
	column.anchor_right = 0.31
	column.anchor_top = 0.0
	column.anchor_bottom = 1.0
	column.offset_left = 18
	column.offset_top = 18
	column.offset_bottom = -18
	column.custom_minimum_size.x = 470
	add_child(column)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	column.add_child(outer)
	var head := PanelContainer.new()
	head.theme_type_variation = "HeaderPanel"
	outer.add_child(head)
	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override("separation", 0)
	head.add_child(hcol)
	var wanted := UiStyle.title("Wanted: Help", 18, true)
	wanted.add_theme_color_override("font_color", UiStyle.c("hud"))
	hcol.add_child(wanted)
	hcol.add_child(UiStyle.title("Dust & Mandibles", 46, true))
	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(card)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	card.add_child(page)
	var tag := _label("Defend the Homestead", 18, Color(0, 0, 0, 0))
	tag.theme_type_variation = "SoftInkLabel"
	page.add_child(tag)
	page.add_child(UiStyle.divider(360))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(col)

	_name_edit = _line_edit("Your name", "Rancher")
	col.add_child(_name_edit)

	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 10)
	col.add_child(_connect_box)
	# [Foundation] Continue the autosaved run (host it; start alone, with a CPU, or wait for a partner).
	var saved := RunSave.read()
	if not saved.is_empty():
		var cont := _button("Continue Last Run (Wave %d)" % int(saved["wave"]))
		cont.pressed.connect(func() -> void: _on_continue())
		_connect_box.add_child(cont)
	var host_btn := _button("Host Game (West Cliff)")
	host_btn.pressed.connect(func() -> void:
		RunSave.pending = {}
		_on_host())
	_connect_box.add_child(host_btn)
	var row := HBoxContainer.new()
	_ip_edit = _line_edit("Host IP or invite", NetworkManager.DEFAULT_ADDRESS)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_port_edit = _line_edit("Port", str(NetworkManager.DEFAULT_PORT))
	_port_edit.custom_minimum_size.x = 90
	row.add_child(_ip_edit)
	row.add_child(_port_edit)
	_connect_box.add_child(row)
	var join_btn := _button("Join Game (East Cliff)")
	join_btn.pressed.connect(_on_join)
	_connect_box.add_child(join_btn)
	_connect_box.add_child(_ledger_button()) # Perk
	var secrets_btn := _button("Secrets") # Theme: code entry for secret cosmetics
	secrets_btn.pressed.connect(func() -> void: _secrets.open())
	_connect_box.add_child(secrets_btn)
	var settings_btn := _button("Settings")
	settings_btn.pressed.connect(func() -> void: _settings.open())
	_connect_box.add_child(settings_btn)
	var quit_btn := _button("Quit")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_connect_box.add_child(quit_btn)

	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 8)
	col.add_child(_lobby_box)
	_roster = _label("", 18, Color(0, 0, 0, 0))
	_roster.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_roster.visible = false
	_lobby_box.add_child(_roster)
	# Brand: the roster as rows, each rider's brand mark beside their name.
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 4)
	_lobby_box.add_child(_roster_box)
	_brand_row = HBoxContainer.new()
	_brand_row.add_theme_constant_override("separation", 8)
	_lobby_box.add_child(_brand_row)
	_ready_btn = CheckButton.new()
	_ready_btn.text = "Ready"
	_ready_btn.toggled.connect(func(on: bool) -> void: NetworkManager.set_ready(on))
	_lobby_box.add_child(_ready_btn)
	# Host: an optional CPU partner for the empty cliff.
	_cpu_pick = OptionButton.new()
	for label: String in ["No CPU Partner", "CPU Partner: Low", "CPU Partner: Medium", "CPU Partner: High"]:
		_cpu_pick.add_item(label)
	_cpu_pick.selected = NetworkManager.cpu_quality + 1
	_cpu_pick.item_selected.connect(func(i: int) -> void: NetworkManager.set_cpu(i - 1))
	_lobby_box.add_child(_cpu_pick)
	_solo_btn = _button("Start Alone (Testing)")
	_solo_btn.pressed.connect(func() -> void: NetworkManager.start_game())
	_lobby_box.add_child(_solo_btn)
	_lobby_box.add_child(_ledger_button()) # Perk
	var leave_btn := _button("Leave")
	leave_btn.pressed.connect(func() -> void:
		RunSave.pending = {}
		NetworkManager.leave()
		_show_connect(""))
	_lobby_box.add_child(leave_btn)

	_status = _label("", 15, Color(0, 0, 0, 0))
	_status.theme_type_variation = "SoftInkLabel"
	page.add_child(_status)

	_settings = PauseMenu.new()
	_settings.in_main_menu = true
	add_child(_settings)
	_ledger = LedgerScreen.new() # Perk
	add_child(_ledger)
	Perks.loadouts_changed.connect(_refresh)
	_secrets = SecretsScreen.new() # Theme: Secrets
	add_child(_secrets)
	_brands = BrandScreen.new() # Brand
	add_child(_brands)
	_brands.picked.connect(func(_id: StringName) -> void: _refresh())
	Brand.changed.connect(_refresh)
	if GameState.has_flag("--opensecrets"): # screenshots (scenes/debug/theme_views.gd)
		_secrets.open.call_deferred()


# Perk: opens the Rancher's Ledger (perks, loadout, wardrobe items).
func _ledger_button() -> Button:
	var b := _button("Rancher's Ledger")
	b.pressed.connect(func() -> void: _ledger.open())
	return b


## Debug/test launches go straight into a solo game, no menu clicks
## (except the tests that are about the menu itself).
func _test_launch() -> bool:
	return GameState.has_flag("--debug") and not GameState.has_flag("--join") 			and not GameState.has_flag("--menushot") and not GameState.has_flag("--menutab") 			and not GameState.has_flag("--menu")


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
	if GameState.has_flag("--solo") or _test_launch():
		NetworkManager.start_game.call_deferred()


## [Foundation] Host the saved run: the lobby starts it from its saved wave.
func _on_continue() -> void:
	var saved := RunSave.read()
	if saved.is_empty():
		_show_connect("The saved run couldn't be read.")
		return
	_on_host()
	if not NetworkManager.is_online():
		return
	RunSave.pending = saved
	if int(saved["cpu_quality"]) >= 0:
		NetworkManager.set_cpu(int(saved["cpu_quality"]))
	_status.text = "Continuing your run at wave %d. Start alone or with the CPU, or wait for your partner." % int(saved["wave"])
	_refresh()


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
	# Brand: every run starts at the branding irons (a continued run brings its brands back).
	if not Brand.has_chosen() and RunSave.pending.is_empty() and not _test_launch():
		_brands.open()


func _refresh() -> void:
	var lines: PackedStringArray = []
	for id: int in NetworkManager.players:
		var p: Dictionary = NetworkManager.players[id]
		var cliff := "West" if int(p["cliff"]) == WorldLayout.WEST else "East"
		var tick := "[ready]" if bool(p["ready"]) else "[not ready]"
		lines.append("%s cliff: %s %s%s" % [cliff, str(p["name"]), tick, Perks.roster_note(id)]) # Perk: perk count
	if NetworkManager.has_cpu():
		var cpu_side := "West" if NetworkManager.cpu_cliff() == WorldLayout.WEST else "East"
		lines.append("%s cliff: %s (CPU, %s) [ready]" % [cpu_side, CpuTeammate.NAME, NetworkManager.CPU_QUALITY_NAMES[NetworkManager.cpu_quality]])
	elif NetworkManager.players.size() < NetworkManager.MAX_PLAYERS:
		lines.append("(waiting for a partner...)")
	_roster.text = "\n".join(lines)
	_fill_roster()
	_solo_btn.visible = multiplayer.is_server() and NetworkManager.is_online()
	_solo_btn.text = "Start With CPU Partner" if NetworkManager.has_cpu() else "Start Alone (Testing)"
	_cpu_pick.visible = multiplayer.is_server()
	_cpu_pick.selected = NetworkManager.cpu_quality + 1


# ------------------------------------------------------------------ styling helpers

static func poster_style() -> StyleBox:
	return UiStyle.poster() # Theme


# Brand: roster rows with brand marks, and the "your brand" line.
func _fill_roster() -> void:
	if _roster_box == null:
		return
	for c in _roster_box.get_children():
		c.queue_free()
	for id: int in NetworkManager.players:
		var p: Dictionary = NetworkManager.players[id]
		var cliff := "West" if int(p["cliff"]) == WorldLayout.WEST else "East"
		var tick := "ready" if bool(p["ready"]) else "not ready"
		_roster_box.add_child(_roster_row(Brand.mark_of(id), "%s Cliff: %s" % [cliff, str(p["name"])],
				"%s%s" % [tick, Perks.roster_note(id)], bool(p["ready"])))
	if NetworkManager.has_cpu():
		var cpu_side := "West" if NetworkManager.cpu_cliff() == WorldLayout.WEST else "East"
		_roster_box.add_child(_roster_row(Brand.mark_of(Brand.CPU_KEY), "%s Cliff: %s" % [cpu_side, CpuTeammate.NAME],
				"CPU, %s  -  ready" % NetworkManager.CPU_QUALITY_NAMES[NetworkManager.cpu_quality], true))
	elif NetworkManager.players.size() < NetworkManager.MAX_PLAYERS:
		var w := _label("(waiting for a partner...)", 15, Color(0, 0, 0, 0))
		w.theme_type_variation = "SoftInkLabel"
		_roster_box.add_child(w)
	for c in _brand_row.get_children():
		c.queue_free()
	_brand_row.add_child(BrandMark.make(Brand.local if Brand.has_chosen() else BrandTable.NONE, 30, UiStyle.ink()))
	var mine := _label("Your brand: %s" % (BrandTable.name_of(Brand.local) if Brand.has_chosen() else "not chosen yet"), 16, Color(0, 0, 0, 0))
	mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brand_row.add_child(mine)
	var change := _button("Change Brand" if Brand.has_chosen() else "Choose Brand")
	change.custom_minimum_size = Vector2(170, 44)
	change.add_theme_font_size_override("font_size", 16)
	change.disabled = not Brand.editable()
	change.pressed.connect(func() -> void: _brands.open())
	_brand_row.add_child(change)


func _roster_row(mark: StringName, who: String, note: String, is_ready: bool) -> Control:
	var r := PanelContainer.new()
	r.theme_type_variation = "CardPanel"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	r.add_child(h)
	var m := BrandMark.make(mark if mark != &"" else BrandTable.NONE, 28, UiStyle.ink())
	m.modulate.a = 1.0 if mark != &"" else 0.35
	h.add_child(m)
	var name_l := _label(who, 17, Color(0, 0, 0, 0))
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.clip_text = true
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_l)
	var n := _label(note, 14, Color(0, 0, 0, 0))
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.theme_type_variation = "GoodLabel" if is_ready else "SoftInkLabel"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return r


# ------------------------------------------------------------------ styling helpers

func _label(text: String, size: int, color: Color) -> Label:
	return UiStyle.label(text, size, color) # Theme: a zero colour follows the set's ink


func _line_edit(placeholder: String, value: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.custom_minimum_size.y = 40
	e.add_theme_font_size_override("font_size", 17)
	return e


func _button(text: String) -> Button:
	var b := UiStyle.button(text) # Theme: big title-screen buttons
	b.custom_minimum_size.y = 56
	b.add_theme_font_size_override("font_size", 21)
	return b
