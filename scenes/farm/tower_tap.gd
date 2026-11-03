class_name TowerTap
extends StaticBody3D
## The spigot on a water tower (Waterworks): take your bucket out (8) and press
## E here to fill it from the tank. Its card shows the tank's level.

var tower: WaterTower


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_WORLD
	var mi := MeshInstance3D.new()
	mi.mesh = WaterworksBuilder.tap()
	mi.material_override = Materials.toon(0.02)
	add_child(mi)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.7, 0.45)
	col.shape = box
	col.position = Vector3(0, 0.1, 0.05)
	add_child(col)


func interact_prompt() -> String:
	if tower == null:
		return ""
	var level := "%d / %d water" % [int(tower.stored), int(Waterworks.TANK_MAX)]
	var title := "Water tower tap   %s" % level
	if Waterworks.tap_amount(tower.stored) <= 0:
		return "%s\nThe tank's dry: it fills while the generator runs" % title
	if not _holding_bucket():
		return "%s\nTake out your bucket (8) to fill it" % title
	return "%s\nE: fill your bucket (%d)" % [title, Waterworks.tap_amount(tower.stored)]


func local_interact(holding: bool) -> void:
	if holding or tower == null or not _holding_bucket():
		return
	if multiplayer.is_server():
		tower.draw(multiplayer.get_unique_id())
	else:
		_request_draw.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_draw() -> void:
	if multiplayer.is_server() and tower != null:
		tower.draw(multiplayer.get_remote_sender_id())


func _holding_bucket() -> bool:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority() and n is Player:
			var g := (n as Player).gun
			return g != null and g.holding == &"water"
	return false
