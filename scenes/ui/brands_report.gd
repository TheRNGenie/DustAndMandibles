class_name BrandsReport
extends VBoxContainer
## On the game-over poster: the Brands this run paid, line by line (Perks works
## them out and banks them), and where to spend them.



func _ready() -> void:
	visible = false
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Perks.run_banked.connect(_show)
	# The poster is centred on the screen: let it grow both ways as this fills in.
	var panel := get_parent().get_parent() as Control if get_parent() != null else null
	if panel != null:
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _show(report: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var ink := UiStyle.c("ink")
	var soft := UiStyle.c("ink_soft")
	var gold := UiStyle.c("warn") # the set's dark amber reads on paper
	var rule := UiStyle.divider(420)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(rule)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(head)
	var g := PerkGlyph.new("brand", Color("#C8901E"))
	g.custom_minimum_size = Vector2(30, 30)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(g)
	var title := UiStyle.title("Notches Earned", 22)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	head.add_child(_label("+%d" % int(report.get("earned", 0)), 30, gold))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(grid)
	for line: Array in report.get("lines", []):
		var a := _label(UiStyle.tc(str(line[0])), 16, ink)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		a.custom_minimum_size.x = 170
		grid.add_child(a)
		var b := _label(str(line[1]), 14, soft)
		b.custom_minimum_size.x = 110
		grid.add_child(b)
		var c := _label("+%d" % int(line[2]), 16, gold)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.custom_minimum_size.x = 50
		grid.add_child(c)
	if int(report.get("earned", 0)) != int(report.get("total_run", 0)):
		add_child(UiStyle.status("Already banked %d of this at the win." % (int(report["total_run"]) - int(report["earned"])), "good", 14))
	var foot := "You have %d Notches. Spend them in the Rancher's Ledger on the main menu." % int(report.get("brands", 0)) \
		if bool(report.get("banked", true)) else "Test run (--debug): these Notches are not banked."
	var f := _label(foot, 14, soft)
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.custom_minimum_size.x = 420
	add_child(f)
	visible = true


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiStyle.ts(size))
	l.add_theme_color_override("font_color", color)
	return l
