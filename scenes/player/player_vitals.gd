class_name PlayerVitals
extends Node
## The local player's health, downed state and "use" key. Health lives on the
## owning peer; the host sends damage to it with an RPC. At 0 HP you're downed for
## 15 s, then respawn at your Homestead: nobody sits out a whole wave.

signal health_changed(hp: float, max_hp: float)
signal downed_changed(downed: bool, seconds: float)
signal prompt_changed(text: String)

const MAX_HP := 100.0
const DOWNED_TIME := 15.0
const REGEN_DELAY := 5.0
const REGEN_PER_SEC := 4.0
const INTERACT_REACH := 3.5
const HOLD_REPEAT := 0.35

var hp := MAX_HP
var downed := false
var _downed_left := 0.0
var _since_hit := 99.0
var _hold := 0.0
var _prompt := ""

@onready var player: Player = get_parent() as Player


func _process(delta: float) -> void:
	if not player.is_multiplayer_authority():
		return
	if downed:
		_downed_left -= delta
		downed_changed.emit(true, _downed_left)
		if _downed_left <= 0.0:
			downed = false
			hp = MAX_HP
			player.respawn()
			downed_changed.emit(false, 0.0)
			health_changed.emit(hp, MAX_HP)
		return
	_since_hit += delta
	if _since_hit > REGEN_DELAY and hp < MAX_HP:
		hp = minf(hp + REGEN_PER_SEC * delta, MAX_HP)
		health_changed.emit(hp, MAX_HP)
	_update_interact(delta)


## Runs on the owning peer.
func apply_damage(amount: float) -> void:
	if downed or (GameState.god_mode and GameState.has_flag("--debug")):
		return
	hp = maxf(hp - amount, 0.0)
	_since_hit = 0.0
	health_changed.emit(hp, MAX_HP)
	if hp <= 0.0:
		downed = true
		_downed_left = DOWNED_TIME
		downed_changed.emit(true, _downed_left)


func _update_interact(delta: float) -> void:
	var target := _look_target()
	var text := ""
	if target != null and target.has_method("interact_prompt"):
		text = str(target.call("interact_prompt"))
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
	if target == null or GameState.menu_open:
		_hold = 0.0
		return
	if Input.is_action_just_pressed("interact"):
		_hold = HOLD_REPEAT
		target.call("local_interact", false)
	elif Input.is_action_pressed("interact"):
		_hold -= delta
		if _hold <= 0.0:
			_hold = HOLD_REPEAT
			target.call("local_interact", true)


func _look_target() -> Object:
	var cam := player.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * INTERACT_REACH,
			WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var c: Object = hit["collider"]
	return c if c != null and c.has_method("local_interact") else null
