class_name HudOverviewMap
extends Control
## The overview map (M): a top-down plan of the canyon. Each cliff is labelled
## by name with its owner in (brackets), every turret and structure sits on its
## grid cell, and the airship shows where it hangs. Hold-free: press M to open,
## M or Esc to close. Refreshes twice a second while open.

const SCALE := 8.0 # pixels per metre
## Along-canyon span shown (the airship hangs north of the plateaus).
const Z_MIN := -28.0
const Z_MAX := 62.0
const PAD := 28.0

var player: Player
var _panel: PanelContainer
var _canvas: Control
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20 # above the in-world ping and alert markers
	visible = false
	_panel = PanelContainer.new()
	var sb := KeyHints.card_style()
	sb.bg_color = Color(Palette.WOOD_DARK, 0.94)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	var title := KeyHints.text("CANYON MAP", 22, Palette.GLOW_YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
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
			_panel.offset_bottom = s.y * 0.5).call()


## Plateau depth shown (grid rows plus a margin) and the canyon gap.
static func _depth() -> float:
	return Buildable.LIP_MARGIN + Buildable.ROWS * WorldLayout.CELL + 4.0


static func _map_size() -> Vector2:
	var w := (WorldLayout.HALF_GAP + _depth()) * 2.0 * SCALE + PAD * 2.0
	var h := (Z_MAX - Z_MIN) * SCALE + PAD * 2.0
	return Vector2(w, h)


## Map position for a canyon-space point: x across the canyon, z along it.
static func _to_map(x: float, z: float) -> Vector2:
	var size := _map_size()
	return Vector2(size.x * 0.5 + x * SCALE, PAD + (z - Z_MIN) * SCALE)


## Unwarped canyon x of a grid row on a cliff.
static func _row_x(cid: int, d: float) -> float:
	return WorldLayout.side_sign(cid) * (WorldLayout.HALF_GAP + d)


static func cliff_name(cid: int) -> String:
	return "West Cliff" if cid == WorldLayout.WEST else "East Cliff"


static func owner_of(cid: int) -> String:
	var names: Array[String] = []
	for id: int in NetworkManager.players:
		if NetworkManager.cliff_of(id) == cid:
			names.append(str((NetworkManager.players[id] as Dictionary)["name"]))
	for c: Node in Engine.get_main_loop().get_nodes_in_group("cpu_teammates"):
		if int(c.get("cliff_id")) == cid:
			names.append(str(c.get("display_name")))
	if names.is_empty():
		return "empty" if not GameState.is_solo() else "you"
	return ", ".join(names)


