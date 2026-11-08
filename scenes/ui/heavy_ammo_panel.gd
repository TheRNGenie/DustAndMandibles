class_name HeavyAmmoPanel
extends VBoxContainer
## The HUD's heavy weapon lines under the ammo counter (heavy weapons handoff,
## Part 3), shown while you hold a universal crop-loaded heavy:
##   [sack icon] (dot) Corn - Ricochet   (crop-coloured)
##   [R] Load Crop                       (bright when the gun is empty)
## It also works the counter itself (`ammo_label`, the HUD's big figure): the
## last tenth of a sack pulses amber with a soft glow behind it, and an empty
## gun reads "— EMPTY —" in faded grey, pulsing slowly (Hud._on_ammo_changed).

const ICON := 32
const POLL := 0.15

## The HUD's big ammo figure (set by Hud when it makes this).
var ammo_label: Label
var _row: HBoxContainer
var _icon: TextureRect
var _dot: Control
var _crop: Label
var _key: HBoxContainer
var _glow: Control
var _t := 0.0
var _pulse := 0.0
var _gun: Gun
var _shown := ""
var _icons: Dictionary = {}
var _col := Color.WHITE
var _state := "" # "", "low", "empty"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 2)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_END
	_row.add_theme_constant_override("separation", 5)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON, ICON)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_icon)
	_dot = Control.new()
	_dot.custom_minimum_size = Vector2(14, 14)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(func() -> void: _dot.draw_circle(_dot.size * 0.5, 6.0, _col))
	_row.add_child(_dot)
	_crop = KeyHints.ink("", 14)
	_crop.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_crop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_crop.add_theme_font_override("font", UiStyle.font("bold"))
	_row.add_child(_crop)
	_key = KeyHints.hint(KeyHints.key_for("reload"), "Load Crop")
	_key.alignment = BoxContainer.ALIGNMENT_END
	add_child(_key)
	for c: StringName in CropEffects.IDS:
		var path := "res://assets/icons/%s.png" % CropEffects.sack_of(c)
		if ResourceLoader.exists(path):
			_icons[c] = load(path)
	visible = false


## Hud: a soft amber glow behind the counter (made beside it, under it in draw order).
func make_glow(parent: Control) -> void:
	_glow = Control.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.show_behind_parent = true
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.draw.connect(_draw_glow)
	parent.add_child(_glow)


func _draw_glow() -> void:
	if _state != "low" or ammo_label == null:
		return
	var r := ammo_label.get_global_rect()
	var c := r.get_center() - _glow.get_global_rect().position
	var a := 0.18 + 0.22 * (0.5 + 0.5 * sin(_pulse * 6.0))
	for i in 3:
		_glow.draw_circle(c, r.size.y * (0.55 + 0.2 * i), Color(HeavyRules.LOW_AMBER, a / (i + 1.5)))


func _local_gun() -> Gun:
	if _gun != null and is_instance_valid(_gun):
		return _gun
	if get_tree() == null:
		return null
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p != null and p.is_multiplayer_authority() and not p.bot:
			_gun = p.gun
			return _gun
	return null


func _process(delta: float) -> void:
	_pulse += delta
	_animate()
	_t -= delta
	if _t > 0.0:
		return
	_t = POLL
	var gun := _local_gun()
	var held := gun != null and gun.def != null and gun.holding == &"" and gun.def.crop_ammo
	if not held:
		if visible:
			visible = false
			_state = ""
			_reset_label()
		return
	visible = true
	var crop := gun.heavy_crop_of(gun.def.id)
	var empty := crop == &"" or gun.ammo <= 0
	_state = "empty" if empty else ("low" if HeavyRules.is_low(gun.ammo, gun.mag_size()) else "")
	var key := "%s:%s:%s" % [gun.def.id, crop, empty]
	if key == _shown:
		return
	_shown = key
	_row.visible = not empty
	if not empty:
		_col = HeavyRules.color_of(crop)
		var tex: Variant = _icons.get(crop)
		_icon.texture = tex as Texture2D if tex is Texture2D else null
		_crop.text = "%s - %s" % [CropEffects.short_name(crop), CropEffects.effect_name(crop)]
		_crop.add_theme_color_override("font_color", _col.lightened(0.15))
		_dot.queue_redraw()


## The counter's pulse (amber when low, a faded grey breath when empty) and the
## bright [R] while it's empty.
func _animate() -> void:
	if not visible:
		return
	var breath := 0.5 + 0.5 * sin(_pulse * (6.0 if _state == "low" else 2.4))
	if ammo_label != null:
		match _state:
			"low":
				ammo_label.modulate = Color.WHITE.lerp(HeavyRules.LOW_AMBER.lightened(0.2), 0.55 + 0.45 * breath)
			"empty":
				ammo_label.modulate = Color(0.62, 0.6, 0.56, 0.55 + 0.35 * breath)
			_:
				ammo_label.modulate = Color.WHITE
	_key.modulate = Color(1.25, 1.2, 1.0, 1.0) if _state == "empty" else Color(1, 1, 1, 0.75)
	if _glow != null:
		_glow.queue_redraw()


func _reset_label() -> void:
	if ammo_label != null:
		ammo_label.modulate = Color.WHITE
	if _glow != null:
		_glow.queue_redraw()
