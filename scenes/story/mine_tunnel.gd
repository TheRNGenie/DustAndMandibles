class_name MineTunnel
extends Node3D
## Down the Hole: the inside of the main tunnel, a short walkable set. The
## railroad's 1889 survey adit: timber sets and rails, hung lanterns, then the
## bugs' own work deeper in (rock glazed with glowing hive resin) opening into
## a warm chamber of egg sacs with the hive hole at the back. The charge spots
## are chalk-marked down both walls.
##
## Built far under the main tunnel's mouth (BlastRules.SET_DROP) so it never
## touches the map: E at the mouth fades you in, E at the daylight fades you
## out (DownTheHole). Local frame: the entrance is at the origin and the tunnel
## runs down -Z; +Z points out of the mouth. Bugs in here walk its floor
## (Bug.UNDERGROUND_Y).

## Metres in where the timbered tunnel ends and the chamber begins, and its end.
const TUNNEL_END := 29.0
const CHAMBER_END := 42.0
const TUNNEL_W := 4.6
const TUNNEL_H := 3.8
const CHAMBER_W := 9.0
const CHAMBER_H := 6.2
## The first charge spot (metres in) and the last.
const FIRST_SPOT := 9.0
const LAST_SPOT := 39.0
## The set's meshes draw on this visual layer only, which the sun doesn't light
## (it's underground: only the lanterns, the resin and the daylight do).
const LAYER := 1 << 19

var director: DownTheHole
var spots: Array[ChargeSpot] = []
var _spot_root: Node3D


## Width / height of the bore `d` metres in.
static func width_at(d: float) -> float:
	return lerpf(TUNNEL_W, CHAMBER_W, smoothstep(TUNNEL_END - 0.5, TUNNEL_END + 2.5, d))


static func height_at(d: float) -> float:
	return lerpf(TUNNEL_H, CHAMBER_H, smoothstep(TUNNEL_END - 0.5, TUNNEL_END + 3.5, d))


## Local point `d` metres in, `x` across, `y` up.
static func local_at(d: float, x: float, y: float) -> Vector3:
	return Vector3(x, y, -d)


func _ready() -> void:
	if DayCycle.instance != null and DayCycle.instance.sun != null:
		DayCycle.instance.sun.light_cull_mask &= ~LAYER
	_build_rock()
	_build_props()
	_build_collision()
	_build_lights()
	var exit := ExitDoor.new()
	exit.name = "Daylight"
	exit.director = director
	add_child(exit)
	exit.position = local_at(0.15, 0.0, 0.0)
	_spot_root = Node3D.new()
	_spot_root.name = "Spots"
	add_child(_spot_root)


## Where you stand having just come in (world), and the hive hole (world, on the floor).
func entrance_stand() -> Vector3:
	return to_global(local_at(2.2, 0.0, 0.1))


func hive_hole() -> Vector3:
	return to_global(local_at(CHAMBER_END - 0.6, 0.0, 0.0))


func floor_y() -> float:
	return global_position.y


## Is a world point inside this set (a player's position)?
func holds(pos: Vector3) -> bool:
	var l := to_local(pos)
	return l.y > -3.0 and l.y < CHAMBER_H + 2.0 and l.z < 1.5 and l.z > -CHAMBER_END - 1.5 and absf(l.x) < CHAMBER_W


## (Re)lays `count` charge spots (the job's size can only be known once the posse is in).
func lay_spots(count: int) -> void:
	if spots.size() == count:
		return
	for s in spots:
		s.queue_free()
	spots.clear()
	var i := 0
	for sp: Array in BlastRules.charge_spots(count, FIRST_SPOT, LAST_SPOT):
		var d := float(sp[0])
		var side := float(sp[1])
		var s := ChargeSpot.new()
		s.name = "Spot%d" % i
		s.index = i
		s.director = director
		s.side = side
		s.depth = d
		_spot_root.add_child(s)
		s.position = local_at(d, side * (width_at(d) * 0.5 - 0.55), 0.0)
		s.rotation.y = -side * PI * 0.5 # its front faces the middle of the bore
		spots.append(s)
		i += 1


func show_set(set_flags: Array) -> void:
	for i in spots.size():
		spots[i].set_charged(i < set_flags.size() and bool(set_flags[i]))


# ------------------------------------------------------------------ the rock

