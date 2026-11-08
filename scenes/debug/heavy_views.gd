extends Node
## Debug: the universal crop-loaded heavies (HeavyRules) seen and tested live.
## Flags (after --):
##   --heavyview=fp          each heavy in first person: empty (barrel up), the sack
##                           going in, loaded with the HUD panel, just fired
##                           (hv_fp_<id>_<pose>.png)
##   --heavyview=<id>[,<id>]|all  load it and fire at bugs climbing your cliff and on the
##                           plateau, save frames (hv_<id>_NN.png), log what each bug
##                           got and the host's shot count ([heavy] lines)
##   --heavycrop=<crop>      the crop to load (default: a different one per gun)
##   --heavydir=<folder>     where to save (default user://heavy_views)
## Run windowed: godot --path . res://scenes/world.tscn -- --solo --debug --heavyview=all

const DEFAULT_CROP: Dictionary = {&"crop_mortar": &"firecracker_chili", &"hand_cannon": &"prickly_pear",
	&"crop_sprayer": &"cotton", &"spike_driver": &"sarsaparilla", &"drum_launcher": &"herbs",
	&"harvest_gatling": &"tumbleweed_vine", &"crop_crossbow": &"corn", &"bola_launcher": &"barrel_cactus",
	&"powder_keg_launcher": &"sulfur_root", &"crop_blunderbuss": &"firecracker_chili"}

var world: Node3D
var _dir := "user://heavy_views"
var _crop: StringName = &""


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	if GameState.flag_value("--heavydir") != "":
		_dir = GameState.flag_value("--heavydir")
	DirAccess.make_dir_recursive_absolute(_dir)
	_crop = StringName(GameState.flag_value("--heavycrop"))
	for i in 40:
		await get_tree().physics_frame
	var player := world.call("local_player") as Player
	if player == null:
		push_error("heavy_views: no local player")
		return
	# Plenty of every sack.
	var stock := {}
	for c: StringName in CropEffects.IDS:
		stock[CropEffects.sack_of(c)] = 20
	Economy.earn(player.cliff_id, stock)
	var what := GameState.flag_value("--heavyview")
	if what == "fp":
		await _first_person(player)
	else:
		for id: StringName in HeavyRules.IDS:
			if what == "all" or String(id) in what.split(","):
				await _fire_at_bugs(player, id)
	print("[heavy] done")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])


func _crop_for(id: StringName) -> StringName:
	return _crop if CropEffects.is_crop(_crop) else DEFAULT_CROP[id]


## Hands the local rider `id`, empty (the shop's way: the host records it, then the gun).
func _give(player: Player, id: StringName) -> void:
	var pid := multiplayer.get_unique_id()
	if not GunShop.loadouts.has(pid):
		GunShop.loadouts[pid] = {&"revolver": 0}
	var owned: Dictionary = GunShop.loadouts[pid]
	var holder := Gun.slot_holder(owned, id)
	if holder != &"":
		owned.erase(holder)
	HeavyAmmo.forget(pid, id)
	owned[id] = 0
	player.gun.grant(id, 0)
	player.gun.equip(id)


## Loads a sack and waits out the load.
func _load(player: Player, id: StringName) -> void:
	player.gun.request_load(_crop_for(id))
	await _wait(Gun.weapon(id).reload_time + 0.6)


func _aim(player: Player, target: Vector3) -> void:
	var to := target - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _fire(player: Player) -> bool:
	var gun := player.gun
	gun.set("_cooldown", 0.0)
	gun.set("spin", 1.0)
	if gun.trigger(player.camera):
		player.net.fire(player.camera.global_position, -player.camera.global_basis.z)
		return true
	return false


func _first_person(player: Player) -> void:
	for id: StringName in HeavyRules.IDS:
		_give(player, id)
		await _wait(1.6)
		await _snap("hv_fp_%s_empty" % id)
		player.gun.request_load(_crop_for(id))
		await _wait(Gun.weapon(id).reload_time * 0.5)
		await _snap("hv_fp_%s_loading" % id)
		await _wait(Gun.weapon(id).reload_time * 0.5 + 0.5)
		await _snap("hv_fp_%s_loaded" % id)
		_fire(player)
		await _wait(0.08)
		await _snap("hv_fp_%s_fire" % id)
		await _wait(0.6)


