class_name HudFeed
extends Control
## Right side: the shared kill feed (who saved whom), structure events and the
## warning-phase lane report. Center: interaction prompt, build status, game over.
## Seeing "your turret saved your partner" is what makes the cross-defense click.

const FEED_LINES := 6
const FEED_LIFETIME := 7.0

var cliff_id: int = 0
var _feed: VBoxContainer
var _spare: Array[Label] = []
var _card: HudPromptCard
var _prompt_text := ""
## Debug: --prompttest="Title|E: Do this   F: That" pins the prompt card ("|" breaks lines).
var _prompt_test := ""
var _over: Control
var _over_strap: PanelContainer
var _over_scroll: ScrollContainer
var _paper: NewspaperFront
var _story_btn: Button
var _over_label: Label
var _keep_going: Button
var _build_mode: BuildMode
var _boss_box: VBoxContainer
var _boss_plate: PanelContainer
var _boss_pcts: Array[Label] = []
## One name + bar per boss on the field (two in the finale).
var _boss_bars: Array[ProgressBar] = []
var _boss_labels: Array[Label] = []
## Bosses already announced in the feed (by instance id).
var _boss_seen: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("hud_feed")
	_prompt_test = GameState.flag_value("--prompttest").replace("|", char(10))
	_feed = VBoxContainer.new()
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.offset_left = -620
	_feed.offset_right = -24
	_feed.offset_top = 90 # pushed below the wave preview while it shows (_process)
	_feed.add_theme_constant_override("separation", 4)
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_feed)

	_card = HudPromptCard.new()
	add_child(_card)

	# End of the run: the shared menu frame (scrim, strap, paper, footer buttons)
	# around the newsprint front page and the Notches report.
	var over_layer := CanvasLayer.new()
	over_layer.layer = 40 # over the rest of the HUD, under the menus
	add_child(over_layer)
	_over = Control.new()
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.visible = false
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	over_layer.add_child(_over)
	_over.add_child(UiStyle.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.add_child(center)
	var frame := UiStyle.panel("FramePanel")
	center.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	frame.add_child(outer)
	_over_strap = UiStyle.strap("The Run Is Over", "", 30)
	outer.add_child(_over_strap)
	var card := UiStyle.panel("PaperPanel")
	outer.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	card.add_child(inner)
	_over_scroll = ScrollContainer.new()
	_over_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(_over_scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiStyle.GAP_GROUP)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_over_scroll.add_child(col)
	_over_label = UiStyle.label("", 26)
	_over_label.visible = false # the newspaper carries the result now
	col.add_child(_over_label)
	_paper = NewspaperFront.new() # end-of-run front page (RunStats)
	_paper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_paper)
	RunStats.reset() # a new world = a new run
	col.add_child(BrandsReport.new()) # Perk: Brands earned this run
	Perks.run_banked.connect(func(_r: Dictionary) -> void: _fit_over.call_deferred())
	_over.resized.connect(func() -> void: _fit_over.call_deferred())
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", UiStyle.GAP_ROW)
	inner.add_child(footer)
	# After a win: keep the waves coming past the last one (host decides).
	_keep_going = MenuScreen.wood_button("Keep Going (Endless)")
	_keep_going.theme_type_variation = "PrimaryButton" # the call to action when it shows
	_keep_going.visible = false
	_keep_going.pressed.connect(func() -> void: GameState.continue_endless())
	footer.add_child(_keep_going)
	# Story: the host retries a lost chapter or rides on to the next one.
	_story_btn = MenuScreen.wood_button("Retry Chapter")
	_story_btn.theme_type_variation = "PrimaryButton"
	_story_btn.visible = false
	_story_btn.pressed.connect(func() -> void:
		var next := str(_story_btn.get_meta("chapter", ""))
		if next != "":
			Story.restart(next))
	footer.add_child(_story_btn)
	var back := MenuScreen.wood_button("Back to Main Menu")
	back.pressed.connect(func() -> void:
		NetworkManager.leave()
		GameState.reset()
		SceneFade.go(NetworkManager.MENU_SCENE))
	footer.add_child(back)

	# Boss bars: a plate under the phase plaque, one name and bar per boss.
	_boss_plate = KeyHints.plate("plate_tight")
	_boss_plate.anchor_left = 0.5
	_boss_plate.anchor_right = 0.5
	_boss_plate.offset_left = -330
	_boss_plate.offset_right = 330
	_boss_plate.offset_top = 104
	_boss_plate.visible = false
	add_child(_boss_plate)
	_boss_box = VBoxContainer.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_theme_constant_override("separation", 3)
	_boss_plate.add_child(_boss_box)
	for k in 2:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_box.add_child(head)
		var skull := UiStyle.mark("warn", UiStyle.hud_c("bad"), 16)
		head.add_child(skull)
		var label := KeyHints.ink("", 18 if k == 0 else 16)
		label.add_theme_font_override("font", UiStyle.font("bold"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		head.add_child(label)
		var pct := KeyHints.number("", 16)
		head.add_child(pct)
		var bar := UiStyle.bar(Palette.TEAM_WEST if k == 0 else Palette.TEAM_WEST.lerp(Palette.GLOW_YELLOW, 0.35),
				Vector2(636, 20 if k == 0 else 15)) # one bar style everywhere
		_boss_box.add_child(bar)
		_boss_labels.append(label)
		_boss_bars.append(bar)
		_boss_pcts.append(pct)
	WaveDirector.wave_announced.connect(_on_wave_announced)
	Economy.notice.connect(func(t: String) -> void: add_line(t, UiStyle.c("title")))
	GameState.game_over.connect(_on_game_over)
	GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
		if p == GameState.Phase.WARNING:
			Audio.play_ui(&"bell")
		if p != GameState.Phase.GAME_OVER and _over.visible:
			# Endless mode picked up after the win screen: back to the game.
			_over.visible = false
			GameState.set_menu(self, false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if GameState.menu_open else Input.MOUSE_MODE_CAPTURED # another screen may still be up
			add_line("Endless! The waves keep coming. How long can you hold?", UiStyle.c("title"))
		)
	GameState.weather_changed.connect(func(k: int) -> void:
		if k != Weather.Kind.CLEAR or GameState.phase == GameState.Phase.WARNING:
			add_line(Weather.BLURBS[k], UiStyle.hud_c("bad") if k == Weather.Kind.BLOOD_MOON else (Palette.SKY_TOP if k != Weather.Kind.SNOW else UiStyle.c("hud"))))


func bind_player(player: Player, bugs: BugManager, builds: BuildManager) -> void:
	cliff_id = player.cliff_id
	_build_mode = player.build_mode
	player.vitals.prompt_changed.connect(func(t: String) -> void: _prompt_text = t)
	bugs.bug_killed.connect(_on_bug_killed)
	builds.structure_event.connect(func(t: String) -> void: add_line(t, Color(UiStyle.c("hud"), 0.8)))


func _process(_delta: float) -> void:
	# The feed sits under the wave preview card when that's up in the corner.
	# Maps: never over the other cliffs' homestead bars stacked top-right.
	var top := HudStatus.right_stack_bottom() + 10.0
	for c in get_parent().get_children():
		if c is HudWavePreview and (c as Control).visible:
			top = (c as Control).position.y + (c as Control).size.y + 10.0
	# ...and under the style grade letter, which hangs under the wave card.
	var hud_root := get_parent() as Hud
	if hud_root != null and hud_root.combo != null:
		top = maxf(top, hud_root.combo.bottom() + 6.0)
	_feed.offset_top = top
	if _build_mode != null and _build_mode.active and not _build_mode.menu_open:
		var hud := get_parent() as Hud
		var icon: Texture2D = hud.build_menu.icon_for(_build_mode.selected_id()) if hud != null else null
		_card.show_build(_build_mode.build_info(icon))
	elif _build_mode != null and _build_mode.menu_open:
		_card.show_text("")
	else:
		_card.show_text(_prompt_text if _prompt_test == "" else _prompt_test)
	_update_boss_bar()


func _update_boss_bar() -> void:
	var bosses: Array[Bug] = []
	var pool: Array = BugManager.instance.bosses if is_instance_valid(BugManager.instance) else get_tree().get_nodes_in_group("bugs")
	for n: Node in pool:
		var b := n as Bug
		if is_instance_valid(b) and b.def.behavior == BugDef.Behavior.BOSS and b.is_alive():
			bosses.append(b)
	_boss_plate.visible = not bosses.is_empty()
	for k in _boss_bars.size():
		var on := k < bosses.size()
		_boss_bars[k].visible = on
		_boss_labels[k].get_parent().visible = on
		if not on:
			continue
		var boss := bosses[k]
		if not _boss_seen.has(boss.get_instance_id()):
			_boss_seen[boss.get_instance_id()] = true
			add_line(boss.def.boss_tip if boss.def.boss_tip != "" else "%s Is Coming!" % UiStyle.tc(boss.def.display_name), UiStyle.hud_c("bad"))
		_boss_bars[k].max_value = boss.health.max_hp
		_boss_bars[k].value = boss.health.hp
		_boss_pcts[k].text = "%d%%" % ceili(100.0 * maxf(boss.health.hp, 0.0) / maxf(boss.health.max_hp, 1.0))
		var status := boss.boss.hud_status() if boss.boss != null else ""
		_boss_labels[k].text = "%s  ·  %s%s" % [UiStyle.tc(boss.def.display_name), WorldLayout.map().name_of(boss.cliff_id), # Maps:
				("  ·  " + status) if status != "" else ""]


func add_line(text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	if color.a == 0.0:
		color = UiStyle.c("hud")
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
	var l := _line(text, color)
	l.set_meta("base", text)
	l.set_meta("count", 1)
	_feed.add_child(l)
	while _feed.get_child_count() > FEED_LINES:
		_retire(_feed.get_child(0) as Label)
	_fade_later(l)


## A feed line: a spare one when there is one (a busy wave used to build and
## free a styled label for every kill), else a new one.
func _line(text: String, color: Color) -> Label:
	var l: Label = _spare.pop_back() if not _spare.is_empty() else null
	if l == null:
		l = UiStyle.label(text, 16, color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# Each line sits on its own small plate (no loose text over the sky); the
		# kit's shared feed plate, so it follows the UI set by itself.
		l.add_theme_stylebox_override("normal", KeyHints.kit_box("feed"))
		l.size_flags_horizontal = Control.SIZE_SHRINK_END
		l.autowrap_mode = TextServer.AUTOWRAP_OFF # one line, hugging its text
	else:
		l.text = text
		l.add_theme_color_override("font_color", color)
		l.add_theme_font_size_override("font_size", UiStyle.ts(16))
		l.modulate.a = 1.0
	# A long line (a boss tip) wraps across the feed's full width; short ones hug their text.
	var long := text.length() > 64
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long else TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_FILL if long else Control.SIZE_SHRINK_END
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if long else HORIZONTAL_ALIGNMENT_RIGHT
	return l


## Takes a line off the feed and keeps it for the next one.
func _retire(l: Label) -> void:
	if l == null:
		return
	var old: Variant = l.get_meta("tween") if l.has_meta("tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	l.remove_meta("tween")
	if l.get_parent() != null:
		l.get_parent().remove_child(l)
	if _spare.size() < FEED_LINES * 2:
		_spare.append(l)
	else:
		l.queue_free()


## (Re)starts a feed line's countdown to fade out.
func _fade_later(l: Label) -> void:
	var old: Variant = l.get_meta("tween") if l.has_meta("tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := l.create_tween()
	tw.tween_interval(FEED_LIFETIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_retire.bind(l))
	l.set_meta("tween", tw)


func _on_bug_killed(bug_name: String, bug_cliff: int, source: String, source_cliff: int, loot: Dictionary) -> void:
	if source_cliff == -2:
		add_line(bug_name, Color(UiStyle.c("hud"), 0.8)) # a plain announcement (e.g. a bandit escaped)
		return
	var scrap := int(loot.get(&"scrap", 0))
	RunStats.note_kill(bug_name, source, scrap) # for the end-of-run newspaper
	var saved := _cliff_owner_name(bug_cliff)
	var text: String
	if source_cliff >= 0 and source_cliff != bug_cliff:
		text = "%s saved %s from %s (+%s to %s)" % [source, saved, _a(bug_name), UiStyle.cost(scrap, ResNames.TEAM_ID), saved]
	elif source != "":
		text = "%s got %s (+%s)" % [source, _a(bug_name), UiStyle.cost(scrap, ResNames.TEAM_ID)]
	else:
		text = "%s went down (+%s)" % [bug_name if bug_name.begins_with("The ") else "A " + bug_name, UiStyle.cost(scrap, ResNames.TEAM_ID)]
	var mine := source_cliff == cliff_id or bug_cliff == cliff_id
	add_line(text, UiStyle.c("title") if mine else UiStyle.c("hud"))


## "a Dust Mite", but "The Hive Mother" (a boss's name already has its article).
static func _a(bug_name: String) -> String:
	return bug_name if bug_name.begins_with("The ") else "a " + bug_name


func _on_wave_announced(heavy_cliff: int, west_share: float, lane_counts: Array) -> void:
	var m := WorldLayout.map()
	var heavy := "Both cliffs equally" if m.count() == 2 else "Every cliff about equally"
	if heavy_cliff >= 0:
		var pct := maxf(west_share, 1.0 - west_share) if m.count() == 2 else west_share
		heavy = "%s gets %d%%" % [m.name_of(heavy_cliff), int(roundf(pct * 100.0))]
	add_line("Dust on the horizon! %s." % heavy, UiStyle.c("title"))


func _on_game_over(won: bool, reason: String) -> void:
	_over_label.text = ("YOU WIN!\n" if won else "THE CANYON IS LOST\n") + reason
	var ch := Story.chapter()
	if ch != null:
		_story_end.call_deferred(ch, won, reason) # after StoryDirector has booked the result
	else:
		_paper.show_run(won, reason)
	(_over_strap.find_child("Title", true, false) as Label).text = "The Canyon Held" if won else "The Canyon Fell"
	_keep_going.visible = won and multiplayer.is_server() and ch == null # the host decides whether to ride on
	_over.visible = true
	UiStyle.fade_in(_over)
	# The front page fills in over a few frames: fit again whenever its size settles.
	var page := _over_scroll.get_child(0) as Control
	if not page.minimum_size_changed.is_connected(_refit_over):
		page.minimum_size_changed.connect(_refit_over)
	_fit_over.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.set_menu(self, true)


## Story: the chapter's front page, and the host's Retry / Next Chapter button.
func _story_end(ch: StoryChapter, won: bool, reason: String) -> void:
	_paper.show_chapter(ch, won, reason, Story.last_result)
	(_over_strap.find_child("Title", true, false) as Label).text = ("Chapter %d Complete" if won else "Chapter %d Lost") % ch.number
	var next := StoryChapter.next_id(ch.id) if won else ch.id
	_story_btn.visible = multiplayer.is_server() and next != ""
	_story_btn.set_meta("chapter", next)
	if next != "":
		_story_btn.text = "Retry Chapter" if not won else "Next: %s" % StoryChapter.load_id(next).title
	_fit_over.call_deferred()


var _refit_queued := false


func _refit_over() -> void:
	if _refit_queued or _over == null or not _over.visible:
		return
	_refit_queued = true
	_fit_over.call_deferred()


## The front page scrolls only when the screen is too short for it.
func _fit_over() -> void:
	_refit_queued = false
	if not _over.visible:
		return
	# Wrapped lines only know their height once laid out at their real width.
	for i in 2:
		await get_tree().process_frame
	var content := (_over_scroll.get_child(0) as Control).get_combined_minimum_size()
	var frame := _over_strap.get_parent().get_parent() as Control
	var chrome := frame.get_combined_minimum_size().y - _over_scroll.custom_minimum_size.y
	var room := _over.size.y - 48.0 - chrome
	_over_scroll.custom_minimum_size = Vector2(content.x, clampf(content.y, 120.0, maxf(room, 120.0)))
	# Belt and braces: some sequences (a game over straight after a wave) left the
	# page laid out at 0 height until something else resized it; nudge the layout
	# until the size takes.
	for k in 4:
		await get_tree().process_frame
		if not _over.visible or _over_scroll.size.y >= _over_scroll.custom_minimum_size.y - 1.0:
			break
		_paper.update_minimum_size()
		_over_scroll.update_minimum_size()
		var holder := frame.get_parent() as Container
		if holder != null:
			holder.queue_sort()


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for l: Label in _spare: # spare lines sit outside the tree
			if is_instance_valid(l):
				l.free()
		_spare.clear()
