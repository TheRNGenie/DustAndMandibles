class_name LoadTimes
extends RefCounted
## --loadtimes: timing log of the menu -> lobby -> world loads (debug aid).
## begin() starts a phase, mark() prints the time since the last mark and since
## the phase began; after each phase the first frames' lengths are logged too
## (a long frame there is a hitch the player sees: shader compiles, uploads).
## --loadtest drives it unattended: the menu hosts after a moment, the lobby
## starts the game, and the world quits a few seconds in.
## Off (the default) every call is one bool test.

static var on := "--loadtimes" in OS.get_cmdline_user_args() or "--loadtest" in OS.get_cmdline_user_args()
static var auto := "--loadtest" in OS.get_cmdline_user_args()
## --loadtest --loadloop: back to the menu once and through it all again (warm caches).
static var again := false
static var rounds_left := 1 if "--loadloop" in OS.get_cmdline_user_args() else 0
static var _phase := ""
static var _t0 := 0
static var _last := 0
static var _frames: Array[int] = []
static var _frames_left := 0
static var _frame_t := 0
static var _hooked := false
static var _proc_t := 0


static func begin(phase: String) -> void:
	if not on:
		return
	_phase = phase
	_t0 = Time.get_ticks_usec()
	_last = _t0
	print("[load] ===== %s (engine up %.0f ms)" % [phase, _t0 / 1000.0])


static func mark(label: String) -> void:
	if not on:
		return
	var now := Time.get_ticks_usec()
	print("[load] %-12s %-34s %8.1f ms   (t=%8.1f)" % [_phase, label, (now - _last) / 1000.0, (now - _t0) / 1000.0])
	_last = now


## Logs the next `count` drawn frames' lengths (from the last mark on).
static func watch_frames(count: int = 30) -> void:
	if not on:
		return
	if not _hooked:
		_hooked = true
		RenderingServer.frame_post_draw.connect(_on_frame)
		(Engine.get_main_loop() as SceneTree).process_frame.connect(func() -> void: _proc_t = Time.get_ticks_usec())
	_frames.clear()
	_frames_left = count
	_frame_t = _last


static func _on_frame() -> void:
	if _frames_left <= 0:
		return
	var now := Time.get_ticks_usec()
	_frames.append(now - _frame_t)
	if _frames.size() <= 3: # where a slow first frame goes: before the idle step, or in it and the draw
		print("[load] %-12s   frame %d: %.0f ms before process, %.0f ms process + draw" % [_phase, _frames.size(), (_proc_t - _frame_t) / 1000.0, (now - _proc_t) / 1000.0])
	_frame_t = now
	_frames_left -= 1
	if _frames_left == 0:
		var parts: PackedStringArray = []
		var total := 0
		var worst := 0
		for us in _frames:
			parts.append("%.0f" % (us / 1000.0))
			total += us
			worst = maxi(worst, us)
		print("[load] %-12s first %d frames: %s ms (sum %.0f, worst %.0f)" % [_phase, _frames.size(), " ".join(parts), total / 1000.0, worst / 1000.0])
		print("[load] %-12s settled at t=%.1f ms" % [_phase, (now - _t0) / 1000.0])
		report_cached()


## Which asset files (res://assets, res://audio, the scenes) are loaded right now:
## printed at each phase's end, so the next phase's loads show up as new names.
static var _seen: Dictionary = {}


static func report_cached(dirs: Array = ["res://assets", "res://scenes", "res://shaders"]) -> void:
	if not on:
		return
	var fresh: PackedStringArray = []
	for d: String in dirs:
		_scan(d, fresh)
	print("[load] %-12s %d resources newly cached: %s" % [_phase, fresh.size(), ", ".join(fresh)])


static func _scan(dir: String, fresh: PackedStringArray) -> void:
	for f in ResourceLoader.list_directory(dir):
		var path := dir.path_join(f)
		if f.ends_with("/"):
			_scan(path.trim_suffix("/"), fresh)
		elif not _seen.has(path) and ResourceLoader.has_cached(path):
			_seen[path] = true
			fresh.append(path.trim_prefix("res://"))
