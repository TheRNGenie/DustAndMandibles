class_name SecretsScreen
extends CanvasLayer
## Main menu > Secrets: a padlocked strongbox with a combination dial. Type a
## code and press Enter (or Try The Lock): a right code spins the dial open and
## adds its hidden cosmetics to your profile (Perks.redeem_secret, saved); a
## wrong one rattles the box. Codes live only as hashes (SecretCodes).

var _root: Control
var _box: PanelContainer
var _dial: Dial
var _code: LineEdit
var _result: Label
var _box_x := 0.0


func _ready() -> void:
	layer = 66
	_build()
	_root.visible = false


func is_open() -> bool:
	return UiStyle.shown(_root)


func open() -> void:
	_root.visible = true
	UiStyle.fade_in(_root)
	_code.text = ""
	_result.text = "Every code opens something. Most open nothing."
	_result.theme_type_variation = "SoftInkLabel"
	_code.grab_focus.call_deferred()


func close() -> void:
	UiStyle.fade_out(_root)


func _input(event: InputEvent) -> void:
	if UiStyle.shown(_root) and event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiStyle.fit(_root) # Theme: bigger on 1440p and up
	add_child(_root)
	_root.add_child(UiStyle.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_box = PanelContainer.new()
	_box.theme_type_variation = "FramePanel"
	_box.custom_minimum_size = Vector2(520, 0)
	center.add_child(_box)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_box.add_child(outer)
	outer.add_child(UiStyle.strap("The Strongbox", "", 30))
	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	outer.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	_dial = Dial.new()
	_dial.custom_minimum_size = Vector2(0, 170)
	col.add_child(_dial)
	var hint := UiStyle.label("Heard a code somewhere? Dial it in.", 16)
	hint.theme_type_variation = "SoftInkLabel"
	col.add_child(hint)
	_code = LineEdit.new()
	_code.placeholder_text = "Code"
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.custom_minimum_size.y = 44
	_code.add_theme_font_size_override("font_size", 22)
	_code.max_length = 32
	_code.text_changed.connect(func(_t: String) -> void: _dial.turn(randf_range(-0.6, 0.6)))
	_code.text_submitted.connect(func(_t: String) -> void: _try())
	col.add_child(_code)
	_result = UiStyle.label("", 16)
	_result.custom_minimum_size.y = 46
	col.add_child(_result)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var try_b := UiStyle.button("Try the Lock")
	try_b.custom_minimum_size.x = 180
	try_b.pressed.connect(_try)
	row.add_child(try_b)
	var close_b := UiStyle.button("Close")
	close_b.custom_minimum_size.x = 140
	close_b.pressed.connect(close)
	row.add_child(close_b)


func _try() -> void:
	var got := Perks.redeem_secret(_code.text)
	if not bool(got["ok"]):
		_result.text = "Nope. The lock doesn't budge."
		_result.theme_type_variation = "BadLabel"
		_shake()
		if Audio.has_sound(&"armor_ping"):
			Audio.play_ui(&"armor_ping", -8.0)
		return
	var added: Array = got["added"]
	_dial.open_up()
	_result.theme_type_variation = "GoodLabel"
	_result.text = ("Click! The box swings open: %s." % ", ".join(added.map(func(e: Variant) -> String: return _pretty(e)))) \
		if not added.is_empty() else "Click! But you've already emptied this one."
	if Audio.has_sound(&"coin"):
		Audio.play_ui(&"coin")
	_code.text = ""


## "Dino Rifle (at the gunsmith)", "Bug Skull (in the Wardrobe)".
static func _pretty(e: Variant) -> String:
	var d: Dictionary = e if e is Dictionary else {}
	if str(d.get("kind", "")) == "notches":
		return "%s Notches" % str(d.get("id", "0"))
	var bits := str(d.get("id", "")).split(":")
	var where := " (at the gunsmith)" if str(d.get("kind", "")) == "weapon" else " (in the Wardrobe)"
	return UiStyle.tc(bits[bits.size() - 1].replace("_", " ")) + where


func _shake() -> void:
	var tw := create_tween()
	var base := _box.position.x
	for i in 6:
		tw.tween_property(_box, "position:x", base + (10.0 if i % 2 == 0 else -10.0) * (1.0 - i / 6.0), 0.04)
	tw.tween_property(_box, "position:x", base, 0.04)
	_dial.turn(1.2)


## The combination dial on the strongbox door, drawn in the set's ink and trim.
class Dial extends Control:
	var _angle := 0.0
	var _target := 0.0
	var _open := 0.0

	func turn(by: float) -> void:
		_target += by

	func open_up() -> void:
		_target += TAU * 1.5
		create_tween().tween_property(self, "_open", 1.0, 0.6).set_delay(0.5)

	func _process(delta: float) -> void:
		_angle = lerpf(_angle, _target, minf(delta * 8.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.y * 0.42, 80.0)
		var ink := UiStyle.c("ink")
		var trim := UiStyle.c("gold")
		# Door plate and hinge bolts.
		draw_rect(Rect2(c - Vector2(r * 1.7, r * 1.15), Vector2(r * 3.4, r * 2.3)), Color(ink, 0.12), true)
		draw_rect(Rect2(c - Vector2(r * 1.7, r * 1.15), Vector2(r * 3.4, r * 2.3)), Color(ink, 0.7), false, 3.0)
		for y: float in [-0.8, 0.8]:
			draw_circle(c + Vector2(-r * 1.5, r * y), 5.0, trim.darkened(0.2))
		# The dial: ring, ticks and the pointer notch.
		draw_circle(c, r, Color(ink, 0.85))
		draw_circle(c, r * 0.86, trim.darkened(0.15))
		draw_arc(c, r * 0.86, 0.0, TAU, 48, Color(ink, 0.6), 2.0, true)
		for i in 40:
			var a := _angle + i * TAU / 40.0
			var long := i % 5 == 0
			draw_line(c + Vector2.from_angle(a) * r * (0.62 if long else 0.7), c + Vector2.from_angle(a) * r * 0.82, ink, 2.0 if long else 1.0, true)
		draw_circle(c, r * 0.32, trim.darkened(0.35))
		draw_circle(c, r * 0.18, trim.lightened(0.2))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -r - 10), c + Vector2(7, -r - 10), c + Vector2(0, -r + 2)]), UiStyle.c("bad"))
		# The handle swings when it opens.
		var h := c + Vector2(r * 1.35, 0)
		var hand := Vector2.from_angle(lerpf(-PI * 0.5, 0.0, _open)) * r * 0.55
		draw_line(h, h + hand, ink, 7.0, true)
		draw_circle(h, 8.0, trim)
