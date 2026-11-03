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
## Maps: the host picks the map in the lobby (everyone sees it).
var _map_pick: OptionButton
var _map_label: Label
var _map_title: Label
var _map_card: PanelContainer
var _map_row: Control
var _connect_box: VBoxContainer
var _lobby_box: VBoxContainer
var _invite_card: Control
var _invite_code: Label
var _invite_note: Label
var _copy_btn: Button
var _solo_btn: Button
var _auto_ready := false
## The --host / --join test flags act on the first menu; back on the menu
## because the host left, it shows why instead of joining the gone game again.
static var _launched := false
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
	NetworkManager.server_closed.connect(func() -> void:
		NetworkManager.menu_message = ""
		_show_connect("The host left the game."))
	NetworkManager.ping_changed.connect(func() -> void:
		if _lobby_box.visible:
			_fill_roster())
	var flag_name := GameState.flag_value("--name")
	if flag_name != "":
		_name_edit.text = flag_name
	if GameState.flag_value("--port") != "": # Perk (test aid): pick the port for --host / --join
		_port_edit.text = GameState.flag_value("--port")
	var first := not _launched
	_launched = true
	if not NetworkManager.pending_join.is_empty():
		var pj := NetworkManager.pending_join
		NetworkManager.pending_join = {}
		_ip_edit.text = str(pj["address"])
		_port_edit.text = str(pj["port"])
		_on_join()
	elif not first and NetworkManager.menu_message != "":
		_show_connect(NetworkManager.menu_message)
		NetworkManager.menu_message = ""
	elif GameState.has_flag("--host") or _test_launch():
		_auto_ready = true
		_on_host()
		# --startafter=S: start the hosted game after S seconds on the menu (crash repro of a normal start).
		if GameState.flag_value("--startafter") != "":
			get_tree().create_timer(GameState.flag_value("--startafter").to_float()).timeout.connect(NetworkManager.start_game)
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
		_show_connect(NetworkManager.menu_message) # e.g. why the last game ended
		NetworkManager.menu_message = ""


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
	var host_btn := _button("Host Game")
	host_btn.pressed.connect(func() -> void:
		RunSave.pending = {}
		_on_host())
	_connect_box.add_child(host_btn)
	# Online (Epic lobby, works anywhere) or Direct (IP/LAN): the way out when online misbehaves.
	if NetworkManager.online != null:
		var via := OptionButton.new()
		via.focus_mode = Control.FOCUS_NONE
		via.add_item("Online (%s)" % NetworkManager.online.backend_name())
		via.add_item("Direct (IP/LAN)")
		via.selected = 0 if Settings.host_online else 1
		via.item_selected.connect(func(i: int) -> void:
			Settings.host_online = i == 0
			Settings.save_settings())
		_connect_box.add_child(UiStyle.row("Host via", via))
	var row := HBoxContainer.new()
	_ip_edit = _line_edit("Invite code (DUST-...) or host IP", "")
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_port_edit = _line_edit("Port", str(NetworkManager.DEFAULT_PORT))
	_port_edit.custom_minimum_size.x = 90
	row.add_child(_ip_edit)
	row.add_child(_port_edit)
	_connect_box.add_child(row)
	var join_btn := _button("Join Game")
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
	# Invite: the host's code (InviteCode) with a copy button, and where it works.
	_invite_card = UiStyle.panel("CardPanel")
	var inv_col := VBoxContainer.new()
	inv_col.add_theme_constant_override("separation", 4)
	_invite_card.add_child(inv_col)
	var inv_row := HBoxContainer.new()
	inv_row.add_theme_constant_override("separation", 8)
	inv_col.add_child(inv_row)
	_invite_code = UiStyle.title("", 22)
	_invite_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_row.add_child(_invite_code)
	var copy_btn := UiStyle.button("Copy Code")
	_copy_btn = copy_btn
	copy_btn.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(NetworkManager.invite_code())
		_status.text = "Invite code copied. Send it to your friend.")
	inv_row.add_child(copy_btn)
	_invite_note = _label("", 14, Color(0, 0, 0, 0))
	_invite_note.theme_type_variation = "SoftInkLabel"
	_invite_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_invite_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_col.add_child(_invite_note)
	_lobby_box.add_child(_invite_card)
	NetworkManager.invite_changed.connect(_refresh_invite)
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
	# Maps: the host picks the map; everyone sees which one on a themed card
	# (its name in the set's title face, the blurb in ink underneath).
	_map_card = UiStyle.panel("CardPanel")
	var map_col := VBoxContainer.new()
	map_col.add_theme_constant_override("separation", 2)
	_map_card.add_child(map_col)
	_map_title = UiStyle.title("", 20)
	map_col.add_child(_map_title)
	_map_label = _label("", 15, Color(0, 0, 0, 0))
	_map_label.theme_type_variation = "SoftInkLabel"
	map_col.add_child(_map_label)
	_lobby_box.add_child(_map_card)
	_map_pick = OptionButton.new()
	_map_pick.focus_mode = Control.FOCUS_NONE
	for id: StringName in MapDef.IDS:
		_map_pick.add_item("%s  (%d Players)" % [MapDef.display_name_of(id), MapDef.players_of(id)])
	_map_pick.item_selected.connect(func(i: int) -> void:
		if not NetworkManager.set_map(MapDef.IDS[i]):
			_status.text = "Too many players in the lobby for that map."
		_refresh())
	_map_row = UiStyle.row("Map", _map_pick)
	_lobby_box.add_child(_map_row)
	# Host: optional CPU teammates for the empty cliffs.
	_cpu_pick = OptionButton.new()
	for label: String in ["No CPU Teammates", "CPU Teammates: Low", "CPU Teammates: Medium", "CPU Teammates: High"]:
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
	if GameState.has_flag("--openledger"): # screenshots of the perk screen
		_ledger.open.call_deferred()
		if GameState.flag_value("--shot") != "":
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				get_viewport().get_texture().get_image().save_png(GameState.flag_value("--shot"))
				get_tree().quit())
	if GameState.has_flag("--opensecrets"): # screenshots (scenes/debug/theme_views.gd)
		_secrets.open.call_deferred()
	if GameState.flag_value("--lobbyshot") != "": # Maps: lobby screenshots (--host --menu --map=...)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(GameState.flag_value("--lobbyshot"))
			print("[lobby] saved ", GameState.flag_value("--lobbyshot"))
			get_tree().quit())


