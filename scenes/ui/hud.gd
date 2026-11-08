class_name Hud
extends CanvasLayer
## HUD root: crosshair, ammo sign, phase banner, canyon-fall message and the F3 debug
## overlay, plus HudStatus (health, resources, Homesteads) and HudFeed (kill feed, prompts).

var _ammo_label: Label
var _center_label: Label
var _blackout: ColorRect
var _debug_label: Label
var _speed_lines: SpeedLines
var combo: HudCombo
var _wave_card: HudWavePreview
var _crosshair: Control
var _scope: ScopeOverlay
var _phase_label: Label
var _phase_icon: PhaseIcon
var _hint_label: Label
## The plaque's figures: the wave number, and one live figure with its caption.
var _wave_box: VBoxContainer
var _wave_num: Label
var _stat_box: VBoxContainer
var _stat_cap: Label
var _stat_val: Label
var _sep_a: VSeparator
var _sep_b: VSeparator
## The ammo sign: the gun's name, the mag size beside the count, the cartridges.
var _ammo_name: Label
var _ammo_max: Label
var _pips: AmmoPips
## The ammo sign's own copy of the HUD plate (tighter margins), refilled on a set swap.
var _ammo_plate: KitBox
const AMMO_BIG := 48
## "[G] not yet" under the plaque while the ready countdown runs.
var status: HudStatus
var feed: HudFeed
var hotbar: HudHotbar
var build_menu: HudBuildMenu
var threat: HudThreatAlert
var title_card: HudTitleCard
var summary: HudWaveSummary
var overview: HudOverviewMap
var tallies: TurretTallies
var tutorial: HudTutorial
var photo: PhotoMode

## The separator between parts of one line of HUD text ("Wave 3  ·  High Noon").
const SEP := "  ·  "
const PHASE_NAMES := {
	GameState.Phase.LOBBY: "Waiting for riders",
	GameState.Phase.BUILD: "DAYBREAK",
	GameState.Phase.WARNING: "DUST ON THE HORIZON",
	GameState.Phase.WAVE: "SUNDOWN",
	GameState.Phase.GAME_OVER: "THE END",
}


