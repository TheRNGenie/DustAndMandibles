class_name UniversalViews
extends RefCounted
## The universal crop-fed turrets, live (gallery steps uni_*, --uionly=uni_all
## or a prefix): built on your cliff's front row through BuildManager, loaded
## with a different crop each through the host's own load path, then bugs climb
## the far wall and they fire. Photographs:
##   uni_lip_empty / uni_lip_loaded / uni_lip_fire_NN  along the lip (rings, glows, shots)
##   uni_close_<id>         each turret close up while firing
##   uni_card / uni_card_empty   the turret card (loaded, then empty)
##   uni_wheel              the crop wheel
##   uni_marks              the far wall: marks, vines, poison, thread
##   uni_house / uni_ground / uni_air   the other groups placed and loaded
##   uni_wave_end           after the wave ends: sacks spent, barrels back up
## and logs [uni] lines: shots per turret, and what the bugs carry (slowed,
## poisoned, marked, volatile, stunned, rooted).

var g: Node
var world: Node
var hud: Hud
var player: Player
var cam: Camera3D
var turrets: Array[UniversalTurret] = []


func run(gallery: Node, w: Node, h: Hud, p: Player) -> void:
	g = gallery
	world = w
	hud = h
	player = p
	var cb := world.get("cliffs") as CliffBuilder
	var bm := BuildManager.instance
	var bugs := world.get("bugs") as BugManager
	if cb == null or bm == null or bugs == null:
		return
	var cid := player.cliff_id
	var far := WorldLayout.other_cliff(cid)
	Economy.earn(cid, {&"scrap": 30000, &"chitin": 3000})
	var sacks := {}
	for c: StringName in CropEffects.IDS:
		sacks[CropEffects.sack_of(c)] = 8
	Economy.earn(cid, sacks)
	# Two crewed guns in the crewed spot (the second on the tower over the first),
	# then the ten cliff turrets along the rest of the front row.
	var crew_ids: Array[StringName] = [&"cf_iron_mule", &"cf_crop_howitzer"]
	if GameState.flag_value("--crewids") != "": # another pair: --crewids=cf_sky_hound,cf_thunder_mule
		crew_ids.clear()
		for cid_s: String in GameState.flag_value("--crewids").split(",", false):
			crew_ids.append(StringName(cid_s))
	if g._wants("uni_crewed"):
		var keep_wave := GameState.wave
		GameState.wave = 10 # (crewed guns unlock at wave 5)
		for id: StringName in crew_ids:
			bm._do_build(1, id, cid, Buildable.CREWED_CELL)
			await g._wait(0.3)
		GameState.wave = keep_wave
	var cliff_ids: Array[StringName] = Defs.UNIVERSAL_CLIFF
	var cols: Array[int] = [1, 3, 5, 7, 12, 14, 16, 18, 19, 8]
	for i in cliff_ids.size():
		bm._do_build(1, cliff_ids[i], cid, Vector2i(0, cols[i]))
	await g._wait(1.0)
	turrets.clear()
	for i in cliff_ids.size():
		for t: Turret in bm.turrets_on(cid, Vector2i(0, cols[i])):
			if t is UniversalTurret:
				turrets.append(t)
	var crewed: Array[UniversalCrewedTurret] = []
	for n: Node in world.get_tree().get_nodes_in_group("universal_turrets"):
		if n is UniversalCrewedTurret and (n as Turret).cliff_id == cid:
			crewed.append(n)
			(n as UniversalCrewedTurret)._host_load(1, &"herbs" if crewed.size() == 1 else &"firecracker_chili")
	print("[uni] crewed placed: %s" % str(crewed.map(func(t: UniversalCrewedTurret) -> String: return "%s level %d" % [t.def.id, t.level])))
	print("[uni] placed %d of %d cliff turrets" % [turrets.size(), cliff_ids.size()])
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 600.0
	world.add_child(cam)
	var prev := g.get_viewport().get_camera_3d()
	var lip := Buildable.cell_center(cb, cid, Vector2i(0, 10))
	var inward := WorldLayout.inward(cid)
	var along := inward.cross(Vector3.UP).normalized()
	# Empty: barrels up, grey rings.
	await g._step("uni_lip_empty", func() -> void:
		hud.visible = false
		cam.global_position = lip + inward * 7.0 + Vector3.UP * 3.2 - along * 9.0
		cam.look_at(lip + along * 4.0 + Vector3.UP * 0.6, Vector3.UP)
		cam.make_current(), Callable(), 1.6)
	# Loaded: one crop each, through the host's load (as a player's E / wheel does).
	for i in turrets.size():
		turrets[i]._host_load(1, CropEffects.IDS[i % CropEffects.IDS.size()])
	await g._wait(1.5)
	await g._step("uni_lip_loaded", func() -> void:
		cam.global_position = lip + inward * 7.0 + Vector3.UP * 3.2 - along * 9.0
		cam.look_at(lip + along * 4.0 + Vector3.UP * 0.6, Vector3.UP)
		cam.make_current(), Callable(), 0.8)
	# Bugs up the far wall: packs in every lane, a few heavies.
	var lanes := WorldLayout.LANE_Z.size()
	for k in 2:
		for lane in lanes:
			bugs.spawn_group(&"dust_mite", 5, far, lane, 6.0 + k * 4.0)
			bugs.spawn_group(&"rattler_beetle", 2, far, lane, 5.0 + k * 5.0)
			bugs.spawn_group(&"wolf_spider", 2, far, lane, 7.0 + k * 3.0)
	await g._wait(5.0)
	if g._wants("uni_lip_fire"):
		cam.global_position = lip + inward * 5.0 + Vector3.UP * 2.6 - along * 8.0
		cam.look_at(lip - inward * 30.0 + Vector3.UP * -4.0, Vector3.UP)
		cam.make_current()
		for f in 6:
			await RenderingServer.frame_post_draw
			g.get_viewport().get_texture().get_image().save_png("%s/uni_lip_fire_%02d.png" % [g.get("_dir"), f])
			await g._wait(0.25)
	# Each turret close up while it fires.
	for t: UniversalTurret in turrets:
		var tt := t
		await g._step("uni_close_" + String(t.def.id), func() -> void:
			if not is_instance_valid(tt):
				return
			# From out over the canyon, looking back at it (the scaffold's open front).
			var face := -tt.global_basis.z
			var side := face.cross(Vector3.UP).normalized()
			cam.fov = 45.0
			cam.global_position = tt.global_position + face * 3.2 + side * 1.6 + Vector3.UP * 1.3
			cam.look_at(tt.global_position + Vector3.UP * 0.55, Vector3.UP)
			cam.make_current(), Callable(), 0.5)
	_tally("cliff fire")
	for t: UniversalCrewedTurret in crewed:
		if is_instance_valid(t):
			print("[uni]   crewed %s (%s): shots %d, heat %.2f" % [t.def.id, t.crop, t.shots, t.heat])
	if not crewed.is_empty():
		var ct := crewed[0]
		await g._step("uni_crewed", func() -> void:
			hud.visible = false
			var face := -ct.global_basis.z
			var side := face.cross(Vector3.UP).normalized()
			cam.fov = 55.0
			cam.global_position = ct.global_position + face * 6.0 + side * 3.0 + Vector3.UP * 4.5
			cam.look_at(ct.global_position + Vector3.UP * 2.0, Vector3.UP)
			cam.make_current(), func() -> void: cam.fov = 60.0, 0.5)
		# Seated in each: the gunner's own view, then from the side (is the seat
		# where the model's seat is?).
		for c: UniversalCrewedTurret in crewed:
			if not is_instance_valid(c):
				continue
			await g._step("uni_seat_%s" % c.def.id, func() -> void:
				hud.visible = true
				if prev != null:
					prev.make_current()
				player.global_position = c.global_position + c.global_basis.z * 2.5
				c._take_seat(), Callable(), 1.6)
			await g._step("uni_seat_%s_side" % c.def.id, func() -> void:
				hud.visible = false
				var f2 := -c.global_basis.z
				var s2 := f2.cross(Vector3.UP).normalized()
				cam.global_position = c.global_position + s2 * 5.0 + Vector3.UP * 2.2 - f2 * 1.0
				cam.look_at(c.global_position + Vector3.UP * 1.3, Vector3.UP)
				cam.make_current(), func() -> void:
					c._leave_seat()
					hud.visible = true, 0.5)
	# The far wall: what the crops did (from over the canyon, near the wall).
	await g._step("uni_marks", func() -> void:
		var wall := cb.face_point(far, WorldLayout.CLIFF_HEIGHT - 10.0, lip.z)
		cam.fov = 55.0
		cam.global_position = wall + (lip - wall).normalized() * 14.0 + Vector3.UP * 2.0
		cam.look_at(wall, Vector3.UP)
		cam.make_current(), func() -> void: cam.fov = 60.0, 0.4)
	# The card and the wheel, from the player's own eyes.
	if not turrets.is_empty():
		var t0 := turrets[0]
		# A kill tally on it, by crop (the card shows each beside the name).
		TurretTallies.counts[String(t0.name)] = 52
		TurretTallies.crop_counts[String(t0.name)] = {&"corn": 40, &"cotton": 12}
		await g._step("uni_card", func() -> void:
			hud.visible = true
			if prev != null:
				prev.make_current()
			_look_at_turret(t0), Callable(), 1.2)
		# More than three crops: the tally gets its own row.
		await g._step("uni_card_many", func() -> void:
			TurretTallies.counts[String(t0.name)] = 131
			TurretTallies.crop_counts[String(t0.name)] = {&"corn": 40, &"cotton": 32, &"barrel_cactus": 21, &"tumbleweed_vine": 18,
				&"sarsaparilla": 11, &"firecracker_chili": 9}
			_look_at_turret(t0), Callable(), 1.0)
		await g._step("uni_wheel", func() -> void:
			_look_at_turret(t0)
			CropWheel.open_for(t0)
			if CropWheel.instance != null:
				CropWheel.instance.set("_aim", Vector2(120, -60))
				CropWheel.instance.set("_choice", CropWheel._sector(Vector2(120, -60))), func() -> void:
			if CropWheel.instance != null:
				CropWheel.instance.close(), 0.6)
	# The wave ends: every sack is spent, the barrels go back up.
	for t: UniversalTurret in turrets:
		if is_instance_valid(t):
			t._on_phase_changed(GameState.Phase.WAVE)
			t._on_phase_changed(GameState.Phase.BUILD)
	await g._wait(1.6)
	var still := 0
	for t: UniversalTurret in turrets:
		if is_instance_valid(t) and t.crop != &"":
			still += 1
	print("[uni] wave end: %d still loaded (want 0), last crops kept: %s" % [still, str(turrets.map(func(t: UniversalTurret) -> String: return String(t.last_crop) if is_instance_valid(t) else "-"))])
	await g._step("uni_wave_end", func() -> void:
		hud.visible = false
		cam.global_position = lip + inward * 7.0 + Vector3.UP * 3.2 - along * 9.0
		cam.look_at(lip + along * 4.0 + Vector3.UP * 0.6, Vector3.UP)
		cam.make_current(), Callable(), 0.4)
	if not turrets.is_empty():
		await g._step("uni_card_empty", func() -> void:
			hud.visible = true
			if prev != null:
				prev.make_current()
			_look_at_turret(turrets[0]), Callable(), 1.0)
	# The other groups: house guns on the house mounts, air guns and obstructions on the ground.
	await _others(cb, bm, bugs, cid)
	hud.visible = true
	if prev != null:
		prev.make_current()
	cam.queue_free()