# Perk: opens the Rancher's Ledger (perks, loadout, wardrobe items).
func _ledger_button() -> Button:
	var b := _button("Rancher's Ledger")
	b.pressed.connect(func() -> void: _ledger.open())
	return b


## Debug/test launches go straight into a solo game, no menu clicks
## (except the tests that are about the menu itself).
func _test_launch() -> bool:
	return GameState.has_flag("--debug") and not GameState.has_flag("--join") and GameState.flag_value("--join") == "" 			and not GameState.has_flag("--menushot") and not GameState.has_flag("--menutab") 			and not GameState.has_flag("--menu")


func _on_host() -> void:
	NetworkManager.local_name = _player_name()
	if NetworkManager.wants_online() and NetworkManager.online_signing_in(): # a moment after launch: let online play finish signing in
		_status.text = "Signing in to online play..."
		await NetworkManager.wait_for_online()
	var err := NetworkManager.host(int(_port_edit.text))
	if err != OK:
		_show_connect("Could not host on port %s (error %d)." % [_port_edit.text, err])
		return
	_show_lobby("Hosting. Send your invite code to a friend, or start alone.")
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
	await _on_host()
	if not NetworkManager.is_online():
		return
	RunSave.pending = saved
	NetworkManager.set_map(StringName(str(saved.get("map", "canyon")))) # Maps: the saved run's map
	if int(saved["cpu_quality"]) >= 0:
		NetworkManager.set_cpu(int(saved["cpu_quality"]))
	_status.text = "Continuing your run at wave %d. Start alone or with the CPU, or wait for your partner." % int(saved["wave"])
	_refresh()


func _on_join() -> void:
	NetworkManager.local_name = _player_name()
	# Online invite (DUST-XXXXXX): found through the online backend's lobbies.
	if InviteCode.is_lobby_code(_ip_edit.text):
		if NetworkManager.join_code(_ip_edit.text) != OK:
			_show_connect(NetworkManager.last_error)
			return
		_show_connect("Finding %s..." % InviteCode.normalize_lobby_code(_ip_edit.text))
		return
	# The IP field also accepts a pasted invite ("IP:port").
	var parsed := NetworkManager.parse_invite(_ip_edit.text)
	if parsed.is_empty():
		_show_connect("Type your friend's invite code (DUST-...), or the host's IP address.")
		return
	if _ip_edit.text.contains(":") or InviteCode.looks_like_code(_ip_edit.text):
		_port_edit.text = str(parsed["port"])
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
	if not Brand.has_chosen() and RunSave.pending.is_empty() and not _test_launch() and GameState.flag_value("--lobbyshot") == "":
		_brands.open()


