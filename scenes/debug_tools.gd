class_name DebugTools
extends Node
## Debug cheats (with --debug or Settings > Debug mode): F6 skip phase, F7 +500 scrap and +50 chitin for both sides, F8 spawn the next
## bug type on a random lane of your partner's cliff, F9 god mode, F10 show lanes.
## Also the automation flags used for testing:
##   --shot=<png> [--frames=N] [--pos=d,z] [--look=yaw,pitch] [--autofire] [--autoskip]
##   [--autobuild] (places turrets on both cliffs) saves a screenshot and quits.

static var instance: DebugTools

var world: Node3D
var _bug_index := 0
var _lanes: MeshInstance3D


func _ready() -> void:
	instance = self
	if GameState.has_flag("--downlog"):
		# Every second: each player as this peer sees it (downed, how far over on its back).
		var dt := Timer.new()
		dt.wait_time = 1.0
		dt.autostart = true
		add_child(dt)
		dt.timeout.connect(func() -> void:
			var parts: PackedStringArray = []
			# --downat=S: knock this peer's own player down S seconds in (once).
			var at := GameState.flag_value("--downat").to_float()
			if at > 0.0 and Time.get_ticks_msec() / 1000.0 >= at and not has_meta(&"downed_once"):
				var me := world.call("local_player") as Player if world != null else null
				if me != null:
					set_meta(&"downed_once", true)
					me.vitals.apply_damage(99999.0)
			for n: Node in get_tree().get_nodes_in_group("players"):
				var p := n as Player
				if p == null or not p.is_node_ready() or p.vitals == null or p.net == null:
					continue
				parts.append("%s%s downed %s over %.2f at %s sync %s floor %s" % [p.name, "(me)" if p.is_multiplayer_authority() else "", p.is_downed(), float(p.get("_down_k")), str(p.global_position.snapped(Vector3.ONE * 0.1)), str(p.net.sync_pos.snapped(Vector3.ONE * 0.1)), p.is_on_floor()])
				# --peershot=<png>: photograph a remote player once lying down ("_down") and once back up ("_up").
				var ps := GameState.flag_value("--peershot")
				if ps != "" and not p.is_multiplayer_authority():
					var k := float(p.get("_down_k"))
					if k >= 0.99 and not has_meta(&"peershot_down"):
						set_meta(&"peershot_down", true)
						_peer_shot(p, ps.replace(".png", "_down.png"))
					elif k <= 0.01 and has_meta(&"peershot_down") and not has_meta(&"peershot_up"):
						set_meta(&"peershot_up", true)
						_peer_shot(p, ps.replace(".png", "_up.png"))
			print("[down] t=%d %s" % [Time.get_ticks_msec() / 1000, "  ".join(parts)]))
	if GameState.has_flag("--selltest"):
		_sell_test() # QA: build a turret in a scaffold frame and sell it (works on a client too)
	if GameState.flag_value("--cpudryat") != "":
		# --cpudryat=S: S seconds in (host), pour out the CPU cliff's water so its crops
		# need a trip to the well; then log the pool and the well every 2 s.
		var dt2 := Timer.new()
		dt2.wait_time = 2.0
		dt2.autostart = true
		add_child(dt2)
		dt2.timeout.connect(func() -> void:
			if not multiplayer.is_server() or not NetworkManager.has_cpu():
				return
			var cid: int = NetworkManager.cpu_cliffs()[0]
			if not has_meta(&"cpudry") and Time.get_ticks_msec() / 1000.0 >= GameState.flag_value("--cpudryat").to_float():
				set_meta(&"cpudry", true)
				# ...and sow a corn plot there, so a crop is waiting on water.
				for n: Node in get_tree().get_nodes_in_group("crops"):
					var plot := n as CropPlot
					if plot != null and plot.cliff_id == cid and plot.growth.stage == CropGrowth.Stage.EMPTY:
						Economy.earn(cid, {CropPlot.seed_res(&"corn"): 1})
						plot.call("_use", -1, &"corn")
						break
				Economy.spend(cid, {&"water": Economy.amount(cid, &"water")})
				print("[cpuwater] drained cliff %d's water" % cid)
			var crops := 0
			for n: Node in get_tree().get_nodes_in_group("crops"):
				var plot := n as CropPlot
				if plot != null and plot.cliff_id == cid and plot.growth.stage == CropGrowth.Stage.PLANTED:
					crops += 1
			var well_left := -1
			for n: Node in get_tree().get_nodes_in_group("water_sources"):
				if n is MechWell and (n as MechWell).cliff_id == cid:
					well_left = (n as MechWell).stored
			print("[cpuwater] t=%d water %d planted crops %d well %d" % [Time.get_ticks_msec() / 1000, Economy.amount(cid, &"water"), crops, well_left]))
	if GameState.flag_value("--leverat") != "":
		# --leverat=S: S seconds in, throw this peer's own generator lever; log the levers every second.
		var lt := Timer.new()
		lt.wait_time = 1.0
		lt.autostart = true
		add_child(lt)
		lt.timeout.connect(func() -> void:
			var me := world.call("local_player") as Player if world != null else null
			if me != null and not has_meta(&"lever_once") and Time.get_ticks_msec() / 1000.0 >= GameState.flag_value("--leverat").to_float():
				set_meta(&"lever_once", true)
				GameState.toggle_ready()
				print("[lever] t=%d threw my lever (cliff %d)" % [Time.get_ticks_msec() / 1000, me.cliff_id])
			print("[lever] t=%d phase %d countdown %.1f levers %s cpu %s" % [Time.get_ticks_msec() / 1000, GameState.phase, GameState.ready_countdown, str(GameState.levers), str(GameState.cpu_levers)]))
	if GameState.flag_value("--act") != "":
		_act_shot(GameState.flag_value("--act"))
	var shot := GameState.flag_value("--shot")
	if GameState.flag_value("--mapshot") != "" or GameState.has_flag("--rangecheck"):
		# Maps: free-camera map screenshots and the turret range check.
		var views: Node = preload("res://scenes/debug/map_views.gd").new()
		views.set("world", world)
		add_child(views)
	elif shot != "":
		_take_screenshot(shot)
	elif GameState.flag_value("--soak") != "":
		_soak(GameState.flag_value("--soak").to_float())
	elif GameState.has_flag("--waterworkstest"):
		_waterworks_test()
	elif GameState.has_flag("--laddertest"):
		_ladder_test()
	elif GameState.has_flag("--scaffoldtest"):
		_scaffold_test()
	elif GameState.has_flag("--crewtest"):
		_crew_test()
	elif GameState.has_flag("--stacktest"):
		_stack_test()
	elif GameState.has_flag("--ledgertest"):
		_ledger_test()
	elif GameState.has_flag("--pausetest"):
		process_mode = Node.PROCESS_MODE_ALWAYS
		for i in 30:
			await get_tree().process_frame
		var v := PauseVote.instance
		v.toggle_vote()
		await get_tree().process_frame
		print("[pause] after voting: paused %s, tree paused %s, boxes %d" % [v.paused, get_tree().paused, v.get("_boxes").get_child_count()])
		var t0 := GameState.time_left
		await get_tree().create_timer(1.0, true, false, true).timeout
		print("[pause] build timer while paused: %.2f -> %.2f" % [t0, GameState.time_left])
		v.press_unpause()
		await get_tree().create_timer(1.0, true, false, true).timeout
		print("[pause] after unpause: paused %s, tree paused %s" % [v.paused, get_tree().paused])
		get_tree().quit()
	elif GameState.has_flag("--covertest"):
		var cp := CoveragePreview.new()
		cp.cliffs = Bug.cliffs
		add_child(cp)
		var base := Buildable.cell_center(Bug.cliffs, 0, Vector2i(0, 12))
		cp.show_for(&"gatling_post", 0, base, 0, true)
		var pm: Mesh = cp.get_child(0).mesh
		var cm: Mesh = cp.get_child(1).mesh
		print("[cover] base %s, patch aabb %s, cone aabb %s" % [str(base.snapped(Vector3.ONE * 0.1)), str(pm.get_aabb() if pm else null), str(cm.get_aabb() if cm else null)])
		print("[cover] preview global %s, top_level %s" % [str(cp.global_position), cp.top_level])
		var pl := world.call("local_player") as Player
		await get_tree().create_timer(0.5).timeout
		pl.build_mode.toggle()
		pl.build_mode._select(0)
		await get_tree().create_timer(0.5).timeout
		var bcp: CoveragePreview = pl.build_mode.get("_coverage")
		print("[cover] build mode preview visible %s in tree %s, ghost visible %s, cell %s" % [bcp.visible, bcp.is_visible_in_tree(), pl.build_mode.get("_ghost").visible, str(pl.build_mode.get("_cell"))])
		get_tree().quit()
	elif GameState.has_flag("--whiptest"):
		_whip_test()
	elif GameState.has_flag("--loottest"):
		_loot_test()
	elif GameState.has_flag("--archtest"):
		_arch_test()
	elif GameState.has_flag("--slidetest"):
		_slide_test()
	elif GameState.has_flag("--guntest"):
		_gun_test()
	elif GameState.has_flag("--chesttest"):
		_chest_test()
	elif GameState.has_flag("--porchtest"):
		_porch_test()
	elif GameState.has_flag("--aatest"):
		_aa_test()
	elif GameState.has_flag("--ziptest"):
		_zip_test()
	elif GameState.has_flag("--grappletest"):
		_grapple_test()
	elif GameState.has_flag("--grappleprobe"):
		_grapple_probe()
	elif GameState.has_flag("--grapplewall"):
		_grapple_wall_test()
	elif GameState.has_flag("--framecover"):
		_frame_cover()
	elif GameState.flag_value("--frameview") != "":
		_frame_view(GameState.flag_value("--frameview"))
	elif GameState.flag_value("--stress") != "":
		_stress(int(GameState.flag_value("--stress")))
	elif GameState.flag_value("--exportdummy") != "":
		# A bareheaded dummy in an A-pose as a GLB (a stand-in for testing tools/rig/autorig.py).
		var r := DummyRig.new()
		add_child(r)
		r.build(Color.RED, false, {"hat": "none", "outfit": "vest", "facial": "none"})
		for i in 3:
			await get_tree().process_frame
		r.set_process(false)
		r._shoulders[0].rotation = Vector3(0, 0, -0.8)
		r._shoulders[1].rotation = Vector3(0, 0, 0.8)
		r._elbows[0].rotation = Vector3.ZERO
		r._elbows[1].rotation = Vector3.ZERO
		r._gun_mi.get_parent().remove_child(r._gun_mi)
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		doc.append_from_scene(r, st)
		print("[export] ", doc.write_to_filesystem(st, GameState.flag_value("--exportdummy")))
		get_tree().quit()
	elif GameState.has_flag("--footcheck"):
		# How high the Meshy bodies' feet sit relative to the rig's origin (the ground).
		for outfit in ["vest", "duster", "poncho", "lawman"]:
			var r := DummyRig.new()
			add_child(r)
			r.build(Color.RED, false, {"outfit": outfit})
			for i in 4:
				r.animate(0.016, 0.0, false, 0.0)
				await get_tree().process_frame
			var m: ModelBody = r._model
			var low := 99.0
			for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
				var arrays := mi.mesh.surface_get_arrays(0)
				var sk := m.skel
				# Skinned positions: approximate with the foot bones' rest-to-pose shift.
				for b in ["LeftFoot", "RightFoot"]:
					var bi := sk.find_bone(b)
					var rest := sk.get_bone_global_rest(bi)
					var pose := sk.get_bone_global_pose(bi)
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for v in verts:
						if (rest.affine_inverse() * v).length() < 0.25:
							var w := r.global_transform.affine_inverse() * (sk.global_transform * (pose * (rest.affine_inverse() * v)))
							low = minf(low, w.y)
			print("[foot] %s lowest boot point %.3f m (0 = ground); hips bone %.3f" % [outfit, low, (r.global_transform.affine_inverse() * (m.skel.global_transform * m.skel.get_bone_global_pose(m.skel.find_bone("Hips")).origin)).y])
			r.queue_free()
		get_tree().quit()
	elif GameState.has_flag("--hotbartest"):
		for i in 30:
			await get_tree().process_frame
		var pl := world.call("local_player") as Player
		var hb := pl.get_node("Hotbar") as Hotbar
		Economy.earn(pl.cliff_id, {&"corn": 3})
		await get_tree().process_frame
		hb.use_slot(0)
		print("[hotbar] slot 1: holding '%s' gun %s" % [pl.gun.holding, pl.gun.def.id if pl.gun.def else "-"])
		hb.use_slot(0)
		print("[hotbar] slot 1 again: holding '%s' (none = empty hands)" % pl.gun.holding)
		hb._scroll(1)
		print("[hotbar] scroll down: slot %d holding '%s'" % [hb.selected, pl.gun.holding])
		hb._scroll(1)
		print("[hotbar] scroll down: slot %d holding '%s'" % [hb.selected, pl.gun.holding])
		hb._scroll(-1)
		print("[hotbar] scroll up: slot %d holding '%s'" % [hb.selected, pl.gun.holding])
		var before := Economy.amount(pl.cliff_id, &"corn")
		hb._drop()
		await get_tree().create_timer(0.3).timeout
		var picks := PickupManager.instance.get_children().filter(func(n: Node) -> bool: return n is WeaponPickup)
		print("[hotbar] dropped corn: %d -> %d, pickups on the ground %d" % [before, Economy.amount(pl.cliff_id, &"corn"), picks.size()])
		if picks.size() > 0:
			PickupManager.instance.try_pick_up(multiplayer.get_unique_id(), picks[-1])
			print("[hotbar] picked it up: corn %d" % Economy.amount(pl.cliff_id, &"corn"))
		get_tree().quit()
	elif GameState.has_flag("--archtop"):
		for i in 10:
			await get_tree().process_frame
		var arches := world.find_child("Arches", true, false)
		for mi: MeshInstance3D in arches.find_children("*", "MeshInstance3D", true, false):
			var arr := mi.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var best := Vector3(0, -999, 0)
			for v in verts:
				var w := mi.global_transform * v
				if absf(w.z + 17.0) < 8.0 and w.y > best.y:
					best = w
			var best2 := Vector3(0, -999, 0)
			for v in verts:
				var w := mi.global_transform * v
				if absf(w.z - 20.0) < 8.0 and w.y > best2.y:
					best2 = w
			print("[arch] crown near z-17: %s  near z20: %s  cliff top %.1f" % [str(best), str(best2), WorldLayout.CLIFF_HEIGHT])
		get_tree().quit()
	elif GameState.flag_value("--iconview") != "":
		for i in 20:
			await get_tree().process_frame
		var ids := [&"revolver", &"lever_rifle", &"coach_shotgun", &"blunderbuss", &"crank_gatling", &"corn", &"prickly_pear", &"chili", &"herbs", &"water", &"grapple", &"lighter"]
		var texs := {}
		for id: StringName in ids:
			texs[id] = IconStudio.item(self, id)
		for i in 10:
			await get_tree().process_frame
		for id: StringName in ids:
			if texs[id] != null:
				(texs[id] as Texture2D).get_image().save_png("%s/%s.png" % [GameState.flag_value("--iconview"), id])
			else:
				print("[icon] no icon for ", id)
		print("[icon] saved")
		get_tree().quit()
	elif GameState.flag_value("--mapview") != "":
		for i in 40:
			await get_tree().process_frame
		_autobuild()
		var bmv := world.get("bugs") as BugManager
		for i in 12:
			bmv.spawn_group(&"dust_mite", 1, i % WorldLayout.cliff_count(), i % 5, float(i % 4) * 12.0 + 5.0)
		Pings.instance.call("_send", 1)
		await get_tree().create_timer(2.0).timeout
		var hud := world.get("hud") as Hud
		hud.overview.visible = true
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png(GameState.flag_value("--mapview"))
		print("[map] saved")
		get_tree().quit()
	elif GameState.flag_value("--titleview") != "":
		for i in 40:
			await get_tree().process_frame
		var hud := world.get("hud") as Hud
		hud.title_card.show_card("WAVE 7 HELD", "Breathe easy. For now", Palette.BONE)
		hud.summary.demo()
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(GameState.flag_value("--titleview"))
		print("[title] saved")
		get_tree().quit()
	elif GameState.flag_value("--pingview") != "":
		_ping_view(GameState.flag_value("--pingview"))
	elif GameState.flag_value("--threatview") != "":
		_threat_view(GameState.flag_value("--threatview"))
	elif GameState.flag_value("--plotview") != "":
		_plot_view(GameState.flag_value("--plotview"))
	elif GameState.flag_value("--skyview") != "":
		_sky_view(GameState.flag_value("--skyview"))
	elif GameState.has_flag("--boardtest"):
		# Stand on each great arch's crown, hook the casino's ring, see where the pull lands.
		for i in 30:
			await get_tree().process_frame
		var pl := world.call("local_player") as Player
		var ship := world.get_node("Airship") as Airship
		for crown: Vector3 in [Vector3(3.7, 96.0, -13.8), Vector3(6.7, 97.5, 21.5)]:
			pl.global_position = crown + Vector3(0, 1.0, 0)
			pl.velocity = Vector3.ZERO
			await get_tree().physics_frame
			pl.grapple.test_mode = true
			pl.hotbar_use_grapple()
			var ring := Airship.ring_position() + Vector3(0, 0.45, 0)
			var q := PhysicsRayQueryParameters3D.create(pl.global_position + Vector3.UP * 1.5, ring, Grapple.MASK, [pl.get_rid()])
			var hit := pl.get_world_3d().direct_space_state.intersect_ray(q)
			print("[board] from %s: line to the ring hits %s" % [str(crown), str(hit.get("collider", "nothing"))])
			pl.grapple.attach(Grapple.Mode.PULL, ring)
			for k in 240:
				await get_tree().physics_frame
			var local := ship.global_transform.affine_inverse() * pl.global_position
			print("[board]   ended at %s, ship-local %s, on floor %s" % [str(pl.global_position.snapped(Vector3.ONE * 0.1)), str(local.snapped(Vector3.ONE * 0.1)), pl.is_on_floor()])
		get_tree().quit()
	elif GameState.has_flag("--flytest"):
		for i in 20:
			await get_tree().process_frame
		var bm := world.get("bugs") as BugManager
		bm.spawn_group(&"dragonfly_bandit", 2, WorldLayout.WEST, 2)
		await get_tree().physics_frame
		for k in 14:
			var line := ""
			for n: Node in get_tree().get_nodes_in_group("bugs"):
				var b := n as Bug
				line += " y %.1f x %.1f" % [b.ground_pos.y, b.ground_pos.x]
			print("[fly] t %.1f:%s (cliff top %.0f)" % [k * 1.5, line, WorldLayout.CLIFF_HEIGHT])
			await get_tree().create_timer(1.5).timeout
		get_tree().quit()
	elif GameState.has_flag("--tunneltest"):
		for i in 20:
			await get_tree().process_frame
		var bm := world.get("bugs") as BugManager
		bm.spawn_group(&"dust_mite", 3, WorldLayout.WEST, 2)
		for k in 16:
			var line := ""
			for n: Node in get_tree().get_nodes_in_group("bugs"):
				var b := n as Bug
				line += "  [%s z %.1f y %.1f]" % [Bug.State.keys()[b.state], b.global_position.z, b.global_position.y]
			print("[tunnel] t %.0f%s" % [k * 2.0, line])
			await get_tree().create_timer(2.0).timeout
		get_tree().quit()
	elif GameState.has_flag("--housediag"):
		_house_diag()
	elif GameState.has_flag("--gatlingdiag"):
		_gatling_diag()
	elif GameState.has_flag("--crawltest"):
		# A rattler beetle climbing up through a column of mites on the west wall.
		for i in 20:
			await get_tree().process_frame
		var bm := world.get("bugs") as BugManager
		for k in 6:
			bm.spawn_at(&"dust_mite", WorldLayout.WEST, 2, 0.0, 14.0 + k * 1.2, Bug.State.CLIMBING, Vector3.ZERO)
		bm.spawn_at(&"rattler_beetle", WorldLayout.WEST, 2, 0.0, 6.0, Bug.State.CLIMBING, Vector3.ZERO)
		var max_crouch := 0.0
		var max_ride := 0.0
		var beetle_y0 := 6.0
		for f in 720:
			await get_tree().physics_frame
			for n: Node in get_tree().get_nodes_in_group("bugs"):
				var b := n as Bug
				if b.def.id == &"dust_mite":
					# Hold the mites in place on the wall (as if clinging) so the beetle reaches them.
					if not b.has_meta("pin"):
						b.set_meta("pin", b.climb_y)
					b.climb_y = float(b.get_meta("pin"))
					max_crouch = maxf(max_crouch, b.crouch)
				else:
					max_ride = maxf(max_ride, b.ride)
		var beetle: Bug = null
		var spread := 0.0
		for n: Node in get_tree().get_nodes_in_group("bugs"):
			var b := n as Bug
			if b.def.id == &"rattler_beetle":
				beetle = b
			else:
				spread = maxf(spread, absf(b.lane_z))
		print("[crawl] beetle climbed %.1f -> %.1f m; mites ducked up to %.2f, beetle rode up to %.2f m, mites edged aside up to %.1f m" % [beetle_y0, beetle.climb_y, max_crouch, max_ride, spread])
		get_tree().quit()
	elif GameState.has_flag("--placetest"):
		for i in 20:
			await get_tree().process_frame
		var b := BuildManager.instance
		Economy.earn(WorldLayout.WEST, {&"scrap": 5000})
		var tries := [[&"gatling_post", Vector2i(8, 6)], [&"duck_gun", Vector2i(0, 3)], [&"farm_plot", Vector2i(0, 8)], [&"barbed_wire", Vector2i(0, 12)],
			[&"scattergun_post", Vector2i(9, 3)], [&"buffalo_rifle", Vector2i(1, 14)]]
		for tr: Array in tries:
			b._do_build(1, tr[0], WorldLayout.WEST, tr[1])
			await get_tree().process_frame
			var lv := b.scaffold_levels(WorldLayout.WEST, tr[1])
			var placed := b.cell_taken(WorldLayout.WEST, tr[1])
			print("[place] %s at %s (zone %s): placed %s, scaffold levels %d" % [tr[0], str(tr[1]), Buildable.Zone.keys()[Buildable.zone(tr[1])], placed, lv])
		for t in b.turrets_on(WorldLayout.WEST, Vector2i(8, 6)):
			print("[place]   gatling stands at level %d" % t.level)
		get_tree().quit()
	elif GameState.has_flag("--steptest"):
		for i in 20:
			await get_tree().process_frame
		var pl := world.call("local_player") as Player
		var home := Homestead.of(pl.cliff_id)
		pl.global_position = home.global_transform * Vector3(0, 0.5, -HouseBuilder.D * 0.5 - 7.0)
		await _walk(pl, home, Vector3(0, 0, 1), 3.5)
		Input.action_release("move_forward")
		print("[steptest] done")
		get_tree().quit()
	elif GameState.flag_value("--stairtest") != "":
		_stair_test(int(GameState.flag_value("--stairtest")))


