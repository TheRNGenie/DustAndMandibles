extends Node
## Player settings: controls, graphics, audio. Saved to user://settings.cfg and
## applied on start. Key bindings saved here override InputSetup's defaults.

signal changed

const PATH := "user://settings.cfg"
const FPS_CAPS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]
## Actions shown on the Controls tab, in display order, with friendly names.
const REMAPPABLE: Dictionary = {
	"move_forward": "Move forward",
	"move_back": "Move back",
	"move_left": "Move left",
	"move_right": "Move right",
	"jump": "Jump / mantle",
	"sprint": "Sprint",
	"slide": "Slide",
	"fire": "Fire",
	"alt_fire": "Aim / zoom (in build mode: close)",
	"reload": "Reload",
	"interact": "Interact / repair",
	"build_menu": "Build menu",
	"demolish": "Demolish",
	"upgrade": "Upgrade turret (chitin)",
	"cycle_option": "Change seed / shop item",
	"drop_item": "Drop weapon",
	"field_guide": "Field Guide (wiki)",
	"ready_up": "Ready (skip build phase)",
	"debug_overlay": "Debug overlay",
}

# Controls
var mouse_sensitivity: float = 0.0022
var invert_y: bool = false
# Graphics
var fov: float = 85.0
var brightness: float = 1.0
var fps_cap: int = 0
var vsync: bool = true
var fullscreen: bool = false
var shadows: bool = true
var msaa: int = 1 # 0 off, 1 = 2x, 2 = 4x, 3 = 8x
var render_scale: float = 1.0
# Audio (linear 0..1)
var master_volume: float = 0.8
var sfx_volume: float = 1.0
var music_volume: float = 0.6

## action -> Array of serialized events ("k:<physical keycode>" or "m:<mouse button>").
var _bindings: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply()


func apply() -> void:
	Engine.max_fps = fps_cap
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][clampi(msaa, 0, 3)] as Viewport.MSAA
	vp.scaling_3d_scale = render_scale
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("Music", music_volume)
	changed.emit()


func _set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


## Sets a setting by name, applies and saves it.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	apply()
	save_settings()


# ------------------------------------------------------------------ key remapping

func rebind(action: String, event: InputEvent) -> void:
	var data := _serialize(event)
	if data == "":
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_bindings[action] = [data]
	save_settings()
	changed.emit()


func reset_bindings() -> void:
	_bindings.clear()
	for action: String in REMAPPABLE:
		InputSetup.reset_action(action)
	save_settings()
	changed.emit()


## Human-readable label for an action's first binding.
func binding_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "(unbound)"
	return event_label(events[0])


static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var key := ev as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Left mouse"
			MOUSE_BUTTON_RIGHT:
				return "Right mouse"
			MOUSE_BUTTON_MIDDLE:
				return "Middle mouse"
			var b:
				return "Mouse %d" % b
	return "?"


func _serialize(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var key := ev as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "k:%d" % code
	if ev is InputEventMouseButton:
		return "m:%d" % (ev as InputEventMouseButton).button_index
	return ""


func _deserialize(data: String) -> InputEvent:
	var parts := data.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "k":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	if parts[0] == "m":
		var m := InputEventMouseButton.new()
		m.button_index = int(parts[1]) as MouseButton
		return m
	return null


# ------------------------------------------------------------------ persistence

const SAVED_KEYS: Array[String] = ["mouse_sensitivity", "invert_y", "fov", "brightness", "fps_cap",
	"vsync", "fullscreen", "shadows", "msaa", "render_scale", "master_volume", "sfx_volume", "music_volume"]


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in SAVED_KEYS:
		cfg.set_value("settings", key, get(key))
	for action: String in _bindings:
		cfg.set_value("bindings", action, _bindings[action])
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in SAVED_KEYS:
		if cfg.has_section_key("settings", key):
			set(key, cfg.get_value("settings", key))
	if cfg.has_section("bindings"):
		for action: String in cfg.get_section_keys("bindings"):
			if not InputMap.has_action(action):
				continue
			var list: Array = cfg.get_value("bindings", action, [])
			var events: Array[InputEvent] = []
			for data: Variant in list:
				var ev := _deserialize(str(data))
				if ev != null:
					events.append(ev)
			if events.is_empty():
				continue
			InputMap.action_erase_events(action)
			for ev in events:
				InputMap.action_add_event(action, ev)
			_bindings[action] = list
