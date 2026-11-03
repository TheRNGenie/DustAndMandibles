class_name SlotMachine
extends CasinoGame
## A one-armed bandit on the casino deck. Pick a stake and Pull. The host rolls
## three reels; three of a kind pays (chilis add seeds, stars add a turret upgrade
## token), a pair returns the stake. Pays back about 82% of stakes in scrap.

const BETS: Array = [10, 25, 50]
## Reel symbols and prizes live in CasinoRules (unit tested).
const SYMBOLS: Array[Array] = CasinoRules.SLOT_SYMBOLS

var _arm: MeshInstance3D
var _arm_t := 0.0


func _ready() -> void:
	super._ready()
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(0.9, 1.5, 0.7), Color("#7A2E22"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.6, 0)), Vector3(0.95, 0.25, 0.75), Palette.GLOW_YELLOW.darkened(0.3))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.05, -0.36)), Vector3(0.7, 0.35, 0.03), Palette.BONE)
	for k in 3:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.22 + k * 0.22, 1.05, -0.38)), Vector3(0.16, 0.26, 0.02), [Color("#B3261E"), Palette.CACTUS, Palette.GLOW_YELLOW][k])
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.5, -0.36)), Vector3(0.5, 0.12, 0.05), Palette.METAL)
	for k in 5:
		MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(-0.36 + k * 0.18, 1.78, -0.3)), Vector3.ONE * 0.05, 3, 6, Palette.GLOW_YELLOW, 0.0, null, 0.9)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.finish(st)
	mi.material_override = Materials.toon(0.015)
	add_child(mi)
	var arm_st := MeshKit.begin()
	MeshKit.add_cylinder(arm_st, Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.03, 0.03, 0.6, 6, Palette.METAL)
	MeshKit.add_ellipsoid(arm_st, Transform3D(Basis(), Vector3(0, 0.62, 0)), Vector3.ONE * 0.08, 4, 8, Color("#C9302C"))
	_arm = MeshInstance3D.new()
	_arm.mesh = MeshKit.finish(arm_st)
	_arm.material_override = Materials.toon(0.01)
	_arm.position = Vector3(0.5, 1.0, 0)
	add_child(_arm)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.8, 0.7)
	col.shape = shape
	col.position.y = 0.9
	add_child(col)


func _process(delta: float) -> void:
	_arm_t = maxf(_arm_t - delta, 0.0)
	_arm.rotation.x = sin(_arm_t / 0.4 * PI) * 0.9


func ui_anim() -> StringName:
	return &"slots"


func ui_title() -> String:
	return "Slot Machine"


func ui_rules() -> String:
	return "Three of a kind: cactus x10, chili x15 + 3 chili seeds, horseshoe x25, star x60 + a turret upgrade token. A pair returns your stake (horseshoes or stars pay double); bugs pay nothing."


func ui_bets() -> Array:
	return BETS


func ui_actions() -> Array:
	return [[&"pull", "Pull the Lever"]]


func ui_cheat() -> Array:
	return ["Pull and Nudge a Reel", "slots"]


static func roll(rng: RandomNumberGenerator) -> int:
	var total := 0
	for s: Array in SYMBOLS:
		total += int(s[1])
	var r := rng.randi_range(1, total)
	for i in SYMBOLS.size():
		r -= int(SYMBOLS[i][1])
		if r <= 0:
			return i
	return 0


func _act(peer_id: int, action: StringName, _choice: int, bet: int) -> void:
	if action != &"pull" and action != &"cheat":
		return
	bet = _valid_bet(bet)
	if action == &"cheat" and _cheat(peer_id, "slots", bet) <= 0: # Brand: Snake Eyes nudge
		return
	if not _take(peer_id, bet):
		return
	var reels := [roll(_rng), roll(_rng), roll(_rng)]
	if action == &"cheat":
		reels = BrandTable.nudge_reels(reels, SYMBOLS.size(), func(r: Array) -> int: return CasinoRules.slot_payout(r))
	var won := CasinoRules.slot_prize(reels, bet)
	_pay(peer_id, won)
	_broadcast({"kind": "reels", "peer": peer_id, "reels": [SYMBOLS[reels[0]][0], SYMBOLS[reels[1]][0], SYMBOLS[reels[2]][0]],
			"result": ("You win %s!" % CasinoRules.prize_text(won)) if not won.is_empty() else "No luck this time."})


func _on_view() -> void:
	_arm_t = 0.4
	Audio.play_at(&"coin" if str(view.get("result", "")).begins_with("You win") else &"reload", global_position + Vector3.UP, -4.0)
