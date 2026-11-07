extends Node
## Map screenshots (debug): a free camera anywhere, for looking at whole maps.
##   --mapcam=x,y,z,tx,ty,tz   camera at (x,y,z) looking at (tx,ty,tz)
##   --mapcam=overhead          high over the middle of the map, looking down
##   --mapcam=orbit:deg,dist,height   round the middle at a compass bearing
##   --mapcam=waterworks:N      cliff N's waterworks (well, generator, water tower)
##   --mapcam=well:N[:run][:side]  close on cliff N's pump jack (run: shown pumping)
##   --mapshot=<png> [--seconds=N] [--keephud] [--turrets]  save and quit
##   --rangecheck               print, per cliff and grid column, whether each
##                              cross-cliff turret can reach the cliff it covers
## Load with preload("res://scenes/debug/map_views.gd").

var world: Node3D


func _ready() -> void:
	if GameState.has_flag("--rangecheck"):
		_range_check.call_deferred()
		return
	_shoot()


func _shoot() -> void:
	for i in 20:
		await get_tree().process_frame
	var m := WorldLayout.map()
	var spec := GameState.flag_value("--mapcam")
	var c := m.center
	var eye := c + Vector3(0, 230, 120)
	var target := c + Vector3(0, 20, 0)
	if spec.begins_with("orbit:"):
		var p := spec.substr(6).split(",")
		var a := deg_to_rad(p[0].to_float())
		eye = c + Vector3(sin(a) * p[1].to_float(), p[2].to_float(), -cos(a) * p[1].to_float())
		target = c + Vector3(0, 25, 0)
	elif spec.begins_with("waterworks:"):
		# --mapcam=waterworks:<cliff>: a cliff's well, generator and water tower from the yard.
		var cid := int(spec.substr(11))
		var g := Generator.of(cid)
		var t := WaterTower.of(cid)
		if g != null and t != null:
			var mid := (g.global_position + t.global_position) * 0.5
			var out := g.global_transform.basis.z.normalized()
			var side := out.cross(Vector3.UP).normalized()
			target = mid + Vector3(0, 2.6, 0)
			eye = mid + out * 12.5 + side * 3.0 + Vector3(0, 4.5, 0)
	elif spec.begins_with("porch:"):
		# --mapcam=porch:<cliff>: the shaded porch on the front of a cliff's house (built for the shot).
		var ph := Homestead.of(int(spec.substr(6)))
		if ph != null:
			ph._set_state(ph.floors, ph.boarded, ph.reinforced, ph.tower, ph.workshop, true)
			var pb := ph.global_transform.basis
			var front := ph.global_position - pb.z.normalized() * (HouseBuilder.D * 0.5 + 1.5)
			target = front + Vector3(0, 1.3, 0)
			eye = front - pb.z.normalized() * 9.0 + pb.x.normalized() * 3.0 + Vector3(0, 3.0, 0)
	elif spec.begins_with("workshop:"):
		# --mapcam=workshop:<cliff>: the Workshop shed on the back of a cliff's house (built for the shot).
		var home := Homestead.of(int(spec.substr(9)))
		if home != null:
			home._set_state(home.floors, home.boarded, home.reinforced, home.tower, true)
			var b := home.global_transform.basis
			var back := home.global_position + b.z.normalized() * (HouseBuilder.D * 0.5 + 1.3)
			target = back + Vector3(0, 1.1, 0)
			eye = back + b.z.normalized() * 5.0 + b.x.normalized() * 2.5 + Vector3(0, 2.2, 0)
	elif spec.begins_with("yard:"):
		# --mapcam=yard:<cliff>[:full]: a cliff's house and fenced yard from outside the
		# front corner (full: every upgrade built for the shot).
		var parts := spec.split(":")
		var home := Homestead.of(int(parts[1]))
		if home != null:
			if parts.has("full"):
				home._set_state(3, true, true, true, true, true)
			var b := home.global_transform.basis
			var front := home.global_position - b.z.normalized() * (HouseBuilder.D * 0.5)
			target = front + Vector3(0, 3.0, 0)
			eye = front - b.z.normalized() * 9.5 + b.x.normalized() * 6.0 + Vector3(0, 3.2, 0)
		for i in 30:
			await get_tree().process_frame
	elif spec.begins_with("fence:"):
		# --mapcam=fence:<cliff>: low along the yard fence's side run.
		var home := Homestead.of(int(spec.substr(6)))
		if home != null:
			var b := home.global_transform.basis
			var p0 := home.global_position + b.x.normalized() * 9.0 - b.z.normalized() * 6.0
			eye = p0 + b.x.normalized() * 6.0 + Vector3(0, 1.8, 0) - b.z.normalized() * 4.0
			target = p0 + b.z.normalized() * 10.0 + Vector3(0, 0.6, 0)
	elif spec.begins_with("airship:"):
		# --mapcam=airship:below|side|deck|casino|bow|stalls|lucky|luckyout: the casino airship from under it, from
		# its flank, and on its deck.
		var ship := world.get_node_or_null("Airship") as Node3D
		if ship != null:
			for i in 60:
				await get_tree().process_frame
			match spec.substr(8):
				"below":
					eye = ship.to_global(Vector3(24.0, -20.0, 26.0))
					target = ship.to_global(Vector3(0, 6.0, 0))
				"deck":
					eye = ship.to_global(Vector3(5.0, 1.8, 14.0))
					target = ship.to_global(Vector3(-1.0, 2.0, -6.0))
				"casino":
					eye = ship.to_global(Vector3(-5.5, 2.2, 6.0))
					target = ship.to_global(Vector3(1.5, 0.8, -10.0))
				"bow":
					eye = ship.to_global(Vector3(5.5, 2.4, -15.0))
					target = ship.to_global(Vector3(-2.0, 1.0, 2.0))
				"stalls":
					eye = ship.to_global(Vector3(0.0, 1.9, 15.5))
					target = ship.to_global(Vector3(0.0, 1.4, 6.0))
				"lucky":
					eye = ship.to_global(Vector3(3.2, 2.0, -1.2))
					target = ship.to_global(Vector3(7.4, 1.2, 2.2))
				"luckyout":
					eye = ship.to_global(Vector3(9.5, 1.8, 0.4))
					target = ship.to_global(Vector3(7.0, 1.3, 2.0))
				_:
					eye = ship.to_global(Vector3(48.0, 8.0, 10.0))
					target = ship.to_global(Vector3(0, 8.0, 0))
	elif spec.begins_with("jackpose:"):
		# --mapcam=jackpose:<cliff>:<phi>[:side|:drive|:back]: the pump jack held at crank
		# angle phi (radians), close up from the side, at its drive, or from behind.
		var parts := spec.split(":")
		for n: Node in get_tree().get_nodes_in_group("water_sources"):
			if n is MechWell and (n as MechWell).cliff_id == int(parts[1]):
				var w := n as MechWell
				w.set("_speed", 0.0)
				w.set("_phi", float(parts[2]))
				w.call("_pose")
				w.set_process(false)
				var b := w.global_transform.basis
				var view := parts[3] if parts.size() > 3 else "side"
				match view:
					"drive":
						var d: Vector3 = w.drive_at
						target = w.to_global(d + Vector3(-0.2, 0.0, 0.3))
						eye = w.to_global(d + Vector3(-2.6, 1.4, -0.6))
					"back":
						target = w.to_global(Vector3(0, 1.6, 0.8))
						eye = w.to_global(Vector3(2.2, 2.2, 4.0))
					_:
						target = w.global_position + b * Vector3(0, 1.7, 0.0)
						eye = target + b.x.normalized() * 4.6 + Vector3(0, 0.6, 0)
		for i in 10:
			await get_tree().process_frame
	elif spec.begins_with("porchchair:"):
		# --mapcam=porchchair:<cliff>: close on the rocking chair on the porch.
		var home := Homestead.of(int(spec.substr(11)))
		if home != null:
			var spot := home.to_global(HouseBuilder.chair_spot())
			var hb := home.global_transform.basis
			target = spot + Vector3(0, 0.6, 0)
			eye = spot + hb.x.normalized() * 1.9 - hb.z.normalized() * 0.9 + Vector3(0, 1.0, 0)
	elif spec.begins_with("hats:"):
		# --mapcam=hats:<front|side>[:old]: one dummy per hat in a row on the west
		# plateau (rigged bodies, or the code-built ones with :old), heads close up.
		var parts := spec.split(":")
		var base := Bug.cliffs.plateau_point(0, 7.0, -32.0)
		var hats: Array = ["cattleman", "ten_gallon", "gambler", "bowler", "sombrero"]
		for i in hats.size():
			var holder := Node3D.new()
			world.add_child(holder)
			holder.global_position = base + Vector3(0, 0, (i - 2) * 1.1)
			var rig := DummyRig.new()
			holder.add_child(rig)
			var look := DummyLook.default_look()
			look["hat"] = hats[i]
			look["hair"] = "long"
			if parts.has("old"):
				look["outfit"] = "none"
			rig.build(Palette.TEAM_WEST, false, look)
			rig.rotation.y = -PI * 0.5 if not (parts.size() > 1 and parts[1] == "side") else PI # face the camera, or show it their side
		for i in 20:
			await get_tree().process_frame
		var head_y := base.y + 1.72
		eye = base + Vector3(3.0, 1.8, 0.0)
		target = Vector3(base.x, head_y - 0.05, base.z)
	elif spec.begins_with("well:"):
		# --mapcam=well:<cliff>[:run][:side]: close on a cliff's pump jack (run: pumping).
		var parts := spec.split(":")
		var cid := int(parts[1])
		MechWell.force_run = parts.has("run")
		for n: Node in get_tree().get_nodes_in_group("water_sources"):
			if n is MechWell and (n as MechWell).cliff_id == cid:
				var w := n as MechWell
				var b := w.global_transform.basis
				var side := b.x.normalized() * (-1.0 if parts.has("side") else 1.0)
				target = w.global_position + b * Vector3(0, 1.2, 0.0)
				eye = target + side * 5.5 + b.z.normalized() * -2.5 + Vector3(0, 1.6, 0)
		for i in 90:
			await get_tree().process_frame
	elif spec != "overhead" and spec != "":
		var p := spec.split(",")
		eye = Vector3(p[0].to_float(), p[1].to_float(), p[2].to_float())
		target = Vector3(p[3].to_float(), p[4].to_float(), p[5].to_float())
	if GameState.has_flag("--turrets") and multiplayer.is_server():
		_build_turrets()
	var cam := Camera3D.new()
	cam.far = 4000.0
	cam.fov = 70.0
	world.add_child(cam)
	cam.global_position = eye
	cam.look_at(target, Vector3.UP if absf((target - eye).normalized().y) < 0.99 else Vector3.FORWARD)
	cam.current = true
	var hud := world.get_node_or_null("Hud") as CanvasLayer
	if hud != null and not GameState.has_flag("--keephud"):
		hud.visible = false
	var secs := GameState.flag_value("--seconds").to_float()
	await get_tree().create_timer(secs if secs > 0.0 else 3.0).timeout
	var path := GameState.flag_value("--mapshot")
	if path != "":
		print("[fps] %d" % Engine.get_frames_per_second()) # frame rate at the moment of the shot (look checks)
		get_viewport().get_texture().get_image().save_png(path)
		print("[mapview] saved ", path)
	get_tree().quit()


