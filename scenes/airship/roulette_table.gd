class_name RouletteTable
extends CasinoTable
## Single-zero roulette for 20 scrap: F picks the bet (red, black, odd, even,
## 1-18, 19-36, 1st dozen, lucky 7), E spins. The wheel on the table spins on
## every peer and the sign shows the number.

const SPIN_TIME := 3.0

static var bet_index := 0

var _wheel: MeshInstance3D
var _t := SPIN_TIME
var _pending := ""


func _ready() -> void:
	title = "ROULETTE  (%d scrap)" % BET
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
	var k := clampf(_t / SPIN_TIME, 0.0, 1.0)
	_wheel.rotation.y += delta * lerpf(14.0, 0.5, k)
	if _t >= SPIN_TIME:
		_show(_pending, &"coin")


func interact_prompt() -> String:
	if _t < SPIN_TIME:
		return "Roulette: the ball is rolling..."
	var b: Array = CasinoRules.ROULETTE_BETS[bet_index]
	return "Roulette: bet %d scrap on %s (pays %d:1)\nE: spin   F: change bet" % [BET, b[1], b[2]]


func _on_f() -> void:
	bet_index = (bet_index + 1) % CasinoRules.ROULETTE_BETS.size()


func _local_choice() -> int:
	return bet_index


func _act(peer_id: int, action: StringName, arg: int) -> void:
	if action != &"e" or _t < SPIN_TIME or not _take_bet(peer_id):
		return
	var bi := clampi(arg, 0, CasinoRules.ROULETTE_BETS.size() - 1)
	var n := _rng.randi_range(0, 36)
	var won := CasinoRules.roulette_payout(bi, n, BET)
	_pay(peer_id, won)
	var colour := "green" if n == 0 else ("red" if CasinoRules.RED_NUMBERS.has(n) else "black")
	var text := "%d %s\n%s bet %s" % [n, colour, CasinoRules.ROULETTE_BETS[bi][1], ("wins +%d" % won) if won > 0 else "loses"]
	_spin.rpc(text)
	get_tree().create_timer(SPIN_TIME).timeout.connect(func() -> void:
		Economy.notify(peer_id, "Roulette: %s" % text.replace("\n", ", ")))


@rpc("authority", "call_local", "reliable")
func _spin(text: String) -> void:
	_t = 0.0
	_pending = text
	_label.text = "%s\n..." % title
	Audio.play_at(&"reload", global_position + Vector3.UP, -4.0)
