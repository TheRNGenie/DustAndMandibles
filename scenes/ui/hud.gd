class_name Hud
extends CanvasLayer
## M0 HUD: crosshair, ammo sign, canyon-fall message and an F3 debug overlay.

var _ammo_label: Label
var _center_label: Label
var _debug_label: Label
var _crosshair: Control


func _ready() -> void:
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	var ammo_sign := PanelContainer.new()
	ammo_sign.add_theme_stylebox_override("panel", wood_sign_style())
	ammo_sign.anchor_left = 1.0
	ammo_sign.anchor_right = 1.0
	ammo_sign.anchor_top = 1.0
	ammo_sign.anchor_bottom = 1.0
	ammo_sign.offset_left = -190
	ammo_sign.offset_top = -86
	ammo_sign.offset_right = -24
	ammo_sign.offset_bottom = -24
	add_child(ammo_sign)
	_ammo_label = Label.new()
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ammo_label.add_theme_font_size_override("font_size", 30)
	_ammo_label.add_theme_color_override("font_color", Palette.BONE)
	ammo_sign.add_child(_ammo_label)

	_center_label = Label.new()
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.offset_left = -300
	_center_label.offset_right = 300
	_center_label.offset_top = 60
	_center_label.offset_bottom = 110
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 28)
	_center_label.add_theme_color_override("font_color", Palette.GLOW_YELLOW)
	_center_label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	_center_label.add_theme_constant_override("outline_size", 8)
	add_child(_center_label)

	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 12)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 4)
	_debug_label.visible = false
	add_child(_debug_label)


## Hooks the HUD up to a local player.
func bind_player(player: Player) -> void:
	player.revolver.ammo_changed.connect(_on_ammo_changed)
	player.revolver.reload_started.connect(func(_d: float) -> void: _ammo_label.text = "Reloading")
	player.fell_into_canyon.connect(func(delay: float) -> void: _show_message("Hauling you back up... (%.0f s)" % delay))
	player.respawned.connect(func() -> void: _center_label.text = "")
	_on_ammo_changed(player.revolver.ammo, Revolver.MAX_AMMO)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		_debug_label.visible = not _debug_label.visible
	if _debug_label.visible:
		_debug_label.text = "FPS %d\nDraw calls %d" % [
			Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]


func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_ammo_label.text = "%d / %d" % [current, max_ammo]


func _show_message(text: String) -> void:
	_center_label.text = text


## Wooden sign panel (StyleBoxFlat only, no textures).
static func wood_sign_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.WOOD
	sb.border_color = Palette.OUTLINE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(3, 3)
	sb.set_content_margin_all(10)
	return sb


## A small cross with a dark outline, drawn in code.
class Crosshair extends Control:
	func _draw() -> void:
		var c := size * 0.5
		for pass_i in 2:
			var col := Palette.OUTLINE if pass_i == 0 else Palette.BONE
			var w := 4.0 if pass_i == 0 else 2.0
			draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), col, w)
			draw_line(c + Vector2(4, 0), c + Vector2(10, 0), col, w)
			draw_line(c + Vector2(0, -10), c + Vector2(0, -4), col, w)
			draw_line(c + Vector2(0, 4), c + Vector2(0, 10), col, w)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
