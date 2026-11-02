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
var _title: Label
var _sub: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ribbon := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.WOOD_DARK, 0.88)
	sb.border_color = Palette.OUTLINE
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	ribbon.add_theme_stylebox_override("panel", sb)
	ribbon.anchor_left = 0.0
	ribbon.anchor_right = 1.0
	ribbon.anchor_top = 0.3
	ribbon.anchor_bottom = 0.3
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ribbon)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(_box)
	_title = KeyHints.text("", 64, Palette.GLOW_YELLOW)
	_title.add_theme_constant_override("outline_size", 12)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_title)
	_sub = KeyHints.text("", 22, Palette.BONE)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_sub)
	modulate.a = 0.0
	visible = false
	GameState.phase_changed.connect(_on_phase)


func _on_phase(p: GameState.Phase) -> void:
	match p:
		GameState.Phase.WAVE:
			show_card("WAVE %d" % GameState.wave, _pick("wave"), Palette.GLOW_YELLOW)
			Audio.play_ui(&"thunder", -6.0)
			if player != null and is_instance_valid(player):
				player.add_shake(0.7)
		GameState.Phase.BUILD:
			if GameState.wave > 1:
				show_card("WAVE %d HELD" % (GameState.wave - 1), _pick("held"), Palette.BONE)
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
	_box.pivot_offset = _box.size * 0.5
	_box.scale = Vector2(1.6, 1.6)
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(1.8)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.6)
	_tween.chain().tween_callback(func() -> void: visible = false)
