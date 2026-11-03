class_name RopeAnchor
extends StaticBody3D
## Canyon Expeditions: a timber davit on the cliff lip with a hand winch, free
## on every cliff (WorldDressing puts one at the south corner of each yard).
## E at the post and you're lowered down the wall on a bosun's chair, about
## eight seconds to the canyon floor; E at the stake on the floor rides you back
## up. Only between waves. The chair hangs off the rope's end at the boom tip,
## out past the face, so the ride never scrapes the rock.
##
## Every peer animates the ride from the same timeline: the rider's peer calls
## begin_ride(), which tells everyone (an RPC on this node, which has the same
## path everywhere); if the chair is at the other end it's spooled over first.

static var _by_cliff: Dictionary = {}

## Seconds to spool the empty chair to the other end before a ride.
const FETCH_TIME := 2.0
## The chair hangs this far below the pulley at the top, and rides this high
## off the ground at the bottom; the rider's feet hang this far under it.
const SEAT_TOP_DROP := 0.9
const SEAT_FLOOR := 0.9
const SEAT_TO_FEET := 0.95
## How far out from the rope (over the gap) the rider hangs.
const RIDER_OUT := 0.35

var cliff_id := 0
## Where things are, in world space (set by setup()).
var tip := Vector3.ZERO
var bottom := Vector3.ZERO
var top_stand := Vector3.ZERO
var foot_stand := Vector3.ZERO
var inward := Vector3.RIGHT

var _from_top := true
var _rest_top := true
var _active := false
var _t := 0.0
var _fetch := 0.0
var _rope: MeshInstance3D
var _seat: Node3D
var _drum: Node3D
var _crank: Node3D
var _tick := 0.0
var _foot: RopeFoot


static func of(cid: int) -> RopeAnchor:
	var a: Variant = _by_cliff.get(cid)
	return a as RopeAnchor if a != null and is_instance_valid(a) else null


static func all() -> Array[RopeAnchor]:
	var out: Array[RopeAnchor] = []
	for k: Variant in _by_cliff:
		var a := of(int(k))
		if a != null:
			out.append(a)
	return out


## Works out where everything goes on cliff `cid` at plateau z `z` (before adding to the tree).
func setup(cliffs: CliffBuilder, cid: int, z: float) -> void:
	cliff_id = cid
	inward = WorldLayout.inward(cid)
	var lip := cliffs.plateau_point(cid, 0.0, z)
	# Reach out past the furthest the face juts out below (buttresses, rough rock).
	var reach := 1.6
	var y := 1.0
	while y < WorldLayout.CLIFF_HEIGHT - 0.5:
		reach = maxf(reach, (cliffs.face_point(cid, y, z) - lip).dot(inward) + 1.4)
		y += 1.0
	reach = minf(reach, 6.0)
	var post := cliffs.plateau_point(cid, 1.3, z)
	position = post
	tip = Vector3(lip.x, maxf(lip.y, post.y), lip.z) + inward * reach + Vector3.UP * 3.4
	bottom = Vector3(tip.x, cliffs.floor_height(tip.x, tip.z), tip.z)
	top_stand = cliffs.plateau_point(cid, 2.8, z) + Vector3.UP * 0.15
	var fs := bottom + inward * 1.8
	foot_stand = Vector3(fs.x, cliffs.floor_height(fs.x, fs.z) + 0.15, fs.z)


func _ready() -> void:
	_by_cliff[cliff_id] = self
	add_to_group("rope_anchors")
	collision_layer = WorldLayout.LAYER_WORLD
	collision_mask = 0
	_build()
	_foot = RopeFoot.new()
	_foot.name = "Foot"
	_foot.anchor = self
	_foot.top_level = true
	add_child(_foot)
	_foot.global_position = bottom + inward * 0.7
	_place_seat(0.0)


func _exit_tree() -> void:
	if _by_cliff.get(cliff_id) == self:
		_by_cliff.erase(cliff_id)


# ------------------------------------------------------------------ the ride

## Is someone on the chair right now?
func busy() -> bool:
	return _active


## Rider's peer: start a ride from the top (down) or from the floor (up).
func begin_ride(from_top: bool) -> bool:
	if _active:
		return false
	_start.rpc(from_top)
	return true


@rpc("any_peer", "call_local", "reliable")
func _start(from_top: bool) -> void:
	_from_top = from_top
	_fetch = 0.0 if _rest_top == from_top else FETCH_TIME
	_t = 0.0
	_active = true
	Audio.play_at(&"zip_grab", tip, -4.0)


## -1 while the chair is still on its way to the rider, then 0..1 along the ride.
func progress() -> float:
	if not _active:
		return 1.0
	if _t < _fetch:
		return -1.0
	return clampf((_t - _fetch) / ExpeditionRules.RIDE_TIME, 0.0, 1.0)