func _ready() -> void:
	status = HudStatus.new()
	add_child(status)
	feed = HudFeed.new()
	add_child(feed)
	hotbar = HudHotbar.new()
	add_child(hotbar)
	build_menu = HudBuildMenu.new()
	add_child(build_menu)
	_wave_card = HudWavePreview.new()
	add_child(_wave_card)
	add_child(HudExpedition.new()) # Canyon Expeditions: backpack card, partners in the canyon
	threat = HudThreatAlert.new()
	add_child(threat)
	title_card = HudTitleCard.new()
	add_child(title_card)
	summary = HudWaveSummary.new()
	add_child(summary)
	overview = HudOverviewMap.new()
	add_child(overview)
	# These two sit beside the HUD in the world, not in it: the tallies need a
	# fixed path for their RPCs, and photo mode must stay up while the HUD hides.
	tallies = TurretTallies.new()
	tallies.name = "TurretTallies"
	photo = PhotoMode.new()
	photo.name = "PhotoMode"
	photo.hud = self
	if get_parent() != null:
		get_parent().add_child.call_deferred(tallies)
		get_parent().add_child.call_deferred(photo)
	var emotes := Emotes.new()
	emotes.name = "Emotes"
	add_child(emotes)
	var wheel := CropWheel.new() # universal crop-fed turrets: Q picks the crop
	wheel.name = "CropWheel"
	add_child(wheel)
	tutorial = HudTutorial.new()
	add_child(tutorial)
	_speed_lines = SpeedLines.new()
	_speed_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speed_lines)
	_scope = ScopeOverlay.new()
	_scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	add_child(_scope)
	combo = HudCombo.new()
	combo.set_anchors_preset(Control.PRESET_FULL_RECT)
	combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combo)
	combo.under = _wave_card # the style grade sits centred under the top-right wave card
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	# The ammo sign, bottom-right: the gun's name, a big count over the mag
	# size, and a row of cartridges that empties as you shoot.
	var ammo_sign := KeyHints.plate()
	ammo_sign.anchor_left = 1.0
	ammo_sign.anchor_right = 1.0
	ammo_sign.anchor_top = 1.0
	ammo_sign.anchor_bottom = 1.0
	ammo_sign.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_sign.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_sign.offset_left = -24
	ammo_sign.offset_right = -24
	ammo_sign.offset_top = -24
	ammo_sign.offset_bottom = -24
	ammo_sign.custom_minimum_size = Vector2(0, 0) # (Logan: narrow, no empty space: it hugs what it shows)
	var tight := (KeyHints.kit_box("plate").duplicate() as KitBox)
	tight.content_margin_left = 12
	tight.content_margin_right = 12
	tight.content_margin_top = 7
	tight.content_margin_bottom = 8
	ammo_sign.add_theme_stylebox_override("panel", tight)
	_ammo_plate = tight
	add_child(ammo_sign)
	var ammo_col := VBoxContainer.new()
	ammo_col.add_theme_constant_override("separation", 0)
	ammo_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_sign.add_child(ammo_col)
	_ammo_name = KeyHints.eyebrow("", 13)
	_ammo_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_name.autowrap_mode = TextServer.AUTOWRAP_OFF # (the card widens a little for a long name rather than cutting it)
	_ammo_name.custom_minimum_size.x = 0
	ammo_col.add_child(_ammo_name)
	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	ammo_row.add_theme_constant_override("separation", 6)
	ammo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_col.add_child(ammo_row)
	_ammo_label = KeyHints.number("", AMMO_BIG)
	_ammo_label.add_theme_constant_override("line_spacing", -6)
	ammo_row.add_child(_ammo_label)
	_ammo_max = KeyHints.number("", 22)
	_ammo_max.theme_type_variation = "SoftInkLabel"
	_ammo_max.add_theme_font_override("font", UiStyle.font("number"))
	_ammo_max.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo_row.add_child(_ammo_max)
	_pips = AmmoPips.new()
	ammo_col.add_child(_pips)
	ammo_col.add_child(SpecialBadge.new()) # special weapons: crop badge and base effect
	var heavy := HeavyAmmoPanel.new() # universal heavies: the crop, EMPTY, the low-ammo pulse
	heavy.ammo_label = _ammo_label
	ammo_col.add_child(heavy)
	heavy.make_glow(ammo_sign)


	_blackout = ColorRect.new()
	_blackout.color = Color.BLACK
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.visible = false
	add_child(_blackout)
	_center_label = Label.new()
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.offset_left = -300
	_center_label.offset_right = 300
	_center_label.offset_top = 60
	_center_label.offset_bottom = 110
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 30)
	_center_label.add_theme_color_override("font_color", UiStyle.c("title")) # Theme
	_center_label.add_theme_font_override("font", UiStyle.display_font())
	_center_label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_center_label.add_theme_constant_override("outline_size", 8)
	add_child(_center_label)

	# The phase plaque: a ticket pinned top-centre. The phase's shape, the wave
	# number, the time of day (and weather, heat) and one live figure (bugs
	# left, levers thrown, the ride-in clock), then one short line on what to do.
	var banner := KeyHints.plate("ticket")
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.offset_left = 0
	banner.offset_right = 0
	banner.offset_top = 14
	add_child(banner)
	var plaque := VBoxContainer.new()
	plaque.add_theme_constant_override("separation", 0)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(plaque)
	# The phase reads by shape as well as words: a sun for daybreak, a warning
	# triangle when dust is on the horizon, a bug while a wave is on.
	var phase_row := HBoxContainer.new()
	phase_row.alignment = BoxContainer.ALIGNMENT_CENTER
	phase_row.add_theme_constant_override("separation", 14)
	phase_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(phase_row)
	_phase_icon = PhaseIcon.new()
	phase_row.add_child(_phase_icon)
	_wave_box = _figure(phase_row, "Wave")
	_wave_num = _wave_box.get_child(1) as Label
	_sep_a = VSeparator.new()
	phase_row.add_child(_sep_a)
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.size_flags_vertical = Control.SIZE_FILL
	_phase_label.theme_type_variation = "HeaderTitle"
	_phase_label.add_theme_font_size_override("font_size", UiStyle.ts(22))
	_phase_label.add_theme_constant_override("outline_size", 4)
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_row.add_child(_phase_label)
	_sep_b = VSeparator.new()
	phase_row.add_child(_sep_b)
	_stat_box = _figure(phase_row, "Bugs Left")
	_stat_cap = _stat_box.get_child(0) as Label
	_stat_val = _stat_box.get_child(1) as Label
	_plaque_font()
	UiStyle.notifier.changed.connect(_plaque_font)
	_hint_label = KeyHints.ink("", 14, true)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.visible = false
	plaque.add_child(_hint_label)
	GameState.ready_countdown_changed.connect(func(_s: float) -> void: _update_hint())
	GameState.levers_changed.connect(_update_hint) # Waterworks
	GameState.phase_changed.connect(func(_p: GameState.Phase) -> void: _flash_phase())
	GameState.skip_votes_changed.connect(func(_v: int, _n: int) -> void: _update_hint())

	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 12)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 4)
	_debug_label.visible = false
	add_child(_debug_label)


