extends Node
## Tiers: a live check of the tier unlocks and the new turrets' specials.
## Started by DebugTools when --tiertest is given (host / solo):
##  1. on wave 1 a Hornet's Nest is refused (locked), a Gatling Post goes up;
##  2. on the run's wave (use --startwave=10) the five new turrets go up on the
##     player's cliff (the Gatling Porch Turret on the house), bugs climb the far
##     wall in packs and columns, a few breach onto the plateau;
##  3. after --tierseconds (default 25) it prints each turret's shots and the
##     ricochet / pierce / spike tallies (TurretEffects.special_stats), then quits
##     unless a --shot is pending.

var world: Node3D


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	for i in 40:
		await get_tree().physics_frame
	if not multiplayer.is_server():
		return
	var player := world.call("local_player") as Player
	var cid := player.cliff_id if player != null else WorldLayout.WEST
	var far := WorldLayout.other_cliff(cid)
	var bm := BuildManager.instance
	for c in WorldLayout.cliff_count():
		Economy.earn(c, {&"scrap": 4000})
	# 1. Locks are host-checked.
	var run_wave := GameState.wave
	GameState.wave = 1
	bm._do_build(1, &"hornets_nest", cid, Vector2i(0, 2))
	bm._do_build(1, &"gatling_post", cid, Vector2i(0, 16))
	for i in 10:
		await get_tree().physics_frame
	print("[tiers] wave 1: hornets_nest built=%s (want false), gatling_post built=%s (want true)" % [
			not bm.turrets_on(cid, Vector2i(0, 2)).is_empty(), not bm.turrets_on(cid, Vector2i(0, 16)).is_empty()])
	GameState.wave = run_wave
	# 2. The new turrets.
	var cols := {&"twin_gatling": 4, &"hornets_nest": 7, &"elephant_battery": 10, &"rail_spike_driver": 13}
	for id: StringName in cols:
		bm._do_build(1, id, cid, Vector2i(0, int(cols[id])))
	var home := Homestead.of(cid)
	if home != null:
		home._set_state.rpc(3, true, true)
		await get_tree().physics_frame
		bm._do_build(1, &"gatling_porch", cid, Vector2i(-1, 0))
	for i in 10:
		await get_tree().physics_frame
	for id: StringName in cols:
		print("[tiers] wave %d: %s built=%s" % [GameState.wave, id, not bm.turrets_on(cid, Vector2i(0, int(cols[id]))).is_empty()])
	TurretEffects.special_stats.clear()
	var bugs := world.get("bugs") as BugManager
	var lanes := WorldLayout.LANE_Z.size()
	for k in 3:
		for lane in lanes:
			bugs.spawn_group(&"dust_mite", 6, far, lane, 8.0 + k * 3.0)
			bugs.spawn_group(&"rattler_beetle", 3, far, lane, 6.0 + k * 4.0)
		await get_tree().create_timer(4.0).timeout
	# A few breach onto the player's own plateau for the porch Gatling.
	for lane in 2:
		bugs.spawn_group(&"wolf_spider", 3, cid, lane, WorldLayout.CLIFF_HEIGHT - 2.0)
	var secs := GameState.flag_value("--tierseconds").to_float() if GameState.flag_value("--tierseconds") != "" else 25.0
	await get_tree().create_timer(secs).timeout
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t != null:
			print("[tiers] cliff %d %s %s shots=%d hp=%.0f/%.0f" % [t.cliff_id, str(t.cell), t.def.id, t.shots, t.health.hp, t.health.max_hp])
	print("[tiers] specials: %s" % str(TurretEffects.special_stats))
	if GameState.flag_value("--shot") == "":
		get_tree().quit()
