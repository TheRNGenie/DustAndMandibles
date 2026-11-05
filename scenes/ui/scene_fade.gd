class_name SceneFade
extends CanvasLayer
## Loading into the game (Logan): the screen fades to black, the world scene
## loads behind the black, then the black fades away once the world is up.
## The layer hangs off the tree's root, so it outlives the scene change.

const OUT_TIME := 0.35 ## to black
const IN_TIME := 0.5 ## black away again, once the world is in

static var _active: SceneFade

var _rect: ColorRect


## Fade to black, then change to `path` (a second call while one runs is ignored).
static func go(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _active != null and is_instance_valid(_active):
		return
	if DisplayServer.get_name() == "headless":
		tree.change_scene_to_file.call_deferred(path) # nothing to see: no wait
		return
	var f := SceneFade.new()
	_active = f
	tree.root.add_child.call_deferred(f)
	f._run.call_deferred(path)


func _init() -> void:
	layer = 128 # over every menu, card and HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP # no clicks on the menu mid-fade
	add_child(_rect)


func _run(path: String) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, OUT_TIME)
	await tw.finished
	await get_tree().process_frame # one full black frame before the load hitch
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	# The new world's first frames build and hitch: stay black through them.
	for i in 3:
		await get_tree().process_frame
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := create_tween()
	back.tween_property(_rect, "color:a", 0.0, IN_TIME)
	await back.finished
	_active = null
	queue_free()
