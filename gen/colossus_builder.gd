class_name ColossusBuilder
extends RefCounted
## The landmarks out on the far lands (Logan: "really lean into stuff like the
## giant bug skeletons but of a much higher quality and more polished"):
##   - the Great Ribs: a colossal beetle's spine and rib cage, 220 m long, half
##     sunk in a dune sea, its head and mandibles at one end;
##   - the Skull: a giant ant's head capsule tipped on its side in the sand, eye
##     sockets, broken antennae and a pair of crossed mandibles;
##   - the Mandible Arch: two mandibles 100 m high meeting over a dune valley;
##   - the Leg Field: a buried spider's jointed legs breaking out of the sand;
## with bone scatter round each, and the derelicts of the people who came before:
## a broken railway trestle across a wash, a leaning telegraph line, and the
## burnt-out frame of a crashed airship.
## Bones are bleached ivory with darker joints and sand-stained feet; all built
## from MeshKit tubes, lathes and ellipsoids, one mesh per kind, no shadows.
## Placed by bearing and distance from the middle, nudged toward the sand.

const BONE := Color("#EADFC6")
const BONE_DK := Color("#B9A684")
const BONE_STAIN := Color("#C9A272")
const SOCKET := Color("#3A2A22")
const IRON := Color("#4A3A32")
const RUST := Color("#8A4A2A")
const TIMBER := Color("#6A4A32")

var far: FarLands
## (x, z) -> ground height (the map's ground plus the far field).
var ground: Callable
var _rng := RandomNumberGenerator.new()
## Where the landmarks went (for the gallery and the dust): [name, position].
var placed: Array = []
## The last build's landmarks, for the UI gallery's close-ups.
static var last_placed: Array = []


func _init(far_lands: FarLands, ground_height: Callable) -> void:
	far = far_lands
	ground = ground_height
	_rng.seed = 6061


## Builds every landmark under `parent`. `spots`: [name, bearing degrees (from
## +X toward +Z), distance] overrides; the canyon's defaults put the arch and
## the ribs down the canyon's two ends (seen along it from the play area) and the
## skull, legs and derelicts off to the sides (seen from the airship).
func build(parent: Node3D, spots: Array = []) -> void:
	if spots.is_empty():
		spots = [["ribs", -90.0, 1040.0], ["arch", 90.0, 1060.0], ["skull", 205.0, 640.0], ["legs", 20.0, 700.0],
			["trestle", 150.0, 820.0], ["telegraph", -30.0, 560.0], ["wreck", -150.0, 900.0]]
	var bones := MeshKit.begin()
	var junk := MeshKit.begin()
	for s: Array in spots:
		var at := _spot(float(s[1]), float(s[2]), str(s[0]) in ["ribs", "skull", "legs", "arch"])
		placed.append([s[0], at])
		var yaw := atan2(at.x - far.center.x, at.z - far.center.y) # (lengthwise along the bearing)
		match str(s[0]):
			"ribs":
				_great_ribs(bones, at, yaw + PI * 0.5)
			"skull":
				_skull(bones, at, yaw + 1.2, 1.45)
			"arch":
				_mandible_arch(bones, at, yaw)
			"legs":
				_leg_field(bones, at, yaw)
			"trestle":
				_trestle(junk, at, yaw + PI * 0.5)
			"telegraph":
				_telegraph(junk, at, yaw + PI * 0.5)
			"wreck":
				_wreck(junk, bones, at, yaw + 0.6)
	last_placed = placed
	var mat := Materials.toon(0.0).duplicate() as ShaderMaterial
	mat.set_shader_parameter("spec_strength", 0.15)
	for part: Array in [["ColossusBones", bones], ["Derelicts", junk]]:
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = MeshKit.finish(part[1])
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## The ground point at `bearing`/`dist`, turned a little toward the deepest sand
## when `sandy` (the bones look best half buried in a dune sea).
func _spot(bearing: float, dist: float, sandy: bool) -> Vector3:
	var best := deg_to_rad(bearing)
	if sandy:
		var best_sand := -1.0
		for k in 9:
			var a := deg_to_rad(bearing + (k - 4) * 4.0)
			var p := far.center + Vector2(cos(a), sin(a)) * dist
			var sand := far.field(p.x, p.y).y
			if sand > best_sand + 0.05:
				best_sand = sand
				best = a
	var p := far.center + Vector2(cos(best), sin(best)) * dist
	return Vector3(p.x, float(ground.call(p.x, p.y)), p.y)


