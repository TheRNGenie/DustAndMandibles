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
	"demolish": "Sell",
	"upgrade": "Upgrade turret (chitin)",
	"tier_up": "Step a turret up a tier (scrap)",
	"cycle_option": "Change seed / shop item",
	"drop_item": "Drop weapon",
	"field_guide": "Field Guide (wiki)",
	"smoke": "Smoke a cigarette",
	"throw_rock": "Throw a rock",
	"melee": "Quick melee (whip)",
	"ready_up": "Throw your generator lever (ready up)",
	"ping": "Ping (hold for the ping wheel)",
	"overview_map": "Canyon map",
	"emote": "Emote (tap: tip hat, hold: wheel)",
	"photo_mode": "Photo mode (hide HUD, free camera)",
	"build_camera": "Build mode: first / third person camera",
	"debug_overlay": "Debug overlay",
}

# Controls
var mouse_sensitivity: float = 0.0022
var invert_y: bool = false
## Build mode's camera: false = first person, true = third person behind your
## rider. Remembered: toggling it in build mode (Tab) changes this too.
var build_cam_third: bool = false
## The grapple's right-click swing: false = hold to swing (let go to drop off),
## true = click to hook on, click again to let go.
var grapple_swing_toggle: bool = false
## Hold to Crouch: holding Slide as you land from the air drops you straight
## into a slide (if you're moving fast enough to slide at all).
var hold_crouch: bool = true
# Graphics
var fov: float = 85.0
var brightness: float = 1.0
var fps_cap: int = 0
var vsync: bool = true
var fullscreen: bool = false
var shadows: bool = true
var msaa: int = 1 # 0 off, 1 = 2x, 2 = 4x, 3 = 8x
var render_scale: float = 1.0
## "low" / "medium" / "high" (GraphicsQuality.PRESET_VALUES) or "custom";
## "" until the first launch picks one for the hardware.
var quality: String = ""
# Levels 0 Low, 1 Medium, 2 High (what they mean: GraphicsQuality).
var shadow_detail: int = GraphicsQuality.HIGH
var effects: int = GraphicsQuality.HIGH
var view_distance: int = GraphicsQuality.HIGH
var particles: int = GraphicsQuality.HIGH
var bug_detail: int = GraphicsQuality.HIGH
# Audio (linear 0..1)
var master_volume: float = 0.8
var sfx_volume: float = 1.0
var music_volume: float = 0.6
var bug_volume: float = 1.0
var weapon_volume: float = 1.0
var speech_volume: float = 1.0
# Accessibility: shape glyphs on team colours and alerts, not colour alone.
var colorblind: bool = false
## UI text size, 0.9 - 1.3 (UiStyle.ts applies it).
var ui_text_scale: float = 1.0
## The first-wave hint cards have been seen (never shown again).
var tutorial_done: bool = false
## Debug cheats (F6-F10, god mode) without the --debug launch flag.
var debug_mode: bool = false
## Host Game makes an online (Epic) lobby when that's available; false = a
## direct IP/LAN game (the way out if online play misbehaves).
var host_online: bool = true
## Your dummy's outfit (see DummyLook), as {slot: option}.
var look: Dictionary = DummyLook.default_look()
signal look_changed

## action -> Array of serialized events ("k:<physical keycode>" or "m:<mouse button>").
var _bindings: Dictionary = {}


## Values the command line overrides for this session only (key -> the saved
## value, which is what gets written back to the file).
var _session: Dictionary = {}


func _ready() -> void:
	load_settings()
	if quality == "":
		# First launch: pick a preset for this machine.
		# (On the OpenGL renderer - Safe Mode, or no Vulkan / D3D12 - it's an old GPU.)
		var preset := "low" if is_compatibility() else GraphicsQuality.auto_preset(_device_type(), RenderingServer.get_video_adapter_name())
		_set_preset_values(preset)
		print("[settings] first launch on '%s': %s graphics" % [RenderingServer.get_video_adapter_name(), preset])
		save_settings()
	_session_overrides()
	apply()


