class_name ZipDeployer
extends Node
## Deployable ziplines on the player (ZipRules, DeployZip). The owner presses
## Deploy Zipline (L) to fire an anchor where they aim; the host spends one
## Zipline Anchor and strings the rope on every peer. E within reach of any
## deployed rope grabs it and rides it the way you're facing.

const REACH := 2.4

var player: Player


func setup(p: Player) -> void:
	player = p


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_multiplayer_authority() or GameState.menu_open or player.is_downed():
		return
	if event.is_action_pressed("deploy_zip"):
		_fire()
	elif event.is_action_pressed("interact") and not player.is_ziplining():
		if _grab():
			get_viewport().set_input_as_handled()


func _fire() -> void:
	if Economy.amount(player.cliff_id, ZipRules.ITEM) <= 0:
		Economy.notice.emit("No zipline anchors. Make them at your Workshop (Gear tab).")
		return
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * ZipRules.RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		Economy.notice.emit("Nothing to bite into there (range %d m)." % int(ZipRules.RANGE))
		return
	var start := player.global_position + Vector3.UP * 2.3
	if multiplayer.is_server():
		_deploy(multiplayer.get_unique_id(), start, hit["position"])
	else:
		_request.rpc_id(1, start, hit["position"])


@rpc("any_peer", "reliable")
func _request(start: Vector3, end: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		_deploy(multiplayer.get_remote_sender_id(), start, end)


## Host: spend the anchor, snap the rider's oldest past the cap, string it everywhere.
func _deploy(peer: int, start: Vector3, end: Vector3) -> void:
	if start.distance_to(end) > ZipRules.RANGE + 4.0 or start.distance_to(player.global_position) > 6.0:
		return
	if not Economy.spend(player.cliff_id, {ZipRules.ITEM: 1}):
		return
	var mine := DeployZip.of_rider(get_tree(), peer)
	if mine.size() >= ZipRules.MAX_PER_RIDER:
		_snap.rpc(mine[0].name)
	_string.rpc(peer, start, end, "DeployZip_%d_%d" % [peer, Time.get_ticks_msec()])


@rpc("authority", "call_local", "reliable")
func _string(peer: int, start: Vector3, end: Vector3, node_name: String) -> void:
	var z := DeployZip.new()
	z.name = node_name
	z.rider = peer
	get_tree().current_scene.add_child(z)
	z.setup(start, end)


@rpc("authority", "call_local", "reliable")
func _snap(node_name: String) -> void:
	var z := get_tree().current_scene.get_node_or_null(NodePath(node_name))
	if z != null:
		z.queue_free()


## E near a rope: hang on and ride it the way you face (style combo action).
func _grab() -> bool:
	var hand := player.global_position + Vector3.UP * Player.ZIP_HANG
	var best: DeployZip = null
	var best_t := 0.0
	var best_d := REACH
	for n: Node in get_tree().get_nodes_in_group("deploy_zips"):
		var z := n as DeployZip
		if z == null or z.is_queued_for_deletion():
			continue
		var near := ZipRules.nearest(z.a, z.b, hand)
		if float(near[1]) < best_d:
			best = z
			best_d = float(near[1])
			best_t = float(near[0])
	if best == null:
		return false
	var toward_b := (-player.camera.global_basis.z).dot(best.b - best.a) >= 0.0
	player.start_zip(best, toward_b, Vector3.INF, best_t, ZipRules.RIDE_SPEED)
	player.combo.add()
	return true
