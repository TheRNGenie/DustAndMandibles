class_name SceneFade
extends CanvasLayer
## Loading (Logan): whenever a button leads to something that has to load, the
## screen fades to a themed loading screen (LoadingScreen: a wanted poster, a
## canyon vista, a field-guide page, the rider's brand plate or the Gazette,
## each with its own spinner) quickly, the work happens behind it, and it fades
## away only once the new screen is ready and running smoothly, so a load never
## looks like the game froze. A quick load inside the menus (cover) fades to
## black and only brings the brand plate up if it runs long.
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
## A scene change keeps its loading screen up at least this long (no flash of it).
const MIN_SHOW := 1.1
## A load inside the current scene shows the brand plate only once it's taken this long.
const COVER_CARD_AFTER := 0.5
const CARD_IN := 0.22

static var _active: SceneFade

var _rect: ColorRect
var _note: Label
var _note_text := "Loading"
var _black_since := -1
var _is_cover := false
## The themed screen over the black (null: plain black), and what's loading.
var _card: LoadingScreen
var _ctx: Dictionary = {}


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
	f._ctx = context(path)
	f._add_card(LoadingScreen.pick(f._ctx), 0.0)
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
	f._ctx = {"to": "first"}
	f._add_card(LoadingScreen.pick(f._ctx), 1.0)
	tree.root.add_child.call_deferred(f)
	f._run_reveal.call_deferred()


## What a change to `path` is loading, for the loading screen to dress for.
static func context(path: String) -> Dictionary:
	var ctx := {"to": "world" if path == NetworkManager.WORLD_SCENE else "menu"}
	ctx["map"] = MapDef.display_name_of(NetworkManager.map_id)
	ctx["endless"] = GameState.endless
	ctx["tutorial"] = GameState.tutorial
	ctx["wave"] = GameState.wave
	ctx["brand"] = Brand.local_id()
	var ch := Story.chapter() if Story.chapter_id != "" else null
	if ch != null and ctx["to"] == "world":
		ctx["chapter"] = ch.number
		ctx["chapter_title"] = ch.title
		ctx["map"] = MapDef.display_name_of(ch.map)
	return ctx


func _add_card(style: StringName, alpha: float) -> void:
	_card = LoadingScreen.make(style, _ctx)
	_card.modulate.a = alpha
	add_child(_card)
	move_child(_note, -1) # the waiting line stays on top


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
	_note.add_theme_font_size_override("font_size", UiStyle.ts(18))
	_note.add_theme_font_override("font", UiStyle.font("label"))
	_note.add_theme_color_override("font_color", Color(UiStyle.c("hud"), 0.9))
	_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_note.offset_left = 40 # hugs its text, growing rightward (the spinners sit bottom right)
	_note.offset_top = -72
	_note.offset_right = 40
	_note.offset_bottom = -32
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note.grow_horizontal = Control.GROW_DIRECTION_END
	var plate := UiStyle.box_for(UiStyle.current, "chip") # on its own small card (no loose text)
	plate.bar_side = 1
	plate.bar = UiStyle.c("accent_hi")
	plate.bar_width = 3.0
	plate.content_margin_left = 16
	plate.content_margin_right = 14
	plate.content_margin_top = 4
	plate.content_margin_bottom = 4
	_note.add_theme_stylebox_override("normal", plate)
	_note.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_note.visible = false
	add_child(_note)


func _process(_delta: float) -> void:
	# A cover that runs long brings the brand plate up over the black.
	if _is_cover and _card == null and _black_since >= 0 and Time.get_ticks_msec() - _black_since > COVER_CARD_AFTER * 1000.0:
		_ctx = {"to": "cover", "brand": Brand.local_id()}
		_add_card(LoadingScreen.pick(_ctx), 0.0)
		_card.progress = 0.4
		create_tween().tween_property(_card, "modulate:a", 1.0, CARD_IN)
	if _black_since < 0 or Time.get_ticks_msec() - _black_since < NOTE_AFTER * 1000.0:
		_note.visible = false
		return
	var scene := get_tree().current_scene
	if not _is_cover and is_instance_valid(scene) and scene.has_method("load_note"):
		_note_text = str(scene.call("load_note"))
	if _card != null:
		# The loading screen letters it beside its own spinner.
		_note.visible = false
		_card.note = _note_text
		return
	_note.visible = true
	_note.text = _note_text + ".".repeat(1 + (Time.get_ticks_msec() / 400) % 3)


func _run(path: String) -> void:
	var old := get_tree().current_scene
	if old != null:
		old.process_mode = Node.PROCESS_MODE_DISABLED # nothing runs on in a scene being left
	await _to_black()
	_set_progress(0.12)
	await get_tree().process_frame # the card shows its first step before the load hitch
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	_set_progress(0.55)
	await _wait_ready(get_tree().current_scene)
	# Never just a flash of the loading screen.
	while Time.get_ticks_msec() - _black_since < MIN_SHOW * 1000.0:
		await get_tree().process_frame
	await _from_black()


func _run_reveal() -> void:
	_black_since = Time.get_ticks_msec()
	_set_progress(0.4)
	await _wait_ready(get_tree().current_scene)
	while Time.get_ticks_msec() - _black_since < MIN_SHOW * 1000.0:
		await get_tree().process_frame
	await _from_black()


func _set_progress(p: float) -> void:
	if _card != null:
		_card.progress = maxf(_card.progress, p)


func _run_cover(work: Callable) -> void:
	await _to_black()
	await work.call()
	await _wait_ready(null)
	await _from_black()


func _to_black() -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, OUT_TIME)
	if _card != null:
		tw.parallel().tween_property(_card, "modulate:a", 1.0, OUT_TIME)
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
		# Creep on toward three quarters while it waits (never stuck).
		_set_progress(lerpf(0.55, 0.78, clampf((Time.get_ticks_msec() - t0) / 4000.0, 0.0, 1.0)))
	_set_progress(0.8)
	t0 = Time.get_ticks_msec()
	var smooth := 0
	var last := Time.get_ticks_usec()
	while smooth < SMOOTH_FRAMES and Time.get_ticks_msec() - t0 < MAX_SETTLE * 1000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		smooth = smooth + 1 if (now - last) / 1000000.0 < SMOOTH_DT else 0
		last = now
		_set_progress(0.8 + 0.15 * float(smooth) / SMOOTH_FRAMES)


func _from_black() -> void:
	# The spinner finishes its count first (a beat, at most).
	if _card != null:
		_card.progress = 1.0
		var t0 := Time.get_ticks_msec()
		while _card.shown < 0.99 and Time.get_ticks_msec() - t0 < 450:
			await get_tree().process_frame
	_black_since = -1
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := create_tween()
	back.tween_property(_rect, "color:a", 0.0, IN_TIME)
	if _card != null:
		back.parallel().tween_property(_card, "modulate:a", 0.0, IN_TIME)
	await back.finished
	if _active == self:
		_active = null
	queue_free()