## Stands the player 2.5 m in front of `t`, looking at its body.
func _look_at_turret(t: UniversalTurret) -> void:
	if not is_instance_valid(t):
		return
	var back := t.global_basis.z
	player.global_position = t.global_position + back * 2.4 + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	var eye := player.global_position + Vector3.UP * 1.6
	var to := t.global_position + Vector3.UP * 0.6 - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Prints what the bugs carry from the crops, and each turret's shots.
func _tally(label: String) -> void:
	var tally := {"slowed": 0, "poisoned": 0, "marked": 0, "volatile": 0, "stunned": 0, "rooted": 0, "alive": 0}
	for n: Node in world.get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive():
			continue
		tally["alive"] += 1
		var st := b.status
		tally["slowed"] += int(st.crop_slowed() > 0.0)
		tally["poisoned"] += int(st.poison_stacks() > 0)
		tally["marked"] += int(st.is_crop_marked())
		tally["volatile"] += int(st.is_volatile())
		tally["stunned"] += int(st.is_stunned())
		tally["rooted"] += int(st.is_rooted())
	print("[uni] %s: bugs %s" % [label, str(tally)])
	for t: UniversalTurret in turrets:
		if is_instance_valid(t):
			print("[uni]   %s (%s, tier %d): shots %d, hp %d" % [t.def.id, t.crop, t.tier + 1, t.shots, int(t.health.hp)])