func _h(x: float, z: float) -> float:
	return float(ground.call(x, z))


## A bone colour by how high above the sand it is: stained at the foot, bleached above.
func _bone_at(p: Vector3, base: Color = BONE) -> Color:
	var above := p.y - _h(p.x, p.z)
	return base.lerp(BONE_STAIN, 1.0 - smoothstep(0.0, 6.0, above)).darkened(_rng.randf() * 0.04)


## A tapering curved bone through `pts` (radii from r0 to r1), knobbed at the ends.
func _bone(st: SurfaceTool, pts: Array, r0: float, r1: float, segs: int = 10) -> void:
	var radii: Array = []
	for i in pts.size():
		var t := float(i) / maxf(pts.size() - 1, 1)
		radii.append(lerpf(r0, r1, t) * (1.0 + 0.12 * sin(t * PI * 3.0)))
	MeshKit.tube(st, pts, radii, segs, _bone_at(pts[pts.size() / 2]))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), pts[0]), Vector3.ONE * r0 * 1.25, 4, 10, _bone_at(pts[0], BONE_DK))


## A curve of `n` points from `a` to `b` bowed by `bow` (a vector) at its middle.
static func _arc(a: Vector3, b: Vector3, bow: Vector3, n: int = 10, power: float = 1.0) -> Array:
	var out: Array = []
	for i in n:
		var t := float(i) / (n - 1)
		out.append(a.lerp(b, t) + bow * pow(sin(t * PI), power))
	return out


# ------------------------------------------------------------------ the Great Ribs

## A colossal beetle: a sinuous spine of ridged vertebrae, 13 pairs of ribs
## arching out and down into the sand (biggest mid-body), the head capsule with
## its mandibles at the front, a few legs sticking up, sunk at both ends.
func _great_ribs(st: SurfaceTool, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var length := 220.0
	var n := 26
	var spine: Array = []
	for i in n:
		var t := float(i) / (n - 1)
		var local := Vector3(sin(t * PI * 1.3) * 9.0, 0.0, (t - 0.5) * length)
		var w := at + b * local
		var lift := 28.0 * sin(t * PI) - 8.0 + 4.0 * sin(t * PI * 3.0)
		w.y = _h(w.x, w.z) + lift
		spine.append(w)
	# Vertebrae: ridged drums along the spine, a dorsal spike on every other one.
	for i in n - 1:
		var p0: Vector3 = spine[i]
		var p1: Vector3 = spine[i + 1]
		var mid := (p0 + p1) * 0.5
		var dir := (p1 - p0).normalized()
		var vb := MeshKit.basis_from_y(dir)
		var r := 5.2 * (0.6 + 0.4 * sin(float(i) / (n - 1) * PI))
		MeshKit.lathe(st, Transform3D(vb, mid - dir * 4.0), [Vector2(r * 0.7, 0.0), Vector2(r, 1.2), Vector2(r * 1.05, 3.5),
				Vector2(r * 0.8, 5.6), Vector2(r * 0.95, 7.0), Vector2(r * 0.6, 8.2)], 12, _bone_at(mid))
		# Transverse processes: stubby wings either side of each vertebra.
		var flank := (b * Vector3(1, 0, 0)).normalized()
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(flank * sx + Vector3.UP * 0.3), mid + flank * sx * r * 1.4), r * 0.35, r * 0.15, r * 1.6, 7, _bone_at(mid, BONE_DK))
		if i % 2 == 0:
			var up := (b * Vector3.UP).normalized()
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(up + dir * 0.4), mid + up * (r + 3.0)), r * 0.45, r * 0.05, 7.0, 8, _bone_at(mid + up * 4.0, BONE_DK))
	# Ribs: a pair off every other vertebra, swelling out from the spine and
	# curving down into the sand: a domed cage, deepest mid-body.
	for i in range(3, n - 4, 2):
		var t := float(i) / (n - 1)
		var root: Vector3 = spine[i]
		var size := 0.45 + 0.55 * sin(t * PI)
		for side: float in [-1.0, 1.0]:
			var out := (b * Vector3(side, 0, 0)).normalized()
			var back := (b * Vector3(0, 0, -1)).normalized()
			var reach := 26.0 + 22.0 * size
			var drop := root.y - _h(root.x + out.x * reach, root.z + out.z * reach) + 5.0
			var pts: Array = []
			for k in 14:
				var th := float(k) / 13.0 * PI * 0.5
				# Out along a quarter ellipse, a touch further out at the shoulder, swept back.
				var p := root + out * (reach * sin(th) + 6.0 * sin(th * 2.0) * size) - Vector3.UP * drop * (1.0 - cos(th)) + Vector3.UP * 4.0 * sin(th * 2.0) + back * 9.0 * sin(th)
				pts.append(p)
			_bone(st, pts, 2.9 * (0.6 + 0.4 * size), 1.0, 10)
	# The head at the front end: a capsule with mandibles, tilted into the sand.
	var head: Vector3 = spine[n - 1] + b * Vector3(0, 0, 18.0)
	head.y = _h(head.x, head.z) + 4.0
	_skull(st, head, yaw, 0.55)
	# A few legs, broken off, standing up out of the sand beside the cage.
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		var foot := at + b * Vector3(side * (52.0 + _rng.randf_range(0.0, 14.0)), 0, -50.0 + k * 34.0)
		foot.y = _h(foot.x, foot.z) - 4.0
		_leg(st, foot, b * Vector3(-side * 0.4, 1.0, 0.2), 34.0 + _rng.randf_range(-6.0, 8.0), 2.4, _rng.randf() < 0.5)
	_scatter_bones(st, at, 120.0, 16)