## The chair: 0 at the top, 1 at the bottom.
func seat_s() -> float:
	if not _active:
		return 0.0 if _rest_top else 1.0
	var start := 0.0 if _from_top else 1.0
	if _t < _fetch:
		var k := ExpeditionRules.ride_ease(_t / maxf(_fetch, 0.01))
		return lerpf(1.0 - start, start, k)
	var r := ExpeditionRules.ride_ease((_t - _fetch) / ExpeditionRules.RIDE_TIME)
	return lerpf(start, 1.0 - start, r)


func seat_point(s: float) -> Vector3:
	var top := tip + Vector3.DOWN * SEAT_TOP_DROP
	var low := bottom + Vector3.UP * SEAT_FLOOR
	return top.lerp(low, s)


## Where a rider's feet are at chair position s.
func rider_point(s: float) -> Vector3:
	return seat_point(s) + Vector3.DOWN * SEAT_TO_FEET + inward * RIDER_OUT


func _process(delta: float) -> void:
	var before := seat_s()
	if _active:
		_t += delta
		if _t >= _fetch + ExpeditionRules.RIDE_TIME:
			_active = false
			_rest_top = not _from_top
	var s := seat_s()
	_place_seat(s)
	# The winch drum and crank turn with the rope.
	var moved := (s - before) * (tip.y - bottom.y)
	_drum.rotation.z += moved * 1.6
	_crank.rotation.z = _drum.rotation.z
	if absf(moved) > 0.001:
		_tick += absf(moved)
		if _tick > 1.2:
			_tick = 0.0
			Audio.play_at(&"wheel_tick", global_position + Vector3.UP, -10.0, 0.8)


func _place_seat(s: float) -> void:
	var p := seat_point(s)
	_seat.global_position = p
	var a := tip
	var len := a.distance_to(p)
	_rope.global_transform = Transform3D(Basis(Vector3.RIGHT, 0.0).scaled(Vector3(1, len, 1)), (a + p) * 0.5)


# ------------------------------------------------------------------ E

func interact_prompt() -> String:
	if GameState.phase != GameState.Phase.BUILD:
		return "Rope Winch  -  only between waves"
	if _active:
		return "Rope Winch  -  someone's on the rope"
	if GameState.ready_countdown >= 0.0:
		return "Rope Winch  -  the wave's riding in"
	return "Rope Winch  -  down into the canyon (%d s)\nE: ride down" % int(ExpeditionRules.RIDE_TIME)


func local_interact(holding: bool) -> void:
	if holding or GameState.phase != GameState.Phase.BUILD or GameState.ready_countdown >= 0.0:
		return
	var me := _local_player()
	if me != null:
		me.start_rope(self, true)


func _local_player() -> Player:
	return Expedition.player_node(multiplayer.get_unique_id())


# ------------------------------------------------------------------ looks

