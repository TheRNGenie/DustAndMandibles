class_name BuildManager
extends Node3D
## Host-authoritative building: clients ask with request RPCs, the host checks
## cliff ownership, the grid and cost, then spawns the turret, trap, plot or rain
## catcher (MultiplayerSpawner replicates it). Turret-line cells can also hold a
## scaffold of up to 3 levels. A turret sits IN its scaffold: level 1 is the
## ground inside the first storey of the frame, levels 2 and 3 stand on the
## floors above (ScaffoldNode.turret_height), and every level gives that turret
## 5 more degrees of look-down. Level 0 is a bare-ground turret with no frame.
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


## Is this turret slot taken? Level 1 stands on the ground inside the frame,
## the same spot as a bare-ground (level 0) turret a scaffold went up around.
func _slot_taken(cid: int, cell: Vector2i, level: int) -> bool:
	if level <= 1:
		return _occupied.has(_key(cid, cell, 0)) or _occupied.has(_key(cid, cell, 1))
	return _occupied.has(_key(cid, cell, level))


## Lowest free turret slot on a cell (0 = bare ground, no scaffold), or -1 if
## every slot is taken.
func free_turret_level(cid: int, cell: Vector2i) -> int:
	var levels := scaffold_levels(cid, cell)
	if levels == 0:
		return -1 if _occupied.has(_key(cid, cell, 0)) else 0
	for level in range(1, levels + 1):
		if not _slot_taken(cid, cell, level):
			return level
	return -1


## Where a new turret would go on a cell: the lowest free slot, or, when every
## level is taken, one more scaffold level on top (added free), up to MAX_SCAFFOLD.
## Only where a scaffold already stands (not on ground-mounted last resorts). -1 = full.
func stack_level(cid: int, cell: Vector2i) -> int:
	var free := free_turret_level(cid, cell)
	if free >= 0:
		return free
	var levels := scaffold_levels(cid, cell)
	if levels > 0 and levels < MAX_SCAFFOLD:
		return levels + 1
	return -1


## The level a turret of this kind would actually be built at here (what the
## build ghost and coverage preview show): normal turrets on a bare cell get a
## free scaffold put up around them, so they go in at level 1. -1 = no room.
func placement_level(id: StringName, cid: int, cell: Vector2i) -> int:
	var level := stack_level(cid, cell)
	if level == 0 and Defs.gets_scaffold(id):
		return 1
	return level


func is_free_for(id: StringName, cid: int, cell: Vector2i) -> bool:
	if not Buildable.cell_ok_for(id, cell):
		return false
	if Defs.is_house_turret(id):
		var home := Homestead.of(cid)
		return home != null and cell.y < home.mount_count() and not _occupied.has(_key(cid, cell, 0))
	# Crewed: crewed guns sit on bare ground only (no scaffold, nothing stacked on
	# or under them), and nothing else goes on a cell one covers.
	if Defs.is_crewed(id):
		for c in Buildable.footprint(id, cell):
			if cell_taken(cid, c) or not turrets_on(cid, c).is_empty():
				return false
		return true
	if crewed_at(cid, cell):
		return false
	if id == &"scaffold":
		return scaffold_levels(cid, cell) < MAX_SCAFFOLD
	if Defs.is_turret(id) and Buildable.is_turret_cell(cell):
		return stack_level(cid, cell) >= 0
	for c in Buildable.footprint(id, cell):
		if _occupied.has(_key(cid, c, 0)) or scaffold_levels(cid, c) > 0:
			return false
	return true


# Crewed: is this cell under a crewed gun's 2 x 2 footprint?
func crewed_at(cid: int, cell: Vector2i) -> bool:
	var t := turret_at(cid, cell, 0)
	return t != null and t.def.crewed


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


## Host: a CPU teammate builds on its own cliff, paying from the shared pool
## within its share (Economy.cpu_spend). Returns whether it went up.
func cpu_build(cpu_name: String, id: StringName, cid: int, cell: Vector2i) -> bool:
	if not multiplayer.is_server() or not is_free_for(id, cid, cell) or GameState.phase == GameState.Phase.GAME_OVER:
		return false
	if not Defs.is_unlocked(id, GameState.tier_wave()): # Tiers: not before its wave
		return false
	if not Economy.cpu_spend(cpu_name, {&"scrap": Defs.cost_of(id)}):
		return false
	# Already paid out of its share; _do_build skips charging while _cpu_builder is set.
	_cpu_builder = cpu_name
	_do_build(-1, id, cid, cell)
	_cpu_builder = ""
	return true


