class_name HudThreatAlert
extends Control
## Partner alerts. When bugs get near the top of a cliff (or come over it) a
## small alert card appears under the plaque and a marker on screen points at
## the highest one: red for your own cliff ("call for cover"), amber for a
## cliff your turrets protect, pale for the rest. Every line names its cliff
## ("3 at North Butte"), yours first. Rings once each time it starts.
## Every alert also has a shape, so it never relies on colour alone: your cliff
## is a square marked "!!", a cliff you cover a diamond marked "!", the rest a
## small circle; the Colour-Blind Shapes setting draws them larger.

const TOP_SHARE := 0.65 # how far up the face counts as "near the top"
const SCAN := 0.4

var player: Player
var _t := 0.0
var _card: PanelContainer
var _label_box: VBoxContainer
## cliff id -> {"count": int, "pos": Vector3} for this scan.
var _threats: Dictionary = {}
var _was := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	# A compact card: tight margins, small text.
	var sb := KeyHints.card_style()
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	sb.set_border_width_all(2)
	_card.add_theme_stylebox_override("panel", sb)
	# Top-left corner, under your homestead bar, out of the middle of the view.
	_card.anchor_left = 0.0
	_card.anchor_right = 0.0
	_card.offset_left = 20
	_card.offset_top = 64
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	_label_box = VBoxContainer.new()
	_label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_label_box)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = SCAN
		_scan()
	queue_redraw()


func _scan() -> void:
	_threats.clear()
	if player == null or not is_instance_valid(player):
		_card.visible = false
		return
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden():
			continue
		var high := 0.0
		match b.state:
			Bug.State.CLIMBING:
				high = b.climb_y / WorldLayout.CLIFF_HEIGHT
			Bug.State.CRESTING, Bug.State.BREACHING:
				high = 1.0
			_:
				continue
		if high < TOP_SHARE:
			continue
		var t: Dictionary = _threats.get(b.cliff_id, {"count": 0, "pos": b.global_position, "high": -1.0})
		t["count"] = int(t["count"]) + 1
		if high > float(t["high"]):
			t["high"] = high
			t["pos"] = b.global_position
		_threats[b.cliff_id] = t
	var mine := player.cliff_id
	var m := WorldLayout.map()
	for c in _label_box.get_children():
		_label_box.remove_child(c)
		c.queue_free()
	# Yours first, then the cliffs your turrets cover (biggest share first), then the rest.
	var order: Array[int] = [mine]
	for cid in m.covered_cliffs(mine):
		if not order.has(cid):
			order.append(cid)
	for cid in m.count():
		if not order.has(cid):
			order.append(cid)
	for cid in order:
		if not _threats.has(cid):
			continue
		var n := int(_threats[cid]["count"])
		var text := "%d at %s%s" % [n, m.name_of(cid), " (Yours)" if cid == mine else ""]
		_label_box.add_child(_line(text, color_for(cid), cid == mine, _covers(cid)))
	_card.visible = _label_box.get_child_count() > 0
	if _card.visible:
		_center.call_deferred()
	for cid in order:
		var now := _threats.has(cid)
		if now and not bool(_was.get(cid, false)) and (cid == mine or _covers(cid)):
			Audio.play_ui(&"bell" if cid == mine else &"wheel_tick", -4.0 if cid == mine else -2.0)
		_was[cid] = now


## Does the local player's cliff send turret fire at cliff `cid`?
func _covers(cid: int) -> bool:
	return WorldLayout.map().cover_share(player.cliff_id, cid) > 0.0


## Red for your cliff, amber for a cliff you cover, pale for the others.
func color_for(cid: int) -> Color:
	if cid == player.cliff_id:
		return UiStyle.hud_c("bad")
	return UiStyle.hud_c("warn") if _covers(cid) else UiStyle.c("hud").darkened(0.15)


func _line(s: String, color: Color, mine: bool, covered: bool) -> Control:
	var l := KeyHints.text(s, 14, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := Glyph.new()
	glyph.mine = mine
	glyph.covered = covered
	glyph.color = color
	row.add_child(glyph)
	row.add_child(l)
	return row


## The colour-blind shape for an alert line: square "!!" (yours), diamond "!" (theirs).
class Glyph extends Control:
	var mine := false
	var covered := true
	var color := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(18, 18)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		HudThreatAlert.draw_shape(self, size * 0.5, 8.5, mine, color, covered)


## Draws an alert shape on any canvas item: a square with "!!" for your own
## cliff, a diamond with "!" for one you cover, a small plain circle otherwise.
static func draw_shape(ci: CanvasItem, p: Vector2, r: float, mine: bool, color: Color, covered: bool = true) -> void:
	if Settings.colorblind:
		r *= 1.25
	if not mine and not covered:
		ci.draw_circle(p, r * 0.62, Color(Palette.OUTLINE, 0.85))
		ci.draw_circle(p, r * 0.62 - 2.5, color)
		return
	var square := mine
	var pts := _shape_points(p, r, square)
	ci.draw_colored_polygon(pts, Color(Palette.OUTLINE, 0.85))
	ci.draw_colored_polygon(_shape_points(p, r - 3.0, square), color)
	var font: Font = ci.get_theme_default_font()
	var mark := "!!" if square else "!"
	var w: float = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	ci.draw_string(font, p + Vector2(-w * 0.5, 5), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.OUTLINE)


static func _shape_points(p: Vector2, r: float, square: bool) -> PackedVector2Array:
	if square:
		var h := r * 0.8
		return PackedVector2Array([p + Vector2(-h, -h), p + Vector2(h, -h), p + Vector2(h, h), p + Vector2(-h, h)])
	return PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])


func _center() -> void:
	var s := _card.get_combined_minimum_size()
	_card.offset_left = 20
	_card.offset_right = 20 + s.x


## Markers: a diamond over the highest bug of each threatened cliff, pinned to
## the screen edge (with an arrow) when it's off screen.
func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# Keep markers clear of the plaque at the top and the hotbar at the bottom.
	var vr := get_viewport_rect()
	var rect := Rect2(vr.position + Vector2(48, 90), vr.size - Vector2(96, 90 + 150))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return # headless or a tiny window
	for cid: int in _threats:
		var pos: Vector3 = _threats[cid]["pos"]
		var color := color_for(cid)
		var behind := cam.is_position_behind(pos + Vector3.UP)
		var p := cam.unproject_position(pos + Vector3.UP * 1.5)
		if behind:
			p = rect.get_center() + (rect.get_center() - p) * 1000.0
		var on_screen := rect.has_point(p) and not behind
		if not on_screen:
			var c := rect.get_center()
			var d := (p - c)
			var k := minf(absf(rect.size.x * 0.5 / maxf(absf(d.x), 0.001)), absf(rect.size.y * 0.5 / maxf(absf(d.y), 0.001)))
			p = c + d * k
			var dir := d.normalized()
			var tip := p + dir * 18.0
			draw_colored_polygon(PackedVector2Array([tip, p + dir.orthogonal() * 10.0, p - dir.orthogonal() * 10.0]), color)
		var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.01)
		var r := 11.0 * pulse
		draw_shape(self, p, r, cid == player.cliff_id, color, _covers(cid))
