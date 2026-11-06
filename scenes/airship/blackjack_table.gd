class_name BlackjackTable
extends CasinoTable
## Blackjack: Deal, then Hit, Stand, Double (first two cards) or Split (a first
## pair, once). Dealer stands on all 17s, a natural pays 3:2 (21 on a split hand
## pays 1:1). One player's round at a time; everyone at the table watches it.

var _hand: Dictionary = {} # host: {"peer", "bets", "hands", "active", "dealer", "shoe", "round", "doubled"}
var _round := 0


func ui_title() -> String:
	return "Blackjack"


func ui_tagline() -> String:
	return "Beat the dealer to 21 without going over."


func ui_rules() -> String:
	return "Get closer to 21 than the dealer without going over. Dealer stands on 17. Blackjack pays 3:2, a win pays 1:1. Double on your first two cards; split a pair once."


func _decorate(st: SurfaceTool) -> void:
	for i in 5:
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(-0.6 + i * 0.3, 1.0, 0.3)), 0.07, 0.07, 0.03, 10, [Color("#C9302C"), Palette.BONE, Color("#2E6FA8")][i % 3])


func make_board() -> CasinoBoard:
	return BlackjackBoard.new(self)


func anim_length() -> float:
	return deal_anim_length() if str(view.get("kind", "")) == "bj" else 0.0


func busy_text() -> String:
	return "Dealing..."


func result_text() -> String:
	if bool(view.get("in_hand", false)):
		if int(view.get("peer", 0)) != multiplayer.get_unique_id():
			return "Another hand is being played."
		return "Your move: hit, stand%s?" % (", double or split" if _can(&"split") else (" or double" if _can(&"double") else ""))
	return result_line("Place your bet and deal.")


func ui_actions() -> Array:
	if bool(view.get("in_hand", false)):
		if int(view.get("peer", 0)) == multiplayer.get_unique_id():
			var out: Array = [[&"hit", "Hit"], [&"stand", "Stand"]]
			if _can(&"double"):
				out.append([&"double", "Double"])
			if _can(&"split"):
				out.append([&"split", "Split"])
			return out
		return []
	return [[&"deal", "Deal"]]


## Whether the active hand in the view can double or split.
func _can(what: StringName) -> bool:
	var hands: Array = view.get("hands", [])
	var a := int(view.get("active", 0))
	if a >= hands.size():
		return false
	if what == &"double":
		return CasinoRules.bj_can_double(hands[a])
	return CasinoRules.bj_can_split(hands[a], hands.size())


func ui_cheat() -> Array:
	return ["Deal With an Ace Up the Sleeve", "blackjack"] if not bool(view.get("in_hand", false)) else []


func _act(peer_id: int, action: StringName, _choice: int, bet: int) -> void:
	if action == &"deal" or action == &"cheat":
		if not _hand.is_empty():
			Economy.notify(peer_id, "Wait for the current hand to finish.")
			return
		bet = _valid_bet(bet)
		if action == &"cheat" and _cheat(peer_id, "blackjack", bet) <= 0: # Brand: Snake Eyes palms an ace
			return
		if not _take(peer_id, bet):
			return
		var shoe := _shoe()
		_round += 1
		var p1: int = shoe.pop_back()
		var d1: int = shoe.pop_back()
		var p2: int = shoe.pop_back()
		if GameState.has_flag("--bjpair"): # debug: deal a pair (split screenshots)
			p2 = p1
		var d2: int = shoe.pop_back()
		_hand = {"peer": peer_id, "bets": [bet], "hands": [[p1, p2]], "active": 0, "dealer": [d1, d2], "shoe": shoe,
				"round": _round * 1000 + _rng.randi_range(0, 999), "doubled": [false]}
		if action == &"cheat":
			(_hand["hands"][0] as Array)[0] = 1
		if CasinoRules.bj_is_blackjack(_hand["hands"][0]) or CasinoRules.bj_is_blackjack(_hand["dealer"]):
			_finish()
		else:
			_send_view(false, "")
		return
	if _hand.is_empty() or int(_hand["peer"]) != peer_id:
		return
	var hands: Array = _hand["hands"]
	var a := int(_hand["active"])
	var hand: Array = hands[a]
	var shoe: Array = _hand["shoe"]
	match action:
		&"hit":
			hand.append(shoe.pop_back())
			if CasinoRules.bj_value(hand) >= 21:
				_next_hand()
			else:
				_send_view(false, "")
		&"stand":
			_next_hand()
		&"double":
			if not CasinoRules.bj_can_double(hand) or not _take(peer_id, int(_hand["bets"][a])):
				return
			_hand["bets"][a] = int(_hand["bets"][a]) * 2
			_hand["doubled"][a] = true
			hand.append(shoe.pop_back())
			_next_hand()
		&"split":
			if not CasinoRules.bj_can_split(hand, hands.size()) or not _take(peer_id, int(_hand["bets"][0])):
				return
			var second: Array = [hand[1], shoe.pop_back()]
			hand.resize(1)
			hand.append(shoe.pop_back())
			hands.append(second)
			_hand["bets"].append(int(_hand["bets"][0]))
			_hand["doubled"].append(false)
			if int(hand[0]) == 1: # split aces get one card each
				_finish()
			elif CasinoRules.bj_value(hand) == 21:
				_next_hand()
			else:
				_send_view(false, "")


