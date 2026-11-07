class_name AmmoSackBuilder
extends RefCounted
## Turret ammo: the burlap sack a harvest fills (one sack = one turret load). A
## lumpy burlap body, a twine-tied neck with a frayed top, and a square cloth
## patch sewn on the front showing the crop it holds (CropBuilder.picture) on a
## band of the crop's colour. About 45 cm tall; origin on the floor, patch
## facing -Z.

const BURLAP := Color("#B48A58")
const BURLAP_DARK := Color("#8E6A40")
const TWINE := Color("#D8C08A")
const PATCH := Color("#F2E3C2")

static var _cache: Dictionary = {}


static func sack(crop_id: StringName) -> ArrayMesh:
	var key := String(crop_id)
	if _cache.has(key):
		return _cache[key]
	var crop := Defs.crop(crop_id)
	var band: Color = crop.color if crop != null else BURLAP_DARK
	var st := MeshKit.begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	# Body: a squat, lumpy bag, fuller at the bottom.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.17, 0)), Vector3(0.17, 0.17, 0.14), 6, 12, BURLAP, 0.012, rng)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector3(0.15, 0.04, 0.125), 4, 12, BURLAP_DARK) # the sack sits flat
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.12, 0.08, 0.1), 5, 10, BURLAP, 0.01, rng)
	# Neck, twine tie and frayed top.
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.38, 0)), 0.05, 0.04, 0.06, 8, BURLAP)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.375, 0)), 0.056, 0.056, 0.018, 10, TWINE)
	for i in 7:
		var a := float(i) * TAU / 7.0
		var base := Vector3(cos(a) * 0.035, 0.41, sin(a) * 0.035)
		MeshKit.add_limb(st, base, base + Vector3(cos(a) * 0.035, 0.035 + rng.randf() * 0.02, sin(a) * 0.035), 0.012, BURLAP_DARK if i % 2 else BURLAP, 3)
	# The patch: a cream square edged in the crop's colour, stitched on the front.
	var front := Vector3(0, 0.18, -0.142)
	MeshKit.add_box(st, Transform3D(Basis(), front + Vector3(0, 0, 0.002)), Vector3(0.15, 0.15, 0.006), band)
	MeshKit.add_box(st, Transform3D(Basis(), front - Vector3(0, 0, 0.002)), Vector3(0.12, 0.12, 0.004), PATCH)
	for k in 4:
		var s := -0.07 + k * 0.0467
		for e: Vector3 in [Vector3(s, 0.075, 0), Vector3(s, -0.075, 0), Vector3(0.075, s, 0), Vector3(-0.075, s, 0)]:
			MeshKit.add_box(st, Transform3D(Basis(), front + e - Vector3(0, 0, 0.0055)), Vector3(0.01, 0.01, 0.002), BURLAP_DARK)
	var mesh := MeshKit.finish(st)
	# The crop's packet picture, scaled up onto the patch.
	var pic := CropBuilder.picture(crop_id)
	if pic != null and pic.get_surface_count() > 0:
		var st2 := SurfaceTool.new()
		st2.append_from(mesh, 0, Transform3D())
		st2.append_from(pic, 0, Transform3D(Basis().scaled(Vector3.ONE * 2.0), front - Vector3(0, 0, 0.008)))
		mesh = st2.commit()
	_cache[key] = mesh
	return mesh