func _draw_map() -> void:
	var c := _canvas
	var font := get_theme_default_font()
	var size := _map_size()
	# Canyon floor between the lips.
	var a := _to_map(-WorldLayout.HALF_GAP, Z_MIN)
	var b := _to_map(WorldLayout.HALF_GAP, Z_MAX)
	c.draw_rect(Rect2(a, b - a), Color(Palette.OUTLINE, 0.45))
	_center_text(c, font, "canyon", (a + b) * 0.5, 13, Palette.BONE.darkened(0.3))
	for cid in 2:
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
		if z < Z_MIN or z > Z_MAX:
			continue
		match b.state:
			Bug.State.CLIMBING:
				var lip := _to_map(_row_x(b.cliff_id, 0.0), z)
				var s := WorldLayout.side_sign(b.cliff_id)
				var len := 3.0 + 14.0 * clampf(b.climb_y / WorldLayout.CLIFF_HEIGHT, 0.0, 1.0)
				c.draw_line(lip, lip - Vector2(s * len, 0), Color(Palette.TEAM_WEST.lightened(0.15), 0.95), 3.0)
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
	var s := WorldLayout.side_sign(cid)
	var half_w := WorldLayout.PLATEAU_WIDTH * 0.5
	# The plateau.
	var p0 := _to_map(_row_x(cid, 0.0), -half_w)
	var p1 := _to_map(_row_x(cid, _depth()), half_w)
	var rect := Rect2(Vector2(minf(p0.x, p1.x), p0.y), Vector2(absf(p1.x - p0.x), p1.y - p0.y))
	c.draw_rect(rect, Color(Palette.SAND, 0.85))
	c.draw_rect(rect, Palette.OUTLINE, false, 2.0)
	# Grid cells.
	for row in Buildable.ROWS:
		for col in Buildable.COLS:
			var cell := Vector2i(row, col)
			var r := _cell_rect(cid, cell)
			var house := Buildable.house_cells().has_point(cell)
			c.draw_rect(r.grow(-0.5), Color(Palette.WOOD_DARK, 0.55) if house else Color(Palette.OUTLINE, 0.08))
	var hc := Buildable.house_cells()
	var hr := _cell_rect(cid, hc.position).merge(_cell_rect(cid, hc.position + hc.size - Vector2i.ONE))
	_center_text(c, font, "house", hr.get_center(), 12, Palette.BONE)
	# Built things.
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		if int(n.get("cliff_id")) != cid or n.get("cell") == null:
			continue
		var cell: Vector2i = n.get("cell")
		if cell.x < 0:
			continue
		var def: TurretDef = n.get("def")
		var r := _cell_rect(cid, cell).grow(-1.0)
		var col := _turret_colour(def)
		c.draw_rect(r, col)
		c.draw_rect(r, Palette.OUTLINE, false, 1.5)
		var ini := _initials(def.display_name if def != null else "?")
		var tw := font.get_string_size(ini, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		c.draw_string(font, r.get_center() + Vector2(-tw * 0.5, 3.5), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.OUTLINE)
	for n: Node in get_tree().get_nodes_in_group("crops"):
		if int(n.get("cliff_id")) != cid:
			continue
		var mp := _world_to_map(cid, (n as Node3D).global_position)
		c.draw_rect(Rect2(mp - Vector2(5, 5), Vector2(10, 10)), Color("#7BC96F"))
	# Name plate: "West Cliff (Logan)", out past the back of the plateau.
	var label := "%s (%s)" % [cliff_name(cid), owner_of(cid)]
	var mine := player != null and player.cliff_id == cid
	_center_text(c, font, label, Vector2(rect.get_center().x, rect.position.y - 12.0), 16,
			Palette.GLOW_YELLOW if mine else Palette.BONE)
	if mine:
		_center_text(c, font, "you are here", Vector2(rect.get_center().x, rect.end.y + 14.0), 12, Palette.GLOW_YELLOW)
	var _unused := s


func _cell_rect(cid: int, cell: Vector2i) -> Rect2:
	var d0 := Buildable.LIP_MARGIN + float(cell.x) * WorldLayout.CELL
	var z0 := -WorldLayout.PLATEAU_WIDTH * 0.5 + float(cell.y) * WorldLayout.CELL
	var a := _to_map(_row_x(cid, d0), z0)
	var b := _to_map(_row_x(cid, d0 + WorldLayout.CELL), z0 + WorldLayout.CELL)
	return Rect2(Vector2(minf(a.x, b.x), a.y), Vector2(absf(b.x - a.x), b.y - a.y))


func _world_to_map(cid: int, pos: Vector3) -> Vector2:
	var cliffs := (get_tree().current_scene.get("cliffs")) as CliffBuilder
	if cliffs == null:
		return _to_map(pos.x, pos.z)
	var pc := cliffs.plateau_coords(cid, pos)
	return _to_map(_row_x(cid, pc.x), pc.y)


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
	_center_text(c, font, "market · casino", mp + Vector2(0, 10), 11, Palette.BONE.darkened(0.2))


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
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w * 0.5, size * 0.35)
	c.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Palette.OUTLINE)
	c.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _legend() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	for item: Array in [[Color("#F2C14E"), "Cliff turret"], [Color("#6FA8DC"), "Air defence"], [Color("#E0533A"), "Last resort"],
			[Color("#7BC96F"), "Crops"], [Palette.TEAM_WEST, "Bugs (ticks = climbing)"], [Palette.GLOW_YELLOW, "You"]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		var sw := ColorRect.new()
		sw.color = item[0]
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(sw)
		cell.add_child(KeyHints.text(str(item[1]), 13, Palette.BONE))
		h.add_child(cell)
	return h
