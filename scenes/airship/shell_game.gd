class_name ShellGame
extends CasinoTable
## The shell game: three tin cups, one dried pea. Pick a cup and Play: the
## dealer hides the pea (a fair 1-in-3 pick by the host), shuffles the cups
## round the felt, then lifts yours. Right pays 2.85x the stake (about 95% back
## over time). The cups move on every peer's table.

const SHUFFLE_TIME := 2.2
const REVEAL_TIME := 1.2
## Left to right as you stand at the table (the felt faces you from its -Z side).
const CUP_X := [0.45, 0.0, -0.45]

var _cups: Array[Node3D] = []
var _pea: MeshInstance3D
var _t := SHUFFLE_TIME + REVEAL_TIME
## The cup order while shuffling (which slot each cup ends in).
var _swaps: Array = []


func ui_anim() -> StringName:
	return &"cards"


func ui_title() -> String:
	return "Shell Game"


func ui_rules() -> String:
	return "Find the pea under one of three cups. Guess right and win %.2fx your stake." % CasinoRules.SHELL_RETURN


func _ready() -> void:
	super._ready()
	for i in 3:
		var cup := Node3D.new()
		cup.position = Vector3(CUP_X[i], 0.99, -0.05)
		add_child(cup)
		var mi := MeshInstance3D.new()
		mi.mesh = _cup_mesh()
		mi.material_override = Materials.toon(0.01)
		cup.add_child(mi)
		_cups.append(cup)
	_pea = MeshInstance3D.new()
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.035, 0.03, 0.035), 4, 6, Color("#C9A86A"))
	_pea.mesh = MeshKit.finish(st)
	_pea.material_override = Materials.toon(0.01)
	_pea.visible = false
	add_child(_pea)


static func _cup_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.11, 0.075, 0.2, 10, Color("#8C949C"))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.205, 0)), 0.078, 0.07, 0.015, 10, Color("#6E767E"))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.01, 0)), 0.115, 0.115, 0.02, 10, Color("#5C646B"), false)
	return MeshKit.finish(st)


func ui_choices() -> Array:
	return ["Left cup", "Middle cup", "Right cup"]


func ui_actions() -> Array:
	return [] if _busy() else [[&"play", "Play"]]


func _busy() -> bool:
	return _t < SHUFFLE_TIME + REVEAL_TIME


func _act(peer_id: int, action: StringName, choice: int, bet: int) -> void:
	if action != &"play" or _busy():
		return
	bet = _valid_bet(bet)
	if not _take(peer_id, bet):
		return
	var pick := clampi(choice, 0, 2)
	var pea := CasinoRules.shell_pea(_rng)
	var won := CasinoRules.shell_payout(pick, pea, bet)
	# Paid at the reveal, so the scrap counter doesn't give the result away.
	_pay_later(peer_id, {&"scrap": won} if won > 0 else {}, SHUFFLE_TIME + 0.4)
	var names := ["left", "middle", "right"]
	_broadcast({"kind": "cups", "peer": peer_id, "pick": pick, "pea": pea, "seed": _rng.randi(), "spinning": true,
			"result": ("Under the %s cup! You win %d scrap" % [names[pea], won]) if won > 0 else ("Nope, it was under the %s cup" % names[pea])})


func _on_view() -> void:
	_t = 0.0
	# A shuffle path from the seed: five swaps of two cups.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(view.get("seed", 0))
	_swaps.clear()
	for i in 5:
		var a := rng.randi_range(0, 2)
		var b := (a + rng.randi_range(1, 2)) % 3
		_swaps.append([a, b])
	_pea.visible = false
	Audio.play_at(&"card_flick", global_position + Vector3.UP, -6.0)


func _process(delta: float) -> void:
	if not _busy() or _cups.is_empty():
		return
	var was_shuffling := _t < SHUFFLE_TIME
	_t += delta
	if _t < SHUFFLE_TIME:
		_shuffle_pose(_t / SHUFFLE_TIME)
		return
	if was_shuffling:
		# Cups back in their slots: the pea is under the final slot shown in view.
		for i in 3:
			_cups[i].position = Vector3(CUP_X[i], 0.99, -0.05)
		Audio.play_at(&"dice", global_position + Vector3.UP, -8.0)
	var pick := int(view.get("pick", 0))
	var pea := int(view.get("pea", 0))
	var lift := clampf((_t - SHUFFLE_TIME) / 0.35, 0.0, 1.0)
	for i in 3:
		var up := 0.0
		if i == pick or i == pea:
			up = lift * 0.18
		_cups[i].position.y = 0.99 + up
		_cups[i].rotation.x = -lift * 0.35 if (i == pick or i == pea) else 0.0
	_pea.position = Vector3(CUP_X[pea], 1.01, -0.05)
	_pea.visible = true
	if not _busy():
		view["spinning"] = false
		Audio.play_at(&"coin", global_position + Vector3.UP, -4.0)
		ui_changed.emit()


## Mid-shuffle: each swap slides two cups past each other in a little arc.
func _shuffle_pose(u: float) -> void:
	var n := _swaps.size()
	var seg := minf(u * n, n - 0.001)
	var k := int(seg)
	var f := seg - k
	var slot := [0, 1, 2] # where each cup sits before swap k
	for j in k:
		var a: int = _swaps[j][0]
		var b: int = _swaps[j][1]
		var ia := slot.find(a)
		var ib := slot.find(b)
		slot[ia] = b
		slot[ib] = a
	var e := f * f * (3.0 - 2.0 * f)
	for c in 3:
		var from: int = slot[c]
		var to := from
		if from == _swaps[k][0]:
			to = _swaps[k][1]
		elif from == _swaps[k][1]:
			to = _swaps[k][0]
		var x := lerpf(CUP_X[from], CUP_X[to], e)
		var arc := sin(e * PI) * 0.16 * (1.0 if from < to else -1.0) if from != to else 0.0
		_cups[c].position = Vector3(x, 0.99, -0.05 + arc)
		_cups[c].rotation.x = 0.0


func _draw_view(table: VBoxContainer) -> void:
	if str(view.get("kind", "")) != "cups":
		table.add_child(MenuScreen.ink_label("Find the pea", 30, MenuScreen.PARCHMENT))
		table.add_child(_cup_row(-1, -1, false))
		return
	var shuffling := bool(view.get("spinning", false))
	table.add_child(_cup_row(int(view.get("pick", 0)), int(view.get("pea", 0)), not shuffling))


## Three cup cards; after the reveal the pea's cup shows the pea and yours is ringed.
func _cup_row(pick: int, pea: int, reveal: bool) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 14)
	for i in 3:
		var cup := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#8C949C") if not (reveal and i == pea) else Color("#E9D6A8")
		sb.border_color = MenuScreen.GOLD if i == pick else Palette.OUTLINE
		sb.set_border_width_all(5 if i == pick else 3)
		sb.corner_radius_top_left = 40
		sb.corner_radius_top_right = 40
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		cup.add_theme_stylebox_override("panel", sb)
		cup.custom_minimum_size = Vector2(110, 100)
		var text := "?"
		if reveal:
			text = "PEA" if i == pea else "-"
		var l := MenuScreen.ink_label(text, 22, MenuScreen.INK if reveal and i == pea else MenuScreen.PARCHMENT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cup.add_child(l)
		line.add_child(cup)
	return line
