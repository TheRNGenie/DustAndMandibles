class_name MapDef
extends RefCounted
## A playable map: how many cliffs it has, where each cliff's lip sits and which
## way it faces, which other cliffs each cliff's turrets cover (and with what
## share of its build grid), how bugs pick a cliff, where the tunnels are and
## where the airship hangs. Cliff ids are ints 0..count()-1.
##
## Every cliff has a local frame: `origin` is the middle of its nominal lip (y 0),
## `inward` points from the lip out over the gap (where bugs climb from), and
## `along` runs along the lip (local z, the build grid's column direction).
## A point at depth d behind the lip, v along it and height y is
##     origin + inward * (prow_u(v) - d) + along * v + up * y
## (the canyon also bends its far reaches: CliffBuilder.warp).
##
## The canyon is the original two-cliff map and plays exactly as before.

const CANYON := &"canyon"
const MESA := &"mesa"
const BUTTES := &"buttes"
const IDS: Array[StringName] = [CANYON, MESA, BUTTES]

## The map this run plays on. Set before the world is built (lobby / --map=).
static var current: MapDef = null


class Cliff:
	extends RefCounted
	var name := ""
	## One word for tight spots ("West", "North").
	var short := ""
	var origin := Vector3.ZERO
	var inward := Vector3.RIGHT
	var along := Vector3.BACK
	## [[first_col, last_col, target_cliff], ...] (inclusive column ranges of the build grid).
	var cover: Array = []
	## How likely bugs are to pick this cliff (relative to the others).
	var weight := 1.0
	## Rock colour of this cliff's walls.
	var rock := Color("#E8B27A")
	## Which noise stream shapes its face (same index = same climb surface).
	var noise := 0
	## A V-shaped lip ("prow"): the middle `prow_half` metres each side of v = 0
	## are straight, then the edge faces fall back `prow_slope` metres per metre.
	var prow_half := 0.0
	var prow_slope := 0.0
	## Dressing style for its walls and landmark (Pinwheel Buttes).
	var style := &""


var id: StringName = CANYON
var display_name := "Canyon"
var blurb := ""
var cliffs: Array[Cliff] = []
## How far along each lip (either way) the cliff's face and plateau run.
var span_v := 90.0
## Bug tunnels on the floor: [[mouth (Vector3, y ignored), out (Vector3, the way bugs come out)], ...].
## The canyon's live in WorldLayout.TUNNELS instead (in the foot of either wall).
var tunnels: Array = []
## The airship's boarding ring (the canyon works it out from its arches).
var airship_ring := Vector3.ZERO
## Middle of the gap / basin / lake.
var center := Vector3.ZERO
## Butte / mesa layout numbers the terrain builder needs.
var ring_radius := 0.0


# ------------------------------------------------------------------ the maps

static func get_current() -> MapDef:
	if current == null:
		current = canyon()
	return current


static func select(map_id: StringName) -> MapDef:
	current = by_id(map_id)
	return current


static func by_id(map_id: StringName) -> MapDef:
	match map_id:
		MESA:
			return mesa()
		BUTTES:
			return buttes()
	return canyon()


static func display_name_of(map_id: StringName) -> String:
	match map_id:
		MESA:
			return "Three-Cliff Mesa"
		BUTTES:
			return "Pinwheel Buttes"
	return "Canyon"


static func players_of(map_id: StringName) -> int:
	match map_id:
		MESA:
			return 3
		BUTTES:
			return 4
	return 2


