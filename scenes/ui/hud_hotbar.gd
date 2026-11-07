class_name HudHotbar
extends Control
## Bottom-centre hotbar: nine wooden slots for keys 1-9, each showing a drawn
## icon of what's in it (empty slots stay blank).

const SLOT_SIZE := Vector2(90, 80) # sized against the status and ammo panels

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
	var width := SLOT_SIZE.x * Hotbar.SLOTS + 6 * (Hotbar.SLOTS - 1) + 18
	row.offset_left = -width * 0.5
	row.offset_right = width * 0.5
	row.offset_top = -SLOT_SIZE.y - 14
	row.offset_bottom = -14
	add_child(row)
	for i in Hotbar.SLOTS:
		if i == 3 or i == 6 or i == 8:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(6, 0)
			row.add_child(gap)
		var p := PanelContainer.new()
		p.custom_minimum_size = SLOT_SIZE
		row.add_child(p)
		var stack := Control.new()
		stack.custom_minimum_size = SLOT_SIZE - Vector2(8, 8)
		stack.clip_contents = true # long guns fill the slot's width without spilling
		p.add_child(stack)
		var icon := ItemIcon.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.host = self
		stack.add_child(icon)
		var key := UiStyle.label(str((i + 1) % 10), 14, UiStyle.c("title")) # the 10th slot is key 0
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		key.position = Vector2(2, -2)
		stack.add_child(key)
		var count := UiStyle.label("", 16, UiStyle.c("hud"))
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.anchor_left = 1.0
		count.anchor_right = 1.0
		count.anchor_top = 1.0
		count.anchor_bottom = 1.0
		count.offset_left = -50
		count.offset_top = -22
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


## What each slot last showed ([id, count, selected, theme]): refresh() only
## touches the slots that changed (it runs on every ledger change).
var _shown: Array = []


func refresh() -> void:
	if hotbar == null:
		return
	_shown.resize(Hotbar.SLOTS)
	for i in Hotbar.SLOTS:
		var info := hotbar.slot_info(i)
		var state := [info["id"], info["count"], bool(info["selected"]), UiStyle.current]
		if _shown[i] == state:
			continue
		var was: Array = _shown[i] if _shown[i] is Array else []
		_shown[i] = state
		_counts[i].text = str(info["count"])
		if was.is_empty() or was[0] != info["id"]:
			_icons[i].item = info["id"]
			_icons[i].queue_redraw()
			# Icons render a frame later: redraw once they're ready.
			get_tree().create_timer(0.2).timeout.connect(_icons[i].queue_redraw)
		if not was.is_empty() and was[2] == state[2] and was[3] == state[3] and (was[0] == &"") == (info["id"] == &""):
			continue
		var sb := UiStyle.wood_sign()
		sb.set_content_margin_all(4)
		if bool(info["selected"]): # Theme: the set's trim lights the picked slot
			sb.border_color = UiStyle.c("gold")
			sb.set_border_width_all(3)
			sb.bg_color = sb.bg_color.lightened(0.18)
		elif info["id"] == &"":
			sb.bg_color.a *= 0.6
		_panels[i].add_theme_stylebox_override("panel", sb)