## Host: on to the next split hand, or the dealer's turn.
func _next_hand() -> void:
	var hands: Array = _hand["hands"]
	_hand["active"] = int(_hand["active"]) + 1
	while int(_hand["active"]) < hands.size() and CasinoRules.bj_value(hands[int(_hand["active"])]) >= 21:
		_hand["active"] = int(_hand["active"]) + 1
	if int(_hand["active"]) >= hands.size():
		_finish()
	else:
		_send_view(false, "")


func _send_view(done: bool, result: String, outcomes: Array = []) -> void:
	var dealer: Array = _hand["dealer"]
	var hands: Array = []
	for h: Array in _hand["hands"]:
		hands.append(h.duplicate())
	_broadcast({"kind": "bj", "in_hand": not done, "peer": _hand["peer"], "round": _hand["round"], "result": result,
			"dealer": dealer.duplicate() if done else [dealer[0], 0], "hands": hands, "bets": (_hand["bets"] as Array).duplicate(),
			"active": int(_hand["active"]), "doubled": (_hand["doubled"] as Array).duplicate(), "outcomes": outcomes})


func _finish() -> void:
	var peer: int = _hand["peer"]
	var hands: Array = _hand["hands"]
	var bets: Array = _hand["bets"]
	var live := false
	for h: Array in hands:
		live = live or CasinoRules.bj_value(h) <= 21
	var natural := hands.size() == 1 and CasinoRules.bj_is_blackjack(hands[0])
	if live and not natural:
		CasinoRules.bj_dealer_play(_hand["dealer"], _hand["shoe"])
	var back := CasinoRules.bj_settle(hands, bets, _hand["dealer"])
	var total := 0
	var staked := 0
	var outcomes: Array = []
	for i in hands.size():
		total += back[i]
		staked += int(bets[i])
		var b := int(bets[i])
		outcomes.append("BLACKJACK" if back[i] > b * 2 else ("WIN" if back[i] > b else ("PUSH" if back[i] == b else ("BUST" if CasinoRules.bj_value(hands[i]) > 21 else "LOSE"))))
	_hand["active"] = hands.size()
	var dv := CasinoRules.bj_value(_hand["dealer"])
	var result := ""
	if total > staked:
		result = ("Blackjack! You win %s" if outcomes.has("BLACKJACK") else "You win %s") % UiStyle.cost(total, ResNames.PERSONAL_ID)
		if dv > 21:
			result = "Dealer busts with %d. %s" % [dv, result]
		result += _part_bonus_later(peer)
	elif total == staked:
		result = "Push. You get %s back" % UiStyle.cost(total, ResNames.PERSONAL_ID)
	elif total > 0:
		result = "One hand wins, one loses: %s back" % UiStyle.cost(total, ResNames.PERSONAL_ID)
	elif outcomes.has("BUST") and hands.size() == 1:
		result = "Bust! The house takes it"
	else:
		result = "Dealer wins with %d" % dv
	# Paid once the dealer's cards have been turned over on screen.
	var dealer_cards := (_hand["dealer"] as Array).size() - 2
	_pay_later(peer, {&"scrap": total} if total > 0 else {}, 1.0 + DEAL_GAP * (dealer_cards + 1))
	_send_view(true, result, outcomes)
	_hand = {}