# ------------------------------------------------------------------ the Skull

## A giant ant's head capsule (size 1 = 70 m long): a domed capsule tipped on its
## side and sunk in the sand, a front plate, two deep eye sockets, antenna
## sockets with broken antennae, and the mandibles crossed in front.
func _skull(st: SurfaceTool, at: Vector3, yaw: float, size: float) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.7 * minf(size, 1.0)) * Basis(Vector3.RIGHT, -0.12)
	var s := size
	var c := at + Vector3(0, 6.0 * s, 0)
	MeshKit.add_ellipsoid(st, Transform3D(b, c), Vector3(26.0, 20.0, 32.0) * s, 10, 18, _bone_at(c))
	# The crown ridge and the plates over the cheeks.
	MeshKit.add_ellipsoid(st, Transform3D(b, c + b * Vector3(0, 13.0, -4.0) * s), Vector3(9.0, 8.0, 24.0) * s, 6, 12, _bone_at(c + Vector3(0, 13.0 * s, 0), BONE))
	for side: float in [-1.0, 1.0]:
		MeshKit.add_ellipsoid(st, Transform3D(b, c + b * Vector3(side * 15.0, -4.0, 12.0) * s), Vector3(9.0, 10.0, 13.0) * s, 6, 12, _bone_at(c + Vector3(0, 8.0 * s, 0), BONE))
		# Eye socket: a long oval hollow on the side of the head (an insect's
		# compound eye, not a face), under a ridged brow.
		var eye := c + b * Vector3(side * 24.5, 4.0, 6.0) * s
		MeshKit.add_ellipsoid(st, Transform3D(b * Basis(Vector3.UP, side * 0.25), eye), Vector3(3.5, 7.0, 11.0) * s, 6, 12, SOCKET)
		MeshKit.add_ellipsoid(st, Transform3D(b * Basis(Vector3.UP, side * 0.25), eye + b * Vector3(-side * 1.2, 6.5, 0.0) * s), Vector3(5.0, 2.0, 12.5) * s, 4, 10, _bone_at(eye, BONE))
		# Ridges sweeping back over the crown.
		var ridge := _arc(c + b * Vector3(side * 6.0, 16.0, 22.0) * s, c + b * Vector3(side * 12.0, 12.0, -26.0) * s, b * Vector3(side * 2.0, 6.0, 0.0) * s, 9)
		_bone(st, ridge, 1.6 * s, 0.6 * s, 7)
		# Antenna socket and a broken antenna, jointed, lying back over the head.
		var ant := c + b * Vector3(side * 8.0, 14.0, 20.0) * s
		MeshKit.add_ellipsoid(st, Transform3D(b, ant), Vector3.ONE * 3.6 * s, 4, 10, SOCKET)
		var pts := _arc(ant, ant + b * Vector3(side * 14.0, 26.0, -24.0) * s, b * Vector3(side * 4.0, 6.0, 4.0) * s, 9)
		_bone(st, pts, 1.8 * s, 0.9 * s, 8)
		# Mandibles: broad curved blades, toothed on the inside, crossing at the tips.
		var root := c + b * Vector3(side * 9.0, -9.0, 30.0) * s
		var tip := c + b * Vector3(-side * 10.0, -12.0, 62.0) * s
		var mpts := _arc(root, tip, b * Vector3(side * 18.0, 3.0, 0.0) * s, 14, 0.8)
		var mr: Array = []
		for k in mpts.size():
			var t := float(k) / (mpts.size() - 1)
			mr.append(lerpf(6.5, 0.6, pow(t, 0.8)) * s)
		MeshKit.tube(st, mpts, mr, 12, _bone_at(mpts[4]))
		for k in range(2, 11):
			var p: Vector3 = mpts[k]
			var t := float(k) / 13.0
			var tooth := (1.0 - absf(t - 0.4) * 2.2) * (1.0 if k % 2 == 0 else 0.55)
			if tooth <= 0.1:
				continue
			var inward := (b * Vector3(-side, 0, 0.3)).normalized()
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(inward), p + inward * float(mr[k]) * 0.8), (1.6 * tooth + 0.4) * s, 0.08 * s, (5.0 * tooth + 1.0) * s, 7, _bone_at(p, BONE_DK))
	# The front plate over the mouth, and a hole punched in the crown.
	MeshKit.add_ellipsoid(st, Transform3D(b, c + b * Vector3(0, -7.0, 27.0) * s), Vector3(9.0, 5.0, 5.0) * s, 5, 12, _bone_at(c + Vector3(0, 8.0 * s, 0), BONE))
	MeshKit.add_ellipsoid(st, Transform3D(b * Basis(Vector3.RIGHT, 0.4), c + b * Vector3(-7.0, 17.5, -6.0) * s), Vector3(6.0, 2.0, 8.0) * s, 5, 10, SOCKET)
	if size >= 0.9:
		_scatter_bones(st, at, 70.0, 10)