## Hooks the HUD up to a local player.
func bind_player(player: Player, bugs: BugManager, builds: BuildManager) -> void:
	status.bind_player(player)
	feed.bind_player(player, bugs, builds)
	build_menu.bind(player.build_mode)
	threat.player = player
	title_card.player = player
	summary.bind(bugs, player.cliff_id)
	overview.player = player
	tallies.bind(bugs)
	tutorial.player = player
	player.gun.ammo_changed.connect(_on_ammo_changed)
	_scope.gun = player.gun
	_dyn_player = player
	player.gun.hit_confirmed.connect(func(weak: bool) -> void: (_crosshair as Crosshair).flash(weak))
	(_crosshair as Crosshair).grapple = player.grapple
	player.gun.reload_started.connect(func(_d: float) -> void: _ammo_show("Reloading", "", 0, -1))
	_speed_lines.player = player
	player.combo.bind_bugs(bugs)
	combo.bind(player)
	# Hitting the canyon floor: hard cut to black over the guitar smash, then
	# fade back in on the porch.
	player.fall_landed.connect(func() -> void:
		_blackout.modulate.a = 1.0
		_blackout.visible = true)
	player.respawned.connect(func() -> void:
		_center_label.text = ""
		var tw := _blackout.create_tween()
		tw.tween_property(_blackout, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func() -> void: _blackout.visible = false))
	_on_ammo_changed(player.gun.ammo, player.gun.def.mag_size)


## The grapple's dynamite: with the launcher out the ammo sign counts bundles,
## and a keycap hint above it says what R does next.
var _dyn_player: Player
var _dyn_hint: Control
var _dyn_hint_text := ""
var _dyn_sign := false
var _dyn_count := -1


func _update_dynamite_hud() -> void:
	var p := _dyn_player
	var dyn := p.dynamite if p != null and is_instance_valid(p) else null
	var on := dyn != null and dyn.owns_r()
	if on:
		if not _dyn_sign or dyn.bundles != _dyn_count:
			_dyn_count = dyn.bundles
			_ammo_name.text = "Dynamite"
			_ammo_show(str(dyn.bundles), "/ %d" % DynamiteRules.MAX_BUNDLES, dyn.bundles, DynamiteRules.MAX_BUNDLES)
		_dyn_sign = true
	elif _dyn_sign:
		_dyn_sign = false
		_dyn_count = -1
		if p != null and is_instance_valid(p) and p.gun.def != null:
			_on_ammo_changed(p.gun.ammo, p.gun.mag_size())
	var text := dyn.hint() if on else ""
	if text != _dyn_hint_text:
		_dyn_hint_text = text
		if _dyn_hint != null:
			_dyn_hint.queue_free()
			_dyn_hint = null
		if text != "":
			# Under the crosshair on a small plate, clear of the backpack card on the canyon floor.
			_dyn_hint = KeyHints.plate("plate_tight")
			_dyn_hint.add_child(KeyHints.row([[KeyHints.key_for("reload"), text]]))
			_dyn_hint.anchor_left = 0.5
			_dyn_hint.anchor_right = 0.5
			_dyn_hint.anchor_top = 0.5
			_dyn_hint.anchor_bottom = 0.5
			_dyn_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
			_dyn_hint.offset_left = 0
			_dyn_hint.offset_right = 0
			_dyn_hint.offset_top = 46
			add_child(_dyn_hint)


func _process(_delta: float) -> void:
	_update_dynamite_hud()
	if Input.is_action_just_pressed("debug_overlay"):
		_debug_label.visible = not _debug_label.visible
	_update_phase_label()
	if _debug_label.visible:
		var role := "offline"
		if NetworkManager.is_online():
			role = "host" if multiplayer.is_server() else "client"
		_debug_label.text = "FPS %d\nDraw calls %d\nPeer %d (%s)\nPing %d ms\nPlayers %d" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			multiplayer.get_unique_id(), role, NetworkManager.get_ping_ms(),
			get_tree().get_nodes_in_group("players").size()]


## The plaque's time of day in the set's display face, unless that face is too
## ornate to read at a glance (then the kit's bold UI face). The centre message
## follows the set's title colour.
func _plaque_font() -> void:
	if _ammo_plate != null: # the ammo sign's tighter plate follows the set too
		var m := [_ammo_plate.content_margin_left, _ammo_plate.content_margin_top, _ammo_plate.content_margin_right, _ammo_plate.content_margin_bottom]
		_ammo_plate.copy_from(KeyHints.kit_box("plate"))
		_ammo_plate.content_margin_left = m[0]
		_ammo_plate.content_margin_top = m[1]
		_ammo_plate.content_margin_right = m[2]
		_ammo_plate.content_margin_bottom = m[3]
	if UiStyle.display_is_decorative():
		_phase_label.add_theme_font_override("font", UiStyle.font("bold"))
	else:
		_phase_label.remove_theme_font_override("font")
	if _center_label != null:
		_center_label.add_theme_color_override("font_color", UiStyle.c("title"))
		_center_label.add_theme_color_override("font_outline_color", UiStyle.c("outline"))