## --act=harvest@0.5[:prop]: the local player acts it out in first person, held
## at that moment, for screenshots of the interaction animations.
func _act_shot(spec: String) -> void:
	for i in 30:
		await get_tree().process_frame
	var pl := world.call("local_player") as Player
	var id := StringName(spec.get_slice("@", 0))
	var rest := spec.get_slice("@", 1) if spec.contains("@") else "0.5"
	var prop := StringName(rest.get_slice(":", 1)) if rest.contains(":") else &""
	pl.head.rotation.x = -0.25
	# Look at a spot on the ground just ahead, as when using a crop plot.
	pl.head.rotation.x = -0.55
	pl.act(id, prop)
	pl.fp_hands.freeze = float(rest.get_slice(":", 0))
	pl.rig.action_freeze = pl.fp_hands.freeze


## --stairtest=N: builds an N-storey house, walks the local player up every flight
## of stairs (held forward key), and prints the heights reached. Works headless.
func _stair_test(floors: int) -> void:
	for i in 20:
		await get_tree().process_frame
	var player := world.call("local_player") as Player
	var home := Homestead.of(player.cliff_id)
	home._set_state(floors, true, true)
	await get_tree().physics_frame
	var base_y := home.global_position.y
	# Walk in the front door first.
	player.global_position = home.global_transform * Vector3(0, 0.5, -HouseBuilder.D * 0.5 - 1.5)
	await _walk(player, home, Vector3(0, 0, 1), 1.2)
	print("[stairs] through the door: local %s" % str((home.global_transform.affine_inverse() * player.global_position).snapped(Vector3.ONE * 0.1)))
	for f in floors:
		player.global_position = home.global_transform * Vector3(2.95, HouseBuilder.H * f + 0.4, 2.0)
		await get_tree().physics_frame
		await _walk(player, home, Vector3(-1, 0, 0), 3.0)
		print("[stairs]   after the climb: local %s, on floor %s" % [str((home.global_transform.affine_inverse() * player.global_position).snapped(Vector3.ONE * 0.05)), player.is_on_floor()])
		var c := player.get_last_slide_collision()
		if c != null:
			print("[stairs]   blocked by %s at local %s normal %s" % [c.get_collider(), str((home.global_transform.affine_inverse() * c.get_position()).snapped(Vector3.ONE * 0.05)), str((home.global_transform.basis.inverse() * c.get_normal()).snapped(Vector3.ONE * 0.05))])
		await _walk(player, home, Vector3(0, 0, -1), 0.8)
		print("[stairs] flight %d: ended %.2f m up (storey floor at %.2f), local %s" % [f + 1, player.global_position.y - base_y, HouseBuilder.H * (f + 1), str((home.global_transform.affine_inverse() * player.global_position).snapped(Vector3.ONE * 0.1))])
	get_tree().quit()


## --houseturrets: 3-storey houses on both cliffs with a house turret on every mount.
func _house_turrets() -> void:
	for cid in 2:
		var home := Homestead.of(cid)
		home._set_state.rpc(3, true, true)
		Economy.earn(cid, {&"scrap": 600})
		for i in home.mount_count():
			BuildManager.instance._do_build(1, &"porch_repeater" if i % 2 == 0 else &"rooftop_cannon", cid, Vector2i(-1, i))


## --ledgertest: buys every house upgrade in turn and prints the result.
func _ledger_test() -> void:
	for i in 20:
		await get_tree().process_frame
	GameState.start_run()
	var home := Homestead.of(0)
	Economy.earn(0, {&"scrap": 1000, &"chitin": 100})
	GameState.damage_homestead(0, 150.0)
	for i in [4, 0, 1, 2, 3, 4, 1]:
		home.buy(1, i)
		await get_tree().process_frame
		print("[ledger] bought %s -> floors %d boarded %s reinforced %s hp %.0f/%.0f mounts %d scrap %d chitin %d" % [
			Homestead.UPGRADES[i]["id"], home.floors, home.boarded, home.reinforced, GameState.homestead_hp[0],
			GameState.homestead_max[0], home.mount_count(), Economy.amount(0, &"scrap"), Economy.amount(0, &"chitin")])
	get_tree().quit()


## --laddertest (with --airship): waits for the casino ship, climbs its ladder,
## plays the slots and the wheel, then skips the phase so the ship leaves.
func _ladder_test() -> void:
	var ship := world.get_node("Airship") as Airship
	var player := world.call("local_player") as Player
	var t0 := Time.get_ticks_msec()
	while not ship._ladder_area.monitoring and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(4.0).timeout
	print("[ladder] ship hovering at %s, ladder out %s" % [str(ship.global_position.snapped(Vector3.ONE * 0.1)), ship._ladder_mi.visible])
	player.global_position = ship.to_global(Vector3(0, 0.3, AirshipBuilder.DECK_L * 0.5 - 1.2))
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0 # facing -Z, toward the deck
	await get_tree().physics_frame
	Input.action_press("move_forward")
	var t := 0.0
	while t < 7.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	await get_tree().create_timer(0.5).timeout
	var local := ship.global_transform.affine_inverse() * player.global_position
	print("[ladder] after climbing: ship-local %s, on ladder %d, on floor %s" % [str(local.snapped(Vector3.ONE * 0.1)), player.ladder_count, player.is_on_floor()])
	Economy.earn(player.cliff_id, {&"scrap": 200, &"chitin": 20})
	var slots := ship.get_node("Slots0") as SlotMachine
	for i in 6:
		slots._act(1, &"pull", 0, 10)
	var wheel := ship.get_node("Wheel") as PrizeWheel
	wheel._act(1, &"spin", 0, 0)
	await get_tree().create_timer(PrizeWheel.SPIN_TIME + 0.5).timeout
	wheel._act(1, &"spin", 0, 0)
	await get_tree().create_timer(PrizeWheel.SPIN_TIME + 0.5).timeout
	var bj := ship.get_node("Blackjack") as BlackjackTable
	bj._act(1, &"deal", 0, 20)
	bj._act(1, &"stand", 0, 0)
	(ship.get_node("Baccarat") as BaccaratTable)._act(1, &"deal", 1, 20)
	(ship.get_node("Roulette") as RouletteTable)._act(1, &"spin", 0, 20)
	await get_tree().create_timer(RouletteTable.SPIN_TIME + 0.5).timeout
	for tn: String in ["Blackjack", "Baccarat", "Roulette"]:
		print("[ladder] %s: %s" % [tn, str((ship.get_node(tn) as CasinoGame).view.get("result", ""))])
	if GameState.flag_value("--menushot") != "":
		MenuScreen.instance.open(ship.get_node(GameState.flag_value("--menushot")))
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("res://docs/screenshots/menu_%s.png" % GameState.flag_value("--menushot").to_lower())
	print("[ladder] after games: scrap %d chitin %d" % [Economy.amount(player.cliff_id, &"scrap"), Economy.amount(player.cliff_id, &"chitin")])
	GameState.debug_skip()
	await get_tree().create_timer(1.0).timeout
	print("[ladder] ship leaving (state %d); player now at %s (oasis top y %.1f)" % [ship._state, str(player.global_position.snapped(Vector3.ONE * 0.1)), WorldLayout.CLIFF_HEIGHT])
	get_tree().quit()


