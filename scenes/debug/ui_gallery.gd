extends Node
## UI gallery (debug only): opens every screen in turn, photographs each one and
## quits. The Brand autoload adds it when --uigallery is given.
##   --uigallery=<dir>    folder for the PNGs (<set>_<step>.png)
##   --uisets=base,irons  UI sets to shoot (default: base)
##   --uionly=a,b         only the steps whose names start with one of these
## Which tour runs depends on where the game lands:
##   --debug --menu --uigallery=<dir>             the title screens
##   --debug --uigallery=<dir>                    the in-game HUD and menus
##   --debug --story=1 --uigallery=<dir>          plus the story overlays
##   --debug --tutorialstep=N --uigallery=<dir>   the tutorial card at step N

const SETTLE := 1.4 # seconds a screen gets to open and fade in before its photo

var _dir := ""
var _sets: PackedStringArray = ["base"]
var _only: PackedStringArray = []
var _count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dir = GameState.flag_value("--uigallery").replace("\\", "/")
	if GameState.flag_value("--uisets") != "":
		_sets = GameState.flag_value("--uisets").split(",", false)
	if GameState.flag_value("--uionly") != "":
		_only = GameState.flag_value("--uionly").split(",", false)
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _run() -> void:
	if GameState.has_flag("--loadfilm"):
		_load_film() # (not awaited: films the launch and the first load as they happen)
	# Wait for the scene to settle: the menu, or (with --debug) the auto-hosted world.
	var until := Time.get_ticks_msec() + 90000
	var world: Node = null
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs != null and cs.get_node_or_null("Hud") != null and cs.has_method("local_player") and cs.call("local_player") != null:
			world = cs
			break
		if cs != null and GameState.has_flag("--menu") and cs.get("_pages") != null:
			break
	await _wait(3.0 if world != null else 9.0) # (the title film takes a while to roll in)
	var fade_until := Time.get_ticks_msec() + 30000
	while SceneFade.busy() and Time.get_ticks_msec() < fade_until: # (the load cover lifts first)
		await get_tree().process_frame
	await _wait(1.0)
	await _loading_shots()
	if world != null:
		if GameState.tutorial:
			await _tutorial_tour()
		else:
			await _world_tour(world)
	else:
		await _menu_tour(get_tree().current_scene)
	print("[uigallery] %d shots in %s" % [_count, _dir])
	get_tree().quit()
	await _wait(4.0) # (a hosted lobby can hold the quit up: leave anyway)
	OS.kill(OS.get_process_id())


## --loadfilm: a frame every fifth of a second for the first half minute
## (load_film_NNN), to see the real loading screens over the real loads.
func _load_film() -> void:
	var t0 := Time.get_ticks_msec()
	var n := 0
	while Time.get_ticks_msec() - t0 < 30000:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/load_film_%03d.png" % [_dir, n])
		n += 1
		await get_tree().create_timer(0.2, true, false, true).timeout


## The loading screens (LoadingScreen), each style dressed for a few loads,
## with its spinner part-way: load_<style>_<case>. --loadanim adds frames of
## each style's spinner moving (load_anim_<style>_NN) for a GIF.
func _loading_shots() -> void:
	if not (_only.is_empty() or Array(_only).any(func(o: String) -> bool: return o.begins_with("load_") or "load_".begins_with(o))):
		return
	var cases: Array = [
		["load_wanted_endless", &"wanted", {"to": "world", "map": "Canyon", "endless": true}, 0.35],
		["load_wanted_story", &"wanted", {"to": "world", "map": "Three-Cliff Mesa", "chapter": 1, "chapter_title": "Holding the Line"}, 0.7],
		["load_vista_story", &"vista", {"to": "world", "map": "Canyon", "chapter": 2, "chapter_title": "Dust and Dynamite"}, 0.3],
		["load_vista_first", &"vista", {"to": "first"}, 0.55],
		["load_vista_storm", &"vista", {"to": "world", "map": "Pinwheel Buttes", "chapter": 4, "chapter_title": "Red Sky"}, 0.8],
		["load_vista_menu", &"vista", {"to": "menu"}, 0.5],
		["load_guide_beetle", &"field_guide", {"to": "world", "map": "Canyon", "bug": "rattler_beetle"}, 0.4],
		["load_guide_spider", &"field_guide", {"to": "world", "map": "Canyon", "bug": "wolf_spider"}, 0.4],
		["load_guide_boss", &"field_guide", {"to": "world", "map": "Canyon", "bug": "queen_spider"}, 0.6],
		["load_guide_scorpion", &"field_guide", {"to": "world", "map": "Three-Cliff Mesa", "bug": "spitter_scorpion"}, 0.6],
		["load_guide_flier", &"field_guide", {"to": "world", "map": "Pinwheel Buttes", "bug": "dragonfly_bandit"}, 0.6],
		["load_brand_base", &"brand", {"to": "world", "map": "Canyon", "brand": &"none", "set": &"base"}, 0.5],
		["load_brand_irons", &"brand", {"to": "world", "map": "Canyon", "brand": &"irons", "set": &"irons"}, 0.34],
		["load_brand_sheaf", &"brand", {"to": "world", "map": "Canyon", "brand": &"sheaf", "set": &"sheaf"}, 0.67],
		["load_brand_snake", &"brand", {"to": "world", "map": "Canyon", "brand": &"snake", "set": &"snake"}, 0.84],
		["load_brand_mandibles", &"brand", {"to": "world", "map": "Canyon", "brand": &"mandibles", "set": &"mandibles"}, 1.0],
		["load_gazette_menu", &"gazette", {"to": "menu", "map": "Canyon"}, 0.5],
		["load_gazette_story", &"gazette", {"to": "world", "map": "Canyon", "chapter": 1, "chapter_title": "Holding the Line"}, 0.5],
	]
	var holder: Array = [null]
	for c: Array in cases:
		var keep := _only
		if not _wants(str(c[0])):
			continue
		_only = []
		await _step(str(c[0]), func() -> void:
			var ctx: Dictionary = c[2]
			if ctx.has("set"):
				UiStyle.apply(ctx["set"])
			var layer := CanvasLayer.new()
			layer.layer = 120
			var card := LoadingScreen.make(c[1], ctx)
			card.progress = float(c[3])
			card.shown = float(c[3])
			layer.add_child(card)
			add_child(layer)
			holder[0] = layer,
			func() -> void: (holder[0] as Node).queue_free(), 1.6)
		_only = keep
	if GameState.has_flag("--loadanim"):
		for style: StringName in LoadingScreen.STYLES:
			var layer := CanvasLayer.new()
			layer.layer = 120
			var card := LoadingScreen.make(style, {"to": "world", "map": "Canyon", "endless": true, "bug": "rattler_beetle"})
			layer.add_child(card)
			add_child(layer)
			for f in 40:
				card.progress = f / 39.0
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/load_anim_%s_%02d.png" % [_dir, style, f])
				await _wait(0.05)
			layer.queue_free()
			await _wait(0.3)


