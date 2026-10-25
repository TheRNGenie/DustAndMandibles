class_name Homestead
extends StaticBody3D
## A player's base core. Breachers chew on it; GameState holds the actual HP so
## both players see both bars, and losing either Homestead loses the run.

var cliff_id: int = 0
var radius: float = 4.5
var _hit_cooldown := 0.0


func _ready() -> void:
	add_to_group("structures")
	add_to_group("homesteads")


func _process(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)


## Host: breacher damage.
func structure_damage(amount: float, _source: String) -> void:
	if not multiplayer.is_server():
		return
	GameState.damage_homestead(cliff_id, amount)
	if _hit_cooldown <= 0.0:
		_hit_cooldown = 0.6
		_hit_fx.rpc()


@rpc("authority", "call_local", "unreliable")
func _hit_fx() -> void:
	Audio.play_at(&"homestead_hit", global_position + Vector3.UP * 2.0)
