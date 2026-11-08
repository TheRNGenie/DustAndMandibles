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
	{"label": "Need chitin", "color": Color("#F2C14E"), "glyph": "$"},
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
	# On a small pill plate (the HUD kit's), the kit's bold face.
	var tf := UiStyle.font("bold")
	var fs := UiStyle.ts(13)
	var w := tf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill := Rect2(s + Vector2(-w * 0.5 - 8.0, r + 5.0), Vector2(w + 16.0, fs + 6.0))
	if a >= 0.99:
		draw_style_box(KeyHints.kit_box("pill"), pill)
	else:
		draw_rect(pill, Color(UiStyle.kc("deep", UiStyle.current, 1), 0.9 * a))
	draw_string(tf, Vector2(pill.position.x + 8.0, pill.position.y + fs * 0.95), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiStyle.kc("text"), a))


func _draw_wheel() -> void:
	var c := get_viewport_rect().get_center()
	KeyHints.draw_wheel_disc(self, c, WHEEL_R, _aim)
	var font := UiStyle.font("number")
	for i in 4:
		var ang := -PI * 0.5 + float(i) * PI * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		var k: Dictionary = KINDS[i + 1]
		var on := i == _choice
		var at := c + dir * WHEEL_R * 0.72
		KeyHints.draw_wheel_slot(self, at, on, k["color"])
		var gw := font.get_string_size(str(k["glyph"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(font, at + Vector2(-gw * 0.5, 8), str(k["glyph"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.OUTLINE)
		# Labels sit outside the ring on small plates: above/below, or beside.
		KeyHints.draw_wheel_label(self, at, i, UiStyle.tc(str(k["label"])), on)
