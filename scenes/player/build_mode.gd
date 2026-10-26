class_name BuildMode
extends Node3D
## Local player's build tool. B toggles it; number keys 1-0 or the mouse wheel pick
## what to build (6 turrets for the cliff edge, then traps and the rain catcher for
## behind the turret line). A ghost snaps to the grid: green = OK, red = blocked or
## too expensive. Left click asks the host to build. X demolishes what you look at
## (50% refund, scaled by health). U upgrades the turret you look at with chitin.
## Right click or B leaves build mode.

signal changed

const REACH := 40.0

var player: Player
var cliffs: CliffBuilder
var active := false
var selected := 0
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _cell := Vector2i(-1, -1)
var _cliff := -1
var _ok := false


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


func selected_id() -> StringName:
	return Defs.BUILD_ORDER[selected]


func _unhandled_input(event: InputEvent) -> void:
	if GameState.menu_open or player.is_downed():
		return
	if event.is_action_pressed("build_menu"):
		_set_active(not active)
	elif active and event.is_action_pressed("alt_fire"):
		_set_active(false)
	elif active and event.is_action_pressed("fire"):
		if _ok:
			BuildManager.instance.build(selected_id(), _cliff, _cell)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("demolish"):
		_act_on_target(&"demolish")
	elif event.is_action_pressed("upgrade"):
		_act_on_target(&"upgrade")
	elif active and event.is_action_pressed("next_item"):
		_select((selected + 1) % Defs.BUILD_ORDER.size())
	elif active and event.is_action_pressed("prev_item"):
		_select((selected - 1 + Defs.BUILD_ORDER.size()) % Defs.BUILD_ORDER.size())
	for i in mini(Defs.BUILD_ORDER.size(), 10):
		if event.is_action_pressed("select_%d" % (i + 1)):
			_select(i)
			_set_active(true)


func _select(i: int) -> void:
	selected = i
	_refresh_ghost_mesh()
	changed.emit()


func _set_active(on: bool) -> void:
	active = on
	_ghost.visible = on
	changed.emit()


func _process(_delta: float) -> void:
	if not active:
		return
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
	_cell = Buildable.world_to_cell(cliffs, _cliff, pos)
	if not Buildable.cell_ok_for(selected_id(), _cell):
		return
	_ghost.visible = true
	_ghost.global_position = Buildable.cell_center(cliffs, _cliff, _cell)
	_ghost.rotation.y = WorldLayout.facing_canyon_yaw(_cliff)
	var bm := BuildManager.instance
	var mine := bm.may_build(multiplayer.get_unique_id(), _cliff)
	var payer := _cliff if GameState.is_solo() else player.cliff_id
	var affordable := Economy.can_afford(payer, {&"scrap": Defs.cost_of(selected_id())})
	_ok = mine and bm.is_free_for(selected_id(), _cliff, _cell) and affordable
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.4, 0.45) if _ok else Color(1.0, 0.3, 0.25, 0.45)


## The build bar text for the HUD: the selected item, its neighbours and why the ghost is red.
func status_text() -> String:
	if not active:
		return ""
	var id := selected_id()
	var n := Defs.BUILD_ORDER.size()
	var prev_id := Defs.BUILD_ORDER[(selected - 1 + n) % n]
	var next_id := Defs.BUILD_ORDER[(selected + 1) % n]
	var where := "cliff edge" if Defs.is_turret(id) else "behind the turret line"
	var line := "BUILD  <  %s  |  [%d] %s - %d scrap (%s)  |  %s  >" % [Defs.name_of(prev_id), (selected + 1) % 10,
			Defs.name_of(id), Defs.cost_of(id), where, Defs.name_of(next_id)]
	line += "\n" + _description(id)
	if _cell.x >= 0 and not _ok and Buildable.cell_ok_for(id, _cell):
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
	var c: Object = hit["collider"]
	if c == null or c.get("cell") == null or c.get("cliff_id") == null:
		return
	var cell: Vector2i = c.get("cell")
	var cid := int(c.get("cliff_id"))
	if cell.x < 0:
		return
	if action == &"upgrade":
		if c is Turret:
			BuildManager.instance.upgrade(cid, cell)
	else:
		BuildManager.instance.demolish(cid, cell)


func _refresh_ghost_mesh() -> void:
	var id := selected_id()
	if Defs.is_turret(id):
		_ghost.mesh = TurretBuilder.build(id, Color.WHITE)["base"]
	else:
		_ghost.mesh = StructureBuilder.build(Defs.structure(id).kind)
