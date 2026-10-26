class_name HudFeed
extends Control
## Right side: the shared kill feed (who saved whom), structure events and the
## warning-phase lane report. Center: interaction prompt, build status, game over.
## Seeing "your turret saved your partner" is what makes the cross-defense click.

const FEED_LINES := 6
const FEED_LIFETIME := 7.0

var cliff_id: int = 0
var _feed: VBoxContainer
var _prompt: Label
var _build: Label
var _over: PanelContainer
var _over_label: Label
var _build_mode: BuildMode


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed = VBoxContainer.new()
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.offset_left = -700
	_feed.offset_right = -24
	_feed.offset_top = 90
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_feed)

	_prompt = _outlined("", 20, Palette.BONE)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = 30
	add_child(_prompt)

	_build = _outlined("", 18, Palette.GLOW_YELLOW)
	_build.anchor_left = 0.5
	_build.anchor_right = 0.5
	_build.anchor_top = 1.0
	_build.anchor_bottom = 1.0
	_build.offset_left = -420
	_build.offset_right = 420
	_build.offset_top = -150
	add_child(_build)

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
	col.add_child(_over_label)
	var back := UiStyle.button("Back to main menu")
	back.pressed.connect(func() -> void:
		NetworkManager.leave()
		GameState.reset()
		get_tree().change_scene_to_file(NetworkManager.MENU_SCENE))
	col.add_child(back)

	WaveDirector.wave_announced.connect(_on_wave_announced)
	GameState.game_over.connect(_on_game_over)
	GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
		if p == GameState.Phase.WARNING:
			Audio.play_ui(&"bell"))


func bind_player(player: Player, bugs: BugManager, builds: BuildManager) -> void:
	cliff_id = player.cliff_id
	_build_mode = player.build_mode
	player.vitals.prompt_changed.connect(func(t: String) -> void: _prompt.text = t)
	bugs.bug_killed.connect(_on_bug_killed)
	builds.structure_event.connect(func(t: String) -> void: add_line(t, Palette.ROCK_C))


func _process(_delta: float) -> void:
	_build.text = _build_mode.status_text() if _build_mode != null else ""


func add_line(text: String, color: Color = Palette.BONE) -> void:
	var l := _outlined(text, 16, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_child(l)
	while _feed.get_child_count() > FEED_LINES:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(FEED_LIFETIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_bug_killed(bug_name: String, bug_cliff: int, source: String, source_cliff: int, loot: Dictionary) -> void:
	var scrap := int(loot.get(&"scrap", 0))
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
	var heavy := "Both cliffs equally"
	if heavy_cliff >= 0:
		heavy = "%s cliff gets %d%%" % ["West" if heavy_cliff == WorldLayout.WEST else "East",
				int(roundf(maxf(west_share, 1.0 - west_share) * 100.0))]
	add_line("Dust on the horizon! %s." % heavy, Palette.GLOW_YELLOW)
	var mine: Array = lane_counts[WorldLayout.other_cliff(cliff_id)]
	var busiest := 0
	for i in mine.size():
		if int(mine[i]) > int(mine[busiest]):
			busiest = i
	add_line("Your partner's busiest lane: %d of 5 (watch it with your turrets)." % (busiest + 1), Palette.BONE)


func _on_game_over(won: bool, reason: String) -> void:
	_over_label.text = ("YOU WIN!\n" if won else "THE CANYON IS LOST\n") + reason
	_over.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.menu_open = true


func _cliff_owner_name(cid: int) -> String:
	for id: int in NetworkManager.players:
		var p: Dictionary = NetworkManager.players[id]
		if int(p["cliff"]) == cid:
			return str(p["name"])
	return "the west" if cid == WorldLayout.WEST else "the east"


static func _outlined(text: String, size: int, color: Color) -> Label:
	var l := UiStyle.label(text, size, color)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	return l