## The Weapon Slots specials, live (armfx_<id>): bugs climbing your own cliff
## just under the rim and a few on the plateau, the gun fired at them from the
## rim, frames as it lands (armfx_<id>_NN) and a log line of what each bug got
## ([armfx] lines: hurt, rooted, stunned, tarred, stripped, frenzied, slowed).
func _armory_fx_shots(world: Node, hud: Hud, player: Player) -> void:
	var cb := world.get("cliffs") as CliffBuilder
	var bm := BugManager.instance
	if cb == null or bm == null:
		return
	var cid := player.cliff_id
	Economy.earn(cid, {&"chili_load": 4, &"sarsaparilla_load": 4, &"corn_load": 4, &"tumbleweed_load": 4, &"herb_load": 4,
		&"cactus_load": 4, &"sulfur_load": 4, &"cotton_load": 4})
	var ids: Array[StringName] = []
	for id: StringName in Gun.ORDER:
		var w := Gun.weapon(id)
		if ArmoryGuns.has(id) and (w.special != &"" or w.pellets > 6):
			ids.append(id)
	var z0 := player.global_position.z
	for id: StringName in ids:
		if not (_wants("armfx_" + String(id)) or _only.has("armfx_all")):
			continue
		# A fresh set of bugs each time.
		for n: Node in get_tree().get_nodes_in_group("bugs"):
			var old := n as Bug
			if old != null and old.is_alive():
				old.escaped() # (gone without a corpse or loot cluttering the next shots)
		await _wait(0.6)
		var lane := 0
		for i in 6:
			var z := z0 + (i - 2.5) * 2.2
			bm.spawn_at(&"rattler_beetle" if i % 3 == 0 else &"wolf_spider", cid, lane, z, WorldLayout.CLIFF_HEIGHT - 7.0 - (i % 2) * 2.5,
					Bug.State.CLIMBING, Vector3.ZERO)
		var rim := cb.plateau_point(cid, 1.5, z0)
		var inward := (cb.plateau_point(cid, 12.0, z0) - rim)
		inward.y = 0.0
		inward = inward.normalized()
		# Line shots (pierce, chain, ballista, ricochet, the volley guns): a file of
		# bugs on the plateau, shot along from further in; the rest: a few loose.
		var line_shot := [&"pierce_line", &"chain", &"ballista", &"ricochet"].has(Gun.weapon(id).special) or Gun.weapon(id).pellets > 6
		# (along the open strip by the rim: the plateau further in has the house and plots)
		var along := Vector3(0, 0, 1)
		for i in (4 if line_shot else 0):
			var p := rim + inward * 2.5 + along * (2.0 + i * 2.5) if line_shot else rim + inward * 9.0 + Vector3(0, 0, (i - 1) * 2.5)
			p.y = cb.ground_height_at(cid, p)
			bm.spawn_at(&"rattler_beetle" if i % 2 == 0 else &"wolf_spider", cid, lane, p.z, 0.0, Bug.State.BREACHING, p)
		await _wait(0.8)
		# Stand on the rim, the gun out, aimed at the middle of the climbers.
		GameState.god_mode = true # (the bugs on the plateau go for the rider)
		player.global_position = (rim + inward * 2.5 + along * 16.0 if line_shot else rim + inward * 0.6) + Vector3.UP * 0.1
		if line_shot:
			player.global_position.y = cb.ground_height_at(cid, player.global_position) + 0.1
		player.velocity = Vector3.ZERO
		var gun := player.gun
		gun.grant(id, 0)
		gun.equip(id)
		gun.ammo = gun.mag_size()
		gun.reserve[id] = 50
		if not GunShop.loadouts.has(multiplayer.get_unique_id()):
			GunShop.loadouts[multiplayer.get_unique_id()] = {}
		GunShop.loadouts[multiplayer.get_unique_id()][id] = 0
		var climbers: Array[Bug] = []
		for n: Node in get_tree().get_nodes_in_group("bugs"):
			var b := n as Bug
			if b != null and b.is_alive() and b.is_climbing():
				climbers.append(b)
		var target := rim - inward * 3.0 + Vector3(0, -6.0, 0)
		if not climbers.is_empty():
			target = climbers[mini(2, climbers.size() - 1)].global_position
		if line_shot:
			target = rim + inward * 2.5 + along * 2.0
			target.y = cb.ground_height_at(cid, target) + 0.6
		elif id == &"bear_trap_launcher" or id == &"caltrops_launcher" or id == &"phosphor_grenade" or id == &"glow_worm_launcher":
			target = cb.face_point(cid, WorldLayout.CLIFF_HEIGHT - 9.0, z0) # on the wall in the climbers' path
		var eye := player.camera.global_position
		var to := target - eye
		player.rotation.y = atan2(-to.x, -to.z)
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		await _wait(0.4)
		var hp_before: Dictionary = {}
		for n: Node in get_tree().get_nodes_in_group("bugs"):
			var b := n as Bug
			if b != null and b.is_alive():
				hp_before[b] = b.health.hp
		# Fire: a burst for the sprays and automatics, one shot for the rest.
		var shots := 14 if Gun.weapon(id).automatic else 1
		for s in shots:
			gun.set("_cooldown", 0.0)
			gun.set("spin", 1.0)
			if gun.ammo <= 0:
				gun.ammo = gun.mag_size()
			player.net.fire(player.camera.global_position, -player.camera.global_basis.z)
			await _wait(Gun.weapon(id).fire_interval)
		# Watch it land from out over the canyon (the rider's own view looks down past their boots).
		var spec := Camera3D.new()
		spec.fov = 60.0
		world.add_child(spec)
		var outward := -inward
		spec.global_position = target + outward * 16.0 + Vector3.UP * 4.0 + Vector3(0, 0, 6.0)
		spec.look_at(target + Vector3.UP * 1.0, Vector3.UP)
		spec.make_current()
		for f in 8:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/armfx_%s_%02d.png" % [_dir, id, f])
			await _wait(0.22)
		player.camera.make_current()
		spec.queue_free()
		if id == &"bear_trap_launcher" or id == &"caltrops_launcher" or id == &"glow_worm_launcher":
			await _wait(4.0) # (the climbers have to reach the trap, the patch, the grub)
		_count += 1
		var tally := {"hurt": 0, "dead": 0, "rooted": 0, "stunned": 0, "tarred": 0, "stripped": 0, "frenzied": 0, "slowed": 0}
		for k: Variant in hp_before:
			if not is_instance_valid(k):
				tally["dead"] += 1
				continue
			var b := k as Bug
			if not b.is_alive():
				tally["dead"] += 1
			elif b.health.hp < float(hp_before[b]) - 0.5:
				tally["hurt"] += 1
			var st := b.status
			tally["rooted"] += int(st.is_rooted())
			tally["stunned"] += int(st.is_stunned())
			tally["tarred"] += int(st.is_tarred())
			tally["stripped"] += int(st.is_stripped())
			tally["frenzied"] += int(st.is_frenzied())
			tally["slowed"] += int(st.speed_multiplier() < 0.99)
		print("[armfx] %s: %s (of %d bugs; ammo %d, reserve %d)" % [id, str(tally), hp_before.size(), gun.ammo, int(gun.reserve.get(id, 0))])
	# A universal heavy takes a sack: an empty Crop Mortar loads a chili sack.
	if _only.has("armfx_all") or _wants("armfx_cropload"):
		var gun := player.gun
		GunShop.loadouts[multiplayer.get_unique_id()][&"crop_mortar"] = 0
		gun.grant(&"crop_mortar", 0)
		gun.equip(&"crop_mortar")
		var before := Economy.amount(cid, &"chili_load")
		gun.request_load(&"firecracker_chili")
		await _wait(4.0)
		print("[armfx] cropload: chili sacks %d -> %d, mortar %d / %d (%s)" % [before, Economy.amount(cid, &"chili_load"), gun.ammo, gun.mag_size(), gun.heavy_crop_of(&"crop_mortar")])


