class_name HudOverviewMap
extends Control
## The overview map (M): a top-down plan of the map (any map, north up on the
## bigger ones; MapDef frames place each cliff). Each cliff is labelled
## by name with its owner in (brackets), every turret and structure sits on its
## grid cell, and the airship shows where it hangs. Hold-free: press M to open,
## M or Esc to close. Refreshes twice a second while open.
## Drawn as a stylised topographic survey sheet of the ground actually being
## played on (see "the survey" below): shaded, tinted relief with contours and
## hachured cliffs, a ruled border with grid references, a compass rose and a
## scale bar, with the claims, builds, bugs and riders inked over it.

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

# ------------------------------------------------------------------ the survey
# The map is a stylised topographic sheet of the real ground: a heightfield is
# surveyed once per world by raycasting straight down onto the terrain (a few
# thousand rays per physics tick, inside a small time budget, starting a few
# seconds after the world loads), stored in a small float texture, and drawn by
# a shader as tinted relief with hillshade, hachured cliff faces and contour
# lines. Nothing re-runs while the map is shut.
const SURVEY_SAMPLES := 100000 ## heightfield size cap (samples: about 0.8 m apart on the big maps)
const SURVEY_BUDGET_US := 2500 ## per physics tick
const SURVEY_DELAY := 3.0 ## seconds after the world is up
const CONTOUR_M := 3.0 ## contour interval (metres); every 5th is an index contour
## Cartographic inks on the survey paper.
const MAP_INK := Color("#2E1B0E")
const MAP_PAPER := Color("#EADCBC")
const MAP_RED := Color("#A3301D")
var _relief: TextureRect
var _heights := PackedFloat32Array()
## 1 where a natural arch spans over the ground (drawn as a bridge, not as ground).
var _arches := PackedFloat32Array()
var _arch_hit := false
var _nx := 0
var _nz := 0
var _survey_i := 0
var _survey_wait := SURVEY_DELAY
var _surveyed := false
var _ray: PhysicsRayQueryParameters3D
var _terrain: Node
static var _topo_shader: Shader


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20 # above the in-world ping and alert markers
	visible = false
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", KeyHints.kit_box("solid")) # the HUD kit's plate, nearly opaque
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_fit()
	var title := KeyHints.text("Canyon Map" if WorldLayout.map().is_canyon() else UiStyle.tc(WorldLayout.map().display_name), 24, UiStyle.c("title"))
	title.theme_type_variation = "HeaderTitle"
	title.remove_theme_color_override("font_color")
	title.uppercase = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(UiStyle.divider(360))
	_texts.append([title, 24])
	# The survey sheet: the shaded relief (baked from the real terrain, drawn by a
	# shader) under the canvas that draws the cliffs, builds, bugs and people.
	var stage := Control.new()
	stage.custom_minimum_size = _map_size()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stage)
	_relief = TextureRect.new()
	_relief.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_relief.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_relief.stretch_mode = TextureRect.STRETCH_SCALE
	_relief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relief.material = _topo_material()
	_relief.visible = false
	stage.add_child(_relief)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	stage.add_child(_canvas)
	_survey_setup()
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
		# Canyon Expeditions: stretch down the canyon to take in the raid sites
		# (the scale shrinks to keep the map on screen).
		var z0 := Z_MIN
		var z1 := Z_MAX
		if SiteManager.instance != null:
			for s: SitePlan.Site in SiteManager.instance.sites:
				z0 = minf(z0, s.pos.z - 8.0)
				z1 = maxf(z1, s.pos.z + 8.0)
		_scale = minf(SCALE, 700.0 / (z1 - z0))
		_origin = Vector2(-(WorldLayout.HALF_GAP + _depth()), z0)
		_size = Vector2((WorldLayout.HALF_GAP + _depth()) * 2.0 * _scale + PAD * 2.0, (z1 - z0) * _scale + PAD * 2.0)
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
	if not _surveyed:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(MAP_PAPER.darkened(0.55), 0.85)) # (the survey is still out)
	if m.is_canyon():
		# Canyon floor between the lips (the relief shows it once surveyed).
		var a := _to_map(-WorldLayout.HALF_GAP, _origin.y)
		var b := _to_map(WorldLayout.HALF_GAP, _origin.y + (_size.y - PAD * 2.0) / _scale)
		if not _surveyed:
			c.draw_rect(Rect2(a, b - a), Color(Palette.OUTLINE, 0.45))
		_center_text(c, font, "Canyon Floor" if _surveyed else "Canyon", (a + b) * 0.5, 13, Palette.BONE.darkened(0.3), true)
		for i in WorldLayout.TUNNELS.size():
			var tm: Vector3 = Bug.cliffs.tunnel(i)[0] if Bug.cliffs != null else Vector3.ZERO
			_tunnel_mark(c, _to_map(tm.x, tm.z))
	else:
		# The basin or lake: everything inside the lips.
		var ctr := _to_map(m.center.x, m.center.z)
		var rim := PackedVector2Array()
		for cid in m.count():
			for k in 9:
				var z := lerpf(-m.span_v, m.span_v, float(k) / 8.0)
				rim.append(_plateau_map(cid, 0.0, z))
		var hull := Geometry2D.convex_hull(rim)
		if not _surveyed:
			c.draw_colored_polygon(hull, Color(Palette.OUTLINE, 0.45))
		_center_text(c, font, "Dry Lake" if m.id == MapDef.BUTTES else "Basin", ctr + Vector2(0, 26), 13, Palette.BONE.darkened(0.3), true)
		for i in m.tunnel_count():
			var t: Array = m.tunnels[i]
			var tp: Vector3 = t[0]
			_tunnel_mark(c, _to_map(tp.x, tp.z))
	for cid in m.count():
		_draw_cliff(c, font, cid)
	_draw_sites(c, font)
	_draw_bugs(c)
	_draw_airship(c, font)
	_draw_pings(c, font)
	_draw_players(c, font)
	if _surveyed:
		_draw_sheet(c, font, size)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.OUTLINE, 0.9), false, 2.0)
		_center_text(c, font, "Surveying the ground...", size * 0.5 + Vector2(0, -size.y * 0.42), 14, Palette.BONE)


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
			Bug.State.CROSSING, Bug.State.FLYING, Bug.State.HUNTING:
				c.draw_circle(_to_map(b.global_position.x, z), 2.0, Color(Palette.TEAM_WEST, 0.6))