## The bore: a boxy arch extruded down the tunnel, roughened with noise, hive
## resin creeping in the deeper you go, then the end wall with the hive hole
## and the daylight at the entrance.
func _build_rock() -> void:
	var st := MeshKit.begin()
	var noise := FastNoiseLite.new()
	noise.seed = 7007
	noise.frequency = 0.45
	var resin_n := FastNoiseLite.new()
	resin_n.seed = 77
	resin_n.frequency = 0.3
	var segs := 18
	var rings: Array = []
	var d := 0.0
	var step := 0.75
	while d <= CHAMBER_END + 0.01:
		var ring: Array[Vector3] = []
		var w := width_at(d)
		var h := height_at(d)
		for k in segs + 1:
			var a := PI * float(k) / float(segs)
			var c := -cos(a)
			var s := sin(a)
			var x := signf(c) * pow(absf(c), 0.55) * w * 0.5
			var y := pow(s, 0.5) * h
			var p := Vector3(x, y, -d)
			var push := noise.get_noise_3d(x, y, d) * 0.6
			if k > 0 and k < segs:
				var n2 := Vector3(x, y - h * 0.35, 0).normalized()
				p += n2 * push
			else:
				p.x += signf(c) * absf(push) * 0.5
			ring.append(p)
		rings.append(ring)
		d += step
	var rock_a := Color("#3A2C28")
	var rock_b := Color("#5E4A40")
	var resin := Color("#D8862A")
	for r in rings.size() - 1:
		var ra: Array[Vector3] = rings[r]
		var rb: Array[Vector3] = rings[r + 1]
		var depth := -ra[0].z
		for k in segs:
			var p0 := ra[k]
			var p1 := ra[k + 1]
			var p2 := rb[k + 1]
			var p3 := rb[k]
			var mid := (p0 + p2) * 0.5
			var inward := Vector3(0, height_at(depth) * 0.4, mid.z) - mid
			var col := rock_a.lerp(rock_b, noise.get_noise_3d(mid.x * 2.0, mid.y * 2.0, mid.z) * 0.5 + 0.5)
			var glow := 0.0
			# Hive resin: none at the timbered mouth, more and more toward the chamber.
			var want := smoothstep(10.0, 34.0, depth)
			if resin_n.get_noise_3d(mid.x, mid.y, mid.z) * 0.5 + 0.5 < want * 0.4:
				col = resin.darkened(0.05 + 0.25 * (resin_n.get_noise_3d(mid.z, mid.x, mid.y) * 0.5 + 0.5))
				glow = 0.28
			var cc := MeshKit.vcol(col, glow)
			MeshKit.tri(st, p0, p1, p2, inward, inward, inward, cc, inward)
			MeshKit.tri(st, p0, p2, p3, inward, inward, inward, cc, inward)
		# Floor strip.
		var f0 := Vector3(ra[0].x, 0.0, ra[0].z)
		var f1 := Vector3(ra[segs].x, 0.0, ra[segs].z)
		var f2 := Vector3(rb[segs].x, 0.0, rb[segs].z)
		var f3 := Vector3(rb[0].x, 0.0, rb[0].z)
		var fc := Color("#4A2E22").lerp(Color("#5E3A28"), noise.get_noise_2d(depth * 3.0, 4.0) * 0.5 + 0.5)
		MeshKit.quad(st, f0, f1, f2, f3, Vector3.UP, MeshKit.vcol(fc))
	# End wall: a fan facing back up the tunnel, and the hive hole in it.
	var last: Array[Vector3] = rings[rings.size() - 1]
	var center := Vector3(0, CHAMBER_H * 0.45, -CHAMBER_END - 0.4)
	for k in segs:
		MeshKit.tri(st, last[k], last[k + 1], center, Vector3.BACK, Vector3.BACK, Vector3.BACK, MeshKit.vcol(rock_a.darkened(0.1)), Vector3.BACK)
	MeshKit.tri(st, last[0], last[segs], center, Vector3.BACK, Vector3.BACK, Vector3.BACK, MeshKit.vcol(rock_a.darkened(0.15)), Vector3.BACK)
	var hole := Vector3(0, 1.3, -CHAMBER_END + 0.15)
	for k in 3:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), hole + Vector3(0, 0, 0.05 * k)), Vector3(1.6 - k * 0.35, 1.35 - k * 0.3, 0.05),
				3, 16, Color("#0C0606").lightened(0.03 * (2 - k)))
	for k in 14: # resin lip round the hole
		var a := TAU * float(k) / 14.0
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), hole + Vector3(cos(a) * 1.75, sin(a) * 1.45, 0.15)), Vector3(0.38, 0.32, 0.2), 3, 6, resin.darkened(0.2), 0.0, null, 0.3)
	# The daylight at the entrance: the canyon floor in the sun, blown out.
	var first: Array[Vector3] = rings[0]
	var dc := Vector3(0, TUNNEL_H * 0.4, 0.35)
	for k in segs:
		var a := first[k] + Vector3(0, 0, 0.35)
		var b := first[k + 1] + Vector3(0, 0, 0.35)
		MeshKit.tri(st, a, b, dc, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, MeshKit.vcol(Color("#FFE7B8"), 1.0), Vector3.FORWARD)
	MeshKit.tri(st, first[0] + Vector3(0, 0, 0.35), first[segs] + Vector3(0, 0, 0.35), dc, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD,
			MeshKit.vcol(Color("#FFE7B8"), 1.0), Vector3.FORWARD)
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	mi.layers = LAYER
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(mi)


