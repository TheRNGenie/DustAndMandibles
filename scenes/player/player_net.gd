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
## The gun in hand ("" when holding an item), so others see it in your fist.
var sync_weapon: StringName = &"revolver"
## Your outfit (DummyLook) as JSON, so the other player sees how you're dressed.
var sync_look: String = ""
var _applied_look := ""

@onready var player: Player = get_parent() as Player

const SMOOTHING := 14.0


func _physics_process(delta: float) -> void:
	if player.is_multiplayer_authority():
		sync_pos = player.global_position
		sync_yaw = player.rotation.y
		sync_pitch = player.head.rotation.x
		sync_sliding = player.is_sliding()
		sync_downed = player.vitals.downed
		var g := player.gun
		sync_weapon = g.def.id if (g.holding == &"" and g.def != null) else &""
		player.rig.set_weapon(sync_weapon)
		sync_look = JSON.stringify(Settings.look)
	else:
		player.rig.set_weapon(sync_weapon)
	if sync_look != _applied_look and sync_look != "":
		_applied_look = sync_look
		player.rig.apply_look(DummyLook.clean(JSON.parse_string(sync_look)))
		if player.is_multiplayer_authority():
			player.gun.refresh_arms(Settings.look)
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


# ------------------------------------------------------------------ rocks

const ROCK_GRAVITY := 18.0
const ROCK_LIFE := 3.0
static var _rock_mesh: ArrayMesh


## Owner: lob a rock. Everyone sees it fly; the thrower decides what it hits.
func throw_rock(origin: Vector3, vel: Vector3) -> void:
	_spawn_rock.rpc(origin, vel)


@rpc("any_peer", "call_local", "reliable")
func _spawn_rock(origin: Vector3, vel: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != player.get_multiplayer_authority() and multiplayer.get_remote_sender_id() != 0:
		return
	if _rock_mesh == null:
		_rock_mesh = PropBuilder.rock(4711, 0.14)
	var rock := Rock.new()
	rock.mesh = _rock_mesh
	rock.material_override = Materials.toon(0.01)
	rock.vel = vel
	rock.thrower = player
	rock.authoritative = player.is_multiplayer_authority()
	player.get_tree().current_scene.add_child(rock)
	rock.global_position = origin
	Audio.play_at(&"pluck", origin, -6.0)


@rpc("any_peer", "call_local", "reliable")
func _bonked(dir: Vector3, strength: float) -> void:
	player.bonk(dir, strength)
	Audio.play_at(&"armor_ping", player.global_position + Vector3.UP * 1.5, -2.0)


## A thrown rock: flies on a lob, tumbles, bonks the first player or bug it meets.
class Rock extends MeshInstance3D:
	var vel := Vector3.ZERO
	var thrower: Player
	var authoritative := false
	var _t := 0.0
	var _spin := Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t > ROCK_LIFE:
			queue_free()
			return
		var from := global_position
		vel.y -= ROCK_GRAVITY * delta
		var to := from + vel * delta
		rotation += _spin * delta
		var q := PhysicsRayQueryParameters3D.create(from, to, WorldLayout.LAYER_WORLD | WorldLayout.LAYER_BUG | WorldLayout.LAYER_STRUCTURE | 1)
		if is_instance_valid(thrower):
			q.exclude = [thrower.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		# Players are capsules on the default layer: check them by distance (cheap, two players).
		for n: Node in get_tree().get_nodes_in_group("players"):
			var p := n as Player
			if p == thrower:
				continue
			var c := p.global_position + Vector3.UP * 1.0
			if _seg_dist(from, to, c) < 0.6:
				if authoritative:
					p.net._bonked.rpc(vel.normalized(), 1.0)
				queue_free()
				return
		if not hit.is_empty():
			global_position = hit["position"]
			var col := hit["collider"] as Object
			if authoritative and col is Hitbox:
				# Bugs barely notice, but they do frown at you.
				var b := (col as Hitbox).get_parent()
				if b != null and b.has_node("Face"):
					(b.get_node("Face") as BugFace).wince()
			Audio.play_at(&"hit_tick", global_position, -8.0)
			queue_free()
			return
		global_position = to

	static func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		return (a + ab * t).distance_to(p)