## Canyon Expeditions: each raid site on the floor as a ringed marker in its
## colour with its initial and name, dimmed once it's picked clean.
func _draw_sites(c: Control, font: Font) -> void:
	var mgr := SiteManager.instance
	if mgr == null:
		return
	for s: SitePlan.Site in mgr.sites:
		var at := _to_map(s.pos.x, s.pos.z)
		var col: Color = SitePlan.COLORS[s.kind]
		var empty := mgr.loot_left(s.index) == 0
		if empty:
			col = Color(col.darkened(0.4), 0.7)
		c.draw_circle(at, 11.0, Palette.OUTLINE)
		c.draw_circle(at, 9.0, col)
		c.draw_arc(at, 13.5, 0.0, TAU, 24, Color(col, 0.6), 2.0)
		_center_text(c, font, s.display_name().substr(0, 1), at, 12, Palette.OUTLINE)
		var label := s.display_name() + (" (Picked Clean)" if empty else "")
		_center_text(c, font, label, at + Vector2(0, -20), 11, Palette.BONE)


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
	var closed := outline.duplicate()
	closed.append(outline[0])
	if _surveyed:
		# The homestead claim: a dashed boundary over the surveyed ground.
		c.draw_colored_polygon(outline, Color(MAP_PAPER, 0.12))
		for i in closed.size() - 1:
			c.draw_dashed_line(closed[i], closed[i + 1], Color(MAP_RED, 0.9), 2.0, 7.0, true)
	else:
		c.draw_colored_polygon(outline, Color(Palette.SAND, 0.85))
		c.draw_polyline(closed, Palette.OUTLINE, 2.0)
	# Grid cells (bigger maps: the lip row tinted by the cliff each spot covers).
	for row in Buildable.ROWS:
		for col in Buildable.COLS:
			var cell := Vector2i(row, col)
			var house := Buildable.house_cells().has_point(cell)
			var fill := Color(Palette.WOOD_DARK, 0.55) if house else Color(Palette.OUTLINE, 0.08)
			if _surveyed:
				fill = Color(MAP_INK, 0.55) if house else Color(MAP_INK, 0.05)
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
	_center_text(c, UiStyle.font("bold") if _surveyed else font, label, at, 17 if _surveyed else 16, Palette.GLOW_YELLOW if mine else Palette.BONE)
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
	if _surveyed:
		# On the survey: the gasbag's outline in ink over the ground, deck dashed.
		var hull := PackedVector2Array()
		var rad := r.size.x * 0.5
		for k in 13:
			hull.append(Vector2(r.get_center().x, r.position.y + rad) + Vector2.from_angle(PI + PI * k / 12.0) * rad)
		for k in 13:
			hull.append(Vector2(r.get_center().x, r.end.y - rad) + Vector2.from_angle(PI * k / 12.0) * rad)
		c.draw_colored_polygon(hull, Color(MAP_PAPER, 0.45))
		var ring := hull.duplicate()
		ring.append(hull[0])
		c.draw_polyline(ring, MAP_INK, 2.0, true)
		c.draw_line(Vector2(r.get_center().x, r.position.y + 6), Vector2(r.get_center().x, r.end.y - 6), Color(MAP_INK, 0.35), 1.0)
	else:
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
		c.draw_circle(mp, 4.5 if me else 3.5, (MAP_RED if _surveyed else Palette.GLOW_YELLOW) if me else Palette.BONE)
		if me and _surveyed:
			c.draw_arc(mp, 10.0, 0.0, TAU, 24, MAP_RED, 2.0, true)
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