## Command-line overrides, never saved: --quality=low|medium|high, --safe (Low
## graphics; the Safe Mode shortcut also starts the OpenGL renderer),
## --windowed, --novsync (also uncaps the frame rate).
func _session_overrides() -> void:
	var args := OS.get_cmdline_user_args()
	var want := ""
	for a: String in args:
		if a.begins_with("--quality="):
			want = a.get_slice("=", 1).to_lower()
	if args.has("--safe") or args.has("--low"):
		want = "low"
	if GraphicsQuality.PRESETS.has(want):
		var values: Dictionary = GraphicsQuality.PRESET_VALUES[want]
		for key: String in values:
			_override(key, values[key])
		_override("quality", want)
	if args.has("--windowed") or args.has("--safe"):
		_override("fullscreen", false)
	if args.has("--swingtoggle"): # test the grapple's toggle swing without saving it
		_override("grapple_swing_toggle", true)
	if args.has("--novsync"):
		_override("vsync", false)
		_override("fps_cap", 0)


func _override(key: String, value: Variant) -> void:
	if not _session.has(key):
		_session[key] = get(key)
	set(key, value)


static func _device_type() -> int:
	var rd := RenderingServer.get_rendering_device()
	if rd != null:
		return rd.get_device_type()
	return RenderingDevice.DEVICE_TYPE_OTHER


## True on the OpenGL (Compatibility) renderer: Safe Mode, or the automatic
## fallback on GPUs without Vulkan / Direct3D 12.
static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


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
	# Below full resolution, AMD FSR upscales (sharper than plain stretching); the
	# OpenGL renderer only has bilinear.
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 and not is_compatibility() else Viewport.SCALING_3D_MODE_BILINEAR
	vp.mesh_lod_threshold = GraphicsQuality.LOD_THRESHOLD[GraphicsQuality.level(view_distance)]
	var sd := GraphicsQuality.level(shadow_detail)
	RenderingServer.directional_shadow_atlas_set_size(GraphicsQuality.SHADOW_ATLAS[sd], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(GraphicsQuality.SHADOW_FILTER[sd] as RenderingServer.ShadowQuality)
	BugManager.set_detail_level(GraphicsQuality.level(bug_detail))
	Materials.set_terrain_detail(GraphicsQuality.level(effects)) # the rock shader's painted detail
	InfestProps.set_detail(GraphicsQuality.level(effects)) # how many infestation props
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("Bugs", bug_volume)
	_set_bus_volume("Weapons", weapon_volume)
	_set_bus_volume("Voice", speech_volume)
	changed.emit()


func _set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


## Sets a setting by name, applies and saves it.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	_session.erase(key)
	if GraphicsQuality.PRESET_KEYS.has(key):
		quality = GraphicsQuality.matching_preset(_preset_values())
		_session.erase("quality")
	apply()
	save_settings()


## Picks a graphics preset ("low", "medium", "high"), applies and saves it.
func set_quality(preset: String) -> void:
	if not GraphicsQuality.PRESETS.has(preset):
		return
	_set_preset_values(preset)
	for key: String in GraphicsQuality.PRESET_KEYS:
		_session.erase(key)
	_session.erase("quality")
	apply()
	save_settings()


func _set_preset_values(preset: String) -> void:
	var values: Dictionary = GraphicsQuality.PRESET_VALUES[preset]
	for key: String in values:
		set(key, values[key])
	quality = preset


func _preset_values() -> Dictionary:
	var d := {}
	for key: String in GraphicsQuality.PRESET_KEYS:
		d[key] = get(key)
	return d


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
	"vsync", "fullscreen", "shadows", "msaa", "render_scale", "quality", "shadow_detail", "effects",
	"view_distance", "particles", "bug_detail", "master_volume", "sfx_volume", "music_volume", "bug_volume", "weapon_volume", "speech_volume", "debug_mode",
	"colorblind", "ui_text_scale", "tutorial_done", "host_online", "build_cam_third", "grapple_swing_toggle", "hold_crouch"]


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in SAVED_KEYS:
		cfg.set_value("settings", key, _session[key] if _session.has(key) else get(key))
	for action: String in _bindings:
		cfg.set_value("bindings", action, _bindings[action])
	cfg.set_value("look", "outfit", JSON.stringify(look))
	cfg.save(PATH)


func set_look(slot: String, option: String) -> void:
	look[slot] = option
	look = DummyLook.clean(look)
	save_settings()
	look_changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in SAVED_KEYS:
		if cfg.has_section_key("settings", key):
			set(key, cfg.get_value("settings", key))
	if not cfg.has_section_key("settings", "quality"):
		# Saved before quality presets: keep every setting as it was.
		quality = GraphicsQuality.matching_preset(_preset_values())
	if cfg.has_section_key("look", "outfit"):
		look = DummyLook.clean(JSON.parse_string(str(cfg.get_value("look", "outfit"))))
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