## --crewtest: crewed 2 x 2 guns: ground only, nothing on or under their four cells
## (scaffolds, turrets, traps, free-scaffold stacking), cost paid once, refund on demolish.
func _crew_test() -> void:
	for i in 30:
		await get_tree().process_frame
	var bm := BuildManager.instance
	Economy.earn(0, {&"scrap": 5000})
	var a := Vector2i(0, 8)
	var fp := Buildable.footprint(&"big_bertha", a)
	var s0 := Economy.amount(0, &"scrap")
	print("[crew] bertha allowed on bare ground: %s" % bm.is_free_for(&"big_bertha", 0, a))
	bm.build(&"big_bertha", 0, a)
	await get_tree().create_timer(0.3).timeout
	var t := bm.turret_at(0, a, 0)
	print("[crew] built %s level %d paid %d (cost %d), scaffold under it %d" % [t.def.id if t != null else &"-", t.level if t != null else -1,
			s0 - Economy.amount(0, &"scrap"), Perks.build_cost(1, &"big_bertha"), bm.scaffold_levels(0, a)])
	for c in fp:
		var bad: PackedStringArray = []
		for id: StringName in [&"gatling_post", &"scaffold", &"bear_trap", &"barbed_wire", &"whaler", &"farm_plot"]:
			if bm.is_free_for(id, 0, c):
				bad.append(String(id))
		print("[crew] cell %s covered: %s, allows %s" % [str(c), bm.crewed_at(0, c), "nothing" if bad.is_empty() else ", ".join(bad)])
	# Overlap from the side: another crewed gun whose square shares a cell.
	print("[crew] overlapping whaler at (0,9): %s, at (1,7): %s, next door (0,10): %s" % [bm.is_free_for(&"whaler", 0, Vector2i(0, 9)),
			bm.is_free_for(&"whaler", 0, Vector2i(1, 7)), bm.is_free_for(&"whaler", 0, Vector2i(0, 10))])
	# Under a scaffold / a stacked turret: never.
	var sc := Vector2i(0, 14)
	bm.build(&"gatling_post", 0, sc)
	await get_tree().create_timer(0.3).timeout
	print("[crew] crewed over a scaffold cell (0,13): %s, (0,14): %s" % [bm.is_free_for(&"thunder_mule", 0, Vector2i(0, 13)), bm.is_free_for(&"thunder_mule", 0, sc)])
	bm.build(&"bear_trap", 0, Vector2i(2, 20))
	await get_tree().create_timer(0.3).timeout
	print("[crew] crewed over a trap: %s" % bm.is_free_for(&"sky_hound", 0, Vector2i(1, 19)))
	# The other three guns go up too.
	for p: Array in [[&"whaler", Vector2i(0, 10)], [&"thunder_mule", Vector2i(0, 16)], [&"sky_hound", Vector2i(0, 18)]]:
		bm.build(p[0], 0, p[1])
		await get_tree().create_timer(0.3).timeout
		var g := bm.turret_at(0, p[1], 0)
		print("[crew] %s at %s: %s" % [p[0], str(p[1]), "up, crewed %s" % (g is CrewedTurret) if g != null and g.def.id == p[0] else "NOT BUILT"])
	s0 = Economy.amount(0, &"scrap")
	bm.demolish_node(t)
	await get_tree().create_timer(0.3).timeout
	print("[crew] demolish bertha refund %d, cells free again %s" % [Economy.amount(0, &"scrap") - s0, fp.all(func(c: Vector2i) -> bool: return not bm.crewed_at(0, c) and bm.is_free_for(&"gatling_post", 0, c))])
	get_tree().quit()


## --selltest: on this peer's own cliff, a scaffold, a turret in its frame and one
## on top; then sell (as X does) the top turret, the frame turret and the scaffold
## in one frame, and finally whatever is left, logging what the cell holds.
func _sell_test() -> void:
	await get_tree().create_timer(14.0).timeout
	var bm := BuildManager.instance
	var me := world.call("local_player") as Player if world != null else null
	if bm == null or me == null:
		return
	var cid := me.cliff_id
	var cell := Vector2i(0, 7)
	if multiplayer.is_server():
		Economy.earn(cid, {&"scrap": 600})
	bm.build(&"scaffold", cid, cell)
	await get_tree().create_timer(0.5).timeout
	bm.build(&"gatling_post", cid, cell)
	await get_tree().create_timer(0.5).timeout
	bm.build(&"gatling_post", cid, cell)
	await get_tree().create_timer(1.0).timeout
	var on := bm.turrets_on(cid, cell)
	print("[sell] built: levels %d, turrets %d, scrap %d" % [bm.scaffold_levels(cid, cell), on.size(), Economy.amount(cid, &"scrap")])
	for t in on:
		bm.demolish_node(t)
	for n: Node in bm.get_children():
		if n is ScaffoldNode and (n as ScaffoldNode).cell == cell and int(n.get("cliff_id")) == cid:
			bm.demolish_node(n)
	await get_tree().create_timer(1.0).timeout
	print("[sell] after one-frame sells: levels %d, turrets %d, scrap %d" % [bm.scaffold_levels(cid, cell), bm.turrets_on(cid, cell).size(), Economy.amount(cid, &"scrap")])
	for k in 3:
		for n: Node in bm.get_children():
			if n is ScaffoldNode and (n as ScaffoldNode).cell == cell and int(n.get("cliff_id")) == cid:
				bm.demolish_node(n)
		await get_tree().create_timer(0.5).timeout
	print("[sell] done: levels %d, turrets %d, scrap %d" % [bm.scaffold_levels(cid, cell), bm.turrets_on(cid, cell).size(), Economy.amount(cid, &"scrap")])


## --scaffoldtest: turret first, then scaffolding over it, then a turret on top.
func _scaffold_test() -> void:
	for i in 20:
		await get_tree().process_frame
	var bm := BuildManager.instance
	Economy.earn(0, {&"scrap": 500})
	var cell := Vector2i(0, 3)
	bm.build(&"gatling_post", 0, cell)
	await get_tree().create_timer(0.3).timeout
	print("[scaffold] scaffold allowed over the turret: %s" % bm.is_free_for(&"scaffold", 0, cell))
	bm.build(&"scaffold", 0, cell)
	await get_tree().create_timer(0.3).timeout
	bm.build(&"buffalo_rifle", 0, cell)
	await get_tree().create_timer(0.3).timeout
	print("[scaffold] levels %d, turrets on the cell: %d" % [bm.scaffold_levels(0, cell), bm.turrets_on(0, cell).size()])
	bm.build(&"farm_plot", 0, Vector2i(3, 4))
	await get_tree().create_timer(0.3).timeout
	print("[scaffold] farm plot covers (4,5): %s, (5,6) free: %s, bear trap on row 1: %s, gatling on row 2: %s" % [
		bm.cell_taken(0, Vector2i(4, 5)), not bm.cell_taken(0, Vector2i(5, 6)),
		bm.is_free_for(&"bear_trap", 0, Vector2i(1, 6)), bm.is_free_for(&"gatling_post", 0, Vector2i(2, 6))])
	get_tree().quit()


## --stacktest: turrets placed on a full scaffold add a free level on top (up to
## MAX_SCAFFOLD). Logs scrap paid, levels, turret heights, stack_level (what the
## ghost uses), the full-stack refusal, demolish order and the save capture.
## On a client (--join ... --stacktest) it logs the scaffold levels and mesh heights it sees.
func _stack_test() -> void:
	for i in 30:
		await get_tree().process_frame
	var bm := BuildManager.instance
	var cell := Vector2i(0, 5)
	if not multiplayer.is_server():
		await get_tree().create_timer(8.0).timeout
		for n: Node in bm.get_children():
			if n is ScaffoldNode:
				var sc := n as ScaffoldNode
				var mi := sc.get("_mi") as MeshInstance3D
				print("[stack] client sees scaffold at %s levels %d mesh top %.2f collision posts %d" % [str(sc.cell), sc.levels,
						mi.mesh.get_aabb().end.y if mi != null and mi.mesh != null else -1.0,
						sc.get_children().filter(func(c: Node) -> bool: return c is CollisionShape3D and not c.is_queued_for_deletion()).size()])
		for t: Node in get_tree().get_nodes_in_group("turrets"):
			print("[stack] client sees %s level %d y %.2f" % [(t as Turret).def.id, (t as Turret).level, (t as Turret).global_position.y])
		get_tree().quit()
		return
	Economy.earn(0, {&"scrap": 2000})
	var ground := Buildable.cell_center(Bug.cliffs, 0, cell).y
	print("[stack] empty cell: stack_level %d (ghost level)" % bm.stack_level(0, cell))
	for id: StringName in [&"gatling_post", &"buffalo_rifle", &"duck_gun", &"water_cannon"]:
		var before := Economy.amount(0, &"scrap")
		var lvl := bm.placement_level(id, 0, cell)
		var ok := bm.is_free_for(id, 0, cell)
		bm.build(id, 0, cell)
		await get_tree().create_timer(0.3).timeout
		var paid := before - Economy.amount(0, &"scrap")
		var hs: PackedStringArray = []
		for t in bm.turrets_on(0, cell):
			hs.append("%s@L%d(+%.1fm)" % [String(t.def.id).left(6), t.level, t.global_position.y - ground])
		print("[stack] %s: allowed %s, ghost level %d, paid %d (cost %d), scaffold levels %d, turrets %s" % [id, ok, lvl, paid,
				Perks.build_cost(1, id), bm.scaffold_levels(0, cell), ", ".join(hs)])
	print("[stack] full stack refuses a 4th: %s, stack_level %d" % [not bm.is_free_for(&"gatling_post", 0, cell), bm.stack_level(0, cell)])
	var data: Dictionary = (world.get("saver") as RunSaver).capture()
	for b: Dictionary in data["builds"]:
		if int(b["row"]) == cell.x and int(b["col"]) == cell.y:
			print("[stack] save: %s level %d levels %s" % [b["type"], int(b["level"]), str(b.get("levels", "-"))])
	# Demolish: the scaffold's top level stays while a turret stands on it.
	var sc: ScaffoldNode = bm.get("_scaffolds")[BuildManager._cell_key(0, cell)]
	var s0 := Economy.amount(0, &"scrap")
	bm.demolish_node(sc)
	await get_tree().create_timer(0.3).timeout
	print("[stack] demolish scaffold under a turret: levels %d, refund %d" % [bm.scaffold_levels(0, cell), Economy.amount(0, &"scrap") - s0])
	var top := bm.turret_at(0, cell, bm.scaffold_levels(0, cell))
	s0 = Economy.amount(0, &"scrap")
	bm.demolish_node(top)
	await get_tree().create_timer(0.3).timeout
	var r1 := Economy.amount(0, &"scrap") - s0
	s0 = Economy.amount(0, &"scrap")
	bm.demolish_node(sc)
	await get_tree().create_timer(0.3).timeout
	print("[stack] top turret refund %d, then the free top level refund %d, levels now %d, turrets %d" % [r1,
			Economy.amount(0, &"scrap") - s0, bm.scaffold_levels(0, cell), bm.turrets_on(0, cell).size()])
	if GameState.has_flag("--stackwait"):
		await get_tree().create_timer(12.0).timeout
	get_tree().quit()


## Holds forward with the player turned to face local direction `dir`.
func _walk(player: Player, home: Homestead, dir: Vector3, seconds: float) -> void:
	var world_dir := home.global_transform.basis * dir
	player.rotation.y = atan2(-world_dir.x, -world_dir.z)
	player.head.rotation.x = 0.0
	Input.action_press("move_forward")
	var t := 0.0
	var next_log := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if GameState.has_flag("--stairlog") and t >= next_log:
			next_log += 0.2
			print("    t %.1f local %s vel %s floor %s wall %s" % [t, str((home.global_transform.affine_inverse() * player.global_position).snapped(Vector3.ONE * 0.05)), str(player.velocity.snapped(Vector3.ONE * 0.1)), player.is_on_floor(), player.is_on_wall()])
			for k in player.get_slide_collision_count():
				var sc := player.get_slide_collision(k)
				print("      hit local %s normal %s" % [str((home.global_transform.affine_inverse() * sc.get_position()).snapped(Vector3.ONE * 0.05)), str((home.global_transform.basis.inverse() * sc.get_normal()).snapped(Vector3.ONE * 0.05))])
	Input.action_release("move_forward")


