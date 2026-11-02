extends Node
## Debug helpers for the Rancher's Ledger (added by the Perks autoload when a
## flag below is given; never part of a normal game):
##   --perkdemo            a demo profile (Brands, unlocks, a 12-perk loadout), never saved
##   --perkshot=<png>      save a screenshot after --seconds (default 2) and quit (menus too)
##   --perkover=win|lose   end the run after --perkat seconds (default 3) on wave --perkwave
##                         (default 9) with --perksaves partner saves (default 6)
##   --perktest            solo run: check every start-of-run and cost perk, print PASS/FAIL, quit
## e.g. --debug --menu --perkdemo --ledger --perkshot=docs/screenshots/ledger.png

var _over_done := false
var _test_started := false


func _ready() -> void:
	var shot := GameState.flag_value("--perkshot")
	if shot != "":
		_shoot(shot)


func _process(_delta: float) -> void:
	var in_world := get_tree().current_scene != null and get_tree().current_scene.name == "World"
	if not in_world or GameState.phase == GameState.Phase.LOBBY:
		return
	if GameState.flag_value("--perkover") != "" and not _over_done and multiplayer.is_server():
		_over_done = true
		_end_run()
	if GameState.has_flag("--perktest") and not _test_started and multiplayer.is_server():
		_test_started = true
		_run_test()


func _shoot(path: String) -> void:
	var secs := GameState.flag_value("--seconds").to_float()
	await get_tree().create_timer(secs if secs > 0.0 else 2.0).timeout
	await RenderingServer.frame_post_draw
	var full := path if path.is_absolute_path() or path.begins_with("res://") else "res://" + path
	get_viewport().get_texture().get_image().save_png(full)
	print("[perks] saved ", full)
	get_tree().quit()


func _end_run() -> void:
	var at := GameState.flag_value("--perkat").to_float()
	await get_tree().create_timer(at if at > 0.0 else 3.0).timeout
	var won := GameState.flag_value("--perkover") == "win"
	var wave := int(GameState.flag_value("--perkwave")) if GameState.flag_value("--perkwave") != "" else 9
	GameState.wave = GameState.config().last_wave if won else wave
	Perks.set("_saves", int(GameState.flag_value("--perksaves")) if GameState.flag_value("--perksaves") != "" else 6)
	GameState.call("_finish", won, "You held the canyon for %d waves!" % GameState.wave if won
		else "The west Homestead fell on wave %d." % GameState.wave)


