class_name HudCombo
extends Control
## The style combo (ComboRules): the grade letter alone, in the rider's brand
## colours, centred under the top-right wave card, and only from rank SHOW_RANK (C) up
## (Logan). A rank-up
## stamps the letter in (each brand its own way: Sheaf burns in, Crossed Irons
## stamps down, Snake Eyes flips like a card); a break shakes it and fades it.
## The screen answers the grade: from B an edge glow, from A speed lines, from
## S a colour wash; at S+ every kill shakes the camera.

var player: Player
## The top-right wave card the badge hangs under.
var under: Control
const SHOW_RANK := 1
var _count := 0
var _rank := 0
var _pop := 0.0
var _crack := 0.0
var _fade := 0.0
var _t := 0.0
var _lines: Array = []
var _letter: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 48:
		_lines.append([randf() * TAU, randf(), randf_range(0.6, 1.4)])
	_letter = Label.new()
	_letter.add_theme_font_override("font", UiStyle.display_font())
	_letter.add_theme_font_size_override("font_size", UiStyle.ts(68))
	_letter.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_letter.add_theme_constant_override("outline_size", 12)
	_letter.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_letter.add_theme_constant_override("shadow_offset_y", 4)
	_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letter)
	_letter.visible = false


## The bottom edge of the grade letter while it shows (the kill feed starts
## under it), else -1.
func bottom() -> float:
	if not _letter.visible or not visible:
		return -1.0
	return _letter.position.y + _letter.size.y


func bind(p: Player) -> void:
	player = p
	p.combo.changed.connect(_on_changed)


func _brand() -> StringName:
	return Brand.local_id()


func _on_changed(count: int, broke: bool) -> void:
	var r := ComboRules.rank(count)
	if broke:
		_crack = 1.0
		_fade = 1.0
		Audio.play_ui(&"card_flick", -10.0, 0.7)
	elif r > _rank:
		_pop = 1.0
		match _brand():
			&"irons":
				Audio.play_ui(&"coin", -6.0, 0.6) # the stamp's clang
			&"snake":
				Audio.play_ui(&"card_flick", -6.0)
			_:
				Audio.play_ui(&"coin", -10.0, 1.3)
	if not broke:
		_count = count
	_rank = r if not broke else _rank
	if not broke:
		_show()


func _show() -> void:
	_letter.text = ComboRules.grade(_count)
	_letter.add_theme_color_override("font_color", ComboRules.color(_brand(), _count))
	_letter.visible = _rank >= SHOW_RANK
	modulate.a = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(_pop - delta * 4.0, 0.0)
	_crack = maxf(_crack - delta * 2.0, 0.0)
	if _fade > 0.0:
		_fade = maxf(_fade - delta * 1.6, 0.0)
		modulate.a = _fade
		if _fade <= 0.0:
			_count = 0
			_rank = 0
			_letter.visible = false
			modulate.a = 1.0
	var c := size * 0.5
	var ls := _letter.get_combined_minimum_size()
	var scale_k := 1.0 + _pop * 0.8
	var shake := Vector2(sin(_t * 90.0), cos(_t * 77.0)) * 8.0 * _crack
	_letter.size = ls
	_letter.pivot_offset = ls * 0.5
	# (the wave card hides during a wave: then the letter hangs under the Homestead plates)
	var top := under.get_global_rect().end.y + 4.0 if under != null and under.visible else HudStatus.right_stack_bottom() + 6.0
	var right_mid := get_viewport_rect().size.x - 24.0 - HudWavePreview.WIDTH * 0.5
	var cx := under.get_global_rect().get_center().x if under != null and under.visible else right_mid
	_letter.position = Vector2(cx - ls.x * 0.5, top) + shake
	match _brand():
		&"snake":
			_letter.scale = Vector2(absf(cos(_pop * PI)) * scale_k, scale_k) # a card flip
		&"irons":
			_letter.scale = Vector2.ONE * (1.0 + _pop * _pop * 1.4) # stamped down hard
		_:
			_letter.scale = Vector2.ONE * scale_k
	if _brand() == &"sheaf" and _pop > 0.0:
		_letter.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.2, 0.7), _pop) # burning in
	else:
		_letter.modulate = Color.WHITE
	if _rank >= 2 and _count > 0:
		for l: Array in _lines:
			l[1] = fposmod(float(l[1]) + delta * 1.4 * float(l[2]), 1.0)
		queue_redraw()
	elif _count == 0:
		queue_redraw()


func _draw() -> void:
	if _count <= 0 or _rank < 2:
		return
	var col := ComboRules.color(_brand(), _count)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	# From B: a glow round the screen's edge.
	var w := 26.0 + 10.0 * (_rank - 2)
	for i in 6:
		var a := (0.16 + 0.05 * (_rank - 2)) * (1.0 - i / 6.0) * (0.7 + 0.3 * pulse)
		var g := w * (1.0 - i / 6.0)
		var cc := Color(col, a)
		draw_rect(Rect2(0, 0, size.x, g), cc)
		draw_rect(Rect2(0, size.y - g, size.x, g), cc)
		draw_rect(Rect2(0, 0, g, size.y), cc)
		draw_rect(Rect2(size.x - g, 0, g, size.y), cc)
	# From A: speed lines racing out at the edges.
	if _rank >= 3:
		var c := size * 0.5
		var r_max := c.length()
		for l: Array in _lines:
			var a := float(l[0])
			var dir := Vector2(cos(a), sin(a))
			var t := float(l[1])
			var r0 := lerpf(0.62, 1.0, t) * r_max
			draw_line(c + dir * r0, c + dir * (r0 + r_max * 0.1 * float(l[2])), Color(col.lightened(0.4), 0.55 * (1.0 - t)), 3.0)
	# From S: a wash of the brand's colour over everything.
	if _rank >= 4:
		draw_rect(Rect2(Vector2.ZERO, size), Color(col, 0.03 + 0.03 * pulse))
