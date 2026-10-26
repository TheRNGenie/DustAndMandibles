class_name BuildManager
extends Node3D
## Host-authoritative building: clients ask with request RPCs, the host checks
## cliff ownership, the grid and cost, then spawns the turret, trap, plot or rain
## catcher (MultiplayerSpawner replicates it). Turret-line cells can also hold a
## scaffold of up to 3 levels: a turret can sit on the ground and on each level,
## and every level up gives that turret 5 more degrees of look-down.
## Demolish / repair / upgrade name the exact node you aimed at.

signal structure_event(text: String)

const REPAIR_HP_PER_SCRAP := 10.0
const REPAIR_CHUNK := 20.0
const DEMOLISH_REFUND := 0.5
const MAX_SCAFFOLD := 3

static var instance: BuildManager

var cliffs: CliffBuilder
var _spawner: MultiplayerSpawner
## "cid:row:col:level" -> Node3D (level 0 for everything that isn't stacked).
var _occupied: Dictionary = {}
## "cid:row:col" -> ScaffoldNode
var _scaffolds: Dictionary = {}
var _next_id := 0


func _ready() -> void:
	instance = self
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "BuildSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(self)
	_spawner.spawn_function = _spawn_built


static func _key(cid: int, cell: Vector2i, level: int = 0) -> String:
	return "%d:%d:%d:%d" % [cid, cell.x, cell.y, level]


static func _cell_key(cid: int, cell: Vector2i) -> String:
	return "%d:%d:%d" % [cid, cell.x, cell.y]


func scaffold_levels(cid: int, cell: Vector2i) -> int:
	var s := _scaffolds.get(_cell_key(cid, cell)) as ScaffoldNode
	return s.levels if s != null and is_instance_valid(s) else 0


## Lowest free turret slot on a cell (0 = ground), or -1 if every slot is taken.
func free_turret_level(cid: int, cell: Vector2i) -> int:
	for level in scaffold_levels(cid, cell) + 1:
		if not _occupied.has(_key(cid, cell, level)):
			return level
	return -1


func is_free_for(id: StringName, cid: int, cell: Vector2i) -> bool:
	if not Buildable.cell_ok_for(id, cell):
		return false
	if Defs.is_house_turret(id):
		var home := Homestead.of(cid)
		return home != null and cell.y < home.mount_count() and not _occupied.has(_key(cid, cell, 0))
	if id == &"scaffold":
		return scaffold_levels(cid, cell) < MAX_SCAFFOLD
	if Defs.is_turret(id) and Buildable.is_turret_cell(cell):
		return free_turret_level(cid, cell) >= 0
	for c in Buildable.footprint(id, cell):
		if _occupied.has(_key(cid, c, 0)) or scaffold_levels(cid, c) > 0:
			return false
	return true


## Is something already standing on this cell (any level, or a scaffold)?
func cell_taken(cid: int, cell: Vector2i) -> bool:
	return _occupied.has(_key(cid, cell, 0)) or scaffold_levels(cid, cell) > 0


## Kept for older callers: is a turret slot free here?
func is_free(cid: int, cell: Vector2i) -> bool:
	return is_free_for(&"gatling_post", cid, cell)


func built_at(cid: int, cell: Vector2i, level: int = 0) -> Node3D:
	return _occupied.get(_key(cid, cell, level)) as Node3D


func turret_at(cid: int, cell: Vector2i, level: int = 0) -> Turret:
	return built_at(cid, cell, level) as Turret


## Every turret standing on a cell (ground first).
func turrets_on(cid: int, cell: Vector2i) -> Array[Turret]:
	var out: Array[Turret] = []
	for level in MAX_SCAFFOLD + 1:
		var t := turret_at(cid, cell, level)
		if t != null:
			out.append(t)
	return out


## Can this peer build on this cliff? Your own cliff only, unless playing solo.
func may_build(peer_id: int, cid: int) -> bool:
	if GameState.is_solo():
		return true
	return NetworkManager.cliff_of(peer_id) == cid


# ------------------------------------------------------------------ client requests

func build(id: StringName, cid: int, cell: Vector2i) -> void:
	_call(&"build", [id, cid, cell])


## Demolish / repair / upgrade the given built node (a turret, structure or scaffold).
func demolish_node(n: Node) -> void:
	_call(&"demolish", [n.name])


func repair_node(n: Node) -> void:
	_call(&"repair", [n.name])


func upgrade_node(n: Node) -> void:
	_call(&"upgrade", [n.name])


