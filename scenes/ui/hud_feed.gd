class_name HudFeed
extends Control
## Right side: the shared kill feed (who saved whom), structure events and the
## warning-phase lane report. Center: interaction prompt, build status, game over.
## Seeing "your turret saved your partner" is what makes the cross-defense click.

const FEED_LINES := 6
const FEED_LIFETIME := 7.0

var cliff_id: int = 0
var _feed: VBoxContainer
var _card: HudPromptCard
var _prompt_text := ""
var _over: PanelContainer
var _paper: NewspaperFront
var _over_label: Label
var _keep_going: Button
var _build_mode: BuildMode
var _boss_box: VBoxContainer
## One name + bar per boss on the field (two in the finale).
var _boss_bars: Array[ProgressBar] = []
var _boss_labels: Array[Label] = []
## Bosses already announced in the feed (by instance id).
var _boss_seen: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("hud_feed")
	_feed = VBoxContainer.new()
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.offset_left = -700
	_feed.offset_right = -24
	_feed.offset_top = 90 # pushed below the wave preview while it shows (_process)
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_feed)

	_card = HudPromptCard.new()
	add_child(_card)

	_over = PanelContainer.new()
	_over.add_theme_stylebox_override("panel", UiStyle.poster())
	_over.set_anchors_preset(Control.PRESET_CENTER)
	_over.offset_left = -280
	_over.offset_right = 280
	_over.offset_top = -120
	_over.offset_bottom = 120
	_over.visible = false
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_over)
	var col := VBoxContainer.new()
	_over.add_child(col)
	_over_label = UiStyle.label("", 26)
	_over_label.visible = false # the newspaper carries the result now
	col.add_child(_over_label)
	_paper = NewspaperFront.new() # end-of-run front page (RunStats)
	col.add_child(_paper)
	RunStats.reset() # a new world = a new run
	col.add_child(BrandsReport.new()) # Perk: Brands earned this run
	# After a win: keep the waves coming past the last one (host decides).
	_keep_going = UiStyle.button("Keep going (endless)")
	_keep_going.visible = false
	_keep_going.pressed.connect(func() -> void: GameState.continue_endless())
	col.add_child(_keep_going)
	var back := UiStyle.button("Back to main menu")
	back.pressed.connect(func() -> void:
		NetworkManager.leave()
		GameState.reset()
		get_tree().change_scene_to_file(NetworkManager.MENU_SCENE))
	col.add_child(back)

	_boss_box = VBoxContainer.new()
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.offset_left = -320
	_boss_box.offset_right = 320
	_boss_box.offset_top = 110
	_boss_box.visible = false
	add_child(_boss_box)
	_boss_box.add_theme_constant_override("separation", 2)
	for k in 2:
		var label := _outlined("", 20, Palette.TEAM_WEST.lightened(0.2))
		_boss_box.add_child(label)
		var bar := UiStyle.bar(Palette.TEAM_WEST if k == 0 else Palette.TEAM_WEST.lerp(Palette.GLOW_YELLOW, 0.35),
				Vector2(640, 22 if k == 0 else 18)) # one bar style everywhere
		_boss_box.add_child(bar)
		_boss_labels.append(label)
		_boss_bars.append(bar)
	WaveDirector.wave_announced.connect(_on_wave_announced)
	Economy.notice.connect(func(t: String) -> void: add_line(t, Palette.GLOW_YELLOW))
	GameState.game_over.connect(_on_game_over)
	GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
		if p == GameState.Phase.WARNING:
			Audio.play_ui(&"bell")
		if p != GameState.Phase.GAME_OVER and _over.visible:
			# Endless mode picked up after the win screen: back to the game.
			_over.visible = false
			GameState.menu_open = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			add_line("Endless! The waves keep coming. How long can you hold?", Palette.GLOW_YELLOW)
		)
	GameState.weather_changed.connect(func(k: int) -> void:
		if k != Weather.Kind.CLEAR or GameState.phase == GameState.Phase.WARNING:
			add_line(Weather.BLURBS[k], Palette.TEAM_WEST if k == Weather.Kind.BLOOD_MOON else (Palette.SKY_TOP if k != Weather.Kind.SNOW else Palette.BONE)))


func bind_player(player: Player, bugs: BugManager, builds: BuildManager) -> void:
	cliff_id = player.cliff_id
	_build_mode = player.build_mode
	player.vitals.prompt_changed.connect(func(t: String) -> void: _prompt_text = t)
	bugs.bug_killed.connect(_on_bug_killed)
	builds.structure_event.connect(func(t: String) -> void: add_line(t, Palette.ROCK_C))


func _process(_delta: float) -> void:
	# The feed sits under the wave preview card when that's up in the corner.
	# Maps: never over the other cliffs' homestead bars stacked top-right.
	var top := maxf(90.0, 76.0 + (WorldLayout.cliff_count() - 2) * 50.0)
	for c in get_parent().get_children():
		if c is HudWavePreview and (c as Control).visible:
			top = (c as Control).position.y + (c as Control).size.y + 10.0
	_feed.offset_top = top
	if _build_mode != null and _build_mode.active and not _build_mode.menu_open:
		var hud := get_parent() as Hud
		var icon: Texture2D = hud.build_menu.icon_for(_build_mode.selected_id()) if hud != null else null
		_card.show_build(_build_mode.build_info(icon))
	elif _build_mode != null and _build_mode.menu_open:
		_card.show_text("")
	else:
		_card.show_text(_prompt_text)
	_update_boss_bar()


