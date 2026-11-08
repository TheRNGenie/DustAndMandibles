class_name KitBar
extends ProgressBar
## The kit's bar (health, homesteads, bosses, water, progress): a dark trough, a
## fill with a lit top edge (KitBox), quarter ticks, and a pale "ghost" that
## lingers where the value just dropped from, then slides down to it.

## Divisions marked with ticks (4 = quarters; 0 = none).
var ticks := 4
var ghost_color := Color(1.0, 0.92, 0.72, 0.6)
var _ghost := -1.0
var _tw: Tween


func _ready() -> void:
	_ghost = ratio
	value_changed.connect(_on_value)


func _on_value(_v: float) -> void:
	var f := ratio
	if f >= _ghost - 0.0005 or not is_inside_tree():
		_ghost = f
		queue_redraw()
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_interval(0.3)
	_tw.tween_method(func(x: float) -> void:
		_ghost = x
		queue_redraw(), _ghost, f, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var f := ratio
	var pad := 2.0
	if _ghost > f + 0.002:
		var x0 := pad + (w - pad * 2.0) * f
		var x1 := pad + (w - pad * 2.0) * _ghost
		draw_rect(Rect2(x0, pad, x1 - x0, h - pad * 2.0), ghost_color)
	if ticks > 1 and h >= 8.0:
		var tc := Color(0, 0, 0, 0.42)
		for i in range(1, ticks):
			var x := roundf(w * i / ticks) + 0.5
			draw_line(Vector2(x, pad + 1.0), Vector2(x, h - pad - 1.0), tc, 1.0)
	# A thin shine along the top of the trough (reads as glass over the fill).
	if h >= 10.0:
		draw_line(Vector2(pad + 2.0, pad + 1.5), Vector2(w - pad - 2.0, pad + 1.5), Color(1, 1, 1, 0.12), 1.0)