# ------------------------------------------------------------------ dressing

func _build_props() -> void:
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1889
	var wood := Palette.WOOD.darkened(0.15)
	var dark := Palette.WOOD_DARK.darkened(0.2)
	var iron := Palette.METAL.darkened(0.35)
	# Timber sets: two posts and a cap, every 3.5 m through the adit; the last
	# two are cracked and sagging where the bugs have been at them.
	var d := 1.4
	var n := 0
	while d < TUNNEL_END - 1.0:
		var hw := TUNNEL_W * 0.5 - 0.3
		var sag := 0.25 if d > 20.0 else 0.0
		var tilt := rng.randf_range(-0.04, 0.04)
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_box(st, Transform3D(Basis(Vector3.FORWARD, tilt * sx), local_at(d, sx * hw, 1.45)), Vector3(0.24, 2.9, 0.24), wood, 0.02, rng)
		var cap := Basis(Vector3.FORWARD, sag * 0.12)
		MeshKit.add_box(st, Transform3D(cap, local_at(d, 0.0, 2.98 - sag * 0.5)), Vector3(TUNNEL_W - 0.3, 0.24, 0.28), wood.lightened(0.05), 0.02, rng)
		# Lagging boards over the cap.
		for k in 4:
			MeshKit.add_box(st, Transform3D(Basis(), local_at(d - 0.6 + k * 0.4, rng.randf_range(-0.6, 0.6), 3.16)), Vector3(TUNNEL_W * 0.7, 0.05, 0.3), dark, 0.02, rng)
		# Wedges and a brace now and then.
		if n % 2 == 1:
			MeshKit.add_limb(st, local_at(d, -hw, 2.4), local_at(d - 1.4, -hw + 0.05, 0.2), 0.08, wood, 5)
		d += 3.5
		n += 1
	# Rails and sleepers out of the mouth to where the chamber starts (the far
	# end bent up by something big).
	var r := 0.0
	while r < TUNNEL_END - 2.0:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.04, 0.04)), local_at(r, 0.0, 0.05)), Vector3(1.5, 0.1, 0.22), dark, 0.02, rng)
		r += 0.75
	for sx: float in [-0.55, 0.55]:
		MeshKit.add_box(st, Transform3D(Basis(), local_at((TUNNEL_END - 6.0) * 0.5, sx, 0.15)), Vector3(0.07, 0.1, TUNNEL_END - 6.0), iron)
		MeshKit.add_limb(st, local_at(TUNNEL_END - 6.0, sx, 0.15), local_at(TUNNEL_END - 3.5, sx * 1.3, 0.9), 0.05, iron, 5)
	# An ore cart off the rails on its side, spilled.
	var cart := Transform3D(Basis(Vector3.FORWARD, 1.2) * Basis(Vector3.UP, 0.3), local_at(15.0, 1.25, 0.55))
	MeshKit.add_box(st, cart, Vector3(1.0, 0.8, 1.4), iron.lightened(0.1), 0.02, rng)
	MeshKit.add_box(st, cart * Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.85, 0.3, 1.25), Color("#24140E"))
	for k in 6:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), local_at(14.0 + rng.randf() * 2.0, 0.4 + rng.randf() * 1.2, 0.12)), Vector3(0.22, 0.14, 0.2), 3, 6, Palette.ROCK_B.darkened(0.3), 0.2, rng)
	# Old survey crates and a broken lantern by the entrance.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.2), local_at(4.2, -1.6, 0.3)), Vector3(0.6, 0.6, 0.6), wood.lightened(0.1), 0.03, rng)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -0.3), local_at(4.9, -1.65, 0.25)), Vector3(0.5, 0.5, 0.5), wood, 0.03, rng)
	# Lanterns hung on every other cap (lit, see _build_lights).
	for ld: float in _lantern_depths():
		var at := local_at(ld, 0.0, 2.55)
		MeshKit.add_limb(st, at + Vector3(0, 0.3, 0), at + Vector3(0, 0.15, 0), 0.015, iron, 3)
		MeshKit.add_box(st, Transform3D(Basis(), at), Vector3(0.22, 0.3, 0.22), iron)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), at), Vector3(0.12, 0.13, 0.12), 3, 6, Palette.GLOW_YELLOW, 0.0, null, 1.0)
	# The chamber: egg sacs in clusters round the walls, glowing faintly,
	# resin drips from the roof, bones of whatever wandered in.
	var egg := Color("#F2E6B8")
	var erng := RandomNumberGenerator.new()
	erng.seed = 4242
	for c in 9:
		var dd := erng.randf_range(TUNNEL_END + 1.0, CHAMBER_END - 1.5)
		var sx := -1.0 if c % 2 == 0 else 1.0
		var base := local_at(dd, sx * (width_at(dd) * 0.5 - 1.0), 0.0)
		for e in erng.randi_range(4, 8):
			var p := base + Vector3(erng.randf_range(-0.8, 0.8), erng.randf_range(0.3, 1.4), erng.randf_range(-0.9, 0.9))
			var rr := erng.randf_range(0.22, 0.4)
			MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.UP, erng.randf() * TAU), p), Vector3(rr, rr * 1.35, rr), 4, 8, egg.darkened(0.08 + erng.randf() * 0.15), 0.05, erng, 0.18)
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), base + Vector3(0, 0.05, 0)), Vector3(1.3, 0.12, 1.2), 3, 10, Color("#9A5E1A"), 0.0, null, 0.2)
	for k in 14:
		var dd := erng.randf_range(16.0, CHAMBER_END - 1.0)
		var top := height_at(dd) - 0.4
		var p := local_at(dd, erng.randf_range(-width_at(dd) * 0.3, width_at(dd) * 0.3), top)
		MeshKit.add_cylinder(st, Transform3D(Basis(), p - Vector3(0, 0.35, 0)), 0.02, 0.12, 0.7, 6, Color("#C27A26"), true, 0.3)
	for k in 5:
		var p := local_at(erng.randf_range(31.0, 40.0), erng.randf_range(-2.5, 2.5), 0.08)
		MeshKit.add_limb(st, p, p + Vector3(erng.randf_range(-0.7, 0.7), 0.05, erng.randf_range(-0.7, 0.7)), 0.06, Palette.BONE, 5)
	var mi := MeshInstance3D.new()
	mi.name = "Props"
	mi.layers = LAYER
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.02)
	add_child(mi)