func _build() -> void:
	var mat := Materials.toon(0.02)
	var wood := Palette.WOOD
	var dark := Palette.WOOD_DARK
	var st := MeshKit.begin()
	var post_top := Vector3(0, 3.9, 0)
	var tip_l := tip - position
	# The post, a footing of stones and two back braces.
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 1.95, 0)), Vector3(0.28, 3.9, 0.28), wood, 0.02)
	MeshKit.add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), 0.55, 0.45, 0.24, 8, Color("#8C7A66"))
	var back := -Vector3(inward.x, 0, inward.z).normalized()
	var side := Vector3.UP.cross(back).normalized()
	for sg: float in [-1.0, 1.0]:
		MeshKit.add_limb(st, back * 1.3 + side * sg * 0.6, Vector3(0, 2.4, 0), 0.07, dark, 6)
	# The boom out over the lip and its diagonal brace.
	var boom_end := tip_l + Vector3.UP * 0.25
	MeshKit.add_limb(st, post_top + Vector3.DOWN * 0.15, boom_end, 0.11, wood, 6)
	MeshKit.add_limb(st, Vector3(0, 2.2, 0), post_top.lerp(boom_end, 0.45), 0.07, dark, 6)
	# The pulley block at the tip.
	MeshKit.add_box(st, Transform3D(Basis.IDENTITY, tip_l + Vector3.UP * 0.05), Vector3(0.22, 0.34, 0.22), Palette.METAL)
	# The rope from the drum up the post and along the boom.
	MeshKit.add_limb(st, back * 0.45 + Vector3(0, 1.0, 0), post_top + back * 0.05, 0.025, Color("#C9A66B"), 5)
	MeshKit.add_limb(st, post_top + Vector3.UP * 0.05, tip_l + Vector3.UP * 0.12, 0.025, Color("#C9A66B"), 5)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = mat
	add_child(mi)
	# The winch: a drum between two cheeks, and a crank.
	var winch := Node3D.new()
	winch.position = back * 0.45 + Vector3(0, 0.95, 0)
	winch.basis = Basis.looking_at(side, Vector3.UP) # drum axis along `side`... rotate about local z
	add_child(winch)
	var cheeks := MeshKit.begin()
	for sg: float in [-1.0, 1.0]:
		MeshKit.add_box(cheeks, Transform3D(Basis.IDENTITY, Vector3(0, -0.4, sg * 0.32)), Vector3(0.5, 1.0, 0.07), dark, 0.01)
	var cm := MeshInstance3D.new()
	cm.mesh = MeshKit.finish(cheeks)
	cm.material_override = mat
	winch.add_child(cm)
	_drum = Node3D.new()
	winch.add_child(_drum)
	var dst := MeshKit.begin()
	MeshKit.add_cylinder(dst, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.2, 0.2, 0.56, 10, Color("#C9A66B"))
	MeshKit.add_box(dst, Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(0.44, 0.05, 0.6), dark)
	var dm := MeshInstance3D.new()
	dm.mesh = MeshKit.finish(dst)
	dm.material_override = mat
	_drum.add_child(dm)
	_crank = Node3D.new()
	_crank.position = Vector3(0, 0, 0.42)
	winch.add_child(_crank)
	var kst := MeshKit.begin()
	MeshKit.add_box(kst, Transform3D(Basis.IDENTITY, Vector3(0.18, 0, 0)), Vector3(0.4, 0.06, 0.05), Palette.METAL)
	MeshKit.add_cylinder(kst, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.36, 0, 0.1)), 0.035, 0.035, 0.22, 6, dark)
	var km := MeshInstance3D.new()
	km.mesh = MeshKit.finish(kst)
	km.material_override = mat
	_crank.add_child(km)
	# The hanging rope (stretched to the chair each frame) and the chair.
	_rope = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	_rope.mesh = cyl
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color("#C9A66B")
	_rope.material_override = rope_mat
	_rope.top_level = true
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	_seat = Node3D.new()
	_seat.top_level = true
	add_child(_seat)
	var sst := MeshKit.begin()
	MeshKit.add_box(sst, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), Vector3(0.55, 0.06, 0.3), wood, 0.01)
	for c: Vector3 in [Vector3(-0.25, 0, -0.12), Vector3(0.25, 0, -0.12), Vector3(-0.25, 0, 0.12), Vector3(0.25, 0, 0.12)]:
		MeshKit.add_limb(sst, c, Vector3(0, 0.75, 0), 0.015, Color("#C9A66B"), 4)
	MeshKit.add_ellipsoid(sst, Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)), Vector3(0.07, 0.09, 0.07), 4, 6, Palette.METAL)
	var sm := MeshInstance3D.new()
	sm.mesh = MeshKit.finish(sst)
	sm.material_override = mat
	_seat.add_child(sm)
	# Collision: the post and winch (E aims at either).
	for shape: Array in [[Vector3(0.5, 3.9, 0.5), Vector3(0, 1.95, 0)], [Vector3(0.7, 1.1, 0.8), winch.position + Vector3(0, -0.4, 0)]]:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = shape[0]
		col.shape = bs
		col.position = shape[1]
		add_child(col)


## The stake at the bottom: a post with a coil of slack rope and a little
## brass bell; E rides you back up.
class RopeFoot extends StaticBody3D:
	var anchor: RopeAnchor

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_WORLD
		collision_mask = 0
		var st := MeshKit.begin()
		MeshKit.add_box(st, Transform3D(Basis.IDENTITY, Vector3(0, 0.75, 0)), Vector3(0.2, 1.5, 0.2), Palette.WOOD, 0.02)
		MeshKit.add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.45, 0.08, 0.1)), 0.42, 0.36, 0.16, 10, Color("#C9A66B"))
		MeshKit.add_cylinder(st, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.55, 0.0)), 0.13, 0.06, 0.18, 8, Color("#D8B04A"))
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.finish(st)
		mi.material_override = Materials.toon(0.02)
		add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.6, 1.7, 0.6)
		col.shape = bs
		col.position = Vector3(0, 0.85, 0)
		add_child(col)

	func interact_prompt() -> String:
		if anchor.busy():
			return "Rope Winch  -  someone's on the rope"
		return "Rope Winch  -  back up to the lip (%d s)\nE: ride up" % int(ExpeditionRules.RIDE_TIME)

	func local_interact(holding: bool) -> void:
		if holding:
			return
		var me := Expedition.player_node(multiplayer.get_unique_id())
		if me != null:
			me.start_rope(anchor, false)
