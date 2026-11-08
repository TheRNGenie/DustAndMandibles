class_name HudTitleCard
extends Control
## The big moments, centre screen: "WAVE 7" when the bugs come (with a ground
## shake), "WAVE 7 HELD" when it's cleared. A wooden ribbon slams in, holds, and
## fades away. Purely local.

const LINES := {
	"wave": ["They're coming up the walls", "Here they come", "Hold the line, partner", "Sundown. Guns up"],
	"held": ["Breathe easy. For now", "The canyon's quiet", "Patch up and build"],
}

var player: Player
var _box: VBoxContainer
var _ribbon: PanelContainer
var _title: Label
var _sub: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A wide plate in the set's deep colour (stitched or riveted, as the set is):
	# the display title, the set's ornament rule, one line under it.
	var center := CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_right = 1.0
	center.anchor_top = 0.3
	center.anchor_bottom = 0.3
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon = KeyHints.plate("ribbon")
	_ribbon.custom_minimum_size.x = 640
	_ribbon.add_child(_box)
	center.add_child(_ribbon)
	_title = Label.new()
	_title.theme_type_variation = "HeaderTitle"
	_title.uppercase = true
	_title.add_theme_font_size_override("font_size", UiStyle.ts(64))
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_title)
	var rule := UiStyle.divider(420)
	_box.add_child(rule)
	_sub = KeyHints.ink("", 22)
	_sub.add_theme_font_override("font", UiStyle.font("bold"))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_sub)
	modulate.a = 0.0
	visible = false
	GameState.phase_changed.connect(_on_phase)


func _on_phase(p: GameState.Phase) -> void:
	match p:
		GameState.Phase.WAVE:
			show_card("Wave %d" % GameState.wave, _pick("wave"), UiStyle.c("title"))
			Audio.play_ui(&"thunder", -6.0)
			if player != null and is_instance_valid(player):
				player.add_shake(0.7)
		GameState.Phase.BUILD:
			if GameState.wave > 1:
				show_card("Wave %d Held" % (GameState.wave - 1), _pick("held"), UiStyle.hud_c("good"))
				Audio.play_ui(&"bell", -4.0)


static func _pick(kind: String) -> String:
	var lines: Array = LINES[kind]
	return lines[randi() % lines.size()]


## Slams the card in, holds it, fades it out.
func show_card(title: String, sub: String, color: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_sub.text = sub
	visible = true
	if _tween != null:
		_tween.kill()
	_ribbon.pivot_offset = _ribbon.size * 0.5
	_ribbon.scale = Vector2(1.35, 1.35)
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_ribbon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(1.8)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.6)
	_tween.chain().tween_callback(func() -> void: visible = false)