## The original map: two cliffs facing each other across a 45 m canyon.
static func canyon() -> MapDef:
	var m := MapDef.new()
	m.id = CANYON
	m.display_name = "Canyon"
	m.blurb = "Two cliffs, one canyon. And the canyon is not the bottom."
	m.span_v = WorldLayout.PLAY_HALF_Z
	var w := Cliff.new()
	w.name = "West Cliff"
	w.short = "West"
	w.origin = Vector3(-WorldLayout.HALF_GAP, 0, 0)
	w.inward = Vector3(1, 0, 0)
	w.along = Vector3(0, 0, 1)
	w.cover = [[0, Buildable.COLS - 1, 1]]
	w.noise = 0
	var e := Cliff.new()
	e.name = "East Cliff"
	e.short = "East"
	e.origin = Vector3(WorldLayout.HALF_GAP, 0, 0)
	e.inward = Vector3(-1, 0, 0)
	e.along = Vector3(0, 0, 1)
	e.cover = [[0, Buildable.COLS - 1, 0]]
	e.noise = 1
	m.cliffs = [w, e]
	return m


## Three plateaus round a sunken basin, every lip facing the middle. Each lip
## is split: its left half covers the neighbour on the left, its right half the
## neighbour on the right. Bugs come out of tunnels in the basin walls between
## the plateaus.
static func mesa() -> MapDef:
	var m := MapDef.new()
	m.id = MESA
	m.display_name = "Three-Cliff Mesa"
	m.blurb = "Three plateaus round a sunken basin. Each half of your lip covers a different neighbour."
	m.span_v = 26.0
	m.ring_radius = 31.0
	var names := ["North Rim", "Southeast Rim", "Southwest Rim"]
	var shorts := ["North", "Southeast", "Southwest"]
	var rocks := [Color("#E8B27A"), Color("#E0A272"), Color("#EBBE88")]
	for i in 3:
		m.cliffs.append(_ring_cliff(m.ring_radius, 120.0 * i, names[i], shorts[i], i))
		m.cliffs[i].rock = rocks[i]
	var half := Buildable.COLS / 2
	for i in 3:
		var c := m.cliffs[i]
		var left := m._side_neighbour(i, -1.0)
		var right := m._side_neighbour(i, 1.0)
		c.cover = [[0, half - 1, left], [half, Buildable.COLS - 1, right]]
	# Tunnels in the foot of the basin walls (two in each wall, between the plateaus).
	# The walls curve round the basin (see MapTerrain._mesa_wall), so do the tunnels.
	for i in 3:
		var j := (i + 1) % 3
		var pa := m.to_world(i, 3.0, signf((m.cliffs[j].origin - m.cliffs[i].origin).dot(m.cliffs[i].along)) * (m.span_v - 2.0))
		var pb := m.to_world(j, 3.0, signf((m.cliffs[i].origin - m.cliffs[j].origin).dot(m.cliffs[j].along)) * (m.span_v - 2.0))
		var a0 := atan2(pa.z, pa.x)
		var da := wrapf(atan2(pb.z, pb.x) - a0, -PI, PI)
		var r0 := Vector2(pa.x, pa.z).length()
		var r1 := Vector2(pb.x, pb.z).length()
		for t: float in [0.3, 0.7]:
			var mouth := Vector3(cos(a0 + da * t), 0, sin(a0 + da * t)) * lerpf(r0, r1, t)
			m.tunnels.append([mouth, (m.center - mouth).normalized()])
	m.airship_ring = Vector3(0, WorldLayout.CLIFF_HEIGHT + 44.0, 0)
	return m


