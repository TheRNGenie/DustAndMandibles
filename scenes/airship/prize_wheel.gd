class_name PrizeWheel
extends CasinoGame
## A big painted prize wheel: Spin for 5 chitin. The host picks the prize and
## every peer sees the wheel spin to it.

const COST := 5
## Label, prize. One wedge each.
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


func _ready() -> void:
	super._ready()
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.15, 0)), Vector3(1.4, 0.3, 0.8), Palette.WOOD_DARK)
	for sx: float in [-0.5, 0.5]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(sx, 1.0, 0.1)), Vector3(0.1, 1.8, 0.1), Palette.WOOD)
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
		var p1 := Vector3(sin(a0), cos(a0), 0) * 0.8
		var p2 := Vector3(sin(a1), cos(a1), 0) * 0.8
		var nrm := Vector3(0, 0, -1)
		MeshKit.tri(wst, Vector3.ZERO, p2, p1, nrm, nrm, nrm, MeshKit.vcol(c), nrm)
		MeshKit.tri(wst, Vector3.ZERO, p1, p2, -nrm, -nrm, -nrm, MeshKit.vcol(c), -nrm)
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


func _process(delta: float) -> void:
	if _t >= SPIN_TIME:
		return
	_t += delta
	var k := 1.0 - pow(1.0 - clampf(_t / SPIN_TIME, 0.0, 1.0), 3.0)
	_wheel.rotation.z = lerpf(_from, _to, k)
	if _t >= SPIN_TIME:
		view["spinning"] = false
		Audio.play_at(&"coin", global_position + Vector3.UP * 1.5, -2.0)
		ui_changed.emit()


func ui_title() -> String:
	return "Prize Wheel"


func ui_rules() -> String:
	return "%d chitin a spin. Scrap, chitin, chili seeds, herbs, or the 25-chitin jackpot. Three wedges bust." % COST


func ui_currency() -> StringName:
	return &"chitin"


func ui_actions() -> Array:
	return [] if _t < SPIN_TIME else [[&"spin", "Spin (%d chitin)" % COST]]


func _draw_view(table: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var landed := int(view.get("wedge", -1))
	var spinning := bool(view.get("spinning", false))
	for i in WEDGES.size():
		var label := String(WEDGES[i][0])
		var w := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1E1A18") if label == "BUST" else Palette.BONE
		sb.border_color = MenuScreen.GOLD if (i == landed and not spinning) else Palette.WOOD_DARK
		sb.set_border_width_all(5 if (i == landed and not spinning) else 2)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(4)
		w.add_theme_stylebox_override("panel", sb)
		w.custom_minimum_size = Vector2(118, 54)
		var l := MenuScreen.ink_label(label, 13, MenuScreen.PARCHMENT if label == "BUST" else MenuScreen.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		w.add_child(l)
		grid.add_child(w)
	table.add_child(grid)


func _act(peer_id: int, action: StringName, _choice: int, _bet: int) -> void:
	if action != &"spin" or _t < SPIN_TIME:
		return
	if not _take(peer_id, COST):
		return
	var i := _rng.randi() % WEDGES.size()
	var prize: Dictionary = WEDGES[i][1]
	_pay(peer_id, prize)
	var label := String(WEDGES[i][0])
	_broadcast({"kind": "wheel", "peer": peer_id, "wedge": i, "spinning": true,
			"result": "Bust! Better luck next spin." if label == "BUST" else "You won %s!" % label.to_lower()})


func menu_build_body(body: Control, screen: MenuScreen) -> void:
	super.menu_build_body(body, screen)


func _on_view() -> void:
	var n := WEDGES.size()
	var i := int(view.get("wedge", 0))
	_from = fmod(_wheel.rotation.z, TAU)
	var target := (float(i) + 0.5) / n * TAU
	_to = _from + TAU * 4.0 + fposmod(target - _from, TAU)
	_t = 0.0
	Audio.play_at(&"reload", global_position + Vector3.UP * 1.5, -4.0)
