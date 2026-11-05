class_name WorldPreload
extends RefCounted
## Loads the game world's scene (its scripts, the player scene) and its heavy art
## (the AI models and their textures: airship, deck props, rigged riders and
## guns, the sky) on background threads while the lobby is up, so starting the
## game doesn't wait on the disk and the script compiler. The world then finds
## them already loaded (load() of a path being loaded waits for that load).
## Nothing here changes what is built: only when the files are read.
## Held until the world has used them (release()), then left to the scene.

const SCENES: Array[String] = ["res://scenes/world.tscn", "res://scenes/player/player.tscn"]
## Folders whose models and pictures every game uses (not recursive).
const DIRS: Array[String] = ["res://assets/airship", "res://assets/airship/deck", "res://assets/deck",
	"res://assets/rigged/guns", "res://assets/sky", "res://assets/train", "res://assets/icons"]
## Story chapters also bring these.
const STORY_DIRS: Array[String] = ["res://assets/story", "res://assets/portraits"]
const FILES: Array[String] = ["res://assets/paper/paper.jpg"]
const EXTS: Array[String] = ["glb", "png", "jpg", "tscn"]

static var _pending: PackedStringArray = []
static var _held: Dictionary = {}
static var _hooked := false


## Every path a game start would load (riders: all outfits and hats, since any
## rider in the posse may wear them).
static func paths(story: bool) -> PackedStringArray:
	var out: PackedStringArray = []
	out.append_array(SCENES)
	for d in DIRS + (STORY_DIRS if story else []):
		for f in ResourceLoader.list_directory(d):
			if not f.ends_with("/") and EXTS.has(f.get_extension()):
				out.append(d.path_join(f))
	for p: String in ModelBody.MODELS.values():
		out.append(p)
	for h: Array in ModelBody.HATS.values():
		out.append(str(h[0]))
	for p in FILES:
		out.append(p)
	return out


## Starts the background loads (again: only what isn't loaded or loading yet).
static func start(story: bool = false) -> void:
	if GameState.has_flag("--nopreload"):
		return
	var n := 0
	for p in paths(story):
		if _held.has(p) or _pending.has(p) or ResourceLoader.has_cached(p) or not ResourceLoader.exists(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_pending.append(p)
			n += 1
	if n > 0 and not _hooked:
		_hooked = true
		(Engine.get_main_loop() as SceneTree).process_frame.connect(_poll)
	if LoadTimes.on:
		print("[load] preload: %d files on background threads" % n)


## Collects finished loads (holding them, so they stay loaded until used).
static func _poll() -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var p := _pending[i]
		var status := ResourceLoader.load_threaded_get_status(p)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_held[p] = ResourceLoader.load_threaded_get(p)
		_pending.remove_at(i)
	if _pending.is_empty() and _hooked:
		_hooked = false
		(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_poll)
		if LoadTimes.on:
			print("[load] preload: done (%d held)" % _held.size())


## The world has what it needs: let go (whatever is still in use stays loaded).
static func release() -> void:
	_held.clear()


static func busy() -> bool:
	return not _pending.is_empty()
