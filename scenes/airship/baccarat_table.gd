class_name BaccaratTable
extends CasinoTable
## Baccarat: bet on Player, Banker or Tie, then Deal a full coup with the
## standard third-card rules. Player 1:1, Banker 0.95:1, Tie 8:1 (Player and
## Banker bets push on a tie).

const SIDES := ["player", "banker", "tie"]


func ui_title() -> String:
	return "Baccarat"


func ui_rules() -> String:
	return "Bet on the hand closest to 9. Player pays 1:1, Banker 0.95:1, Tie 8:1. Player and Banker bets push on a tie."


func _decorate(st: SurfaceTool) -> void:
	for i in 3:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.5 + i * 0.5, 0.99, 0.1)), Vector3(0.36, 0.01, 0.3), [Color("#2E6FA8"), Color("#C9302C"), Palette.GLOW_YELLOW][i])


func ui_choices() -> Array:
	return ["Player", "Banker", "Tie"]


func ui_actions() -> Array:
	return [[&"deal", "Deal"]]


func _act(peer_id: int, action: StringName, choice: int, bet: int) -> void:
	if action != &"deal":
		return
	bet = _valid_bet(bet)
	if not _take(peer_id, bet):
		return
	var bet_on: String = SIDES[clampi(choice, 0, 2)]
	var r := CasinoRules.bac_deal(_shoe())
	var won := CasinoRules.bac_payout(bet_on, r["winner"], bet)
	_pay(peer_id, {&"scrap": won} if won > 0 else {})
	var verdict := "%s wins" % String(r["winner"]).capitalize() if r["winner"] != "tie" else "Tie"
	var outcome := ("you win %d scrap" % won) if won > bet else ("bet returned" if won == bet else "you lose")
	_broadcast({"kind": "cards", "peer": peer_id, "result": "%s - %s" % [verdict, outcome],
			"rows": [["Banker", r["banker"], CasinoRules.bac_value(r["banker"])], ["Player", r["player"], CasinoRules.bac_value(r["player"])]]})
