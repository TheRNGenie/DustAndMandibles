class_name SpecialBadge
extends VBoxContainer
## The HUD's special weapon lines under the ammo counter (special weapons
## handoff, Part 3), shown while you hold a special weapon:
##   [crop icon] Corn - Ricochet      (crop-coloured)   or   (wrench) No Crop
##   BASE: Wide Cone                  (grey)
##   Visit workbench to upgrade       (until you've fitted a crop once)
## Also dyes the held gun's grip wrap and maker's mark for its crop
## (SpecialGuns.paint_grip) whenever the crop changes.

const ICON := 32
const POLL := 0.2

var _row: HBoxContainer
var _icon: TextureRect
var _wrench: Control
var _crop: Label
var _base: Label
var _hint: Label
var _t := 0.0
## [weapon id, code] last shown, and the gun model last painted with which crop.
var _shown: Array = []
var _painted: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 0)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_END
	_row.add_theme_constant_override("separation", 5)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON, ICON) * 0.75
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_icon)
	_wrench = Control.new()
	_wrench.custom_minimum_size = Vector2(ICON, ICON) * 0.75
	_wrench.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrench.draw.connect(_draw_wrench)
	_row.add_child(_wrench)
	_crop = KeyHints.ink("", 14)
	_crop.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_crop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_crop)
	_base = KeyHints.ink("", 12, true)
	_base.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_base)
	_hint = KeyHints.ink("Visit workbench to upgrade", 12, true)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(1, 1, 1, 0.75)
	add_child(_hint)
	visible = false


## The empty-crop badge: a plain circle with a little wrench across it.
func _draw_wrench() -> void:
	var s := _wrench.size
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.42
	var col := Color(0.75, 0.72, 0.66, 0.9)
	_wrench.draw_arc(c, r, 0.0, TAU, 28, col, 1.6, true)
	var a := c + Vector2(-r, r) * 0.45
	var b := c + Vector2(r, -r) * 0.45
	_wrench.draw_line(a, b, col, 2.2, true)
	_wrench.draw_arc(b, r * 0.28, PI * 0.5, PI * 2.0, 12, col, 2.0, true)


func _local_gun() -> Gun:
	if get_tree() == null:
		return null
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == multiplayer.get_unique_id():
			return (n as Player).gun
	return null


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = POLL
	var gun := _local_gun()
	if gun == null:
		visible = false
		return
	_paint(gun)
	var id := gun.def.id if gun.def != null and gun.holding == &"" else &""
	if not SpecialRules.is_special(id):
		visible = false
		_shown = []
		return
	visible = true
	var code := gun.code_of(id)
	var key := [id, code, CropBench.used_once]
	if key == _shown:
		return
	_shown = key
	var crop := SpecialCrop.crop_of(code)
	_icon.visible = crop != &""
	_wrench.visible = crop == &""
	if crop != &"":
		var tex: Variant = CropBench.crop_icon(crop)
		_icon.texture = tex as Texture2D if tex is Texture2D else null
		_crop.text = "%s - %s" % [CropEffects.short_name(crop), CropEffects.effect_name(crop)]
		_crop.add_theme_color_override("font_color", SpecialCrop.color_of(crop).lightened(0.15))
	else:
		_crop.text = "No Crop"
		_crop.add_theme_color_override("font_color", Color(0.7, 0.68, 0.63))
	_base.text = "BASE: %s" % SpecialRules.base_name(id)
	_hint.visible = crop == &"" and not CropBench.used_once


## Dye the special weapon's first-person model for its crop when that changes.
func _paint(gun: Gun) -> void:
	var id := SpecialRules.held_in(gun.owned)
	if id == &"":
		return
	var crop := SpecialCrop.crop_of(gun.code_of(id))
	var model: Node = gun._models.get(id) as Node
	if model == null:
		return
	if _painted.get(model.get_instance_id(), &"none") == crop:
		return
	_painted[model.get_instance_id()] = crop
	SpecialGuns.paint_grip(model, crop)
