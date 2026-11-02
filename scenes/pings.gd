class_name Pings
extends Control
## The ping wheel. Tap the ping key (middle mouse) to mark the spot under your
## crosshair; hold it to open a wheel and flick toward "Bugs here", "Need
## scrap", "Build here" or "On my way", then let go. Both players see the ping
## as a marker in the world (pinned to the screen edge when off screen) with a
## sound and a line in the feed. Lives in the world so its RPCs line up.

const HOLD := 0.18
const LIFETIME := 7.0
const RANGE := 400.0
const WHEEL_R := 110.0

## Each kind: label, colour, glyph drawn in the marker.
const KINDS := [
	{"label": "Look here", "color": Color("#F2E6C9"), "glyph": "!"},
	{"label": "Bugs here", "color": Color("#E0533A"), "glyph": "x"},
	{"label": "Need scrap", "color": Color("#F2C14E"), "glyph": "$"},
	{"label": "Build here", "color": Color("#7BC96F"), "glyph": "+"},
	{"label": "On my way", "color": Color("#6FA8DC"), "glyph": ">"},
]

static var instance: Pings

var _active: Array = [] # [{kind, pos, who, t}]
var _down := false
var _held := 0.0
var _wheel := false
var _aim := Vector2.ZERO
var _choice := -1


func _ready() -> void:
	instance = self
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Draw above the 3D world, under menus.
	z_index = 5


func _input(event: InputEvent) -> void:
	if GameState.menu_open:
		return
	if event.is_action_pressed("ping"):
		_down = true
		_held = 0.0
		_aim = Vector2.ZERO
		_choice = -1
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ping") and _down:
		_down = false
		var kind := (_choice + 1 if _choice >= 0 else -1) if _wheel else 0
		_wheel = false
		if kind >= 0:
			_send(kind)
		get_viewport().set_input_as_handled()
	elif _wheel and event is InputEventMouseMotion:
		# The wheel steals the mouse: no turning while you pick.
		_aim += (event as InputEventMouseMotion).relative
		if _aim.length() > WHEEL_R * 1.4:
			_aim = _aim.normalized() * WHEEL_R * 1.4
		_choice = _sector(_aim) if _aim.length() > 24.0 else -1
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _down:
		_held += delta
		if _held >= HOLD and not _wheel:
			_wheel = true
	for i in range(_active.size() - 1, -1, -1):
		_active[i]["t"] = float(_active[i]["t"]) - delta
		if float(_active[i]["t"]) <= 0.0:
			_active.remove_at(i)
	queue_redraw()


## 0 = up, 1 = right, 2 = down, 3 = left (wheel kinds 1..4).
static func _sector(v: Vector2) -> int:
	var a := fposmod(atan2(v.x, -v.y) + PI * 0.25, TAU)
	return int(a / (PI * 0.5)) % 4


func _send(kind: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.global_position
	var to := from - cam.global_basis.z * RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, WorldLayout.MASK_SHOTS)
	var me := get_tree().get_nodes_in_group("players").filter(func(p: Node) -> bool: return p.is_multiplayer_authority())
	if not me.is_empty():
		q.exclude = [(me[0] as CollisionObject3D).get_rid()]
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	var pos: Vector3 = hit["position"] if not hit.is_empty() else from - cam.global_basis.z * 60.0
	_ping.rpc(kind, pos, NetworkManager.local_name)


@rpc("any_peer", "call_local", "reliable")
func _ping(kind: int, pos: Vector3, who: String) -> void:
	kind = clampi(kind, 0, KINDS.size() - 1)
	# One live ping per player: a new one replaces the last.
	for i in range(_active.size() - 1, -1, -1):
		if _active[i]["who"] == who:
			_active.remove_at(i)
	_active.append({"kind": kind, "pos": pos, "who": who, "t": LIFETIME})
	Audio.play_ui(&"wheel_tick", -2.0)
	var hud := get_tree().get_first_node_in_group("hud_feed") as HudFeed
	if hud != null:
		hud.add_line("%s: %s" % [who, KINDS[kind]["label"]], KINDS[kind]["color"])


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		for p: Dictionary in _active:
			_draw_marker(cam, p)
	if _wheel:
		_draw_wheel()