## --soak=N: runs N seconds (works headless), auto-readies every build phase,
## logs each phase change, then quits. Combine with --autobuild and --fast.
## --waterworkstest: throw the lever, call it off, throw it again, watch the
## generators start with the wave, the tower fill and the tap fill a bucket, then
## the levers drop when the wave ends. Prints [ww] lines and quits.
func _waterworks_test() -> void:
	for i in 40:
		await get_tree().process_frame
	var g := Generator.of(0)
	var t := WaterTower.of(0)
	var say := func(what: String) -> void:
		print("[ww] %-22s phase %d countdown %5.2f levers %s pumps %s tank %.2f water %d" % [what, GameState.phase, GameState.ready_countdown,
				str(GameState.levers), GameState.pumps_on(), t.stored if t != null else -1.0, Economy.amount(0, &"water")])
	say.call("start")
	if g == null or t == null:
		print("[ww] FAIL: no generator/tower on cliff 0")
		get_tree().quit()
		return
	print("[ww] generator prompt: ", g.interact_prompt().replace("
", " | "))
	g.local_interact(false)
	await get_tree().create_timer(0.4).timeout
	say.call("lever thrown")
	g.local_interact(false)
	await get_tree().create_timer(0.4).timeout
	say.call("lever pulled back")
	g.local_interact(false)
	var waited := 0.0
	while GameState.phase != GameState.Phase.WAVE and waited < 30.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	say.call("wave on")
	await get_tree().create_timer(6.0).timeout
	say.call("6 s of pumping")
	t.set_level(12.0)
	await get_tree().process_frame
	var tap := t.get_node("Tap") as TowerTap
	print("[ww] tap prompt: ", tap.interact_prompt().replace("
", " | "))
	var got := t.draw(multiplayer.get_unique_id())
	await get_tree().process_frame
	say.call("tap drew %d" % got)
	GameState.end_wave()
	await get_tree().create_timer(0.5).timeout
	say.call("wave over")
	get_tree().quit()


func _soak(seconds: float) -> void:
	for i in 20:
		await get_tree().process_frame
	if GameState.has_flag("--autobuild") and multiplayer.is_server():
		_autobuild()
	if GameState.flag_value("--showcase") != "":
		_showcase()
	var bugs := world.get("bugs") as BugManager
	var kills_by: Dictionary = {}
	if GameState.has_flag("--houseturrets"):
		_house_turrets()
		bugs.bug_killed.connect(func(_name: String, _bc: int, source: String, _sc: int, _loot: Dictionary) -> void:
			var key := source.get_slice("'s ", 1) if source.contains("'s ") else source
			kills_by[key] = int(kills_by.get(key, 0)) + 1)
	GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
		print("[soak %5.1fs] wave %d phase %d  homesteads %s  bugs %d  scrap W%d E%d  |  mem %.1f MB  nodes %d  objects %d  orphans %d  video %.0f MB" % [
			Time.get_ticks_msec() / 1000.0, GameState.wave, p, str(GameState.homestead_hp),
			bugs.alive_count(), Economy.amount(0, &"scrap"), Economy.amount(1, &"scrap"),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]))
	var start := Time.get_ticks_msec()
	var last_seen := {} # --stuckcheck: bug -> [position, seconds unmoved]
	CpuProf.install(get_tree().root)
	var prof_t := 0
	while Time.get_ticks_msec() - start < int(seconds * 1000.0) and GameState.phase != GameState.Phase.GAME_OVER:
		await get_tree().create_timer(1.0).timeout
		# Per-system script time every 10 s of a wave (CpuProf).
		prof_t += 1
		if prof_t >= 10:
			prof_t = 0
			if GameState.phase == GameState.Phase.WAVE:
				print("[soak cpu] bugs %d turrets %d  %s" % [bugs.alive_count(), get_tree().get_nodes_in_group("turrets").size(), CpuProf.report()])
			CpuProf.reset()
		if GameState.has_flag("--stuckcheck"):
			# Living bugs that haven't moved half a metre in 30 s (rooted/webbed ones excepted).
			var now := {}
			for n: Node in get_tree().get_nodes_in_group("bugs"):
				var b := n as Bug
				if not b.is_alive() or b.is_hidden():
					continue
				var prev: Array = last_seen.get(b, [b.global_position, 0])
				var still := int(prev[1]) + 1 if (prev[0] as Vector3).distance_to(b.global_position) < 0.5 else 0
				now[b] = [prev[0] if still > 0 else b.global_position, still]
				if still == 30:
					print("[stuck] %s state %d cliff %d y %.1f pos %s hp %.0f unmoved 30 s" % [b.def.id, b.state, b.cliff_id, b.climb_y,
							str(b.global_position.snapped(Vector3.ONE * 0.1)), b.health.hp])
					var goal := Bug.cliffs.tunnel_mouth(b.cliff_id, b.lane_z)
					print("[stuck]   speed %.2f status %.2f weather %.2f temp %.2f  goal %s (%.1f m)  ground_pos %s  lane %d lane_z %.1f" % [
							b.speed(), b.status.speed_multiplier(), Weather.bug_speed(GameState.weather), Weather.bug_temp_speed(GameState.temperature()),
							str(goal.snapped(Vector3.ONE * 0.1)), Vector2(goal.x - b.ground_pos.x, goal.z - b.ground_pos.z).length(),
							str(b.ground_pos.snapped(Vector3.ONE * 0.1)), b.lane, b.lane_z])
			last_seen = now
		if GameState.has_flag("--god"):
			GameState.god_mode = true
		if GameState.has_flag("--autokill"):
			# Stand-in for players with revolvers: 25 damage per second to every breacher and bandit.
			for n: Node in get_tree().get_nodes_in_group("bugs"):
				var b := n as Bug
				if b.is_alive() and (b.state == Bug.State.BREACHING or b.state == Bug.State.FLYING):
					b.receive_hit(25.0, b.global_position, Vector3.DOWN, false, 1.0, "Rancher", b.cliff_id)
		if GameState.phase == GameState.Phase.BUILD:
			if GameState.has_flag("--farm"):
				_farm()
			GameState.vote_skip()
	if GameState.flag_value("--perkset") != "":
		var mend := 0
		var tl := 0
		for n: Node in get_tree().get_nodes_in_group("turrets"):
			tl += 1
			if (n as Turret).perk_mend > 0.0:
				mend += 1
		print("[soak] perks: loadouts %s, turrets %d with Overtime %d, Scrap Scavenger sources %s" % [str(Perks.loadouts), tl, mend, str(Perks.get("_turret_scrap"))])
	print("[soak] end: wave %d phase %d homesteads %s bugs %d" % [GameState.wave, GameState.phase, str(GameState.homestead_hp), bugs.alive_count()])
	if not kills_by.is_empty():
		print("[soak] kills by source: %s" % str(kills_by))
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		print("  left: %s state %d cliff %d y %.1f pos %s hp %.0f" % [b.def.id, b.state, b.cliff_id, b.climb_y, str(b.global_position.snapped(Vector3.ONE * 0.1)), b.health.hp])
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.debug_enabled() or GameState.menu_open:
		return
	if event.is_action_pressed("debug_skip_phase"):
		GameState.debug_skip()
	elif event.is_action_pressed("debug_add_scrap"):
		_cheat.rpc_id(1, "scrap")
	elif event.is_action_pressed("debug_spawn_bug"):
		_cheat.rpc_id(1, "spawn")
	elif event.is_action_pressed("debug_god_mode"):
		_cheat.rpc_id(1, "god")
	elif event.is_action_pressed("debug_show_lanes"):
		_toggle_lanes()


@rpc("any_peer", "call_local", "reliable")
func _cheat(kind: String) -> void:
	if not multiplayer.is_server() or not GameState.debug_enabled():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var cid := NetworkManager.cliff_of(sender) if NetworkManager.is_online() else _local_cliff()
	match kind:
		"scrap":
			# Both sides get it, so a playtest isn't stuck waiting on the partner.
			for side in [WorldLayout.WEST, WorldLayout.EAST]:
				Economy.earn(side, {&"scrap": 500, &"chitin": 50})
		"spawn":
			var ids: Array = Defs.active_bug_ids()
			var id: StringName = ids[_bug_index % ids.size()]
			_bug_index += 1
			var d := Defs.bug(id)
			(world.get("bugs") as BugManager).spawn_group(id, d.group_size, WorldLayout.other_cliff(cid), randi() % 5)
		"god":
			GameState.god_mode = not GameState.god_mode
			print("God mode: ", GameState.god_mode)


## Debug tab buttons: "skip", "scrap", "spawn", "god", "lanes".
func run(kind: String) -> void:
	match kind:
		"skip":
			GameState.debug_skip()
		"lanes":
			_toggle_lanes()
		_:
			_cheat.rpc_id(1, kind)


func _local_cliff() -> int:
	var p := world.call("local_player") as Player
	return p.cliff_id if p != null else WorldLayout.WEST


## Draws each climb lane as a glowing line up both cliff faces.
func _toggle_lanes() -> void:
	if _lanes != null:
		_lanes.queue_free()
		_lanes = null
		return
	var cliffs := world.get("cliffs") as CliffBuilder
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Palette.ACID_GREEN
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for cid in 2:
		for lz in WorldLayout.LANE_Z:
			var y := 0.0
			while y < WorldLayout.CLIFF_HEIGHT:
				var n := cliffs.face_normal(cid, y, lz) * 0.3
				im.surface_add_vertex(cliffs.face_point(cid, y, lz) + n)
				im.surface_add_vertex(cliffs.face_point(cid, y + 1.0, lz) + n)
				y += 1.0
	im.surface_end()
	_lanes = MeshInstance3D.new()
	_lanes.mesh = im
	world.add_child(_lanes)


## --peershot: a camera 3.5 m off a remote player's side, looking at them, for one frame.
func _peer_shot(p: Player, path: String) -> void:
	var prev := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	var side := p.global_basis.x.normalized()
	cam.look_at_from_position(p.global_position + side * 3.5 + Vector3.UP * 1.4, p.global_position + Vector3.UP * 0.4)
	cam.make_current()
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[down] peershot saved %s" % path)
	cam.queue_free()
	if prev != null:
		prev.make_current()


func _take_screenshot(path: String) -> void:
	var frames := int(GameState.flag_value("--frames")) if GameState.flag_value("--frames") != "" else 90
	# --seconds=N waits real time instead of a frame count (frame rate varies a lot).
	var seconds := GameState.flag_value("--seconds").to_float()
	for i in 20:
		await get_tree().process_frame
	var player := world.call("local_player") as Player
	var cliffs := world.get("cliffs") as CliffBuilder
	var pos := GameState.flag_value("--pos")
	if player != null and pos != "":
		var p := pos.split(",")
		player.global_position = cliffs.plateau_point(player.cliff_id, p[0].to_float(), p[1].to_float()) + Vector3.UP * 0.2
		player.spawn_transform = player.global_transform
	var look := GameState.flag_value("--look")
	if player != null and look != "":
		var parts := look.split(",")
		player.rotation.y += deg_to_rad(parts[0].to_float())
		player.head.rotation.x = deg_to_rad(parts[1].to_float())
	if GameState.has_flag("--autobuild") and multiplayer.is_server():
		_autobuild()
	if GameState.flag_value("--crewview") != "": # Crewed: crewed gun views (scenes/debug/crewed_views.gd)
		add_child(load("res://scenes/debug/crewed_views.gd").new())
	if (GameState.has_flag("--showcase") or GameState.flag_value("--showcase") != "") and multiplayer.is_server():
		_showcase()
	if GameState.flag_value("--buildmode") != "" and player != null:
		player.build_mode.toggle()
		player.build_mode._select(int(GameState.flag_value("--buildmode")))
	if GameState.flag_value("--house") != "":
		var f := int(GameState.flag_value("--house"))
		for n: Node in world.get_tree().get_nodes_in_group("homesteads"):
			var h := n as Homestead
			h._set_state(clampi(f, 1, 3), f >= 2, f >= 3)
			print("[house] cliff %d at %s, floors %d" % [h.cliff_id, str(h.global_position), h.floors])
	if GameState.has_flag("--houseturrets") and multiplayer.is_server():
		_house_turrets()
	if GameState.flag_value("--openmenu") != "":
		var which := GameState.flag_value("--openmenu")
		var target: Node = null
		match which:
			"vendor":
				target = world.find_child("Vendor", true, false)
			"gunsmith":
				target = world.find_child("GunShop", true, false)
			"ledger":
				target = Homestead.of(0).get_node("Ledger")
			"wardrobe":
				for kv: Array in [["hair", GameState.flag_value("--hairstyle")]]:
					if str(kv[1]) != "":
						Settings.look[kv[0]] = kv[1]
				Wardrobe.open()
			"guide":
				FieldGuide.open()
				if GameState.flag_value("--menutab") != "":
					MenuScreen.instance.tab = int(GameState.flag_value("--menutab"))
					MenuScreen.instance.refresh()
		if target != null:
			Economy.earn(0, {&"corn": 6, &"chili": 3, &"chitin": 30, &"scrap": 200})
			MenuScreen.instance.open(target)
			if GameState.flag_value("--menutab") != "":
				MenuScreen.instance.tab = int(GameState.flag_value("--menutab"))
				MenuScreen.instance.refresh()
	if GameState.flag_value("--weapon") != "" and player != null:
		var wid := StringName(GameState.flag_value("--weapon"))
		# --glass=N: the Dino Rifle's glass fit (DinoGlass, 0-5).
		player.gun.grant(wid, DinoGlass.with_variant(0, int(GameState.flag_value("--glass"))) if GameState.flag_value("--glass") != "" else 0)
		player.gun.equip(wid)
		if GameState.has_flag("--aim"):
			player.gun.aiming = true # hold right click (scope checks)
		if GameState.has_flag("--shooting"):
			# Keep firing (and reloading) so screenshots catch tracers mid-flight.
			var timer := Timer.new()
			timer.wait_time = 0.07
			timer.autostart = true
			add_child(timer)
			timer.timeout.connect(func() -> void:
				player.gun.trigger_held = true
				player.gun.spin = 1.0
				if player.gun.trigger(player.camera):
					player.net.fire(player.camera.global_position, -player.camera.global_transform.basis.z)
				elif player.gun.ammo <= 0:
					player.gun.ammo = player.gun.mag_size())
	if GameState.has_flag("--chestview") and player != null:
		# Stand inside the house looking at the storage chest, with it open.
		var home := Homestead.of(player.cliff_id)
		player.global_position = home.to_global(Vector3(-0.6, 0.15, -0.4))
		player.look_at(home.to_global(HouseBuilder.chest_position() + Vector3(0, 0.15, 0)), Vector3.UP)
		player.rotation.x = 0.0
		player.head.rotation.x = -0.45
		(home.get_node("Chest") as StorageChest).set("_peek", 30.0)
	if GameState.has_flag("--pauseshot"):
		process_mode = Node.PROCESS_MODE_ALWAYS
		PauseVote.instance.toggle_vote()
	if GameState.has_flag("--cover") and player != null:
		var cp := CoveragePreview.new()
		cp.cliffs = Bug.cliffs
		world.add_child(cp)
		cp.show_for(&"gatling_post", 0, Buildable.cell_center(Bug.cliffs, 0, Vector2i(0, 12)), 0, true)
	if GameState.has_flag("--goldwhip") and player != null:
		player.whip.code = 2 | 4 | 8 | 16 | WeaponMods.GOLDEN_BIT
	if GameState.has_flag("--lashing") and player != null:
		# Keep lashing the whip so screenshots catch it mid-swing.
		var lt := Timer.new()
		lt.wait_time = 0.8
		lt.autostart = true
		add_child(lt)
		lt.timeout.connect(func() -> void: player.whip.lash())
	if GameState.has_flag("--downed") and player != null:
		player.vitals.apply_damage(99999.0) # knocked down (screenshots of the downed pose)
	if GameState.flag_value("--hold") != "" and player != null:
		player.gun.hold_item(StringName(GameState.flag_value("--hold")))
	if GameState.flag_value("--vmcam") != "" and player != null:
		# Look at the first-person gun and hands from outside: side, top or front.
		var vc := Camera3D.new()
		vc.fov = 40.0
		vc.near = 0.01
		player.camera.add_child(vc)
		var target := Vector3(0.12, -0.2, -0.45)
		match GameState.flag_value("--vmcam"):
			"top":
				vc.position = target + Vector3(0.0, 0.75, 0.05)
			"front":
				vc.position = target + Vector3(0.1, 0.05, -0.8)
			"left":
				vc.position = target + Vector3(-0.8, 0.05, 0.0)
			"close":
				target = Vector3(0.2, -0.24, -0.45)
				vc.position = target + Vector3(0.32, 0.06, 0.12)
			_:
				vc.position = target + Vector3(0.8, 0.05, 0.0)
		vc.look_at(player.camera.to_global(target), player.camera.global_basis.y)
		vc.current = true
	if GameState.has_flag("--lighter") and player != null:
		player.gun.hold_item(&"lighter")
		player.lighter.debug_light()
	if GameState.has_flag("--grapple") and player != null:
		# Hold the grapple and hang a rope off the windmill-ish spot ahead.
		player.grapple.test_mode = true
		player.hotbar_use_grapple()
		player.grapple.attach(Grapple.Mode.PULL, player.global_position - player.global_basis.z * 25.0 + Vector3.UP * 9.0)
		player.grapple.mode = Grapple.Mode.NONE
	if GameState.flag_value("--reload") != "" and player != null:
		# Start a reload with N rounds missing, then wait --reloadwait seconds.
		player.gun.ammo = player.gun.def.mag_size - int(GameState.flag_value("--reload"))
		player.gun.reload()
		await get_tree().create_timer(GameState.flag_value("--reloadwait").to_float()).timeout
	if GameState.has_flag("--falltest") and player != null:
		# Drop off the west lip into the canyon and log the fall.
		player.global_position = Vector3(-WorldLayout.HALF_GAP + 3.0, WorldLayout.CLIFF_HEIGHT - 2.0, 4.0)
		player.velocity = Vector3(2, 0, 0)
		var t0 := Time.get_ticks_msec()
		var landed := false
		player.fall_landed.connect(func() -> void:
			landed = true
			print("[fall] landed after %.2f s at y %.1f" % [(Time.get_ticks_msec() - t0) / 1000.0, player.global_position.y]))
		var top_speed := 0.0
		var wait := GameState.flag_value("--fallwait").to_float()
		while (wait <= 0.0 and not landed and Time.get_ticks_msec() - t0 < 10000) or (wait > 0.0 and Time.get_ticks_msec() - t0 < wait * 1000.0):
			await get_tree().physics_frame
			top_speed = maxf(top_speed, -player.velocity.y)
		print("[fall] top speed %.1f m/s, intensity %.2f" % [top_speed, player.fall_intensity])
	if GameState.flag_value("--weathernow") != "":
		GameState._sync_phase(GameState.phase, GameState.time_left, GameState.wave, int(GameState.flag_value("--weathernow")))
		await get_tree().create_timer(5.5).timeout
	if GameState.has_flag("--rocktest") and player != null:
		# Throw a rock, then get bonked by one from the side; report the shove.
		player.net.throw_rock(player.camera.global_position + Vector3(0, 0, -0.4), Vector3(0, 3, -18))
		await get_tree().create_timer(0.2).timeout
		var before := player.global_position
		player.net._bonked(Vector3(1, 0, 0), 1.0)
		await get_tree().create_timer(GameState.flag_value("--rockwait").to_float() if GameState.flag_value("--rockwait") != "" else 0.5).timeout
		print("[rock] rocks in flight %d, shoved %.2f m, stagger left %.2f" % [get_tree().current_scene.get_children().filter(func(n: Node) -> bool: return n is PlayerNet.Rock).size(),
				before.distance_to(player.global_position), player._stagger])
	if GameState.has_flag("--smoke") and player != null and player.cigarette != null:
		player.cigarette.light()
	if GameState.flag_value("--buildmenu") != "" and player != null:
		player.build_mode.toggle()
		player.build_mode.show_category(int(GameState.flag_value("--buildmenu")))
		player.build_mode.open_menu()
	if GameState.flag_value("--pause") != "":
		var pm := world.get_node("PauseMenu") as PauseMenu
		pm.open()
		pm.select_tab(int(GameState.flag_value("--pause")))
	var start := Time.get_ticks_msec()
	var i := 0
	while (seconds > 0.0 and Time.get_ticks_msec() - start < int(seconds * 1000.0)) or (seconds <= 0.0 and i < frames):
		await get_tree().process_frame
		i += 1
		if player != null and look != "":
			player.head.rotation.x = deg_to_rad(look.split(",")[1].to_float())
		_apply_freecam(player)
		if i == 30 and GameState.has_flag("--autoskip"):
			GameState.vote_skip()
		if player != null and GameState.has_flag("--autofire") and i % 40 == 0:
			if player.gun.trigger(player.camera):
				player.net.fire(player.camera.global_position, -player.camera.global_transform.basis.z)
	var players_root := world.get("players_root") as Node3D
	print("[peer %d] phase %d wave %d, players %d, bugs %d, homesteads %s" % [multiplayer.get_unique_id(),
			GameState.phase, GameState.wave, players_root.get_child_count(),
			(world.get("bugs") as BugManager).alive_count(), str(GameState.homestead_hp)])
	var shown := 0
	for b: Node in get_tree().get_nodes_in_group("bugs"):
		if shown < 4:
			var bug := b as Bug
			print("  bug %s %s state %d y %.1f z %.1f at %s visible %s" % [bug.name, bug.def.id, bug.state, bug.climb_y, bug.lane_z, str(bug.global_position.snapped(Vector3.ONE * 0.1)), bug.is_visible_in_tree()])
			shown += 1
	for p: Node in players_root.get_children():
		print("[peer %d]   player %s at %s" % [multiplayer.get_unique_id(), p.name, str((p as Node3D).global_position.snapped(Vector3.ONE * 0.1))])
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved screenshot to ", path)
	get_tree().quit()


## --cam=x,y,z,tx,ty,tz puts the camera at a fixed spot looking at a target.
func _apply_freecam(player: Player) -> void:
	var cam := GameState.flag_value("--cam")
	if player == null or cam == "":
		return
	var v := cam.split(",")
	var from := Vector3(v[0].to_float(), v[1].to_float(), v[2].to_float())
	var to := Vector3(v[3].to_float(), v[4].to_float(), v[5].to_float())
	player.camera.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


## Spends each cliff's scrap on the next free turret slot (Buffalo every third).
func _reinvest(builds: BuildManager) -> void:
	# Farm first (plant, water, harvest every plot) and use the wells, like a player would.
	_farm()
	var turret_cycle: Array[StringName] = [&"gatling_post", &"buffalo_rifle", &"water_cannon",
		&"gatling_post", &"chili_mortar", &"dynamite_lobber", &"lasso_harpoon"]
	var trap_cycle: Array[StringName] = [&"lantern_post", &"barbed_wire", &"bear_trap", &"dynamite_crate", &"palisade", &"rain_catcher"]
	for cid in WorldLayout.cliff_count():
		var i := 0
		for col in Buildable.COLS:
			var id := turret_cycle[i % turret_cycle.size()]
			if not builds.is_free(cid, Vector2i(0, col)):
				i += 1
				continue
			if Economy.amount(cid, &"scrap") < Defs.cost_of(id):
				break
			builds.build(id, cid, Vector2i(0, col))
			i += 1
		# Spare scrap goes into traps around the Homestead.
		var j := 0
		for col: int in [7, 9, 11, 13, 8, 12]:
			var tid := trap_cycle[j % trap_cycle.size()]
			j += 1
			var cell := Vector2i(1, col)
			if builds.is_free_for(tid, cid, cell) and Economy.amount(cid, &"scrap") >= Defs.cost_of(tid) + 60:
				builds.build(tid, cid, cell)
		# Upgrade a turret with spare chitin.
		for col in Buildable.COLS:
			var t := builds.turret_at(cid, Vector2i(0, col))
			if t != null and t.upgrade_cost() > 0 and Economy.amount(cid, &"chitin") >= t.upgrade_cost():
				builds.upgrade_node(t)
				break


func _farm() -> void:
	for n: Node in get_tree().get_nodes_in_group("crops"):
		var plot := n as CropPlot
		for k in 2:
			plot.local_interact(false)
	for n: Node in get_tree().get_nodes_in_group("water_sources"):
		(n as WaterSource).local_interact(false)


## Test helper: one of each bug, frozen on the west face (lanes 1-4, 25 m up) for portraits.
func _showcase() -> void:
	var bm := world.get("bugs") as BugManager
	var lane := 1
	if GameState.flag_value("--showcase") == "7":
		# Scaffold test: two levels + three turrets stacked on one west cell.
		var b := world.get("builds") as BuildManager
		Economy.earn(WorldLayout.WEST, {&"scrap": 1000})
		var cell := Vector2i(0, 9)
		b.build(&"scaffold", WorldLayout.WEST, cell)
		await get_tree().process_frame
		b.build(&"scaffold", WorldLayout.WEST, cell)
		for i in 3:
			b.build(&"gatling_post", WorldLayout.WEST, cell)
			await get_tree().process_frame
		b.build(&"buffalo_rifle", WorldLayout.WEST, Vector2i(0, 11))
		await get_tree().process_frame
		print("[scaffold] levels %d, turrets %d, a 4th fits: %s" % [b.scaffold_levels(WorldLayout.WEST, cell), b.turrets_on(WorldLayout.WEST, cell).size(), b.is_free_for(&"gatling_post", WorldLayout.WEST, cell)])
		for t in b.turrets_on(WorldLayout.WEST, cell):
			print("[scaffold]   level %d at y %.1f look-down %.0f deg" % [t.level, t.global_position.y, t.pitch_limit()])
		return
	elif GameState.flag_value("--showcase") == "6":
		# Shop test: sell corn at the vendor, buy and fire the shotgun.
		var vendor := world.find_child("Vendor", true, false) as VendorCart
		var shop := world.find_child("GunShop", true, false) as GunShop
		Economy.earn(WorldLayout.WEST, {&"corn": 20, &"chitin": 5})
		var before := Economy.amount(WorldLayout.WEST, &"chitin")
		for i in 12:
			vendor._sell(1, &"corn")
		print("[shop] corn price now %.2f, chitin %d -> %d" % [vendor.market.price(&"corn"), before, Economy.amount(WorldLayout.WEST, &"chitin")])
		Economy.earn(WorldLayout.WEST, {&"chitin": 40})
		shop._buy(1, "buy", &"coach_shotgun")
		shop._buy(1, "upgrade", &"coach_shotgun")
		var p := world.call("local_player") as Player
		print("[shop] owns shotgun: %s level %d, chitin left %d" % [p.gun.owns(&"coach_shotgun"), p.gun.level_of(&"coach_shotgun"), Economy.amount(WorldLayout.WEST, &"chitin")])
		p.gun.equip(&"coach_shotgun")
		var shots := 0
		if p.gun.trigger(p.camera):
			p.net.fire(p.camera.global_position, -p.camera.global_transform.basis.z)
			shots += 1
		var seeds0 := Economy.amount(WorldLayout.WEST, &"seed_corn")
		vendor._sell(1, &"seed_corn")
		vendor._sell(1, &"seed_corn")
		var seeds1 := Economy.amount(WorldLayout.WEST, &"seed_corn")
		var plot := world.get_node("Dressing").get_node("Plot0_0_0") as CropPlot
		plot._use(1, &"corn")
		print("[shop] corn seeds %d -> bought -> %d -> planted -> %d, plot stage %d" % [seeds0, seeds1, Economy.amount(WorldLayout.WEST, &"seed_corn"), plot.growth.stage])
		print("[shop] fired shotgun: %d, ammo %d/%d, pellets %d" % [shots, p.gun.ammo, p.gun.def.mag_size, Gun.shot_dirs(&"coach_shotgun", Vector3.FORWARD, 7).size()])
		return
	elif GameState.flag_value("--showcase") == "5":
		# Plateau-guard test: two last-line turrets on the west plateau, breachers on it,
		# and climbers on both cliff faces that the guards must ignore.
		var builds := world.get("builds") as BuildManager
		var cl := world.get("cliffs") as CliffBuilder
		Economy.earn(WorldLayout.WEST, {&"scrap": 500})
		builds.build(&"scattergun_post", WorldLayout.WEST, Vector2i(4, 9))
		builds.build(&"sharpshooter_tower", WorldLayout.WEST, Vector2i(5, 12))
		for i in 3:
			bm.spawn_at(&"rattler_beetle", WorldLayout.WEST, 2, 0.0, 0.0, Bug.State.BREACHING, cl.plateau_point(WorldLayout.WEST, 3.0, -4.0 + i * 4.0))
		bm.spawn_group(&"spitter_scorpion", 1, WorldLayout.WEST, 1, 55.0)
		bm.spawn_group(&"spitter_scorpion", 1, WorldLayout.EAST, 3, 55.0)
		return
	elif GameState.flag_value("--showcase") == "8":
		# Face check: bugs standing on the west plateau, looking toward the house.
		var cl := world.get("cliffs") as CliffBuilder
		var zs := [-3.0, 0.0, 3.2]
		var ids: Array[StringName] = [&"dust_mite", &"wolf_spider", &"rattler_beetle"]
		for i in 3:
			bm.spawn_at(ids[i], WorldLayout.WEST, 2, zs[i], 0.0, Bug.State.BREACHING, cl.plateau_point(WorldLayout.WEST, 6.0, zs[i]))
	elif GameState.flag_value("--showcase") == "4":
		# Turret reach test: frozen spitters on the east face at the old and new cling heights.
		bm.spawn_group(&"spitter_scorpion", 1, WorldLayout.EAST, 1, 39.0)
		bm.spawn_group(&"spitter_scorpion", 1, WorldLayout.EAST, 3, 47.0)
	elif GameState.flag_value("--showcase") == "3":
		bm.spawn_group(&"iron_tumble", 1, WorldLayout.WEST, 2, 25.0)
	elif GameState.flag_value("--showcase") == "2":
		for id: StringName in [&"brood_mother", &"spiderling", &"crop_weevil"]:
			bm.spawn_group(id, 1, WorldLayout.WEST, lane, 25.0)
			lane += 1
		var cliffs := world.get("cliffs") as CliffBuilder
		bm.spawn_at(&"burrow_tick", WorldLayout.WEST, 4, 16.0, 0.0, Bug.State.BREACHING, cliffs.plateau_point(WorldLayout.WEST, 3.0, 16.0))
		bm.spawn_at(&"dragonfly_bandit", WorldLayout.WEST, 4, 20.0, 0.0, Bug.State.FLYING, Vector3(-18.0, 30.0, 20.0))
	else:
		for id: StringName in [&"dust_mite", &"wolf_spider", &"rattler_beetle", &"spitter_scorpion"]:
			bm.spawn_group(id, 1, WorldLayout.WEST, lane, 25.0)
			lane += 1
	await get_tree().process_frame
	for b: Node in get_tree().get_nodes_in_group("bugs"):
		(b as Bug).speed_mult = 0.0


## Test helper: a row of turrets on both cliffs (free).
func _autobuild() -> void:
	var builds := world.get("builds") as BuildManager
	if GameState.has_flag("--light"):
		# Realistic start: what the starting scrap buys, then reinvest each build phase.
		for cid in WorldLayout.cliff_count():
			for col: int in [6, 13]:
				builds.build(&"gatling_post", cid, Vector2i(0, col))
		GameState.phase_changed.connect(func(p: GameState.Phase) -> void:
			if p == GameState.Phase.BUILD:
				_reinvest(builds))
		return
	# Maps: every cliff; the bigger maps also need guns on both lip ends.
	var cols: Array = [3, 6, 9, 12, 15] if WorldLayout.map().is_canyon() else [1, 3, 6, 9, 12, 15, 17]
	for cid in WorldLayout.cliff_count():
		Economy.earn(cid, {&"scrap": 1000})
		for col: int in cols:
			builds.build(&"gatling_post", cid, Vector2i(0, col))
		for col: int in [5, 11]:
			builds.build(&"buffalo_rifle", cid, Vector2i(0, col))



## --stress=N: N bugs of every kind climbing both cliffs (plus --autobuild
## turrets if given); prints frame timings and render counts every 2 s for 12 s.
func _stress(count: int) -> void:
	for i in 30:
		await get_tree().process_frame
	if GameState.has_flag("--autobuild") and multiplayer.is_server():
		_autobuild()
	var bm := world.get("bugs") as BugManager
	var ids: Array = Defs.active_bug_ids()
	ids = ids.filter(func(id: StringName) -> bool: return Defs.bug(id).behavior != BugDef.Behavior.BOSS and not [&"locust", &"hive_drone"].has(id)) # every boss (and their minions) out: the same mix as before the bosses
	# Look across at the far wall so the bugs are on screen.
	var pl := world.call("local_player") as Player
	if pl != null:
		pl.head.rotation.x = -0.35
	for i in count:
		bm.spawn_group(ids[i % ids.size()], 1, i % WorldLayout.cliff_count(), i % 5, float(i % 7) * 4.0)
	await get_tree().create_timer(1.0).timeout
	var pic := GameState.flag_value("--stressshot")
	if pic != "":
		await get_tree().create_timer(float(GameState.flag_value("--seconds")) if GameState.flag_value("--seconds") != "" else 4.0).timeout
		get_viewport().get_texture().get_image().save_png(pic)
		print("[stress] screenshot ", pic)
	CpuProf.install(get_tree().root)
	for s in 6:
		CpuProf.reset()
		var t0 := Time.get_ticks_msec()
		var frames := Engine.get_frames_drawn()
		var proc := 0.0
		var phys := 0.0
		var n := 0
		var gaps: Array[float] = []
		var last := Time.get_ticks_usec()
		while Time.get_ticks_msec() - t0 < 2000:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			gaps.append(float(now - last) / 1000.0)
			last = now
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			n += 1
		var fps := float(Engine.get_frames_drawn() - frames) / 2.0
		gaps.sort()
		# Worst frame and the 1%-low frame time (the slowest 1% of frames).
		print("[stress]   frame ms: median %.1f  1%%-low %.1f  worst %.1f  bug update %.0f us" % [
			gaps[gaps.size() / 2], gaps[int(gaps.size() * 0.99)], gaps[gaps.size() - 1], BugManager._avg_us])
		print("[stress] bugs %d  fps %.0f  process %.2f ms  physics %.2f ms  draw calls %d  objects %d  nodes %d" % [
			get_tree().get_nodes_in_group("bugs").size(), fps if fps > 0 else float(n) / 2.0, proc / n * 1000.0, phys / n * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		var vp := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		print("[stress]   render cpu %.2f ms  gpu %.2f ms  frame cpu %.2f ms  video mem %.0f MB  textures %.0f MB  static mem %.0f MB" % [RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp), RenderingServer.get_frame_setup_time_cpu(),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
		print("[stress]   ", CpuProf.report())
		print("[stress]   physics active %d  pairs %d  islands %d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)])
		var kinds := {}
		var states := {}
		for nd in get_tree().root.find_children("*", "", true, false):
			var k := nd.get_class() + ("/" + (nd.get_script() as Script).resource_path.get_file() if nd.get_script() != null else "")
			kinds[k] = int(kinds.get(k, 0)) + 1
		for b in get_tree().get_nodes_in_group("bugs"):
			var st := str(b.get("state"))
			states[st] = int(states.get(st, 0)) + 1
		var top := kinds.keys()
		top.sort_custom(func(x, y) -> bool: return kinds[x] > kinds[y])
		print("[stress]   states ", states, "  top ", top.slice(0, 8).map(func(k) -> String: return "%s=%d" % [k, kinds[k]]))
	get_tree().quit()


## --grappletest: pulls the player to a point 18 m away and 6 m up, then swings
## them from an anchor 12 m overhead; prints where they end up. Works headless.
func _grapple_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var g := player.grapple
	g.test_mode = true
	player.hotbar_use_grapple()
	var start := player.global_position
	var fwd := -player.global_basis.z
	var target := start + fwd * 18.0 + Vector3.UP * 6.0
	g.attach(Grapple.Mode.PULL, target)
	var t := 0.0
	while g.is_active() and t < 3.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	print("[grapple] pull: %.2f s, ended %.1f m from the hook point (started 19 m away)" % [t, (player.global_position + Vector3.UP * 0.9).distance_to(target)])
	await get_tree().create_timer(1.0).timeout
	var anchor := player.global_position + Vector3.UP * 12.0 + fwd * 4.0
	player.velocity = fwd * -6.0 + Vector3.UP * 2.0
	Input.action_press("alt_fire")
	g.attach(Grapple.Mode.SWING, anchor)
	var rope := g._rope_len
	var max_err := 0.0
	var lowest := INF
	for i in 120:
		await get_tree().physics_frame
		var d := (player.global_position + Vector3.UP * 0.9).distance_to(anchor)
		max_err = maxf(max_err, d - rope)
		lowest = minf(lowest, player.global_position.y)
	Input.action_release("alt_fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("[grapple] swing: rope %.1f m, worst stretch %.2f m, lowest point %.1f m below the anchor, released: %s" % [rope, max_err, anchor.y - lowest, not g.is_active()])
	# Reel in: swing and hold left click too.
	await get_tree().create_timer(1.0).timeout
	var anchor2 := player.global_position + Vector3.UP * 16.0 + fwd * 3.0
	Input.action_press("alt_fire")
	g.attach(Grapple.Mode.SWING, anchor2)
	var d0 := (player.global_position + Vector3.UP * 0.9).distance_to(anchor2)
	g.reel_test = true
	for i in 90:
		await get_tree().physics_frame
	var d1 := (player.global_position + Vector3.UP * 0.9).distance_to(anchor2)
	g.reel_test = false
	Input.action_release("alt_fire")
	print("[grapple] reel in: %.1f m from the hook -> %.1f m after 1.5 s holding left click" % [d0, d1])
	get_tree().quit()


## --grappleprobe: rays (the hook's mask) from each lip and from mid-air in
## the gap at every cliff face; logs what each one catches.
func _grapple_probe() -> void:
	for i in 30:
		await get_tree().physics_frame
	var cliffs := world.get("cliffs") as CliffBuilder
	var space := (world as Node3D).get_world_3d().direct_space_state
	var n := WorldLayout.cliff_count()
	var hits := 0
	var total := 0
	for cid in n:
		for other in n:
			for y: float in [15.0, 30.0, 45.0, 55.0]:
				for z: float in [-10.0, 0.0, 10.0]:
					var target := cliffs.face_point(other, y, z)
					var from := cliffs.plateau_point(cid, 1.0, 0.0) + Vector3.UP * 1.6
					if cid == other:
						# Own face: from out over the gap, as when you've dropped off the lip.
						from = target + WorldLayout.inward(other) * 12.0 + Vector3.UP * 4.0
					var dir := (target - from).normalized()
					var q := PhysicsRayQueryParameters3D.create(from, from + dir * 250.0, Grapple.MASK)
					var hit := space.intersect_ray(q)
					total += 1
					var what := "MISS (want %.1f, long ray: %s)" % [from.distance_to(target), "nothing" if hit.is_empty() else "%s %.1f" % [(hit["collider"] as Node).name, from.distance_to(hit["position"])]]
					if not hit.is_empty() and from.distance_to(hit["position"]) <= Grapple.RANGE:
						hits += 1
						what = "%s %.1f m (want %.1f)" % [(hit["collider"] as Node).name, from.distance_to(hit["position"]), from.distance_to(target)]
					print("[gprobe] cliff %d -> face %d y %.0f z %.0f: %s" % [cid, other, y, z, what])
	print("[gprobe] %d/%d caught" % [hits, total])
	get_tree().quit()


## --framecover [--map=..]: a gatling goes up in its frame (ground level) on
## row-0 cells of every cliff; logs how much of the covered wall it can see
## (arc + line of sight, the turret's own check) from where it stands, against
## the same gun 3 m up (where the first turret used to stand on its scaffold).
func _frame_cover() -> void:
	for i in 30:
		await get_tree().physics_frame
	var bm := BuildManager.instance
	var cliffs := Bug.cliffs
	var space := (world as Node3D).get_world_3d().direct_space_state
	var tot := [0, 0, 0, 0, 0, 0]
	for cid in WorldLayout.cliff_count():
		Economy.earn(cid, {&"scrap": 2000})
		for col: int in [3, 9, 15]:
			bm.build(&"gatling_post", cid, Vector2i(0, col))
	await get_tree().create_timer(1.0).timeout
	for t: Node in get_tree().get_nodes_in_group("turrets"):
		var tu := t as Turret
		if tu.cell.x != 0:
			continue
		var m0 := tu._sight_point()
		var other := tu.covers
		var zc := cliffs.plateau_coords(other, m0).y
		var seen := [0, 0, 0, 0, 0]
		var n := 0
		for y in range(2, 59, 2):
			for dz in range(-12, 13, 3):
				var fp := cliffs.face_point(other, float(y), zc + dz) + WorldLayout.inward(other) * 0.8
				n += 1
				for k in 5:
					var m := m0 + Vector3.UP * ([0.0, 3.0, 1.0, 1.5, 2.0][k] as float)
					var pl := tu.pitch_limit()
					if not Targeting.in_arc(m, fp, pl, tu.def.range * tu.range_multiplier()):
						continue
					if space.intersect_ray(PhysicsRayQueryParameters3D.create(m, fp, WorldLayout.LAYER_WORLD)).is_empty():
						seen[k] += 1
		tot[0] += n
		tot[1] += seen[0]
		tot[2] += seen[1]
		tot[3] += seen[2]
		tot[4] += seen[3]
		tot[5] += seen[4]
		print("[fcover] cliff %d col %d level %d: sees %d/%d of the wall in the frame, %d/%d from 3 m up" % [tu.cliff_id, tu.cell.y, tu.level, seen[0], n, seen[1], n])
	print("[fcover] total of %d: in the frame %d, 3 m up %d; 1 m up %d, 1.5 m up %d, 2 m up %d" % [tot[0], tot[1], tot[2], tot[3], tot[4], tot[5]])
	get_tree().quit()


## --frameview=<png> [--frameangle=deg] [--framedist=m]: turrets in their
## scaffold frames (one, two and three storeys on the local cliff), seen from
## the plateau behind them; saves the picture and quits.
func _frame_view(path: String) -> void:
	for i in 30:
		await get_tree().physics_frame
	var bm := BuildManager.instance
	var player := world.call("local_player") as Player
	var cid := player.cliff_id
	Economy.earn(cid, {&"scrap": 3000})
	var stacks := [[&"gatling_post"], [&"buffalo_rifle", &"gatling_post"], [&"water_cannon", &"duck_gun", &"buffalo_rifle"]]
	var cols := [5, 7, 9]
	for i in 3:
		for id: StringName in stacks[i]:
			bm.build(id, cid, Vector2i(0, cols[i]))
			await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(1.0).timeout
	var mid := Buildable.cell_center(Bug.cliffs, cid, Vector2i(0, 7))
	var inward := WorldLayout.inward(cid)
	var along := inward.cross(Vector3.UP).normalized()
	var ang := deg_to_rad(GameState.flag_value("--frameangle").to_float() if GameState.flag_value("--frameangle") != "" else 35.0)
	var dist := GameState.flag_value("--framedist").to_float() if GameState.flag_value("--framedist") != "" else 11.0
	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	var back := (-inward * cos(ang) + along * sin(ang)).normalized()
	cam.global_position = mid + back * dist + Vector3.UP * 4.5
	cam.look_at(mid + Vector3.UP * 2.6, Vector3.UP)
	cam.current = true
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## --grapplewall [--map=..]: step off your lip, and on the way down hook the
## facing wall (pull), then hang off it on a swing rope; logs whether the fall
## was called off and whether you ever ended up inside or through the rock.
## With --gshot=<png> it saves a view mid-swing instead of quitting at the end.
func _grapple_wall_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	# A client's own player arrives a little later (spawned by the host).
	var player := world.call("local_player") as Player
	var wait := 0
	while (player == null or not player.is_node_ready() or player.grapple == null) and wait < 1200:
		await get_tree().physics_frame
		wait += 1
		player = world.call("local_player") as Player
	if player == null:
		print("[gwall] no local player")
		return
	await get_tree().create_timer(GameState.flag_value("--gwallat").to_float()).timeout # --gwallat=S: start later
	var cliffs := world.get("cliffs") as CliffBuilder
	var g := player.grapple
	g.test_mode = true
	player.hotbar_use_grapple()
	var cid := player.cliff_id
	var other := 1 if cid == 0 else 0
	var inward := WorldLayout.inward(cid)
	player.global_position = cliffs.plateau_point(cid, 0.0, 0.0) + inward * 3.5 + Vector3.UP * 0.5
	player.velocity = inward * 3.0
	var t := 0.0
	while not player.is_plummeting() and t < 4.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for i in 20:
		await get_tree().physics_frame
	print("[gwall] falling after %.1f s at y %.1f, plummeting %s" % [t, player.global_position.y, player.is_plummeting()])
	var aim_at := func(p: Vector3) -> void:
		var d := (p - player.camera.global_position).normalized()
		player.rotation.y = atan2(-d.x, -d.z)
		player.head.rotation.x = asin(clampf(d.y, -1.0, 1.0))
	# The space a body may occupy: from mid-gap toward the wall, the rock must
	# not come before the body does.
	var space := player.get_world_3d().direct_space_state
	var worst := [0.0]
	var check := func(face_cid: int) -> void:
		var c := player.global_position + Vector3.UP * 0.9
		var mid := c + WorldLayout.inward(face_cid) * 8.0
		var q := PhysicsRayQueryParameters3D.create(mid, c, WorldLayout.LAYER_WORLD, [player.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			worst[0] = maxf(worst[0], (hit["position"] as Vector3).distance_to(c))
	var target := cliffs.face_point(other, player.global_position.y - 4.0, 2.0)
	aim_at.call(target)
	await get_tree().physics_frame
	Input.action_press("fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("fire")
	print("[gwall] pull hooked: %s (anchor %.1f m off the aimed rock), plummeting %s" % [g.is_active(), g.anchor.distance_to(target), player.is_plummeting()])
	t = 0.0
	while g.is_active() and t < 5.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		check.call(other)
	print("[gwall] pull arrived in %.2f s, %.1f m from the hook, worst depth into rock %.2f m" % [t, (player.global_position + Vector3.UP * 0.9).distance_to(g.anchor), worst[0]])
	# Swing: hook the wall above you and hang there, pumping into the rock.
	for i in 30:
		await get_tree().physics_frame
	var up := cliffs.face_point(other, player.global_position.y + 9.0, 6.0)
	aim_at.call(up)
	await get_tree().physics_frame
	Input.action_press("alt_fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("[gwall] swing hooked: %s, plummeting %s" % [g.is_active(), player.is_plummeting()])
	worst[0] = 0.0
	Input.action_press("move_forward")
	var shot := GameState.flag_value("--gshot")
	for i in 180:
		await get_tree().physics_frame
		check.call(other)
		if i == 120 and shot != "":
			# Look back along the gap for the picture.
			player.rotation.y += PI * 0.75
			player.head.rotation.x = 0.35
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot)
	Input.action_release("move_forward")
	print("[gwall] swing 3 s: still hooked %s, rope %.1f m, now %.1f m from the hook, worst depth into rock %.2f m, y %.1f" % [g.is_active(), g._rope_len, (player.global_position + Vector3.UP * 0.9).distance_to(g.anchor), worst[0], player.global_position.y])
	# Reel up the wall.
	g.reel_test = true
	for i in 120:
		await get_tree().physics_frame
		check.call(other)
	g.reel_test = false
	Input.action_release("alt_fire")
	await get_tree().physics_frame
	print("[gwall] reeled 2 s: %.1f m from the hook, worst depth %.2f m, released %s" % [(player.global_position + Vector3.UP * 0.9).distance_to(g.anchor), worst[0], not g.is_active()])
	get_tree().quit()


## --ziptest: both houses get towers; the local player climbs the west tower's
## ladder, rides the zip line to the east tower and the run is logged.
func _zip_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	for cid in 2:
		Homestead.of(cid)._set_state(3, false, false, true)
	await get_tree().physics_frame
	var line := ZipLine.current(get_tree())
	print("[zip] line exists: %s, span %.1f m" % [line != null, line.a.distance_to(line.b) if line != null else 0.0])
	var player := world.call("local_player") as Player
	var home := Homestead.of(player.cliff_id)
	# Ladder: stand at its foot on the roof deck and hold forward.
	var box := HouseBuilder.tower_ladder_box()
	player.global_position = home.to_global(Vector3(box.get_center().x, HouseBuilder.H * 3.0 + 0.3, box.position.z - 0.2))
	player.look_at(home.to_global(Vector3(HouseBuilder.TOWER_X, HouseBuilder.H * 3.0 + 0.3, HouseBuilder.TOWER_Z)), Vector3.UP)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	Input.action_press("move_forward")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	for i in 20:
		await get_tree().physics_frame
	var local := home.to_local(player.global_position)
	print("[zip] after the ladder: local %s (platform top %.1f), on floor %s" % [str(local.snapped(Vector3.ONE * 0.1)), HouseBuilder.zip_arrival().y, player.is_on_floor()])
	var other := Homestead.of(WorldLayout.other_cliff(player.cliff_id))
	player.start_zip(line, player.cliff_id == WorldLayout.WEST, other.zip_arrival_global())
	var t := 0.0
	var lowest := INF
	while player.is_ziplining() and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		lowest = minf(lowest, player.global_position.y)
	print("[zip] ride took %.1f s, lowest %.1f m, landed %.1f m from the far platform" % [t, lowest, player.global_position.distance_to(other.zip_arrival_global())])
	get_tree().quit()


## --aatest: one of each air-defence turret on the west cliff's second row, six
## dragonfly bandits flying over the west plateau; logs what's left after 20 s.
func _aa_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	Economy.earn(0, {&"scrap": 2000})
	var ids := [&"duck_gun", &"sky_sweeper", &"powder_flak", &"net_thrower", &"firework_battery"]
	for i in ids.size():
		BuildManager.instance._do_build(1, ids[i], 0, Vector2i(1, 4 + i * 3))
	await get_tree().physics_frame
	var built := 0
	for t: Node in get_tree().get_nodes_in_group("turrets"):
		if (t as Turret).def.anti_air:
			built += 1
	var bm := world.get("bugs") as BugManager
	for i in 6:
		var pos := Bug.cliffs.plateau_point(WorldLayout.WEST, 14.0 + i * 2.0, -12.0 + i * 4.0) + Vector3.UP * 7.0
		bm.spawn_at(&"dragonfly_bandit", WorldLayout.WEST, i % 5, pos.z, 0.0, Bug.State.FLYING, pos)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().physics_frame
	var left := 0
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		if (n as Bug).is_alive():
			left += 1
	print("[aa] built %d air-defence turrets; dragonflies left after 20 s: %d of 6" % [built, left])
	get_tree().quit()


## --porchtest: walks into the house from the yard three ways (up the steps, onto
## the porch's side edge, and straight at the porch's front edge off the steps)
## and logs where the player ended up and how far they got.
func _porch_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var home := Homestead.of(player.cliff_id)
	var hd := HouseBuilder.D * 0.5
	for start: Vector3 in [Vector3(0, 0.3, -hd - 5.0), Vector3(2.6, 0.3, -hd - 5.0), Vector3(-2.4, 0.3, -hd - 5.0)]:
		player.global_position = home.to_global(start)
		player.velocity = Vector3.ZERO
		player.look_at(home.to_global(Vector3(start.x, 0.3, 0.0)), Vector3.UP)
		player.rotation.x = 0.0
		player.rotation.z = 0.0
		for i in 10:
			await get_tree().physics_frame
		Input.action_press("move_forward")
		var t0 := Time.get_ticks_msec()
		var stuck := 0.0
		var last := player.global_position
		while Time.get_ticks_msec() - t0 < 2500:
			await get_tree().physics_frame
			if player.global_position.distance_to(last) < 0.01:
				stuck += get_physics_process_delta_time()
			last = player.global_position
		var c := player.get_last_slide_collision()
		if c != null:
			print("[porch]   touching %s at local %s normal %s" % [c.get_collider(), str(home.to_local(c.get_position()).snapped(Vector3.ONE * 0.05)), str((home.global_basis.inverse() * c.get_normal()).snapped(Vector3.ONE * 0.05))])
		Input.action_release("move_forward")
		var local := home.to_local(player.global_position)
		print("[porch] from x=%.1f: ended at local %s, stuck %.2f s, %s" % [start.x, str(local.snapped(Vector3.ONE * 0.05)), stuck,
				"on the porch or inside" if local.z > -hd - HouseBuilder.PORCH_DEPTH and local.y > 0.25 or local.z > -hd else "did NOT get up"])
	get_tree().quit()


## --chesttest: stores the revolver, corn and water in the house chest, then takes
## them back, logging pockets and chest after each step.
func _chest_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var chest := Homestead.of(player.cliff_id).get_node("Chest") as StorageChest
	Economy.earn(player.cliff_id, {&"corn": 5})
	var log := func(step: String) -> void:
		print("[chest] %s: weapons %s, corn %d, water %d | chest %s %s" % [step, str(player.gun.slots), Economy.amount(player.cliff_id, &"corn"),
				Economy.amount(player.cliff_id, &"water"), str(chest.weapons), str(chest.items)])
	log.call("start")
	chest.menu_press("w:revolver", &"store")
	chest.menu_press("i:corn", &"storeall")
	chest.menu_press("i:water", &"store1")
	await get_tree().physics_frame
	log.call("stored")
	chest.menu_press("w:revolver", &"take")
	chest.menu_press("i:corn", &"take1")
	chest.menu_press("i:water", &"takeall")
	await get_tree().physics_frame
	log.call("took back")
	get_tree().quit()


## --guntest: fires the blunderbuss once and reloads it; holds the crank
## gatling's trigger for 2 s; logs ammo along the way.
func _gun_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var gun := player.gun
	gun.grant(&"blunderbuss", 0)
	gun.equip(&"blunderbuss")
	await get_tree().create_timer(0.5).timeout
	var fired := gun.trigger(player.camera)
	print("[guns] blunderbuss fired %s, ammo %d/%d, second shot allowed: %s" % [fired, gun.ammo, gun.def.mag_size, gun.trigger(player.camera)])
	gun.reload()
	await get_tree().create_timer(3.5).timeout
	print("[guns] blunderbuss after reload: %d/%d" % [gun.ammo, gun.def.mag_size])
	gun.grant(&"crank_gatling", 0)
	gun.equip(&"crank_gatling")
	await get_tree().create_timer(0.5).timeout
	gun.trigger_held = true
	var t0 := Time.get_ticks_msec()
	var first_shot := -1.0
	while Time.get_ticks_msec() - t0 < 2000:
		# (headless has no captured mouse, so the player's input code keeps
		# letting go of the trigger each physics tick: hold it again)
		await get_tree().process_frame
		gun.trigger_held = true
		if gun.trigger(player.camera) and first_shot < 0.0:
			first_shot = (Time.get_ticks_msec() - t0) / 1000.0
	gun.trigger_held = false
	print("[guns] gatling: first shot after %.2f s of cranking, ammo after 2 s held: %d/%d" % [first_shot, gun.ammo, gun.def.mag_size])
	# Gunsmith mods: fit the revolver's hair trigger, then a level upgrade, and check both stick.
	var shop: GunShop = null
	for n: Node in get_tree().get_nodes_in_group("structures"):
		if n is GunShop:
			shop = n
	if shop == null:
		shop = get_tree().root.find_child("GunShop*", true, false) as GunShop
	Economy.earn(player.cliff_id, {&"chitin": 200})
	gun.equip(&"revolver")
	var before := gun.fire_interval()
	if shop != null:
		shop._buy(multiplayer.get_unique_id(), "mod", &"revolver", 0)
		shop._buy(multiplayer.get_unique_id(), "upgrade", &"revolver")
	await get_tree().physics_frame
	print("[guns] revolver mods: code %d, level %d, hair trigger %s, interval %.3f -> %.3f, shop found %s" % [gun.code_of(&"revolver"),
			gun.level_of(&"revolver"), WeaponMods.has_mod(gun.code_of(&"revolver"), 0), before, gun.fire_interval(), shop != null])
	get_tree().quit()


## --slidetest: sprints along the plateau, then does three slide-jumps in a row,
## logging horizontal speed and hop stacks; then waits for the boost to fade.
func _slide_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	player.global_position = Bug.cliffs.plateau_point(player.cliff_id, 8.0, -19.0) + Vector3.UP * 0.5
	player.look_at(Bug.cliffs.plateau_point(player.cliff_id, 8.0, 30.0) + Vector3.UP * 0.5, Vector3.UP)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var speed := func() -> float: return Vector2(player.velocity.x, player.velocity.z).length()
	for i in 25:
		await get_tree().physics_frame
	print("[slide] sprinting: %.1f m/s" % speed.call())
	for hop in 3:
		while not player.is_on_floor():
			await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_press("slide")
		await get_tree().physics_frame
		Input.action_release("slide")
		for i in 5:
			await get_tree().physics_frame
		var sliding: bool = player.get("_sliding")
		Input.action_press("jump")
		await get_tree().physics_frame
		Input.action_release("jump")
		var top := 0.0
		for i in 6:
			await get_tree().physics_frame
			top = maxf(top, speed.call())
		while not player.is_on_floor():
			await get_tree().physics_frame
			top = maxf(top, speed.call())
		print("[slide] hop %d: was sliding %s, stacks %d, top speed %.1f m/s" % [hop + 1, sliding, player.hop_stacks, top])
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500:
		await get_tree().physics_frame
	print("[slide] after 3.5 s: stacks %d" % player.hop_stacks)
	get_tree().quit()


## --archtest: from the west lip under the first arch, aims the grapple straight
## up at it, swings for 2 s and logs what the hook hit.
func _arch_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var g := player.grapple
	g.test_mode = true
	player.hotbar_use_grapple()
	# From the west lip: aim at each arch where it passes over the far (east)
	# rim, pull across (left click), let go and see where you land.
	for z: float in [-17.0, 20.0]:
		player.respawn()
		player.set("_fall_left", -1.0)
		player.global_position = Bug.cliffs.plateau_point(WorldLayout.WEST, 1.0, z) + Vector3.UP * 0.3
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		var from := player.global_position + Vector3.UP * 1.6
		var aim := Vector3(WorldLayout.HALF_GAP + 9.0, from.y + 30.0, z) - from
		var q := PhysicsRayQueryParameters3D.create(from, from + aim.normalized() * Grapple.RANGE, Grapple.MASK, [player.get_rid()])
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			print("[arch] z %.0f: nothing to hook within %d m" % [z, int(Grapple.RANGE)])
			continue
		var p: Vector3 = hit["position"]
		print("[arch] z %.0f: hook hits %s at x %.1f, %.1f m up, %.1f m away" % [z, (hit["collider"] as Node).name, p.x, p.y - player.global_position.y, from.distance_to(p)])
		g.attach(Grapple.Mode.PULL, p)
		var t := 0.0
		while g.is_active() and t < 4.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		var t2 := 0.0
		while not player.is_on_floor() and t2 < 6.0:
			await get_tree().physics_frame
			t2 += get_physics_process_delta_time()
		print("[arch] z %.0f: pulled for %.1f s, landed at x %.1f, y %.1f (%s)" % [z, t, player.global_position.x, player.global_position.y,
				"on the far plateau" if player.global_position.x > WorldLayout.HALF_GAP and player.global_position.y > WorldLayout.CLIFF_HEIGHT - 1.0 else "NOT across"])
	get_tree().quit()


## --loottest: kills one beetle on the west plateau and one on the cliff face;
## only the plateau kill should leave loot. Loots it and logs chitin.
func _loot_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var bm := world.get("bugs") as BugManager
	var pos := Bug.cliffs.plateau_point(WorldLayout.WEST, 12.0, 6.0)
	bm.spawn_at(&"rattler_beetle", WorldLayout.WEST, 2, 6.0, 0.0, Bug.State.BREACHING, pos)
	bm.spawn_group(&"rattler_beetle", 1, WorldLayout.WEST, 3, 20.0)
	for i in 10:
		await get_tree().physics_frame
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		(n as Bug).health.take_damage(99999.0, "test")
	for i in 10:
		await get_tree().physics_frame
	var heaps := get_tree().get_nodes_in_group("loot")
	print("[loot] heaps after killing one plateau bug and one climber: %d" % heaps.size())
	if heaps.is_empty():
		get_tree().quit()
		return
	var drop := heaps[0] as LootDrop
	var before := Economy.amount(player.cliff_id, &"chitin")
	print("[loot] prompt: %s" % drop.interact_prompt())
	drop.local_interact(false)
	for i in 5:
		await get_tree().physics_frame
	print("[loot] chitin %d -> %d, heaps left %d" % [before, Economy.amount(player.cliff_id, &"chitin"), get_tree().get_nodes_in_group("loot").size()])
	get_tree().quit()


## --whiptest: a rattler beetle stands 4 m in front of the player on the plateau;
## lashes three times and logs its health, stun and which swings played.
func _whip_test() -> void:
	for i in 30:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	var bm := world.get("bugs") as BugManager
	player.global_position = Bug.cliffs.plateau_point(WorldLayout.WEST, 10.0, 8.0) + Vector3.UP * 0.3
	var target := Bug.cliffs.plateau_point(WorldLayout.WEST, 10.0, 12.0)
	bm.spawn_at(&"rattler_beetle", WorldLayout.WEST, 2, 12.0, 0.0, Bug.State.BREACHING, target)
	for i in 5:
		await get_tree().physics_frame
	var bug: Bug = null
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		bug = n as Bug
		bug.speed_mult = 0.0
	player.look_at(bug.global_position, Vector3.UP)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	player.head.rotation.x = -0.1
	var moves: Array[int] = []
	for k in 3:
		var hp := bug.health.hp
		player.whip.lash()
		moves.append(player.whip.get("_move"))
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 500:
			await get_tree().physics_frame
		print("[whip] lash %d (swing %d): hp %.0f -> %.0f, stunned %s" % [k + 1, moves[k], hp, bug.health.hp, bug.status.is_rooted()])
		await get_tree().create_timer(0.4).timeout
	# Upgrades: two levels and the barbed popper at the gunsmith, then lash again.
	var shop := get_tree().root.find_child("GunShop*", true, false) as GunShop
	Economy.earn(player.cliff_id, {&"chitin": 200})
	shop._buy(multiplayer.get_unique_id(), "upgrade", &"whip")
	shop._buy(multiplayer.get_unique_id(), "upgrade", &"whip")
	shop._buy(multiplayer.get_unique_id(), "mod", &"whip", 1)
	await get_tree().create_timer(0.8).timeout
	var hp2 := bug.health.hp
	player.whip.lash()
	await get_tree().create_timer(0.5).timeout
	print("[whip] upgraded (code %d, %s): hp %.0f -> %.0f" % [player.whip.code, WeaponMods.names(&"whip", player.whip.code), hp2, bug.health.hp])
	shop._buy(multiplayer.get_unique_id(), "mod", &"whip", 0)
	shop._buy(multiplayer.get_unique_id(), "mod", &"whip", 2)
	shop._buy(multiplayer.get_unique_id(), "gild", &"whip")
	await get_tree().physics_frame
	print("[whip] golden: %s, lash damage %.0f, reach %.1f m" % [WeaponMods.is_golden(player.whip.code), Whip.damage_for(player.whip.code), Whip.reach_for(player.whip.code)])
	get_tree().quit()


## --skyview=<png prefix>: stands on the airship deck and saves a screenshot
## looking each way (N, E, S, W), to check the view from up there.
func _sky_view(prefix: String) -> void:
	for i in 40:
		await get_tree().process_frame
	var pl := world.call("local_player") as Player
	var ship := world.get_node("Airship") as Node3D
	for k in 4:
		# At the rail on each side, looking out and a little down.
		var yaw := float(k) * PI * 0.5
		var out := Vector3(-sin(yaw), 0, -cos(yaw))
		var reach := Vector3(AirshipBuilder.DECK_W * 0.5 - 1.2, 0, AirshipBuilder.DECK_L * 0.5 - 1.2)
		pl.global_position = ship.global_position + Vector3(out.x * reach.x, 0.6, out.z * reach.z)
		pl.velocity = Vector3.ZERO
		pl.rotation.y = yaw
		pl.head.rotation.x = -0.3
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [prefix, k])
		print("[sky] saved %s_%d.png at %s" % [prefix, k, str(pl.global_position)])
	get_tree().quit()


## --plotview=<png>: builds a farm plot just ahead, looks at it and saves a
## screenshot of the prompt card (to check the planting UI).
func _plot_view(path: String) -> void:
	for i in 40:
		await get_tree().process_frame
	var pl := world.call("local_player") as Player
	pl.head.rotation.x = -0.75
	var bm := pl.build_mode
	bm.toggle()
	bm.choose(&"farm_plot")
	for i in 20:
		await get_tree().physics_frame
	BuildManager.instance.build(&"farm_plot", bm.get("_cliff"), bm.get("_cell"))
	bm.toggle()
	for i in 60:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("[plot] saved ", path)
	get_tree().quit()


## --threatview=<png>: puts bugs high on both cliffs and screenshots the
## partner alerts.
func _threat_view(path: String) -> void:
	for i in 40:
		await get_tree().process_frame
	var bm := world.get("bugs") as BugManager
	for cid in 2:
		bm.spawn_group(&"rattler_beetle", 3, cid, 2, 46.0)
	var pl := world.call("local_player") as Player
	pl.head.rotation.x = -0.1
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(path)
	print("[threat] saved ", path)
	get_tree().quit()


## --pingview=<png prefix>: drops a ping, then opens the wheel with "Bugs here"
## picked; screenshots both.
func _ping_view(prefix: String) -> void:
	for i in 40:
		await get_tree().process_frame
	var p := Pings.instance
	var pl := world.call("local_player") as Player
	pl.head.rotation.x = -0.2
	p.call("_send", 1)
	pl.rotate_y(0.5)
	for i in 20:
		await get_tree().process_frame
	p.set("_down", true)
	p.set("_held", 1.0)
	p.set("_wheel", true)
	p.set("_aim", Vector2(0, -80))
	p.set("_choice", 0)
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(prefix + "_wheel.png")
	print("[ping] saved")
	get_tree().quit()


## --housediag [--inwave] [--noidle]: house turrets vs mites standing in the yard; prints each
## targeting check and shots per second (--inwave: during a wave; --noidle: hold _idle_t at 0).
func _house_diag() -> void:
	for i in 30:
		await get_tree().process_frame
	_house_turrets()
	var bm := world.get("bugs") as BugManager
	var home := Homestead.of(0)
	var spot := Vector3(-34.0, 60.3, 1.0)
	bm.spawn_at(&"dust_mite", WorldLayout.WEST, 2, 0.0, 60.0, Bug.State.BREACHING, spot)
	for i in 3:
		await get_tree().physics_frame
	var b: Bug = null
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		b = n as Bug
	if b == null:
		print("[housediag] no bug")
		get_tree().quit()
		return
	print("[housediag] bug %s state %d cliff %d pos %s, home %s dist %.1f (guard %.1f), turrets %d" % [b.def.id, b.state, b.cliff_id, str(b.global_position.snapped(Vector3.ONE * 0.1)), str(home.global_position.snapped(Vector3.ONE * 0.1)), b.global_position.distance_to(home.global_position), Homestead.GUARD_RADIUS, get_tree().get_nodes_in_group("turrets").size()])
	for n: Node in BuildManager.instance.get_children():
		var t := n as Turret
		if t == null or not t.def.guards_house:
			continue
		var head: Node3D = t.get("_head")
		var muzzle := head.global_position
		var to := b.global_position - muzzle
		var pitch := rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
		var q := PhysicsRayQueryParameters3D.create(muzzle, b.global_position, WorldLayout.LAYER_WORLD)
		var hit := t.get_world_3d().direct_space_state.intersect_ray(q)
		print("[housediag] %s cliff %d cell %s muzzle %s dist %.1f pitch %.0f (limit %.0f) valid %s, LOS hit %s at %s" % [t.def.id, t.cliff_id, str(t.cell), str(muzzle.snapped(Vector3.ONE * 0.1)), to.length(), pitch, t.pitch_limit(), t.call("_valid", b), hit.get("collider"), str(hit.get("position"))])
	if GameState.has_flag("--inwave"):
		var t0 := Time.get_ticks_msec()
		while GameState.phase != GameState.Phase.WAVE and Time.get_ticks_msec() - t0 < 60000:
			GameState.vote_skip()
			await get_tree().create_timer(0.5).timeout
		print("[housediag] phase %d wave %d floors %d mounts %d" % [GameState.phase, GameState.wave, home.floors, home.mount_count()])
		for n: Node in BuildManager.instance.get_children():
			if n is Turret and (n as Turret).def.guards_house:
				print("[housediag]   %s cliff %d cell %s alive %s" % [(n as Turret).def.id, (n as Turret).cliff_id, str((n as Turret).cell), is_instance_valid(n)])
	for k in 8:
		bm.spawn_at(&"dust_mite", WorldLayout.WEST, 2, 0.0, 60.0, Bug.State.BREACHING, spot + Vector3(0, 0, k * 0.5))
	var shots0 := {}
	for n: Node in BuildManager.instance.get_children():
		if n is Turret:
			shots0[n] = (n as Turret).shots
	for s in 10:
		for f in 60:
			if GameState.has_flag("--noidle"):
				for t: Turret in shots0:
					t.set("_idle_t", 0.0)
			await get_tree().physics_frame
		var alive := 0
		var where := ""
		for n: Node in get_tree().get_nodes_in_group("bugs"):
			var bb := n as Bug
			if bb.is_alive():
				alive += 1
				where = "%s st %d hidden %s" % [str(bb.global_position.snapped(Vector3.ONE * 0.1)), bb.state, bb.is_hidden()]
		var shot := ""
		for t: Turret in shots0:
			if t.cliff_id == 0:
				shot += " %d" % (t.shots - int(shots0[t]))
		print("[housediag] t %d: alive %d (e.g. %s), west house turret shots%s" % [s + 1, alive, where, shot])
	get_tree().quit()


## --gatlingdiag [--noidle]: five east gatlings vs six beetles held 30 m up the west face during a
## wave; prints shots and beetle HP each second (--noidle: hold _idle_t at 0 to compare).
func _gatling_diag() -> void:
	for i in 30:
		await get_tree().process_frame
	var builds := world.get("builds") as BuildManager
	Economy.earn(1, {&"scrap": 1000})
	for col: int in [3, 6, 9, 12, 15]:
		builds.build(&"gatling_post", 1, Vector2i(0, col))
	var t0 := Time.get_ticks_msec()
	while GameState.phase != GameState.Phase.WAVE and Time.get_ticks_msec() - t0 < 60000:
		GameState.vote_skip()
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(4.0).timeout # turrets go idle
	var bm := world.get("bugs") as BugManager
	for k in 6:
		bm.spawn_at(&"rattler_beetle", WorldLayout.WEST, 2, -6.0 + k * 2.5, 30.0, Bug.State.CLIMBING, Vector3.ZERO)
	var mine: Array[Turret] = []
	for n: Node in builds.get_children():
		if n is Turret and (n as Turret).cliff_id == 1:
			mine.append(n)
	var shots0 := 0
	for t in mine:
		shots0 += t.shots
	for s in 8:
		for f in 60:
			for n: Node in get_tree().get_nodes_in_group("bugs"):
				var b := n as Bug
				if b.def.id == &"rattler_beetle":
					if not b.has_meta("pin"):
						b.set_meta("pin", b.climb_y)
					b.climb_y = float(b.get_meta("pin"))
			if GameState.has_flag("--noidle"):
				for t in mine:
					t.set("_idle_t", 0.0)
			await get_tree().physics_frame
		var shots := 0
		for t in mine:
			shots += t.shots
		var hp := 0.0
		for n: Node in get_tree().get_nodes_in_group("bugs"):
			if (n as Bug).def.id == &"rattler_beetle" and (n as Bug).is_alive():
				hp += (n as Bug).health.hp
		print("[gatdiag] t %d: east gatling shots %d, beetle hp left %.0f, idle_t %.1f" % [s + 1, shots - shots0, hp, float(mine[0].get("_idle_t"))])
	get_tree().quit()