## Four lone buttes round a cracked dry lake. Each butte's inner face is a
## shallow V: the wide centre face looks across the lake at the opposite butte
## (12 of 20 columns), the two angled edge faces at the neighbours either side
## (4 columns each). Bugs rise out of cracks in the lakebed.
static func buttes() -> MapDef:
	var m := MapDef.new()
	m.id = BUTTES
	m.display_name = "Pinwheel Buttes"
	m.blurb = "Four lone buttes round a dry lake. Your centre guns cover the far butte, your edges the neighbours."
	m.span_v = 30.0
	m.ring_radius = 30.0
	var names := ["North Butte", "East Butte", "South Butte", "West Butte"]
	var shorts := ["North", "East", "South", "West"]
	var rocks := [Color("#C8603E"), Color("#EAD3B0"), Color("#5E5A5C"), Color("#D99A3E")]
	var styles := [&"ledges", &"layers", &"basalt", &"buttress"]
	for i in 4:
		var c := _ring_cliff(m.ring_radius, 90.0 * i, names[i], shorts[i], 0)
		c.rock = rocks[i]
		c.style = styles[i]
		c.prow_half = 12.0
		c.prow_slope = 0.7
		m.cliffs.append(c)
	for i in 4:
		var c := m.cliffs[i]
		var left := m._side_neighbour(i, -1.0)
		var right := m._side_neighbour(i, 1.0)
		c.cover = [[0, 3, left], [4, 15, (i + 2) % 4], [16, Buildable.COLS - 1, right]]
	# Cracks in the lakebed: a ring of fissures a little way out from the middle.
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		var r := 9.0 if k % 2 == 0 else 15.0
		var mouth := Vector3(sin(a) * r, 0, -cos(a) * r)
		# Bugs come out along the crack, heading round the lake.
		m.tunnels.append([mouth, Vector3(cos(a), 0, sin(a))])
	m.airship_ring = Vector3(0, WorldLayout.CLIFF_HEIGHT + 44.0, 0)
	return m


## A cliff on a ring round the middle, at compass `bearing` degrees (0 = north = -Z,
## 90 = east = +X), its lip facing the middle.
static func _ring_cliff(radius: float, bearing: float, cliff_name: String, short_name: String, noise_index: int) -> Cliff:
	var b := deg_to_rad(bearing)
	var out := Vector3(sin(b), 0, -cos(b))
	var c := Cliff.new()
	c.name = cliff_name
	c.short = short_name
	c.origin = out * radius
	c.inward = -out
	# Along = the defender's right hand when facing the gap.
	c.along = Vector3(-c.inward.z, 0, c.inward.x)
	c.noise = noise_index
	return c


## The neighbour lying on cliff `i`'s left (side -1) or right (side +1).
func _side_neighbour(i: int, side: float) -> int:
	var best := -1
	var best_d := INF
	for j in cliffs.size():
		if j == i:
			continue
		var rel := cliffs[j].origin - cliffs[i].origin
		if rel.dot(cliffs[i].along) * side <= 0.0:
			continue
		var d := rel.length()
		if d < best_d:
			best_d = d
			best = j
	return best


## The end of cliff i's lip nearest cliff `other` (top of the face, y 0).
func lip_end(i: int, other: Cliff) -> Vector3:
	var c := cliffs[i]
	var side := signf((other.origin - c.origin).dot(c.along))
	return to_world(i, 0.0, side * span_v)


# ------------------------------------------------------------------ queries

func count() -> int:
	return cliffs.size()


func is_canyon() -> bool:
	return id == CANYON


func cliff(cid: int) -> Cliff:
	return cliffs[clampi(cid, 0, cliffs.size() - 1)]


func name_of(cid: int) -> String:
	if cid < 0 or cid >= cliffs.size():
		return "?"
	return cliffs[cid].name


func short_of(cid: int) -> String:
	if cid < 0 or cid >= cliffs.size():
		return "?"
	return cliffs[cid].short


## How far the lip at v falls back from the nominal line (0 for a straight lip).
func prow_u(cid: int, v: float) -> float:
	var c := cliffs[cid]
	if c.prow_half <= 0.0:
		return 0.0
	return -maxf(absf(v) - c.prow_half, 0.0) * c.prow_slope


## World point (y 0) at u toward the gap from the nominal lip line and v along it.
func to_world(cid: int, u: float, v: float) -> Vector3:
	var c := cliffs[cid]
	return c.origin + c.inward * u + c.along * v


## (u, v) of a world position in a cliff's frame (no canyon warp).
func local_uv(cid: int, pos: Vector3) -> Vector2:
	var c := cliffs[cid]
	var rel := Vector3(pos.x - c.origin.x, 0.0, pos.z - c.origin.z)
	return Vector2(rel.dot(c.inward), rel.dot(c.along))