# ------------------------------------------------------------------ the Mandible Arch

## Two great mandibles rising out of the sand either side of a dune valley and
## crossing at the top, 100 m high: a gateway seen down the canyon.
func _mandible_arch(st: SurfaceTool, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	for side: float in [-1.0, 1.0]:
		var foot := at + b * Vector3(side * 70.0, 0.0, 0.0)
		foot.y = _h(foot.x, foot.z) - 8.0
		var tip := at + b * Vector3(-side * 18.0, 0.0, 6.0 * side)
		tip.y = foot.y + 104.0
		var pts := _arc(foot, tip, b * Vector3(side * 26.0, 0.0, 0.0) + Vector3.UP * 10.0, 18, 0.9)
		var radii: Array = []
		for k in pts.size():
			var t := float(k) / (pts.size() - 1)
			# Broad at the root, a swell where the big teeth sit, then a long point.
			radii.append(lerpf(13.0, 1.0, pow(t, 0.8)) * (1.0 + 0.18 * exp(-pow((t - 0.45) * 6.0, 2.0))))
		MeshKit.tube(st, pts, radii, 14, _bone_at(pts[6]))
		# A row of teeth along the inner edge, biggest in the middle.
		for k in range(3, 15):
			var p: Vector3 = pts[k]
			var t := float(k) / 17.0
			var tooth := (1.0 - absf(t - 0.42) * 1.9) * (1.0 if k % 2 == 0 else 0.6)
			if tooth <= 0.1:
				continue
			var tangent := ((pts[k + 1] as Vector3) - (pts[k - 1] as Vector3)).normalized()
			var inward := (b * Vector3(-side, 0.0, 0.0)).normalized()
			inward = (inward - tangent * inward.dot(tangent)).normalized()
			var rr: float = radii[k]
			MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y(inward + tangent * 0.35), p + inward * rr * 0.8), 2.6 * tooth + 0.6, 0.15, 10.0 * tooth + 2.0, 8, _bone_at(p, BONE_DK))
		# The jaw socket: a knuckled mass where the mandible leaves the sand.
		MeshKit.add_ellipsoid(st, Transform3D(b, foot + Vector3(0, 9.0, 0)), Vector3(19.0, 13.0, 16.0), 7, 14, _bone_at(foot + Vector3(0, 12, 0), BONE_DK))
		MeshKit.add_ellipsoid(st, Transform3D(b, foot + b * Vector3(side * 8.0, 15.0, 0)), Vector3(8.0, 6.0, 9.0), 5, 10, _bone_at(foot + Vector3(0, 16, 0), BONE))
	_scatter_bones(st, at, 90.0, 12)


