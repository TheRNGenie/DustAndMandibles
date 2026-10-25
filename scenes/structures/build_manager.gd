class_name BuildManager
extends Node3D
## Host-authoritative building: clients ask with request_* RPCs, the host checks
## cliff ownership, the grid and cost, then spawns the turret (MultiplayerSpawner
## replicates it). Also handles demolish refunds, repairs and salvage piles.

signal structure_event(text: String)

const REPAIR_HP_PER_SCRAP := 10.0
const REPAIR_CHUNK := 20.0
const DEMOLISH_REFUND := 0.5

static var instance: BuildManager

var cliffs: CliffBuilder
var _spawner: MultiplayerSpawner
var _occupied: Dictionary = {} # "cid:row:col" -> Turret
var _next_id := 0


func _ready() -> void:
	instance = self
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "TurretSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(self)
	_spawner.spawn_function = _spawn_turret


static func _key(cid: int, cell: Vector2i) -> String:
	return "%d:%d:%d" % [cid, cell.x, cell.y]


func is_free(cid: int, cell: Vector2i) -> bool:
	return Buildable.is_turret_cell(cell) and not _occupied.has(_key(cid, cell))


func turret_at(cid: int, cell: Vector2i) -> Turret:
	return _occupied.get(_key(cid, cell)) as Turret


## Can this peer build on this cliff? Your own cliff only, unless playing solo.
func may_build(peer_id: int, cid: int) -> bool:
	if GameState.is_solo():
		return true
	return NetworkManager.cliff_of(peer_id) == cid


# ------------------------------------------------------------------ client requests

func build(turret_id: StringName, cid: int, cell: Vector2i) -> void:
	if multiplayer.is_server():
		_do_build(multiplayer.get_unique_id(), turret_id, cid, cell)
	else:
		_request_build.rpc_id(1, turret_id, cid, cell)


func demolish(cid: int, cell: Vector2i) -> void:
	if multiplayer.is_server():
		_do_demolish(multiplayer.get_unique_id(), cid, cell)
	else:
		_request_demolish.rpc_id(1, cid, cell)


func repair(cid: int, cell: Vector2i) -> void:
	if multiplayer.is_server():
		_do_repair(multiplayer.get_unique_id(), cid, cell)
	else:
		_request_repair.rpc_id(1, cid, cell)


@rpc("any_peer", "reliable")
func _request_build(turret_id: StringName, cid: int, cell: Vector2i) -> void:
	if multiplayer.is_server():
		_do_build(multiplayer.get_remote_sender_id(), turret_id, cid, cell)


@rpc("any_peer", "reliable")
func _request_demolish(cid: int, cell: Vector2i) -> void:
	if multiplayer.is_server():
		_do_demolish(multiplayer.get_remote_sender_id(), cid, cell)


@rpc("any_peer", "reliable")
func _request_repair(cid: int, cell: Vector2i) -> void:
	if multiplayer.is_server():
		_do_repair(multiplayer.get_remote_sender_id(), cid, cell)


# ------------------------------------------------------------------ host logic

func _do_build(peer_id: int, turret_id: StringName, cid: int, cell: Vector2i) -> void:
	var d := Defs.turret(turret_id)
	if d == null or not may_build(peer_id, cid) or not is_free(cid, cell):
		return
	if GameState.phase == GameState.Phase.GAME_OVER:
		return
	if not Economy.spend(cid, {&"scrap": d.cost_scrap}):
		var msg := "Not enough scrap for a %s (%d)." % [d.display_name, d.cost_scrap]
		if peer_id == multiplayer.get_unique_id():
			structure_event.emit(msg)
		else:
			_feedback.rpc_id(peer_id, msg)
		return
	_next_id += 1
	var player_name := _name_of(peer_id)
	_spawner.spawn({"id": _next_id, "type": turret_id, "cliff": cid, "row": cell.x, "col": cell.y, "owner": player_name})


func _spawn_turret(data: Variant) -> Node:
	var d := data as Dictionary
	var cid := int(d["cliff"])
	var cell := Vector2i(int(d["row"]), int(d["col"]))
	var t := Turret.new()
	t.name = "Turret%d" % int(d["id"])
	t.setup(Defs.turret(StringName(d["type"])), cid, cell, Buildable.cell_center(cliffs, cid, cell), str(d["owner"]))
	_occupied[_key(cid, cell)] = t
	t.tree_exiting.connect(func() -> void:
		if _occupied.get(_key(cid, cell)) == t:
			_occupied.erase(_key(cid, cell)))
	Audio.play_at(&"build", t.position)
	return t


func _do_demolish(peer_id: int, cid: int, cell: Vector2i) -> void:
	var t := turret_at(cid, cell)
	if t == null or not may_build(peer_id, cid):
		return
	var refund := int(t.def.cost_scrap * DEMOLISH_REFUND * t.health.fraction())
	Economy.earn(cid, {&"scrap": refund})
	_occupied.erase(_key(cid, cell))
	t.queue_free()


func _do_repair(peer_id: int, cid: int, cell: Vector2i) -> void:
	var t := turret_at(cid, cell)
	if t == null or not t.needs_repair():
		return
	# Anyone can repair anything: helping your partner's turrets is the point.
	var payer := cid if GameState.is_solo() else NetworkManager.cliff_of(peer_id)
	var cost := int(ceil(REPAIR_CHUNK / REPAIR_HP_PER_SCRAP))
	if not Economy.spend(payer, {&"scrap": cost}):
		return
	t.repair(REPAIR_CHUNK)


## Host: a turret's HP hit zero.
func on_structure_destroyed(t: Turret) -> void:
	_occupied.erase(_key(t.cliff_id, t.cell))
	_wreck.rpc(t.global_position, "%s's %s was destroyed!" % [t.owner_name, t.def.display_name])
	t.queue_free()


@rpc("authority", "call_local", "reliable")
func _wreck(pos: Vector3, text: String) -> void:
	if Turret.vfx != null:
		Turret.vfx.pop(pos + Vector3.UP, Palette.WOOD, 1.6)
	Audio.play_at(&"dynamite", pos, -6.0)
	structure_event.emit(text)


@rpc("authority", "reliable")
func _feedback(text: String) -> void:
	structure_event.emit(text)


func _name_of(peer_id: int) -> String:
	if NetworkManager.players.has(peer_id):
		return str((NetworkManager.players[peer_id] as Dictionary)["name"])
	return NetworkManager.local_name