func _update_boss_bar() -> void:
	var bosses: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b.def.behavior == BugDef.Behavior.BOSS and b.is_alive():
			bosses.append(b)
	_boss_box.visible = not bosses.is_empty()
	for k in _boss_bars.size():
		var on := k < bosses.size()
		_boss_bars[k].visible = on
		_boss_labels[k].visible = on
		if not on:
			continue
		var boss := bosses[k]
		if not _boss_seen.has(boss.get_instance_id()):
			_boss_seen[boss.get_instance_id()] = true
			add_line(boss.def.boss_tip if boss.def.boss_tip != "" else "%s is coming!" % boss.def.display_name.to_upper(), Palette.TEAM_WEST)
		_boss_bars[k].max_value = boss.health.max_hp
		_boss_bars[k].value = boss.health.hp
		var status := boss.boss.hud_status() if boss.boss != null else ""
		_boss_labels[k].text = "%s  -  %s%s" % [boss.def.display_name.to_upper(), WorldLayout.map().name_of(boss.cliff_id), # Maps:
				("  -  " + status) if status != "" else ""]


func add_line(text: String, color: Color = Palette.BONE) -> void:
	# The same line again (e.g. a turret on a killing spree): bump a "x3" count
	# on the last line instead of stacking copies.
	if _feed.get_child_count() > 0:
		var last := _feed.get_child(_feed.get_child_count() - 1) as Label
		if last != null and last.get_meta("base", "") == text:
			var n := int(last.get_meta("count", 1)) + 1
			last.set_meta("count", n)
			last.text = "%s  x%d" % [text, n]
			last.modulate.a = 1.0
			_fade_later(last)
			return
	var l := _outlined(text, 16, color)
	l.set_meta("base", text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Each line sits on its own small dark plate (no loose text over the sky).
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(UiStyle.c("hud_bg"), 0.82) # Theme: the set's HUD card
	plate.border_color = UiStyle.c("hud_rim")
	plate.border_width_left = 3
	plate.set_corner_radius_all(3)
	plate.content_margin_left = 8
	plate.content_margin_right = 8
	plate.content_margin_top = 1
	plate.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", plate)
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	l.autowrap_mode = TextServer.AUTOWRAP_OFF # one line, hugging its text
	_feed.add_child(l)
	while _feed.get_child_count() > FEED_LINES:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))
	_fade_later(l)


## (Re)starts a feed line's countdown to fade out.
func _fade_later(l: Label) -> void:
	var old: Variant = l.get_meta("tween") if l.has_meta("tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := l.create_tween()
	tw.tween_interval(FEED_LIFETIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	l.set_meta("tween", tw)


func _on_bug_killed(bug_name: String, bug_cliff: int, source: String, source_cliff: int, loot: Dictionary) -> void:
	if source_cliff == -2:
		add_line(bug_name, Palette.ROCK_C) # a plain announcement (e.g. a bandit escaped)
		return
	var scrap := int(loot.get(&"scrap", 0))
	RunStats.note_kill(bug_name, source, scrap) # for the end-of-run newspaper
	var saved := _cliff_owner_name(bug_cliff)
	var text: String
	if source_cliff >= 0 and source_cliff != bug_cliff:
		text = "%s saved %s from a %s (+%d scrap to %s)" % [source, saved, bug_name, scrap, saved]
	elif source != "":
		text = "%s got a %s (+%d scrap)" % [source, bug_name, scrap]
	else:
		text = "A %s went down (+%d scrap)" % [bug_name, scrap]
	var mine := source_cliff == cliff_id or bug_cliff == cliff_id
	add_line(text, Palette.GLOW_YELLOW if mine else Palette.BONE)


func _on_wave_announced(heavy_cliff: int, west_share: float, lane_counts: Array) -> void:
	var m := WorldLayout.map()
	var heavy := "Both cliffs equally" if m.count() == 2 else "Every cliff about equally"
	if heavy_cliff >= 0:
		var pct := maxf(west_share, 1.0 - west_share) if m.count() == 2 else west_share
		heavy = "%s gets %d%%" % [m.name_of(heavy_cliff), int(roundf(pct * 100.0))]
	add_line("Dust on the horizon! %s." % heavy, Palette.GLOW_YELLOW)


func _on_game_over(won: bool, reason: String) -> void:
	_over_label.text = ("YOU WIN!\n" if won else "THE CANYON IS LOST\n") + reason
	_paper.show_run(won, reason)
	_over.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.menu_open = true


func _cliff_owner_name(cid: int) -> String:
	var who := Hud.owner_name(cid) # a player or a CPU teammate
	if who != "open" and who != "you":
		return who
	return "the " + WorldLayout.map().name_of(cid)


static func _outlined(text: String, size: int, color: Color) -> Label:
	var l := UiStyle.label(text, size, color)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	return l