# ------------------------------------------------------------------ the Leg Field

## A buried spider: six jointed legs breaking out of a dune, bent at the knees,
## a broken one lying flat, the hump of its back just showing.
func _leg_field(st: SurfaceTool, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var hump := at + Vector3(0, 2.0, 0)
	MeshKit.add_ellipsoid(st, Transform3D(b, hump), Vector3(24.0, 9.0, 30.0), 6, 14, _bone_at(hump + Vector3(0, 8, 0), BONE))
	for k in 6:
		var side := -1.0 if k % 2 == 0 else 1.0
		var row := float(k / 2) - 1.0
		var foot := at + b * Vector3(side * 26.0, 0.0, row * 24.0)
		foot.y = _h(foot.x, foot.z) - 3.0
		var up := b * Vector3(side * 0.6, 1.0, row * 0.25)
		_leg(st, foot, up, 62.0 + _rng.randf_range(-8.0, 10.0), 3.4, k == 5)
	_scatter_bones(st, at, 80.0, 10)


## A jointed leg from `foot` (in the sand): femur up and out, a knobbed knee,
## the tibia bent back down, a claw; `broken` snaps it at the knee.
func _leg(st: SurfaceTool, foot: Vector3, up: Vector3, length: float, r: float, broken: bool) -> void:
	var u := up.normalized()
	var side := u.cross(Vector3.UP).normalized() if absf(u.y) < 0.99 else Vector3.RIGHT
	var knee := foot + u * length * 0.55 + Vector3.UP * length * 0.12
	_bone(st, _arc(foot, knee, side * length * 0.05, 8), r, r * 0.75, 10)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), knee), Vector3.ONE * r * 1.35, 5, 10, _bone_at(knee, BONE_DK))
	if broken:
		return
	var out := Vector3(u.x, 0.0, u.z).normalized() if Vector2(u.x, u.z).length() > 0.05 else Vector3.FORWARD
	var claw := knee + out * length * 0.42 - Vector3.UP * length * 0.3
	var pts := _arc(knee, claw, Vector3.UP * length * 0.08, 8)
	_bone(st, pts, r * 0.75, r * 0.3, 10)
	MeshKit.add_cylinder(st, Transform3D(MeshKit.basis_from_y((claw - knee).normalized()), claw + (claw - knee).normalized() * r * 1.2), r * 0.35, 0.05, r * 3.0, 6, _bone_at(claw, BONE_DK))


## Loose bones round a landmark: rib fragments, vertebrae and plates half sunk.
func _scatter_bones(st: SurfaceTool, at: Vector3, r: float, n: int) -> void:
	for k in n:
		var a := _rng.randf() * TAU
		var p := at + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(r * 0.5, r)
		p.y = _h(p.x, p.z) - 0.6
		match k % 3:
			0:
				var blen := _rng.randf_range(10.0, 22.0)
				var dir := Vector3(cos(a + 1.3), 0, sin(a + 1.3))
				_bone(st, _arc(p - dir * blen * 0.5, p + dir * blen * 0.5, Vector3.UP * blen * 0.25, 7), _rng.randf_range(0.8, 1.4), 0.5, 8)
			1:
				var rr := _rng.randf_range(2.0, 3.5)
				MeshKit.lathe(st, Transform3D(MeshKit.basis_from_y(Vector3(cos(a), 0.6, sin(a)).normalized()), p), [Vector2(rr * 0.7, 0.0),
						Vector2(rr, 1.0), Vector2(rr * 0.8, 2.6), Vector2(rr * 0.6, 3.4)], 10, _bone_at(p + Vector3.UP))
			_:
				MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, 0.4), p), Vector3(_rng.randf_range(4.0, 8.0), 1.2, _rng.randf_range(3.0, 6.0)), 4, 10, _bone_at(p + Vector3.UP * 2.0, BONE))