func _draw_marker(cam: Camera3D, p: Dictionary) -> void:
	var k: Dictionary = KINDS[int(p["kind"])]
	var color: Color = k["color"]
	var pos: Vector3 = p["pos"]
	var vr := get_viewport_rect()
	var rect := Rect2(vr.position + Vector2(48, 90), vr.size - Vector2(96, 240))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return # headless or a tiny window
	var behind := cam.is_position_behind(pos)
	var s := cam.unproject_position(pos)
	if behind:
		s = rect.get_center() + (rect.get_center() - s) * 1000.0
	var off := behind or not rect.has_point(s)
	if off:
		var c := rect.get_center()
		var d := s - c
		var kk := minf(absf(rect.size.x * 0.5 / maxf(absf(d.x), 0.001)), absf(rect.size.y * 0.5 / maxf(absf(d.y), 0.001)))
		s = c + d * kk
		var dir := d.normalized()
		draw_colored_polygon(PackedVector2Array([s + dir * 22.0, s + dir.orthogonal() * 9.0 + dir * 8.0, s - dir.orthogonal() * 9.0 + dir * 8.0]), color)
	# Fade in the last second; a little bounce when it lands.
	var life := float(p["t"])
	var a := clampf(life, 0.0, 1.0)
	var bounce := 1.0 + 0.4 * maxf(0.0, (life - (LIFETIME - 0.3)) / 0.3)
	var r := 13.0 * bounce
	draw_circle(s, r + 3.0, Color(Palette.OUTLINE, 0.85 * a))
	draw_circle(s, r, Color(color, a))
	var font := get_theme_default_font()
	draw_string(font, s + Vector2(-5, 6), str(k["glyph"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.OUTLINE, a))
	# Who pinged and how far away.
	var dist := int(cam.global_position.distance_to(pos))
	var tag := "%s  %dm" % [str(k["label"]), dist]
	var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(font, s + Vector2(-w * 0.5, r + 18), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(Palette.OUTLINE, a))
	draw_string(font, s + Vector2(-w * 0.5, r + 18), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Palette.BONE, a))


func _draw_wheel() -> void:
	var c := get_viewport_rect().get_center()
	draw_circle(c, WHEEL_R + 10.0, Color(Palette.WOOD_DARK, 0.7))
	draw_arc(c, WHEEL_R + 10.0, 0, TAU, 64, Palette.OUTLINE, 3.0)
	var font := get_theme_default_font()
	for i in 4:
		var ang := -PI * 0.5 + float(i) * PI * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		var k: Dictionary = KINDS[i + 1]
		var on := i == _choice
		var at := c + dir * WHEEL_R * 0.72
		draw_circle(at, 30.0 if on else 24.0, Color(k["color"], 1.0 if on else 0.55))
		draw_arc(at, 30.0 if on else 24.0, 0, TAU, 32, Palette.OUTLINE, 2.0)
		draw_string(font, at + Vector2(-5, 7), str(k["glyph"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.OUTLINE)
		var label: String = k["label"]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		# Labels sit outside the ring: above/below for top/bottom, beside for left/right.
		var lp := at + Vector2(-w * 0.5, -40) if i == 0 else (at + Vector2(-w * 0.5, 52) if i == 2 else
				(at + Vector2(42, 5) if i == 1 else at + Vector2(-42 - w, 5)))
		draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Palette.OUTLINE)
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.GLOW_YELLOW if on else Palette.BONE)
	# Where the mouse is pointing.
	draw_line(c, c + _aim.limit_length(WHEEL_R * 0.5), Palette.BONE, 3.0)
	draw_circle(c, 5.0, Palette.BONE)