## Host: a turret part, paid with the winnings (returns its line).
func _part_bonus_later(peer_id: int) -> String:
	var key := CasinoRules.part_bonus(_rng)
	if key == &"":
		return ""
	_pay_later(peer_id, {key: 1}, 2.0)
	return ". The house throws in a %s for the Workshop!" % CraftTable.part_name(key)


## Every peer: deal order for the new cards (player, dealer, player, hole card,
## then hits, then the hole card turned and the dealer's draws).
func _on_view_change(before: Dictionary) -> void:
	if str(view.get("kind", "")) != "bj":
		return
	var round_id := int(view.get("round", 0))
	var hands: Array = view.get("hands", [])
	var dealer: Array = view.get("dealer", [])
	var keys: Array = ["h0:0", "d:0", "h0:1", "d:1"]
	# A split: the second card moves across rather than coming from the shoe.
	if hands.size() > 1 and int(before.get("round", -1)) == round_id and (before.get("hands", []) as Array).size() == 1:
		deal_times["h1:0"] = Time.get_ticks_msec() / 1000.0 - 1.0
	for h in hands.size():
		for i in (hands[h] as Array).size():
			keys.append("h%d:%d" % [h, i])
	if dealer.size() > 1 and int(dealer[1]) > 0:
		keys.append("flip")
		for i in range(2, dealer.size()):
			keys.append("d:%d" % i)
	stamp_deal(round_id, keys)


func _on_view() -> void:
	Audio.play_at(&"card_flick", global_position + Vector3.UP, -4.0)


# ------------------------------------------------------------------ the felt