## Y rotation that turns a node's forward (-Z) to face the gap from this cliff.
func facing_yaw(cid: int) -> float:
	if is_canyon():
		return (-1.0 if cid == 0 else 1.0) * PI * 0.5
	var n := cliffs[cid].inward
	return atan2(-n.x, -n.z)


## The cliff a turret in grid column `col` of cliff `cid` covers.
func covered_cliff(cid: int, col: int) -> int:
	if cid < 0 or cid >= cliffs.size():
		return -1
	for seg: Array in cliffs[cid].cover:
		if col >= int(seg[0]) and col <= int(seg[1]):
			return int(seg[2])
	return main_target(cid)


## Every cliff that cliff `cid`'s turrets cover, biggest share first.
func covered_cliffs(cid: int) -> Array[int]:
	var out: Array[int] = []
	var shares := {}
	for seg: Array in cliffs[cid].cover:
		shares[int(seg[2])] = float(shares.get(int(seg[2]), 0.0)) + float(int(seg[1]) - int(seg[0]) + 1)
	for k: int in shares:
		out.append(k)
	out.sort_custom(func(a: int, b: int) -> bool: return float(shares[a]) > float(shares[b]))
	return out


## Fraction (0..1) of cliff `cid`'s grid columns that cover `target`.
func cover_share(cid: int, target: int) -> float:
	var n := 0
	for seg: Array in cliffs[cid].cover:
		if int(seg[2]) == target:
			n += int(seg[1]) - int(seg[0]) + 1
	return float(n) / float(Buildable.COLS)


## The cliffs whose turrets cover `target` (its defenders).
func defenders_of(target: int) -> Array[int]:
	var out: Array[int] = []
	for i in cliffs.size():
		if i != target and cover_share(i, target) > 0.0:
			out.append(i)
	return out


## The cliff this one's turrets mostly cover (the canyon's "other cliff").
func main_target(cid: int) -> int:
	if is_canyon() or cliffs.size() == 2:
		return 1 - clampi(cid, 0, 1)
	var c := covered_cliffs(cid)
	return c[0] if not c.is_empty() else (cid + 1) % cliffs.size()


## Bug spawn weights, normalised to sum 1.
func spawn_weights() -> Array[float]:
	var total := 0.0
	for c in cliffs:
		total += c.weight
	var out: Array[float] = []
	for c in cliffs:
		out.append(c.weight / maxf(total, 0.0001))
	return out


## Which cliff's plateau a world position is on (behind its lip), or -1 over the gap.
func cliff_at(pos: Vector3) -> int:
	if is_canyon():
		if pos.x < -WorldLayout.HALF_GAP + 0.5:
			return 0
		if pos.x > WorldLayout.HALF_GAP - 0.5:
			return 1
		return -1
	var best := -1
	var best_d := -INF
	for i in cliffs.size():
		var uv := local_uv(i, pos)
		if absf(uv.y) > span_v + 4.0:
			continue
		var d := prow_u(i, uv.y) - uv.x # metres behind the lip
		if d > -0.5 and d > best_d:
			best_d = d
			best = i
	return best


## Where a flier rising out of the gap heads first (over the gap in front of
## `cid`, `height` up), given where it is now.
func rise_point(cid: int, pos: Vector3, height: float) -> Vector3:
	if is_canyon():
		var into := clampf(pos.z, -WorldLayout.PLATEAU_WIDTH * 0.4, WorldLayout.PLATEAU_WIDTH * 0.4)
		return Vector3(0.0, height, into)
	var c := cliffs[cid]
	var p := center.lerp(c.origin, 0.55)
	return Vector3(p.x, height, p.z)


## The middle of the gap in front of a cliff (where its bugs climb from).
func gap_point(cid: int) -> Vector3:
	if is_canyon():
		return Vector3.ZERO
	return center.lerp(cliffs[cid].origin, 0.5)


func tunnel_count() -> int:
	return WorldLayout.TUNNELS.size() if is_canyon() else tunnels.size()