## A caption over a figure ("WAVE" / "3"), for the plaque.
func _figure(parent: Control, caption: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -7)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	var cap := KeyHints.eyebrow(caption, 12)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var num := KeyHints.number("", 30)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)
	return v


## Runs every frame, but only sets text (a Label ignores an unchanged string).
func _update_phase_label() -> void:
	var title: String = UiStyle.tc(str(PHASE_NAMES.get(GameState.phase, "")).to_lower())
	if DayCycle.instance != null and (GameState.phase == GameState.Phase.BUILD or GameState.phase == GameState.Phase.WAVE):
		title = UiStyle.tc(DayCycle.instance.stage_name().to_lower())
		if GameState.weather != Weather.Kind.CLEAR:
			title += SEP + UiStyle.tc(str(Weather.NAMES[GameState.weather]).to_lower())
		title += SEP + "%d°F" % int(round(GameState.temperature()))
	_phase_label.text = title
	var lobby := GameState.phase == GameState.Phase.LOBBY
	_wave_box.visible = not lobby
	_sep_a.visible = not lobby
	_stat_box.visible = not lobby
	_sep_b.visible = not lobby
	if lobby:
		return
	_wave_num.text = str(GameState.wave)
	if GameState.phase == GameState.Phase.WAVE:
		var left := BugManager.instance.alive_count() if is_instance_valid(BugManager.instance) else get_tree().get_nodes_in_group("bugs").size()
		_stat_cap.text = "Bug Left" if left == 1 else "Bugs Left"
		_stat_val.text = str(left)
	elif GameState.phase == GameState.Phase.BUILD and GameState.ready_countdown >= 0.0:
		_stat_cap.text = "Riding In"
		_stat_val.text = UiStyle.clock(GameState.ready_countdown)
	elif GameState.phase == GameState.Phase.BUILD and not GameState.has_flag("--fast"):
		_stat_cap.text = "Levers"
		_stat_val.text = "%d / %d" % [GameState.skip_votes, maxi(NetworkManager.players.size(), 1)]
	else:
		_stat_cap.text = "Time"
		_stat_val.text = UiStyle.clock(GameState.time_left)


func _flash_phase() -> void:
	_update_hint()
	_phase_icon.queue_redraw()
	var tw := create_tween()
	_phase_label.pivot_offset = _phase_label.size * 0.5
	_phase_label.scale = Vector2(1.15, 1.15)
	tw.tween_property(_phase_label, "scale", Vector2.ONE, 0.25)


func _update_hint() -> void:
	match GameState.phase:
		GameState.Phase.BUILD:
			# Waterworks: ready-up is the breaker lever at your generator (it's a
			# thing in the yard now, so no "press G" line; the banner keeps the count).
			if GameState.ready_countdown >= 0.0:
				_hint_label.text = "Every lever's thrown. The generators are cranking, the bugs are coming"
			else:
				_hint_label.text = ""
		GameState.Phase.WARNING:
			_hint_label.text = "A wave is coming. Get back to your cliff"
		_:
			_hint_label.text = ""
	_hint_label.visible = _hint_label.text != ""


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	var g := _scope.gun if _scope != null else null
	if g != null and is_instance_valid(g) and g.def != null:
		_ammo_name.text = UiStyle.tc(g.def.display_name)
	if g != null and is_instance_valid(g) and g.def != null and g.def.special == &"smoke":
		# Bee Smoker: its fuel, as a share (the cartridges become a gauge).
		_ammo_show("%d%%" % roundi(100.0 * current / maxf(max_ammo, 1)), "Fuel", current, max_ammo, true)
		return
	if g != null and is_instance_valid(g) and g.def != null and g.def.crop_ammo and (current <= 0 or g.heavy_crop_of(g.def.id) == &""):
		_ammo_show("— EMPTY —", "", 0, max_ammo) # a universal heavy with no sack in it (HeavyAmmoPanel)
		return
	_ammo_show(str(current), "/ %d" % max_ammo, current, max_ammo)


## Sets the ammo sign: the big figure, the small one beside it, the cartridges
## (`max_ammo` < 0 leaves them empty: reloading). Changes only what changed.
func _ammo_show(big: String, small: String, current: int, max_ammo: int, gauge: bool = false) -> void:
	_ammo_label.text = big
	var size := AMMO_BIG if big.length() <= 4 else 28
	if _ammo_label.get_meta(&"fs", 0) != size:
		_ammo_label.set_meta(&"fs", size)
		_ammo_label.add_theme_font_size_override("font_size", UiStyle.ts(size))
	_ammo_max.text = small
	_ammo_max.visible = small != ""
	if max_ammo < 0:
		_pips.set_ammo(0, _pips.mag, _pips.gauge)
	else:
		_pips.set_ammo(current, max_ammo, gauge)


func _show_message(text: String) -> void:
	_center_label.text = text


