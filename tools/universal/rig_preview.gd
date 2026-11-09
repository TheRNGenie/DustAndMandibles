extends "res://tools/universal/uni_preview.gd"
## The universal turrets' fal models (RiggedTurret) on the studio stage, put
## together the way Turret.setup does (base, head on the yaw pivot, gun on the
## pitch pivot, spin cluster on the gun) and posed, so a bad split shows: a piece
## left behind when the head turns or the gun tilts, barrels off their axis.
##   rest   as built
##   aim    head turned 40 deg, gun tilted 15 deg down, barrels spun 60 deg
##   up     gun raised to the empty rest angle (45 deg up), head turned -30 deg
## A red dot marks each muzzle.
##
##   Godot --path . --screen 0 --windowed --resolution 1280x720 -s res://tools/universal/rig_preview.gd
##       -- --out=<dir> [--ids=id,id|cliff|air|house|ground|crewed|all] [--views=quarter,side]


func _run() -> void:
	_out = _arg("--out", OS.get_user_data_dir() + "/rig")
	DirAccess.make_dir_recursive_absolute(_out)
	var pick := _arg("--ids", "all")
	var ids: Array[StringName] = []
	var groups := {"cliff": Defs.UNIVERSAL_CLIFF, "air": Defs.UNIVERSAL_AA, "house": Defs.UNIVERSAL_LAST,
		"ground": Defs.UNIVERSAL_OBSTRUCTIONS, "crewed": Defs.UNIVERSAL_CREWED}
	if pick == "all":
		for g: String in groups:
			ids.append_array(groups[g])
	elif groups.has(pick):
		ids.append_array(groups[pick])
	else:
		for s: String in pick.split(",", false):
			ids.append(StringName(s.strip_edges()))
	var views := _arg("--views", "quarter,side").split(",", false)
	var stage := _stage()
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	for id: StringName in ids:
		if not RiggedTurret.has(id):
			print("[rig] %s: no model" % id)
			continue
		var parts := RiggedTurret.build(id, Color.WHITE)
		var holder := Node3D.new()
		stage.add_child(holder)
		var base := MeshInstance3D.new()
		base.mesh = parts["base"]
		holder.add_child(base)
		var head := Node3D.new()
		head.position.y = float(parts["head_y"])
		holder.add_child(head)
		var head_mi := MeshInstance3D.new()
		head_mi.mesh = parts["head"]
		head.add_child(head_mi)
		var gun := Node3D.new()
		gun.position.y = float(parts["gun_y"])
		head.add_child(gun)
		var gun_mi := MeshInstance3D.new()
		gun_mi.mesh = parts["gun"]
		gun.add_child(gun_mi)
		var spins: Array[Node3D] = []
		for k: String in ["spin", "spin_b"]:
			if parts.has(k):
				var sp := MeshInstance3D.new()
				sp.mesh = parts[k]
				sp.position = parts[k + "_at"]
				if parts.has(k + "_basis"):
					sp.basis = parts[k + "_basis"]
				gun_mi.add_child(sp)
				spins.append(sp)
		for k: String in ["muzzle", "muzzle_b"]:
			if parts.has(k):
				var dot := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.04
				sm.height = 0.08
				dot.mesh = sm
				var m := StandardMaterial3D.new()
				m.albedo_color = Color.RED
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				dot.material_override = m
				dot.position = parts[k]
				gun.add_child(dot)
		var box := _aabb(holder)
		print("[rig] %s: %.2f x %.2f x %.2f m, head_y %.2f gun_y %.2f, spin %d, fixed yaw %s" % [id, box.size.x, box.size.y, box.size.z,
				float(parts["head_y"]), float(parts["gun_y"]), spins.size(), str(parts.get("fixed_yaw", false))])
		var tilts := (parts["gun"] as Mesh).get_surface_count() > 0 # (no gun part: it turns but never tilts)
		for st: String in ["rest", "aim", "up"]:
			head.rotation.y = 0.0
			gun.rotation.x = 0.0
			for sp in spins:
				sp.basis = sp.basis.orthonormalized()
			match st:
				"aim":
					if not bool(parts.get("fixed_yaw", false)):
						head.rotation.y = deg_to_rad(40.0)
					gun.rotation.x = deg_to_rad(-15.0) if tilts else 0.0
					for sp in spins:
						sp.rotate_object_local(Vector3.BACK, deg_to_rad(60.0))
				"up":
					if not bool(parts.get("fixed_yaw", false)):
						head.rotation.y = deg_to_rad(-30.0)
					gun.rotation.x = UniKit.REST_UP if tilts else 0.0
			for v: String in views:
				_place(cam, v, box)
				for i in 3:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s_%s_%s.png" % [_out, id, st, v])
			for sp in spins: # back to the built turn for the next pose
				if st == "aim":
					sp.rotate_object_local(Vector3.BACK, deg_to_rad(-60.0))
		holder.free()
	quit()
