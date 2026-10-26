class_name StructureNode
extends StaticBody3D
## A trap or wall built on your own plateau to handle breachers (turrets can't).
## Barbed wire slows, bear traps root (E to re-arm), dynamite crates explode when
## shot, palisades soak up chewing, lanterns light the night and reveal Burrow Ticks.

const TICK := 0.25

static var vfx: VfxPool

var def: StructureDef
var cliff_id: int = 0
var cell: Vector2i
var owner_name := ""
var radius: float = 1.0
var health: Health
var armed := true
var _light: OmniLight3D
var _t := 0.0


func setup(d: StructureDef, cid: int, c: Vector2i, pos: Vector3, owner_label: String) -> void:
	def = d
	cliff_id = cid
	cell = c
	owner_name = owner_label
	radius = d.radius if d.kind == StructureDef.Kind.PALISADE else 0.8
	position = pos
	rotation.y = WorldLayout.facing_canyon_yaw(cid)
	var walk_through := d.kind == StructureDef.Kind.BARBED_WIRE or d.kind == StructureDef.Kind.BEAR_TRAP \
			or d.kind == StructureDef.Kind.DYNAMITE_CRATE
	collision_layer = WorldLayout.LAYER_TRAP if walk_through else WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.mesh = StructureBuilder.build(d.kind)
	mi.material_override = Materials.toon(0.02)
	add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.2, 0.5) if d.kind == StructureDef.Kind.PALISADE else Vector3(1.0, 0.8, 1.0)
	col.shape = shape
	col.position.y = shape.size.y * 0.5
	add_child(col)
	health = Health.new()
	health.name = "Health"
	health.setup(d.max_hp)
	add_child(health)
	health.died.connect(_on_destroyed)
	if d.kind == StructureDef.Kind.LANTERN:
		_light = OmniLight3D.new()
		_light.position = Vector3(0.5, 1.8, 0)
		_light.light_color = Palette.GLOW_YELLOW
		_light.omni_range = d.radius
		_light.light_energy = 0.0
		add_child(_light)
		add_to_group("lanterns")
		radius = 0.6
	add_to_group("structures")
	var cfg := SceneReplicationConfig.new()
	for p: String in [".:armed", "Health:hp"]:
		cfg.add_property(NodePath(p))
		cfg.property_set_spawn(NodePath(p), true)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	sync.replication_interval = 0.2
	add_child(sync)


## Lantern radius for revealing Burrow Ticks.
func reveal_radius() -> float:
	return def.radius


func _process(_delta: float) -> void:
	if _light != null:
		var night := GameState.phase == GameState.Phase.WAVE or GameState.phase == GameState.Phase.WARNING
		_light.light_energy = move_toward(_light.light_energy, 2.5 if night else 0.0, 0.05)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	match def.kind:
		StructureDef.Kind.BARBED_WIRE:
			for b in _breachers_near(def.radius):
				b.status.slow(0.5, TICK * 2.0)
		StructureDef.Kind.BEAR_TRAP:
			if armed:
				var near := _breachers_near(def.radius)
				if not near.is_empty():
					near[0].status.root(4.0)
					near[0].health.take_damage(20.0, owner_name + "'s bear trap", cliff_id)
					armed = false
					_snap.rpc()


func _breachers_near(r: float) -> Array[Bug]:
	var out: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b.cliff_id != cliff_id or b.state != Bug.State.BREACHING or not b.is_alive():
			continue
		if b.global_position.distance_to(global_position) <= r + float(b.spec["body_radius"]):
			out.append(b)
	return out


func interact_prompt() -> String:
	var text := "%s  %d/%d HP" % [def.display_name, int(health.hp), int(health.max_hp)]
	if def.kind == StructureDef.Kind.BEAR_TRAP:
		text += "  - armed" if armed else "\nE: re-arm the trap"
	elif def.kind == StructureDef.Kind.DYNAMITE_CRATE:
		text += "\nShoot it when breachers are close!"
	return text


func local_interact(_holding: bool) -> void:
	if def.kind == StructureDef.Kind.BEAR_TRAP and not armed:
		_request_arm.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_arm() -> void:
	if multiplayer.is_server():
		armed = true


## Host: shot by a player (via the revolver's apply_hit path).
func apply_hit(_damage: float, _point: Vector3, _dir: Vector3, _pierce: bool = false,
		source: String = "", source_cliff: int = -1) -> void:
	if multiplayer.is_server() and def.kind == StructureDef.Kind.DYNAMITE_CRATE:
		_explode(source, source_cliff)


## Host: breachers chewing on it.
func structure_damage(amount: float, source: String) -> void:
	if multiplayer.is_server():
		health.take_damage(amount, source)


func _explode(source: String, source_cliff: int) -> void:
	if health.dead:
		return
	var who := source if source != "" else owner_name
	for b in _breachers_near(def.radius):
		b.receive_hit(80.0, global_position, (b.global_position - global_position).normalized(), true, 1.0,
				who + "'s dynamite crate", source_cliff)
	_boom.rpc()
	health.dead = true
	BuildManager.instance.on_structure_destroyed(self)


func _on_destroyed(_source: String, source_cliff: int) -> void:
	if not multiplayer.is_server():
		return
	if def.kind == StructureDef.Kind.DYNAMITE_CRATE:
		for b in _breachers_near(def.radius):
			b.receive_hit(80.0, global_position, Vector3.UP, true, 1.0, "Dynamite crate", source_cliff)
		_boom.rpc()
	BuildManager.instance.on_structure_destroyed(self)


@rpc("authority", "call_local", "reliable")
func _snap() -> void:
	Audio.play_at(&"armor_ping", global_position)


@rpc("authority", "call_local", "reliable")
func _boom() -> void:
	Audio.play_at(&"dynamite", global_position)
	if vfx != null:
		vfx.pop(global_position + Vector3.UP * 0.5, Palette.GLOW_YELLOW, 3.0)
		vfx.pop(global_position + Vector3.UP * 0.5, Palette.WOOD, 2.0)
