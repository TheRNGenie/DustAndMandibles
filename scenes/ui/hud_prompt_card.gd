class_name HudPromptCard
extends PanelContainer
## The one place on-screen instructions appear: a small card just above the
## hotbar with a title, an optional icon and status line, and keycap hints.
## Shows the build bar while placing, otherwise whatever you're looking at.

var _shown_key := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.card_style())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -(HudHotbar.SLOT_SIZE.y + 30)
	visible = false


## An interaction prompt as plain text ("E: plant corn   F: change seed").
func show_text(prompt: String) -> void:
	if prompt.strip_edges() == "":
		_clear()
		return
	if prompt == _shown_key:
		return
	_shown_key = prompt
	var parsed := KeyHints.parse(prompt)
	var col := _fresh()
	var titles: Array = parsed["title"]
	for i in titles.size():
		var l := KeyHints.text(str(titles[i]), 18 if i == 0 else 14, Palette.BONE if i == 0 else Palette.BONE.darkened(0.25))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	if not (parsed["keys"] as Array).is_empty():
		col.add_child(KeyHints.row(parsed["keys"]))
	_settle()


## The build bar: what you're placing, its price, why it can't go here, keys.
## info: {"icon", "name", "cost", "afford", "status", "status_bad", "keys"}.
func show_build(info: Dictionary) -> void:
	var key := str(info.get("name")) + "|" + str(info.get("cost")) + "|" + str(info.get("afford")) + "|" + str(info.get("status")) + "|" + str(info.get("status_bad")) + "|" + str(info.get("keys"))
	if key == _shown_key:
		return
	_shown_key = key
	var col := _fresh()
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var tex: Texture2D = info.get("icon")
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(words)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_row)
	name_row.add_child(KeyHints.text(str(info.get("name")), 20, Palette.BONE))
	name_row.add_child(_price(int(info.get("cost")), bool(info.get("afford"))))
	var status := str(info.get("status", ""))
	if status != "":
		words.add_child(KeyHints.text(status, 14, Palette.TEAM_WEST.lightened(0.35) if info.get("status_bad", false) else Palette.BONE.darkened(0.25)))
	col.add_child(KeyHints.row(info.get("keys", [])))
	_settle()


func _price(cost: int, afford: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.OUTLINE, 0.55)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(KeyHints.text("%d scrap" % cost, 15, Palette.GLOW_YELLOW if afford else Palette.TEAM_WEST.lightened(0.3)))
	return p


func _fresh() -> VBoxContainer:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	return col


## Shrinks to fit the new content and recentres over the hotbar.
func _settle() -> void:
	visible = true
	_center.call_deferred()


func _center() -> void:
	var s := get_combined_minimum_size()
	offset_left = -s.x * 0.5
	offset_right = s.x * 0.5
	offset_top = offset_bottom - s.y


func _clear() -> void:
	if _shown_key == "" and not visible:
		return
	_shown_key = ""
	visible = false
