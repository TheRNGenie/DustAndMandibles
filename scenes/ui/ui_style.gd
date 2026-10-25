class_name UiStyle
extends RefCounted
## Shared western UI styling: wanted-poster panels, wooden-sign buttons, labels.
## StyleBoxFlat only, no textures.

static func poster() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.BONE
	sb.border_color = Palette.WOOD_DARK
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(6, 6)
	sb.set_content_margin_all(24)
	return sb


static func wood_sign() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.WOOD
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(3, 3)
	sb.set_content_margin_all(10)
	return sb


static func label(text: String, size: int = 16, color: Color = Palette.OUTLINE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 38
	var normal := wood_sign()
	normal.set_content_margin_all(6)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.WOOD.lightened(0.12)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", Palette.BONE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	return b


## A row with a left-aligned caption and a control on the right.
static func row(caption: String, control: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	var l := label(caption, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size.x = 260
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 260)
	r.add_child(control)
	return r


## A slider with a live value readout. `fmt` formats the value for display.
static func slider(min_v: float, max_v: float, step: float, value: float, fmt: String,
		on_change: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.x = 200
	var readout := label(fmt % value, 15)
	readout.custom_minimum_size.x = 60
	s.value_changed.connect(func(v: float) -> void:
		readout.text = fmt % v
		on_change.call(v))
	box.add_child(s)
	box.add_child(readout)
	return box


static func check(value: bool, on_change: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.button_pressed = value
	c.add_theme_color_override("font_color", Palette.OUTLINE)
	c.toggled.connect(func(on: bool) -> void: on_change.call(on))
	return c
