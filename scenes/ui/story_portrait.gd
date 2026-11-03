class_name StoryPortrait
extends RefCounted
## Radio portraits of the Lucky Mandible's crew, rendered from the game's own
## crash-test-dummy characters (DummyRig with their hats and outfits, plus a
## few props: the Captain's balloonist goggles, Doc's spectacles, Pearl's
## feather and dice) and lit like an old tintype: warm key light, cool rim.
## Each portrait renders once into its own SubViewport (cached per host).

## speaker -> [look, paint team colour, yaw degrees]
const CAST: Dictionary = {
	"stroud": [{"hat": "cattleman", "hair": "ponytail", "hair_color": "ginger", "facial": "none", "outfit": "lawman",
		"neck": "bandana", "extra": "bandolier", "paint": "white"}, Color("#7A2E2A"), 18.0],
	"kettle": [{"hat": "gambler", "facial": "walrus", "hair": "none", "hair_color": "grey", "outfit": "vest",
		"neck": "bolo", "extra": "bandolier", "paint": "white"}, Color("#4A4E58"), -16.0],
	"pearl": [{"hat": "bowler", "hair": "long", "hair_color": "black", "facial": "none", "outfit": "vest",
		"neck": "bolo", "extra": "none", "paint": "orange"}, Color("#6B2C5E"), 14.0],
	"doc": [{"hat": "none", "hair": "none", "hair_color": "grey", "facial": "chops", "outfit": "duster",
		"neck": "bolo", "extra": "none", "paint": "yellow"}, Color("#3E5A44"), -20.0],
}
const SIZE := Vector2i(256, 256)

static var _cache: Dictionary = {}


static func texture(host: Node, who: String) -> Texture2D:
	if _cache.has(who) and is_instance_valid(_cache[who]["vp"]):
		return _cache[who]["tex"]
	var spec: Array = CAST.get(who, CAST["stroud"])
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var rig := DummyRig.new()
	vp.add_child(rig)
	rig.build(spec[1], false, spec[0])
	rig.relaxed = true
	rig.set_weapon(&"")
	rig.rotation.y = deg_to_rad(float(spec[2]))
	var head := rig.get("_head") as Node3D
	if head != null:
		_props(who, head)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.near = 0.02
	vp.add_child(cam)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#B9A4C8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
	var key := DirectionalLight3D.new()
	key.light_color = Color("#FFE2B8")
	key.light_energy = 1.35
	key.rotation = Vector3(deg_to_rad(-28), deg_to_rad(-38), 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#9FC7E8")
	rim.light_energy = 0.9
	rim.rotation = Vector3(deg_to_rad(-12), deg_to_rad(150), 0)
	vp.add_child(rim)
	_cache[who] = {"vp": vp, "tex": vp.get_texture()}
	# Frame the head once the rig (and any rigged model) has settled.
	var vp_ref: WeakRef = weakref(vp)
	var frame_it := func() -> void:
		var v := vp_ref.get_ref() as SubViewport
		if v == null or head == null or not is_instance_valid(head):
			return
		var h := head.global_position + Vector3.UP * 0.12
		cam.position = h + Vector3(0.0, 0.06, -1.55)
		cam.look_at(h + Vector3.DOWN * 0.1, Vector3.UP)
	# A few frames so any rigged body settles, then render once and stop.
	for t: float in [0.0, 0.1, 0.3]:
		host.get_tree().create_timer(t).timeout.connect(frame_it)
	host.get_tree().create_timer(0.6).timeout.connect(func() -> void:
		var v := vp_ref.get_ref() as SubViewport
		if v != null:
			frame_it.call()
			v.render_target_update_mode = SubViewport.UPDATE_ONCE)
	return vp.get_texture()


## A character's props on its head pivot (head space: +Y up, the face looks -Z).
static func _props(who: String, head: Node3D) -> void:
	if not ["stroud", "doc", "pearl"].has(who):
		return
	var st := MeshKit.begin()
	var brass := Color("#D9A83A")
	match who:
		"stroud":
			# Balloonist goggles pushed up on the hat band.
			for sx: float in [-1.0, 1.0]:
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.35), Vector3(sx * 0.075, 0.2, -0.16)), 0.058, 0.058, 0.05, 12, brass)
				MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.35), Vector3(sx * 0.075, 0.2, -0.18)), 0.044, 0.044, 0.02, 12, Color("#7FB8C8"), true, 0.15)
			MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.2, -0.15)), Vector3(0.05, 0.025, 0.03), brass)
		"doc":
			# Round wire spectacles.
			for sx: float in [-1.0, 1.0]:
				var c := Vector3(sx * 0.065, 0.07, -0.19)
				for k in 12:
					var a := TAU * k / 12.0
					var b := TAU * (k + 1) / 12.0
					MeshKit.add_limb(st, c + Vector3(cos(a), sin(a), 0) * 0.045, c + Vector3(cos(b), sin(b), 0) * 0.045, 0.006, brass, 4)
			MeshKit.add_limb(st, Vector3(-0.02, 0.075, -0.19), Vector3(0.02, 0.075, -0.19), 0.006, brass, 4)
		"pearl":
			# A red feather in the hat band.
			MeshKit.add_limb(st, Vector3(0.12, 0.24, 0.0), Vector3(0.2, 0.42, 0.06), 0.03, Color("#C0392B"), 6)
			MeshKit.add_limb(st, Vector3(0.2, 0.42, 0.06), Vector3(0.23, 0.5, 0.1), 0.018, Color("#E05A4A"), 6)
	var mesh := MeshKit.finish(st)
	if mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Materials.toon(0.006)
	head.add_child(mi)
