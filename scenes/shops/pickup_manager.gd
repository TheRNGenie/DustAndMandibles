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


## Host only: one crop, medicine or bucket of water on the ground.
func spawn_item(item: StringName, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_next_id += 1
	_spawner.spawn({"id": _next_id, "item": item, "pos": pos})


func _spawn_pickup(data: Variant) -> Node:
	var d := data as Dictionary
	var p := WeaponPickup.new()
	p.name = "Pickup%d" % int(d["id"])
	if d.has("item"):
		p.setup_item(StringName(d["item"]), d["pos"])
	else:
		p.setup(StringName(d["weapon"]), int(d["level"]), d["pos"])
	return p


## Host: someone pressed E on a pickup.
func try_pick_up(peer_id: int, pickup: WeaponPickup) -> void:
	if not is_instance_valid(pickup) or pickup.is_queued_for_deletion():
		return
	if pickup.item_id != &"":
		# A dropped crop, medicine or water: back into the picker's stock.
		var cliff := 0
		for n: Node in get_tree().get_nodes_in_group("players"):
			if n.get_multiplayer_authority() == peer_id:
				cliff = (n as Player).cliff_id
		Economy.earn(cliff, {pickup.item_id: 1})
		pickup.queue_free()
		return
	if not GunShop.loadouts.has(peer_id):
		GunShop.loadouts[peer_id] = {&"revolver": 0}
	var owned: Dictionary = GunShop.loadouts[peer_id]
	if owned.has(pickup.weapon_id):
		Economy.notify(peer_id, "You already carry a %s." % Gun.weapon(pickup.weapon_id).display_name)
		return
	if Gun.slot_refusal(owned, pickup.weapon_id) != "": # Weapon Slots: one gun of each kind
		Economy.notify(peer_id, Gun.slot_refusal(owned, pickup.weapon_id))
		return
	owned[pickup.weapon_id] = pickup.level
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id:
			(n as Player).net.grant_weapon(pickup.weapon_id, pickup.level)
	pickup.queue_free()
