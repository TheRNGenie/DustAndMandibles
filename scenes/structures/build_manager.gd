class_name BuildManager
extends Node3D
## Host-authoritative building: clients ask with request_* RPCs, the host checks
## cliff ownership, the grid and cost, then spawns the turret, trap or rain catcher
## (MultiplayerSpawner replicates it). Also handles demolish refunds, repairs and
## turret upgrades.

signal structure_event(text: String)

const REPAIR_HP_PER_SCRAP := 10.0
const REPAIR_CHUNK := 20.0
const DEMOLISH_REFUND := 0.5

static var instance: BuildManager

var cliffs: CliffBuilder
var _spawner: MultiplayerSpawner
var _occupied: Dictionary = {} # "cid:row:col" -> Node3D (Turret, StructureNode or WaterSource)
var _next_id := 0


func _ready() -> void:
	instance = self
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "BuildSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(self)
	_spawner.spawn_function = _spawn_built


static func _key(cid: int, cell: Vector2i) -> String:
	return "%d:%d:%d" % [cid, cell.x, cell.y]


func is_free_for(id: StringName, cid: int, cell: Vector2i) -> bool:
	return Buildable.cell_ok_for(id, cell) and not _occupied.has(_key(cid, cell))


## Kept for older callers: is a turret cell free?
func is_free(cid: int, cell: Vector2i) -> bool:
	return is_free_for(&"gatling_post", cid, cell)


func built_at(cid: int, cell: Vector2i) -> Node3D:
	return _occupied.get(_key(cid, cell)) as Node3D


func turret_at(cid: int, cell: Vector2i) -> Turret:
	return built_at(cid, cell) as Turret


## Can this peer build on this cliff? Your own cliff only, unless playing solo.
func may_build(peer_id: int, cid: int) -> bool:
	if GameState.is_solo():
		return true
	return NetworkManager.cliff_of(peer_id) == cid


# ------------------------------------------------------------------ client requests

func build(id: StringName, cid: int, cell: Vector2i) -> void:
	_call(&"build", [id, cid, cell])


func demolish(cid: int, cell: Vector2i) -> void:
	_call(&"demolish", [cid, cell])


func repair(cid: int, cell: Vector2i) -> void:
	_call(&"repair", [cid, cell])


func upgrade(cid: int, cell: Vector2i) -> void:
	_call(&"upgrade", [cid, cell])


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
	match action:
		&"build":
			_do_build(peer_id, StringName(args[0]), int(args[1]), args[2])
		&"demolish":
			_do_demolish(peer_id, int(args[0]), args[1])
		&"repair":
			_do_repair(peer_id, int(args[0]), args[1])
		&"upgrade":
			_do_upgrade(peer_id, int(args[0]), args[1])


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
	_next_id += 1
	_spawner.spawn({"id": _next_id, "type": id, "cliff": cid, "row": cell.x, "col": cell.y, "owner": _name_of(peer_id)})


func _spawn_built(data: Variant) -> Node:
	var d := data as Dictionary
	var cid := int(d["cliff"])
	var cell := Vector2i(int(d["row"]), int(d["col"]))
	var id := StringName(d["type"])
	var pos := Buildable.cell_center(cliffs, cid, cell)
	var node: Node3D
	if Defs.is_turret(id):
		var t := Turret.new()
		t.setup(Defs.turret(id), cid, cell, pos, str(d["owner"]))
		node = t
	elif Defs.structure(id).kind == StructureDef.Kind.RAIN_CATCHER:
		node = _make_rain_catcher(cid, cell, pos)
	else:
		var s := StructureNode.new()
		s.setup(Defs.structure(id), cid, cell, pos, str(d["owner"]))
		node = s
	node.name = "Built%d" % int(d["id"])
	var key := _key(cid, cell)
	_occupied[key] = node
	node.tree_exiting.connect(func() -> void:
		if _occupied.get(key) == node:
			_occupied.erase(key))
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


func _do_demolish(peer_id: int, cid: int, cell: Vector2i) -> void:
	var n := built_at(cid, cell)
	if n == null or not may_build(peer_id, cid):
		return
	var id: StringName = n.get("build_id") if n is WaterSource else (n as Object).get("def").get("id")
	var fraction := 1.0
	var h: Variant = n.get("health")
	if h != null:
		fraction = (h as Health).fraction()
	Economy.earn(cid, {&"scrap": int(Defs.cost_of(id) * DEMOLISH_REFUND * fraction)})
	_occupied.erase(_key(cid, cell))
	n.queue_free()


func _do_repair(peer_id: int, cid: int, cell: Vector2i) -> void:
	var t := turret_at(cid, cell)
	if t == null or not t.needs_repair():
		return
	# Anyone can repair anything: helping your partner's turrets is the point.
	var payer := Economy.payer_cliff(peer_id, cid)
	if not Economy.spend(payer, {&"scrap": int(ceil(REPAIR_CHUNK / REPAIR_HP_PER_SCRAP))}):
		return
	t.repair(REPAIR_CHUNK)


func _do_upgrade(peer_id: int, cid: int, cell: Vector2i) -> void:
	var t := turret_at(cid, cell)
	if t == null or t.upgrade_cost() <= 0:
		return
	var payer := Economy.payer_cliff(peer_id, cid)
	if not Economy.spend(payer, {&"chitin": t.upgrade_cost()}):
		Economy.notify(peer_id, "Upgrading needs %d chitin (armoured bugs drop it)." % t.upgrade_cost())
		return
	t.upgrade()
	_upgraded.rpc(t.global_position)


@rpc("authority", "call_local", "reliable")
func _upgraded(pos: Vector3) -> void:
	Audio.play_at(&"coin", pos)
	if Turret.vfx != null:
		Turret.vfx.pop(pos + Vector3.UP * 1.5, Palette.GLOW_YELLOW, 1.0)


## Host: a turret or structure's HP hit zero.
func on_structure_destroyed(n: Node3D) -> void:
	var cid := int(n.get("cliff_id"))
	var cell: Vector2i = n.get("cell")
	_occupied.erase(_key(cid, cell))
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
