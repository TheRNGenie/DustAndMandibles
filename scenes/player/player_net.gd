class_name PlayerNet
extends Node
## Networking for one player: state replicated by the sibling MultiplayerSynchronizer
## (20 Hz, interpolated on the other peer) and host-confirmed shooting.
## Movement is owned by the player's own peer; hits are decided by the host.

## Replicated state, written by the owning peer.
var sync_pos: Vector3
var sync_yaw: float
var sync_pitch: float
var sync_sliding: bool

@onready var player: Player = get_parent() as Player

const SMOOTHING := 14.0


func _physics_process(delta: float) -> void:
	if player.is_multiplayer_authority():
		sync_pos = player.global_position
		sync_yaw = player.rotation.y
		sync_pitch = player.head.rotation.x
		sync_sliding = player.is_sliding()
	else:
		var k := 1.0 - exp(-SMOOTHING * delta)
		if player.global_position.distance_to(sync_pos) > 6.0:
			player.global_position = sync_pos # teleport (respawn, mantle)
		else:
			player.global_position = player.global_position.lerp(sync_pos, k)
		player.rotation.y = lerp_angle(player.rotation.y, sync_yaw, k)
		player.head.rotation.x = lerpf(player.head.rotation.x, sync_pitch, k)
		player.set_remote_pose(sync_sliding)


## Sets the initial replicated state so the other peer doesn't lerp from the origin.
func prime() -> void:
	sync_pos = player.global_position
	sync_yaw = player.rotation.y


## Called by the owning peer after the revolver fired.
func fire(origin: Vector3, dir: Vector3) -> void:
	var hit := player.revolver.raycast(origin, dir, [player.get_rid()])
	player.revolver.show_impact(hit, dir) # client-side prediction
	if multiplayer.is_server():
		_server_fire(origin, dir, hit)
	else:
		_request_fire.rpc_id(1, origin, dir)


@rpc("any_peer", "call_remote", "reliable")
func _request_fire(origin: Vector3, dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player.get_multiplayer_authority():
		return
	var hit := player.revolver.raycast(origin, dir.normalized(), [player.get_rid()])
	if GameState.has_flag("--netlog"):
		print("[host] confirmed shot from peer %d, hit: %s" % [multiplayer.get_remote_sender_id(),
				str((hit["collider"] as Node).name) if not hit.is_empty() else "nothing"])
	_show_remote_shot(origin, dir, hit)
	_server_fire(origin, dir, hit)


## Host: applies damage, then tells every other peer to draw the shot.
func _server_fire(origin: Vector3, dir: Vector3, hit: Dictionary) -> void:
	player.revolver.apply_hit_result(hit, dir)
	_fire_fx.rpc(origin, dir)


@rpc("any_peer", "call_remote", "reliable")
func _fire_fx(origin: Vector3, dir: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1 or player.is_multiplayer_authority():
		return # only the host sends this, and the shooter already predicted it
	var hit := player.revolver.raycast(origin, dir, [player.get_rid()])
	if GameState.has_flag("--netlog"):
		print("[peer %d] drew shot from player %s" % [multiplayer.get_unique_id(), player.name])
	_show_remote_shot(origin, dir, hit)


func _show_remote_shot(origin: Vector3, dir: Vector3, hit: Dictionary) -> void:
	player.revolver.show_impact(hit, dir)
	var end: Vector3 = hit["position"] if not hit.is_empty() else origin + dir * Revolver.RANGE
	var muzzle := player.global_position + Vector3.UP * 1.3 + player.global_transform.basis.x * 0.3
	if player.revolver.vfx != null:
		player.revolver.vfx.tracer(muzzle, end)
	player.flash_body()