## Each Weapon Slots gun in first person (given straight to the local rider):
## held at rest, aimed, part-way through a reload, and just after a shot.
func _armory_shots(player: Player) -> void:
	var ids: Array[StringName] = []
	for id: StringName in Gun.ORDER:
		if ArmoryGuns.has(id):
			ids.append(id)
	var gun := player.gun
	for id: StringName in ids:
		if not (_wants("arm_" + String(id)) or _only.has("arm_all")):
			continue
		gun.grant(id, 0)
		gun.equip(id)
		gun.ammo = gun.mag_size()
		await _wait(1.0)
		for pose: String in ["", "_aim", "_reload", "_fire"]:
			# (The rider's own input sets aiming every frame; --aim holds it up.)
			if pose == "_aim":
				GameState.flags.append("--aim")
			elif GameState.flags.has("--aim"):
				GameState.flags.remove_at(GameState.flags.find("--aim"))
			gun.set_aiming(pose == "_aim")
			if pose == "_reload":
				gun.ammo = 0
				gun.reserve[id] = 99
				gun.reload()
				await _wait(maxf(gun.reload_time() * 0.35, 0.3))
			elif pose == "_fire":
				gun.ammo = gun.mag_size()
				gun.set("_stage", 0)
				gun.set("_cooldown", 0.0)
				gun.set("spin", 1.0)
				gun.trigger(get_viewport().get_camera_3d())
				await _wait(0.06)
			else:
				await _wait(0.5)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/arm_%s%s.png" % [_dir, id, pose])
			_count += 1
		gun.set_aiming(false)
		await _wait(0.6)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _wants(step: String) -> bool:
	if _only.is_empty():
		return true
	for o: String in _only:
		if step.begins_with(o):
			return true
	return false


## Runs one step for every set: setup, settle, photograph, teardown.
func _step(step: String, setup: Callable, teardown: Callable = Callable(), settle: float = SETTLE) -> void:
	if not _wants(step):
		return
	for set_id: String in _sets:
		UiStyle.apply(StringName(set_id))
		await get_tree().process_frame
		var ok: Variant = setup.call()
		if ok is Signal:
			await ok
		await _wait(settle)
		await _film_clear()
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%s.png" % [_dir, set_id, step]
		get_viewport().get_texture().get_image().save_png(path)
		_count += 1
		print("[uigallery] ", path)
		if teardown.is_valid():
			teardown.call()
			await _wait(0.35)
	UiStyle.apply(StringName(_sets[0]))


## Frames of a hit on your Homestead (full, then down to 45%: the pickets topple
## right to left) and of it mending, for a GIF: homes_anim_NN.png.
func _homes_anim(player: Player) -> void:
	var cid := player.cliff_id
	var mx: float = GameState.homestead_max[cid]
	GameState.homestead_hp[cid] = mx
	GameState.homestead_changed.emit(cid, mx, mx)
	await _wait(1.5)
	var n := 0
	for phase: float in [0.45, 0.8]:
		GameState.homestead_hp[cid] = mx * phase
		GameState.homestead_changed.emit(cid, mx * phase, mx)
		for f in 22:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/homes_anim_%02d.png" % [_dir, n])
			n += 1
			await _wait(0.045)
		await _wait(0.6)


# ------------------------------------------------------------------ title screens

func _menu_tour(menu: Node) -> void:
	var sheet: Array = [null]
	await _step("kit_sheet", func() -> void:
		sheet[0] = (load("res://scenes/debug/kit_sheet.gd") as GDScript).new()
		add_child(sheet[0]),
		func() -> void: (sheet[0] as Node).queue_free(), 1.2)
	await _step("menu_home", func() -> void: menu.call("_page", &"home"))
	await _step("menu_story_mode", func() -> void: menu.call("_open_mode", &"story"),
		func() -> void: menu.call("_page", &"home"))
	await _step("menu_coop", func() -> void:
		menu.call("_open_mode", &"endless")
		menu.call("_page", &"coop"),
		func() -> void: menu.call("_page", &"home"))
	var settings := menu.get("_settings") as PauseMenu
	if settings != null:
		for i in 4:
			await _step("menu_settings_t%d" % i, func() -> void:
				settings.open()
				settings.select_tab(i),
				func() -> void: settings.close())
	var secrets := menu.get("_secrets") as CanvasLayer
	if secrets != null:
		await _step("menu_secrets", func() -> void: secrets.call("open"), func() -> void: secrets.call("close"))
	var story := menu.get("_story") as CanvasLayer
	if story != null:
		await _step("menu_story_screen", func() -> void: story.call("open"), func() -> void: story.call("close"), 1.6)
	var brands := menu.get("_brands") as CanvasLayer
	if brands != null:
		await _step("menu_brands", func() -> void: brands.call("open"), func() -> void:
			brands.call("close")
			brands.visible = false, 1.4)
	var ledger := menu.get("_ledger") as CanvasLayer
	if ledger != null:
		for t in 2:
			await _step("menu_ledger_t%d" % t, func() -> void:
				ledger.call("open")
				ledger.set("tab", t)
				ledger.call("refresh"),
				func() -> void: ledger.call("close"), 1.4)
	# The lobby last: it hosts (on the test port) and stays there.
	if _wants("menu_lobby"):
		if not Brand.has_chosen():
			Brand.choose(&"none")
		menu.call("_on_host")
		await _wait(2.5)
		await _step("menu_lobby", func() -> void: pass)


