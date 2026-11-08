class_name Emotes
extends Control
## The emote wheel. Tap the emote key (H) to tip your hat; hold it to open a
## wheel and flick toward Tip hat, Wave, Point or Shrug, then let go. Your body
## acts it out for everyone (Player.act replicates it) and your partner sees a
## small card over your head naming it, so it reads even across the canyon.
## Lives on the HUD under a fixed name so its RPCs line up on every peer.

const HOLD := 0.18
const WHEEL_R := 110.0
const BUBBLE_TIME := 2.6

var _down := false
var _held := 0.0
var _wheel := false
var _aim := Vector2.ZERO
var _choice := -1
## Cards over other players' heads: [{peer, id, t}].
var _bubbles: Array = []
var _was_busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	if GameState.flag_value("--emoteview") != "":
		var view: Node = load("res://scenes/debug/emote_view.gd").new()
		add_child(view)


func _input(event: InputEvent) -> void:
	if GameState.menu_open:
		_down = false
		_wheel = false
		return
	if event.is_action_pressed("emote") and not event.is_echo():
		_down = true
		_held = 0.0
		_aim = Vector2.ZERO
		_choice = -1
		get_viewport().set_input_as_handled()
	elif event.is_action_released("emote") and _down:
		_down = false
		var pick := (_choice if _wheel else 0)
		_wheel = false
		if pick >= 0:
			play(DummyActions.EMOTES[pick])
		get_viewport().set_input_as_handled()
	elif _wheel and event is InputEventMouseMotion:
		# The wheel steals the mouse: no turning while you pick.
		_aim += (event as InputEventMouseMotion).relative
		if _aim.length() > WHEEL_R * 1.4:
			_aim = _aim.normalized() * WHEEL_R * 1.4
		_choice = Pings._sector(_aim) if _aim.length() > 24.0 else -1
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _down:
		_held += delta
		if _held >= HOLD and not _wheel:
			_wheel = true
	for i in range(_bubbles.size() - 1, -1, -1):
		_bubbles[i]["t"] = float(_bubbles[i]["t"]) - delta
		if float(_bubbles[i]["t"]) <= 0.0:
			_bubbles.remove_at(i)
	# Keep drawing while anything shows, and once more after it all goes.
	var busy := _wheel or not _bubbles.is_empty()
	if busy or _was_busy:
		queue_redraw()
	_was_busy = busy


## Acts out an emote as the local player and shows it to everyone else.
func play(id: StringName) -> void:
	var me := _local_player()
	if me == null or me.is_downed() or (me.fp_hands != null and me.fp_hands.is_playing()):
		return
	me.act(id)
	_shown.rpc(multiplayer.get_unique_id(), DummyActions.EMOTES.find(id))


@rpc("any_peer", "call_local", "reliable")
func _shown(peer: int, index: int) -> void:
	if index < 0 or index >= DummyActions.EMOTES.size() or peer == multiplayer.get_unique_id():
		return
	for i in range(_bubbles.size() - 1, -1, -1):
		if int(_bubbles[i]["peer"]) == peer:
			_bubbles.remove_at(i)
	_bubbles.append({"peer": peer, "id": DummyActions.EMOTES[index], "t": BUBBLE_TIME})


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority():
			return n as Player
	return null


func _player_of(peer: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer:
			return n as Player
	return null


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		for b: Dictionary in _bubbles:
			_draw_bubble(cam, b)
	if _wheel:
		_draw_wheel()


## A small card over the emoting player's head: who, and what.
func _draw_bubble(cam: Camera3D, b: Dictionary) -> void:
	var p := _player_of(int(b["peer"]))
	if p == null:
		return
	var head := p.global_position + Vector3.UP * 2.3
	if cam.is_position_behind(head):
		return
	var s := cam.unproject_position(head)
	if not get_viewport_rect().grow(-20).has_point(s):
		return
	var life := float(b["t"])
	var a := clampf(life * 3.0, 0.0, 1.0) * clampf((BUBBLE_TIME - life) * 6.0, 0.0, 1.0)
	var font := get_theme_default_font()
	var who := p.display_name()
	var line := "%s  ·  %s" % [who, DummyActions.EMOTE_NAMES[b["id"]]]
	var fs := 15
	var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var rect := Rect2(s + Vector2(-w * 0.5 - 12.0, -30.0), Vector2(w + 24.0, 28.0))
	var sb := KeyHints.card_style()
	sb.set_content_margin_all(0)
	sb.shadow_size = 3
	_fade(sb, a)
	draw_style_box(sb, rect)
	# A little tail pointing down at the head.
	var tip := PackedVector2Array([rect.get_center() + Vector2(-7, 14), rect.get_center() + Vector2(7, 14), rect.get_center() + Vector2(0, 22)])
	draw_colored_polygon(tip, Color(Palette.OUTLINE, a))
	draw_string(font, rect.position + Vector2(12, 20), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.BONE, a))


static func _fade(sb: StyleBoxFlat, a: float) -> void:
	sb.bg_color.a *= a
	sb.border_color.a *= a
	sb.shadow_color.a *= a


func _draw_wheel() -> void:
	var c := get_viewport_rect().get_center()
	KeyHints.draw_wheel_disc(self, c, WHEEL_R, _aim)
	for i in 4:
		var ang := -PI * 0.5 + float(i) * PI * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		var id: StringName = DummyActions.EMOTES[i]
		var on := i == _choice
		var at := c + dir * WHEEL_R * 0.72
		var r := KeyHints.draw_wheel_slot(self, at, on, Palette.BONE)
		_draw_icon(id, at, r * 0.55)
		KeyHints.draw_wheel_label(self, at, i, UiStyle.tc(str(DummyActions.EMOTE_NAMES[id])), on)


## Little drawn icons: a hat, a waving hand's motion lines, an arrow, a "?".
func _draw_icon(id: StringName, at: Vector2, s: float) -> void:
	var ink := Palette.OUTLINE
	match id:
		&"tip_hat":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.55, s * 0.15), at + Vector2(-s * 0.45, -s * 0.6),
					at + Vector2(s * 0.45, -s * 0.6), at + Vector2(s * 0.55, s * 0.15)]), ink)
			draw_line(at + Vector2(-s, s * 0.3), at + Vector2(s, s * 0.3), ink, 4.0)
		&"wave":
			for k in 3:
				var rr := s * (0.35 + 0.3 * k)
				draw_arc(at + Vector2(-s * 0.4, s * 0.4), rr, -PI * 0.5, 0.0, 10, ink, 3.0)
		&"point":
			draw_line(at + Vector2(-s, 0), at + Vector2(s * 0.5, 0), ink, 4.0)
			draw_colored_polygon(PackedVector2Array([at + Vector2(s, 0), at + Vector2(s * 0.35, -s * 0.5), at + Vector2(s * 0.35, s * 0.5)]), ink)
		&"shrug":
			var font := get_theme_default_font()
			draw_string(font, at + Vector2(-s * 0.4, s * 0.55), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 2.0), ink)
