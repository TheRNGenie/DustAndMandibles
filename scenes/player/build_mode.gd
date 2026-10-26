class_name BuildMode
extends Node3D
## Local player's build tool. B opens the build menu on the left of the screen
## (Farming / Cliff Turrets / Tactical / Last Resorts); pick a category, then an item
## (mouse, or number keys). The menu tucks away and a ghost snaps to the grid:
## green = OK, red = blocked or too expensive. Left click asks the host to build.
## B brings the menu back, the wheel cycles items in the category, right click leaves.
## X demolishes what you look at (50% refund, scaled by health). U upgrades a turret.

signal changed

const REACH := 40.0

var player: Player
var cliffs: CliffBuilder
var active := false
## The side menu is up (cursor free) rather than placing.
var menu_open := false
## Open category in the menu (-1 = category list).
var category := 1
var selected := 0
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _cell := Vector2i(-1, -1)
var _cliff := -1
var _ok := false
var _grid: MultiMeshInstance3D
var _grid_t := 0.0


func _ready() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost = MeshInstance3D.new()
	_ghost.material_override = _ghost_mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	_refresh_ghost_mesh()
	# Build-spot overlay: a tile on every cell you can use for the selected item.
	_grid = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mm.mesh = _tile_mesh()
	_grid.material_override = mat
	_grid.multimesh = mm
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.top_level = true
	_grid.visible = false
	add_child(_grid)


func selected_id() -> StringName:
	return Defs.BUILD_ORDER[selected]


func _unhandled_input(event: InputEvent) -> void:
	if GameState.menu_open or player.is_downed():
		return
	if event.is_action_pressed("build_menu"):
		if not active:
			_set_active(true)
			open_menu()
		elif menu_open:
			_set_active(false)
		else:
			open_menu()
	elif active and event.is_action_pressed("alt_fire"):
		_set_active(false)
		get_viewport().set_input_as_handled()
	elif active and event.is_action_pressed("fire"):
		if _ok and not menu_open:
			BuildManager.instance.build(selected_id(), _cliff, _cell)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("demolish"):
		_act_on_target(&"demolish")
	elif event.is_action_pressed("upgrade"):
		_act_on_target(&"upgrade")
	elif active and not menu_open and event.is_action_pressed("next_item"):
		_cycle(1)
	elif active and not menu_open and event.is_action_pressed("prev_item"):
		_cycle(-1)
	if active:
		for i in 9:
			if event.is_action_pressed("select_%d" % (i + 1)):
				_number_key(i)
				get_viewport().set_input_as_handled()


func category_items(c: int) -> Array:
	return Defs.BUILD_CATEGORIES[c]["items"] if c >= 0 else []


func open_menu() -> void:
	menu_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	changed.emit()


func close_menu() -> void:
	menu_open = false
	if not GameState.menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	changed.emit()


func show_category(c: int) -> void:
	category = c
	changed.emit()


## From the menu: build this item (closes the menu, shows the ghost).
func choose(id: StringName) -> void:
	for c in Defs.BUILD_CATEGORIES.size():
		if category_items(c).has(id):
			category = c
	_select(Defs.BUILD_ORDER.find(id))
	close_menu()


func _number_key(i: int) -> void:
	if menu_open and category < 0:
		if i < Defs.BUILD_CATEGORIES.size():
			show_category(i)
		return
	var items := category_items(category)
	if i < items.size():
		choose(items[i])


func _cycle(step: int) -> void:
	var items := category_items(category)
	if items.is_empty():
		return
	var i := items.find(selected_id())
	_select(Defs.BUILD_ORDER.find(items[(i + step + items.size()) % items.size()]))


func _select(i: int) -> void:
	selected = i
	_grid_t = 0.0
	_refresh_ghost_mesh()
	changed.emit()


func toggle() -> void:
	_set_active(not active)


func _set_active(on: bool) -> void:
	active = on
	if not on and menu_open:
		close_menu()
	_ghost.visible = on
	_grid.visible = on
	_grid_t = 0.0
	changed.emit()


