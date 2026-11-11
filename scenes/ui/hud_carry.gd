class_name HudCarry
extends PanelContainer
## The crops you carry on you (playtest fixes, Nov 2026: up to 25 of each kind,
## yours alone, apart from the cellar): a row of crop badges with "12/25" just
## over your health card on the left (the hotbar's harvest slots 4-6 only have
## room for three kinds; the middle is the turret card's). It
## shows for a few seconds whenever what you carry changes, and the whole time
## you're down in the root cellar (where the ammo workbench takes them).
##
## Reads the local player's carry, duck-typed (the dev side's PlayerCarry):
##   player.carry.carried() -> {crop: n}    player.carry.CAP (25)
##   player.in_cellar (optional bool)

const SHOW_FOR := 4.0
const FADE := 0.3

var _shown: Dictionary = {}
var _age := 99.0
var _row: HFlowContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", KeyHints.kit_box("plate_tight"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 24
	offset_right = 24
	offset_bottom = -230 # (until the health card is found: _place)
	offset_top = -230
	_row = HFlowContainer.new() # (wraps to the health card's width)
	_row.add_theme_constant_override("h_separation", 10)
	_row.add_theme_constant_override("v_separation", 4)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	var p := _local_player()
	var carry: Variant = p.get("carry") if p != null else null
	if not (carry is Object) or not is_instance_valid(carry) or not (carry as Object).has_method("carried"):
		visible = false
		return
	var now: Dictionary = (carry as Object).call("carried")
	var cap := int((carry as Object).get("CAP")) if (carry as Object).get("CAP") != null else 25
	if now != _shown:
		_shown = now.duplicate()
		_age = 0.0
		_fill(now, cap)
	_age += delta
	_place()
	var stay := bool(p.get("in_cellar")) if p.get("in_cellar") != null else false
	var want := 1.0 if (not now.is_empty() and (stay or _age < SHOW_FOR)) else 0.0
	modulate.a = move_toward(modulate.a, want, delta / FADE)
	visible = modulate.a > 0.01


## The badges: every crop you carry, most first, "n/cap" (full ones in the accent).
func _fill(now: Dictionary, cap: int) -> void:
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	var keys := now.keys().filter(func(k: Variant) -> bool: return int(now[k]) > 0)
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(now[a]) > int(now[b]))
	for k: Variant in keys:
		var crop := StringName(str(k))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.tooltip_text = CropEffects.short_name(crop)
		h.add_child(CropChip.make(crop, 22))
		var n := int(now[k])
		var l := KeyHints.number("%d/%d" % [n, cap], 15)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if n >= cap:
			l.add_theme_color_override("font_color", UiStyle.c("accent_hi"))
		h.add_child(l)
		_row.add_child(h)


## Sits just over the HUD's health card (it grows upward with optional rows, so
## its live top is read), clear of the turret card in the middle.
func _place() -> void:
	var hud := get_parent()
	var st: Variant = hud.get("status") if hud != null else null
	if not (st is Control) or (st as Control).get_child_count() == 0:
		return
	var card := (st as Control).get_child(0) as Control
	if card == null or not card.is_visible_in_tree():
		return
	var r := card.get_global_rect()
	offset_left = r.position.x
	offset_right = r.position.x
	offset_bottom = r.position.y - get_viewport().get_visible_rect().size.y - 8.0
	offset_top = offset_bottom
	_row.custom_minimum_size.x = maxf(r.size.x - 24.0, 200.0)


func _local_player() -> Node:
	for n: Node in get_tree().get_nodes_in_group("players"):
		var pl := n as Player
		if pl != null and pl.is_multiplayer_authority() and not pl.bot:
			return pl
	return null


## The gallery: a made-up load to show (no player carry needed).
func demo(now: Dictionary, cap: int = 25) -> void:
	set_process(false)
	_fill(now, cap)
	_place()
	modulate.a = 1.0
	visible = true
