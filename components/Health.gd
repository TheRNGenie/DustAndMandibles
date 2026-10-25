class_name Health
extends Node
## Hit points for bugs, turrets and structures. Only the host changes `hp`;
## clients receive it through the owner's MultiplayerSynchronizer.

signal changed(hp: float, max_hp: float)
signal died(source: String, source_cliff: int)

@export var max_hp: float = 100.0
var hp: float = 100.0:
	set(value):
		hp = value
		changed.emit(hp, max_hp)
var dead := false


func setup(max_value: float) -> void:
	max_hp = max_value
	hp = max_value


## Host only. `source` names who did it (for the kill feed); `source_cliff` is their cliff or -1.
func take_damage(amount: float, source: String = "", source_cliff: int = -1) -> void:
	if dead or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		dead = true
		died.emit(source, source_cliff)


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(hp + amount, max_hp)


func fraction() -> float:
	return hp / maxf(max_hp, 0.001)