func _process(delta: float) -> void:
	if not active:
		return
	_grid_t -= delta
	if _grid_t <= 0.0:
		_grid_t = 0.1
		_rebuild_grid()
	var hit := _aim_hit()
	_cell = Vector2i(-1, -1)
	_ok = false
	_ghost.visible = false
	if hit.is_empty():
		return
	var pos: Vector3 = hit["position"]
	_cliff = Buildable.cliff_at(pos)
	if _cliff < 0:
		return
	if Defs.is_house_turret(selected_id()):
		_aim_house_mount(pos)
		return
	_cell = Buildable.world_to_cell(cliffs, _cliff, pos)
	if selected_id() == &"farm_plot":
		# 2 x 2 plots: centre the footprint on where you aim.
		var pc := cliffs.plateau_coords(_cliff, pos)
		_cell = Buildable.cell_of(pc.x - WorldLayout.CELL * 0.5, pc.y - WorldLayout.CELL * 0.5)
	# Aiming at a built turret or scaffold: use its own cell (so scaffolding can go
	# over a turret, and turrets onto a scaffold, wherever on it you aim).
	var hit_node := hit["collider"] as Node
	if hit_node != null and hit_node.get_parent() == BuildManager.instance and hit_node.get("cell") != null:
		var hc: Vector2i = hit_node.get("cell")
		if hc.x >= 0 and int(hit_node.get("cliff_id")) == _cliff:
			_cell = hc
	if not Buildable.cell_ok_for(selected_id(), _cell):
		return
	_ghost.visible = true
	_ghost.global_position = Buildable.footprint_center(cliffs, _cliff, selected_id(), _cell)
	var bm0 := BuildManager.instance
	if Defs.is_turret(selected_id()) and Buildable.is_turret_cell(_cell):
		_ghost.global_position.y += ScaffoldNode.LEVEL_HEIGHT * maxi(bm0.free_turret_level(_cliff, _cell), 0)
	elif selected_id() == &"scaffold":
		_ghost.global_position.y += ScaffoldNode.LEVEL_HEIGHT * bm0.scaffold_levels(_cliff, _cell)
	_ghost.rotation.y = WorldLayout.facing_canyon_yaw(_cliff)
	var bm := BuildManager.instance
	var mine := bm.may_build(multiplayer.get_unique_id(), _cliff)
	var payer := _cliff if GameState.is_solo() else player.cliff_id
	var affordable := Economy.can_afford(payer, {&"scrap": Defs.cost_of(selected_id())})
	_ok = mine and bm.is_free_for(selected_id(), _cliff, _cell) and affordable
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.4, 0.45) if _ok else Color(1.0, 0.3, 0.25, 0.45)


## House turrets: snap to the nearest mount on the house you're aiming at.
func _aim_house_mount(pos: Vector3) -> void:
	var home := Homestead.of(_cliff)
	if home == null:
		return
	var best := -1
	var best_d := 6.0
	for i in home.mount_count():
		var d := home.mount_global(i).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	_cell = Vector2i(-1, best)
	_ghost.visible = true
	_ghost.global_position = home.mount_global(best)
	_ghost.rotation.y = WorldLayout.facing_canyon_yaw(_cliff)
	var bm := BuildManager.instance
	var payer := _cliff if GameState.is_solo() else player.cliff_id
	_ok = bm.may_build(multiplayer.get_unique_id(), _cliff) and bm.is_free_for(selected_id(), _cliff, _cell) 			and Economy.can_afford(payer, {&"scrap": Defs.cost_of(selected_id())})
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.4, 0.45) if _ok else Color(1.0, 0.3, 0.25, 0.45)


## The build bar text for the HUD: the selected item, its neighbours and why the ghost is red.
func status_text() -> String:
	if not active:
		return ""
	if menu_open:
		return ""
	var id := selected_id()
	var where := "open plots"
	if Buildable.TACTICAL.has(id):
		where = "tactical row or open plots"
	if id == &"scaffold" or (Defs.is_turret(id) and not Defs.turret(id).guards_plateau):
		where = "cliff-edge row"
	elif Defs.is_house_turret(id):
		where = "house mounts (porch, balcony, roof deck)"
	elif Defs.is_turret(id):
		where = "plateau"
	var line := "BUILDING  %s - %d scrap  (B: menu, wheel: next, right click: done)" % [Defs.name_of(id), Defs.cost_of(id)]
	if _cell != Vector2i(-1, -1) and not _ok and Buildable.cell_ok_for(id, _cell):
		if not BuildManager.instance.may_build(multiplayer.get_unique_id(), _cliff):
			line += "\nYou can only build on your own plateau. Your turrets cover your partner."
		elif not BuildManager.instance.is_free_for(id, _cliff, _cell):
			line += "\nThat spot is taken."
		else:
			line += "\nNot enough scrap."
	elif not _ghost.visible:
		line += "\nAim at the %s on your plateau." % where
	return line


