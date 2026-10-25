extends Node
## Registers every input action in code, so project.godot stays readable and
## bindings live in one place.

const KEY_BINDINGS: Dictionary = {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"slide": [KEY_CTRL, KEY_C],
	"reload": [KEY_R],
	"interact": [KEY_E],
	"toggle_mouse": [KEY_ESCAPE],
	"debug_overlay": [KEY_F3],
	"ready_up": [KEY_G],
	"debug_skip_phase": [KEY_F6],
}

const MOUSE_BINDINGS: Dictionary = {
	"fire": [MOUSE_BUTTON_LEFT],
}


func _enter_tree() -> void:
	for action: String in KEY_BINDINGS:
		_ensure_action(action)
		for key: int in KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE_BINDINGS:
		_ensure_action(action)
		for button: int in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button as MouseButton
			InputMap.action_add_event(action, ev)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
