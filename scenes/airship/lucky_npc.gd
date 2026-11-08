class_name LuckyNpc
extends StaticBody3D
## Lucky Moreau, always aboard: the crash-test dummy in his own outfit (dark
## duster, a slouch hat with a hawk feather, red bandana, a gold hoop and an
## amber pendant), leaning with his forearms on the deck railing, a lit
## cigarette in his hand, looking out over the canyon. Every so often he takes a
## drag (the smoke curls up), flicks the ash or glances along the deck.
## Talk to him (E): once his trade is open (Amber.lucky_open: past story chapter
## 4, or wave 8 in a normal run) he opens his shop, the same menu as his stall;
## before that he tells you to come back later. Local and cosmetic apart from
## the menu (sales go through LuckyStall like before).
## Once the team has found hive amber (Amber.found) he leaves the rail for his
## booth: the same lean and cigarette, forearms on his counter, facing the
## customers (Logan).

const LOOK := {"hat": "cattleman", "facial": "none", "hair": "long", "hair_color": "black", "outfit": "duster",
	"neck": "bandana", "extra": "spurs", "paint": "amber"}
const COAT := Color("#2A2226")
const NOT_YET := "Nothing on the table yet, friend. Come back when the hive's coughing up amber."
## His place in the booth, in the stall's own space: behind the counter, as far
## back from it as he stands from the rail, facing the customers (-Z).
const BOOTH_SPOT := Vector3(0.35, 0.0, 0.15)

var stall: LuckyStall
var rig: DummyRig
var _bubble: Label3D
var _bubble_t := 0.0
var _t := randf() * 5.0
var _next_drag := 3.0
var _drag := -1.0 # 0..1 while taking a drag
var _next_flick := 7.0
var _flick := -1.0
var _glance := 0.0
var _glance_t := 5.0
var _smoke: CPUParticles3D
var _ember: OmniLight3D
var _rail: Transform3D # where the airship put him (on the deck rail)
var _in_booth := false


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	add_to_group("lucky_npc")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	rig = DummyRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(COAT, false, LOOK)
	rig.relaxed = true
	rig.set_weapon(&"")
	_dress()
	_bubble = Label3D.new()
	_bubble.font_size = 44
	_bubble.pixel_size = 0.0032
	_bubble.outline_size = 12
	_bubble.width = 900.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.modulate = Palette.BONE
	_bubble.outline_modulate = Palette.OUTLINE
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0, 2.25, 0)
	_bubble.visible = false
	add_child(_bubble)
	_rail = transform


## The hawk feather on his hat, the gold hoop, the amber pendant and his cigarette.
func _dress() -> void:
	var mat := Materials.toon(0.006)
	var st := MeshKit.begin()
	# Feather tucked in the hat band, sweeping back.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, -0.7) * Basis(Vector3.BACK, 0.35), Vector3(0.11, 0.27, 0.06)), Vector3(0.03, 0.13, 0.008), 3, 8, Color("#7A4A2A"))
	MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3.RIGHT, -0.7) * Basis(Vector3.BACK, 0.35), Vector3(0.115, 0.31, 0.04)), Vector3(0.02, 0.06, 0.009), 3, 6, Palette.BONE)
	# The gold hoop at his left ear.
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.12, 0.02, 0.0)), Vector3(0.012, 0.03, 0.03), 3, 8, Color("#E8B84A"))
	var head_bits := MeshInstance3D.new()
	head_bits.mesh = MeshKit.finish(st)
	head_bits.material_override = mat
	rig._head.add_child(head_bits)
	var pst := MeshKit.begin()
	MeshKit.add_ellipsoid(pst, Transform3D(Basis(), Vector3(0, 0.36, -0.15)), Vector3(0.04, 0.05, 0.025), 3, 8, Color("#F0A030"), 0.0, null)
	var pendant := MeshInstance3D.new()
	pendant.mesh = MeshKit.finish(pst)
	pendant.material_override = mat
	rig._torso.add_child(pendant)
	# The cigarette between the fingers of his right hand, a glowing tip.
	var cst := MeshKit.begin()
	MeshKit.add_cylinder(cst, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.06)), 0.011, 0.011, 0.1, 8, Palette.BONE)
	MeshKit.add_cylinder(cst, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.115)), 0.0115, 0.0115, 0.01, 8, Color("#FF6A1A"), true, 0.9)
	var cig := MeshInstance3D.new()
	cig.mesh = MeshKit.finish(cst)
	cig.material_override = Materials.toon(0.002)
	rig._hand.add_child(cig)
	_ember = OmniLight3D.new()
	_ember.light_color = Color("#FF7A2A")
	_ember.light_energy = 0.4
	_ember.omni_range = 0.5
	_ember.position = Vector3(0, 0, -0.12)
	rig._hand.add_child(_ember)
	# A thin curl of smoke off the tip (and a puff when he takes a drag).
	_smoke = CPUParticles3D.new()
	_smoke.amount = 10
	_smoke.lifetime = 2.2
	_smoke.local_coords = false
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.gravity = Vector3(0, 0.25, 0)
	_smoke.initial_velocity_min = 0.08
	_smoke.initial_velocity_max = 0.18
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	_smoke.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.45))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	_smoke.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.86, 0.84, 0.8)
	if ResourceLoader.exists("res://assets/fx/smoke.png"):
		sm.albedo_texture = load("res://assets/fx/smoke.png")
	quad.material = sm
	_smoke.mesh = quad
	_smoke.position = Vector3(0, 0, -0.12)
	rig._hand.add_child(_smoke)


