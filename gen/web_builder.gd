class_name WebBuilder
extends RefCounted
## Spider silk for the canyon: orb webs plastered on the cliff walls, tattered
## sheet webs and egg sacs on the floor, and long strands strung across the
## canyon low down. Every web is thin ribbons in one batched mesh per area,
## drawn with a soft translucent white material (see material()).

static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	return m


## A thin silk ribbon from a to b, lying in the plane facing `n`.
static func strand(st: SurfaceTool, a: Vector3, b: Vector3, n: Vector3, width: float, col: Color) -> void:
	var side := (b - a).cross(n)
	if side.length_squared() < 0.000001:
		return
	side = side.normalized() * width * 0.5
	MeshKit.quad(st, a - side, b - side, b + side, a + side, n, col)


## An orb web centred at c on a surface with normal n, about `radius` across.
## `tatter` (0..1) is the chance each spiral segment is torn away.
static func orb(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, n: Vector3, radius: float, tatter: float) -> void:
	var up := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var r := up.cross(n).normalized()
	var u := n.cross(r).normalized()
	var spokes := rng.randi_range(9, 14)
	var angles: Array[float] = []
	var lengths: Array[float] = []
	for i in spokes:
		angles.append(TAU * (float(i) + rng.randf_range(-0.25, 0.25)) / float(spokes))
		lengths.append(radius * rng.randf_range(0.75, 1.15))
	var silk := Color(1, 1, 1, 0.7)
	var faint := Color(1, 1, 1, 0.45)
	for i in spokes:
		var tip := c + (r * cos(angles[i]) + u * sin(angles[i])) * lengths[i]
		strand(st, c, tip, n, 0.035 * radius / 2.0 + 0.015, silk)
	var rings := rng.randi_range(6, 10)
	for k in rings:
		var f := (float(k) + 1.0) / (float(rings) + 1.0)
		for i in spokes:
			if rng.randf() < tatter:
				continue
			var j := (i + 1) % spokes
			var a := c + (r * cos(angles[i]) + u * sin(angles[i])) * lengths[i] * f
			var b := c + (r * cos(angles[j]) + u * sin(angles[j])) * lengths[j] * f
			# Sag slightly toward the centre so it reads as silk, not wire.
			var mid := (a + b) * 0.5 - (((a + b) * 0.5) - c) * 0.06
			strand(st, a, mid, n, 0.02 + 0.01 * radius / 3.0, faint)
			strand(st, mid, b, n, 0.02 + 0.01 * radius / 3.0, faint)
	# Anchor lines out to the rock.
	for i in 3:
		var a := TAU * rng.randf()
		var from := c + (r * cos(a) + u * sin(a)) * radius
		strand(st, from, from + (r * cos(a) + u * sin(a)) * radius * rng.randf_range(0.4, 0.9), n, 0.03, silk)


## A sagging sheet web on the ground: a translucent patch with criss-cross silk.
static func sheet(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, size: float, height_at: Callable) -> void:
	var pts: Array[Vector3] = []
	var count := rng.randi_range(6, 9)
	for i in count:
		var a := TAU * float(i) / float(count) + rng.randf_range(-0.2, 0.2)
		var d := size * rng.randf_range(0.6, 1.0)
		var p := c + Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = float(height_at.call(p.x, p.z)) + rng.randf_range(0.3, 1.1) # pinned to stones and stalks
		pts.append(p)
	var hub := c + Vector3(0, 0.15, 0)
	hub.y = float(height_at.call(c.x, c.z)) + 0.15
	var film := Color(1, 1, 1, 0.22)
	for i in count:
		var a := pts[i]
		var b := pts[(i + 1) % count]
		MeshKit.tri(st, hub, a, b, Vector3.UP, Vector3.UP, Vector3.UP, film, Vector3.UP)
		strand(st, hub, a, Vector3.UP, 0.04, Color(1, 1, 1, 0.6))
		strand(st, a, b, Vector3.UP, 0.03, Color(1, 1, 1, 0.5))
	for i in 10:
		var a := pts[rng.randi() % count]
		var b := pts[rng.randi() % count]
		strand(st, a, b, Vector3.UP, 0.025, Color(1, 1, 1, 0.4))


## A cluster of pale egg sacs.
static func egg_sacs(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3) -> void:
	for i in rng.randi_range(2, 5):
		var p := c + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.1, 0.3), rng.randf_range(-0.5, 0.5))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(0.22, 0.28, 0.22) * rng.randf_range(0.8, 1.3), 4, 8,
				Color(0.95, 0.93, 0.86, 0.9))
