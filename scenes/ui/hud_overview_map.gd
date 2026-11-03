class_name HudOverviewMap
extends Control
## The overview map (M): a top-down plan of the map (any map, north up on the
## bigger ones; MapDef frames place each cliff). Each cliff is labelled
## by name with its owner in (brackets), every turret and structure sits on its
## grid cell, and the airship shows where it hangs. Hold-free: press M to open,
## M or Esc to close. Refreshes twice a second while open.

const SCALE := 8.0 # pixels per metre
## Along-canyon span shown (the airship hangs north of the plateaus).
const Z_MIN := -28.0
const Z_MAX := 62.0
const PAD := 28.0

var player: Player
## Map pixels per metre, and the world (x, z) drawn at the canvas's padded corner.
var _scale := SCALE
var _origin := Vector2.ZERO
var _size := Vector2.ZERO
var _panel: PanelContainer
var _canvas: Control
var _t := 0.0
## How far the panel is shrunk to fit the screen; text is drawn larger by its
## inverse so it never reads smaller than 12 px on screen.
var _k := 1.0
## [Label, base size] pairs that keep their on-screen size when the panel shrinks.
var _texts: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20 # above the in-world ping and alert markers
	visible = false
	_panel = PanelContainer.new()
	var sb := KeyHints.card_style() # the set's HUD card, nearly opaque
	sb.bg_color = Color(sb.bg_color, 0.98)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_fit()
	var title := KeyHints.text("Canyon Map" if WorldLayout.map().is_canyon() else UiStyle.tc(WorldLayout.map().display_name), 24, UiStyle.c("title"))
	title.add_theme_font_override("font", UiStyle.display_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_texts.append([title, 24])
	_canvas = Control.new()
	_canvas.custom_minimum_size = _map_size()
	_canvas.draw.connect(_draw_map)
	col.add_child(_canvas)
	col.add_child(_legend())
	col.add_child(KeyHints.row([[KeyHints.key_for("overview_map"), "Close"]]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("overview_map") and not GameState.menu_open:
		visible = not visible
		_t = 0.0
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		_canvas.queue_redraw()
		(func() -> void:
			var s := _panel.get_combined_minimum_size()
			_panel.offset_left = -s.x * 0.5
			_panel.offset_right = s.x * 0.5
			_panel.offset_top = -s.y * 0.5
			_panel.offset_bottom = s.y * 0.5
			# Shrink to fit between the plaque and the hotbar on short screens.
			var vp := get_viewport_rect().size
			var k := minf(1.0, minf((vp.y - 150.0) / s.y, (vp.x - 60.0) / s.x))
			_panel.pivot_offset = s * 0.5
			_panel.scale = Vector2(k, k)
			if absf(k - _k) > 0.02:
				_k = k
				for pair: Array in _texts:
					(pair[0] as Label).add_theme_font_size_override("font_size", _px(int(pair[1])))).call()


## A font size that shows at least 12 px on screen however far the panel is
## shrunk (the plot initials inside cells are drawn apart, at their own size).
func _px(size: int) -> int:
	var want := maxf(size * _k, 12.0)
	return roundi(want / maxf(_k, 0.05))


## Plateau depth shown (grid rows plus a margin) and the canyon gap.
static func _depth() -> float:
	return Buildable.LIP_MARGIN + Buildable.ROWS * WorldLayout.CELL + 4.0


## Works out the scale and framing: the canyon keeps its fixed strip; the
## bigger maps fit every plateau and the airship into about 900 x 640 pixels.
func _fit() -> void:
	var m := WorldLayout.map()
	if m.is_canyon():
		_scale = SCALE
		_origin = Vector2(-(WorldLayout.HALF_GAP + _depth()), Z_MIN)
		_size = Vector2((WorldLayout.HALF_GAP + _depth()) * 2.0 * SCALE + PAD * 2.0, (Z_MAX - Z_MIN) * SCALE + PAD * 2.0)
		return
	var half_w := WorldLayout.PLATEAU_WIDTH * 0.5
	var box := Rect2(Vector2(m.airship_ring.x, m.airship_ring.z), Vector2.ZERO)
	for cid in m.count():
		for corner: Vector2 in [Vector2(0, -half_w), Vector2(0, half_w), Vector2(_depth(), -half_w), Vector2(_depth(), half_w)]:
			var w := WorldLayout.plateau_to_world(cid, corner.x, corner.y, 0.0)
			box = box.expand(Vector2(w.x, w.z))
	box = box.grow(16.0)
	_scale = minf(900.0 / box.size.x, 640.0 / box.size.y)
	_origin = box.position
	_size = box.size * _scale + Vector2(PAD, PAD) * 2.0


func _map_size() -> Vector2:
	return _size


## Map position for a world point (x, z); the bigger maps put north (-z) at the top.
func _to_map(x: float, z: float) -> Vector2:
	return Vector2(PAD + (x - _origin.x) * _scale, PAD + (z - _origin.y) * _scale)


## Map position of a plateau point (d back from the lip, z along it).
func _plateau_map(cid: int, d: float, z: float) -> Vector2:
	var w := WorldLayout.plateau_to_world(cid, d, z, 0.0)
	return _to_map(w.x, w.z)


static func cliff_name(cid: int) -> String:
	return WorldLayout.map().name_of(cid)


static func owner_of(cid: int) -> String:
	var names: Array[String] = []
	for id: int in NetworkManager.players:
		if NetworkManager.cliff_of(id) == cid:
			names.append(str((NetworkManager.players[id] as Dictionary)["name"]))
	for c: Node in Engine.get_main_loop().get_nodes_in_group("cpu_teammates"):
		if int(c.get("cliff_id")) == cid:
			names.append(str(c.get("display_name")))
	if names.is_empty():
		return "you" if GameState.is_solo() and MapDef.players_of(NetworkManager.map_id) <= 2 else "open"
	return ", ".join(names)


func _draw_map() -> void:
	var c := _canvas
	var font := get_theme_default_font()
	var size := _map_size()
	var m := WorldLayout.map()
	if m.is_canyon():
		# Canyon floor between the lips.
		var a := _to_map(-WorldLayout.HALF_GAP, Z_MIN)
		var b := _to_map(WorldLayout.HALF_GAP, Z_MAX)
		c.draw_rect(Rect2(a, b - a), Color(Palette.OUTLINE, 0.45))
		_center_text(c, font, "Canyon", (a + b) * 0.5, 13, Palette.BONE.darkened(0.3))
	else:
		# The basin or lake: everything inside the lips.
		var ctr := _to_map(m.center.x, m.center.z)
		var rim := PackedVector2Array()
		for cid in m.count():
			for k in 9:
				var z := lerpf(-m.span_v, m.span_v, float(k) / 8.0)
				rim.append(_plateau_map(cid, 0.0, z))
		var hull := Geometry2D.convex_hull(rim)
		c.draw_colored_polygon(hull, Color(Palette.OUTLINE, 0.45))
		_center_text(c, font, "Dry Lake" if m.id == MapDef.BUTTES else "Basin", ctr + Vector2(0, 26), 13, Palette.BONE.darkened(0.3))
		for i in m.tunnel_count():
			var t: Array = m.tunnels[i]
			var tp: Vector3 = t[0]
			c.draw_circle(_to_map(tp.x, tp.z), 3.0, Color("#160C0A"))
	for cid in m.count():
		_draw_cliff(c, font, cid)
	_draw_bugs(c)
	_draw_airship(c, font)
	_draw_pings(c, font)
	_draw_players(c, font)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.OUTLINE, 0.9), false, 2.0)


## Bugs climbing each wall as red ticks along its lip (longer = higher up), and
## bugs on a plateau as red dots: where the pressure is at a glance.
func _draw_bugs(c: Control) -> void:
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive():
			continue
		var z := b.global_position.z
		var at := _to_map(b.global_position.x, z)
		if at.x < 0.0 or at.y < 0.0 or at.x > _size.x or at.y > _size.y:
			continue
		match b.state:
			Bug.State.CLIMBING:
				var lip := _plateau_map(b.cliff_id, 0.0, b.lane_z)
				var inw := WorldLayout.inward(b.cliff_id)
				var tick := 3.0 + 14.0 * clampf(b.climb_y / WorldLayout.CLIFF_HEIGHT, 0.0, 1.0)
				c.draw_line(lip, lip + Vector2(inw.x, inw.z) * tick, Color(Palette.TEAM_WEST.lightened(0.15), 0.95), 3.0)
			Bug.State.CRESTING, Bug.State.BREACHING:
				c.draw_circle(_to_map(b.global_position.x, z), 3.5, Palette.TEAM_WEST.lightened(0.2))
			Bug.State.CROSSING, Bug.State.FLYING:
				c.draw_circle(_to_map(b.global_position.x, z), 2.0, Color(Palette.TEAM_WEST, 0.6))


## Live pings, so a call-out made in the world shows up on the map too.
func _draw_pings(c: Control, font: Font) -> void:
	if Pings.instance == null:
		return
	for p: Dictionary in Pings.instance.get("_active"):
		var k: Dictionary = Pings.KINDS[int(p["kind"])]
		var pos: Vector3 = p["pos"]
		var mp := _to_map(pos.x, pos.z)
		c.draw_circle(mp, 8.0, Palette.OUTLINE)
		c.draw_circle(mp, 6.5, k["color"])
		_center_text(c, font, "%s: %s" % [p["who"], k["label"]], mp + Vector2(0, -16), 11, Palette.BONE)


func _draw_cliff(c: Control, font: Font, cid: int) -> void:
	var m := WorldLayout.map()
	var half_w := WorldLayout.PLATEAU_WIDTH * 0.5
	# The plateau: along the lip (it bends on a butte's prow), then back along the rear.
	var outline := PackedVector2Array()
	for k in 21:
		outline.append(_plateau_map(cid, 0.0, lerpf(-half_w, half_w, float(k) / 20.0)))
	for k in 21:
		outline.append(_plateau_map(cid, _depth(), lerpf(half_w, -half_w, float(k) / 20.0)))
	var rect := Rect2(outline[0], Vector2.ZERO)
	for q in outline:
		rect = rect.expand(q)
	c.draw_colored_polygon(outline, Color(Palette.SAND, 0.85))
	var closed := outline.duplicate()
	closed.append(outline[0])
	c.draw_polyline(closed, Palette.OUTLINE, 2.0)
	# Grid cells (bigger maps: the lip row tinted by the cliff each spot covers).
	for row in Buildable.ROWS:
		for col in Buildable.COLS:
			var cell := Vector2i(row, col)
			var house := Buildable.house_cells().has_point(cell)
			var fill := Color(Palette.WOOD_DARK, 0.55) if house else Color(Palette.OUTLINE, 0.08)
			if not house and row == 0 and not m.is_canyon():
				fill = Color(Palette.team_color(m.covered_cliff(cid, col)), 0.45)
			c.draw_colored_polygon(_cell_poly(cid, cell, 0.5), fill)
	var hc := Buildable.house_cells()
	var hcenter := _poly_center(_cell_poly(cid, hc.position, 0.0) + _cell_poly(cid, hc.position + hc.size - Vector2i.ONE, 0.0))
	_center_text(c, font, "House", hcenter, 12, UiStyle.c("hud"))
	# Built things.
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		if int(n.get("cliff_id")) != cid or n.get("cell") == null:
			continue
		var cell: Vector2i = n.get("cell")
		if cell.x < 0:
			continue
		var def: TurretDef = n.get("def")
		var poly := _cell_poly(cid, cell, 1.0)
		var col := _turret_colour(def)
		c.draw_colored_polygon(poly, col)
		var ring := poly.duplicate()
		ring.append(poly[0])
		c.draw_polyline(ring, Palette.OUTLINE, 1.5)
		var ini := _initials(def.display_name if def != null else "?")
		var tw := font.get_string_size(ini, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		c.draw_string(font, _poly_center(poly) + Vector2(-tw * 0.5, 3.5), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.OUTLINE)
	for n: Node in get_tree().get_nodes_in_group("crops"):
		if int(n.get("cliff_id")) != cid:
			continue
		var mp := _world_to_map(cid, (n as Node3D).global_position)
		c.draw_rect(Rect2(mp - Vector2(5, 5), Vector2(10, 10)), Color("#7BC96F"))
	# Name plate: "West Cliff (Logan)", out past the back of the plateau.
	var label := "%s (%s)" % [cliff_name(cid), owner_of(cid)]
	var mine := player != null and player.cliff_id == cid
	var at := Vector2(rect.get_center().x, rect.position.y - 12.0)
	var below := Vector2(rect.get_center().x, rect.end.y + 14.0)
	if not m.is_canyon():
		# Bigger maps: the name sits just behind the plateau, away from the middle.
		at = _plateau_map(cid, _depth() + 9.0, 0.0)
		below = _plateau_map(cid, _depth() - 4.0, 0.0)
	_center_text(c, font, label, at, 16, Palette.GLOW_YELLOW if mine else Palette.BONE)
	if mine:
		_center_text(c, font, "You Are Here", below, 12, Palette.GLOW_YELLOW)


## A grid cell's corners on the map, pulled `inset` pixels in from its edges.
func _cell_poly(cid: int, cell: Vector2i, inset: float) -> PackedVector2Array:
	var d0 := Buildable.LIP_MARGIN + float(cell.x) * WorldLayout.CELL
	var z0 := -WorldLayout.PLATEAU_WIDTH * 0.5 + float(cell.y) * WorldLayout.CELL
	var pts := PackedVector2Array([_plateau_map(cid, d0, z0), _plateau_map(cid, d0, z0 + WorldLayout.CELL),
			_plateau_map(cid, d0 + WorldLayout.CELL, z0 + WorldLayout.CELL), _plateau_map(cid, d0 + WorldLayout.CELL, z0)])
	if inset > 0.0:
		var ctr := _poly_center(pts)
		for i in pts.size():
			pts[i] = pts[i] + (ctr - pts[i]).normalized() * inset
	return pts


static func _poly_center(pts: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for q in pts:
		sum += q
	return sum / maxf(float(pts.size()), 1.0)


func _world_to_map(_cid: int, pos: Vector3) -> Vector2:
	return _to_map(pos.x, pos.z)


func _draw_airship(c: Control, font: Font) -> void:
	var ship := get_tree().current_scene.get_node_or_null("Airship") as Node3D
	if ship == null:
		return
	var mp := _to_map(ship.global_position.x, ship.global_position.z)
	var w := AirshipBuilder.DECK_W * SCALE
	var l := AirshipBuilder.DECK_L * SCALE
	var r := Rect2(mp - Vector2(w, l) * 0.5, Vector2(w, l))
	c.draw_rect(r, Color(Palette.TEAM_WEST, 0.35))
	c.draw_rect(r, Palette.TEAM_WEST.lightened(0.2), false, 2.0)
	_center_text(c, font, "Airship", mp + Vector2(0, -6), 14, Palette.BONE)
	_center_text(c, font, "Market · Casino", mp + Vector2(0, 10), 11, Palette.BONE.darkened(0.2))


func _draw_players(c: Control, font: Font) -> void:
	var people: Array = get_tree().get_nodes_in_group("players")
	people.append_array(get_tree().get_nodes_in_group("cpu_teammates"))
	for n: Node in people:
		var p := n as Node3D
		var mp := _to_map(p.global_position.x, p.global_position.z)
		var me := n == player
		c.draw_circle(mp, 6.0 if me else 5.0, Palette.OUTLINE)
		c.draw_circle(mp, 4.5 if me else 3.5, Palette.GLOW_YELLOW if me else Palette.BONE)
		if not me:
			var who := str(n.get("display_name")) if n.is_in_group("cpu_teammates") else _peer_name(n)
			_center_text(c, font, who, mp + Vector2(0, -12), 11, Palette.BONE)
			# Theme: the rider's brand mark above their name.
			BrandMark.paint_at(c, Brand.mark_of(Brand.CPU_KEY if n.is_in_group("cpu_teammates") else int(str(n.name)) if str(n.name).is_valid_int() else -1),
					mp + Vector2(0, -30), 14.0, Palette.BONE)


static func _peer_name(n: Node) -> String:
	var id := int(str(n.name)) if str(n.name).is_valid_int() else -1
	if NetworkManager.players.has(id):
		return str((NetworkManager.players[id] as Dictionary)["name"])
	return "Partner"


static func _turret_colour(def: TurretDef) -> Color:
	if def == null:
		return Palette.BONE
	if def.anti_air:
		return Color("#6FA8DC")
	if def.guards_plateau or def.guards_house:
		return Color("#E0533A")
	return Color("#F2C14E")


static func _initials(n: String) -> String:
	var out := ""
	for w: String in n.split(" ", false):
		out += w.substr(0, 1)
	return out.substr(0, 2).to_upper()


func _center_text(c: Control, font: Font, s: String, at: Vector2, size: int, col: Color) -> void:
	size = _px(size)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w * 0.5, size * 0.35)
	c.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Palette.OUTLINE)
	c.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _legend() -> HFlowContainer:
	var h := HFlowContainer.new() # wraps under the map instead of widening the panel
	h.alignment = FlowContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("h_separation", 16)
	h.add_theme_constant_override("v_separation", 4)
	for item: Array in [[Color("#F2C14E"), "Cliff Turret"], [Color("#6FA8DC"), "Air Defence"], [Color("#E0533A"), "Last Resort"],
			[Color("#7BC96F"), "Crops"], [Palette.TEAM_WEST, "Bugs (Ticks = Climbing)"], [Palette.GLOW_YELLOW, "You"]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(UiStyle.swatch(item[0], 14))
		var l := KeyHints.text(str(item[1]), 14, UiStyle.c("hud"))
		_texts.append([l, 14])
		cell.add_child(l)
		h.add_child(cell)
	return h
