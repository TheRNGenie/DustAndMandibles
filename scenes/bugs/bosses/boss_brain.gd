class_name BossBrain
extends RefCounted
## One boss's mechanic. Every peer makes one for each boss bug (Bug.setup); the
## host's copy decides (think, hits, kills), every copy draws (visual, on_event).
## The host tells the other copies what happened through BossFx.send, so the
## telegraphs, projectiles and breakable parts look the same on every screen.
## Each boss has its own script in this folder, named after its bug id.
## The Iron Tumbleweed (the first boss) keeps its rules in Bug itself.

## Every live boss brain on this peer (BossFx hooks walk these).
static var active: Array[BossBrain] = []

var bug: Bug
## Seconds since this boss appeared (local).
var age := 0.0


static func make(b: Bug) -> BossBrain:
	var path := "res://scenes/bugs/bosses/%s.gd" % b.def.base_id()
	if not ResourceLoader.exists(path):
		return null
	var brain := (load(path) as GDScript).new() as BossBrain
	brain.bug = b
	return brain


## Is a boss with this id alive on this peer?
static func any_alive(id: StringName) -> bool:
	for b in active:
		if b.bug != null and is_instance_valid(b.bug) and b.bug.def.id == id and b.bug.is_alive():
			return true
	return false


## Bosses that leave their tunnel some other way (fliers): {"state", "pos"} or {}.
static func spawn_override(id: StringName, mouth: Vector3, way_out: Vector3) -> Dictionary:
	if id == &"locust_lord":
		return {"state": Bug.State.FLYING, "pos": mouth + way_out * 2.5 + Vector3(0, 3.0, 0)}
	return {}


# ------------------------------------------------------------------ lifecycle (Bug calls these)

## Every peer, once the bug is in the tree: build any extra parts.
func attach() -> void:
	active.append(self)
	_attach()


## Every peer, when the bug leaves the tree.
func detach() -> void:
	active.erase(self)
	_detach()


func _attach() -> void:
	pass


func _detach() -> void:
	pass


## Host, each update. Return true when this replaces the bug's usual brain.
func think(_delta: float) -> bool:
	return false


## Every peer, each update (also while hidden underground).
func visual(_delta: float) -> void:
	pass


## Host: a hit on the body for `damage`; returns the damage the body takes.
func body_damage(damage: float, _point: Vector3, _source: String, _source_cliff: int) -> float:
	return damage


## Every peer: something the host's brain announced (BossFx.send).
func on_event(_kind: StringName, _args: Array) -> void:
	pass


## Host: the boss reached the lip.
func on_crest() -> void:
	pass


## Host: the boss died (before it is freed).
func on_death(_source: String, _source_cliff: int) -> void:
	pass


## Host: another bug died.
func on_bug_died(_dead: Bug) -> void:
	pass


## Host: a splash went off somewhere.
func on_splash(_cliff: int, _center: Vector3, _radius: float, _damage: float, _source: String, _source_cliff: int) -> void:
	pass


## Host: a Water Cannon (on the turret `t`) hit this boss.
func on_water_hit(_t: Turret) -> void:
	pass


## Turrets can't lock on right now (the Mirage Mantis fading out).
func untargetable() -> bool:
	return false


## Where a turret at `from` aims (the body, unless the boss has parts to shoot).
func aim_for(_from: Vector3) -> Vector3:
	return bug.global_position


## Movement multiplier from the mechanic (a crippled Strider limps).
func speed_mult() -> float:
	return 1.0


## A few words after the name on the HUD boss bar ("BOULDER 60%"), or "".
func hud_status() -> String:
	return ""


# ------------------------------------------------------------------ helpers

func host() -> bool:
	return bug.is_inside_tree() and bug.multiplayer.is_server()


func send(kind: StringName, args: Array = []) -> void:
	if BossFx.instance != null:
		BossFx.instance.send(bug, kind, args)


func fx() -> BossFx:
	return BossFx.instance


## A point on the body, in the bug node's space (body units times the bug's scale).
func local(p: Vector3) -> Vector3:
	return p * float(bug.spec["scale"]) * bug.grow


## The same point in world space.
func world(p: Vector3) -> Vector3:
	return bug.global_transform * local(p)


## Living turrets on the cliff across from this boss (the ones shooting at it),
## within `reach` metres.
func far_turrets(reach: float = 120.0) -> Array[Turret]:
	var out: Array[Turret] = []
	for n: Node in bug.get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t == null or t.cliff_id == bug.cliff_id or t.health.dead or t.def.guards_plateau:
			continue
		if t.global_position.distance_to(bug.global_position) <= reach:
			out.append(t)
	return out


## Host: spawns small bugs around the boss (climbing beside it, or on its plateau).
func spawn_minions(id: StringName, count: int, spread: float = 2.0) -> void:
	var bm := BugManager.instance
	if bm == null:
		return
	for i in count:
		var z := clampf(bug.lane_z + randf_range(-spread, spread), -WorldLayout.PLATEAU_WIDTH * 0.5 + 1.5, WorldLayout.PLATEAU_WIDTH * 0.5 - 1.5)
		match bug.state:
			Bug.State.CLIMBING, Bug.State.CRESTING:
				bm.spawn_at(id, bug.cliff_id, bug.lane, z, clampf(bug.climb_y + randf_range(-1.5, 1.0), 0.0, WorldLayout.CLIFF_HEIGHT - 1.0), Bug.State.CLIMBING, Vector3.ZERO)
			Bug.State.BREACHING:
				var p := bug.ground_pos + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
				bm.spawn_at(id, bug.cliff_id, bug.lane, z, 0.0, Bug.State.BREACHING, p)
			_:
				var q := bug.ground_pos + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
				bm.spawn_at(id, bug.cliff_id, bug.lane, z, 0.0, Bug.State.CROSSING, q)


## Living bugs of a kind (host bookkeeping for caps).
func count_alive(id: StringName) -> int:
	var n := 0
	for c in bug.get_parent().get_children():
		var b := c as Bug
		if b != null and b.def.id == id and b.is_alive():
			n += 1
	return n


## Credits shown in the feed: "Logan's Gatling Post" -> as is; "" -> "Someone".
static func who(source: String) -> String:
	return source if source != "" else "Someone"