func _refresh_invite() -> void:
	if _invite_card == null:
		return
	_invite_card.visible = NetworkManager.is_online() and multiplayer.is_server()
	var code := NetworkManager.invite_code()
	var pending := code == "..." # the online lobby is still being made
	if NetworkManager.in_online_lobby():
		_invite_code.text = "Creating lobby..." if pending else "Lobby  " + code
	else:
		_invite_code.text = "Invite Code:  " + code
	if _copy_btn != null:
		_copy_btn.disabled = pending
	_invite_note.text = NetworkManager.invite_note()


func _refresh() -> void:
	_refresh_invite()
	var lines: PackedStringArray = []
	# Maps: one line per cliff of the chosen map, by cliff name.
	var map := MapDef.by_id(NetworkManager.map_id)
	for id: int in NetworkManager.players:
		var p: Dictionary = NetworkManager.players[id]
		var cliff := map.name_of(int(p["cliff"]))
		var tick := "[ready]" if bool(p["ready"]) else "[not ready]"
		lines.append("%s: %s %s%s" % [cliff, str(p["name"]), tick, Perks.roster_note(id)]) # Perk: perk count
	if NetworkManager.has_cpu():
		var free := NetworkManager.cpu_cliffs()
		for i in free.size():
			lines.append("%s: %s (CPU, %s) [ready]" % [map.name_of(free[i]), CpuTeammate.NAMES[mini(i, CpuTeammate.NAMES.size() - 1)], NetworkManager.CPU_QUALITY_NAMES[NetworkManager.cpu_quality]])
	elif NetworkManager.players.size() < NetworkManager.max_players():
		var waiting := NetworkManager.max_players() - NetworkManager.players.size()
		lines.append("(waiting for a partner...)" if waiting == 1 else "(room for %d more...)" % waiting)
	_roster.text = "\n".join(lines)
	_fill_roster()
	_solo_btn.visible = multiplayer.is_server() and NetworkManager.is_online()
	var cpus := NetworkManager.cpu_cliffs().size() if NetworkManager.has_cpu() else 0
	_solo_btn.text = ("Start With CPU Partner" if cpus == 1 else "Start With %d CPU Teammates" % cpus) if cpus > 0 else "Start Alone (Testing)"
	_cpu_pick.visible = multiplayer.is_server()
	_cpu_pick.selected = NetworkManager.cpu_quality + 1
	_map_row.visible = multiplayer.is_server()
	_map_pick.selected = MapDef.IDS.find(NetworkManager.map_id)
	_map_title.text = "%s  -  %d Cliffs" % [map.display_name, map.count()]
	_map_label.text = map.blurb


# ------------------------------------------------------------------ styling helpers

static func poster_style() -> StyleBox:
	return UiStyle.poster() # Theme


# Brand: roster rows with brand marks, and the "your brand" line.
func _fill_roster() -> void:
	if _roster_box == null:
		return
	for c in _roster_box.get_children():
		c.queue_free()
	var map := MapDef.by_id(NetworkManager.map_id) # Maps: rows by cliff name
	for id: int in NetworkManager.players:
		var p: Dictionary = NetworkManager.players[id]
		var tick := "ready" if bool(p["ready"]) else "not ready"
		_roster_box.add_child(_roster_row(Brand.mark_of(id), "%s: %s" % [map.name_of(int(p["cliff"])), str(p["name"])],
				"%s%s%s" % [tick, Perks.roster_note(id), NetworkManager.ping_note(id)], bool(p["ready"])))
	if NetworkManager.has_cpu():
		var free := NetworkManager.cpu_cliffs()
		for i in free.size():
			_roster_box.add_child(_roster_row(Brand.mark_of(Brand.CPU_KEY), "%s: %s" % [map.name_of(free[i]), CpuTeammate.NAMES[mini(i, CpuTeammate.NAMES.size() - 1)]],
					"CPU, %s  -  ready" % NetworkManager.CPU_QUALITY_NAMES[NetworkManager.cpu_quality], true))
	elif NetworkManager.players.size() < NetworkManager.max_players():
		var waiting := NetworkManager.max_players() - NetworkManager.players.size()
		var w := _label("(waiting for a partner...)" if waiting == 1 else "(room for %d more...)" % waiting, 15, Color(0, 0, 0, 0))
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
