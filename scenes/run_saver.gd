class_name RunSaver
extends Node
## Host: autosaves the run (RunSave) at the start of every build phase, and
## rebuilds the world from a save when the game was started with "Continue last
## run" (RunSave.pending). Lives in the world so it can reach the builds, the
## houses, the wells and the players.

var world: Node3D
## The host is putting a saved run back together: don't autosave over it yet.
var _resuming := false
## Latest hunger/thirst reported by each cliff's player ({cliff: {food, water}}).
var _vitals: Dictionary = {}


func _ready() -> void:
	GameState.phase_changed.connect(_on_phase)


func _on_phase(p: GameState.Phase) -> void:
	if p != GameState.Phase.BUILD or not multiplayer.is_server() or _resuming:
		return
	# Remote players own their hunger and thirst: ask, then save once the
	# answers are in (everything else from this phase change has run by then).
	if NetworkManager.is_online() and not multiplayer.get_peers().is_empty():
		_ask_vitals.rpc()
		get_tree().create_timer(0.75).timeout.connect(save_now)
	else:
		save_now.call_deferred()


## Host: writes the run as it stands now.
func save_now() -> void:
	if not multiplayer.is_server() or GameState.phase == GameState.Phase.GAME_OVER or GameState.phase == GameState.Phase.LOBBY:
		return
	if RunSave.write(capture()):
		print("[save] run saved at wave %d (%s)" % [GameState.wave, RunSave.path()])


@rpc("authority", "call_remote", "reliable")
func _ask_vitals() -> void:
	var p := _local_player()
	if p != null and p.vitals != null:
		_tell_vitals.rpc_id(1, p.cliff_id, p.vitals.food, p.vitals.water)


@rpc("any_peer", "call_remote", "reliable")
func _tell_vitals(cliff: int, food: float, water: float) -> void:
	if multiplayer.is_server():
		_vitals[clampi(cliff, 0, 1)] = {"food": clampf(food, 0.0, 1.0), "water": clampf(water, 0.0, 1.0)}


## Every peer: the host hands back a player's saved hunger and thirst.
@rpc("authority", "call_local", "reliable")
func _set_vitals(cliff: int, food: float, water: float) -> void:
	var p := _local_player()
	if p != null and p.cliff_id == cliff and p.vitals != null:
		p.vitals.food = food
		p.vitals.water = water
		p.vitals.needs_changed.emit(food, water)


