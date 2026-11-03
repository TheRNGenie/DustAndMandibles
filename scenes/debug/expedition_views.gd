extends Node
## Debug views for Canyon Expeditions (with --shot=<png> --seconds=N):
##   --expview=ride      riding the rope winch down (starts at once)
##   --expview=rideup    standing on the floor, riding back up
##   --expview=floor     on the canyon floor at the rope's foot, looking up the wall
##   --expview=hud       on the floor with a loaded backpack (the HUD card)
##   --expview=sack      a dropped sack on the floor in front of you
##   --expview=hunt      on the floor long enough that hunters come
##   --expview=down      (a client in a two-window test) go down and stay there
## --exppitch=deg / --expyaw=deg turn the view after placing you.

var world: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player: Player = null
	var until := Time.get_ticks_msec() + 20000
	while player == null and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		player = world.call("local_player") as Player
	if player == null:
		return
	for i in 30:
		await get_tree().process_frame
	var kind := GameState.flag_value("--expview")
	var anchor := RopeAnchor.of(player.cliff_id)
	if anchor == null:
		print("[exp] no rope anchor on cliff %d" % player.cliff_id)
		return
	var me := multiplayer.get_unique_id()
	print("[exp] anchor %d tip %s bottom %s" % [player.cliff_id, str(anchor.tip.snapped(Vector3.ONE * 0.1)), str(anchor.bottom.snapped(Vector3.ONE * 0.1))])
	match kind:
		"ride":
			player.global_position = anchor.top_stand
			await get_tree().physics_frame
			player.start_rope(anchor, true)
			_fill(me, {&"scrap": 6})
		"rideup":
			_to_floor(player, anchor)
			_fill(me, {&"scrap": 5, &"chitin": 3})
			await get_tree().create_timer(0.5).timeout
			player.start_rope(anchor, false)
		"lock":
			# Ready up, go down (the lever drops), try again from the floor (refused), come up, ready.
			GameState.toggle_ready()
			await get_tree().create_timer(0.5).timeout
			print("[exp] lock: ready up top -> votes %d countdown %.1f" % [GameState.skip_votes, GameState.ready_countdown])
			_to_floor(player, anchor)
			await get_tree().create_timer(1.0).timeout
			print("[exp] lock: went down -> votes %d countdown %.1f levers %s" % [GameState.skip_votes, GameState.ready_countdown, str(GameState.levers)])
			GameState.toggle_ready()
			await get_tree().create_timer(0.5).timeout
			print("[exp] lock: tried from the floor -> votes %d countdown %.1f" % [GameState.skip_votes, GameState.ready_countdown])
			player.respawn()
			await get_tree().create_timer(1.0).timeout
			GameState.toggle_ready()
			await get_tree().create_timer(0.5).timeout
			print("[exp] lock: back up and ready -> votes %d countdown %.1f" % [GameState.skip_votes, GameState.ready_countdown])
		"downed":
			_to_floor(player, anchor)
			_fill(me, {&"scrap": 8, &"chitin": 4})
			await get_tree().create_timer(1.5).timeout
			player.vitals.apply_damage(99999.0)
			player.rotation.y = atan2(-anchor.inward.x, -anchor.inward.z)
		"floor", "down":
			_to_floor(player, anchor)
			player.rotation.y = atan2(anchor.inward.x, anchor.inward.z)
			player.head.rotation.x = deg_to_rad(55.0)
		"hud":
			_to_floor(player, anchor)
			player.rotation.y = atan2(-anchor.inward.x, -anchor.inward.z) + 0.6
			_fill(me, {&"scrap": 9, &"chitin": 5, &"bone": 3, &"relic": 1})
		"sack":
			_to_floor(player, anchor)
			var fwd := -anchor.inward
			player.rotation.y = atan2(-fwd.x, -fwd.z) + PI
			player.head.rotation.x = deg_to_rad(-38.0)
			var at := player.global_position - player.global_basis.z * 3.0
			if multiplayer.is_server():
				Expedition.drop_sack(at, {&"scrap": 12, &"chitin": 4, &"bone": 2}, "Kettle")
		"hunt":
			_to_floor(player, anchor)
			player.rotation.y = atan2(-anchor.inward.x, -anchor.inward.z) + PI * 0.5
			await get_tree().create_timer(1.0).timeout
			if multiplayer.is_server():
				Expedition.set("_floor_secs", {me: ExpeditionRules.HUNT_AT + 1.0})
	if GameState.flag_value("--exppitch") != "":
		player.head.rotation.x = deg_to_rad(GameState.flag_value("--exppitch").to_float())
	if GameState.flag_value("--expyaw") != "":
		player.rotation.y += deg_to_rad(GameState.flag_value("--expyaw").to_float())
	var log_t := Timer.new()
	log_t.wait_time = 1.0
	log_t.autostart = true
	add_child(log_t)
	log_t.timeout.connect(func() -> void:
		print("[exp] t pos %s down %s trip %s pack %s floor %.1f bugs %d sacks %d levers %s" % [str(player.global_position.snapped(Vector3.ONE * 0.1)),
				str(Expedition.down.keys()), player.on_trip(), str(Expedition.local_pack()), Expedition.floor_time(me),
				Bug.floor_bugs.size(), Expedition.sack_count(), str(GameState.levers)])
		print("[exp] chitin %d scrap %d" % [Economy.amount(player.cliff_id, &"chitin"), Economy.team_scrap()]))


func _to_floor(player: Player, anchor: RopeAnchor) -> void:
	player.global_position = anchor.foot_stand
	player.velocity = Vector3.ZERO
	player.set("_trip", true)


func _fill(peer: int, items: Dictionary) -> void:
	if multiplayer.is_server():
		Expedition.add_to_backpack(peer, items)
