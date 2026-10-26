extends Node
## Registers every input action in code, so project.godot stays readable and
## bindings live in one place. Settings applies the player's remaps on top.

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
	"build_menu": [KEY_B],
	"demolish": [KEY_X],
	"cycle_option": [KEY_F],
	"drop_item": [KEY_Q],
	"field_guide": [KEY_J],
	"upgrade": [KEY_U],
	"pause_menu": [KEY_ESCAPE],
	"debug_overlay": [KEY_F3],
	"ready_up": [KEY_G],
	"debug_skip_phase": [KEY_F6],
	"debug_add_scrap": [KEY_F7],
	"debug_spawn_bug": [KEY_F8],
	"debug_god_mode": [KEY_F9],
	"debug_show_lanes": [KEY_F10],
	"select_1": [KEY_1],
	"select_2": [KEY_2],
	"select_3": [KEY_3],
	"select_4": [KEY_4],
	"select_5": [KEY_5],
	"select_6": [KEY_6],
	"select_7": [KEY_7],
	"select_8": [KEY_8],
	"select_9": [KEY_9],
	"select_10": [KEY_0],
}

const MOUSE_BINDINGS: Dictionary = {
	"fire": [MOUSE_BUTTON_LEFT],
	"alt_fire": [MOUSE_BUTTON_RIGHT],
	"next_item": [MOUSE_BUTTON_WHEEL_DOWN],
	"prev_item": [MOUSE_BUTTON_WHEEL_UP],
}


func _enter_tree() -> void:
	for action: String in KEY_BINDINGS:
		reset_action(action)
	for action: String in MOUSE_BINDINGS:
		reset_action(action)


## Restores an action's default bindings.
func reset_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for key: int in KEY_BINDINGS.get(action, []):
		var ev := InputEventKey.new()
		ev.physical_keycode = key as Key
		InputMap.action_add_event(action, ev)
	for button: int in MOUSE_BINDINGS.get(action, []):
		var mb := InputEventMouseButton.new()
		mb.button_index = button as MouseButton
		InputMap.action_add_event(action, mb)
