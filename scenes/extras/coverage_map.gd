class_name CoverageMap
extends Node
## How many turrets cover each stretch of each cliff wall, on a coarse grid of
## the climbing band (z across the plateau, y up the wall). Uses the same maths
## as the placement preview (Targeting.in_arc, range from tier and scaffold
## level, look-down from the level). Rebuilt only when the turret set changes
## (checked twice a second from a cheap signature), so reading it is free:
## the build-mode heat map draws it, and climbing bugs lean toward the weakly
## covered columns when they pick their next wander target (LaneClimber).
## Every peer keeps its own copy from the replicated turrets.

signal changed

const STEP := 2.0
## Bugs climb within +-18 m of the plateau centre; cover a little past that.
const Z_HALF := 20.0
const POLL := 0.5

static var instance: CoverageMap

var cliffs: CliffBuilder
var cols := 0
var rows := 0
## Per wall: turret count per grid point, index r * cols + c (r = up the wall).
var counts: Array[PackedByteArray] = [PackedByteArray(), PackedByteArray()]
## Per wall: counts summed from row r to the top, per column (same indexing).
var _suffix: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
## Per wall: the face points the grid samples (world space).
var points: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
var _sig := -1
var _t := 0.0


func _ready() -> void:
	instance = self
	cols = int(Z_HALF * 2.0 / STEP) + 1
	rows = int(WorldLayout.CLIFF_HEIGHT / STEP) + 1
	for w in 2:
		var a := PackedByteArray()
		a.resize(cols * rows)
		counts[w] = a
		var s := PackedInt32Array()
		s.resize(cols * rows)
		_suffix[w] = s


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func z_of(c: int) -> float:
	return -Z_HALF + c * STEP


func y_of(r: int) -> float:
	return minf(r * STEP, WorldLayout.CLIFF_HEIGHT - 0.5)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = POLL
	if cliffs == null:
		cliffs = Bug.cliffs
		if cliffs == null:
			return
	var sig := _signature()
	if sig != _sig:
		_sig = sig
		rebuild()


## A hash of everything that changes coverage: which turrets, where, tier, level.
func _signature() -> int:
	var h := 17
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t == null or not t.is_inside_tree() or t.is_queued_for_deletion():
			continue
		h = hash([h, t.def.id, t.tier, t.level, t.cliff_id, t.global_position.snapped(Vector3.ONE * 0.5)])
	return h


func rebuild() -> void:
	if points[0].is_empty():
		for w in 2:
			var p := PackedVector3Array()
			p.resize(cols * rows)
			for r in rows:
				for c in cols:
					p[r * cols + c] = cliffs.face_point(w, y_of(r), z_of(c))
			points[w] = p
	# Turret arcs: [muzzle, pitch, range] grouped by the wall they cover.
	var arcs: Array = [[], []]
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t == null or not t.is_inside_tree() or t.is_queued_for_deletion() or t.def == null:
			continue
		if t.def.guards_plateau or t.def.anti_air:
			continue
		var head := t.get("_head") as Node3D
		var muzzle := head.global_position if head != null else t.global_position + Vector3.UP * 1.5
		arcs[WorldLayout.other_cliff(t.cliff_id)].append([muzzle, t.pitch_limit(), t.def.range_at(t.tier, t.level)])
	for w in 2:
		var pts := points[w]
		var cnt := counts[w]
		for i in cnt.size():
			cnt[i] = mini(CoverageRules.count_covering(arcs[w], pts[i]), 255)
		counts[w] = cnt
		var suf := _suffix[w]
		for c in cols:
			var run := 0
			for r in range(rows - 1, -1, -1):
				run += cnt[r * cols + c]
				suf[r * cols + c] = run
		_suffix[w] = suf
		if GameState.has_flag("--coverlog"):
			var h := [0, 0, 0]
			for v in cnt:
				h[mini(v, 2)] += 1
			print("[coverage] wall %d: %d turrets, none %d / one %d / two+ %d points" % [w, arcs[w].size(), h[0], h[1], h[2]])
	changed.emit()


func count_at(wall: int, r: int, c: int) -> int:
	return counts[wall][r * cols + c]


## Average number of turrets covering column z of `wall`, from height `from_y`
## to the lip (what a bug at that height still has to climb through).
func cover_ahead(wall: int, z: float, from_y: float) -> float:
	if wall < 0 or wall > 1 or _suffix[wall].is_empty():
		return 0.0
	var c := clampi(roundi((z + Z_HALF) / STEP), 0, cols - 1)
	var r := clampi(int(from_y / STEP), 0, rows - 1)
	return float(_suffix[wall][r * cols + c]) / float(rows - r)


static func pick_weakest(cover: Array, noise: Array) -> int:
	return CoverageRules.pick_weakest(cover, noise)


static func heat_color(n: int) -> Color:
	return CoverageRules.heat_color(n)
