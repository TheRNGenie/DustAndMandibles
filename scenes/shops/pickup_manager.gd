class_name PickupManager
extends Node3D
## Weapons lying on the ground (dropped with Q). The host spawns them and hands
## them to whoever presses E on them, if that player has a free weapon slot.

static var instance: PickupManager

var _spawner: MultiplayerSpawner
var _next_id := 0


func _ready() -> void:
	instance = self
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PickupSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(self)
	_spawner.spawn_function = _spawn_pickup


## Host only.
func spawn_weapon(id: StringName, level: int, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_next_id += 1
	_spawner.spawn({"id": _next_id, "weapon": id, "level": level, "pos": pos})


func _spawn_pickup(data: Variant) -> Node:
	var d := data as Dictionary
	var p := WeaponPickup.new()
	p.name = "Pickup%d" % int(d["id"])
	p.setup(StringName(d["weapon"]), int(d["level"]), d["pos"])
	return p


## Host: someone pressed E on a pickup.
func try_pick_up(peer_id: int, pickup: WeaponPickup) -> void:
	if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
		return
	if not GunShop.loadouts.has(peer_id):
		GunShop.loadouts[peer_id] = {&"revolver": 0}
	var owned: Dictionary = GunShop.loadouts[peer_id]
	if owned.has(pickup.weapon_id):
		Economy.notify(peer_id, "You already carry a %s." % Gun.weapon(pickup.weapon_id).display_name)
		return
	if owned.size() >= Gun.MAX_WEAPONS:
		Economy.notify(peer_id, "Your three weapon slots are full. Drop one first (Q).")
		return
	owned[pickup.weapon_id] = pickup.level
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id:
			(n as Player).net.grant_weapon(pickup.weapon_id, pickup.level)
	pickup.queue_free()