func _lantern_depths() -> Array[float]:
	return [4.9, 11.9, 18.9, 25.9]


func _build_lights() -> void:
	for ld in _lantern_depths():
		var l := OmniLight3D.new()
		l.light_color = Color("#FFC27A")
		l.light_energy = 1.3
		l.omni_range = 7.0
		l.omni_attenuation = 1.2
		l.position = local_at(ld, 0.0, 2.3)
		add_child(l)
	for c: Array in [[TUNNEL_END + 4.0, Color("#FFB04A")], [CHAMBER_END - 3.0, Color("#B6E06A")]]:
		var l := OmniLight3D.new()
		l.light_color = c[1]
		l.light_energy = 2.0
		l.omni_range = 11.0
		l.position = local_at(float(c[0]), 0.0, 3.2)
		add_child(l)
	# Daylight spilling in at the mouth.
	var day := OmniLight3D.new()
	day.light_color = Color("#FFE7B8")
	day.light_energy = 2.5
	day.omni_range = 7.0
	day.position = local_at(0.6, 0.0, 2.0)
	add_child(day)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	body.collision_layer = WorldLayout.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	var mid_t := TUNNEL_END * 0.5
	var mid_c := (TUNNEL_END + CHAMBER_END) * 0.5
	var len_c := CHAMBER_END - TUNNEL_END + 1.0
	var boxes: Array = [
		[local_at(CHAMBER_END * 0.5, 0.0, -0.5), Vector3(CHAMBER_W + 4.0, 1.0, CHAMBER_END + 4.0)], # floor
		[local_at(mid_t, 0.0, TUNNEL_H + 0.5), Vector3(TUNNEL_W + 2.0, 1.0, TUNNEL_END + 1.0)], # tunnel roof
		[local_at(mid_c, 0.0, CHAMBER_H + 0.5), Vector3(CHAMBER_W + 2.0, 1.0, len_c)], # chamber roof
		[local_at(CHAMBER_END + 0.4, 0.0, 3.0), Vector3(CHAMBER_W + 2.0, 8.0, 1.0)], # end wall
		[local_at(-0.6, 0.0, 3.0), Vector3(TUNNEL_W + 2.0, 8.0, 1.0)], # behind the daylight
	]
	for sx: float in [-1.0, 1.0]:
		boxes.append([local_at(mid_t, sx * (TUNNEL_W * 0.5 + 0.35), 3.0), Vector3(1.0, 8.0, TUNNEL_END + 1.0)])
		boxes.append([local_at(mid_c, sx * (CHAMBER_W * 0.5 + 0.2), 3.0), Vector3(1.0, 8.0, len_c)])
		boxes.append([local_at(TUNNEL_END + 0.6, sx * (TUNNEL_W + CHAMBER_W) * 0.25, 3.0), Vector3((CHAMBER_W - TUNNEL_W) * 0.5, 8.0, 1.0)])
	for b: Array in boxes:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		col.shape = bs
		col.position = b[0]
		body.add_child(col)


