class_name BlackjackTable
extends CasinoTable
## Blackjack for 20 scrap: E deals, then E hits and F stands. Dealer stands on
## all 17s, a natural pays 3:2. One player's hand at a time per peer; the sign
## shows the latest hand.

## peer -> {"player": Array, "dealer": Array, "shoe": Array}
var _hands: Dictionary = {}
var _local_in_hand := false


func _ready() -> void:
	title = "BLACKJACK  (%d scrap)" % BET
	super._ready()


func _decorate(st: SurfaceTool) -> void:
	for i in 5:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.6 + i * 0.3, 1.0, 0.3)), 0.07, 0.07, 0.03, 10, [Color("#C9302C"), Palette.BONE, Color("#2E6FA8")][i % 3])


func interact_prompt() -> String:
	if _local_in_hand:
		return "Blackjack: E hit   F stand"
	return "Blackjack: %d scrap a hand\nE: deal. Dealer stands on 17, blackjack pays 3:2." % BET


func _on_f() -> void:
	if _local_in_hand:
		_send(&"stand", 0)


func _act(peer_id: int, action: StringName, _arg: int) -> void:
	var h: Dictionary = _hands.get(peer_id, {})
	if action == &"e" and h.is_empty():
		if not _take_bet(peer_id):
			return
		var shoe := _shoe()
		h = {"player": [shoe.pop_back(), shoe.pop_back()], "dealer": [shoe.pop_back(), shoe.pop_back()], "shoe": shoe}
		_hands[peer_id] = h
		if CasinoRules.bj_is_blackjack(h["player"]) or CasinoRules.bj_is_blackjack(h["dealer"]):
			_finish(peer_id)
			return
		_update(peer_id, false)
	elif action == &"e":
		(h["player"] as Array).append((h["shoe"] as Array).pop_back())
		if CasinoRules.bj_value(h["player"]) >= 21:
			_finish(peer_id)
		else:
			_update(peer_id, false)
	elif action == &"stand" and not h.is_empty():
		_finish(peer_id)


func _update(peer_id: int, done: bool) -> void:
	var h: Dictionary = _hands[peer_id]
	var dealer: Array = h["dealer"]
	var dealer_text := _hand_text(dealer) if done else "%s ??" % _hand_text([dealer[0]])
	var text := "You: %s (%d)\nDealer: %s" % [_hand_text(h["player"]), CasinoRules.bj_value(h["player"]), dealer_text]
	_show.rpc(text, &"pluck")
	if peer_id != multiplayer.get_unique_id():
		_set_in_hand.rpc_id(peer_id, not done)
	else:
		_set_in_hand(not done)


func _finish(peer_id: int) -> void:
	var h: Dictionary = _hands[peer_id]
	if CasinoRules.bj_value(h["player"]) <= 21:
		CasinoRules.bj_dealer_play(h["dealer"], h["shoe"])
	var won := CasinoRules.bj_payout(h["player"], h["dealer"], BET)
	_pay(peer_id, won)
	var result := "BLACKJACK! +%d" % won if won > BET * 2 else ("You win +%d" % won if won > BET else ("Push" if won == BET else "Dealer wins"))
	_show.rpc("You: %s (%d)\nDealer: %s (%d)\n%s" % [_hand_text(h["player"]), CasinoRules.bj_value(h["player"]),
			_hand_text(h["dealer"]), CasinoRules.bj_value(h["dealer"]), result], &"coin" if won > BET else &"reload")
	Economy.notify(peer_id, "Blackjack: %s" % result)
	_hands.erase(peer_id)
	if peer_id != multiplayer.get_unique_id():
		_set_in_hand.rpc_id(peer_id, false)
	else:
		_set_in_hand(false)


@rpc("authority", "call_remote", "reliable")
func _set_in_hand(on: bool) -> void:
	_local_in_hand = on
