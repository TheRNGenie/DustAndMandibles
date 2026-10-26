class_name HudHotbar
extends Control
## Bottom-centre hotbar: eight wooden slots for keys 1-8, each showing a drawn
## icon of what's in it (empty slots stay blank).

const SLOT_SIZE := Vector2(76, 64)

var hotbar: Hotbar
var _panels: Array[PanelContainer] = []
var _icons: Array[ItemIcon] = []
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
	var width := SLOT_SIZE.x * 8 + 6 * 7 + 12
	row.offset_left = -width * 0.5
	row.offset_right = width * 0.5
	row.offset_top = -SLOT_SIZE.y - 14
	row.offset_bottom = -14
	add_child(row)
	for i in 8:
		if i == 3 or i == 6:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(6, 0)
			row.add_child(gap)
		var p := PanelContainer.new()
		p.custom_minimum_size = SLOT_SIZE
		row.add_child(p)
		var stack := Control.new()
		stack.custom_minimum_size = SLOT_SIZE - Vector2(8, 8)
		p.add_child(stack)
		var icon := ItemIcon.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(icon)
		var key := UiStyle.label(str(i + 1), 12, Palette.GLOW_YELLOW)
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		key.position = Vector2(2, -2)
		stack.add_child(key)
		var count := UiStyle.label("", 12, Palette.BONE)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.anchor_left = 1.0
		count.anchor_right = 1.0
		count.anchor_top = 1.0
		count.anchor_bottom = 1.0
		count.offset_left = -50
		count.offset_top = -18
		count.add_theme_color_override("font_outline_color", Palette.OUTLINE)
		count.add_theme_constant_override("outline_size", 4)
		stack.add_child(count)
		_panels.append(p)
		_icons.append(icon)
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
		_icons[i].item = info["id"]
		_icons[i].queue_redraw()
		_counts[i].text = str(info["count"])
		var sb := UiStyle.wood_sign()
		sb.set_content_margin_all(4)
		if bool(info["selected"]):
			sb.border_color = Palette.GLOW_YELLOW
			sb.bg_color = Palette.WOOD.lightened(0.15)
		elif info["id"] == &"":
			sb.bg_color = Palette.WOOD_DARK
		_panels[i].add_theme_stylebox_override("panel", sb)


