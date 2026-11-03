class_name SoundLimiter
extends RefCounted
## Decides which pooled player a busy one-shot (the bug death crunch) may use, so a
## big wave doesn't turn into noise: at most `max_per_window` sounds start within
## `window_ms`. When that budget is spent, a new sound only plays if it is nearer
## than the farthest one started in the window (it takes that one's player);
## otherwise it is skipped. Pure logic, no audio, so tests can drive it.

var max_per_window: int
var window_ms: int
var _start: PackedInt64Array = []
var _dist: PackedFloat32Array = []


func _init(slots: int = 6, max_in_window: int = 4, window: int = 100) -> void:
	max_per_window = mini(max_in_window, slots)
	window_ms = window
	_start.resize(slots)
	_dist.resize(slots)
	for i in slots:
		_start[i] = -1000000000
		_dist[i] = INF


## Returns the slot (player index) to play on, or -1 to skip this sound.
func admit(now_ms: int, dist: float) -> int:
	var in_window := 0
	var oldest := -1
	var farthest := -1
	for i in _start.size():
		if now_ms - _start[i] < window_ms:
			in_window += 1
			if farthest < 0 or _dist[i] > _dist[farthest]:
				farthest = i
		elif oldest < 0 or _start[i] < _start[oldest]:
			oldest = i
	var slot := -1
	if in_window < max_per_window and oldest >= 0:
		slot = oldest
	elif farthest >= 0 and dist < _dist[farthest]:
		slot = farthest # nearest first: a closer death bumps a farther one
	if slot >= 0:
		_start[slot] = now_ms
		_dist[slot] = dist
	return slot
