class_name BlackjackTable
extends CasinoTable
## Blackjack: Deal, then Hit or Stand. Dealer stands on all 17s, a natural pays
## 3:2. One hand at a time at this table.

var _hand: Dictionary = {} # host: {"peer", "bet", "player", "dealer", "shoe"}


func ui_title() -> String:
	return "Blackjack"


func ui_rules() -> String:
	return "Get closer to 21 than the dealer without going over. Dealer stands on 17. Blackjack pays 3:2, a win pays 1:1."


func _decorate(st: SurfaceTool) -> void:
	for i in 5:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.6 + i * 0.3, 1.0, 0.3)), 0.07, 0.07, 0.03, 10, [Color("#C9302C"), Palette.BONE, Color("#2E6FA8")][i % 3])


func ui_actions() -> Array:
	if bool(view.get("in_hand", false)):
		if int(view.get("peer", 0)) == multiplayer.get_unique_id():
			return [[&"hit", "Hit"], [&"stand", "Stand"]]
		return []
	return [[&"deal", "Deal"]]


func _act(peer_id: int, action: StringName, _choice: int, bet: int) -> void:
	if action == &"deal":
		if not _hand.is_empty():
			Economy.notify(peer_id, "Wait for the current hand to finish.")
			return
		bet = _valid_bet(bet)
		if not _take(peer_id, bet):
			return
		var shoe := _shoe()
		_hand = {"peer": peer_id, "bet": bet, "player": [shoe.pop_back(), shoe.pop_back()],
				"dealer": [shoe.pop_back(), shoe.pop_back()], "shoe": shoe}
		if CasinoRules.bj_is_blackjack(_hand["player"]) or CasinoRules.bj_is_blackjack(_hand["dealer"]):
			_finish()
		else:
			_send_view(false, "Hit or stand?")
	elif _hand.is_empty() or int(_hand["peer"]) != peer_id:
		return
	elif action == &"hit":
		(_hand["player"] as Array).append((_hand["shoe"] as Array).pop_back())
		if CasinoRules.bj_value(_hand["player"]) >= 21:
			_finish()
		else:
			_send_view(false, "Hit or stand?")
	elif action == &"stand":
		_finish()


func _send_view(done: bool, result: String) -> void:
	var dealer: Array = _hand["dealer"]
	var shown: Array = dealer if done else [dealer[0], 0] # 0 = face-down card
	_broadcast({"kind": "cards", "in_hand": not done, "peer": _hand["peer"], "result": result,
			"rows": [["Dealer", shown, CasinoRules.bj_value(dealer) if done else CasinoRules.bj_value([dealer[0]])],
				["You", _hand["player"], CasinoRules.bj_value(_hand["player"])]]})


func _finish() -> void:
	var peer: int = _hand["peer"]
	var bet: int = _hand["bet"]
	if CasinoRules.bj_value(_hand["player"]) <= 21:
		CasinoRules.bj_dealer_play(_hand["dealer"], _hand["shoe"])
	var won := CasinoRules.bj_payout(_hand["player"], _hand["dealer"], bet)
	_pay(peer, {&"scrap": won} if won > 0 else {})
	var result := "BLACKJACK! You win %d" % won if won > bet * 2 else ("You win %d scrap" % won if won > bet else ("Push, bet returned" if won == bet else "Dealer wins"))
	_send_view(true, result)
	_hand = {}
