class_name GraphicsTab
extends VBoxContainer
## Graphics tab: brightness, FPS cap, V-Sync, fullscreen, FOV, shadows, anti-aliasing, render scale.


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiStyle.row("Brightness", UiStyle.slider(0.5, 1.6, 0.05, Settings.brightness, "%.2f",
			func(v: float) -> void: Settings.set_value("brightness", v))))

	var fps := OptionButton.new()
	for cap in Settings.FPS_CAPS:
		fps.add_item("Unlimited" if cap == 0 else "%d FPS" % cap)
	fps.selected = maxi(Settings.FPS_CAPS.find(Settings.fps_cap), 0)
	fps.item_selected.connect(func(i: int) -> void: Settings.set_value("fps_cap", Settings.FPS_CAPS[i]))
	add_child(UiStyle.row("FPS cap", fps))

	add_child(UiStyle.row("V-Sync", UiStyle.check(Settings.vsync,
			func(on: bool) -> void: Settings.set_value("vsync", on))))
	add_child(UiStyle.row("Fullscreen", UiStyle.check(Settings.fullscreen,
			func(on: bool) -> void: Settings.set_value("fullscreen", on))))
	add_child(UiStyle.row("Field of view", UiStyle.slider(70.0, 110.0, 1.0, Settings.fov, "%.0f",
			func(v: float) -> void: Settings.set_value("fov", v))))
	add_child(UiStyle.row("Shadows", UiStyle.check(Settings.shadows,
			func(on: bool) -> void: Settings.set_value("shadows", on))))

	var aa := OptionButton.new()
	for label: String in ["Off", "2x MSAA", "4x MSAA", "8x MSAA"]:
		aa.add_item(label)
	aa.selected = Settings.msaa
	aa.item_selected.connect(func(i: int) -> void: Settings.set_value("msaa", i))
	add_child(UiStyle.row("Anti-aliasing", aa))

	add_child(UiStyle.row("Render scale", UiStyle.slider(0.5, 1.0, 0.05, Settings.render_scale, "%.2f",
			func(v: float) -> void: Settings.set_value("render_scale", v))))
