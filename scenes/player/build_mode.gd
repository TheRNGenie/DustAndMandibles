class_name BuildMode
extends Node3D
## Local player's build tool. B toggles it; number keys pick a turret; a ghost
## snaps to the turret line on the cliff edge (green = OK, red = blocked or too
## expensive); left click asks the host to build; X demolishes the turret you
## look at (50% refund, scaled by its health). Right click or B leaves build mode.

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


func selected_def() -> TurretDef:
	return Defs.turret(Defs.TURRET_ORDER[selected])


func _unhandled_input(event: InputEvent) -> void:
	if GameState.menu_open or player.is_downed():
		return
	if event.is_action_pressed("build_menu"):
		_set_active(not active)
	elif active and event.is_action_pressed("alt_fire"):
		_set_active(false)
	elif active and event.is_action_pressed("fire"):
		if _ok:
			BuildManager.instance.build(selected_def().id, _cliff, _cell)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("demolish"):
		_demolish_target()
	for i in Defs.TURRET_ORDER.size():
		if event.is_action_pressed("select_%d" % (i + 1)):
			selected = i
			_set_active(true)
			_refresh_ghost_mesh()


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
	if hit.is_empty():
		_ghost.visible = false
		return
	var pos: Vector3 = hit["position"]
	_cliff = Buildable.cliff_at(pos)
	if _cliff < 0:
		_ghost.visible = false
		return
	_cell = Buildable.world_to_cell(cliffs, _cliff, pos)
	if not Buildable.is_turret_cell(_cell):
		_ghost.visible = false
		return
	_ghost.visible = true
	_ghost.global_position = Buildable.cell_center(cliffs, _cliff, _cell)
	_ghost.rotation.y = WorldLayout.facing_canyon_yaw(_cliff)
	var bm := BuildManager.instance
	var mine := bm.may_build(multiplayer.get_unique_id(), _cliff)
	var affordable := Economy.can_afford(_cliff if GameState.is_solo() else player.cliff_id, {&"scrap": selected_def().cost_scrap})
	_ok = mine and bm.is_free(_cliff, _cell) and affordable
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.4, 0.45) if _ok else Color(1.0, 0.3, 0.25, 0.45)


## Why the ghost is red, for the HUD.
func status_text() -> String:
	if not active:
		return ""
	var d := selected_def()
	var line := "BUILD: [%d] %s - %d scrap.  Click to place, X demolish, B/right-click exit." % [selected + 1, d.display_name, d.cost_scrap]
	if _cell.x >= 0 and not _ok:
		if not BuildManager.instance.may_build(multiplayer.get_unique_id(), _cliff):
			line += "\nYou can only build on your own cliff edge. Your turrets cover your partner."
		elif not BuildManager.instance.is_free(_cliff, _cell):
			line += "\nThat spot is taken."
		else:
			line += "\nNot enough scrap."
	elif _cell.x < 0:
		line += "\nAim at the turret line along your cliff edge."
	return line


func _aim_hit() -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE)
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _demolish_target() -> void:
	var hit := _aim_hit()
	if hit.is_empty():
		return
	var t := hit["collider"] as Turret
	if t != null:
		BuildManager.instance.demolish(t.cliff_id, t.cell)


func _refresh_ghost_mesh() -> void:
	var parts := TurretBuilder.build(selected_def().id, Color.WHITE)
	_ghost.mesh = parts["base"]
