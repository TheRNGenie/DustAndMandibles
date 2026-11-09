class_name CropWheel
extends Control
## The crop selector wheel for the universal crop-fed turrets: nine segments,
## one per crop, each with its sack, name, effect and how many sacks you have,
## on the crop's colour. The loaded crop has a bright border; crops you have no
## sacks of are dimmed and can't be picked.
##
## Q while looking at a universal turret opens it (it takes the key before the
## hotbar's drop), and so does E on one with no last crop to reload. Move the
## mouse towards a crop, click to load it; Q, right click or Esc closes it.
## Lives on the HUD (a fixed name, so it's found on every peer).

static var instance: CropWheel

const RADIUS := 250.0
const SLOT_R := 44.0

## The universal turret (UniversalTurret or UniversalCrewedTurret) being loaded,
## or the local player's Gun with a universal heavy out (HeavyRules).
var turret: Node
## Opened by holding a key (R for a heavy): letting go of it loads the crop
## pointed at (&"" = click to load, as for turrets).
var release_action: StringName = &""
var _open := false
var _aim := Vector2.ZERO
var _choice := -1
var _icons: Dictionary = {}


func _ready() -> void:
	instance = self
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	for c: StringName in CropEffects.IDS:
		var path := "res://assets/icons/%s.png" % CropEffects.sack_of(c)
		if ResourceLoader.exists(path):
			_icons[c] = load(path)


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if _open:
		GameState.set_menu(self, false)


## Opens the wheel for `t` (the local player's).
static func open_for(t: Node, release: StringName = &"") -> void:
	if instance == null or t == null:
		return
	instance.turret = t
	instance.release_action = release
	instance._open = true
	instance._aim = Vector2.ZERO
	instance._choice = -1
	GameState.set_menu(instance, true)
	instance.queue_redraw()


func close() -> void:
	if not _open:
		return
	_open = false
	GameState.set_menu(self, false)
	queue_redraw()


func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if not _open:
		# Q on a universal turret: the wheel, not a dropped item.
		if event.is_action_pressed("drop_item") and not event.is_echo() and not GameState.menu_open:
			var t := _looked_at()
			if t != null and bool(t.call("local_swap")):
				get_viewport().set_input_as_handled()
		return
	if turret == null or not is_instance_valid(turret) or not bool(turret.call("can_load_now")):
		close()
		return
	if release_action != &"" and event.is_action_released(release_action):
		# Held-key wheel (a heavy's R): letting go loads what it points at.
		if _choice >= 0 and _can_pick(CropEffects.IDS[_choice]):
			turret.call("request_load", CropEffects.IDS[_choice])
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_aim += (event as InputEventMouseMotion).relative
		if _aim.length() > RADIUS * 1.3:
			_aim = _aim.normalized() * RADIUS * 1.3
		_choice = _sector(_aim) if _aim.length() > 30.0 else -1
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fire"):
		if _choice >= 0:
			var c: StringName = CropEffects.IDS[_choice]
			if _can_pick(c):
				turret.call("request_load", c)
				close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("drop_item") or event.is_action_pressed("alt_fire") or event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


## The universal turret the local player is looking at, if any.
func _looked_at() -> Turret:
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p != null and p.is_multiplayer_authority() and not p.bot:
			if p.crewing != null or p.is_downed() or (p.build_mode != null and p.build_mode.menu_open):
				return null
			var t: Variant = p.vitals.call("_look_target")
			return t as Turret if (t is Turret and (t as Turret).has_method("local_swap")) else null
	return null


## The segment `v` points at: 0 straight up, then clockwise.
static func _sector(v: Vector2) -> int:
	var a := fposmod(atan2(v.x, -v.y) + PI / 9.0, TAU)
	return int(a / (TAU / 9.0)) % 9


func _process(_delta: float) -> void:
	if _open:
		queue_redraw()