# ------------------------------------------------------------------ derelicts

## A railway trestle across a wash: timber bents under a deck, rails on top,
## and a broken span sagging into the gap.
func _trestle(st: SurfaceTool, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var spans := 16
	var step := 12.0
	var top := at.y + 24.0
	for k in spans + 1:
		var c := at + b * Vector3(0, 0, (k - spans * 0.5) * step)
		var gy := _h(c.x, c.z)
		var broken := k == 7 or k == 8
		var h := top - gy
		if h < 2.0:
			continue
		var bent_top := top - (8.0 if broken else 0.0)
		for sx: float in [-3.2, -1.1, 1.1, 3.2]:
			var lean := 0.08 * signf(sx) if absf(sx) > 2.0 else 0.0
			var foot := c + b * Vector3(sx + lean * h, 0, 0)
			foot.y = gy - 1.0
			var head := c + b * Vector3(sx * 0.8, 0, 0)
			head.y = bent_top
			MeshKit.add_limb(st, foot, head, 0.35, TIMBER.darkened(_rng.randf() * 0.15), 5)
		# Cross bracing.
		for y in range(1, int(h / 8.0) + 1):
			var yy := gy + y * 8.0
			if yy > bent_top - 2.0:
				break
			var l := c + b * Vector3(-3.2, 0, 0)
			var r := c + b * Vector3(3.2, 0, 0)
			MeshKit.add_limb(st, Vector3(l.x, yy, l.z), Vector3(r.x, yy + 6.0, r.z), 0.18, TIMBER.darkened(0.1), 4)
			MeshKit.add_limb(st, Vector3(r.x, yy, r.z), Vector3(l.x, yy + 6.0, l.z), 0.18, TIMBER.darkened(0.1), 4)
		MeshKit.add_box(st, Transform3D(b, Vector3(c.x, bent_top + 0.3, c.z)), Vector3(8.0, 0.6, 1.0), TIMBER)
	# The deck and rails, the two broken spans hanging down.
	for k in spans:
		var a := at + b * Vector3(0, 0, (k - spans * 0.5) * step)
		var e := at + b * Vector3(0, 0, (k + 1 - spans * 0.5) * step)
		var ya := top - (8.0 if k == 7 or k == 8 else 0.0)
		var ye := top - (8.0 if k + 1 == 7 or k + 1 == 8 else 0.0)
		if k == 7:
			ye = top - 18.0
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_limb(st, Vector3(a.x, ya + 0.8, a.z) + b * Vector3(sx * 0.9, 0, 0), Vector3(e.x, ye + 0.8, e.z) + b * Vector3(sx * 0.9, 0, 0), 0.12, IRON, 4)
		MeshKit.add_limb(st, Vector3(a.x, ya + 0.55, a.z), Vector3(e.x, ye + 0.55, e.z), 0.9, TIMBER.darkened(0.2), 4)


## A telegraph line marching off across the dunes: poles leaning every which
## way, cross arms, a few down, the wire sagging between those still standing.
func _telegraph(st: SurfaceTool, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var prev_top := Vector3.INF
	for k in 22:
		var c := at + b * Vector3(_rng.randf_range(-2.0, 2.0), 0, (k - 11) * 34.0)
		c.y = _h(c.x, c.z) - 1.0
		if _rng.randf() < 0.15:
			# Down: lying in the sand.
			var dir := b * Vector3(1, 0, 0.3).normalized()
			MeshKit.add_limb(st, c + Vector3(0, 0.5, 0), c + dir * 9.0 + Vector3(0, 0.4, 0), 0.25, TIMBER.darkened(0.25), 5)
			prev_top = Vector3.INF
			continue
		var lean := Vector3(_rng.randf_range(-0.18, 0.18), 1.0, _rng.randf_range(-0.18, 0.18)).normalized()
		var top := c + lean * 10.0
		MeshKit.add_limb(st, c, top, 0.24, TIMBER.darkened(_rng.randf() * 0.2), 5)
		MeshKit.add_box(st, Transform3D(MeshKit.basis_from_y(lean) * Basis(Vector3.UP, yaw + PI * 0.5), top - lean * 0.8), Vector3(3.2, 0.25, 0.25), TIMBER.darkened(0.15))
		if prev_top != Vector3.INF:
			var pts: Array = []
			var radii: Array = []
			for j in 7:
				var t := j / 6.0
				pts.append(prev_top.lerp(top, t) - Vector3.UP * sin(t * PI) * 2.2 - lean * 0.6)
				radii.append(0.05)
			MeshKit.tube(st, pts, radii, 3, Color("#2A221E"))
		prev_top = top


## A crashed airship: the ribbed frame of its envelope broken in two and half
## buried, rags of canvas, the gondola on its side and a bent propeller.
func _wreck(st: SurfaceTool, bones: SurfaceTool, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.12)
	var length := 120.0
	var r := 16.0
	for k in 12:
		var t := float(k) / 11.0
		var z := (t - 0.5) * length
		var rr := r * sqrt(maxf(1.0 - pow((t - 0.5) * 2.0, 2.0), 0.08))
		var c := at + b * Vector3(0, rr * 0.55 - 4.0 - (10.0 if t > 0.62 else 0.0), z)
		# One hoop of the frame, broken where it meets the sand.
		var pts: Array = []
		var radii: Array = []
		for j in 13:
			var a := PI * (-0.1 + 1.2 * j / 12.0)
			pts.append(c + b * Vector3(cos(a) * rr, sin(a) * rr, 0))
			radii.append(0.45)
		MeshKit.tube(st, pts, radii, 5, RUST.darkened(0.1 * (k % 2)))
	# Long girders along the top and sides, snapped at the break.
	for g in 5:
		var a := PI * (0.1 + 0.8 * g / 4.0)
		for half in 2:
			var z0 := -length * 0.5 if half == 0 else length * 0.14
			var z1 := length * 0.08 if half == 0 else length * 0.5
			var drop := 0.0 if half == 0 else 10.0
			var p0 := at + b * Vector3(cos(a) * r * 0.7, sin(a) * r * 0.7 - drop, z0)
			var p1 := at + b * Vector3(cos(a) * r * 0.9, sin(a) * r * 0.9 - drop, z1)
			MeshKit.add_limb(st, p0, p1, 0.35, RUST, 5)
	# Canvas rags hanging from the frame.
	for k in 7:
		var c := at + b * Vector3(_rng.randf_range(-r, r) * 0.7, r * 0.6, _rng.randf_range(-length, length) * 0.4)
		MeshKit.add_box(st, Transform3D(b * Basis(Vector3.BACK, _rng.randf_range(-0.6, 0.6)), c), Vector3(_rng.randf_range(6.0, 12.0), _rng.randf_range(6.0, 10.0), 0.2), Color("#C9B48A").darkened(_rng.randf() * 0.3))
	# The gondola on its side, and a bent propeller.
	var g := at + b * Vector3(r * 1.4, 2.0, length * 0.18)
	g.y = _h(g.x, g.z) + 2.0
	MeshKit.add_box(st, Transform3D(b * Basis(Vector3.BACK, 1.3), g), Vector3(8.0, 5.0, 26.0), TIMBER.darkened(0.2))
	var prop := g + b * Vector3(-3.0, 6.0, -16.0)
	for k in 3:
		var a := TAU * k / 3.0
		MeshKit.add_box(st, Transform3D(b * Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.4), prop + b * Vector3(cos(a), sin(a), 0) * 2.2), Vector3(4.4, 0.8, 0.25), IRON)
	_scatter_bones(bones, at, 70.0, 6)