func _call(action: StringName, args: Array) -> void:
	if multiplayer.is_server():
		_handle(multiplayer.get_unique_id(), action, args)
	else:
		_request.rpc_id(1, action, args)


@rpc("any_peer", "reliable")
func _request(action: StringName, args: Array) -> void:
	if multiplayer.is_server():
		_handle(multiplayer.get_remote_sender_id(), action, args)


func _handle(peer_id: int, action: StringName, args: Array) -> void:
	if action == &"build":
		_do_build(peer_id, StringName(args[0]), int(args[1]), args[2])
		return
	var n := get_node_or_null(NodePath(str(args[0]))) as Node3D
	if n == null:
		return
	match action:
		&"demolish":
			_do_demolish(peer_id, n)
		&"repair":
			_do_repair(peer_id, n)
		&"upgrade":
			_do_upgrade(peer_id, n)


# ------------------------------------------------------------------ host logic

func _do_build(peer_id: int, id: StringName, cid: int, cell: Vector2i) -> void:
	if not (Defs.is_turret(id) or Defs.STRUCTURES.has(id)):
		return
	if not may_build(peer_id, cid) or not is_free_for(id, cid, cell) or GameState.phase == GameState.Phase.GAME_OVER:
		return
	var cost := Defs.cost_of(id)
	if not Economy.spend(cid, {&"scrap": cost}):
		Economy.notify(peer_id, "Not enough scrap for a %s (%d)." % [Defs.name_of(id), cost])
		return
	if id == &"scaffold" and scaffold_levels(cid, cell) > 0:
		(_scaffolds[_cell_key(cid, cell)] as ScaffoldNode).set_levels(scaffold_levels(cid, cell) + 1)
		_built_fx.rpc(Buildable.cell_center(cliffs, cid, cell))
		return
	var level := 0
	if Defs.is_turret(id) and Buildable.is_turret_cell(cell):
		level = free_turret_level(cid, cell)
	_next_id += 1
	_spawner.spawn({"id": _next_id, "type": id, "cliff": cid, "row": cell.x, "col": cell.y,
			"level": level, "owner": _name_of(peer_id)})


func _spawn_built(data: Variant) -> Node:
	var d := data as Dictionary
	var cid := int(d["cliff"])
	var cell := Vector2i(int(d["row"]), int(d["col"]))
	var id := StringName(d["type"])
	var level := int(d.get("level", 0))
	var pos := Buildable.footprint_center(cliffs, cid, id, cell) if cell.x >= 0 else Homestead.of(cid).mount_global(cell.y)
	var node: Node3D
	if Defs.is_turret(id):
		var t := Turret.new()
		t.setup(Defs.turret(id), cid, cell, pos + Vector3.UP * ScaffoldNode.LEVEL_HEIGHT * level, str(d["owner"]), level)
		node = t
	elif id == &"scaffold":
		var sc := ScaffoldNode.new()
		sc.setup(cid, cell, pos)
		_scaffolds[_cell_key(cid, cell)] = sc
		node = sc
	elif Defs.structure(id).kind == StructureDef.Kind.RAIN_CATCHER:
		node = _make_rain_catcher(cid, cell, pos)
	elif Defs.structure(id).kind == StructureDef.Kind.FARM_PLOT:
		var plot := CropPlot.new()
		plot.setup(cid)
		plot.cell = cell
		plot.position = pos
		plot.rotation.y = WorldLayout.facing_canyon_yaw(cid)
		node = plot
	else:
		var s := StructureNode.new()
		s.setup(Defs.structure(id), cid, cell, pos, str(d["owner"]))
		node = s
	node.name = "Built%d" % int(d["id"])
	if id != &"scaffold":
		# Every cell of the footprint (farm plots cover 2 x 2) points at the node.
		var keys: Array[String] = []
		for c in (Buildable.footprint(id, cell) if cell.x >= 0 else [cell]):
			keys.append(_key(cid, c, level))
		for key in keys:
			_occupied[key] = node
		node.tree_exiting.connect(func() -> void:
			for key in keys:
				if _occupied.get(key) == node:
					_occupied.erase(key))
	else:
		var ck := _cell_key(cid, cell)
		node.tree_exiting.connect(func() -> void:
			if _scaffolds.get(ck) == node:
				_scaffolds.erase(ck))
	Audio.play_at(&"build", pos)
	return node


