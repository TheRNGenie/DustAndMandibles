class_name RouletteTable
extends CasinoTable
## Single-zero roulette: pick a bet (red, black, odd, even, 1-18, 19-36, 1st
## dozen, lucky 7) and Spin. The little wheel on the table spins on every peer.

const SPIN_TIME := 3.0

var _wheel: MeshInstance3D
var _t := SPIN_TIME


func ui_title() -> String:
	return "Roulette"


func ui_rules() -> String:
	return "Single zero. Colours, odd/even and halves pay 1:1, the 1st dozen 2:1, Lucky 7 pays 35:1."


func _ready() -> void:
	super._ready()
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(), 0.38, 0.38, 0.06, 37, Palette.WOOD_DARK)
	for i in 37:
		var a := TAU * i / 37.0
		var c := Color("#2E7D32") if i == 0 else (Color("#C9302C") if CasinoRules.RED_NUMBERS.has(i) else Palette.OUTLINE)
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -a), Vector3(sin(a), 0.035, cos(a)) * 0.3), Vector3(0.05, 0.01, 0.12), c)
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.06, 0)), 0.08, 0.05, 0.08, 8, Palette.GLOW_YELLOW.darkened(0.2))
	_wheel = MeshInstance3D.new()
	_wheel.mesh = MeshKit.finish(st)
	_wheel.material_override = Materials.toon(0.01)
	_wheel.position = Vector3(-0.45, 1.02, 0)
	add_child(_wheel)


func _process(delta: float) -> void:
	if _t >= SPIN_TIME:
		return
	_t += delta
	_wheel.rotation.y += delta * lerpf(14.0, 0.5, clampf(_t / SPIN_TIME, 0.0, 1.0))
	if _t >= SPIN_TIME:
		view["spinning"] = false
		Audio.play_at(&"coin", global_position + Vector3.UP, -4.0)
		ui_changed.emit()


func ui_choices() -> Array:
	var out: Array = []
	for b: Array in CasinoRules.ROULETTE_BETS:
		out.append("%s (%d:1)" % [b[1], b[2]])
	return out


func ui_actions() -> Array:
	return [] if _t < SPIN_TIME else [[&"spin", "Spin"]]


func _act(peer_id: int, action: StringName, choice: int, bet: int) -> void:
	if action != &"spin" or _t < SPIN_TIME:
		return
	bet = _valid_bet(bet)
	if not _take(peer_id, bet):
		return
	var bi := clampi(choice, 0, CasinoRules.ROULETTE_BETS.size() - 1)
	var n := _rng.randi_range(0, 36)
	var won := CasinoRules.roulette_payout(bi, n, bet)
	_pay(peer_id, {&"scrap": won} if won > 0 else {})
	var colour := "green" if n == 0 else ("red" if CasinoRules.RED_NUMBERS.has(n) else "black")
	_broadcast({"kind": "number", "peer": peer_id, "number": n, "colour": colour, "spinning": true,
			"result": "%d %s - %s %s" % [n, colour, CasinoRules.ROULETTE_BETS[bi][1], ("wins %d scrap" % won) if won > 0 else "loses"]})


func _on_view() -> void:
	_t = 0.0
	Audio.play_at(&"reload", global_position + Vector3.UP, -4.0)
