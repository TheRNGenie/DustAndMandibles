class_name SceneFade
extends CanvasLayer
## Loading (Logan): whenever a button leads to something that has to load, the
## screen fades to black quickly, the work happens behind the black, and the
## black fades away only once the new screen is ready and running smoothly, so
## a load never looks like the game froze.
##   go(path)     change scene (menu to world, world back to menu)
##   cover(work)  a load inside the current scene (`work` may await)
## The layer hangs off the tree's root, so it outlives the scene change.

const OUT_TIME := 0.18 ## to black
const IN_TIME := 0.35 ## black away again, once the new screen is ready
## Behind the black, wait for this many smooth frames in a row (the first
## frames of a new world build meshes and compile shaders, and hitch).
const SMOOTH_FRAMES := 4
const SMOOTH_DT := 0.05
const MAX_SETTLE := 2.5 ## never wait longer than this for the frames to settle
const MAX_READY := 12.0 ## nor this for a scene that says it's still loading

const NOTE_AFTER := 0.8 ## a black screen this long says what it's waiting on

static var _active: SceneFade

var _rect: ColorRect
var _note: Label
var _note_text := "Loading"
var _black_since := -1
var _is_cover := false


## Fade to black, then change to `path`. The old scene stops moving under the
## black. A second change while one runs is ignored.
static func go(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if busy():
		if not _active._is_cover:
			return
		_active.queue_free() # a scene change beats a load inside the old scene
		_active = null
	if DisplayServer.get_name() == "headless":
		tree.change_scene_to_file.call_deferred(path) # nothing to see: no wait
		return
	var f := SceneFade.new()
	_active = f
	tree.root.add_child.call_deferred(f)
	f._run.call_deferred(path)


## Fade to black, run `work` (it may await), then fade back in once the frames
## are smooth again. Ignored (work runs at once) while another fade is running.
static func cover(work: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or busy() or DisplayServer.get_name() == "headless":
		await work.call()
		return
	var f := SceneFade.new()
	f._is_cover = true
	_active = f
	tree.root.add_child(f)
	await f._run_cover(work)


## The game's first screen: starts black and fades in once it runs smoothly
## (its first frames build the menu and hitch). Ignored mid-fade.
static func reveal() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or busy() or DisplayServer.get_name() == "headless":
		return
	var f := SceneFade.new()
	f._rect.color.a = 1.0
	_active = f
	tree.root.add_child.call_deferred(f)
	f._run_reveal.call_deferred()


## True while the screen is fading or black.
static func busy() -> bool:
	return _active != null and is_instance_valid(_active)


func _init() -> void:
	layer = 128 # over every menu, card and HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP # no clicks mid-fade
	add_child(_rect)
	# A long wait gets a small line in the corner with dots that keep moving, so
	# it never looks stuck.
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", UiStyle.ts(20))
	_note.add_theme_color_override("font_color", Color(0.93, 0.87, 0.76, 0.85))
	_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_note.offset_left = -40 # hugs its text, growing leftward
	_note.offset_top = -72
	_note.offset_right = -40
	_note.offset_bottom = -32
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var plate := StyleBoxFlat.new() # on its own small card (no loose text)
	plate.bg_color = Color(UiStyle.c("hud_bg"), 0.9)
	plate.border_color = UiStyle.c("hud_rim")
	plate.border_width_left = 3
	plate.set_corner_radius_all(3)
	plate.content_margin_left = 12
	plate.content_margin_right = 12
	plate.content_margin_top = 3
	plate.content_margin_bottom = 3
	_note.add_theme_stylebox_override("normal", plate)
	_note.size_flags_horizontal = Control.SIZE_SHRINK_END
	_note.visible = false
	add_child(_note)


func _process(_delta: float) -> void:
	if _black_since < 0 or Time.get_ticks_msec() - _black_since < NOTE_AFTER * 1000.0:
		_note.visible = false
		return
	var scene := get_tree().current_scene
	if not _is_cover and is_instance_valid(scene) and scene.has_method("load_note"):
		_note_text = str(scene.call("load_note"))
	_note.visible = true
	_note.text = _note_text + ".".repeat(1 + (Time.get_ticks_msec() / 400) % 3)


func _run(path: String) -> void:
	var old := get_tree().current_scene
	if old != null:
		old.process_mode = Node.PROCESS_MODE_DISABLED # nothing runs on in a scene being left
	await _to_black()
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await _wait_ready(get_tree().current_scene)
	await _from_black()


func _run_reveal() -> void:
	_black_since = Time.get_ticks_msec()
	await _wait_ready(get_tree().current_scene)
	await _from_black()


func _run_cover(work: Callable) -> void:
	await _to_black()
	await work.call()
	await _wait_ready(null)
	await _from_black()


func _to_black() -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, OUT_TIME)
	await tw.finished
	_black_since = Time.get_ticks_msec()
	await get_tree().process_frame # one full black frame before the load hitch


## Stays black while `scene` says it's still loading (load_finished()), then
## until the frames run smoothly.
func _wait_ready(scene: Node) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(scene) and scene.has_method("load_finished") and not scene.call("load_finished") \
			and Time.get_ticks_msec() - t0 < MAX_READY * 1000.0:
		await get_tree().process_frame
	t0 = Time.get_ticks_msec()
	var smooth := 0
	var last := Time.get_ticks_usec()
	while smooth < SMOOTH_FRAMES and Time.get_ticks_msec() - t0 < MAX_SETTLE * 1000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		smooth = smooth + 1 if (now - last) / 1000000.0 < SMOOTH_DT else 0
		last = now


func _from_black() -> void:
	_black_since = -1
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := create_tween()
	back.tween_property(_rect, "color:a", 0.0, IN_TIME)
	await back.finished
	if _active == self:
		_active = null
	queue_free()