func _run_test() -> void:
	var cfg := GameState.config()
	await get_tree().create_timer(2.5).timeout
	var ok := 0
	var bad := 0
	var lo := Perks.loadout_of(multiplayer.get_unique_id())
	print("[perktest] loadout ", lo)
	var me := multiplayer.get_unique_id()
	var cid := 0
	var checks: Array = []
	var stash := roundi(PerkTable.amount_in(lo, &"scrap_stash"))
	checks.append(["Scrap Stash start scrap", Economy.amount(cid, &"scrap"), cfg.start_scrap + stash])
	checks.append(["Homestead Plot seeds", Economy.amount(cid, &"seed_corn"), 2 if lo.has(&"homestead_plot") else 0])
	var plots := 0
	var scaffolds := 0
	for n: Node in BuildManager.instance.get_children():
		if n is CropPlot and (n as CropPlot).cliff_id == cid:
			plots += 1
	for n: Node in BuildManager.instance.get_children():
		if n is ScaffoldNode and (n as ScaffoldNode).cliff_id == cid:
			scaffolds += 1
	checks.append(["Homestead Plot plots", plots, 1 if lo.has(&"homestead_plot") else 0])
	checks.append(["Old Scaffolds scaffolds", scaffolds, 2 if lo.has(&"old_scaffolds") else 0])
	checks.append(["Starting Iron rifle", GunShop.loadouts.get(me, {}).has(&"lever_rifle"), lo.has(&"starting_iron")])
	var hp_want := roundf(cfg.homestead_hp * PerkTable.amount_in(lo, &"stout_timbers")) + cfg.homestead_hp
	checks.append(["Stout Timbers house HP", GameState.homestead_max[cid], hp_want])
	var gat := Defs.cost_of(&"gatling_post")
	checks.append(["Barn Raising first turret", Perks.build_cost(me, &"gatling_post"), 0 if lo.has(&"barn_raising") else
		int(PerkTable.scale_cost({&"s": gat}, PerkTable.less(lo, &"bulk_lumber"))[&"s"])])
	# Build a turret: free with Barn Raising, then Bulk Lumber prices the next.
	var before := Economy.amount(cid, &"scrap")
	var cell := Vector2i(0, 12)
	BuildManager.instance.build(&"gatling_post", cid, cell)
	await get_tree().process_frame
	var t := BuildManager.instance.turret_at(cid, cell, 1)
	if t == null:
		t = BuildManager.instance.turret_at(cid, cell, 0)
	checks.append(["turret built", t != null, true])
	checks.append(["Barn Raising paid nothing", Economy.amount(cid, &"scrap"), before if lo.has(&"barn_raising") else before - Perks.build_cost(me, &"gatling_post")])
	checks.append(["Bulk Lumber second turret", Perks.build_cost(me, &"gatling_post"),
		int(PerkTable.scale_cost({&"s": gat}, PerkTable.less(lo, &"bulk_lumber"))[&"s"])])
	if t != null:
		checks.append(["Long Sights range x", snappedf(t.perk_range, 0.001), snappedf(PerkTable.more(lo, &"long_sights"), 0.001)])
		checks.append(["Well Oiled interval x", snappedf(t.perk_rate, 0.001), snappedf(PerkTable.less(lo, &"well_oiled"), 0.001)])
		checks.append(["Reinforced Frames HP", roundf(t.health.max_hp), roundf(t.def.hp_at(0) * PerkTable.more(lo, &"reinforced_frames"))])
	checks.append(["Chitin Smith upgrade 30", Perks.discount(me, &"chitin_smith", 30), roundi(30 * PerkTable.less(lo, &"chitin_smith"))])
	checks.append(["Green Thumb growth x", snappedf(Perks.cliff_more(cid, &"green_thumb"), 0.001), snappedf(PerkTable.more(lo, &"green_thumb"), 0.001)])
	checks.append(["Quick Hands reload x", snappedf(Perks.local_less(&"quick_hands"), 0.001), snappedf(PerkTable.less(lo, &"quick_hands"), 0.001)])
	var pl: Player = null
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority():
			pl = n as Player
	if pl != null:
		pl.gun.equip(&"revolver")
		checks.append(["Bandolier revolver mag", pl.gun.mag_size(), 6 + PerkTable.bandolier_bonus(6, int(lo.get(&"bandolier", 0)))])
		var hp0 := pl.vitals.hp
		pl.vitals.apply_damage(20.0)
		checks.append(["Tough Hide damage", snappedf(hp0 - pl.vitals.hp, 0.01), snappedf(20.0 * PerkTable.less(lo, &"tough_hide"), 0.01)])
	var house := Homestead.UPGRADES[1]["cost"] as Dictionary
	checks.append(["Carpenter board-up price", Perks.discount_cost(me, &"carpenter", house), PerkTable.scale_cost(house, PerkTable.less(lo, &"carpenter"))])
	for c: Array in checks:
		var pass_: bool = c[1] == c[2]
		print("[perktest] %s  %s: got %s, want %s" % ["PASS" if pass_ else "FAIL", c[0], str(c[1]), str(c[2])])
		if pass_:
			ok += 1
		else:
			bad += 1
	print("[perktest] %d passed, %d failed" % [ok, bad])
	get_tree().quit(1 if bad > 0 else 0)
