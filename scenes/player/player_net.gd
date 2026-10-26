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
var sync_downed: bool

@onready var player: Player = get_parent() as Player

const SMOOTHING := 14.0


func _physics_process(delta: float) -> void:
	if player.is_multiplayer_authority():
		sync_pos = player.global_position
		sync_yaw = player.rotation.y
		sync_pitch = player.head.rotation.x
		sync_sliding = player.is_sliding()
		sync_downed = player.vitals.downed
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


## Host: damage this player (from a breacher). Health lives on the owning peer.
func server_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if player.is_multiplayer_authority():
		player.vitals.apply_damage(amount)
	else:
		_take_damage.rpc_id(player.get_multiplayer_authority(), amount)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _take_damage(amount: float) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		player.vitals.apply_damage(amount)


## Owner: ask the host to spend 1 food or water so you can eat or drink.
func request_consume(kind: StringName) -> void:
	if multiplayer.is_server():
		_consume(multiplayer.get_unique_id(), kind)
	else:
		_request_consume.rpc_id(1, kind)


@rpc("any_peer", "reliable")
func _request_consume(kind: StringName) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		_consume(multiplayer.get_remote_sender_id(), kind)


func _consume(peer_id: int, kind: StringName) -> void:
	var payer := Economy.payer_cliff(peer_id, player.cliff_id)
	if not Economy.spend(payer, {kind: 1}):
		Economy.notify(peer_id, "No %s left in your stockpile. Grow some!" % String(kind))
		return
	if peer_id == multiplayer.get_unique_id():
		player.vitals.consumed(kind)
	else:
		_consumed.rpc_id(peer_id, kind)


@rpc("any_peer", "reliable")
func _consumed(kind: StringName) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		player.vitals.consumed(kind)


## Host: hand a bought or upgraded weapon to this player's own Gun.
func grant_weapon(id: StringName, level: int) -> void:
	if player.is_multiplayer_authority():
		_apply_grant(id, level)
	else:
		_grant.rpc_id(player.get_multiplayer_authority(), id, level)


@rpc("any_peer", "reliable")
func _grant(id: StringName, level: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_apply_grant(id, level)


func _apply_grant(id: StringName, level: int) -> void:
	player.gun.grant(id, level)
	if level == 0:
		player.gun.equip(id)
		Economy.notice.emit("You bought the %s! It's on your hotbar." % Gun.weapon(id).display_name)
	else:
		Economy.notice.emit("%s upgraded to level %d." % [Gun.weapon(id).display_name, level])


## Owner: drop a weapon at your feet (anyone can pick it up again).
func drop_weapon(id: StringName) -> void:
	var level := player.gun.level_of(id)
	player.gun.remove_weapon(id)
	var pos := player.global_position + -player.global_transform.basis.z * 1.2 + Vector3.UP * 0.6
	if multiplayer.is_server():
		_host_drop(multiplayer.get_unique_id(), id, level, pos)
	else:
		_request_drop.rpc_id(1, id, level, pos)


@rpc("any_peer", "reliable")
func _request_drop(id: StringName, level: int, pos: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		_host_drop(multiplayer.get_remote_sender_id(), id, level, pos)


func _host_drop(peer_id: int, id: StringName, level: int, pos: Vector3) -> void:
	var owned: Dictionary = GunShop.loadouts.get(peer_id, {&"revolver": 0})
	if not owned.has(id):
		return
	owned.erase(id)
	GunShop.loadouts[peer_id] = owned
	PickupManager.instance.spawn_weapon(id, level, pos)


## Called by the owning peer after the gun fired.
func fire(origin: Vector3, dir: Vector3) -> void:
	var gun := player.gun
	var id := gun.def.id
	var level := gun.level_of(id)
	var seed_value := randi() & ~1
	if gun.aim > 0.6:
		seed_value |= 1 # aimed shots spread less (see Gun.shot_dirs)
	var dmg := Gun.damage_for(id, level)
	for d in Gun.shot_dirs(id, dir, seed_value):
		var hit := gun.raycast(origin, d, [player.get_rid()], gun.def.range)
		gun.show_impact(hit, d, true, dmg) # client-side prediction
	if multiplayer.is_server():
		_server_fire(origin, dir, id, level, seed_value)
	else:
		_request_fire.rpc_id(1, origin, dir, id, level, seed_value)


@rpc("any_peer", "call_remote", "reliable")
func _request_fire(origin: Vector3, dir: Vector3, id: StringName, level: int, seed_value: int) -> void:
	if not multiplayer.is_server() or Gun.weapon(id) == null:
		return
	if multiplayer.get_remote_sender_id() != player.get_multiplayer_authority():
		return
	if GameState.has_flag("--netlog"):
		print("[host] confirmed %s shot from peer %d" % [String(id), multiplayer.get_remote_sender_id()])
	_show_remote_shot(origin, dir, id, seed_value)
	_server_fire(origin, dir, id, clampi(level, 0, 2), seed_value)


## Host: applies damage for every pellet, then tells every other peer to draw the shot.
func _server_fire(origin: Vector3, dir: Vector3, id: StringName, level: int, seed_value: int) -> void:
	var def := Gun.weapon(id)
	var dmg := Gun.damage_for(id, level)
	for d in Gun.shot_dirs(id, dir.normalized(), seed_value):
		var hit := player.gun.raycast(origin, d, [player.get_rid()], def.range)
		Gun.apply_hit_result(hit, d, dmg, def.pierce_armor, player.display_name(), player.cliff_id)
	_fire_fx.rpc(origin, dir, id, seed_value)


@rpc("any_peer", "call_remote", "reliable")
func _fire_fx(origin: Vector3, dir: Vector3, id: StringName, seed_value: int) -> void:
	if multiplayer.get_remote_sender_id() != 1 or player.is_multiplayer_authority():
		return # only the host sends this, and the shooter already predicted it
	_show_remote_shot(origin, dir, id, seed_value)


func _show_remote_shot(origin: Vector3, dir: Vector3, id: StringName, seed_value: int) -> void:
	var def := Gun.weapon(id)
	Audio.play_at(def.sound, player.global_position + Vector3.UP * 1.4, -4.0)
	var muzzle := player.global_position + Vector3.UP * 1.3 + player.global_transform.basis.x * 0.3
	for d in Gun.shot_dirs(id, dir.normalized(), seed_value):
		var hit := player.gun.raycast(origin, d, [player.get_rid()], def.range)
		player.gun.show_impact(hit, d)
		var end: Vector3 = hit["position"] if not hit.is_empty() else origin + d * def.range
		if player.gun.vfx != null:
			player.gun.vfx.tracer(muzzle, end)
	player.flash_body()
