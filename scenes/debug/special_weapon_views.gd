extends Node
## Debug: the special weapons (slot 2) seen and tested live. Flags (after --):
##   --weaponview=<id>|all   fire each at bugs climbing your own cliff and on the
##                            plateau, save frames (sp_<id>_NN.png) and log what
##                            each bug got ([special] lines)
##   --weaponview=fp         first-person look at each gun in hand with the HUD
##                            badge (sp_fp_<id>.png)
##   --weaponview=bench      the workbench behind the house, and its menu open
##   --weaponcrop=<crop>     fit this crop first (default: none)
##   --weapondir=<folder>    where to save (default user://special_views)
## Run windowed: godot --path . res://scenes/world.tscn -- --solo --weaponview=all

var world: Node3D
var _dir := "user://special_views"
var _crop: StringName = &""


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	if GameState.flag_value("--weapondir") != "":
		_dir = GameState.flag_value("--weapondir")
	DirAccess.make_dir_recursive_absolute(_dir)
	_crop = StringName(GameState.flag_value("--weaponcrop"))
	for i in 40:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	if player == null:
		push_error("special_views: no local player")
		return
	var what := GameState.flag_value("--weaponview")
	match what:
		"bench":
			await _bench(player)
		"fp":
			await _first_person(player)
		_:
			for id: StringName in SpecialRules.IDS:
				if what == "all" or what == String(id):
					await _fire_at_bugs(player, id)
	print("[special] done")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])


func _give(player: Player, id: StringName) -> void:
	var code := SpecialCrop.with_crop(0, _crop) if CropEffects.is_crop(_crop) else 0
	var pid := multiplayer.get_unique_id()
	if not GunShop.loadouts.has(pid):
		GunShop.loadouts[pid] = {&"revolver": 0}
	var owned: Dictionary = GunShop.loadouts[pid]
	var holder := Gun.slot_holder(owned, id)
	if holder != &"":
		owned.erase(holder)
	owned[id] = code
	player.gun.grant(id, code)
	player.gun.equip(id)
	player.gun.ammo = player.gun.mag_size()