var _cpu_builder := ""


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
	if (_cpu_builder == "" and not may_build(peer_id, cid)) or not is_free_for(id, cid, cell) or GameState.phase == GameState.Phase.GAME_OVER:
		return
	# Tiers: Mid and Late turrets can't go up before their wave (the menu greys them out too).
	if not Defs.is_unlocked(id, GameState.tier_wave()):
		if _cpu_builder == "":
			Economy.notify(peer_id, "The %s %s." % [Defs.name_of(id), Defs.lock_reason(id, GameState.tier_wave()).to_lower()])
		return
	# Crafted turrets: placing one uses up the item made at the Workshop (no scrap).
	if CraftTable.is_craft(id):
		if _cpu_builder != "" or not Economy.spend(cid, {id: 1}):
			Economy.notify(peer_id, "You don't have a %s. Craft one at the Workshop." % Defs.name_of(id))
			return
	var cost := Perks.build_cost(peer_id, id) # Perk: Bulk Lumber / Barn Raising
	if _cpu_builder == "" and not Economy.spend(cid, {&"scrap": cost}):
		Economy.notify(peer_id, "Not enough scrap for a %s (%d)." % [Defs.name_of(id), cost])
		return
	if _cpu_builder == "" and not CraftTable.is_craft(id):
		Perks.note_built(peer_id, id) # Perk: Barn Raising used up
	if id == &"scaffold" and scaffold_levels(cid, cell) > 0:
		(_scaffolds[_cell_key(cid, cell)] as ScaffoldNode).set_levels(scaffold_levels(cid, cell) + 1)
		(_scaffolds[_cell_key(cid, cell)] as ScaffoldNode).paid_levels += 1
		_built_fx.rpc(Buildable.cell_center(cliffs, cid, cell))
		return
	var level := 0
	# Turrets go up inside a free scaffold: a timber frame round the gun at
	# ground level, which later turrets on the cell stack up through.
	if Defs.gets_scaffold(id) and scaffold_levels(cid, cell) == 0 and not _occupied.has(_key(cid, cell, 0)):
		_next_id += 1
		_spawner.spawn({"id": _next_id, "type": &"scaffold", "cliff": cid, "row": cell.x, "col": cell.y,
				"level": 0, "owner": _name_of(peer_id)})
	if Defs.is_turret(id) and Buildable.is_turret_cell(cell):
		level = placement_level(id, cid, cell)
		# Placing on top of a full stack: the next scaffold level goes up free.
		if level > scaffold_levels(cid, cell) and scaffold_levels(cid, cell) > 0:
			(_scaffolds[_cell_key(cid, cell)] as ScaffoldNode).set_levels(level)
	_next_id += 1
	_spawner.spawn({"id": _next_id, "type": id, "cliff": cid, "row": cell.x, "col": cell.y,
			"level": level, "owner": _name_of(peer_id), "peer": peer_id}) # Perk: "peer" for the builder's perks


func _spawn_built(data: Variant) -> Node:
	var d := data as Dictionary
	var cid := int(d["cliff"])
	var cell := Vector2i(int(d["row"]), int(d["col"]))
	var id := StringName(d["type"])
	var level := int(d.get("level", 0))
	var pos := Buildable.footprint_center(cliffs, cid, id, cell) if cell.x >= 0 else Homestead.of(cid).mount_global(cell.y)
	var node: Node3D
	if Defs.is_turret(id):
		var t: Turret = CrewedTurret.new() if Defs.is_crewed(id) else Turret.new() # Crewed
		t.setup(Defs.turret(id), cid, cell, pos + Vector3.UP * ScaffoldNode.turret_height(level), str(d["owner"]), level)
		Perks.apply_turret(t, int(d.get("peer", 0))) # Perk: Long Sights / Well Oiled / Reinforced Frames
		node = t
	elif id == &"scaffold":
		var sc := ScaffoldNode.new()
		sc.setup(cid, cell, pos)
		_scaffolds[_cell_key(cid, cell)] = sc
		sc.paid_levels = 1 if d.has("peer") else 0 # free scaffolds under turrets carry no "peer"
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
	w.display_name = "Rain Catcher"
	w.rates = Vector2(20.0, 3.0)
	w.capacity = 8
	w.rain_only = true # the only water besides the pump: rain
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