## Simple drawn icons for hotbar items (no image files).
class ItemIcon extends Control:
	var item: StringName = &""

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.4
		var dark := Palette.OUTLINE
		match item:
			&"revolver":
				draw_rect(Rect2(c + Vector2(-s, -s * 0.35), Vector2(s * 1.5, s * 0.3)), Palette.METAL, true)
				draw_circle(c + Vector2(-s * 0.05, -s * 0.15), s * 0.28, Palette.METAL.lightened(0.15))
				_poly([c + Vector2(s * 0.1, -s * 0.1), c + Vector2(s * 0.55, -s * 0.1), c + Vector2(s * 0.8, s * 0.7), c + Vector2(s * 0.35, s * 0.75)], Palette.WOOD)
			&"lever_rifle":
				draw_rect(Rect2(c + Vector2(-s * 1.3, -s * 0.25), Vector2(s * 1.8, s * 0.18)), Palette.METAL, true)
				draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.3), Vector2(s * 0.5, s * 0.3)), Palette.GLOW_YELLOW.darkened(0.4), true)
				_poly([c + Vector2(s * 0.4, -s * 0.25), c + Vector2(s * 1.3, -s * 0.1), c + Vector2(s * 1.3, s * 0.35), c + Vector2(s * 0.4, s * 0.05)], Palette.WOOD)
				draw_arc(c + Vector2(s * 0.1, s * 0.15), s * 0.2, 0.0, PI, 10, dark, 2.0)
			&"coach_shotgun":
				draw_rect(Rect2(c + Vector2(-s * 1.2, -s * 0.35), Vector2(s * 1.4, s * 0.16)), Palette.METAL, true)
				draw_rect(Rect2(c + Vector2(-s * 1.2, -s * 0.16), Vector2(s * 1.4, s * 0.16)), Palette.METAL.darkened(0.15), true)
				_poly([c + Vector2(s * 0.2, -s * 0.35), c + Vector2(s * 1.2, -s * 0.15), c + Vector2(s * 1.2, s * 0.4), c + Vector2(s * 0.2, s * 0.0)], Palette.WOOD_DARK)
			&"corn":
				_poly([c + Vector2(0, -s), c + Vector2(s * 0.4, -s * 0.2), c + Vector2(s * 0.25, s * 0.8), c + Vector2(-s * 0.25, s * 0.8), c + Vector2(-s * 0.4, -s * 0.2)], Color("#F5D140"))
				_poly([c + Vector2(-s * 0.25, s * 0.9), c + Vector2(-s * 0.6, -s * 0.1), c + Vector2(-s * 0.1, s * 0.4)], Palette.CACTUS)
				_poly([c + Vector2(s * 0.25, s * 0.9), c + Vector2(s * 0.6, -s * 0.1), c + Vector2(s * 0.1, s * 0.4)], Palette.CACTUS)
			&"prickly_pear":
				draw_circle(c + Vector2(0, s * 0.1), s * 0.6, Color("#D94C8C"))
				for k in 5:
					var a := TAU * k / 5.0
					draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.35 + Vector2(0, s * 0.1), s * 0.05, Palette.BONE)
			&"chili":
				_poly([c + Vector2(-s * 0.2, -s * 0.6), c + Vector2(s * 0.25, -s * 0.5), c + Vector2(s * 0.35, s * 0.2), c + Vector2(-s * 0.2, s * 0.9), c + Vector2(-s * 0.35, s * 0.1)], Color("#E3361F"))
				draw_line(c + Vector2(0, -s * 0.6), c + Vector2(s * 0.2, -s * 0.95), Palette.CACTUS, 3.0)
			&"herbs":
				draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.2), Vector2(s * 0.9, s * 1.0)), Palette.BONE, true)
				draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.05), Vector2(s * 0.24, s * 0.7)), Palette.TEAM_WEST, true)
				draw_rect(Rect2(c + Vector2(-s * 0.35, s * 0.18), Vector2(s * 0.7, s * 0.24)), Palette.TEAM_WEST, true)
				for k in 3:
					draw_circle(c + Vector2(-s * 0.3 + k * s * 0.3, -s * 0.45), s * 0.18, Color("#8CC66E"))
			&"hammer":
				draw_line(c + Vector2(-s * 0.5, s * 0.7), c + Vector2(s * 0.3, -s * 0.3), Palette.WOOD, 5.0)
				_poly([c + Vector2(s * 0.0, -s * 0.7), c + Vector2(s * 0.7, -s * 0.0), c + Vector2(s * 0.5, s * 0.2), c + Vector2(-s * 0.2, -s * 0.5)], Palette.METAL)
			&"planks":
				for k in 3:
					_poly([c + Vector2(-s * 0.8, -s * 0.55 + k * s * 0.45), c + Vector2(s * 0.8, -s * 0.75 + k * s * 0.45),
							c + Vector2(s * 0.8, -s * 0.45 + k * s * 0.45), c + Vector2(-s * 0.8, -s * 0.25 + k * s * 0.45)], Palette.WOOD.lightened(0.1 * k))
			&"shield":
				_poly([c + Vector2(-s * 0.7, -s * 0.7), c + Vector2(s * 0.7, -s * 0.7), c + Vector2(s * 0.6, s * 0.2), c + Vector2(0, s * 0.85), c + Vector2(-s * 0.6, s * 0.2)], Palette.METAL)
				draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.2), Vector2(s * 1.4, s * 0.18)), Palette.METAL.darkened(0.35), true)
			&"house":
				draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.1), Vector2(s * 1.2, s * 0.9)), Palette.WOOD, true)
				_poly([c + Vector2(-s * 0.8, -s * 0.05), c + Vector2(0, -s * 0.8), c + Vector2(s * 0.8, -s * 0.05)], Palette.ROOF)
				draw_rect(Rect2(c + Vector2(-s * 0.15, s * 0.3), Vector2(s * 0.3, s * 0.5)), Palette.WOOD_DARK, true)
			&"water":
				_poly([c + Vector2(-s * 0.6, -s * 0.4), c + Vector2(s * 0.6, -s * 0.4), c + Vector2(s * 0.45, s * 0.8), c + Vector2(-s * 0.45, s * 0.8)], Palette.WOOD)
				draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.4), Vector2(s * 1.1, s * 0.2)), Palette.SKY_TOP, true)
				draw_arc(c + Vector2(0, -s * 0.4), s * 0.6, PI, TAU, 12, Palette.METAL, 2.0)

	func _poly(points: Array, color: Color) -> void:
		var packed := PackedVector2Array(points)
		draw_colored_polygon(packed, color)
		packed.append(points[0])
		draw_polyline(packed, Palette.OUTLINE, 1.5)