class BlackjackBoard extends CasinoBoard:
	const K := 1.12
	var table: BlackjackTable

	func _init(g: CasinoGame) -> void:
		super._init(g)
		table = g as BlackjackTable
		custom_minimum_size = Vector2(0, 452)

	func _shoe_at() -> Vector2:
		return Vector2(size.x - 92, 64)

	func _tick() -> void:
		for k: Variant in table.deal_times.keys():
			if due("deal_" + str(k), float(table.deal_times[k]) - game.view_at):
				sfx(&"card_flick", -6.0, 1.15 if str(k) == "flip" else 1.0)

	func _draw_game() -> void:
		var r := Rect2(Vector2.ZERO, size)
		felt(r, 26)
		var c := Vector2(size.x * 0.5, 0)
		# The printed felt: payouts and the dealer's rule bent along the table's curve.
		var arc_c := Vector2(size.x * 0.5, -362)
		draw_arc(arc_c, 540, PI * 0.5 - 0.62, PI * 0.5 + 0.62, 64, Color(GOLD, 0.45), 2.0, true)
		arc_text(arc_c, 566, 0.0, "BLACKJACK PAYS 3 TO 2", 26, Color(GOLD, 0.85))
		arc_text(arc_c, 598, 0.0, "Dealer Must Stand on 17 and Draw to 16", 17, Color(1, 1, 1, 0.6), false)
		chip_rack(Rect2(c.x - 130, 14, 260, 34))
		shoe_box(_shoe_at())
		# Discard tray, top left.
		rrect(Rect2(40, 26, 74, 96), Color(0, 0, 0, 0.25), 6, 2, Color(GOLD, 0.4))
		text(Vector2(77, 136), "DISCARD", 10, Color(1, 1, 1, 0.4), 0, 0, true)
		var v := game.view
		var playing := str(v.get("kind", "")) == "bj"
		var round_id := int(v.get("round", 0))
		var shoe := _shoe_at()
		var now := Time.get_ticks_msec() / 1000.0
		# Dealer's hand.
		var dealer: Array = v.get("dealer", []) if playing else []
		var dx := c.x - (dealer.size() - 1) * 18.0 * K
		var vis: Array = []
		for i in dealer.size():
			var rank := int(dealer[i])
			var key := "d:%d" % i
			var hole := i == 1
			deal_card(table, key, Vector2(dx + i * 36.0 * K, 112), rank, BlackjackTable.card_suit(round_id, key), shoe, 0.0, K, hole)
			var landed := not table.deal_times.has(key) or now >= float(table.deal_times[key]) + 0.25
			if hole:
				landed = rank > 0 and table.deal_times.has("flip") and now >= float(table.deal_times["flip"]) + 0.15
			if landed and rank > 0:
				vis.append(rank)
		if not vis.is_empty():
			plaque(Vector2(dx - 80, 112), _total_text(vis))
		# Player hands with their bets.
		var hands: Array = v.get("hands", []) if playing else []
		var bets: Array = v.get("bets", [])
		var outcomes: Array = v.get("outcomes", [])
		var doubled: Array = v.get("doubled", [])
		var n := maxi(hands.size(), 1)
		for h in n:
			var hx := c.x + (h - (n - 1) * 0.5) * 300.0
			var spot := Vector2(hx, 406)
			ring(spot, 34, Color(GOLD, 0.7), 2.0)
			ring(spot, 28, Color(1, 1, 1, 0.25), 1.0)
			var bet := int(bets[h]) if h < bets.size() and playing else game.stake()
			chip_stack(spot + Vector2(0, 6), 22, bet, 1.0 if playing and h < hands.size() else 0.55)
			if h >= hands.size():
				text(spot + Vector2(0, -88), "Place Your Bet", 18, Color(1, 1, 1, 0.55), 0, 0, true)
				continue
			var hand: Array = hands[h]
			var x0 := hx - (hand.size() - 1) * 15.0 * K
			var landed: Array = []
			for i in hand.size():
				var key := "h%d:%d" % [h, i]
				var rot := PI * 0.5 if h < doubled.size() and bool(doubled[h]) and i == 2 else 0.0
				var at := Vector2(x0 + i * 30.0 * K + (24.0 if rot != 0.0 else 0.0), 318 - i * 4.0)
				deal_card(table, key, at, int(hand[i]), BlackjackTable.card_suit(round_id, key), shoe, rot, K)
				if not table.deal_times.has(key) or now >= float(table.deal_times[key]) + 0.25:
					landed.append(hand[i])
			if not landed.is_empty():
				plaque(Vector2(x0 - 82, 318), _total_text(landed, hands.size() > 1))
			var active := bool(v.get("in_hand", false)) and int(v.get("active", 0)) == h
			if active and hands.size() > 1:
				var bob := sin(Time.get_ticks_msec() / 200.0) * 4.0
				poly(PackedVector2Array([Vector2(hx - 12, 244 + bob), Vector2(hx + 12, 244 + bob), Vector2(hx, 258 + bob)]), GOLD)
			if h < outcomes.size() and not game.ui_busy():
				_badge(Vector2(hx + 76, 400), str(outcomes[h]))

	func _total_text(cards: Array, split: bool = false) -> String:
		var t := CasinoRules.bj_value(cards)
		if t > 21:
			return "Bust %d" % t
		if not split and CasinoRules.bj_is_blackjack(cards):
			return "Blackjack"
		var hard := 0
		for c: int in cards:
			hard += mini(c, 10)
		return ("Soft %d" % t) if cards.has(1) and hard + 10 == t else str(t)

	func _badge(at: Vector2, s: String) -> void:
		var col := Color("#2E7D32") if s == "WIN" or s == "BLACKJACK" else (Color("#8C949C") if s == "PUSH" else RED)
		var w := text_width(s, 16, true) + 20
		draw_set_transform(at, -0.15, Vector2.ONE)
		rrect(Rect2(-w * 0.5, -15, w, 30), col, 6, 2, CREAM)
		text(Vector2.ZERO, s, 16, CREAM, 0, 0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
