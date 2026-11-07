class_name CellarStairs
extends StaticBody3D
## The foot of the root cellar's stairs (RootCellar): E climbs back out beside the doors.

var cellar: RootCellar


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.4, 1.4)
	col.shape = box
	col.position = Vector3(0, 1.4, 0.2)
	add_child(col)


func interact_prompt() -> String:
	return "Stairs\nE: climb out"


func local_interact(holding: bool) -> void:
	if holding or cellar == null:
		return
	Audio.play_at(&"chest_open", global_position, -3.0)
	var away := cellar.top() - cellar.global_position
	cellar.move_player(cellar.top(), atan2(-away.x, -away.z))
