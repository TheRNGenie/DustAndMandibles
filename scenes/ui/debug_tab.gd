class_name DebugTab
extends VBoxContainer
## Settings > Debug: turn debug mode on or off, and buttons for every cheat
## (they also have hotkeys). In multiplayer only the host's debug mode counts.


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiStyle.row("Debug mode", UiStyle.check(Settings.debug_mode,
			func(on: bool) -> void:
				Settings.set_value("debug_mode", on)
				_refresh())))
	add_child(UiStyle.note("Cheats for testing. Online, they only work when the host has debug mode on."))
	for entry: Array in [["skip", "Skip to the next phase", "debug_skip_phase"],
			["scrap", "+500 scrap, +50 chitin", "debug_add_scrap"],
			["spawn", "Spawn a bug on your partner's cliff", "debug_spawn_bug"],
			["god", "God mode on/off", "debug_god_mode"],
			["lanes", "Show climb lanes", "debug_show_lanes"]]:
		var b := UiStyle.button("%s  (%s)" % [entry[1], Settings.binding_label(entry[2])])
		b.set_meta("kind", entry[0])
		b.pressed.connect(func() -> void:
			if DebugTools.instance != null and is_instance_valid(DebugTools.instance):
				DebugTools.instance.run(str(entry[0])))
		add_child(b)
	visibility_changed.connect(_refresh)
	add_child(UiStyle.note("Performance overlay: %s (works any time)." % Settings.binding_label("debug_overlay")))
	_refresh()


func _refresh() -> void:
	var in_game := DebugTools.instance != null and is_instance_valid(DebugTools.instance) and DebugTools.instance.is_inside_tree()
	for c: Node in get_children():
		if c is Button and c.has_meta("kind"):
			(c as Button).disabled = not (Settings.debug_mode or GameState.has_flag("--debug")) or not in_game