## Simple drawn icons for hotbar items (no image files).
class ItemIcon extends Control:
	var item: StringName = &""
	## Where the 3D icon renders live (the hotbar itself).
	var host: Node

	func _draw() -> void:
		# A painted icon (assets/icons) where there is one; then a picture of the
		# real model; the drawn icon otherwise.
		var painted: Texture2D = UiStyle.painted_icon(item) if item != &"" and not GunModels.has(item) else null
		var pr := get_node_or_null("Painted") as TextureRect
		if painted != null:
			if pr == null:
				pr = TextureRect.new()
				pr.name = "Painted"
				pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				add_child(pr)
			pr.texture = painted
			pr.visible = true
			return
		if pr != null:
			pr.visible = false
		if item != &"" and host != null:
			var tex := IconStudio.item(host, item)
			if tex != null:
				var side := maxf(size.x, size.y) * 1.1 # fill the width: most items are long guns
				draw_texture_rect(tex, Rect2(size * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side)), false)
				return
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.45
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
			&"blunderbuss":
				# Short barrel flaring into a bell, chunky stock.
				draw_rect(Rect2(c + Vector2(-s * 0.9, -s * 0.3), Vector2(s * 1.1, s * 0.16)), Color("#D6A74A"), true)
				_poly([c + Vector2(-s * 0.9, -s * 0.38), c + Vector2(-s * 1.25, -s * 0.55), c + Vector2(-s * 1.25, s * 0.05), c + Vector2(-s * 0.9, -s * 0.1)], Color("#D6A74A").lightened(0.15))
				_poly([c + Vector2(s * 0.15, -s * 0.3), c + Vector2(s * 1.1, -s * 0.05), c + Vector2(s * 1.1, s * 0.4), c + Vector2(s * 0.15, s * 0.0)], Palette.WOOD)
			&"crank_gatling":
				for k in 3:
					draw_rect(Rect2(c + Vector2(-s * 1.2, -s * 0.35 + k * s * 0.12), Vector2(s * 1.2, s * 0.07)), Palette.METAL, true)
				draw_rect(Rect2(c + Vector2(-s * 0.05, -s * 0.45), Vector2(s * 0.6, s * 0.5)), Color("#D6A74A").darkened(0.1), true)
				draw_circle(c + Vector2(s * 0.25, -s * 0.6), s * 0.25, Palette.METAL.darkened(0.2))
				draw_line(c + Vector2(s * 0.55, -s * 0.2), c + Vector2(s * 0.75, s * 0.35), dark, 3.0)
				draw_circle(c + Vector2(s * 0.8, s * 0.4), s * 0.1, Palette.WOOD)
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
			&"lighter":
				# A Zippo with its lid flipped open and a little flame.
				draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.05), Vector2(s * 0.7, s * 0.85)), Palette.METAL.lightened(0.3), true)
				draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.05), Vector2(s * 0.7, s * 0.85)), dark, false, 2.0)
				_poly([c + Vector2(s * 0.35, -s * 0.05), c + Vector2(s * 0.85, -s * 0.45), c + Vector2(s * 0.75, -s * 0.6), c + Vector2(s * 0.25, -s * 0.2)], Palette.METAL.lightened(0.15))
				draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.3), Vector2(s * 0.44, s * 0.25)), Palette.METAL, true)
				_poly([c + Vector2(0, -s * 0.95), c + Vector2(s * 0.14, -s * 0.5), c + Vector2(0, -s * 0.38), c + Vector2(-s * 0.14, -s * 0.5)], Color("#FF8A2A"))
			&"grapple":
				# Stubby brass launcher with a three-pronged hook in the muzzle.
				draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.2), Vector2(s * 1.2, s * 0.4)), Color("#D6A74A"), true)
				_poly([c + Vector2(s * 0.1, s * 0.2), c + Vector2(s * 0.45, s * 0.2), c + Vector2(s * 0.6, s * 0.85), c + Vector2(s * 0.25, s * 0.85)], Palette.WOOD)
				for k in 3:
					var a := -0.7 + k * 0.7
					draw_line(c + Vector2(-s * 0.7, 0), c + Vector2(-s * 0.7, 0) + Vector2(-cos(a), sin(a)) * s * 0.45, Palette.METAL, 3.0)
				draw_arc(c + Vector2(s * 0.6, -s * 0.5), s * 0.3, 0.0, TAU, 12, Color("#B8955A"), 2.0)
			&"herbs":
				draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.2), Vector2(s * 0.9, s * 1.0)), Palette.BONE, true)
				draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.05), Vector2(s * 0.24, s * 0.7)), Palette.TEAM_WEST, true)
				draw_rect(Rect2(c + Vector2(-s * 0.35, s * 0.18), Vector2(s * 0.7, s * 0.24)), Palette.TEAM_WEST, true)
				for k in 3:
					draw_circle(c + Vector2(-s * 0.3 + k * s * 0.3, -s * 0.45), s * 0.18, Color("#8CC66E"))
			&"amber":
				# Hive amber: a faceted honey-gold lump with a dark speck of bug inside.
				_poly([c + Vector2(-s * 0.7, s * 0.1), c + Vector2(-s * 0.3, -s * 0.65), c + Vector2(s * 0.45, -s * 0.6), c + Vector2(s * 0.75, s * 0.05), c + Vector2(s * 0.3, s * 0.7), c + Vector2(-s * 0.4, s * 0.6)], AmberRules.COLOR)
				_poly([c + Vector2(-s * 0.3, -s * 0.65), c + Vector2(s * 0.45, -s * 0.6), c + Vector2(s * 0.1, -s * 0.15), c + Vector2(-s * 0.35, -s * 0.2)], AmberRules.GLOW.lightened(0.3))
				draw_circle(c + Vector2(s * 0.05, s * 0.15), s * 0.14, Color("#3A2414"))
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