func _fire_at_bugs(player: Player, id: StringName) -> void:
	var cb := world.get("cliffs") as CliffBuilder
	var bm := BugManager.instance
	if cb == null or bm == null:
		return
	var cid := player.cliff_id
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var old := n as Bug
		if old != null and old.is_alive():
			old.escaped()
	_give(player, id)
	await _load(player, id) # (loaded first, so the climbers haven't gone over the top by the time it fires)
	var z0 := player.global_position.z
	for i in 8:
		bm.spawn_at(&"rattler_beetle" if i % 3 == 0 else &"wolf_spider", cid, 0, z0 + (i - 4) * 1.3,
				WorldLayout.CLIFF_HEIGHT - 8.0 - (i % 2) * 1.5, Bug.State.CLIMBING, Vector3.ZERO)
	await _wait(0.6)
	GameState.god_mode = true
	var rim := cb.plateau_point(cid, 1.5, z0)
	var inward := cb.plateau_point(cid, 12.0, z0) - rim
	inward.y = 0.0
	inward = inward.normalized()
	# The sprayer and blunderbuss need to be close: lean over the rim; the rest step back.
	# Right at the rim, so the edge doesn't hide the climbers below.
	player.global_position = rim + inward * 0.6 + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	var climbers: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and b.is_climbing():
			climbers.append(b)
	var target := cb.face_point(cid, WorldLayout.CLIFF_HEIGHT - 8.5, z0)
	if not climbers.is_empty() and id != &"spike_driver" and id != &"powder_keg_launcher":
		target = climbers[mini(3, climbers.size() - 1)].global_position
	_aim(player, target)
	await _wait(0.3)
	var hp: Dictionary = {}
	for b in climbers:
		hp[b] = b.health.hp
	var w := Gun.weapon(id)
	var shots := 0
	var tries := 30 if w.automatic else 3
	for s in tries:
		if _fire(player):
			shots += 1
		await _wait(maxf(w.fire_interval, 0.12) if not w.automatic else 0.12)
	await _wait(0.9 if w.special in [&"uh_mortar", &"uh_drum", &"uh_keg", &"uh_crossbow", &"uh_bola", &"uh_spike"] else 0.15)
	var t := _tally(hp)
	var spec := Camera3D.new()
	spec.fov = 60.0
	world.add_child(spec)
	spec.global_position = target - inward * 16.0 + Vector3.UP * 3.0 + Vector3(0, 0, 6.0)
	spec.look_at(target, Vector3.UP)
	spec.make_current()
	for f in 8:
		await _snap("hv_%s_%s_%02d" % [id, _crop_for(id), f])
		await _wait(0.3 if id != &"powder_keg_launcher" else 0.6)
	player.camera.make_current()
	spec.queue_free()
	var left := HeavyAmmo.of(multiplayer.get_unique_id(), id)
	print("[heavy] %s crop=%s fired %d, gun %d/%d, host %s %d; of %d climbers: %s" % [id, _crop_for(id), shots,
			player.gun.ammo, player.gun.mag_size(), left[0], int(left[1]), hp.size(), str(t)])


func _tally(hp: Dictionary) -> Dictionary:
	var t := {"hurt": 0, "dead": 0, "rooted": 0, "stunned": 0, "poison": 0, "cslow": 0, "cmark": 0, "volatile": 0, "fell": 0}
	for k: Variant in hp:
		if not is_instance_valid(k) or not (k as Bug).is_alive():
			t["dead"] += 1
			continue
		var b := k as Bug
		if b.health.hp < float(hp[b]) - 0.5:
			t["hurt"] += 1
		var st := b.status
		t["rooted"] += int(st.is_rooted())
		t["stunned"] += int(st.is_stunned())
		t["poison"] += int(st.poison_stacks() > 0)
		t["cslow"] += int(st.crop_slowed() > 0.0)
		t["cmark"] += int(st.is_crop_marked())
		t["volatile"] += int(st.is_volatile())
		t["fell"] += int(b.is_climbing() and b.climb_y < 1.0)
	return t