# ------------------------------------------------------------------ in game

func _world_tour(world: Node) -> void:
	var hud := world.get("hud") as Hud
	var player := world.call("local_player") as Player
	var cid := player.cliff_id
	Economy.earn(cid, {&"corn": 6, &"chili": 3, &"chitin": 40, &"scrap": 250, &"corn_load": 2})
	if GameState.has_flag("--themetime"):
		await _wait(3.0)
		print("[themetime] nodes=", get_tree().get_node_count())
		for sid: StringName in [&"sheaf", &"base", &"irons", &"base"]:
			var t0 := Time.get_ticks_usec()
			UiStyle.apply(sid)
			print("[themetime] %s apply %d ms" % [sid, (Time.get_ticks_usec() - t0) / 1000])
			var f0 := Time.get_ticks_usec()
			await get_tree().process_frame
			var f1 := Time.get_ticks_usec()
			await get_tree().process_frame
			var f2 := Time.get_ticks_usec()
			await _wait(1.0)
			print("[themetime]   next frames %d ms, %d ms; fps after 1 s %d" % [(f1 - f0) / 1000, (f2 - f1) / 1000, Engine.get_frames_per_second()])
	player.global_position = Bug.cliffs.plateau_point(cid, 6.0, 4.0) + Vector3.UP * 0.2 if Bug.cliffs != null else player.global_position
	await _wait(0.5)
	if GameState.has_flag("--fpsdebug"):
		var tick := func() -> void:
			while true:
				await _wait(0.5)
				print("[homesdebug] t=%d fps=%d proc=%.1fms phys=%.1fms draws=%d" % [Time.get_ticks_msec(), Engine.get_frames_per_second(),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		tick.call()
	await _step("hud_build", func() -> void: pass)
	# The Homestead plates at full, hurt, burning and burnt down (yours, then the others).
	for look: Array in [["homes_a", 1.0, 0.72], ["homes_b", 0.55, 0.38], ["homes_c", 0.23, 0.0]]:
		await _step(str(look[0]), func() -> void:
			for hc in GameState.homestead_hp.size():
				var mine := hc == player.cliff_id
				GameState.homestead_hp[hc] = GameState.homestead_max[hc] * float(look[1] if mine else look[2])
				GameState.homestead_changed.emit(hc, GameState.homestead_hp[hc], GameState.homestead_max[hc]), Callable(), 2.5)
		if GameState.has_flag("--homesdebug"):
			var st: Node = hud.get("status")
			print("[homesdebug] ", look[0], " ts=", Engine.time_scale, " paused=", get_tree().paused, " fps=", Engine.get_frames_per_second())
			for f: Variant in st.get("_fences"):
				print("[homesdebug]   ratio=", f.ratio, " tilt=", f.get("_tilt"), " proc=", f.is_processing(), " mode=", f.process_mode, " can=", f.can_process())
	if _wants("anim_homes"):
		await _homes_anim(player)
	for hc in GameState.homestead_hp.size():
		GameState.homestead_hp[hc] = GameState.homestead_max[hc]
		GameState.homestead_changed.emit(hc, GameState.homestead_hp[hc], GameState.homestead_max[hc])
	await _step("hud_prompt", func() -> void: hud.feed.set("_prompt_text", "Water Barrel\nE: Fill Bucket   F: Drink"),
		func() -> void: hud.feed.set("_prompt_text", ""))
	# Warm the build menu's icons first (they render lazily, a few per frame).
	if _wants("build_menu"):
		player.build_mode.toggle()
		for c: int in [1, 0, 4]:
			player.build_mode.show_category(c)
			player.build_mode.open_menu()
			await _wait(1.5)
		if player.build_mode.active:
			player.build_mode.toggle()
		await _wait(0.5)
	# Tabs: 0 Farming, 1 Cliff Turrets (both kinds), 4 Air Defense; then the
	# Cliff Turrets tab sorted to Standard and to Crop-Fed (Defs.build_tabs()).
	for pick: Array in [["build_menu_c1", 1, 0], ["build_menu_c0", 0, 0], ["build_menu_c4", 4, 0], ["build_menu_std", 1, 1], ["build_menu_crop", 1, 2], ["build_menu_air", 1, 3]]:
		await _step(str(pick[0]), func() -> void:
			player.build_mode.toggle()
			player.build_mode.set_kind(int(pick[2]))
			player.build_mode.show_category(int(pick[1]))
			player.build_mode.open_menu(),
			func() -> void:
				player.build_mode.set_kind(0)
				if player.build_mode.active:
					player.build_mode.toggle())
	# The sky at several hours and weathers (no HUD): sky_<name>.
	if _only.is_empty() or Array(_only).any(func(o: String) -> bool: return o.begins_with("sky_")):
		await _sky_shots(world, hud, player)
	# Each weather from the ground (no HUD): wx_<kind>_<view>, plus a lightning strike.
	if _only.is_empty() or Array(_only).any(func(o: String) -> bool: return o.begins_with("wx_")):
		await _weather_shots(world, hud, player)
	# The Weapon Slots guns in your hands: arm_<id> held, arm_<id>_aim, arm_<id>_reload.
	if Array(_only).any(func(o: String) -> bool: return o.begins_with("arm_")):
		await _armory_shots(player)
	if Array(_only).any(func(o: String) -> bool: return o.begins_with("armfx_")):
		await _armory_fx_shots(world, hud, player)
	# Universal crop-fed turrets, live (scenes/debug/universal_views.gd).
	if Array(_only).any(func(o: String) -> bool: return o.begins_with("uni_")):
		await UniversalViews.new().run(self, world, hud, player)
	# The land beyond the play area, as the player sees it (no HUD): land_<view>.
	if _only.is_empty() or Array(_only).any(func(o: String) -> bool: return o.begins_with("land_")):
		await _land_shots(world, hud)
	# The airship's casino tables in 3D (no HUD): a front view and a three-quarter view each.
	if _only.is_empty() or Array(_only).any(func(o: String) -> bool: return o.begins_with("table_")):
		await _table_shots(world, hud)
	var pm := world.get_node_or_null("PauseMenu") as PauseMenu
	if pm != null:
		for i in 5:
			await _step("pause_t%d" % i, func() -> void:
				pm.open()
				pm.select_tab(i),
				func() -> void: pm.close())
	if PauseVote.instance != null:
		await _step("pause_vote", func() -> void: PauseVote.instance.toggle_vote(),
			func() -> void: PauseVote.instance.press_unpause())
	var menus := {
		"menu_vendor_t0": ["Vendor", 0], "menu_vendor_t1": ["Vendor", 1],
		"menu_gunsmith_t0": ["GunShop", 0], "menu_gunsmith_t1": ["GunShop", 1], "menu_gunsmith_t2": ["GunShop", 2], "menu_gunsmith_t3": ["GunShop", 3],
		"casino_slots": ["Slots0", -1], "casino_blackjack": ["Blackjack", -1], "casino_roulette": ["Roulette", -1],
		"casino_wheel": ["Wheel", -1], "casino_chips": ["ChipCage", -1], "casino_race": ["BeetleRace", -1],
	}
	for step: String in menus:
		var node := world.find_child(str(menus[step][0]), true, false)
		if node == null:
			continue
		var tab: int = menus[step][1]
		await _step(step, func() -> void:
			MenuScreen.instance.open(node)
			if tab >= 0:
				MenuScreen.instance.tab = tab
				MenuScreen.instance.refresh(),
			func() -> void: MenuScreen.instance.close())
	var home := Homestead.of(cid)
	if home != null and home.get_node_or_null("Ledger") != null:
		await _step("menu_house_ledger", func() -> void: MenuScreen.instance.open(home.get_node("Ledger")),
			func() -> void: MenuScreen.instance.close())
	if home != null and home.get_node_or_null("Chest") != null:
		await _step("menu_chest", func() -> void: MenuScreen.instance.open(home.get_node("Chest")),
			func() -> void: MenuScreen.instance.close())
	for t in 3:
		await _step("menu_guide_t%d" % t, func() -> void:
			FieldGuide.open()
			MenuScreen.instance.tab = t
			MenuScreen.instance.refresh(),
			func() -> void: MenuScreen.instance.close())
	await _step("menu_wardrobe", func() -> void: Wardrobe.open(), func() -> void: MenuScreen.instance.close(), 1.5)
	if _wants("map"): # the map's terrain survey runs a few seconds after load
		var until := Time.get_ticks_msec() + 30000
		while not bool(hud.overview.get("_surveyed")) and Time.get_ticks_msec() < until:
			await get_tree().process_frame
	await _step("map", func() -> void: hud.overview.visible = true, func() -> void: hud.overview.visible = false)
	await _step("wave_summary", func() -> void: hud.summary.demo(), Callable(), 2.0)
	await _step("title_card", func() -> void: hud.title_card.show_card("Wave 3 Held", "The canyon is quiet. For now.", UiStyle.c("title")), Callable(), 1.2)
	if world.get_node_or_null("StoryDirector") != null:
		await _story_steps(world.get_node("StoryDirector"))
	# The wave: skip to it and let the bugs climb.
	if _wants("hud_wave"):
		GameState.debug_skip()
		await _wait(1.0)
		if GameState.phase != GameState.Phase.WAVE:
			GameState.debug_skip()
		await _wait(14.0)
		await _step("hud_wave", func() -> void: pass)
	await _step("gameover", func() -> void: GameState._finish(true, "Debug view of the end of the run."), Callable(), 2.5)


func _story_steps(director: Node) -> void:
	var radio := director.get("radio") as Node
	if radio != null:
		await _step("story_radio", func() -> void: radio.call("say", "stroud", "Riders, the north wall's crawling. Keep your partner's side covered."), Callable(), 2.5)
	var tele := director.get("telegram") as Node
	if tele != null:
		await _step("story_telegram", func() -> void: tele.call("open"), func() -> void: tele.call("close_view"), 1.5)


func _tutorial_tour() -> void:
	await _wait(4.0)
	await _step("tutorial_%s" % GameState.flag_value("--tutorialstep"), func() -> void: pass)


## On the title screen, waits (up to 20 s) for the canyon film to be on screen
## and not mid-fade between its shots.
func _film_clear() -> void:
	var cs := get_tree().current_scene
	var film: Node = cs.get("_cinematic") if cs != null and cs.get("_cinematic") != null else null
	if film == null:
		return
	var until := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until:
		var fade := film.get("fade") as ColorRect
		if bool(film.get("ready_to_film")) and fade != null and fade.color.a < 0.03 and float(film.get("_t")) < float(film.get("_dur")) - 1.5:
			return
		await get_tree().process_frame


func _table_shots(world: Node, hud: Hud) -> void:
	var ship := world.get_node_or_null("Airship") as Node3D
	if ship == null:
		return
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 400.0
	world.add_child(cam)
	var prev := get_viewport().get_camera_3d()
	hud.visible = false
	var views := {"front": Vector3(0.0, 1.75, -2.6), "side": Vector3(1.9, 1.9, -1.9), "top": Vector3(0.0, 3.1, -0.9)}
	# The booths are bigger: stand further back.
	var booth_views := {"front": Vector3(0.0, 2.0, -5.4), "side": Vector3(3.2, 2.2, -3.8), "top": Vector3(0.0, 3.6, -2.4)}
	# The whole deck: from the boarding ladder at eye height, from above the bow, and straight down.
	for d: Array in [["deck_ladder", Vector3(0, 1.7, 16.6), Vector3(0, 1.2, 4.0)], ["deck_mid", Vector3(0, 1.75, 2.0), Vector3(0, 1.4, 14.0)],
			["deck_high", Vector3(-1.0, 3.7, 4.2), Vector3(0, 0.6, 12.0)], ["deck_aft", Vector3(0, 3.8, -5.0), Vector3(0, 1.0, 10.0)]]:
		var step := "table_" + str(d[0])
		if not (_only.is_empty() or _only.has("table_all") or _wants(step)):
			continue
		var keep := _only
		_only = []
		await _step(step, func() -> void:
			cam.fov = 80.0
			cam.global_position = ship.to_global(d[1])
			cam.look_at(ship.to_global(d[2]), Vector3.UP if absf((d[1] as Vector3).x - (d[2] as Vector3).x) + absf((d[1] as Vector3).z - (d[2] as Vector3).z) > 0.1 else Vector3.FORWARD)
			cam.make_current(), func() -> void: cam.fov = 50.0, 0.8)
		_only = keep
	# A pull on the first slot machine: mid-spin, then stopped on the roll.
	if _only.has("table_all") or _wants("table_slotspin"):
		var slots := ship.get_node_or_null("Slots0") as SlotMachine
		if slots != null:
			var keep := _only
			_only = []
			await _step("table_slotspin_a", func() -> void:
				cam.global_position = slots.global_transform * Vector3(0.0, 1.5, -1.3)
				cam.look_at(slots.global_transform * Vector3(0, 1.3, 0), Vector3.UP)
				cam.make_current()
				slots._act(1, &"pull", 0, 10), Callable(), 0.55)
			await _step("table_slotspin_b", func() -> void: pass, Callable(), 3.5)
			_only = keep
	for table_name: String in ["Baccarat", "Blackjack", "Roulette", "ShellGame", "BeetleRace", "Wheel", "Slots0",
			"Vendor", "GunShop", "ChipCage", "Lucky", "LuckyMoreau"]:
		var t := ship.get_node_or_null(table_name) as Node3D
		if t == null:
			continue
		var booth := ["Vendor", "GunShop", "ChipCage", "Lucky"].has(table_name)
		for v: String in views:
			var step := "table_%s_%s" % [table_name.to_lower(), v]
			if not (_only.is_empty() or _only.has("table_all") or _wants(step)):
				continue
			var keep := _only
			_only = [] # (this step is wanted: let _step take it)
			await _step(step, func() -> void:
				cam.global_position = t.global_transform * (booth_views[v] if booth else views[v])
				cam.look_at(t.global_transform * Vector3(0, 1.55 if booth else 0.95, 0), Vector3.UP)
				cam.make_current(), Callable(), 0.6)
			_only = keep
	hud.visible = true
	cam.queue_free()
	if prev != null:
		prev.make_current()


## The sky photographed across the day and in weather: [name, hour, weather,
## yaw offset from the sun (degrees), pitch (degrees)].
## Weather as the player sees it: [name, weather, hour]; three views each
## (across the canyon from the rim, along it, and from the floor), and for the
## thunderstorm a strike in front of the camera caught mid-flash (wx_storm_bolt).
const WX_SHOTS := [["rain", 2, 15.0], ["storm", 3, 16.0], ["dust", 5, 13.0], ["windy", 1, 11.0], ["snow", 4, 12.0],
	["fog", 7, 9.0], ["heat", 6, 13.5], ["bloodmoon", 8, 23.0]]


func _weather_shots(world: Node, hud: Hud, player: Player) -> void:
	var cb := world.get("cliffs") as CliffBuilder
	var cycle := DayCycle.instance
	if cb == null or cycle == null:
		return
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = GraphicsQuality.VIEW_FAR[GraphicsQuality.level(Settings.view_distance)]
	world.add_child(cam)
	var prev := get_viewport().get_camera_3d()
	hud.visible = false
	var keep_weather := GameState.weather
	var rim := cb.plateau_point(player.cliff_id, 6.0, 4.0) + Vector3(0, 1.7, 0)
	var across := cb.plateau_point(1 - player.cliff_id, 10.0, 10.0) + Vector3(0, -8.0, 0)
	var floor_at := Vector3(cb.center_x(-30.0), cb.floor_height(cb.center_x(-30.0), -30.0) + 1.7, -30.0)
	var views: Array = [["across", rim, across], ["along", rim + Vector3(0, 0.5, 0), rim + Vector3(0, -12.0, 120.0)],
		["floor", floor_at, floor_at + Vector3(0, 8.0, 100.0)]]
	for w: Array in WX_SHOTS:
		for v: Array in views:
			var step := "wx_%s_%s" % [w[0], v[0]]
			if not (_only.is_empty() or _only.has("wx_all") or _wants(step)):
				continue
			var keep := _only
			_only = []
			await _step(step, func() -> void:
				GameState.weather = int(w[1])
				cycle.clock = float(w[2])
				cycle.set("_target", float(w[2]))
				cycle.set("_rate", 0.0)
				cycle.snap_sky()
				if WeatherFx.instance != null:
					WeatherFx.instance.snap()
				cam.global_position = v[1]
				cam.look_at(v[2], Vector3.UP)
				cam.make_current(), Callable(), 6.0)
			_only = keep
	# A lightning strike on the far rim, caught just after the flash.
	if _only.has("wx_all") or _wants("wx_storm_bolt"):
		var keep := _only
		_only = []
		var fx := WeatherFx.instance
		await _step("wx_storm_bolt", func() -> void:
			GameState.weather = Weather.Kind.THUNDERSTORM
			cycle.clock = 16.0
			cycle.set("_target", 16.0)
			cycle.snap_sky()
			if fx != null:
				fx.snap()
			cam.global_position = rim
			cam.look_at(across + Vector3(0, 20, 0), Vector3.UP)
			cam.make_current(), Callable(), 6.0)
		_only = keep
		if fx != null:
			for k in 6:
				if k == 0:
					fx.call("_bolt", across + Vector3(0, 8.0, 0), false)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/base_wx_bolt_%02d.png" % [_dir, k])
				await _wait(0.05)
	# Frame cost of each weather (wx_perf): GPU and render CPU averaged over three
	# seconds, looking along the canyon from the rim, clear first.
	if _wants("wx_perf") and not _only.is_empty():
		var vp := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		cam.global_position = views[1][1]
		cam.look_at(views[1][2], Vector3.UP)
		cam.make_current()
		for kind: int in [Weather.Kind.CLEAR, Weather.Kind.LIGHT_RAIN, Weather.Kind.THUNDERSTORM, Weather.Kind.DUST_STORM, Weather.Kind.SNOW, Weather.Kind.FOG, Weather.Kind.CLEAR]:
			GameState.weather = kind
			cycle.clock = 15.0
			cycle.set("_target", 15.0)
			cycle.snap_sky()
			if WeatherFx.instance != null:
				WeatherFx.instance.snap()
			await _wait(2.0)
			var t0 := Time.get_ticks_msec()
			var gpu := 0.0
			var cpu := 0.0
			var n := 0
			while Time.get_ticks_msec() - t0 < 3000:
				await get_tree().process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
				n += 1
			print("[wxperf] %s: gpu %.3f ms  render cpu %.3f ms  fps %d  draws %d" % [Weather.Kind.keys()[kind], gpu / n, cpu / n,
					Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	GameState.weather = keep_weather
	hud.visible = true
	cam.queue_free()
	if prev != null:
		prev.make_current()


## The landscape past the play area from the places a player looks at it:
## the rim looking out and along, across the canyon, high over the cliffs,
## the canyon floor, the airship, at the in-game view distance; then a fogless
## overview from far above (land_overview). --landhour=<h> sets the clock (15).
func _land_shots(world: Node, hud: Hud) -> void:
	var cb := world.get("cliffs") as CliffBuilder
	var cycle := DayCycle.instance
	if cb == null or cycle == null:
		return
	# --hidenodes=Prefix,...: hide the terrain and dressing pieces whose names start
	# so (to see which builder makes what); --landfar=<m> overrides the far plane.
	var hide := GameState.flag_value("--hidenodes").split(",", false)
	if not hide.is_empty():
		for root_name: String in ["Terrain", "Dressing"]:
			var root := world.get_node_or_null(root_name)
			if root == null:
				continue
			for n: Node in root.get_children():
				for pre: String in hide:
					if str(n.name).begins_with(pre) and n is Node3D:
						(n as Node3D).visible = false
		print("[land] terrain pieces: ", ", ".join(PackedStringArray(world.get_node("Terrain").get_children().map(func(n: Node) -> String: return str(n.name)))))
		print("[land] dressing pieces: ", ", ".join(PackedStringArray(world.get_node("Dressing").get_children().map(func(n: Node) -> String: return "%s(%s)" % [n.name, n.get_class()]))))
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = GraphicsQuality.VIEW_FAR[GraphicsQuality.level(Settings.view_distance)]
	if GameState.flag_value("--landfar") != "":
		cam.far = GameState.flag_value("--landfar").to_float()
	world.add_child(cam)
	var prev := get_viewport().get_camera_3d()
	hud.visible = false
	var hour := 15.0 if GameState.flag_value("--landhour") == "" else GameState.flag_value("--landhour").to_float()
	cycle.clock = hour
	cycle.set("_target", hour)
	cycle.set("_rate", 0.0)
	cycle.sky_style = 0
	cycle.snap_sky()
	var out0 := Vector3(WorldLayout.side_sign(0), 0, 0)
	var out1 := Vector3(WorldLayout.side_sign(1), 0, 0)
	var rim := cb.plateau_point(0, 30.0, 0.0) + Vector3(0, 2.5, 0)
	var rim1 := cb.plateau_point(1, 40.0, 30.0) + Vector3(0, 2.5, 0)
	var floor_at := Vector3(cb.center_x(140.0), cb.floor_height(cb.center_x(140.0), 140.0) + 2.0, 140.0)
	var ship := world.get_node_or_null("Airship") as Node3D
	var ship_at := ship.global_position + Vector3(6.5, 2.2, 0.0) if ship != null else rim + Vector3(0, 40, 0)
	var views: Array = [
		["rim_out", rim, rim + out0 * 200.0 + Vector3(0, -8, 0)],
		["rim_out_left", rim, rim + (out0 + Vector3(0, 0, -0.8)).normalized() * 200.0 + Vector3(0, -8, 0)],
		["rim_along", cb.plateau_point(0, 8.0, -60.0) + Vector3(0, 3, 0), cb.plateau_point(0, 8.0, 200.0) + Vector3(0, -10, 0)],
		["across", rim1, rim1 - out1 * 300.0 + Vector3(0, -10, 0)],
		["across_wide", rim1 + Vector3(0, 8, 0), rim1 - out1 * 300.0 + Vector3(0, -30, 120)],
		["high_out", rim + Vector3(0, 90, 0), rim + out0 * 400.0 + Vector3(0, -60, 0)],
		["high_along", Vector3(cb.center_x(-260.0), 170.0, -260.0), Vector3(cb.center_x(300.0), 30.0, 300.0)],
		["floor_along", floor_at, floor_at + Vector3(0, 6, 200)],
		["ship_out", ship_at, ship_at + Vector3(300, -70, 60)],
		["ship_back", ship_at + Vector3(-13, 0, 0), ship_at + Vector3(-300, -70, -60)],
	]
	for v: Array in views:
		var step := "land_" + str(v[0])
		if not (_only.is_empty() or _only.has("land_all") or _wants(step)):
			continue
		var keep := _only
		_only = []
		await _step(step, func() -> void:
			cam.global_position = v[1]
			cam.look_at(v[2], Vector3.UP)
			cam.make_current(), Callable(), 2.0)
		_only = keep
	# Frame cost of the view distance from the airship (land_perf): far plane at the
	# old 600 m against 2 km, render CPU and GPU averaged over three seconds each.
	if _wants("land_perf") and not _only.is_empty():
		var vp := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		cam.global_position = ship_at
		cam.look_at(ship_at + Vector3(300, -70, 60), Vector3.UP)
		cam.make_current()
		for far_m: float in [600.0, 2000.0, 600.0, 2000.0]:
			cam.far = far_m
			await _wait(1.5)
			var t0 := Time.get_ticks_msec()
			var gpu := 0.0
			var cpu := 0.0
			var n := 0
			while Time.get_ticks_msec() - t0 < 3000:
				await get_tree().process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
				n += 1
			print("[landperf] far %d m: gpu %.3f ms  render cpu %.3f ms  draws %d  prims %d" % [far_m, gpu / n, cpu / n,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		cam.far = GraphicsQuality.VIEW_FAR[GraphicsQuality.level(Settings.view_distance)]
	# Each landmark close up: from 160 m toward the middle and 50 m up (land_mark_<name>).
	for mk: Array in ColossusBuilder.last_placed:
		var step := "land_mark_" + str(mk[0])
		if not (_only.has("land_all") or _wants(step)):
			continue
		var at: Vector3 = mk[1]
		var back := Vector3(-at.x, 0, -at.z).normalized()
		var keep := _only
		_only = []
		await _step(step, func() -> void:
			cam.global_position = at + back * 170.0 + Vector3(0, 55.0, 0)
			cam.look_at(at + Vector3(0, 25.0, 0), Vector3.UP)
			cam.make_current(), Callable(), 2.0)
		_only = keep
	# A fogless map of everything out to the horizon, from straight above.
	if _only.has("land_all") or _wants("land_overview"):
		var env := (world.get("_env") as Environment)
		var fog_was := env.fog_enabled if env != null else false
		var keep := _only
		_only = []
		await _step("land_overview", func() -> void:
			if env != null:
				env.fog_enabled = false
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 4200.0
			cam.far = 4000.0
			cam.global_position = Vector3(0, 1800, 0)
			cam.look_at(Vector3(0, 0, 0.01), Vector3.FORWARD)
			cam.make_current(), func() -> void:
			if env != null:
				env.fog_enabled = fog_was
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE, 3.0)
		_only = keep
	cycle.sky_style = -1
	hud.visible = true
	cam.queue_free()
	if prev != null:
		prev.make_current()


## GPU cost of the sky, old shader against new (--uionly=sky_perf
## --oldsky=<path to the old sky.gdshader>): the camera floats over the airship
## looking out at mostly sky, and the viewport's measured GPU time is averaged
## over three seconds for each look.
func _sky_perf(world: Node, hud: Hud, cycle: DayCycle) -> void:
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 2000.0
	world.add_child(cam)
	hud.visible = false
	var ship := world.get_node_or_null("Airship") as Node3D
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var new_shader := cycle.sky.shader
	var old := Shader.new()
	old.code = FileAccess.get_file_as_string(GameState.flag_value("--oldsky"))
	for look: Array in [["noon", 14.0, 0, 1], ["dusk", 18.3, 0, 2], ["night", 23.0, 0, 3], ["storm", 13.0, 3, -1]]:
		for which: String in ["old", "new", "old", "new"]:
			cycle.sky.shader = old if which == "old" else new_shader
			if which == "old":
				cycle.sky.set_shader_parameter("cloud_noise", Materials.noise_texture(42, 0.012, 512))
				cycle.sky.set_shader_parameter("art_clouds", load("res://assets/sky/clouds.png"))
			GameState.weather = int(look[2])
			cycle.sky_style = int(look[3])
			cycle.clock = float(look[1])
			cycle.set("_target", float(look[1]))
			cycle.set("_rate", 0.0)
			cycle.set("_sky_sent", {})
			cycle.snap_sky()
			cam.global_position = (ship.global_position if ship != null else Vector3.ZERO) + Vector3.UP * 30.0
			cam.global_rotation = Vector3(deg_to_rad(20.0), cycle.sun.global_rotation.y + deg_to_rad(120.0), 0.0)
			cam.make_current()
			await get_tree().create_timer(1.5).timeout
			var t0 := Time.get_ticks_msec()
			var gpu := 0.0
			var n := 0
			while Time.get_ticks_msec() - t0 < 3000:
				await get_tree().process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				n += 1
			print("[skyperf] %s %s gpu %.3f ms over %d frames" % [look[0], which, gpu / maxf(n, 1), n])
	cycle.sky.shader = new_shader
	cycle.sky_style = -1
	cycle.set("_sky_sent", {})
	hud.visible = true
	cam.queue_free()


## Sky shots: [name, hour, weather, yaw from the sun's heading (0 looks away
## from the sun, 180 into it), pitch, cloud style (-1 = the wave's own), height].
## Height 0 stands at the player; above 0 the camera floats that high over the
## airship, clear of the canyon walls.
const SKY_SHOTS := [["noon", 12.0, 0, 150.0, 18.0, 1, 0.0], ["noon_sun", 12.0, 0, 0.0, 30.0, 5, 0.0],
	["morning", 8.5, 0, 60.0, 14.0, 2, 0.0], ["dusk", 18.3, 0, 0.0, 8.0, 1, 0.0], ["dusk_away", 18.3, 0, 170.0, 14.0, 2, 0.0],
	["night", 23.0, 0, 120.0, 30.0, 0, 0.0], ["dawn", 6.2, 0, 10.0, 10.0, 3, 0.0], ["storm", 13.0, 3, 120.0, 16.0, -1, 0.0],
	["rain", 15.0, 2, 90.0, 16.0, -1, 0.0], ["dust", 12.0, 5, 90.0, 12.0, -1, 0.0], ["windy", 11.0, 1, 100.0, 16.0, -1, 0.0],
	["bloodmoon", 23.0, 8, 0.0, 22.0, -1, 0.0],
	# From above the airship: the cloud styles a wave can roll, and the rest of the new sky.
	["hi_fair", 14.0, 0, 120.0, 12.0, 0, 30.0], ["hi_puffy", 14.0, 0, 120.0, 12.0, 1, 30.0],
	["hi_mackerel", 14.0, 0, 120.0, 12.0, 2, 30.0], ["hi_mares_tails", 14.0, 0, 120.0, 12.0, 3, 30.0],
	["hi_big_sky", 14.0, 0, 120.0, 6.0, 4, 30.0], ["hi_broken", 14.0, 0, 120.0, 12.0, 5, 30.0],
	["hi_dusk_puffy", 18.0, 0, 200.0, 8.0, 1, 30.0], ["hi_dusk_mackerel", 18.4, 0, 210.0, 12.0, 2, 30.0],
	["hi_dusk_away", 18.4, 0, 0.0, 8.0, 0, 30.0], ["hi_dawn", 6.3, 0, 195.0, 8.0, 3, 30.0],
	["hi_noon_sun", 11.0, 0, 180.0, 30.0, 1, 30.0], ["hi_storm", 13.0, 3, 60.0, 6.0, -1, 30.0],
	["hi_rain", 15.0, 2, 60.0, 8.0, -1, 30.0], ["hi_dust", 12.0, 5, 60.0, 6.0, -1, 30.0],
	["hi_heat", 13.0, 6, 200.0, 10.0, -1, 30.0], ["hi_fog", 10.0, 7, 60.0, 8.0, -1, 30.0],
	["hi_snow", 12.0, 4, 60.0, 10.0, -1, 30.0], ["hi_windy", 11.0, 1, 100.0, 12.0, -1, 30.0],
	["hi_night", 23.0, 0, 180.0, 30.0, 0, 30.0], ["hi_night2", 47.0, 0, 180.0, 30.0, 2, 30.0],
	["hi_night3", 71.0, 0, 180.0, 30.0, 4, 30.0], ["hi_night4", 95.0, 0, 180.0, 30.0, 0, 30.0],
	["hi_night_away", 23.0, 0, 30.0, 35.0, 3, 30.0],
	["hi_bloodmoon", 23.0, 8, 180.0, 26.0, -1, 30.0], ["hi_zenith", 15.0, 0, 90.0, 80.0, 1, 30.0]]


func _sky_shots(world: Node, hud: Hud, player: Player) -> void:
	var cycle := DayCycle.instance
	if cycle == null:
		return
	if _wants("sky_perf") and GameState.flag_value("--oldsky") != "":
		await _sky_perf(world, hud, cycle)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 2000.0
	world.add_child(cam)
	var prev := get_viewport().get_camera_3d()
	hud.visible = false
	var keep_weather := GameState.weather
	var keep_clock := cycle.clock
	for shot: Array in SKY_SHOTS:
		var step := "sky_" + str(shot[0])
		if not (_only.is_empty() or _only.has("sky_all") or _wants(step)):
			continue
		var keep := _only
		_only = []
		await _step(step, func() -> void:
			GameState.weather = int(shot[2])
			cycle.sky_style = int(shot[5])
			cycle.clock = float(shot[1])
			cycle.set("_target", float(shot[1]))
			cycle.set("_rate", 0.0)
			cycle.snap_sky()
			# --skyset=param:value,...: pin sky parameters (tuning the shader by eye).
			for kv: String in GameState.flag_value("--skyset").split(",", false):
				cycle.sky.set_shader_parameter(kv.get_slice(":", 0), kv.get_slice(":", 1).to_float())
			var ship := world.get_node_or_null("Airship") as Node3D
			if float(shot[6]) > 0.0 and ship != null:
				cam.global_position = ship.global_position + Vector3.UP * float(shot[6])
			else:
				cam.global_position = player.global_position + Vector3.UP * (1.7 + float(shot[6]))
			var sun_yaw := cycle.sun.global_rotation.y
			cam.global_rotation = Vector3(deg_to_rad(float(shot[4])), sun_yaw + deg_to_rad(float(shot[3])), 0.0)
			cam.make_current(), Callable(), 6.0) # (weather and the sky's reflections ease in)
		_only = keep
	GameState.weather = keep_weather
	cycle.sky_style = -1
	cycle.clock = keep_clock
	cycle.set("_target", keep_clock)
	hud.visible = true
	cam.queue_free()
	if prev != null:
		prev.make_current()
