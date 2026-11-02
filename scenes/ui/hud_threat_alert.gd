class_name HudThreatAlert
extends Control
## Partner alerts. When bugs get near the top of a cliff (or come over it) a
## small alert card appears under the plaque and a marker on screen points at
## the highest one: red for your own cliff ("call for cover"), amber for your
## partner's (the one your turrets protect). Rings once each time it starts.

const TOP_SHARE := 0.65 # how far up the face counts as "near the top"
const SCAN := 0.4

var player: Player
var _t := 0.0
var _card: PanelContainer
var _label_box: VBoxContainer
## cliff id -> {"count": int, "pos": Vector3} for this scan.
var _threats: Dictionary = {}
var _was := {0: false, 1: false}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", KeyHints.card_style())
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_top = 168
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
	var theirs := WorldLayout.other_cliff(mine)
	for c in _label_box.get_children():
		_label_box.remove_child(c)
		c.queue_free()
	if _threats.has(mine):
		var n := int(_threats[mine]["count"])
		_label_box.add_child(_line("%d %s at the top of YOUR cliff  ·  call for cover" % [n, "bug" if n == 1 else "bugs"], Palette.TEAM_WEST.lightened(0.35)))
	if _threats.has(theirs):
		var n := int(_threats[theirs]["count"])
		_label_box.add_child(_line("%d %s nearing the top of your partner's cliff" % [n, "bug" if n == 1 else "bugs"], Palette.GLOW_YELLOW))
	_card.visible = _label_box.get_child_count() > 0
	if _card.visible:
		_center.call_deferred()
	for cid: int in [mine, theirs]:
		var now := _threats.has(cid)
		if now and not _was[cid]:
			Audio.play_ui(&"bell" if cid == mine else &"wheel_tick", -4.0 if cid == mine else -2.0)
		_was[cid] = now


func _line(s: String, color: Color) -> Label:
	var l := KeyHints.text(s, 16, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _center() -> void:
	var s := _card.get_combined_minimum_size()
	_card.offset_left = -s.x * 0.5
	_card.offset_right = s.x * 0.5


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
	for cid: int in _threats:
		var pos: Vector3 = _threats[cid]["pos"]
		var color := Palette.TEAM_WEST.lightened(0.2) if cid == player.cliff_id else Palette.GLOW_YELLOW
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
		var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		draw_colored_polygon(pts, Color(Palette.OUTLINE, 0.8))
		var r2 := r - 3.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r2), p + Vector2(r2, 0), p + Vector2(0, r2), p + Vector2(-r2, 0)]), color)
		draw_string(get_theme_default_font(), p + Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Palette.OUTLINE)
