class_name PlayerVitals
extends Node
## The local player's health, downed state and "use" key. Health lives on the
## owning peer; the host sends damage to it with an RPC. At 0 HP you're downed for
## 15 s, then respawn at your Homestead: nobody sits out a whole wave.

signal health_changed(hp: float, max_hp: float)
signal downed_changed(downed: bool, seconds: float)
signal prompt_changed(text: String)
signal needs_changed(hunger: float, thirst: float)

const MAX_HP := 100.0
const DOWNED_TIME := 15.0
const REGEN_DELAY := 5.0
const REGEN_PER_SEC := 4.0
const INTERACT_REACH := 3.5
const HOLD_REPEAT := 0.35
## Hunger and thirst drain slowly: a full bar lasts about two wave cycles.
const NEED_MAX := 100.0
const NEED_DRAIN := 0.2 # per second
const NEED_LOW := 20.0
const EAT_AMOUNT := 35.0
const DRINK_AMOUNT := 35.0

var hp := MAX_HP
var downed := false
var _downed_left := 0.0
var _since_hit := 99.0
var _hold := 0.0
var _prompt := ""
var hunger := NEED_MAX
var thirst := NEED_MAX

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
		# Eating well doubles regeneration.
		var regen := REGEN_PER_SEC * (2.0 if hunger > 70.0 else 1.0)
		hp = minf(hp + regen * delta, MAX_HP)
		health_changed.emit(hp, MAX_HP)
	_update_needs(delta)
	_update_interact(delta)


func _update_needs(delta: float) -> void:
	if GameState.phase == GameState.Phase.LOBBY or GameState.phase == GameState.Phase.GAME_OVER:
		return
	var drain := NEED_DRAIN * delta * GameState.growth_scale()
	hunger = maxf(hunger - drain, 0.0)
	thirst = maxf(thirst - drain, 0.0)
	needs_changed.emit(hunger, thirst)
	if GameState.menu_open:
		return
	if Input.is_action_just_pressed("eat") and hunger < NEED_MAX - 5.0:
		player.net.request_consume(&"food")
	if Input.is_action_just_pressed("drink") and thirst < NEED_MAX - 5.0:
		player.net.request_consume(&"water")


## Low hunger disables sprint.
func can_sprint() -> bool:
	return hunger > NEED_LOW


## Low thirst makes reloading slower.
func reload_multiplier() -> float:
	return 1.6 if thirst <= NEED_LOW else 1.0


## Owner: the host approved eating or drinking.
func consumed(kind: StringName) -> void:
	if kind == &"food":
		hunger = minf(hunger + EAT_AMOUNT, NEED_MAX)
	else:
		thirst = minf(thirst + DRINK_AMOUNT, NEED_MAX)
	needs_changed.emit(hunger, thirst)
	Audio.play_ui(&"coin", -8.0)


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
			WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE | WorldLayout.LAYER_TRAP)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var c: Object = hit["collider"]
	return c if c != null and c.has_method("local_interact") else null
