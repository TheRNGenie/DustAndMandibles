class_name PilotInput
extends RefCounted
## What a bot rider (the Hyper CPU) presses this physics tick: the stand-in for
## the keyboard and mouse that Player and Grapple read through in_vec/in_held/
## in_just. A press counts as "just pressed" on the tick it went down only, as
## with Input.

## Move keys, as Input.get_vector("move_left", "move_right", "move_forward", "move_back").
var move := Vector2.ZERO
var _held: Dictionary = {}
var _down: Dictionary = {}


## Player calls this before the pilot's tick: last tick's presses are no longer new.
func begin_tick() -> void:
	_down.clear()


func hold(action: StringName, on: bool = true) -> void:
	if on and not _held.has(action):
		_down[action] = true
	if on:
		_held[action] = true
	else:
		_held.erase(action)


## A tap: down this tick (it stays held until released).
func press(action: StringName) -> void:
	_held.erase(action)
	hold(action)


func release(action: StringName) -> void:
	_held.erase(action)


func release_all() -> void:
	_held.clear()
	_down.clear()
	move = Vector2.ZERO


func held(action: StringName) -> bool:
	return _held.has(action)


func just(action: StringName) -> bool:
	return _down.has(action)