func _aim(player: Player, target: Vector3) -> void:
	var to := target - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Fire from the eye at `at` (or along the view when it's INF): aimed at where a
## bug is now, not where it was when the camera turned.
func _fire(player: Player, at: Vector3 = Vector3.INF) -> void:
	player.gun.set("_cooldown", 0.0)
	if player.gun.ammo <= 0:
		player.gun.ammo = player.gun.mag_size()
	var eye := player.camera.global_position
	var dir := (at - eye).normalized() if at != Vector3.INF else -player.camera.global_basis.z
	player.net.fire(eye, dir)


## The climber nearest the middle of the bunch, right now (its body, not its feet).
func _mid_climber() -> Vector3:
	var all: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive():
			all.append(b)
	if all.is_empty():
		return Vector3.INF
	all.sort_custom(func(a: Bug, b: Bug) -> bool: return a.global_position.z < b.global_position.z)
	return all[all.size() / 2].global_position + Vector3.UP * 0.4


func _fire_at_bugs(player: Player, id: StringName) -> void:
	var cb := world.get("cliffs") as CliffBuilder
	var bm := BugManager.instance
	if cb == null or bm == null:
		return
	var cid := player.cliff_id
	# The bugs climb the partner's cliff, across the canyon: the rider's own side
	# is the partner's job (the cross-canyon rule), and shots down your own face
	# only hit your own lip.
	var oc := WorldLayout.other_cliff(cid)
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var old := n as Bug
		if old != null and old.is_alive():
			old.escaped()
	await _wait(0.5)
	var z0 := player.global_position.z
	var rim := cb.plateau_point(cid, 1.5, z0)
	var inward := cb.plateau_point(cid, 12.0, z0) - rim
	inward.y = 0.0
	inward = inward.normalized()
	# The short-range ones (they can't reach across the canyon): bugs that got up
	# onto your own plateau, a few metres in front of you.
	var near := Gun.range_for(id, 0) < WorldLayout.GAP + 6.0
	if id == &"trip_wire_gun":
		await _wire_test(player, cb, bm, cid, rim, inward, z0)
		return
	for i in 7:
		if near:
			var p := rim + inward * ((11.0 if id == &"trip_wire_gun" else 6.5) + (i % 2) * 1.5) + Vector3(0, 0, (i - 3) * 1.3)
			p.y = cb.ground_height_at(cid, p)
			bm.spawn_at(&"rattler_beetle" if i % 3 == 0 else &"wolf_spider", cid, 0, p.z, 0.0, Bug.State.BREACHING, p)
		else:
			bm.spawn_at(&"rattler_beetle" if i % 3 == 0 else &"wolf_spider", oc, 0, z0 + (i - 3) * 1.4,
					WorldLayout.CLIFF_HEIGHT - 7.0 - (i % 2) * 1.5, Bug.State.CLIMBING, Vector3.ZERO)
	await _wait(0.6)
	GameState.god_mode = true
	player.global_position = rim + inward * 0.6 + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	_give(player, id)
	var climbers: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and (b.is_climbing() or near):
			climbers.append(b)
	var target := cb.face_point(oc, WorldLayout.CLIFF_HEIGHT - 8.0, z0)
	if not climbers.is_empty():
		target = climbers[mini(3, climbers.size() - 1)].global_position
	if id == &"spore_launcher" or id == &"trip_wire_gun" or id == &"bramble_pistol":
		target = cb.face_point(oc, WorldLayout.CLIFF_HEIGHT - 5.5, z0) # on the wall in their path
		if near:
			target = rim + inward * 4.5
			target.y = cb.ground_height_at(cid, target) + 0.05 # on the ground in their path
	_aim(player, target)
	await _wait(0.3)
	var hp: Dictionary = {}
	for b in climbers:
		hp[b] = b.health.hp
	var w := Gun.weapon(id)
	if id == &"trip_wire_gun":
		var a1 := cb.face_point(oc, WorldLayout.CLIFF_HEIGHT - 5.5, z0 - 5.0)
		if near:
			a1 = rim + inward * 6.0 + Vector3(0, 0, 0.4)
			a1.y = cb.ground_height_at(cid, a1) + 0.3
		_aim(player, a1)
		_fire(player, a1)
		await _wait(0.45)
		var a2 := cb.face_point(oc, WorldLayout.CLIFF_HEIGHT - 5.5, z0 + 5.0)
		if near:
			a2 = rim + inward * 15.0 + Vector3(0, 0, -0.4)
			a2.y = cb.ground_height_at(cid, a2) + 0.3
		_aim(player, a2)
		_fire(player, a2)
	else:
		var wall := id == &"spore_launcher" or id == &"bramble_pistol"
		for s in ((16 if w.fire_interval < 0.2 else 6) if w.automatic else (3 if w.mag_size >= 3 else 1)):
			var at := target if wall else _mid_climber()
			if at != Vector3.INF:
				_aim(player, at)
			_fire(player, at)
			await _wait(maxf(w.fire_interval, 0.1))
	await _wait(0.35)
	_tally(id, hp, "right after")
	var spec := Camera3D.new()
	spec.fov = 60.0
	world.add_child(spec)
	var back := player.global_position - target
	back.y = 0.0
	spec.global_position = target + back.normalized() * 14.0 + Vector3.UP * 3.0 + Vector3(0, 0, 5.0)
	spec.look_at(target, Vector3.UP)
	spec.make_current()
	for f in 8:
		await _snap("sp_%s%s_%02d" % [id, ("_" + String(_crop)) if _crop != &"" else "", f])
		await _wait(0.25)
	if id == &"spore_launcher" or id == &"trip_wire_gun":
		await _wait(3.0) # the climbers have to reach the pods, the wire
		await _snap("sp_%s_late" % id)
	player.camera.make_current()
	spec.queue_free()
	_tally(id, hp, "later")


func _tally(id: StringName, hp: Dictionary, when: String) -> void:
	var t := {"hurt": 0, "dead": 0, "weak": 0, "marked": 0, "drowsy": 0, "rooted": 0, "poison": 0, "cslow": 0, "cmark": 0, "volatile": 0}
	for k: Variant in hp:
		if not is_instance_valid(k) or not (k as Bug).is_alive():
			t["dead"] += 1
			continue
		var b := k as Bug
		if b.health.hp < float(hp[b]) - 0.5:
			t["hurt"] += 1
		var st := b.status
		t["weak"] += int(st.is_weakened())
		t["marked"] += int(st.is_marked())
		t["drowsy"] += int(st.is_drowsy())
		t["rooted"] += int(st.is_rooted())
		t["poison"] += int(st.poison_stacks() > 0)
		t["cslow"] += int(st.crop_slowed() > 0.0)
		t["cmark"] += int(st.is_crop_marked())
		t["volatile"] += int(st.is_volatile())
	print("[special] %s crop=%s (%s) of %d climbers: %s" % [id, _crop if _crop != &"" else "none", when, hp.size(), str(t)])


func _first_person(player: Player) -> void:
	for id: StringName in SpecialRules.IDS:
		_give(player, id)
		await _wait(0.9)
		await _snap("sp_fp_%s%s" % [id, ("_" + String(_crop)) if _crop != &"" else ""])


func _bench(player: Player) -> void:
	var home := Homestead.of(player.cliff_id)
	if home == null:
		return
	home.set("workshop", true) # (the Workshop's a house upgrade: built for the shot)
	home.call("_build_workshop")
	await _wait(0.2)
	var shop := home.get_node_or_null("Workshop") as Workshop
	var bench := shop.get_node_or_null("CropBench") as CropBench if shop != null else null
	if bench == null:
		push_error("special_views: no workshop")
		return
	_give(player, &"crop_duster")
	Economy.earn(player.cliff_id, {&"corn_load": 3, &"cotton_load": 2, &"herb_load": 1})
	var cam := Camera3D.new()
	cam.fov = 55.0
	world.add_child(cam)
	var front := -shop.global_basis.z # (the shed's open front)
	cam.global_position = bench.global_position + front * 2.6 + Vector3.UP * 0.9 + shop.global_basis.x * 0.8
	cam.look_at(bench.global_position, Vector3.UP)
	cam.make_current()
	await _wait(0.6)
	await _snap("sp_bench")
	bench._fit(multiplayer.get_unique_id(), &"corn")
	await _wait(0.8)
	await _snap("sp_bench_glow")
	print("[special] bench: duster code %d crop %s" % [player.gun.code_of(&"crop_duster"), SpecialCrop.crop_of(player.gun.code_of(&"crop_duster"))])
	player.camera.make_current()
	cam.queue_free()
	if MenuScreen.instance != null:
		MenuScreen.instance.open(shop)
		await _wait(0.4)
		MenuScreen.instance.tab = 4 # the Special Weapon tab
		MenuScreen.instance.refresh()
		await _wait(0.8)
		await _snap("sp_bench_menu")


## Trip Wire Gun on the plateau: string a wire first, then let bugs walk into it.
func _wire_test(player: Player, cb: CliffBuilder, bm: BugManager, cid: int, rim: Vector3, inward: Vector3, z0: float) -> void:
	GameState.god_mode = true
	player.global_position = rim + inward * 0.6 + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	_give(player, &"trip_wire_gun")
	for z: float in [-6.0, 6.0]:
		var a := rim + inward * 3.0 + Vector3(0, 0, z)
		a.y = cb.ground_height_at(cid, a) + 0.3
		_aim(player, a)
		_fire(player, a)
		await _wait(0.45)
	var hp: Dictionary = {}
	for i in 7:
		var p := rim + inward * (7.0 + (i % 2) * 1.5) + Vector3(0, 0, (i - 3) * 1.3)
		p.y = cb.ground_height_at(cid, p)
		bm.spawn_at(&"rattler_beetle" if i % 3 == 0 else &"wolf_spider", cid, 0, p.z, 0.0, Bug.State.BREACHING, p)
	await _wait(0.2)
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive():
			hp[b] = b.health.hp
	await _wait(2.5)
	await _snap("sp_trip_wire_gun%s_plateau" % (("_" + String(_crop)) if _crop != &"" else ""))
	_tally(&"trip_wire_gun", hp, "bugs walked into it")