static func _description(id: StringName) -> String:
	if Defs.is_turret(id):
		return Defs.turret(id).description
	return Defs.structure(id).description


func _aim_hit() -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE | WorldLayout.LAYER_TRAP)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _act_on_target(action: StringName) -> void:
	var hit := _aim_hit()
	if hit.is_empty():
		return
	var c := hit["collider"] as Node
	if c == null or c.get("cell") == null or c.get("cliff_id") == null:
		return
	var cell: Vector2i = c.get("cell")
	if c.get_parent() != BuildManager.instance:
		return
	if action == &"upgrade":
		if c is Turret:
			BuildManager.instance.upgrade_node(c)
	else:
		BuildManager.instance.demolish_node(c)


func _refresh_ghost_mesh() -> void:
	var id := selected_id()
	if Defs.is_turret(id):
		_ghost.mesh = TurretBuilder.build(id, Color.WHITE)["base"]
	else:
		_ghost.mesh = StructureBuilder.build(Defs.structure(id).kind)


## Tiles every cell on your plateau where the selected item can go, as framed
## tiles coloured by zone: gold = cliff edge, rust = tactical row, sage = plots.
## Taken cells go dark red; the cells you're aiming at light up.
const ZONE_COLORS := {Buildable.Zone.TURRET: Color("#FFC84A"), Buildable.Zone.TACTICAL: Color("#E8784A"), Buildable.Zone.PLOT: Color("#9FD27A")}


func _rebuild_grid() -> void:
	var id := selected_id()
	var cliffs_to_show: Array[int] = [player.cliff_id]
	if GameState.is_solo():
		cliffs_to_show = [WorldLayout.WEST, WorldLayout.EAST]
	var cells: Array = []
	for cid in cliffs_to_show:
		if Defs.is_house_turret(id):
			var home := Homestead.of(cid)
			for i in (home.mount_count() if home != null else 0):
				cells.append([cid, Vector2i(-1, i)])
			continue
		for row in Buildable.ROWS:
			for col in Buildable.COLS:
				var c := Vector2i(row, col)
				if Buildable.zone_ok(id, c):
					cells.append([cid, c])
	var aimed: Array[Vector2i] = []
	if _cell.x >= 0:
		aimed = Buildable.footprint(id, _cell)
	var mm := _grid.multimesh
	mm.instance_count = cells.size()
	var bm := BuildManager.instance
	for i in cells.size():
		var cid: int = cells[i][0]
		var c: Vector2i = cells[i][1]
		var pos := (Buildable.cell_center(cliffs, cid, c) if c.x >= 0 else Homestead.of(cid).mount_global(c.y)) + Vector3.UP * 0.06
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, WorldLayout.facing_canyon_yaw(cid)), pos))
		var taken := bm.cell_taken(cid, c) if (c.x >= 0 and not Defs.is_turret(id) and id != &"scaffold") else not bm.is_free_for(id, cid, c)
		var col: Color = ZONE_COLORS.get(Buildable.zone(c), Color("#9FD27A")) if c.x >= 0 else Color("#9FD27A")
		col.a = 0.8
		if taken:
			col = Color(0.55, 0.15, 0.12, 0.45)
		if cid == _cliff and (aimed.has(c) or c == _cell):
			col = Color(1.0, 1.0, 0.85, 0.95) if _ok else Color(1.0, 0.35, 0.3, 0.9)
		mm.set_instance_color(i, col)


## One grid tile: a thin rounded frame with a faint fill (colour from the instance).
static func _tile_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	var s := WorldLayout.CELL * 0.86
	var w := 0.12
	var h := s * 0.5
	var frame := Color(1, 1, 1, 1)
	var fill := Color(1, 1, 1, 0.3)
	var n := Vector3.UP
	MeshKit.quad(st, Vector3(-h + w, 0, -h + w), Vector3(h - w, 0, -h + w), Vector3(h - w, 0, h - w), Vector3(-h + w, 0, h - w), n, fill)
	for side in 4:
		var b := Basis(Vector3.UP, side * PI * 0.5)
		MeshKit.quad(st, b * Vector3(-h, 0.005, -h), b * Vector3(h, 0.005, -h), b * Vector3(h - w, 0.005, -h + w), b * Vector3(-h + w, 0.005, -h + w), n, frame)
	return MeshKit.finish(st)
