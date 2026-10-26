class_name SlotMachine
extends StaticBody3D
## A one-armed bandit on the casino deck. E pulls (10 / 25 / 50 scrap, F changes
## the bet). The host rolls three reels; three of a kind pays, two horseshoes
## return the bet. Pays out of (and into) your cliff's stockpile.

const BETS: Array[int] = [10, 25, 50]
## Symbol, weight, payout multiplier for three of a kind.
const SYMBOLS: Array[Array] = [["BUG", 30, 0], ["CACTUS", 25, 3], ["CHILI", 20, 5], ["HORSESHOE", 15, 8], ["STAR", 10, 20]]

static var bet_index := 0

var _label: Label3D
var _arm: MeshInstance3D
var _arm_t := 0.0


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	var st := MeshKit.begin()
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(0.9, 1.5, 0.7), Color("#7A2E22"))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.6, 0)), Vector3(0.95, 0.25, 0.75), Palette.GLOW_YELLOW.darkened(0.3))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.05, -0.36)), Vector3(0.7, 0.35, 0.03), Palette.BONE)
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
	_label = Label3D.new()
	_label.text = "- - -"
	_label.font_size = 40
	_label.outline_size = 8
	_label.modulate = Palette.OUTLINE
	_label.outline_modulate = Palette.BONE
	_label.pixel_size = 0.004
	_label.position = Vector3(0, 1.05, -0.39)
	_label.rotation.y = PI
	add_child(_label)


func _process(delta: float) -> void:
	_arm_t = maxf(_arm_t - delta, 0.0)
	_arm.rotation.x = sin(_arm_t / 0.4 * PI) * 0.9


func cycle_option() -> void:
	bet_index = (bet_index + 1) % BETS.size()


func interact_prompt() -> String:
	return "Slot machine: bet %d scrap\nE: pull   F: change bet\n3 of a kind pays: cactus x3, chili x5, horseshoe x8, star x20. Two horseshoes: bet back." % BETS[bet_index]


func local_interact(holding: bool) -> void:
	if holding:
		return
	if multiplayer.is_server():
		_pull(multiplayer.get_unique_id(), bet_index)
	else:
		_request_pull.rpc_id(1, bet_index)


@rpc("any_peer", "reliable")
func _request_pull(index: int) -> void:
	if multiplayer.is_server():
		_pull(multiplayer.get_remote_sender_id(), index)


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


## Payout multiplier for three reels.
static func payout(reels: Array) -> int:
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return int(SYMBOLS[reels[0]][2])
	var shoes := 0
	for r: int in reels:
		if SYMBOLS[r][0] == "HORSESHOE":
			shoes += 1
	return 1 if shoes == 2 else 0


func _pull(peer_id: int, index: int) -> void:
	var bet := BETS[clampi(index, 0, BETS.size() - 1)]
	var cid := NetworkManager.cliff_of(peer_id)
	if not Economy.spend(cid, {&"scrap": bet}):
		Economy.notify(peer_id, "You need %d scrap to play." % bet)
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var reels := [roll(rng), roll(rng), roll(rng)]
	var win := bet * payout(reels)
	if win > 0:
		Economy.earn(cid, {&"scrap": win})
	_show.rpc(reels, win)
	var shown := "%s %s %s" % [SYMBOLS[reels[0]][0], SYMBOLS[reels[1]][0], SYMBOLS[reels[2]][0]]
	Economy.notify(peer_id, ("Slots: %s. You win %d scrap!" % [shown, win]) if win > 0 else ("Slots: %s. No luck." % shown))


@rpc("authority", "call_local", "reliable")
func _show(reels: Array, win: int) -> void:
	_arm_t = 0.4
	_label.text = "%s %s %s" % [SYMBOLS[reels[0]][0], SYMBOLS[reels[1]][0], SYMBOLS[reels[2]][0]]
	_label.modulate = Color("#2E7D32") if win > 0 else Palette.OUTLINE
	Audio.play_at(&"coin" if win > 0 else &"reload", global_position + Vector3.UP, -4.0)
