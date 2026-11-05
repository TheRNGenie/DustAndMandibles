class_name LootDrop
extends StaticBody3D
## What a bug leaves behind when it's killed up on the plateau (it made it off
## the cliff wall): a little heap of glinting chitin shards and a broken leg or
## two. E to loot it: its shells pay the team pot (shown as chitin; see ResNames). Spawned on every peer by BugManager; the host pays
## out and tells everyone to remove it. Fades away if nobody bothers.

const LIFETIME := 90.0

var loot_id := 0
var chitin := 1
var bug_name := "bug"
var color := Color.WHITE
## Goods a thief stole and dropped here ({res: amount}); they go back to the stockpile.
var stolen: Dictionary = {}
var _t := 0.0
var _mi: MeshInstance3D


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	add_to_group("loot")
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	col.position.y = 0.3
	add_child(col)
	_mi = MeshInstance3D.new()
	_mi.mesh = _heap(color, chitin)
	_mi.material_override = Materials.toon(0.015)
	_mi.scale = Vector3.ONE * 1.6
	add_child(_mi)


static func _heap(shell: Color, n: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 31 + int(shell.r * 100.0)
	var st := MeshKit.begin()
	# Shell plates from the bug, curled and cracked.
	for i in 4:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.4) + Vector3(0, 0.06, 0)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, a).rotated(Vector3.RIGHT, rng.randf_range(-0.6, 0.6)), p),
				Vector3(0.18, 0.05, 0.13), 4, 8, shell.darkened(rng.randf() * 0.2), 0.15, rng)
	# A snapped leg.
	var a0 := Vector3(rng.randf_range(-0.3, 0.3), 0.05, rng.randf_range(-0.3, 0.3))
	MeshKit.add_limb(st, a0, a0 + Vector3(rng.randf_range(-0.4, 0.4), 0.15, rng.randf_range(-0.4, 0.4)), 0.035, shell.darkened(0.4), 5)
	# Glinting teal chitin shards (they glow a little so you spot them).
	for i in mini(3 + n, 10):
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.35) + Vector3(0, 0.1, 0)
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3(rng.randf(), 1, rng.randf()).normalized(), rng.randf() * TAU), p),
				0.0, 0.05, 0.16, 4, Color("#5FE0C8"), false, 0.6)
	return MeshKit.finish(st)


func _process(delta: float) -> void:
	_t += delta
	# A slow bob and spin so it reads as something to pick up.
	_mi.position.y = sin(_t * 2.5) * 0.04
	_mi.rotation.y += delta * 0.6
	if _t > LIFETIME - 3.0:
		_mi.scale = Vector3.ONE * 1.6 * maxf((LIFETIME - _t) / 3.0, 0.01)
	if _t >= LIFETIME:
		queue_free()


func interact_prompt() -> String:
	if not stolen.is_empty():
		return "E: Take back the stolen %s (+%s to the team pot)" % [Economy.describe(stolen), UiStyle.cost(chitin, ResNames.TEAM_ID)]
	return "E: Loot the %s (+%s to the team pot)" % [bug_name.to_lower(), UiStyle.cost(chitin, ResNames.TEAM_ID)]


func local_interact(holding: bool) -> void:
	if holding or BugManager.instance == null:
		return
	BugManager.instance.request_loot(loot_id)
