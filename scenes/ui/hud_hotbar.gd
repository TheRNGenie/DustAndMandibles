class_name HudHotbar
extends Control
## Bottom-centre hotbar: ten slots for keys 1-0 (1-3 guns, 4-6 harvest,
## 7 medicine, 8 bucket, 9 Zippo, 0 grapple), each showing a picture of what's
## in it. The picked slot wears the set's metal and stands a little taller;
## empty slots stay quiet. A keycap sits in each corner, counts on a pill.

const SLOT_SIZE := Vector2(80, 72) # sized against the status and ammo panels
## How far the picked slot stands up out of the row.
const LIFT := 8.0

var hotbar: Hotbar
var _panels: Array[PanelContainer] = []
var _icons: Array[ItemIcon] = []
var _counts: Array[Label] = []
var _pills: Array[PanelContainer] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A brand swap re-tints the rarity slots (their boxes are private copies). A
	# method, not a lambda: it lets go by itself when the HUD is freed.
	UiStyle.notifier.changed.connect(_on_set_changed)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	var width := SLOT_SIZE.x * Hotbar.SLOTS + 6 * (Hotbar.SLOTS - 1) + 3 * 12
	row.offset_left = -width * 0.5
	row.offset_right = width * 0.5
	row.offset_top = -SLOT_SIZE.y - LIFT - 18
	row.offset_bottom = -18
	add_child(row)
	for i in Hotbar.SLOTS:
		if i == 3 or i == 6 or i == 8:
			# A wider gap between the groups: guns | harvest | medicine, bucket | Zippo, grapple.
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(6, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
		var p := PanelContainer.new()
		p.custom_minimum_size = SLOT_SIZE
		p.size_flags_vertical = Control.SIZE_SHRINK_END
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", KeyHints.kit_box("slot_empty"))
		row.add_child(p)
		var stack := Control.new()
		stack.clip_contents = true # long guns fill the slot's width without spilling
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(stack)
		var icon := ItemIcon.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_top = 6
		icon.offset_bottom = -2
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.host = self
		stack.add_child(icon)
		# The slot's key: a small keycap in the top-left corner (the 10th slot is key 0).
		var key := PanelContainer.new()
		key.add_theme_stylebox_override("panel", KeyHints.kit_box("key_small"))
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.position = Vector2(1, 1)
		var kl := KeyHints.number(str((i + 1) % 10), 12)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.custom_minimum_size.x = 9
		key.add_child(kl)
		stack.add_child(key)
		# The count (x6, +2*): a small pill in the bottom-right corner.
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", KeyHints.kit_box("pill"))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.anchor_left = 1.0
		pill.anchor_right = 1.0
		pill.anchor_top = 1.0
		pill.anchor_bottom = 1.0
		pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
		pill.offset_right = -1
		pill.offset_bottom = -1
		pill.offset_left = -1
		pill.offset_top = -1
		pill.visible = false
		stack.add_child(pill)
		var count := KeyHints.number("", 14)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.add_child(count)
		_panels.append(p)
		_icons.append(icon)
		_counts.append(count)
		_pills.append(pill)


func _on_set_changed() -> void:
	for i in _shown.size():
		_shown[i] = null


func bind(h: Hotbar) -> void:
	hotbar = h
	hotbar.changed.connect(refresh)
	refresh()


## What each slot last showed ([id, count, selected]): refresh() only touches
## the slots that changed (it runs on every ledger change). The slot looks are
## shared kit boxes that follow the UI set by themselves.
var _shown: Array = []


func refresh() -> void:
	if hotbar == null:
		return
	_shown.resize(Hotbar.SLOTS)
	for i in Hotbar.SLOTS:
		var info := hotbar.slot_info(i)
		var state := [info["id"], info["count"], bool(info["selected"]), int(info.get("rarity", 0))]
		var bag_crop := _bag_crop() if info["id"] == CropBagUI.ITEM else &"" # the crop bag wears its set crop's sack
		state.append(bag_crop)
		if _shown[i] == state:
			continue
		var was: Array = _shown[i] if _shown[i] is Array else []
		_shown[i] = state
		_counts[i].text = str(info["count"])
		_pills[i].visible = str(info["count"]) != ""
		if was.is_empty() or was[0] != info["id"] or (was.size() > 4 and was[4] != bag_crop):
			_icons[i].item = info["id"]
			_icons[i].crop = bag_crop
			_icons[i].queue_redraw()
			# Icons render a frame later: redraw once they're ready.
			get_tree().create_timer(0.2).timeout.connect(_icons[i].queue_redraw)
		if not was.is_empty() and was[2] == state[2] and was.size() > 3 and was[3] == state[3] and (was[0] == &"") == (info["id"] == &""):
			continue
		var picked := bool(info["selected"])
		var kind := "slot_selected" if picked else ("slot_empty" if info["id"] == &"" else "slot")
		var box := KeyHints.kit_box(kind)
		# Gun rarity (Uncommon and up): the slot's rim and rule take its colour.
		var rar := MenuScreen.rarity_color(int(state[3])) if info["id"] != &"" else Color(0, 0, 0, 0)
		if rar.a > 0.0:
			var tinted := box.duplicate() as KitBox
			tinted.rim = rar if picked else Color(rar, 0.85)
			tinted.rim_width = 2.0
			tinted.rule = Color(rar, 0.45)
			_panels[i].add_theme_stylebox_override("panel", tinted)
		else:
			_panels[i].add_theme_stylebox_override("panel", box)
		# The picked slot stands up out of the row; empty ones fade back.
		_panels[i].custom_minimum_size = SLOT_SIZE + (Vector2(0, LIFT) if picked else Vector2.ZERO)
		_panels[i].get_child(0).get_child(1).modulate = Color(1, 1, 1, 1.0 if info["id"] != &"" or picked else 0.55)


## The local player's crop bag's set crop (&"" when none, or no bag).
func _bag_crop() -> StringName:
	var p: Node = hotbar.player if hotbar != null else null
	var bag: Variant = p.get("crop_bag") if p != null else null
	return StringName(bag.get("set_crop")) if bag is Object and is_instance_valid(bag) else &""


## Simple drawn icons for hotbar items (no image files).
class ItemIcon extends Control:
	var item: StringName = &""
	## The crop bag: the crop it's set to (its sack's painted icon), &"" = an empty sack.
	var crop: StringName = &""
	## Raw crops drawn as their crop badge (no painted icon yet).
	const RAW_CHIPS: Array[StringName] = [&"cotton", &"sulfur_root", &"barrel_cactus", &"tumbleweed_vine"]
	## Where the 3D icon renders live (the hotbar itself).
	var host: Node

	func _draw() -> void:
		# A painted icon (assets/icons) where there is one; then a picture of the
		# real model; the drawn icon otherwise.
		var painted: Texture2D = UiStyle.painted_icon(item) if item != &"" and not GunModels.has(item) else null
		if item == CropBagUI.ITEM: # the set crop's ammo sack (assets/icons/<sack>.png); drawn when empty
			painted = UiStyle.painted_icon(CropEffects.sack_of(crop)) if crop != &"" else null
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
		# The raw crops with no painted icon (carried crops, playtest fixes Nov 2026):
		# their crop badge (CropChip).
		var chip := get_node_or_null("Chip") as CropChip
		if item in RAW_CHIPS:
			if chip == null:
				chip = CropChip.make(item, 48)
				chip.name = "Chip"
				chip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				add_child(chip)
			chip.crop = item
			chip.visible = true
			chip.queue_redraw()
			return
		if chip != null:
			chip.visible = false
		if item != &"" and host != null and item != CropBagUI.ITEM: # (the empty bag is drawn, below)
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
			&"crop_bag":
				# An empty burlap sack, its drawstring loose: set it with right click.
				var sack := Color("#C9A06A")
				_poly([c + Vector2(-s * 0.55, -s * 0.35), c + Vector2(s * 0.55, -s * 0.35), c + Vector2(s * 0.75, s * 0.55),
						c + Vector2(s * 0.4, s * 0.9), c + Vector2(-s * 0.4, s * 0.9), c + Vector2(-s * 0.75, s * 0.55)], sack)
				_poly([c + Vector2(-s * 0.3, -s * 0.35), c + Vector2(s * 0.3, -s * 0.35), c + Vector2(s * 0.42, -s * 0.75), c + Vector2(-s * 0.42, -s * 0.75)], sack.darkened(0.12))
				draw_line(c + Vector2(-s * 0.36, -s * 0.38), c + Vector2(s * 0.36, -s * 0.38), Palette.WOOD_DARK, 3.0)
				draw_line(c + Vector2(s * 0.3, -s * 0.38), c + Vector2(s * 0.55, -s * 0.05), Palette.WOOD_DARK, 2.0)
				for k in 3:
					draw_line(c + Vector2(-s * 0.45 + k * s * 0.3, s * 0.05), c + Vector2(-s * 0.38 + k * s * 0.3, s * 0.7), sack.darkened(0.25), 1.5)
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
