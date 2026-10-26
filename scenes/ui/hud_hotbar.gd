class_name HudHotbar
extends Control
## Bottom-centre hotbar: eight wooden slots for keys 1-8.

const SLOT_SIZE := Vector2(84, 52)

var hotbar: Hotbar
var _panels: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _counts: Array[Label] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	var width := SLOT_SIZE.x * 8 + 6 * 7
	row.offset_left = -width * 0.5
	row.offset_right = width * 0.5
	row.offset_top = -SLOT_SIZE.y - 14
	row.offset_bottom = -14
	add_child(row)
	for i in 8:
		var p := PanelContainer.new()
		p.custom_minimum_size = SLOT_SIZE
		row.add_child(p)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		p.add_child(box)
		var top := HBoxContainer.new()
		box.add_child(top)
		var key := UiStyle.label(str(i + 1), 12, Palette.GLOW_YELLOW)
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(key)
		var count := UiStyle.label("", 12, Palette.BONE)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(count)
		var name_label := UiStyle.label("", 13, Palette.BONE)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		box.add_child(name_label)
		_panels.append(p)
		_labels.append(name_label)
		_counts.append(count)


func bind(h: Hotbar) -> void:
	hotbar = h
	hotbar.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if hotbar == null:
		return
	for i in 8:
		var info := hotbar.slot_info(i)
		_labels[i].text = str(info["label"])
		_counts[i].text = str(info["count"])
		var sb := UiStyle.wood_sign()
		sb.set_content_margin_all(4)
		if bool(info["selected"]):
			sb.border_color = Palette.GLOW_YELLOW
			sb.bg_color = Palette.WOOD.lightened(0.15)
		_panels[i].add_theme_stylebox_override("panel", sb)
		_panels[i].modulate = Color(1, 1, 1, 1.0 if bool(info["available"]) else 0.45)