## Maps: who holds cliff `cid`: a player's name, a CPU teammate's, or "empty".
static func owner_name(cid: int) -> String:
	for id: int in NetworkManager.players:
		if int((NetworkManager.players[id] as Dictionary)["cliff"]) == cid:
			return str((NetworkManager.players[id] as Dictionary)["name"])
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		for n: Node in tree.get_nodes_in_group("cpu_teammates"):
			if int(n.get("cliff_id")) == cid:
				return str(n.get("display_name"))
	return "you" if GameState.is_solo() and MapDef.players_of(NetworkManager.map_id) <= 2 else "open" # solo on a bigger map: the other buttes are nobody's


## Theme: the HUD sign is the theme set's HUD card.
static func wood_sign_style() -> StyleBoxFlat:
	return UiStyle.hud_flat()


## A small cross with a dark outline, drawn in code. Hits flash an X; weak-spot
## hits flash a bigger gold X with a little "CRIT" pop and a high ping.
class Crosshair extends Control:
	const CRIT_SOUND := "res://audio/sfx/armor_ping.wav"
	const CRIT_GAP := 0.07 # fastest the crit ping repeats (automatic guns)
	var marker := 0.0
	var marker_weak := false
	var _crit := 0.0
	var _crit_side := 1.0
	var _crit_sfx: AudioStreamPlayer
	var _crit_cd := 0.0
	## With the grapple out: a cooldown ring, and the cross turns green when the
	## aimed point is within rope length (grey when it's out of reach).
	var grapple: Grapple
	var _hooking := false
	var _hook_cd := 0.0
	var _hook_ok := false

	func _ready() -> void:
		if ResourceLoader.exists(CRIT_SOUND):
			_crit_sfx = AudioStreamPlayer.new()
			_crit_sfx.stream = load(CRIT_SOUND)
			_crit_sfx.bus = &"UI" if AudioServer.get_bus_index("UI") >= 0 else &"Master"
			_crit_sfx.volume_db = -7.0
			add_child(_crit_sfx)

	func flash(weak: bool) -> void:
		marker = 1.0
		marker_weak = weak
		if weak:
			_crit = 1.0
			_crit_side = -_crit_side
			if _crit_sfx != null and _crit_cd <= 0.0:
				_crit_cd = CRIT_GAP
				_crit_sfx.pitch_scale = randf_range(1.75, 1.95)
				_crit_sfx.play()
		queue_redraw()

	func _process(delta: float) -> void:
		_crit_cd -= delta
		var hooking := grapple != null and is_instance_valid(grapple) and grapple.aiming()
		if hooking or _hooking:
			var cd := grapple.cooldown_fraction() if hooking else 0.0
			var ok := hooking and grapple.aim_in_range()
			if hooking != _hooking or cd != _hook_cd or ok != _hook_ok:
				_hooking = hooking
				_hook_cd = cd
				_hook_ok = ok
				queue_redraw()
		if marker > 0.0 or _crit > 0.0:
			marker = maxf(marker - delta * (3.5 if marker_weak else 5.0), 0.0)
			_crit = maxf(_crit - delta * 2.2, 0.0)
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if marker > 0.0:
			# Hit marker: an X that pops when your shot lands. Weak spots get a
			# bigger, outlined gold X that punches out and settles.
			if marker_weak:
				var punch := 1.0 + 0.35 * marker * marker
				var gold := Color(Palette.GLOW_YELLOW, minf(marker * 1.6, 1.0))
				var edge := Color(Palette.OUTLINE, minf(marker * 1.6, 1.0) * 0.9)
				for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					draw_line(c + d * 7.0 * punch, c + d * 19.0 * punch, edge, 6.0)
				for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					draw_line(c + d * 7.5 * punch, c + d * 18.0 * punch, gold, 3.5)
			else:
				var mc := Color.WHITE * Color(1, 1, 1, marker)
				for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
					draw_line(c + d * 7.0, c + d * 15.0, mc, 3.0)
		if _crit > 0.0:
			# "CRIT" on a tiny dark tag, rising off to one side and fading.
			var font := get_theme_default_font()
			var fs := 13
			var rise := (1.0 - _crit) * 14.0
			var a := minf(_crit * 2.5, 1.0)
			var tw := font.get_string_size("CRIT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := c + Vector2(26.0 * _crit_side - (tw if _crit_side < 0.0 else 0.0), -18.0 - rise)
			var tag := Rect2(at + Vector2(-5, -fs + 1), Vector2(tw + 10, fs + 6))
			draw_rect(tag, Color(Palette.OUTLINE, 0.75 * a))
			draw_rect(tag, Color(Palette.GLOW_YELLOW, a), false, 1.5)
			draw_string(font, at, "CRIT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.GLOW_YELLOW, a))
		var cross := Palette.BONE
		if _hooking:
			cross = Palette.ACID_GREEN if _hook_ok else Palette.METAL.lightened(0.25)
			if _hook_cd > 0.0:
				# Cooldown: an arc that empties clockwise from the top.
				var end := -PI * 0.5 + TAU * _hook_cd
				draw_arc(c, 16.0, -PI * 0.5, end, 32, Palette.OUTLINE, 5.0, true)
				draw_arc(c, 16.0, -PI * 0.5, end, 32, Palette.BONE, 2.5, true)
			elif _hook_ok:
				draw_arc(c, 16.0, 0.0, TAU, 32, Color(Palette.OUTLINE, 0.6), 4.0, true)
				draw_arc(c, 16.0, 0.0, TAU, 32, Color(Palette.ACID_GREEN, 0.8), 2.0, true)
		for pass_i in 2:
			var col := Palette.OUTLINE if pass_i == 0 else cross
			var w := 4.0 if pass_i == 0 else 2.0
			draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), col, w)
			draw_line(c + Vector2(4, 0), c + Vector2(10, 0), col, w)
			draw_line(c + Vector2(0, -10), c + Vector2(0, -4), col, w)
			draw_line(c + Vector2(0, 4), c + Vector2(0, 10), col, w)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Streaks rushing past the edges of the screen while you fall (and a white
## flash on impact). Only the outer ring of the screen, so you can still see.
class SpeedLines extends Control:
	var player: Player
	var _lines: Array = []
	var _flash := 0.0
	var _drawn := false # something is on screen that the next idle frame must clear

	func _ready() -> void:
		for i in 70:
			_lines.append([randf() * TAU, randf(), randf_range(0.6, 1.4)])

	func _process(delta: float) -> void:
		if player == null:
			return
		if player.fall_intensity > 0.02 or _flash > 0.0:
			for l: Array in _lines:
				l[1] = fposmod(float(l[1]) + delta * (1.5 + player.fall_intensity * 5.0) * float(l[2]), 1.0)
			queue_redraw()
			_drawn = true
		_flash = maxf(_flash - delta * 2.5, 0.0)
		if player.fall_intensity <= 0.02 and _flash <= 0.0 and _drawn:
			_drawn = false # one last redraw clears it, then it stays idle
			queue_redraw()

	func flash() -> void:
		_flash = 1.0

	func _draw() -> void:
		if player == null:
			return
		var k := player.fall_intensity
		if k > 0.02:
			var c := size * 0.5
			var r_max := c.length()
			for l: Array in _lines:
				var a := float(l[0])
				var dir := Vector2(cos(a), sin(a))
				# Lines start in the outer ring and race outward.
				var t := float(l[1])
				var r0 := lerpf(0.55, 1.0, t) * r_max
				var len := r_max * (0.08 + 0.25 * k) * float(l[2])
				var col := Color(1, 1, 1, 0.55 * k * (1.0 - t * 0.6))
				draw_line(c + dir * r0, c + dir * (r0 + len), col, 2.0 + 3.0 * k)
		if _flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0.95, _flash * 0.85))