# ------------------------------------------------------------------ interactables

## The daylight at the entrance: E fades you back out onto the canyon floor.
class ExitDoor extends StaticBody3D:
	var director: DownTheHole

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_WORLD
		collision_mask = 0
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(MineTunnel.TUNNEL_W, MineTunnel.TUNNEL_H, 0.3)
		col.shape = bs
		col.position = Vector3(0, MineTunnel.TUNNEL_H * 0.5, 0.05)
		add_child(col)

	func interact_prompt() -> String:
		return "Daylight  -  the canyon floor\nE: back out of the tunnel"

	func local_interact(holding: bool) -> void:
		if not holding and director != null:
			director.leave_tunnel()


## A chalk-marked spot on the wall where a charge goes. E with dynamite in your
## backpack sets one: a bundle of red sticks strapped to the rock, its fuse
## cord run back along the floor toward the daylight.
class ChargeSpot extends StaticBody3D:
	var index := 0
	var side := 1.0
	var depth := 10.0
	var director: DownTheHole
	var _bundle: MeshInstance3D
	var _cord: MeshInstance3D
	var _mark: MeshInstance3D
	var charged := false

	func _ready() -> void:
		collision_layer = WorldLayout.LAYER_STRUCTURE
		collision_mask = 0
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.1, 1.8, 0.9)
		col.shape = bs
		col.position = Vector3(0, 0.9, 0)
		add_child(col)
		_mark = MeshInstance3D.new()
		_mark.mesh = DownTheHole.chalk_mark_mesh()
		_mark.material_override = Materials.toon(0.0)
		_mark.layers = MineTunnel.LAYER
		add_child(_mark)
		_bundle = MeshInstance3D.new()
		_bundle.mesh = DownTheHole.charge_mesh()
		_bundle.material_override = Materials.toon(0.015)
		_bundle.layers = MineTunnel.LAYER
		_bundle.visible = false
		add_child(_bundle)
		_cord = MeshInstance3D.new()
		_cord.mesh = _cord_mesh()
		_cord.material_override = Materials.toon(0.0)
		_cord.layers = MineTunnel.LAYER
		_cord.visible = false
		add_child(_cord)

	## The fuse cord: down off the bundle, out to the rail line, back to the mouth.
	func _cord_mesh() -> ArrayMesh:
		var st := MeshKit.begin()
		var pts: Array = [Vector3(0, 0.55, 0.15), Vector3(0, 0.05, 0.35)]
		var parent_tf := Transform3D(Basis(Vector3.UP, -side * PI * 0.5), MineTunnel.local_at(depth, side * (MineTunnel.width_at(depth) * 0.5 - 0.55), 0.0))
		var inv := parent_tf.affine_inverse()
		var lane := side * (0.95 + 0.12 * index)
		var d := depth - 0.5
		while d > 0.4:
			pts.append(inv * MineTunnel.local_at(d, lane, 0.04))
			d -= 2.0
		pts.append(inv * MineTunnel.local_at(0.3, lane, 0.04))
		for i in pts.size() - 1:
			MeshKit.add_limb(st, pts[i], pts[i + 1], 0.018, Color("#2B1B17"), 3)
		return MeshKit.finish(st)

	func set_charged(on: bool) -> void:
		if on == charged:
			return
		charged = on
		_bundle.visible = on
		_cord.visible = on
		_mark.visible = not on

	func interact_prompt() -> String:
		if director == null or director.blown:
			return ""
		if charged:
			return "Charge %d  -  set" % (index + 1)
		var me := multiplayer.get_unique_id()
		if Expedition.pack_count(me, BlastRules.ITEM) <= 0:
			return "Charge Spot %d  -  chalk-marked\nBring a dynamite crate from the pile at the rope foot" % (index + 1)
		return "Charge Spot %d\nE: set the charge" % (index + 1)

	func local_interact(holding: bool) -> void:
		if holding or charged or director == null:
			return
		director.request_set(index)