## Scrap you get back for selling this buildable: half its price, scaled by
## its health (Salvager pays more). Scaffolds are free, so they sell for nothing.
func sell_price(peer_id: int, n: Node) -> int:
	if n is ScaffoldNode:
		return 0
	var id: StringName = n.get("build_id") if n.get("build_id") != null else (n as Object).get("def").get("id")
	var fraction := 1.0
	var h: Variant = n.get("health")
	if h != null:
		fraction = (h as Health).fraction()
	return int(Defs.cost_of(id) * DEMOLISH_REFUND * fraction * Perks.more(peer_id, &"salvager")) # Perk: Salvager


func _do_demolish(peer_id: int, n: Node3D) -> void:
	var cid := int(n.get("cliff_id"))
	if not may_build(peer_id, cid):
		return
	if n is ScaffoldNode:
		# Take down the top level, but only if no turret is standing on it.
		var sc := n as ScaffoldNode
		if turret_at(cid, sc.cell, sc.levels) != null:
			Economy.notify(peer_id, "Sell the turret in the top storey first.")
			return
		if sc.paid_levels > 0: # scaffolds are free now; old saves' paid levels still pay back
			sc.paid_levels -= 1
			Economy.earn(cid, {&"scrap": int(25 * DEMOLISH_REFUND * Perks.more(peer_id, &"salvager"))}) # Perk: Salvager
		if sc.levels <= 1:
			sc.queue_free()
		else:
			sc.set_levels(sc.levels - 1)
		return
	Economy.earn(cid, {&"scrap": sell_price(peer_id, n)})
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
	t.repair(REPAIR_CHUNK * Perks.more(peer_id, &"tinker")) # Perk: Tinker


func _do_upgrade(peer_id: int, n: Node3D) -> void:
	var t := n as Turret
	if t == null or t.upgrade_cost() <= 0:
		return
	var payer := Economy.payer_cliff(peer_id, t.cliff_id)
	# A casino upgrade token pays first; otherwise chitin.
	var paid := Economy.amount(payer, Turret.UPGRADE_TOKEN) > 0 and Economy.spend(payer, {Turret.UPGRADE_TOKEN: 1})
	var chitin := Perks.discount(peer_id, &"chitin_smith", t.upgrade_cost()) # Perk: Chitin Smith
	if not paid and not Economy.spend(payer, {&"chitin": chitin}):
		Economy.notify(peer_id, "Upgrading needs %d chitin (armoured bugs and the airship market give it)." % chitin)
		return
	t.upgrade()
	Economy.notify(peer_id, "%s upgraded: %s." % [t.def.display_name, TurretDef.TIER_NAMES[t.tier]])
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


## Host: puts a saved build back exactly where it was (Continue last run): no
## cost, no grid checks, at the saved scaffold level. Returns the new node.
func restore_built(id: StringName, cid: int, cell: Vector2i, level: int, owner_label: String) -> Node3D:
	if not multiplayer.is_server() or not (Defs.is_turret(id) or Defs.STRUCTURES.has(id)):
		return null
	# Older saves could hold a bare-ground turret with a scaffold over it AND a
	# turret on the first platform; level 1 is the ground inside the frame now,
	# so a turret landing on a taken slot moves up to the next free one.
	if Defs.is_turret(id) and cell.x >= 0 and scaffold_levels(cid, cell) > 0 and _slot_taken(cid, cell, level):
		var up := stack_level(cid, cell)
		if up < 0:
			return null
		if up > scaffold_levels(cid, cell):
			(_scaffolds[_cell_key(cid, cell)] as ScaffoldNode).set_levels(up)
		level = up
	_next_id += 1
	return _spawner.spawn({"id": _next_id, "type": id, "cliff": cid, "row": cell.x, "col": cell.y,
			"level": level, "owner": owner_label}) as Node3D


# Perk: start-of-run gifts (Homestead Plot, Old Scaffolds) go up free for the player.
func free_build(peer_id: int, id: StringName, cid: int, cell: Vector2i) -> bool:
	if not multiplayer.is_server() or not is_free_for(id, cid, cell):
		return false
	var who := _name_of(peer_id)
	_cpu_builder = who
	_do_build(peer_id, id, cid, cell)
	_cpu_builder = ""
	return true


func _name_of(peer_id: int) -> String:
	if _cpu_builder != "":
		return _cpu_builder
	if NetworkManager.players.has(peer_id):
		return str((NetworkManager.players[peer_id] as Dictionary)["name"])
	return NetworkManager.local_name