func _player_on(peer_id: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id and n is Player:
			return n as Player
	return null


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority() and n is Player:
			return n as Player
	return null


# ------------------------------------------------------------------ capture

## The whole run as RunSave data.
func capture() -> Dictionary:
	var data := {"wave": GameState.wave, "phase": GameState.phase, "endless": GameState.endless,
			"weather": GameState.weather, "cpu_quality": NetworkManager.cpu_quality,
			"saved_at": int(Time.get_unix_time_from_system()), "map": String(WorldLayout.map().id)}
	var homes: Array = []
	for cid in WorldLayout.cliff_count():
		var h := Homestead.of(cid)
		homes.append({"hp": GameState.homestead_hp[cid], "max": GameState.homestead_max[cid],
				"floors": h.floors if h != null else 1, "boarded": h != null and h.boarded,
				"reinforced": h != null and h.reinforced, "tower": h != null and h.tower})
	data["homesteads"] = homes
	var builds: Array = []
	var bm := BuildManager.instance
	if bm != null:
		for n: Node in bm.get_children():
			var b := _capture_build(n)
			if not b.is_empty():
				builds.append(b)
	data["builds"] = builds
	var wells: Array = []
	for n: Node in world.find_children("*", "WaterSource", true, false):
		var w := n as WaterSource
		if w.build_id == &"" and not w.is_queued_for_deletion():
			wells.append({"path": str(world.get_path_to(w)), "stored": w.stored, "working": w.working})
	data["wells"] = wells
	data["economy"] = {"stock": Economy.ledger.stock, "shared": Economy.shared, "gained": Economy.gained,
			"cpu_spent": Economy.cpu_spent, "cpu_share": Economy.cpu_share}
	var players := _vitals.duplicate()
	var me := _local_player()
	if me != null and me.vitals != null:
		players[me.cliff_id] = {"food": me.vitals.food, "water": me.vitals.water}
	data["players"] = players
	# Perks: each human's locked loadout and Barn Raising, and the guns they own.
	var perks := {}
	var guns := {}
	for cid in WorldLayout.cliff_count():
		var peer := Perks.peer_for_cliff(cid)
		if peer <= 0:
			continue
		perks[cid] = Perks.run_state_of(peer)
		if GunShop.loadouts.has(peer):
			guns[cid] = GunShop.loadouts[peer]
	data["perks"] = perks
	data["guns"] = guns
	data["brands"] = Brand.save_state() # Brand: each cliff's brand
	var seen: Variant = WaveDirector.get("boss_seen")
	data["bosses_seen"] = (seen as Array).duplicate() if seen is Array else []
	return data


func _capture_build(n: Node) -> Dictionary:
	if n.is_queued_for_deletion() or not (n is Node3D) or n.get("cliff_id") == null or n.get("cell") == null:
		return {}
	var cell: Vector2i = n.get("cell")
	var b := {"cliff": int(n.get("cliff_id")), "row": cell.x, "col": cell.y, "level": 0, "owner": ""}
	if n is Turret:
		var t := n as Turret
		if t.health.dead:
			return {}
		b.merge({"type": t.def.id, "level": t.level, "owner": t.owner_name, "tier": t.tier, "hp": t.health.hp,
				"perk": [t.perk_range, t.perk_rate, t.perk_hp]}, true)
	elif n is ScaffoldNode:
		b.merge({"type": &"scaffold", "levels": (n as ScaffoldNode).levels}, true)
	elif n is StructureNode:
		var s := n as StructureNode
		if s.health.dead:
			return {}
		b.merge({"type": s.def.id, "owner": s.owner_name, "hp": s.health.hp, "armed": s.armed}, true)
	elif n is CropPlot:
		var c := n as CropPlot
		b["type"] = c.build_id
		if c.crop_def != null:
			b["crop"] = {"id": c.crop_def.id, "stage": c.growth.stage, "progress": c.growth.progress, "watered": c.growth.watered}
	elif n is WaterSource:
		b.merge({"type": (n as WaterSource).build_id, "stored": (n as WaterSource).stored}, true)
	else:
		return {}
	return b


# ------------------------------------------------------------------ resume

## Host: starts the saved run instead of a new one. False if there was nothing to resume.
func resume(data: Dictionary) -> bool:
	if data.is_empty() or not multiplayer.is_server():
		return false
	_resuming = true
	Perks.resumed = true # the saved run already had its start-of-run gifts
	# Bosses already met, before start_run plans the saved wave (no early repeats).
	if WaveDirector.get("boss_seen") is Array:
		WaveDirector.set("_last_wave", 0)
		WaveDirector.set("boss_seen", (data.get("bosses_seen", []) as Array).duplicate())
	GameState.start_run(int(data["wave"])) # [Foundation hook] start at the saved wave
	# Perks lock everyone back into the loadouts they started this run with.
	var perks: Dictionary = data["perks"]
	for cid: int in perks:
		var peer := Perks.peer_for_cliff(cid)
		if peer > 0:
			Perks.restore_run_state(peer, perks[cid])
	Brand.restore_state(data.get("brands", {})) # Brand: everyone rides with the brand they saved with
	var guns: Dictionary = data["guns"]
	for cid: int in guns:
		var peer := Perks.peer_for_cliff(cid)
		if peer <= 0:
			continue
		GunShop.loadouts[peer] = (guns[cid] as Dictionary).duplicate()
		var pl := _player_on(peer)
		for w: StringName in guns[cid]:
			if pl != null and Gun.weapon(w) != null:
				pl.net.grant_weapon(w, int(guns[cid][w]))
	GameState.endless = bool(data["endless"])
	# The houses first (their storeys carry the house-turret mounts).
	var homes: Array = data["homesteads"]
	for cid in mini(homes.size(), WorldLayout.cliff_count()):
		var h: Dictionary = homes[cid]
		var home := Homestead.of(cid)
		if home != null:
			home._set_state.rpc(int(h["floors"]), bool(h["boarded"]), bool(h["reinforced"]), bool(h["tower"]))
		if float(h["max"]) > 0.0:
			GameState.homestead_max[cid] = float(h["max"])
			GameState.homestead_hp[cid] = clampf(float(h["hp"]), 1.0, float(h["max"]))
	GameState._sync_homesteads_reliable.rpc(GameState.homestead_hp, GameState.homestead_max)
	_restore_builds(data["builds"])
	for w: Dictionary in data["wells"]:
		var well := world.get_node_or_null(NodePath(str(w["path"]))) as WaterSource
		if well != null:
			well._sync.rpc(int(w["stored"]), bool(w["working"]))
	var eco: Dictionary = data["economy"]
	Economy.ledger.stock = RunSave.fit_stock(eco["stock"], bool(eco["shared"]), Economy.shared)
	if Economy.shared and bool(eco["shared"]):
		Economy.gained = (eco["gained"] as Dictionary).duplicate()
		Economy.cpu_spent = (eco["cpu_spent"] as Dictionary).duplicate(true)
	Economy._push()
	var players: Dictionary = data["players"]
	for cid: int in players:
		var p: Dictionary = players[cid]
		_vitals[cid] = p
		_set_vitals.rpc(cid, float(p["food"]), float(p["water"]))
	print("[save] resumed the run at wave %d: %d of %d builds back up, scrap W%d E%d" % [GameState.wave,
			BuildManager.instance.get_child_count() - 1 if BuildManager.instance != null else 0,
			(data["builds"] as Array).size(), Economy.amount(0, &"scrap"), Economy.amount(1, &"scrap")])
	set_deferred("_resuming", false)
	return true


func _restore_builds(builds: Array) -> void:
	var bm := BuildManager.instance
	if bm == null:
		return
	# Scaffolds before the turrets that stand on them.
	var ordered := builds.filter(func(b: Dictionary) -> bool: return b["type"] == &"scaffold")
	ordered.append_array(builds.filter(func(b: Dictionary) -> bool: return b["type"] != &"scaffold"))
	for b: Dictionary in ordered:
		var id: StringName = b["type"]
		var n := bm.restore_built(id, int(b["cliff"]), Vector2i(int(b["row"]), int(b["col"])), int(b["level"]), str(b["owner"]))
		if n == null:
			continue
		if n is Turret:
			var t := n as Turret
			var perk: Array = b["perk"]
			t.perk_range = float(perk[0])
			t.perk_rate = float(perk[1])
			t.perk_hp = float(perk[2])
			t.tier = clampi(int(b["tier"]), 0, TurretDef.MAX_TIER)
			t.health.setup(t.def.hp_at(t.tier) * t.perk_hp)
			if float(b["hp"]) > 0.0:
				t.health.hp = minf(float(b["hp"]), t.health.max_hp)
		elif n is ScaffoldNode:
			(n as ScaffoldNode).set_levels(int(b["levels"]))
		elif n is StructureNode:
			var s := n as StructureNode
			if float(b["hp"]) > 0.0:
				s.health.hp = minf(float(b["hp"]), s.health.max_hp)
			s.armed = bool(b["armed"])
		elif n is CropPlot:
			var crop: Dictionary = b.get("crop", {})
			if not crop.is_empty() and Defs.crop(crop["id"]) != null:
				(n as CropPlot)._sync.rpc(crop["id"], int(crop["stage"]), float(crop["progress"]), bool(crop["watered"]))
		elif n is WaterSource:
			var ws := n as WaterSource
			ws._sync.rpc(int(b["stored"]), ws.working)
