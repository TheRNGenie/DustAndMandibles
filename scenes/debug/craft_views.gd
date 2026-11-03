extends Node
## Crafted turrets: a debug lineup of crafted designs standing side by side on
## your plateau, posed (heads turned, guns raised), for checking their looks.
## Started by DebugTools when --craftlineup is given with --shot.
##   --craftlineup              a default set of 6 designs covering every part
##   --craftlineup=a,b,c        these designs (ids with or without "craft_"; plain turret ids too)
##   --craftlineup=tiers        Tiers: the five new Mid / Late turrets (gen/tier_builder.gd)
## Options: --craftcam=front|back|near (default front: from the canyon side, 3/4 view),
##   --craftpitch=deg (gun pitch, default 8), --craftyaw=deg (head yaw, default -25).

const DEFAULT := [&"craft_post_rifle_lead", &"craft_swivel_scatter_fire", &"craft_tripod_cannon_acid",
		&"craft_post_nozzle_explosive", &"craft_swivel_cannon_lead", &"craft_tripod_rifle_explosive"]

var world: Node3D


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	for i in 25:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var cid := player.cliff_id if player != null else WorldLayout.WEST
	var ids: Array = DEFAULT
	var spec := GameState.flag_value("--craftlineup")
	if spec != "":
		ids = []
		for s: String in (",".join(TierBuilder.IDS) if spec == "tiers" else spec).split(","):
			if Defs.TURRETS.has(StringName(s)): # Tiers: plain turret ids line up too
				ids.append(StringName(s))
				continue
			ids.append(StringName(s if s.begins_with(CraftTable.PREFIX) else CraftTable.PREFIX + s))
	var cliffs := world.get("cliffs") as CliffBuilder
	var a := Buildable.cell_center(cliffs, cid, Vector2i(3, 6))
	var b := Buildable.cell_center(cliffs, cid, Vector2i(3, 7))
	var along := (b - a).normalized()
	var yaw := WorldLayout.facing_canyon_yaw(cid)
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD # toward the canyon
	var gap := 2.3
	var pitch := deg_to_rad(GameState.flag_value("--craftpitch").to_float()) if GameState.flag_value("--craftpitch") != "" else deg_to_rad(8.0)
	var turn := deg_to_rad(GameState.flag_value("--craftyaw").to_float()) if GameState.flag_value("--craftyaw") != "" else deg_to_rad(-25.0)
	var centre := Vector3.ZERO
	for i in ids.size():
		var id: StringName = ids[i]
		var p := a + along * gap * (float(i) - (ids.size() - 1) * 0.5)
		var cell_ground := Buildable.cell_center(cliffs, cid, Vector2i(3, clampi(6 + roundi((float(i) - (ids.size() - 1) * 0.5) * gap / 2.0), 0, Buildable.COLS - 1)))
		p.y = cell_ground.y
		centre += p / ids.size()
		_pose(id, p, yaw, turn, pitch, Palette.team_color(cid))
		print("[craftview] %s (%s) at %s" % [id, Defs.name_of(id), str(p.snapped(Vector3.ONE * 0.1))])
	if player != null:
		player.global_position = centre - fwd * 14.0 + Vector3.UP * 1.0
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	var right := fwd.cross(Vector3.UP).normalized()
	var width := gap * ids.size()
	match GameState.flag_value("--craftcam"):
		"back":
			cam.global_position = centre - fwd * width * 0.75 + right * 1.5 + Vector3.UP * 2.6
		"near":
			cam.global_position = centre + fwd * maxf(width * 0.8, 3.0) - right * 1.2 + Vector3.UP * 1.9
		_:
			cam.global_position = centre + fwd * width * 0.95 - right * 1.5 + Vector3.UP * 2.6
	cam.look_at(centre + Vector3.UP * 0.95, Vector3.UP)
	cam.current = true


## One design as plain meshes in its parts (like Turret builds it), posed.
func _pose(id: StringName, at: Vector3, yaw: float, turn: float, pitch: float, team: Color) -> void:
	var parts := TurretBuilder.build(id, team)
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = at
	root.rotation.y = yaw
	var base := MeshInstance3D.new()
	base.mesh = parts["base"]
	base.material_override = Materials.toon(0.025)
	root.add_child(base)
	var head := Node3D.new()
	head.position.y = float(parts["head_y"])
	head.rotation.y = turn
	root.add_child(head)
	var hm := MeshInstance3D.new()
	hm.mesh = parts["head"]
	hm.material_override = Materials.toon(0.02)
	head.add_child(hm)
	var gun := Node3D.new()
	gun.position.y = float(parts["gun_y"])
	gun.rotation.x = pitch
	head.add_child(gun)
	var gm := MeshInstance3D.new()
	gm.mesh = parts["gun"]
	gm.material_override = Materials.toon(0.015)
	gun.add_child(gm)
	if parts.has("spin"):
		var sm := MeshInstance3D.new()
		sm.mesh = parts["spin"]
		sm.material_override = Materials.toon(0.012)
		sm.position = parts["spin_at"]
		gm.add_child(sm)
	if parts.has("spin_b"): # Tiers: the Twin Gatling's second cluster
		var sb := MeshInstance3D.new()
		sb.mesh = parts["spin_b"]
		sb.material_override = Materials.toon(0.012)
		sb.position = parts["spin_b_at"]
		gm.add_child(sb)
	# A marker at the muzzle offset, to check it sits at the barrel's mouth.
	if GameState.has_flag("--craftmuzzle"):
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.04
		s.height = 0.08
		m.mesh = s
		m.position = parts["muzzle"]
		gun.add_child(m)
