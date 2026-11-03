class_name GraphicsTab
extends VBoxContainer
## Graphics tab: display options (brightness, FPS cap, V-Sync, fullscreen, FOV,
## colour-blind shapes), then a Quality preset (Low / Medium / High / Custom)
## and the settings it drives. Changing one of those by hand makes it Custom.

const LEVELS: Array[String] = ["Low", "Medium", "High"]

var _quality: OptionButton


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_child(UiStyle.row("Brightness", UiStyle.slider(0.5, 1.6, 0.05, Settings.brightness, "%.2f",
			func(v: float) -> void: Settings.set_value("brightness", v))))

	var fps := OptionButton.new()
	for cap in Settings.FPS_CAPS:
		fps.add_item("Unlimited" if cap == 0 else "%d FPS" % cap)
	fps.selected = maxi(Settings.FPS_CAPS.find(Settings.fps_cap), 0)
	fps.item_selected.connect(func(i: int) -> void: Settings.set_value("fps_cap", Settings.FPS_CAPS[i]))
	add_child(UiStyle.row("FPS Cap", fps))

	add_child(UiStyle.row("V-Sync", UiStyle.check(Settings.vsync,
			func(on: bool) -> void: Settings.set_value("vsync", on))))
	add_child(UiStyle.row("Fullscreen", UiStyle.check(Settings.fullscreen,
			func(on: bool) -> void: Settings.set_value("fullscreen", on))))
	add_child(UiStyle.row("Field of View", UiStyle.slider(70.0, 110.0, 1.0, Settings.fov, "%.0f",
			func(v: float) -> void: Settings.set_value("fov", v))))
	add_child(UiStyle.row("Colour-Blind Shapes", UiStyle.check(Settings.colorblind,
			func(on: bool) -> void: Settings.set_value("colorblind", on))))

	add_child(UiStyle.divider())

	# Quality preset: picking one sets everything below.
	_quality = OptionButton.new()
	for n: String in GraphicsQuality.NAMES:
		_quality.add_item(n)
	_quality.set_item_disabled(GraphicsQuality.NAMES.size() - 1, true) # Custom: change a setting below
	_show_quality()
	_quality.item_selected.connect(func(i: int) -> void:
		if i < GraphicsQuality.PRESETS.size():
			Settings.set_quality(GraphicsQuality.PRESETS[i])
			_build.call_deferred())
	add_child(UiStyle.row("Quality", _quality))

	if Settings.is_compatibility():
		var note := UiStyle.label("Compatibility (Safe Mode), No Shadows", 15)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(UiStyle.row("Renderer", note))

	add_child(UiStyle.row("Shadows", UiStyle.check(Settings.shadows,
			func(on: bool) -> void: _change("shadows", on))))
	add_child(UiStyle.row("Shadow Detail", _levels(Settings.shadow_detail, "shadow_detail")))

	var aa := OptionButton.new()
	for label: String in ["Off", "2x MSAA", "4x MSAA", "8x MSAA"]:
		aa.add_item(label)
	aa.selected = clampi(Settings.msaa, 0, 3)
	aa.item_selected.connect(func(i: int) -> void: _change("msaa", i))
	add_child(UiStyle.row("Anti-Aliasing", aa))

	add_child(UiStyle.row("Render Scale", UiStyle.slider(0.5, 1.0, 0.05, Settings.render_scale, "%.2f",
			func(v: float) -> void: _change("render_scale", v))))
	add_child(UiStyle.row("Effects (Glow)", _levels(Settings.effects, "effects")))
	add_child(UiStyle.row("View Distance", _levels(Settings.view_distance, "view_distance")))
	add_child(UiStyle.row("Particles", _levels(Settings.particles, "particles")))
	add_child(UiStyle.row("Bug Detail", _levels(Settings.bug_detail, "bug_detail")))


## A Low / Medium / High picker for one setting.
func _levels(value: int, key: String) -> OptionButton:
	var o := OptionButton.new()
	for n: String in LEVELS:
		o.add_item(n)
	o.selected = GraphicsQuality.level(value)
	o.item_selected.connect(func(i: int) -> void: _change(key, i))
	return o


## Changes one preset-driven setting; the Quality picker then shows the preset
## it matches, or Custom.
func _change(key: String, value: Variant) -> void:
	Settings.set_value(key, value)
	_show_quality()


func _show_quality() -> void:
	var qi := GraphicsQuality.PRESETS.find(Settings.quality)
	_quality.set_block_signals(true)
	_quality.selected = qi if qi >= 0 else GraphicsQuality.NAMES.size() - 1
	_quality.set_block_signals(false)
