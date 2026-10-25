class_name BugManager
extends Node3D
## Spawns and tracks bugs (host decides, MultiplayerSpawner replicates), pays out
## loot when they die, and draws deaths and acid spit on every peer.

signal bug_killed(bug_name: String, bug_cliff: int, source: String, source_cliff: int, loot: Dictionary)

var vfx: VfxPool
var _spawner: MultiplayerSpawner
var _next_id := 0


func _ready() -> void:
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "BugSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(self)
	_spawner.spawn_function = _spawn_bug
	LaneClimber.spit_requested = _on_spit


## Host only: spawns `count` bugs of a type at the bottom of a lane.
func spawn_group(bug_id: StringName, count: int, cliff: int, lane: int) -> void:
	if not multiplayer.is_server():
		return
	var cfg := Defs.WAVE_CONFIG
	for i in count:
		if alive_count() >= cfg.max_active_bugs:
			return
		var z := WorldLayout.LANE_Z[lane] + randf_range(-1.6, 1.6)
		var y := -float(i) * 0.9 # stagger groups so they climb in a column
		_next_id += 1
		_spawner.spawn({"id": _next_id, "bug": bug_id, "cliff": cliff, "lane": lane,
				"z": z, "y": y, "hp": cfg.hp_multiplier})


func _spawn_bug(data: Variant) -> Node:
	var d := data as Dictionary
	var bug := Bug.new()
	bug.name = "Bug%d" % int(d["id"])
	bug.setup(Defs.bug(StringName(d["bug"])), int(d["cliff"]), int(d["lane"]),
			float(d["z"]), float(d["y"]), float(d["hp"]))
	if multiplayer.is_server():
		bug.died.connect(_on_bug_died)
	return bug


func alive_count() -> int:
	var n := 0
	for c in get_children():
		if c is Bug and (c as Bug).is_alive():
			n += 1
	return n


## Living bugs climbing a given cliff (for turret targeting).
func climbers_on(cliff: int) -> Array[Bug]:
	var out: Array[Bug] = []
	for c in get_children():
		var b := c as Bug
		if b != null and b.is_alive() and b.is_climbing() and b.cliff_id == cliff:
			out.append(b)
	return out


func _on_bug_died(bug: Bug, source: String, source_cliff: int) -> void:
	# Loot lands on the cliff the bug was climbing: your turrets earn for your partner.
	var loot := {&"scrap": bug.def.scrap_drop, &"chitin": bug.def.chitin_drop}
	Economy.earn(bug.cliff_id, loot)
	_pop.rpc(bug.global_position, bug.def.shell_color, float(bug.spec["scale"]))
	_announce_kill.rpc(bug.def.display_name, bug.cliff_id, source, source_cliff, bug.def.scrap_drop)
	bug.queue_free()


@rpc("authority", "call_local", "reliable")
func _pop(pos: Vector3, color: Color, size: float) -> void:
	if vfx != null:
		vfx.pop(pos, color, size)
	Audio.play_at(&"bug_pop", pos)


@rpc("authority", "call_local", "reliable")
func _announce_kill(bug_name: String, bug_cliff: int, source: String, source_cliff: int, scrap: int) -> void:
	bug_killed.emit(bug_name, bug_cliff, source, source_cliff, {&"scrap": scrap})


# ------------------------------------------------------------------ spitter acid

## Host: a spitter lobs acid at a random turret on the cliff it faces.
func _on_spit(bug: Bug, damage: float, max_range: float) -> void:
	var targets: Array[Node3D] = []
	for s: Node in get_tree().get_nodes_in_group("turrets"):
		var t := s as Node3D
		if int(t.get("cliff_id")) != bug.cliff_id and t.global_position.distance_to(bug.global_position) < max_range:
			targets.append(t)
	if targets.is_empty():
		return
	var target := targets[randi() % targets.size()]
	var flight := 1.2
	_draw_spit.rpc(bug.global_position, target.global_position + Vector3.UP, flight)
	get_tree().create_timer(flight).timeout.connect(func() -> void:
		if is_instance_valid(target) and target.has_method("structure_damage"):
			target.call("structure_damage", damage, "Spitter acid"))


@rpc("authority", "call_local", "reliable")
func _draw_spit(from: Vector3, to: Vector3, flight: float) -> void:
	Audio.play_at(&"acid_spit", from)
	if vfx != null:
		vfx.acid_blob(from, to, flight)
