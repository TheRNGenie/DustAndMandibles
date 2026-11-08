class_name HudExpedition
extends Control
## Canyon Expeditions on the HUD:
##  - your backpack (bottom right, over the ammo sign): weight against capacity,
##    what's in it, how much it slows you; shown while it holds anything or
##    you're down in the canyon, with your time down and the airship hail key;
##  - partners down in the canyon: a line under the phase plaque for each
##    ("Kettle is in the canyon") and a marker over them in the world.

var player: Player
var _card: PanelContainer
var _title: Label
var _bar: ProgressBar
var _items: Label
var _foot: Label
var _partners: VBoxContainer
var _markers: Markers
var _t := 0.0
var _down_since := -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", KeyHints.kit_box("plate"))
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = -300
	_card.offset_right = -24
	_card.offset_bottom = -166 # over the ammo sign
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(box)
	_title = UiStyle.label("", 18)
	_title.add_theme_font_override("font", UiStyle.font("bold"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_title)
	_bar = UiStyle.bar(UiStyle.c("accent"), Vector2(240, 14), float(Backpack.CAPACITY))
	box.add_child(_bar)
	_items = UiStyle.label("", 15)
	_items.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_items)
	_foot = UiStyle.note("", 14)
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_foot)

	_partners = VBoxContainer.new()
	_partners.anchor_left = 0.5
	_partners.anchor_right = 0.5
	_partners.offset_left = -260
	_partners.offset_right = 260
	_partners.offset_top = 104
	_partners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_partners)

	_markers = Markers.new()
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers)

	Expedition.backpack_changed.connect(func(_p: int) -> void: _refresh())
	Expedition.went_down.connect(func(_p: int) -> void: _refresh_partners())
	Expedition.came_up.connect(func(_p: int) -> void: _refresh_partners())


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	_refresh()


func _refresh() -> void:
	var me := multiplayer.get_unique_id()
	var pack := Expedition.pack_of(me)
	var down := Expedition.is_down(me)
	if down and _down_since < 0.0:
		_down_since = Time.get_ticks_msec() / 1000.0
	elif not down:
		_down_since = -1.0
	_card.visible = down or not pack.is_empty()
	if not _card.visible:
		return
	var w := Backpack.weigh(pack)
	_title.text = UiStyle.tc("backpack") + "   %d / %d" % [w, Backpack.CAPACITY]
	_bar.value = w
	var lines: PackedStringArray = []
	for k: Variant in pack:
		lines.append("%s  x%d" % [ExpeditionRules.item_name(StringName(k)), int(pack[k])])
	_items.text = "\n".join(lines) if not lines.is_empty() else UiStyle.tc("empty")
	var foot: PackedStringArray = []
	var slow := roundi((1.0 - Backpack.speed_for(w)) * 100.0)
	if slow > 0:
		foot.append("Slowed %d%%" % slow)
	if down:
		var secs := Time.get_ticks_msec() / 1000.0 - _down_since
		foot.append("In the Canyon %s" % UiStyle.clock(secs))
		foot.append("G: Hail the Airship (%s)" % UiStyle.cost(ExpeditionRules.AIRSHIP_FARE, ResNames.PERSONAL_ID))
	else:
		foot.append("Unpacks When You're Back Up Top")
	_foot.text = "\n".join(foot)
	_refresh_partners()


func _refresh_partners() -> void:
	var names := Expedition.names_down(multiplayer.get_unique_id())
	for c: Node in _partners.get_children():
		c.queue_free()
	for n: String in names:
		# Each on a small plate, centred under the plaque (no loose text over the view).
		var plate := KeyHints.plate("plate_tight")
		plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var l := KeyHints.ink("%s %s" % [n, UiStyle.tc("is in the canyon")], 17)
		l.theme_type_variation = "GoldLabel"
		l.add_theme_font_override("font", UiStyle.font("bold"))
		plate.add_child(l)
		_partners.add_child(plate)
	_markers.queue_redraw()


## A marker over each partner who's down: a bobbing arrow and their name,
## pinned to the screen edge when they're off to the side.
class Markers extends Control:
	func _process(_d: float) -> void:
		if not Expedition.anyone_down():
			return
		queue_redraw()

	func _draw() -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var me := multiplayer.get_unique_id()
		var font := get_theme_default_font()
		var vp := get_viewport_rect().size
		for peer: int in Expedition.down:
			if peer == me:
				continue
			var pl := Expedition.player_node(peer)
			if pl == null:
				continue
			var at := pl.global_position + Vector3.UP * 2.4
			var behind := cam.is_position_behind(at)
			var p := cam.unproject_position(at)
			if behind:
				p = vp - p
			p = Vector2(clampf(p.x, 40, vp.x - 40), clampf(p.y, 60, vp.y - 60))
			var bob := sin(Time.get_ticks_msec() / 250.0) * 4.0
			var col := Color("#FFD27A")
			var tip := p + Vector2(0, bob)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-11, -16), tip + Vector2(11, -16), tip]), Palette.OUTLINE)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -14), tip + Vector2(7, -14), tip + Vector2(0, -3)]), col)
			var text := "%s  %dm" % [pl.display_name(), int(cam.global_position.distance_to(pl.global_position))]
			var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_string_outline(font, tip + Vector2(-size.x * 0.5, -22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Palette.OUTLINE)
			draw_string(font, tip + Vector2(-size.x * 0.5, -22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