## The Elephant Gun's (and Dino Rifle's) magnifying glass: when you're looking
## through it, the view is a round lens in a dark surround with a fine cross.
## The Dino Rifle's glass sits wherever it got tied on (DinoGlass).
class ScopeOverlay extends Control:
	var gun: Gun

	func _process(_delta: float) -> void:
		var on := gun != null and is_instance_valid(gun) and gun.is_scoped()
		if on != visible:
			visible = on
		if visible:
			queue_redraw()

	func _draw() -> void:
		var short := minf(size.x, size.y)
		var c := size * 0.5
		var r := short * 0.42
		if gun != null and is_instance_valid(gun) and gun.def != null and gun.def.id == &"telescope_rifle":
			_draw_spyglass(c, short)
			return
		# Dino Rifle: where and how its glass got tied on (DinoGlass).
		var fit := {}
		if gun != null and is_instance_valid(gun) and gun.def != null and gun.def.id == &"dino_rifle":
			fit = DinoGlass.get_fit(gun.code_of(&"dino_rifle"))
			c += (fit["lens"] as Vector2) * short
			r *= float(fit["size"])
			var wob := float(fit["wobble"])
			if wob > 0.0:
				var s := Time.get_ticks_msec() / 1000.0
				c += Vector2(sin(s * 2.3) + 0.5 * sin(s * 5.1), cos(s * 1.7) + 0.4 * sin(s * 4.3)) * wob * short
				r *= 1.0 + 0.04 * sin(s * 3.1)
		# Dark surround: a thick ring from the lens edge out past the corners.
		var outer := size.length() + (c - size * 0.5).length()
		draw_arc(c, (r + outer) * 0.5, 0.0, TAU, 96, Color(0.04, 0.03, 0.02, 0.97), outer - r + 2.0, true)
		# Brass rim and a soft inner shadow.
		draw_arc(c, r + 6.0, 0.0, TAU, 96, Color("#B8893A"), 12.0, true)
		draw_arc(c, r - 10.0, 0.0, TAU, 96, Color(0, 0, 0, 0.25), 20.0, true)
		# Fine cross with a gap in the middle.
		var line := Color(0.08, 0.06, 0.04, 0.9)
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 14.0, c + d * r, line, 2.0)
		draw_circle(c, 2.5, line)
		if fit.is_empty():
			return
		if float(fit["wobble"]) > 0.0:
			# Fisheye: the edge of the glass bulges and smears.
			for i in 3:
				draw_arc(c, r * (0.78 + 0.07 * i), 0.0, TAU, 64, Color(1, 1, 1, 0.05), r * 0.06, true)
		if bool(fit["cracked"]):
			_draw_crack(c, r)


	## The Telescope Rifle's brass spyglass: a smaller, sharper lens deep in a
	## black drawtube (the tube's brass rings show round it), a fine crosshair
	## with range ticks below the centre, and a little tremor from your breathing.
	func _draw_spyglass(c: Vector2, short: float) -> void:
		var s := Time.get_ticks_msec() / 1000.0
		c += Vector2(sin(s * 0.9) + 0.4 * sin(s * 2.3), cos(s * 0.7) + 0.3 * sin(s * 1.9)) * short * 0.0025
		var r := short * 0.36
		var outer := size.length() + 2.0
		draw_arc(c, (r + outer) * 0.5, 0.0, TAU, 96, Color(0.02, 0.015, 0.01, 0.99), outer - r + 2.0, true)
		# The drawtube seen end-on: brass rims stepping out from the lens.
		for i in 3:
			draw_arc(c, r + 5.0 + i * 13.0, 0.0, TAU, 96, Color("#B8893A").darkened(0.25 * i), 5.0 - i, true)
		draw_arc(c, r - 14.0, 0.0, TAU, 96, Color(0, 0, 0, 0.32), 28.0, true)
		draw_arc(c, r * 0.97, PI * 1.1, PI * 1.45, 24, Color(1, 1, 1, 0.12), 3.0, true)
		# Crosshair: fine wires to the rim, thicker posts at the edge.
		var ink := Color(0.05, 0.04, 0.03, 0.92)
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 6.0, c + d * r * 0.62, ink, 1.4, true)
			draw_line(c + d * r * 0.62, c + d * r, ink, 4.0, true)
		# Range ticks down the lower wire (hold-over for long shots).
		for i in range(1, 5):
			var y := c.y + r * 0.1 * i
			var w := r * (0.06 if i % 2 == 0 else 0.035)
			draw_line(Vector2(c.x - w, y), Vector2(c.x + w, y), ink, 1.4, true)
		draw_circle(c, 1.8, Color("#C83A2A"))


	## A crack across the lens: one jagged run edge to edge, with a few branches.
	func _draw_crack(c: Vector2, r: float) -> void:
		var ink := Color(0.95, 0.97, 1.0, 0.55)
		var dark := Color(0, 0, 0, 0.35)
		var main: PackedVector2Array = [c + Vector2(-0.98, -0.2) * r, c + Vector2(-0.62, -0.12) * r, c + Vector2(-0.4, 0.02) * r,
			c + Vector2(-0.12, -0.05) * r, c + Vector2(0.08, 0.1) * r, c + Vector2(0.35, 0.06) * r, c + Vector2(0.6, 0.22) * r,
			c + Vector2(0.97, 0.25) * r]
		draw_polyline(main, dark, 4.0, true)
		draw_polyline(main, ink, 1.6, true)
		for b: PackedVector2Array in [
				PackedVector2Array([c + Vector2(-0.4, 0.02) * r, c + Vector2(-0.33, 0.3) * r, c + Vector2(-0.38, 0.55) * r]),
				PackedVector2Array([c + Vector2(0.08, 0.1) * r, c + Vector2(0.02, -0.3) * r, c + Vector2(0.12, -0.62) * r]),
				PackedVector2Array([c + Vector2(0.6, 0.22) * r, c + Vector2(0.55, 0.5) * r])]:
			draw_polyline(b, dark, 3.0, true)
			draw_polyline(b, ink, 1.2, true)