## A gatling post on every 3rd lip cell of every cliff (shows the coverage split).
func _build_turrets() -> void:
	var bm := BuildManager.instance
	if bm == null:
		return
	for cid in WorldLayout.cliff_count():
		for col: int in [1, 4, 7, 10, 13, 16, 18]:
			bm.build(&"gatling_post", cid, Vector2i(0, col))


## For every cliff, grid column and cross-cliff turret: from the front row and
## the back row, how much of the covered cliff's climb (y 0..60, lanes -18..18)
## is inside its range and look-down limit, ignoring line of sight.
func _range_check() -> void:
	await get_tree().process_frame
	var cl := Bug.cliffs
	var m := WorldLayout.map()
	var ids: Array[StringName] = []
	for id: StringName in Defs.TURRETS:
		ids.append(id)
	print("[range] map %s" % m.display_name)
	for id in ids:
		var d := Defs.turret(id)
		if d == null or d.guards_plateau or d.anti_air or Defs.is_house_turret(id):
			continue
		var head := TurretBuilder.head_y(id)
		var worst := 1.0
		var worst_at := ""
		var sum := 0.0
		var n := 0
		for cid in m.count():
			for col in Buildable.COLS:
				var target := m.covered_cliff(cid, col)
				for row: int in [0, 6]:
					var muzzle := Buildable.cell_center(cl, cid, Vector2i(row, col)) + Vector3(0, head, 0)
					var hit := 0
					var tot := 0
					for lane in range(-18, 19, 3):
						for yy in range(2, 60, 4):
							tot += 1
							if Targeting.in_arc(muzzle, cl.face_point(target, float(yy), float(lane)), d.pitch_limit_deg, d.range):
								hit += 1
					var share := float(hit) / float(tot)
					sum += share
					n += 1
					if share < worst:
						worst = share
						worst_at = "%s col %d row %d -> %s" % [m.short_of(cid), col, row, m.short_of(target)]
		print("[range] %-16s range %5.1f  pitch %2.0f  covers %3.0f%% of the climb on average, worst %3.0f%% (%s)" % [id, d.range, d.pitch_limit_deg, sum / n * 100.0, worst * 100.0, worst_at])
	# Lip-to-lip distances between each cliff and the cliffs it covers.
	for cid in m.count():
		for t in m.covered_cliffs(cid):
			var a := cl.plateau_point(cid, 1.0, 0.0)
			var b := cl.face_point(t, WorldLayout.CLIFF_HEIGHT - 1.0, 0.0)
			print("[range] %s -> %s: lip to lip %.1f m (share %.0f%%)" % [m.name_of(cid), m.name_of(t), Vector2(a.x - b.x, a.z - b.z).length(), m.cover_share(cid, t) * 100.0])
	get_tree().quit()
