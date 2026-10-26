class_name BaccaratTable
extends CasinoTable
## Baccarat for 20 scrap: F picks Player, Banker or Tie, E deals a full coup with
## the standard third-card rules. Player pays 1:1, Banker 0.95:1, Tie 8:1
## (Player and Banker bets push on a tie).

const SIDES := ["player", "banker", "tie"]
const SIDE_NAMES := ["Player", "Banker", "Tie"]

static var side := 0


func _ready() -> void:
	title = "BACCARAT  (%d scrap)" % BET
	super._ready()


func _decorate(st: SurfaceTool) -> void:
	for i in 3:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.5 + i * 0.5, 0.99, 0.1)), Vector3(0.36, 0.01, 0.3), [Color("#2E6FA8"), Color("#C9302C"), Palette.GLOW_YELLOW][i])


func interact_prompt() -> String:
	return "Baccarat: bet %d scrap on %s\nE: deal   F: change bet (Player 1:1, Banker 0.95:1, Tie 8:1)" % [BET, SIDE_NAMES[side]]


func _on_f() -> void:
	side = (side + 1) % SIDES.size()


func _local_choice() -> int:
	return side


func _act(peer_id: int, action: StringName, arg: int) -> void:
	if action != &"e" or not _take_bet(peer_id):
		return
	var bet_on: String = SIDES[clampi(arg, 0, 2)]
	var shoe := _shoe()
	var r := CasinoRules.bac_deal(shoe)
	var won := CasinoRules.bac_payout(bet_on, r["winner"], BET)
	_pay(peer_id, won)
	var verdict := "%s wins" % String(r["winner"]).capitalize() if r["winner"] != "tie" else "Tie"
	var result := ("+%d" % won) if won > BET else ("push" if won == BET else "lost")
	_show.rpc("Player: %s (%d)\nBanker: %s (%d)\n%s - your %s bet %s" % [_hand_text(r["player"]), CasinoRules.bac_value(r["player"]),
			_hand_text(r["banker"]), CasinoRules.bac_value(r["banker"]), verdict, bet_on, result], &"coin" if won > BET else &"pluck")
	Economy.notify(peer_id, "Baccarat: %s, your %s bet %s." % [verdict, bet_on, result])