func _process(delta: float) -> void:
	if rig == null:
		return
	# Hive amber found: into his booth (and back to the rail on a new run).
	var booth := Amber.found and stall != null
	if booth != _in_booth:
		_in_booth = booth
		transform = stall.transform * Transform3D(Basis(), BOOTH_SPOT) if booth else _rail
	_t += delta
	rig.animate(delta, 0.0, false, 0.0)
	# Now and then: a drag, a flick of the ash, a glance along the deck.
	_next_drag -= delta
	if _next_drag <= 0.0 and _drag < 0.0 and _flick < 0.0:
		_drag = 0.0
		_next_drag = randf_range(7.0, 12.0)
	_next_flick -= delta
	if _next_flick <= 0.0 and _drag < 0.0 and _flick < 0.0:
		_flick = 0.0
		_next_flick = randf_range(9.0, 15.0)
	_glance_t -= delta
	if _glance_t <= 0.0:
		_glance_t = randf_range(5.0, 11.0)
		_glance = randf_range(-0.9, 0.7) if randf() < 0.5 else 0.0
	var drag_k := 0.0
	if _drag >= 0.0:
		_drag += delta / 2.6
		drag_k = sin(clampf(_drag, 0.0, 1.0) * PI)
		if _drag >= 0.62 and _drag - delta / 2.6 < 0.62:
			_puff()
		if _drag >= 1.0:
			_drag = -1.0
	var flick_k := 0.0
	if _flick >= 0.0:
		_flick += delta / 0.7
		flick_k = sin(clampf(_flick, 0.0, 1.0) * PI * 3.0) * (1.0 - _flick)
		if _flick >= 1.0:
			_flick = -1.0
	_ember.light_energy = 0.35 + drag_k * 0.9 + sin(_t * 3.1) * 0.05
	_lean(drag_k, flick_k)
	if rig._model != null:
		rig._model.apply() # the rigged body follows the leaning pivots this frame
	if _bubble_t > 0.0:
		_bubble_t -= delta
		_bubble.visible = _bubble_t > 0.0


## The pose: hips back, chest over the rail, forearms on it, head up and out;
## the right hand comes up to his mouth for a drag.
func _lean(drag_k: float, flick_k: float) -> void:
	var breathe := sin(_t * 1.3) * 0.02
	rig._torso.rotation = Vector3(-0.42 + breathe, 0.05, 0.0)
	rig._hips.rotation = Vector3(0.05, 0.0, 0.03)
	# Left leg straight, right knee bent with the foot crossed behind.
	rig._thighs[0].rotation = Vector3(0.12, 0.0, 0.02)
	rig._shins[0].rotation = Vector3(-0.12, 0.0, 0.0)
	rig._thighs[1].rotation = Vector3(0.28, 0.0, -0.05)
	rig._shins[1].rotation = Vector3(-0.62, 0.0, 0.0)
	# Forearms flat on the rail, hands loosely together.
	rig._shoulders[0].rotation = Vector3(0.95, -0.22, -0.12)
	rig._elbows[0].rotation.x = 1.15
	var r_sh := Vector3(0.95, 0.22, 0.12).lerp(Vector3(1.9, 0.55, 0.25), drag_k)
	r_sh.x += flick_k * 0.12
	rig._shoulders[1].rotation = r_sh
	rig._elbows[1].rotation.x = lerpf(1.15, 2.35, drag_k) + flick_k * 0.25
	# Looking out, a little up; a glance along the deck now and then.
	rig._head.rotation = Vector3(0.38 - drag_k * 0.15, lerpf(rig._head.rotation.y, _glance, 0.04), 0.0)


func _puff() -> void:
	_smoke.amount = 10
	_smoke.restart()


# ------------------------------------------------------------------ talking

func interact_prompt() -> String:
	if Amber.lucky_open():
		return "E: deal with Lucky Moreau (hive amber only)"
	return "E: talk to Lucky Moreau"


func local_interact(holding: bool) -> void:
	if holding:
		return
	if Amber.lucky_open() and stall != null:
		stall.local_interact(false)
		say(AmberRules.LUCKY_GREETING)
	else:
		say(NOT_YET)


func say(line: String, seconds: float = 6.0) -> void:
	_bubble.text = "\"%s\"" % line
	_bubble.visible = true
	_bubble_t = seconds
