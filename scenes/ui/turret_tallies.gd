class_name TurretTallies
extends Node
## Kill tallies for each turret. The host works out which turret landed each
## killing blow (by its "Owner's Turret Name" source, and the nearest aim point
## when the same owner has several of one kind) and tells every peer. The count
## shows on the turret's prompt, and at 50 / 100 / 500 kills the turret earns a
## little painted plank on its back: tally marks, then red paint, then brass.
## Lives in the world under a fixed name so its RPCs line up on every peer.

## Kills that earn a plank, in order.
const RANKS: Array[int] = [50, 100, 500]

## turret node name -> kills. Read by Turret.interact_prompt via kills_of().
static var counts: Dictionary = {}


func _ready() -> void:
	counts = {}


## Host: start watching bugs die.
func bind(bugs: BugManager) -> void:
	if bugs == null or not bugs.multiplayer.is_server():
		return
	bugs.child_entered_tree.connect(func(n: Node) -> void:
		var b := n as Bug
		if b != null and not b.died.is_connected(_on_bug_died):
			b.died.connect(_on_bug_died))


static func kills_of(turret: Node) -> int:
	return int(counts.get(String(turret.name), 0))


## " · 132 kills" for a prompt's title line ("" before the first kill).
static func prompt_suffix(turret: Node) -> String:
	var n := kills_of(turret)
	if n <= 0:
		return ""
	return "  ·  %d %s" % [n, "kill" if n == 1 else "kills"]


func _on_bug_died(bug: Bug, source: String, source_cliff: int) -> void:
	if source == "":
		return
	var best: Turret = null
	var best_d := INF
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t == null or t.def == null or t.cliff_id != source_cliff:
			continue
		var own := "%s's %s" % [t.owner_name, t.def.display_name]
		if own != source and own + SpecialShotRules.FIRE_SHELL != source: # Twin Mortar's fire shell counts too
			continue
		var d := t.aim_point.distance_squared_to(bug.global_position)
		if d < best_d:
			best_d = d
			best = t
	if best != null:
		_set_kills.rpc(String(best.name), kills_of(best) + 1)


@rpc("authority", "call_local", "reliable")
func _set_kills(turret_name: String, n: int) -> void:
	var before := int(counts.get(turret_name, 0))
	counts[turret_name] = n
	if _rank(n) == _rank(before):
		return
	for t: Node in get_tree().get_nodes_in_group("turrets"):
		if String(t.name) == turret_name:
			_decorate(t as Node3D, _rank(n))


static func _rank(n: int) -> int:
	var r := 0
	for k in RANKS:
		if n >= k:
			r += 1
	return r


## A plank on the back of the base (the side you stand on; turrets face -Z).
static func _decorate(turret: Node3D, rank: int) -> void:
	if turret == null:
		return
	var old := turret.get_node_or_null("KillPlank")
	if old != null:
		old.queue_free()
	if rank <= 0:
		return
	var base: MeshInstance3D = null
	for c in turret.get_children():
		if c is MeshInstance3D:
			base = c
			break
	var box := base.get_aabb() if base != null and base.mesh != null else AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.name = "KillPlank"
	mi.mesh = plank_mesh(rank)
	mi.material_override = Materials.toon(0.01)
	mi.position = Vector3(0.0, clampf(box.get_center().y, 0.35, 0.8), box.end.z + 0.03)
	turret.add_child(mi)


## The plank itself: weathered wood with chalk tally marks (rank 1), the same
## daubed in red paint with a second bundle (rank 2), or a brass plate with a
## star (rank 3). Faces +Z.
static func plank_mesh(rank: int) -> ArrayMesh:
	var st := MeshKit.begin()
	var plate := Palette.WOOD if rank < 3 else Color("#C9A13B")
	var rim := Palette.OUTLINE if rank < 3 else Color("#7A5A1E")
	MeshKit.add_box(st, Transform3D(Basis(), Vector3.ZERO), Vector3(0.5, 0.17, 0.03), rim)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0, 0.008)), Vector3(0.46, 0.13, 0.03), plate)
	if rank < 3:
		var paint := Palette.BONE if rank == 1 else Color("#B8352A")
		var bundles := 1 if rank == 1 else 2
		for b in bundles:
			var x0 := (-0.075 if bundles == 1 else -0.17 + b * 0.18)
			for i in 4:
				MeshKit.add_box(st, Transform3D(Basis(), Vector3(x0 + i * 0.035, 0, 0.026)), Vector3(0.012, 0.09, 0.006), paint)
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, -1.0), Vector3(x0 + 0.052, 0, 0.03)), Vector3(0.012, 0.15, 0.006), paint)
	else:
		# A five-point star struck into the brass.
		for k in 5:
			var a := float(k) * TAU / 5.0
			MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, a), Vector3(0, 0, 0.026)).translated_local(Vector3(0, 0.025, 0)),
					Vector3(0.022, 0.05, 0.006), Palette.WOOD_DARK)
	return MeshKit.finish(st)