func _center_text(c: Control, font: Font, s: String, at: Vector2, size: int, col: Color, faint: bool = false) -> void:
	size = _px(size)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w * 0.5, size * 0.35)
	if _surveyed:
		# Keep every label on the sheet (names behind a plateau can run off its edge).
		p.x = clampf(p.x, 10.0, maxf(c.size.x - w - 10.0, 10.0))
		# Cartographic lettering: ink (or the red of "you") with a paper halo;
		# place names over the ground in spaced capitals.
		var ink := MAP_RED if col == Palette.GLOW_YELLOW else (Color(MAP_INK, 0.62) if faint else MAP_INK)
		if faint:
			s = s.to_upper()
			w = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			p = at + Vector2(-w * 0.5, size * 0.35)
			p.x = clampf(p.x, 10.0, maxf(c.size.x - w - 10.0, 10.0))
		c.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(MAP_PAPER, 0.85))
		c.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
		return
	c.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Palette.OUTLINE)
	c.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _legend() -> HFlowContainer:
	var h := HFlowContainer.new() # wraps under the map instead of widening the panel
	h.alignment = FlowContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("h_separation", 16)
	h.add_theme_constant_override("v_separation", 4)
	for item: Array in [[Color("#F2C14E"), "Cliff Turret"], [Color("#6FA8DC"), "Air Defence"], [Color("#E0533A"), "Last Resort"],
			[Color("#7BC96F"), "Crops"], [Palette.TEAM_WEST, "Bugs (Ticks = Climbing)"], [SitePlan.COLORS[SitePlan.Kind.BONEYARD], "Raid Site"],
			[Palette.GLOW_YELLOW, "You"]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.add_child(UiStyle.swatch(item[0], 14))
		var l := KeyHints.ink(str(item[1]), 14)
		_texts.append([l, 14])
		cell.add_child(l)
		h.add_child(cell)
	return h


# ------------------------------------------------------------------ survey

## Sizes the heightfield: one sample per ~0.6 m on the canyon, coarser on the
## big maps so the whole sheet stays under SURVEY_SAMPLES.
func _survey_setup() -> void:
	var span := _size / _scale # metres the canvas covers (padding included)
	var step := maxf(0.6, sqrt(span.x * span.y / float(SURVEY_SAMPLES)))
	_nx = maxi(int(ceil(span.x / step)), 8)
	_nz = maxi(int(ceil(span.y / step)), 8)
	_heights.resize(_nx * _nz)
	_heights.fill(0.0)
	_arches.resize(_nx * _nz)
	_arches.fill(0.0)
	_ray = PhysicsRayQueryParameters3D.new()
	_ray.collision_mask = WorldLayout.LAYER_WORLD
	_ray.hit_back_faces = false


## World (x, z) under a canvas pixel.
func _canvas_world(p: Vector2) -> Vector2:
	return Vector2(_origin.x + (p.x - PAD) / _scale, _origin.y + (p.y - PAD) / _scale)


func _physics_process(delta: float) -> void:
	if _surveyed:
		return
	if _survey_wait > 0.0:
		_survey_wait -= delta
		return
	var scene := get_tree().current_scene
	_terrain = scene.get_node_or_null("Terrain") if scene != null else null
	var world := get_viewport().get_world_3d() if get_viewport() != null else null
	if _terrain == null or world == null:
		return
	var space := world.direct_space_state
	var t0 := Time.get_ticks_usec()
	var total := _nx * _nz
	while _survey_i < total and Time.get_ticks_usec() - t0 < SURVEY_BUDGET_US:
		var ix := _survey_i % _nx
		var iz := _survey_i / _nx
		var w := _canvas_world(Vector2((ix + 0.5) / _nx * _size.x, (iz + 0.5) / _nz * _size.y))
		_arch_hit = false
		_heights[_survey_i] = _ground_at(space, w)
		_arches[_survey_i] = 1.0 if _arch_hit else 0.0
		_survey_i += 1
	if _survey_i >= total:
		_finish_survey()


## The terrain's height at (x, z): the first downward hit on the world layer
## that belongs to the canyon itself (props and buildings are looked through).
func _ground_at(space: PhysicsDirectSpaceState3D, w: Vector2) -> float:
	var top := 400.0
	for attempt in 4:
		_ray.from = Vector3(w.x, top, w.y)
		_ray.to = Vector3(w.x, -200.0, w.y)
		var hit := space.intersect_ray(_ray)
		if hit.is_empty():
			return -INF
		var col := hit["collider"] as Node
		var y: float = (hit["position"] as Vector3).y
		if col != null and col.name == &"Arches":
			_arch_hit = true # (seen through: the ground under the arch is what's mapped)
		elif col != null and _terrain.is_ancestor_of(col):
			return y
		top = y - 0.05
	return -INF


func _finish_survey() -> void:
	_surveyed = true
	var lo := INF
	var hi := -INF
	for h in _heights:
		if h > -1e6:
			lo = minf(lo, h)
			hi = maxf(hi, h)
	if lo == INF:
		return # nothing to survey (no terrain): keep the flat plan
	for i in _heights.size():
		if _heights[i] < -1e6:
			_heights[i] = lo # no ground found: read as the lowest ground
	var both := PackedFloat32Array()
	both.resize(_nx * _nz * 2)
	for i in _heights.size():
		both[i * 2] = _heights[i]
		both[i * 2 + 1] = _arches[i]
	var img := Image.create_from_data(_nx, _nz, false, Image.FORMAT_RGF, both.to_byte_array())
	var mat := _relief.material as ShaderMaterial
	var tex := ImageTexture.create_from_image(img)
	mat.set_shader_parameter("heights", tex)
	_relief.texture = tex # (a TextureRect only runs its shader over a texture it draws)
	mat.set_shader_parameter("texel", Vector2(1.0 / _nx, 1.0 / _nz))
	mat.set_shader_parameter("metres", Vector2(_size.x / _scale / _nx, _size.y / _scale / _nz))
	mat.set_shader_parameter("h_lo", lo)
	mat.set_shader_parameter("h_hi", maxf(hi, lo + 1.0))
	mat.set_shader_parameter("step_m", CONTOUR_M)
	_relief.visible = true
	_heights = PackedFloat32Array() # (the texture keeps its own copy)
	_arches = PackedFloat32Array()
	set_physics_process(false)
	if visible:
		_canvas.queue_redraw()


## The relief shader: elevation tint (rust canyon floor up to pale sand rims),
## a north-west hillshade, banded strata and diagonal hachures on steep walls,
## anti-aliased contours with heavier index contours, on survey paper.
static func _topo_material() -> ShaderMaterial:
	if _topo_shader == null:
		_topo_shader = Shader.new()
		_topo_shader.code = """
shader_type canvas_item;
uniform sampler2D heights : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.01);
uniform vec2 metres = vec2(1.0);
uniform float h_lo = 0.0;
uniform float h_hi = 60.0;
uniform float step_m = 3.0;
uniform vec4 paper : source_color = vec4(0.918, 0.863, 0.737, 1.0);
uniform vec4 low : source_color = vec4(0.55, 0.27, 0.16, 1.0);
uniform vec4 mid : source_color = vec4(0.78, 0.50, 0.31, 1.0);
uniform vec4 high : source_color = vec4(0.94, 0.86, 0.66, 1.0);
uniform vec4 ink : source_color = vec4(0.18, 0.106, 0.055, 1.0);

float hgt(vec2 uv) { return texture(heights, uv).r; }

void fragment() {
	vec2 uv = UV;
	float h = hgt(uv);
	float hx = (hgt(uv + vec2(texel.x, 0.0)) - hgt(uv - vec2(texel.x, 0.0))) / (2.0 * metres.x);
	float hz = (hgt(uv + vec2(0.0, texel.y)) - hgt(uv - vec2(0.0, texel.y))) / (2.0 * metres.y);
	vec3 n = normalize(vec3(-hx, 1.0, -hz));
	float shade = clamp(dot(n, normalize(vec3(-0.55, 0.85, -0.6))), 0.0, 1.0);
	float slope = length(vec2(hx, hz));
	float t = clamp((h - h_lo) / max(h_hi - h_lo, 1.0), 0.0, 1.0);
	vec3 col = t < 0.5 ? mix(low.rgb, mid.rgb, t * 2.0) : mix(mid.rgb, high.rgb, (t - 0.5) * 2.0);
	// Strata: alternating bands down the walls, like the canyon's rock.
	float band = step(0.5, fract(h / 7.0));
	float wall = smoothstep(0.5, 1.6, slope);
	col *= mix(1.0, 0.9 + 0.12 * band, wall);
	col = mix(col, paper.rgb, 0.22);
	col *= 0.5 + 0.62 * shade;
	// Hachures on the steep faces (screen-space diagonal strokes).
	float hatch = smoothstep(0.35, 0.65, abs(fract((FRAGCOORD.x - FRAGCOORD.y) * 0.16) - 0.5) * 2.0);
	col = mix(col, ink.rgb, wall * hatch * 0.28);
	// Contours, anti-aliased; they fade where they pile up on a cliff face.
	float c = h / step_m;
	float fw = max(fwidth(c), 1e-4);
	float d = abs(fract(c - 0.5) - 0.5) / fw;
	float line = (1.0 - smoothstep(0.4, 1.3, d)) * (1.0 - smoothstep(0.3, 0.8, fw));
	float ci = h / (step_m * 5.0);
	float fwi = max(fwidth(ci), 1e-4);
	float di = abs(fract(ci - 0.5) - 0.5) / fwi;
	float iline = (1.0 - smoothstep(0.9, 2.0, di)) * (1.0 - smoothstep(0.25, 0.7, fwi));
	col = mix(col, ink.rgb, line * 0.42);
	col = mix(col, ink.rgb, iline * 0.72);
	// Natural arches: a pale stippled bridge with an inked edge over the ground.
	float arch = texture(heights, uv).g;
	float edge = clamp(fwidth(arch) * 3.0, 0.0, 1.0);
	float dash = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) * 0.09));
	col = mix(col, paper.rgb, smoothstep(0.35, 0.65, arch) * 0.16);
	col = mix(col, ink.rgb, edge * dash * 0.75);
	// Printed on paper: a soft vignette toward the sheet's edges.
	vec2 q = UV - 0.5;
	col *= 1.0 - dot(q, q) * 0.45;
	COLOR = vec4(col, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _topo_shader
	return mat


## A bug tunnel's mouth: a dark ring struck through, like a mine adit on a survey.
func _tunnel_mark(c: Control, at: Vector2) -> void:
	if not _surveyed:
		c.draw_circle(at, 3.0, Color("#160C0A"))
		return
	c.draw_circle(at, 5.0, Color(MAP_INK, 0.85), true, -1.0, true)
	c.draw_circle(at, 2.6, MAP_PAPER, true, -1.0, true)
	c.draw_line(at + Vector2(-7, -7), at + Vector2(7, 7), MAP_INK, 1.5, true)


## The sheet's furniture: a double ruled border with grid references along the
## edges, a compass rose, a scale bar and the contour note.
func _draw_sheet(c: Control, font: Font, size: Vector2) -> void:
	var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(MAP_INK, 0.9), false, 3.0)
	c.draw_rect(r, Color(MAP_INK, 0.75), false, 1.0)
	# Grid references: letters across, numbers down, every 20 m.
	var cell_m := 20.0
	var fs := _px(10)
	var x0 := _canvas_world(Vector2(0, 0))
	var x1 := _canvas_world(size)
	var i := 0
	var gx := ceilf(x0.x / cell_m) * cell_m
	while gx < x1.x:
		var px := PAD + (gx - _origin.x) * _scale
		c.draw_line(Vector2(px, 0), Vector2(px, 6), MAP_INK, 1.0)
		c.draw_line(Vector2(px, size.y - 6), Vector2(px, size.y), MAP_INK, 1.0)
		c.draw_line(Vector2(px, 6), Vector2(px, size.y - 6), Color(MAP_INK, 0.07), 1.0)
		c.draw_string(font, Vector2(px + 3, 17), String.chr(65 + (i % 26)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(MAP_INK, 0.7))
		gx += cell_m
		i += 1
	var j := 1
	var gz := ceilf(x0.y / cell_m) * cell_m
	while gz < x1.y:
		var py := PAD + (gz - _origin.y) * _scale
		c.draw_line(Vector2(0, py), Vector2(6, py), MAP_INK, 1.0)
		c.draw_line(Vector2(size.x - 6, py), Vector2(size.x, py), MAP_INK, 1.0)
		c.draw_line(Vector2(6, py), Vector2(size.x - 6, py), Color(MAP_INK, 0.07), 1.0)
		c.draw_string(font, Vector2(9, py - 3), str(j), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(MAP_INK, 0.7))
		gz += cell_m
		j += 1
	# Compass rose, top right (north is up the sheet: -z).
	var cr := Vector2(size.x - 46, 52)
	var rr := 24.0
	c.draw_circle(cr, rr + 6.0, Color(MAP_PAPER, 0.75), true, -1.0, true)
	c.draw_arc(cr, rr + 6.0, 0.0, TAU, 40, Color(MAP_INK, 0.8), 1.2, true)
	c.draw_arc(cr, rr - 2.0, 0.0, TAU, 40, Color(MAP_INK, 0.45), 1.0, true)
	for k in 8:
		var a := -PI / 2.0 + k * PI / 4.0
		var long := k % 2 == 0
		var tip := cr + Vector2.from_angle(a) * (rr if long else rr * 0.55)
		var side := Vector2.from_angle(a + PI / 2.0) * (5.0 if long else 3.5)
		var dark := MAP_RED if k == 0 else MAP_INK
		c.draw_colored_polygon(PackedVector2Array([cr, cr + side, tip]), dark)
		c.draw_colored_polygon(PackedVector2Array([cr, cr - side, tip]), Color(dark, 0.45))
	c.draw_circle(cr, 2.5, MAP_PAPER, true, -1.0, true)
	var nfs := _px(13)
	var nw := font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	c.draw_string_outline(font, cr + Vector2(-nw * 0.5, -rr - 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, 4, MAP_PAPER)
	c.draw_string(font, cr + Vector2(-nw * 0.5, -rr - 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, MAP_RED)
	# Scale bar, bottom left: 0 to 20 m in alternating ink and paper blocks.
	var sb := Vector2(22, size.y - 26)
	var seg := 5.0 * _scale
	for k in 4:
		var q := Rect2(sb + Vector2(seg * k, 0), Vector2(seg, 6))
		c.draw_rect(q, MAP_INK if k % 2 == 0 else MAP_PAPER)
		c.draw_rect(q, MAP_INK, false, 1.0)
	var sfs := _px(10)
	for k: int in [0, 2, 4]:
		var t := ("%d m" % (k * 5)) if k == 4 else str(k * 5)
		c.draw_string_outline(font, sb + Vector2(seg * k - 3, -4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, 3, Color(MAP_PAPER, 0.85))
		c.draw_string(font, sb + Vector2(seg * k - 3, -4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, MAP_INK)
	var note := "Contours every %d m" % int(CONTOUR_M)
	c.draw_string_outline(font, sb + Vector2(seg * 4 + 12, 7), note, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, 3, Color(MAP_PAPER, 0.85))
	c.draw_string(font, sb + Vector2(seg * 4 + 12, 7), note, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(MAP_INK, 0.8))
