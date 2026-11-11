extends Node
## Debug: the Nov 11 playtest fixes seen live, solo (--playtestview=<dir>):
## the crop bag's turret card and wheel at 10 m, a load from the bag, the cellar
## with its workbench and the carried-crops strip, the bench's menu and a
## conversion. Logs [playtest] lines and saves pt_*.png, then quits.
## Run windowed: godot --path . res://scenes/world.tscn -- --solo --debug --playtestview=<dir>

var world: Node3D
var _dir := ""


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	_dir = GameState.flag_value("--playtestview")
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/pt_%s.png" % [_dir, name])
	print("[playtest] saved pt_%s.png" % name)


func _aim(p: Player, at: Vector3) -> void:
	var d := at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _run() -> void:
	var p: Player = null
	while p == null or not bool(world.get("_started")):
		await get_tree().create_timer(0.5).timeout
		p = world.call("local_player") as Player
	await get_tree().create_timer(2.0).timeout
	var cid := p.cliff_id
	# (no stray mouse wheel or keys switching what's in hand mid-shot)
	var hb := p.get_node_or_null("Hotbar")
	if hb != null:
		hb.set_process_unhandled_input(false)
	Economy.notice.connect(func(text: String) -> void: print("[playtest] notice: ", text))
	var builds := world.get("builds") as BuildManager
	Economy.earn(cid, {&"scrap": 2000, &"chitin": 200, &"corn_load": 40, &"chili_load": 6})
	builds.build(&"cf_crop_hopper", cid, Vector2i(0, 7))
	builds.build(&"cf_harvest_mortar", cid, Vector2i(0, 11))
	builds.build(&"gatling_post", cid, Vector2i(0, 4)) # (a turret that isn't crop-fed: orange)
	await get_tree().create_timer(2.0).timeout
	p.carry.add(&"corn", 12)
	p.carry.add(&"firecracker_chili", 5)
	p.carry.add(&"cotton", 8)
	var t: Turret = null
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		print("[playtest] found turret %s cliff %d" % [n.name, int(n.get("cliff_id"))])
		if int(n.get("cliff_id")) == cid and n.has_method("request_load") and t == null:
			t = n as Turret
	print("[playtest] turret %s, carry %s, corn sacks %d" % [t.def.id if t != null else "none", str(p.carry.carried()), Economy.amount(cid, &"corn_load")])
	# The bag out, 10 m back from the turret, looking at it.
	p.crop_bag.set_bag_crop(&"corn")
	p.gun.hold_item(CropBagUI.ITEM)
	var inward := WorldLayout.inward(cid)
	p.global_position = t.global_position - inward * 6.0 + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.6).timeout
	_aim(p, t.global_position + Vector3.UP * 0.9)
	await get_tree().create_timer(1.2).timeout
	print("[playtest] bag target at %.1f m: %s, feed %s" % [p.camera.global_position.distance_to(t.global_position),
			str(p.crop_bag.target()), str(CropBagUI.feed(t, &"corn"))])
	await _shot("bag_card")
	CropWheel.open_for(CropBagUI.Wheel.new(p.crop_bag), &"alt_fire")
	await _shot("bag_wheel")
	CropWheel.instance.close()
	t.request_load(&"corn")
	await get_tree().create_timer(0.8).timeout
	print("[playtest] after a bag load: turret crop %s, corn sacks %d" % [str(t.get("crop")), Economy.amount(cid, &"corn_load")])
	print("[playtest] holding after the load: %s" % p.gun.holding)
	p.gun.hold_item(CropBagUI.ITEM)
	p.global_position = t.global_position - WorldLayout.inward(cid) * 14.0 + Vector3.UP * 0.1
	await get_tree().create_timer(0.5).timeout
	_aim(p, t.global_position + Vector3.UP * 0.3)
	await get_tree().create_timer(0.6).timeout
	await _shot("bag_loaded")
	# Down in the cellar, at the workbench.
	var home := Homestead.of(cid)
	var cellar := home.get_node_or_null("RootCellar") as RootCellar
	var bench := cellar.get_node("Room/Workbench") as CropWorkbench
	p.gun.hold_item(&"none")
	p.global_position = bench.global_position + bench.global_basis.x * 0.0 + (cellar.to_global(RootCellar.ROOM + Vector3(0.3, 0.1, 0.6)) - bench.global_position).normalized() * 1.9
	p.global_position.y = bench.global_position.y + 0.1
	p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.6).timeout
	_aim(p, bench.global_position + Vector3.UP * 0.7)
	await get_tree().create_timer(1.0).timeout
	print("[playtest] in cellar: %s" % p.in_cellar)
	await _shot("cellar")
	bench.local_interact(false)
	await _shot("bench_menu")
	bench.request_convert(&"corn", 5)
	await get_tree().create_timer(0.5).timeout
	print("[playtest] converted 5 corn: carry %s, corn sacks %d" % [str(p.carry.carried()), Economy.amount(cid, &"corn_load")])
	await _shot("bench_after")
	MenuScreen.instance.close()
	# The seed wheel on an empty farm plot, and one-button planting with corn in hand.
	var plot: CropPlot = null
	for n: Node in get_tree().get_nodes_in_group("crops"):
		var cp := n as CropPlot
		if cp != null and cp.cliff_id == cid and cp.growth.stage == CropGrowth.Stage.EMPTY:
			plot = cp
			break
	if plot != null:
		Economy.earn(cid, {CropPlot.seed_res(&"corn"): 5, CropPlot.seed_res(&"cotton"): 3})
		p.global_position = plot.global_position + Vector3(0, 0.2, 3.0)
		await get_tree().create_timer(0.6).timeout
		_aim(p, plot.global_position)
		await get_tree().create_timer(0.6).timeout
		CropWheel.open_for(CropPlot.SeedWheel.new(plot), &"interact")
		await _shot("seed_wheel")
		CropWheel.instance.close()
		p.gun.hold_item(&"corn")
		print("[playtest] held seed: %s, prompt: %s" % [plot.held_seed(), plot.interact_prompt().replace("
", " / ")])
		plot.local_interact(false)
		await get_tree().create_timer(0.6).timeout
		print("[playtest] plot after a one-button plant: %s" % (plot.crop_def.id if plot.crop_def != null else &"none"))
	get_tree().quit()