func _draw() -> void:
	if not _open or turret == null or not is_instance_valid(turret):
		return
	# Drawn for 1080p and scaled to the window, so it fits at 720p (clear of the
	# hotbar) and doesn't shrink to a dot at 4K.
	var vp := get_viewport_rect()
	var zoom := clampf(vp.size.y / 1080.0, 0.62, 2.0)
	draw_set_transform(vp.get_center(), 0.0, Vector2(zoom, zoom))
	var c := Vector2.ZERO
	var loaded_crop := StringName(turret.get("crop"))
	KeyHints.draw_wheel_disc(self, c, RADIUS, _aim)
	var font := UiStyle.font("bold")
	var font_r := UiStyle.font("regular")
	# The middle: the turret's name and what it's loaded with.
	var title := UiStyle.tc(str((turret.get("def") as Resource).get("display_name")))
	var fs := UiStyle.ts(17)
	draw_string(font, c + Vector2(-140, -8), title, HORIZONTAL_ALIGNMENT_CENTER, 280, fs, UiStyle.kc("text"))
	var now := "Loaded: %s" % CropEffects.short_name(loaded_crop) if loaded_crop != &"" else "Empty"
	draw_string(font_r, c + Vector2(-140, 16), now, HORIZONTAL_ALIGNMENT_CENTER, 280, UiStyle.ts(13),
			CropEffects.color_of(loaded_crop).lightened(0.2) if loaded_crop != &"" else Color(0.7, 0.7, 0.7))
	if _choice >= 0:
		var pick: StringName = CropEffects.IDS[_choice]
		draw_string(font_r, c + Vector2(-140, 36), "Release to load" if release_action != &"" else "Click to load", HORIZONTAL_ALIGNMENT_CENTER, 280, UiStyle.ts(12),
				UiStyle.kc("accent_hi") if _can_pick(pick) else Color(0.6, 0.6, 0.6))
	for i in 9:
		var crop: StringName = CropEffects.IDS[i]
		var ang := -PI * 0.5 + float(i) * TAU / 9.0
		var dir := Vector2(cos(ang), sin(ang))
		var at := c + dir * RADIUS * 0.66
		var have := int(turret.call("sacks_of", crop))
		var on := i == _choice
		var loaded := crop == loaded_crop
		var col: Color = CropEffects.color_of(crop)
		var dim := have <= 0
		var r := SLOT_R * (1.12 if on and not dim else 1.0)
		# Segment: the crop's colour (dimmed with no sacks), a dark well, its sack icon.
		draw_circle(at, r + 4.0, Color(0, 0, 0, 0.45))
		draw_circle(at, r, Color(col.darkened(0.55), 0.55) if dim else col.darkened(0.15))
		draw_circle(at, r - 7.0, Color(UiStyle.kc("well"), 0.9))
		if _icons.has(crop):
			var s := (r - 9.0) * 1.5
			draw_texture_rect(_icons[crop], Rect2(at - Vector2(s, s) * 0.5 - Vector2(0, 6), Vector2(s, s)), false,
					Color(1, 1, 1, 0.35) if dim else Color.WHITE)
		var ring := UiStyle.kc("accent_hi") if loaded else (col.lightened(0.3) if on and not dim else Color(col, 0.5 if dim else 0.85))
		draw_arc(at, r, 0, TAU, 48, ring, 5.0 if loaded else (3.0 if on else 1.5), true)
		# Sack count badge.
		var badge := at + Vector2(r * 0.72, -r * 0.72)
		draw_circle(badge, 13.0, Color(0, 0, 0, 0.75))
		draw_string(font, badge + Vector2(-13, 5), str(have), HORIZONTAL_ALIGNMENT_CENTER, 26, UiStyle.ts(13),
				Color(0.6, 0.6, 0.6) if dim else Color.WHITE)
		# Name and effect just outside the ring, on a dark plate.
		var name_s := CropEffects.short_name(crop)
		var eff := CropEffects.effect_name(crop)
		var text_c := Color(0.55, 0.55, 0.55) if dim else (UiStyle.kc("accent_hi") if on else UiStyle.kc("text"))
		var lab := c + dir * (RADIUS * 0.66 + SLOT_R + 38.0)
		var nfs := UiStyle.ts(15)
		var efs := UiStyle.ts(12)
		var w := maxf(font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x, font_r.get_string_size(eff, HORIZONTAL_ALIGNMENT_LEFT, -1, efs).x) + 16.0
		var plate := Rect2(lab - Vector2(w * 0.5, nfs * 0.5 + 6.0), Vector2(w, nfs + efs + 12.0))
		draw_rect(plate, Color(0.08, 0.06, 0.05, 0.82))
		draw_rect(plate, Color(col, 0.35 if dim else 0.8), false, 1.5)
		draw_string(font, Vector2(plate.position.x, plate.position.y + nfs + 1.0), name_s, HORIZONTAL_ALIGNMENT_CENTER, w, nfs, text_c)
		draw_string(font_r, Vector2(plate.position.x, plate.position.y + nfs + efs + 5.0), eff, HORIZONTAL_ALIGNMENT_CENTER, w, efs,
				Color(col.lightened(0.3), 0.5 if dim else 1.0))
	# The keys along the bottom.
	var keys := str(turret.call("wheel_keys")) if turret.has_method("wheel_keys") else "Click: Load   ·   Q / Right Click: Close"
	draw_string(font_r, c + Vector2(-200, RADIUS + 100), keys, HORIZONTAL_ALIGNMENT_CENTER, 400,
			UiStyle.ts(13), UiStyle.kc("text"))


## May crop `c` be loaded now? (A heavy also takes a fresh sack of the crop already in it.)
func _can_pick(c: StringName) -> bool:
	if turret.has_method("can_pick"):
		return bool(turret.call("can_pick", c))
	return int(turret.call("sacks_of", c)) > 0 and c != StringName(turret.get("crop"))
