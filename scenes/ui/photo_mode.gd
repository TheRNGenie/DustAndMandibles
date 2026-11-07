class_name PhotoMode
extends CanvasLayer
## Photo mode. The photo key (P) steps through: HUD hidden -> free camera ->
## back to normal. Esc also leaves. The free camera flies with the move keys
## (jump / slide for up and down, sprint for fast) while your rider stands still.
## A short card names the keys on each step, then fades so the shot is clean.
## Its own layer beside the HUD, so hiding the HUD doesn't hide the card.

enum Mode { OFF, CLEAN, FREE }

const SPEED := 8.0
const FAST := 3.0

var hud: Hud
var mode := Mode.OFF
var _cam: Camera3D
var _player_cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _card: PanelContainer
var _card_tw: Tween
var _blocked_menu := false


func _ready() -> void:
	layer = 20
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", KeyHints.card_style())
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_bottom = -28
	_card.visible = false
	add_child(_card)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("photo_mode") and not event.is_echo():
		if mode == Mode.OFF and GameState.menu_open:
			return
		_step()
		get_viewport().set_input_as_handled()
	elif mode != Mode.OFF and event.is_action_pressed("pause_menu"):
		_set_mode(Mode.OFF)
		get_viewport().set_input_as_handled()
	elif mode == Mode.FREE and event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		var y_sign := -1.0 if Settings.invert_y else 1.0
		_yaw -= m.relative.x * Settings.mouse_sensitivity
		_pitch = clampf(_pitch - m.relative.y * Settings.mouse_sensitivity * y_sign, -1.5, 1.5)
		get_viewport().set_input_as_handled()


func _step() -> void:
	match mode:
		Mode.OFF:
			_set_mode(Mode.CLEAN)
		Mode.CLEAN:
			var me := _local_player()
			var can_fly := me != null and not (me.build_mode != null and (me.build_mode.active or me.build_mode.menu_open))
			_set_mode(Mode.FREE if can_fly else Mode.OFF)
		Mode.FREE:
			_set_mode(Mode.OFF)


func _set_mode(m: Mode) -> void:
	if m != Mode.FREE:
		_leave_free()
	mode = m
	if hud != null:
		hud.visible = m == Mode.OFF
	match m:
		Mode.OFF:
			_card.visible = false
		Mode.CLEAN:
			_show_card("Photo mode", [[KeyHints.key_for("photo_mode"), "Free camera"], ["Esc", "Exit"]])
		Mode.FREE:
			_enter_free()
			_show_card("Free camera", [["WASD", "Fly"], [KeyHints.key_for("jump"), "Up"], [KeyHints.key_for("slide"), "Down"],
					[KeyHints.key_for("sprint"), "Fast"], [KeyHints.key_for("photo_mode"), "Exit"]])


func _enter_free() -> void:
	_player_cam = get_viewport().get_camera_3d()
	if _player_cam == null:
		return
	_cam = Camera3D.new()
	_cam.fov = _player_cam.fov
	_cam.far = _player_cam.far
	_cam.near = _player_cam.near
	(hud.get_parent() if hud != null else get_tree().current_scene).add_child(_cam)
	_cam.global_transform = _player_cam.global_transform
	var e := _player_cam.global_basis.get_euler()
	_yaw = e.y
	_pitch = e.x
	_cam.current = true
	# Freeze the rider (movement, shooting, interacting) while you fly.
	if not _blocked_menu:
		GameState.set_menu(self, true)
		_blocked_menu = true


func _leave_free() -> void:
	if _cam != null:
		_cam.queue_free()
		_cam = null
		if _player_cam != null and is_instance_valid(_player_cam):
			_player_cam.current = true
	_player_cam = null
	if _blocked_menu:
		GameState.set_menu(self, false)
		_blocked_menu = false


func _process(delta: float) -> void:
	if mode != Mode.FREE or _cam == null:
		return
	_cam.global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := _cam.global_basis * Vector3(v.x, 0.0, v.y)
	if Input.is_action_pressed("jump"):
		dir += Vector3.UP
	if Input.is_action_pressed("slide"):
		dir += Vector3.DOWN
	var speed := SPEED * (FAST if Input.is_action_pressed("sprint") else 1.0)
	_cam.global_position += dir.limit_length(1.0) * speed * delta


func _show_card(title: String, keys: Array) -> void:
	for c in _card.get_children():
		_card.remove_child(c)
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	var t := KeyHints.text(title, 16, Palette.BONE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(KeyHints.row(keys))
	_card.visible = true
	_card.modulate.a = 1.0
	if _card_tw != null:
		_card_tw.kill()
	_card_tw = _card.create_tween()
	_card_tw.tween_interval(2.5)
	_card_tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	_card_tw.tween_callback(func() -> void: _card.visible = false)


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority():
			return n as Player
	return null


func _exit_tree() -> void:
	_leave_free()