## The ammo sign's row of cartridges, right-aligned: a brass round for each one
## in the mag, an empty case for each one fired. Big mags (and the Bee Smoker's
## fuel) show as a segmented gauge instead. Redraws only when the count changes.
class AmmoPips extends Control:
	const MAX_ROUNDS := 16
	const SEGMENTS := 20
	var current := 0
	var mag := 0
	var gauge := false

	func _init() -> void:
		custom_minimum_size = Vector2(60, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		UiStyle.notifier.changed.connect(queue_redraw)

	func set_ammo(cur: int, mx: int, as_gauge: bool = false) -> void:
		if cur == current and mx == mag and as_gauge == gauge:
			return
		current = cur
		mag = mx
		gauge = as_gauge
		# As wide as the rounds need (a gauge keeps a short fixed bar).
		custom_minimum_size.x = 96.0 if (gauge or mag > MAX_ROUNDS) else clampf(mag * 10.0, 40.0, 160.0)
		queue_redraw()

	func _draw() -> void:
		if mag <= 0:
			return
		var brass := UiStyle.kc("accent_hi")
		var dim := Color(UiStyle.kc("faint"), 0.45)
		var dark := Color(0, 0, 0, 0.55)
		var h := size.y
		if gauge or mag > MAX_ROUNDS:
			# A segmented gauge, filled from the left.
			var n := SEGMENTS
			var gap := 2.0
			var w := (size.x - gap * (n - 1)) / n
			var lit := ceili(float(current) / mag * n - 0.001)
			for i in n:
				var r := Rect2(i * (w + gap), h * 0.3, w, h * 0.55)
				draw_rect(r.grow(1.0), dark)
				draw_rect(r, brass if i < lit else dim)
			return
		# One cartridge per round: a case with a lead tip, right-aligned.
		var step := minf(10.0, size.x / mag)
		var cw := minf(6.0, step - 1.5)
		var x0 := size.x - step * mag + (step - cw) * 0.5
		for i in mag:
			var x := x0 + i * step
			var full := i >= mag - current # spent rounds empty from the left
			var body := Rect2(x, h * 0.36, cw, h * 0.64)
			draw_rect(body.grow(1.0), dark)
			if full:
				draw_rect(body, brass)
				draw_rect(Rect2(body.position, Vector2(cw * 0.35, body.size.y)), Color(1, 1, 1, 0.25))
				var tip := PackedVector2Array([Vector2(x, h * 0.36), Vector2(x + cw * 0.5, 0.0), Vector2(x + cw, h * 0.36)])
				draw_colored_polygon(tip, Color("#9A9AA0"))
			else:
				draw_rect(body, dim, false, 1.0)


## The plaque's phase shape: sun (building), warning triangle (a wave is
## coming), bug (wave on); nothing in the lobby or at the end.
class PhaseIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(28, 28)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		UiStyle.notifier.changed.connect(queue_redraw)

	func _process(_d: float) -> void:
		var on := GameState.phase in [GameState.Phase.BUILD, GameState.Phase.WARNING, GameState.Phase.WAVE]
		if visible != on:
			visible = on
		if get_meta(&"p", -1) != GameState.phase:
			set_meta(&"p", GameState.phase)
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var ink := Color(UiStyle.c("outline"), 0.9)
		match GameState.phase:
			GameState.Phase.BUILD:
				var sun := UiStyle.c("title")
				for i in 8:
					var d := Vector2.from_angle(TAU * i / 8.0)
					draw_line(c + d * r * 0.55, c + d * r * 0.98, ink, 4.0, true)
					draw_line(c + d * r * 0.55, c + d * r * 0.92, sun, 2.0, true)
				draw_circle(c, r * 0.5, ink)
				draw_circle(c, r * 0.4, sun)
			GameState.Phase.WARNING:
				var tri := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.85), c + Vector2(-r, r * 0.85)])
				draw_colored_polygon(tri, ink)
				var inner := PackedVector2Array([c + Vector2(0, -r * 0.62), c + Vector2(r * 0.7, r * 0.66), c + Vector2(-r * 0.7, r * 0.66)])
				draw_colored_polygon(inner, UiStyle.hud_c("warn"))
				draw_line(c + Vector2(0, -r * 0.2), c + Vector2(0, r * 0.25), ink, 2.5)
				draw_circle(c + Vector2(0, r * 0.45), 1.6, ink)
			GameState.Phase.WAVE:
				var bug := UiStyle.hud_c("bad")
				for side: float in [-1.0, 1.0]:
					for k in 3:
						var y := (k - 1) * r * 0.42
						draw_line(c + Vector2(side * r * 0.3, y), c + Vector2(side * r * 0.95, y + (k - 1) * r * 0.25), ink, 3.0, true)
				draw_circle(c + Vector2(0, -r * 0.62), r * 0.3, ink)
				var body := PackedVector2Array()
				for i in 16:
					var a := TAU * i / 16.0
					body.append(c + Vector2(cos(a) * r * 0.42, r * 0.12 + sin(a) * r * 0.66))
				draw_colored_polygon(body, ink)
				var inner_body := PackedVector2Array()
				for i in 16:
					var a := TAU * i / 16.0
					inner_body.append(c + Vector2(cos(a) * r * 0.3, r * 0.12 + sin(a) * r * 0.54))
				draw_colored_polygon(inner_body, bug)