func _make_rain_catcher(cid: int, cell: Vector2i, pos: Vector3) -> WaterSource:
	var w := WaterSource.new()
	w.cliff_id = cid
	w.cell = cell
	w.build_id = &"rain_catcher"
	w.display_name = "Rain catcher"
	w.rates = Vector2(20.0, 3.0)
	w.capacity = 8
	w.position = pos
	w.collision_layer = WorldLayout.LAYER_STRUCTURE
	var mi := MeshInstance3D.new()
	mi.mesh = StructureBuilder.build(StructureDef.Kind.RAIN_CATCHER)
	mi.material_override = Materials.toon(0.02)
	w.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.6
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	w.add_child(col)
	return w


func _do_demolish(peer_id: int, n: Node3D) -> void:
	var cid := int(n.get("cliff_id"))
	if not may_build(peer_id, cid):
		return
	if n is ScaffoldNode:
		# Take down the top level, but only if no turret is standing on it.
		var sc := n as ScaffoldNode
		if turret_at(cid, sc.cell, sc.levels) != null:
			Economy.notify(peer_id, "Remove the turret on the top level first.")
			return
		Economy.earn(cid, {&"scrap": int(Defs.cost_of(&"scaffold") * DEMOLISH_REFUND)})
		if sc.levels <= 1:
			sc.queue_free()
		else:
			sc.set_levels(sc.levels - 1)
		return
	var id: StringName = n.get("build_id") if n.get("build_id") != null else (n as Object).get("def").get("id")
	var fraction := 1.0
	var h: Variant = n.get("health")
	if h != null:
		fraction = (h as Health).fraction()
	Economy.earn(cid, {&"scrap": int(Defs.cost_of(id) * DEMOLISH_REFUND * fraction)})
	n.queue_free()


func _do_repair(peer_id: int, n: Node3D) -> void:
	var t := n as Turret
	if n is ScaffoldNode:
		# Repairing a scaffold patches up its most damaged turret.
		var worst: Turret = null
		for tt in turrets_on(int(n.get("cliff_id")), (n as ScaffoldNode).cell):
			if tt.needs_repair() and (worst == null or tt.health.fraction() < worst.health.fraction()):
				worst = tt
		t = worst
	if t == null or not t.needs_repair():
		return
	# Anyone can repair anything: helping your partner's turrets is the point.
	var payer := Economy.payer_cliff(peer_id, t.cliff_id)
	if not Economy.spend(payer, {&"scrap": int(ceil(REPAIR_CHUNK / REPAIR_HP_PER_SCRAP))}):
		return
	t.repair(REPAIR_CHUNK)


func _do_upgrade(peer_id: int, n: Node3D) -> void:
	var t := n as Turret
	if t == null or t.upgrade_cost() <= 0:
		return
	var payer := Economy.payer_cliff(peer_id, t.cliff_id)
	if not Economy.spend(payer, {&"chitin": t.upgrade_cost()}):
		Economy.notify(peer_id, "Upgrading needs %d chitin (armoured bugs and the Oasis vendor give it)." % t.upgrade_cost())
		return
	t.upgrade()
	_upgraded.rpc(t.global_position)


@rpc("authority", "call_local", "reliable")
func _upgraded(pos: Vector3) -> void:
	Audio.play_at(&"coin", pos)
	if Turret.vfx != null:
		Turret.vfx.pop(pos + Vector3.UP * 1.5, Palette.GLOW_YELLOW, 1.0)


@rpc("authority", "call_local", "reliable")
func _built_fx(pos: Vector3) -> void:
	Audio.play_at(&"build", pos)


## Host: a turret or structure's HP hit zero.
func on_structure_destroyed(n: Node3D) -> void:
	var label := "A structure"
	if n is Turret:
		label = "%s's %s" % [(n as Turret).owner_name, (n as Turret).def.display_name]
	elif n is StructureNode:
		label = "%s's %s" % [(n as StructureNode).owner_name, (n as StructureNode).def.display_name]
	_wreck.rpc(n.global_position, "%s was destroyed!" % label)
	n.queue_free()


@rpc("authority", "call_local", "reliable")
func _wreck(pos: Vector3, text: String) -> void:
	if Turret.vfx != null:
		Turret.vfx.pop(pos + Vector3.UP, Palette.WOOD, 1.6)
	Audio.play_at(&"dynamite", pos, -6.0)
	structure_event.emit(text)


func _name_of(peer_id: int) -> String:
	if NetworkManager.players.has(peer_id):
		return str((NetworkManager.players[peer_id] as Dictionary)["name"])
	return NetworkManager.local_name
