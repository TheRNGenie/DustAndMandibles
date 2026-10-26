class_name PrizeWheel
extends StaticBody3D
## A big painted prize wheel. E spins it for 5 chitin; the host picks the prize
## and every peer sees the wheel spin to it.

const COST := 5
## Label, prize. Weighted equally (one wedge each).
const WEDGES: Array[Array] = [
	["BUST", {}], ["50 SCRAP", {&"scrap": 50}], ["8 CHITIN", {&"chitin": 8}], ["BUST", {}],
	["120 SCRAP", {&"scrap": 120}], ["3 CHILI SEEDS", {&"seed_chili": 3}], ["BUST", {}], ["JACKPOT 25 CHITIN", {&"chitin": 25}],
	["30 SCRAP", {&"scrap": 30}], ["4 HERBS", {&"herbs": 4}],
]
const SPIN_TIME := 3.5

var _wheel: Node3D
var _from := 0.0
var _to := 0.0
var _t := SPIN_TIME
var _label: Label3D
var _pending := ""


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(1.4, 0.3, 0.8), Palette.WOOD_DARK)
	for sx: float in [-0.5, 0.5]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 1.0, 0.1)), Vector3(0.1, 1.8, 0.1), Palette.WOOD)
	# Pointer at the top.
	MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0, 2.62, -0.12)), Vector3(0.18, 0.18, 0.05), Palette.GLOW_YELLOW, 0.0, null, 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.015)
	add_child(mi)
	_wheel = Node3D.new()
	_wheel.position = Vector3(0, 1.75, -0.05)
	add_child(_wheel)
	var wst := MeshKit.begin()
	var n := WEDGES.size()
	var colors: Array[Color] = [Color("#C9302C"), Palette.BONE, Color("#2E6FA8"), Palette.GLOW_YELLOW.darkened(0.2)]
	for i in n:
		var a0 := TAU * float(i) / n
		var a1 := TAU * float(i + 1) / n
		var c := Palette.OUTLINE if String(WEDGES[i][0]) == "BUST" else colors[i % colors.size()]
		var p0 := Vector3.ZERO
		var p1 := Vector3(sin(a0), cos(a0), 0) * 0.8
		var p2 := Vector3(sin(a1), cos(a1), 0) * 0.8
		var nrm := Vector3(0, 0, -1)
		MeshKit.tri(wst, p0, p2, p1, nrm, nrm, nrm, MeshKit.vcol(c), nrm)
		MeshKit.tri(wst, p0, p1, p2, -nrm, -nrm, -nrm, MeshKit.vcol(c), -nrm)
	MeshKit.add_cylinder(wst, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.03)), 0.12, 0.12, 0.08, 10, Palette.METAL)
	var wmi := MeshInstance3D.new()
	wmi.mesh = MeshKit.finish(wst)
	wmi.material_override = Materials.toon(0.01)
	_wheel.add_child(wmi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 2.6, 0.5)
	col.shape = shape
	col.position.y = 1.3
	add_child(col)
	_label = Label3D.new()
	_label.text = "PRIZE WHEEL\n%d chitin a spin" % COST
	_label.font_size = 36
	_label.outline_size = 8
	_label.modulate = Palette.GLOW_YELLOW
	_label.pixel_size = 0.005
	_label.position = Vector3(0, 0.55, -0.45)
	_label.rotation.y = PI
	add_child(_label)


func _process(delta: float) -> void:
	if _t >= SPIN_TIME:
		return
	_t += delta
	var k := clampf(_t / SPIN_TIME, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	_wheel.rotation.z = lerpf(_from, _to, k)
	if _t >= SPIN_TIME:
		_label.text = _pending
		Audio.play_at(&"coin", global_position + Vector3.UP * 1.5, -2.0)


func interact_prompt() -> String:
	if _t < SPIN_TIME:
		return "The wheel is spinning..."
	return "Prize wheel: %d chitin a spin\nE: spin. Prizes: scrap, chitin, seeds, herbs, or a 25-chitin jackpot." % COST


func local_interact(holding: bool) -> void:
	if holding or _t < SPIN_TIME:
		return
	if multiplayer.is_server():
		_spin(multiplayer.get_unique_id())
	else:
		_request_spin.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_spin() -> void:
	if multiplayer.is_server():
		_spin(multiplayer.get_remote_sender_id())


func _spin(peer_id: int) -> void:
	if _t < SPIN_TIME:
		return
	var cid := NetworkManager.cliff_of(peer_id)
	if not Economy.spend(cid, {&"chitin": COST}):
		Economy.notify(peer_id, "A spin costs %d chitin." % COST)
		return
	var i := randi() % WEDGES.size()
	var prize: Dictionary = WEDGES[i][1]
	if not prize.is_empty():
		Economy.earn(cid, prize)
	_spin_to.rpc(i, peer_id)


@rpc("authority", "call_local", "reliable")
func _spin_to(i: int, peer_id: int) -> void:
	var n := WEDGES.size()
	_from = fmod(_wheel.rotation.z, TAU)
	# Wedge i is centred at angle (i + 0.5) / n * TAU clockwise from the top.
	var target := (float(i) + 0.5) / n * TAU
	_to = _from + TAU * 4.0 + fposmod(target - _from, TAU)
	_t = 0.0
	_label.text = "..."
	var who := "You" if peer_id == multiplayer.get_unique_id() else "Your partner"
	_pending = "%s\n%s" % [String(WEDGES[i][0]), "" if String(WEDGES[i][0]) == "BUST" else "(won)"]
	if peer_id == multiplayer.get_unique_id():
		get_tree().create_timer(SPIN_TIME).timeout.connect(func() -> void:
			Economy.notice.emit("%s spun the wheel: %s" % [who, String(WEDGES[i][0])]))
	Audio.play_at(&"reload", global_position + Vector3.UP * 1.5, -4.0)