func _others(cb: CliffBuilder, bm: BuildManager, bugs: BugManager, cid: int) -> void:
	if not (g._wants("uni_house") or g._wants("uni_ground") or g._wants("uni_air")):
		return
	var home := Homestead.of(cid)
	if home != null:
		home._set_state.rpc(3, true, true)
		await g._wait(0.5)
	var placed: Array[UniversalTurret] = []
	var mounts := home.mount_count() if home != null else 0
	for i in mini(Defs.UNIVERSAL_LAST.size(), mounts):
		bm._do_build(1, Defs.UNIVERSAL_LAST[i], cid, Vector2i(-1, i))
	for i in Defs.UNIVERSAL_AA.size():
		bm._do_build(1, Defs.UNIVERSAL_AA[i], cid, Vector2i(2, 2 + i * 3))
	for i in Defs.UNIVERSAL_OBSTRUCTIONS.size():
		bm._do_build(1, Defs.UNIVERSAL_OBSTRUCTIONS[i], cid, Vector2i(4, 3 + i * 3))
	await g._wait(1.0)
	for n: Node in world.get_tree().get_nodes_in_group("universal_turrets"):
		var t := n as UniversalTurret
		if t != null and not turrets.has(t) and t.cliff_id == cid:
			placed.append(t)
	print("[uni] placed %d others" % placed.size())
	var i := 0
	for t: UniversalTurret in placed:
		t._host_load(1, CropEffects.IDS[(i * 4 + 1) % CropEffects.IDS.size()])
		i += 1
	await g._wait(1.2)
	var lip := Buildable.cell_center(cb, cid, Vector2i(2, 8))
	var inward := WorldLayout.inward(cid)
	var along := inward.cross(Vector3.UP).normalized()
	await g._step("uni_air", func() -> void:
		hud.visible = false
		cam.global_position = lip + inward * 6.0 + Vector3.UP * 3.0 - along * 7.0
		cam.look_at(lip + along * 2.0 + Vector3.UP * 0.8, Vector3.UP)
		cam.make_current(), Callable(), 0.6)
	if home != null:
		await g._step("uni_house", func() -> void:
			var hp := home.global_position
			cam.global_position = hp - inward * 9.0 + Vector3.UP * 5.0 + along * 4.0
			cam.look_at(hp + Vector3.UP * 2.5, Vector3.UP)
			cam.make_current(), Callable(), 0.6)
	var gp := Buildable.cell_center(cb, cid, Vector2i(4, 9))
	await g._step("uni_ground", func() -> void:
		cam.global_position = gp + inward * 5.0 + Vector3.UP * 3.5 - along * 6.0
		cam.look_at(gp + along * 2.0, Vector3.UP)
		cam.make_current(), Callable(), 0.6)
	# Breachers on the plateau right at each obstruction, and near the house.
	for t: UniversalTurret in placed:
		if t.def.obstruction:
			var p := t.global_position + Vector3(0.0, 0.0, 1.4)
			bugs.spawn_at(&"wolf_spider", cid, 0, p.z, 0.0, Bug.State.BREACHING, p)
	if home != null:
		for k in 3:
			var p := home.global_position + WorldLayout.inward(cid) * -6.0 + Vector3(0, 0, (k - 1) * 3.0)
			p.y = cb.ground_height_at(cid, p)
			bugs.spawn_at(&"rattler_beetle", cid, 0, p.z, 0.0, Bug.State.BREACHING, p)
	await g._wait(3.0)
	await g._step("uni_ground_mid", func() -> void:
		cam.global_position = gp + inward * 5.0 + Vector3.UP * 3.5 - along * 6.0
		cam.look_at(gp + along * 2.0, Vector3.UP)
		cam.make_current(), Callable(), 0.1)
	await g._wait(5.0)
	var gone := 0
	for t: UniversalTurret in placed:
		if not is_instance_valid(t) or (t is UniversalObstruction and (t as UniversalObstruction).gone_off):
			gone += 1
	print("[uni] obstructions/house: %d gone off or removed" % gone)
	for t: UniversalTurret in placed:
		if is_instance_valid(t):
			print("[uni]   %s (%s): shots %d, hp %d" % [t.def.id, t.crop, t.shots, int(t.health.hp)])
	await g._step("uni_ground_after", func() -> void:
		cam.global_position = gp + inward * 5.0 + Vector3.UP * 3.5 - along * 6.0
		cam.look_at(gp + along * 2.0, Vector3.UP)
		cam.make_current(), Callable(), 0.3)
