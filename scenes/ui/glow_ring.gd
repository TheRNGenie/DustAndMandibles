class_name GlowRing
extends Control
## A pulsing gold rim drawn over a button, shown while its key is in GlowRing.keys
## (the tutorial points at the gunsmith's Upgrades tab, the build menu's Crafted
## tab). Add it as the button's child; it fills the button and takes no clicks.

## The keys being pointed at right now (a tab's name, e.g. "Upgrades").
static var keys: Array[String] = []

var key := ""
var _t := 0.0


static func attach(to: Control, k: String) -> GlowRing:
	var g := GlowRing.new()
	g.key = k
	to.add_child(g)
	return g


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(delta: float) -> void:
	var b := get_parent() as Button
	var on := keys.has(key) and (b == null or b.theme_type_variation != &"TabButtonSelected") # (gone once it's open)
	if on != visible:
		visible = on
	if on:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var gold := UiStyle.c("gold")
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(gold, 0.10 + 0.14 * pulse))
	for i in 3:
		var grow := 2.0 + i * 3.0 + pulse * 2.0
		draw_rect(r.grow(grow), Color(gold, (0.85 - i * 0.28) * (0.55 + 0.45 * pulse)), false, 2.5 - i * 0.6)
