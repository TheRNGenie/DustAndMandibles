class_name HudPromptCard
extends PanelContainer
## The one place on-screen instructions appear: a small card just above the
## hotbar with a title, an optional icon and status line, and keycap hints.
## Shows the build bar while placing, otherwise whatever you're looking at.

var _shown_key := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.kit_box("plate"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -(HudHotbar.SLOT_SIZE.y + HudHotbar.LIFT + 30)
	visible = false


func _process(_delta: float) -> void:
	# The crop wheel covers the middle: the card steps aside while it's open.
	var wheel := CropWheel.instance != null and CropWheel.instance.is_open()
	modulate.a = 0.0 if wheel else 1.0


## An interaction prompt as plain text ("E: plant corn   F: change seed").
func show_text(prompt: String) -> void:
	if prompt.strip_edges() == "":
		_clear()
		return
	if prompt == _shown_key:
		return
	_shown_key = prompt
	if prompt.begins_with("@turret:"): # a universal crop-fed turret's card
		var info: Variant = JSON.parse_string(prompt.substr(8))
		if info is Dictionary:
			show_turret(info)
			return
	if prompt.begins_with("@bag:"): # the same turret, seen with the crop bag out (CropBagUI.prompt)
		var binfo: Variant = JSON.parse_string(prompt.substr(5))
		if binfo is Dictionary:
			show_bag(binfo)
			return
	var parsed := KeyHints.parse(prompt)
	var col := _fresh()
	var titles: Array = parsed["title"]
	for i in titles.size():
		var l := KeyHints.ink(str(titles[i]), 18 if i == 0 else 14, i > 0)
		if i == 0:
			l.add_theme_font_override("font", UiStyle.font("bold"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	if not (parsed["keys"] as Array).is_empty():
		if not titles.is_empty():
			col.add_child(_rule())
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
		var well := KeyHints.plate("well")
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(icon)
		top.add_child(well)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(words)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(name_row)
	var nm := KeyHints.ink(UiStyle.tc(str(info.get("name"))), 18)
	nm.add_theme_font_override("font", UiStyle.font("bold"))
	name_row.add_child(nm)
	name_row.add_child(_price(int(info.get("cost")), bool(info.get("afford"))))
	var status := str(info.get("status", ""))
	if status != "":
		if info.get("status_bad", false): # a cross as well as the red, so it reads without colour
			words.add_child(UiStyle.status(status, "bad", 14, true))
		else:
			words.add_child(KeyHints.ink(status, 14, true))
	col.add_child(_rule())
	col.add_child(KeyHints.row(info.get("keys", [])))
	_settle()


## A universal crop-fed turret's card (UniversalTurret.card_info): its name and
## tier, the crop it's loaded with (a dot and words in the crop's colour, or a
## hollow grey dot: Empty (Idle)), the last crop, and the keys that work now.
func show_turret(info: Dictionary) -> void:
	var col := _fresh()
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var nm := KeyHints.ink(UiStyle.tc(str(info.get("name", ""))), 18)
	nm.add_theme_font_override("font", UiStyle.font("bold"))
	top.add_child(nm)
	var tier := KeyHints.plate("pill")
	tier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tl := KeyHints.text("Tier %d" % int(info.get("tier", 1)), 13, UiStyle.c("accent_hi"))
	tier.add_child(tl)
	top.add_child(tier)
	# Its kills beside the name: the crop that made them and how many, kept
	# apart per crop. More than three crops take a row of their own under it.
	var kills: Array = info.get("kills", [])
	if not kills.is_empty() or int(info.get("kills_total", 0)) > 0:
		var where := top
		if kills.size() > 3:
			where = HBoxContainer.new()
			where.alignment = BoxContainer.ALIGNMENT_CENTER
			where.add_theme_constant_override("separation", 10)
			where.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(where)
		else:
			var gap := Control.new()
			gap.custom_minimum_size.x = 2
			top.add_child(gap)
		if kills.is_empty():
			where.add_child(KeyHints.number(str(int(info.get("kills_total", 0))), 17))
		for k: Variant in kills:
			var pair := k as Array
			var tally := HBoxContainer.new()
			tally.add_theme_constant_override("separation", 4)
			tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tally.add_child(HudWaveSummary.crop_icon(StringName(str(pair[0])), 24))
			tally.add_child(KeyHints.number(str(int(pair[1])), 17))
			where.add_child(tally)
		var kl := KeyHints.eyebrow("Kills", 11)
		kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		where.add_child(kl)
	var crop_row := HBoxContainer.new()
	crop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crop_row.add_theme_constant_override("separation", 8)
	crop_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(crop_row)
	var loaded := str(info.get("crop", "")) != ""
	var cc := Color.html(str(info.get("color", "808080"))) if loaded else CropEffects.EMPTY_COLOR
	var dot := CropDot.new()
	dot.color = cc
	dot.filled = loaded
	crop_row.add_child(dot)
	var words := "%s (%s)" % [str(info.get("crop_name")), str(info.get("effect"))] if loaded else "Empty (Idle)"
	var cl := KeyHints.text(words, 16, cc.lightened(0.15) if loaded else Color(0.62, 0.62, 0.62))
	cl.add_theme_font_override("font", UiStyle.font("bold"))
	crop_row.add_child(cl)
	var last := KeyHints.ink("Last: %s   ·   HP %s" % [str(info.get("last", "None")), str(info.get("hp", ""))], 13, true)
	last.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(last)
	for n: Variant in info.get("notes", []):
		var nl := KeyHints.ink(str(n), 13, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nl)
	var keys: Array = info.get("keys", [])
	if not keys.is_empty():
		col.add_child(_rule())
		col.add_child(KeyHints.row(keys))
	_settle()


## A crop-fed turret seen with the crop bag out (CropBagUI.prompt): its name,
## tier and health; what's in it now; the bag's crop and how many sacks of it the
## cellar has; why a click won't load (when it won't); the keys.
func show_bag(info: Dictionary) -> void:
	var col := _fresh()
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var nm := KeyHints.ink(UiStyle.tc(str(info.get("name", ""))), 18)
	nm.add_theme_font_override("font", UiStyle.font("bold"))
	top.add_child(nm)
	var tier := KeyHints.plate("pill")
	tier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tier.add_child(KeyHints.text("Tier %d" % int(info.get("tier", 1)), 13, UiStyle.c("accent_hi")))
	top.add_child(tier)
	if str(info.get("hp", "")) != "":
		var hp := KeyHints.ink("HP %s" % str(info["hp"]), 13, true)
		hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(hp)
	# In it now  ·  in your bag
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var now := StringName(str(info.get("now", "")))
	var dot := CropDot.new()
	dot.color = CropEffects.color_of(now) if now != &"" else CropEffects.EMPTY_COLOR
	dot.filled = now != &""
	row.add_child(dot)
	row.add_child(KeyHints.ink(str(info.get("now_name", "")) if now != &"" else "Empty", 14, now == &""))
	var arrow := KeyHints.ink("›", 16, true)
	row.add_child(arrow)
	var bag := StringName(str(info.get("bag", "")))
	if bag != &"":
		row.add_child(HudWaveSummary.crop_icon(bag, 24))
		var bl := KeyHints.text("Bag: %s" % str(info.get("bag_name", "")), 16, CropEffects.color_of(bag).lightened(0.15))
		bl.add_theme_font_override("font", UiStyle.font("bold"))
		row.add_child(bl)
		var n := int(info.get("have", 0))
		var cnt := KeyHints.number("x%d" % n, 16)
		cnt.add_theme_color_override("font_color", UiStyle.c("accent_hi") if n > 0 else UiStyle.hud_c("bad"))
		cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cnt)
	else:
		row.add_child(KeyHints.ink("Bag: Empty", 16, true))
	var st: Array = info.get("status", ["", ""])
	if st.size() >= 2 and str(st[0]) != "":
		var sb := UiStyle.status(str(st[0]), str(st[1]), 14, true)
		sb.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(sb)
	var keys: Array = info.get("keys", [])
	if not keys.is_empty():
		col.add_child(_rule())
		col.add_child(KeyHints.row(keys))
	_settle()


## The crop dot: a 12 px circle in the crop's colour, or a hollow grey ring.
class CropDot extends Control:
	var color := Color.GRAY
	var filled := true

	func _init() -> void:
		custom_minimum_size = Vector2(14, 14)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		if filled:
			draw_circle(c, 6.5, Color(0, 0, 0, 0.5))
			draw_circle(c, 6.0, color)
		else:
			draw_arc(c, 5.5, 0, TAU, 24, color, 2.0, true)


func _price(cost: int, afford: bool) -> PanelContainer:
	var p := KeyHints.plate("pill")
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if not afford:
		row.add_child(UiStyle.mark("bad", UiStyle.hud_c("bad"), 12))
	row.add_child(UiStyle.resource_chip(&"scrap", 12))
	var l := KeyHints.number(UiStyle.cost(cost, "scrap"), 15)
	l.add_theme_color_override("font_color", UiStyle.c("accent_hi") if afford else UiStyle.hud_c("bad"))
	row.add_child(l)
	return p


## A faint hairline in the set's metal between the words and the keys.
func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(UiStyle.c("accent"), 0.25)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


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
