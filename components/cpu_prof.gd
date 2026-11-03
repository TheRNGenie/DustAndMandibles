class_name CpuProf
extends RefCounted
## Cheap per-system CPU timing for the --stress / --soak reports (debug only).
## Systems add the microseconds they took (CpuProf.add) when `on`; probe nodes
## at the very start and end of the physics and idle passes give the whole
## script time per tick and per frame. Off (the default) it costs one bool test.

static var on := false
static var _us: Dictionary = {} # system -> microseconds since reset
static var _ticks := 0
static var _frames := 0
static var _phys_us := 0
static var _proc_us := 0


static func add(key: StringName, us: int) -> void:
	_us[key] = int(_us.get(key, 0)) + us


## Starts timing: two probes at each end of the physics and idle passes.
static func install(root: Node) -> void:
	on = true
	for first: bool in [true, false]:
		var p := _Probe.new()
		p.first = first
		p.name = "CpuProbe%s" % ("First" if first else "Last")
		p.process_priority = -100000 if first else 100000
		p.process_physics_priority = -100000 if first else 100000
		root.add_child(p)
	reset()


static func reset() -> void:
	_us.clear()
	_ticks = 0
	_frames = 0
	_phys_us = 0
	_proc_us = 0


## "physics script X ms/tick (systems...)  idle script Y ms/frame (systems...)".
static func report() -> String:
	var t := maxi(_ticks, 1)
	var f := maxi(_frames, 1)
	var keys := _us.keys()
	keys.sort_custom(func(a, b) -> bool: return int(_us[a]) > int(_us[b]))
	var parts: Array[String] = []
	for k: StringName in keys:
		var per := float(_us[k]) / 1000.0 / (float(f) if String(k).begins_with("p:") else float(t))
		parts.append("%s %.2f" % [k, per])
	return "script ms: physics %.2f/tick (%d ticks)  idle %.2f/frame (%d frames)  | %s" % [
		float(_phys_us) / 1000.0 / t, _ticks, float(_proc_us) / 1000.0 / f, _frames, "  ".join(parts)]


class _Probe extends Node:
	var first := true
	static var _p0 := 0
	static var _i0 := 0

	func _physics_process(_d: float) -> void:
		if first:
			_p0 = Time.get_ticks_usec()
		else:
			CpuProf._phys_us += Time.get_ticks_usec() - _p0
			CpuProf._ticks += 1

	func _process(_d: float) -> void:
		if first:
			_i0 = Time.get_ticks_usec()
		else:
			CpuProf._proc_us += Time.get_ticks_usec() - _i0
			CpuProf._frames += 1
