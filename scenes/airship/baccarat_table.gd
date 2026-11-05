class_name BaccaratTable
extends CasinoTable
## Baccarat: click Player, Banker or Tie on the felt, then Deal a full coup
## with the standard third-card rules. Player 1:1, Banker 0.95:1 (the house's
## 5% commission), Tie 8:1 (Player and Banker bets push on a tie). The cards go
## to their boxes one by one, third cards sideways, and the croupier calls the
## rule each draw followed; the bead road keeps the shoe's history.

const SIDES := ["player", "banker", "tie"]
const ROAD := 36

var _round := 0
var _road: Array = [] # host: past winners, oldest first


func ui_title() -> String:
	return "Baccarat"


func ui_tagline() -> String:
	return "Back the Player, the Banker or a Tie. Closest to 9 wins."


func ui_rules() -> String:
	return "Bet on the hand closest to 9. Player pays 1:1, Banker 0.95:1, Tie 8:1. Player and Banker bets push on a tie."


func _decorate(st: SurfaceTool) -> void:
	for i in 3:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.5 + i * 0.5, 0.99, 0.1)), Vector3(0.36, 0.01, 0.3), [Color("#2E6FA8"), Color("#C9302C"), Palette.GLOW_YELLOW][i])


func ui_choices() -> Array:
	return ["Player", "Banker", "Tie"]


func board_picks() -> bool:
	return true


func ui_actions() -> Array:
	return [[&"deal", "Deal"]]


func make_board() -> CasinoBoard:
	return BaccaratBoard.new(self)


func anim_length() -> float:
	return deal_anim_length() + 0.3 if str(view.get("kind", "")) == "bac" else 0.0


func busy_text() -> String:
	return "Cards..."


func result_text() -> String:
	if str(view.get("kind", "")) != "bac":
		return "Click Player, Banker or Tie on the felt, then deal."
	return result_line()


func _act(peer_id: int, action: StringName, choice: int, bet: int) -> void:
	if action != &"deal" or ui_busy_host():
		return
	bet = _valid_bet(bet)
	if not _take(peer_id, bet):
		return
	var bet_on: String = SIDES[clampi(choice, 0, 2)]
	var r := CasinoRules.bac_deal(_shoe())
	var won := CasinoRules.bac_payout(bet_on, r["winner"], bet)
	var verdict := "%s wins" % String(r["winner"]).capitalize() if r["winner"] != "tie" else "Tie"
	var pv := CasinoRules.bac_value(r["player"])
	var bv := CasinoRules.bac_value(r["banker"])
	var outcome := ("you win %s" % UiStyle.cost(won, ResNames.TEAM_ID)) if won > bet else ("your bet comes back" if won == bet else "the house takes it")
	var prize: Dictionary = {&"scrap": won} if won > 0 else {}
	if won > bet:
		var key := CasinoRules.part_bonus(_rng)
		if key != &"":
			prize[key] = 1
			outcome += ". The house throws in a %s for the Workshop!" % CraftTable.part_name(key)
	var cards := (r["player"] as Array).size() + (r["banker"] as Array).size()
	_pay_later(peer_id, prize, DEAL_GAP * cards + 0.5)
	_road.append(r["winner"])
	if _road.size() > ROAD:
		_road.pop_front()
	_round += 1
	_busy_until = Time.get_ticks_msec() / 1000.0 + DEAL_GAP * cards + 0.4
	_broadcast({"kind": "bac", "peer": peer_id, "round": _round * 1000 + _rng.randi_range(0, 999), "bet_on": bet_on, "bet": bet,
			"player": r["player"], "banker": r["banker"], "winner": r["winner"], "win": won, "road": _road.duplicate(),
			"calls": CasinoRules.bac_explain(r["player"], r["banker"]),
			"result": "%s, %d to %d: %s" % [verdict, maxi(pv, bv), mini(pv, bv), outcome]})


var _busy_until := 0.0


## Host: one coup at a time on the felt.
func ui_busy_host() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _busy_until


## Every peer: the dealing order (Player, Banker, Player, Banker, then the thirds).
func _on_view_change(_before: Dictionary) -> void:
	if str(view.get("kind", "")) != "bac":
		return
	var keys: Array = ["p:0", "b:0", "p:1", "b:1"]
	if (view.get("player", []) as Array).size() > 2:
		keys.append("p:2")
	if (view.get("banker", []) as Array).size() > 2:
		keys.append("b:2")
	stamp_deal(int(view.get("round", 0)), keys)


# ------------------------------------------------------------------ the felt

class BaccaratBoard extends CasinoBoard:
	const K := 1.05
	const BLUE := Color("#2E5FA3")
	var table: BaccaratTable
	var _hover_side := -1

	func _init(g: CasinoGame) -> void:
		super._init(g)
		table = g as BaccaratTable
		custom_minimum_size = Vector2(0, 452)

	func _road_x() -> float:
		return size.x - 238.0

	func _shoe_at() -> Vector2:
		return Vector2(74, 92)

	func _tick() -> void:
		for k: Variant in table.deal_times.keys():
			if due("deal_" + str(k), float(table.deal_times[k]) - game.view_at):
				sfx(&"card_flick", -6.0, 1.05 if str(k).ends_with("2") else 1.0)
		if str(game.view.get("kind", "")) == "bac" and due("verdict", game.anim_length() - 0.1):
			sfx(&"bell", -14.0, 1.4)

	func _area(i: int) -> Rect2:
		var w := (_road_x() - 60.0) / 3.0
		var order := [0, 2, 1] # Player, Tie, Banker left to right
		var slot: int = order.find(i)
		return Rect2(24 + slot * (w + 6), 300, w, 128)

	func _draw_game() -> void:
		felt(Rect2(Vector2.ZERO, size), 26)
		var v := game.view
		var playing := str(v.get("kind", "")) == "bac"
		var done := playing and not game.ui_busy()
		var round_id := int(v.get("round", 0))
		var shoe := _shoe_at()
		var mid := _road_x() * 0.5
		shoe_box(shoe)
		var now := Time.get_ticks_msec() / 1000.0
		# The two card boxes.
		for side in 2:
			var box_name := "PLAYER" if side == 0 else "BANKER"
			var col := BLUE if side == 0 else RED
			var box := Rect2(mid + (-300 if side == 0 else 24), 40, 276, 150)
			rrect(box, Color(0, 0, 0, 0.12), 14, 2, col.lightened(0.3))
			text(Vector2(box.get_center().x, box.position.y + 14), box_name, 15, col.lightened(0.45), 0, 3, true)
			var hand: Array = v.get("player" if side == 0 else "banker", []) if playing else []
			var landed: Array = []
			for i in hand.size():
				var key := ("p:%d" if side == 0 else "b:%d") % i
				var at := box.position + Vector2(56 + i * 74, 80)
				var rot := 0.0
				if i == 2:
					at = box.position + Vector2(56 + 2 * 74 + 10, 86)
					rot = PI * 0.5
				deal_card(table, key, at, int(hand[i]), BaccaratTable.card_suit(round_id, key), shoe, rot, K)
				if not table.deal_times.has(key) or now >= float(table.deal_times[key]) + 0.25:
					landed.append(hand[i])
			if not landed.is_empty():
				var won := done and str(v.get("winner", "")) == ("player" if side == 0 else "banker")
				plaque(Vector2(box.get_center().x, box.end.y + 20), str(CasinoRules.bac_value(landed)), GOLD if won else Color("#F2E3C2"))
		# The croupier's calls, as the cards land.
		var calls: PackedStringArray = v.get("calls", PackedStringArray()) if playing else PackedStringArray()
		var y := 250.0
		for i in calls.size():
			var when := float(table.deal_times.get("b:1", 0.0)) + 0.3 if i == 0 else table.deal_last + 0.3
			if now >= when:
				text(Vector2(mid, y), calls[i], 15, Color(1, 1, 1, 0.85), 0, 3)
				y += 20
		if done:
			var w := str(v.get("winner", ""))
			var label := "TIE" if w == "tie" else ("%s WINS" % w.to_upper())
			text(Vector2(mid, 222), label, 22, GOLD, 0, 5, true)
		# The betting areas.
		var bet_on := str(v.get("bet_on", "")) if playing else ""
		for i in 3:
			var a := _area(i)
			var col: Color = [BLUE, RED, Color("#3F8F3A")][i]
			var picked := i == game.ui_choice
			var lit: bool = done and str(v.get("winner", "")) == BaccaratTable.SIDES[i]
			rrect(a, Color(col, 0.35 if not lit else 0.6 + 0.2 * sin(now * 8.0)), 16, 3 if picked else 2, GOLD if picked else Color(1, 1, 1, 0.6))
			if i == _hover_side and not game.ui_busy():
				rrect(a, Color(1, 1, 1, 0.08), 16)
			var title: String = ["PLAYER", "BANKER", "TIE"][i]
			text(Vector2(a.get_center().x, a.position.y + 24), title, 22, CREAM, 0, 4, true)
			var pays: String = ["Pays 1 to 1", "Pays 19 to 20", "Pays 8 to 1"][i]
			text(Vector2(a.get_center().x, a.position.y + 48), pays, 13, Color(1, 1, 1, 0.8))
			if i == 1:
				text(Vector2(a.get_center().x, a.position.y + 66), "5% Commission on Banker Wins", 11, Color(1, 1, 1, 0.6))
			# Your chips: the stake you'll put down, or the coup's bet.
			var stake := 0
			if playing and game.ui_busy():
				stake = int(v.get("bet", 0)) if bet_on == BaccaratTable.SIDES[i] else 0
			elif picked:
				stake = game.stake()
			if stake > 0:
				chip_stack(Vector2(a.get_center().x, a.end.y - 30), 20, stake, 1.0 if game.ui_busy() or (done and bet_on == BaccaratTable.SIDES[i]) else 0.7)
		_road(Rect2(_road_x() + 10, 14, size.x - _road_x() - 28, 414))

	## The bead road: every coup of the shoe as a dot (P blue, B red, T green), in columns of six.
	func _road(r: Rect2) -> void:
		rrect(r, CREAM, 8, 3, WOOD)
		text(Vector2(r.get_center().x, r.position.y + 18), "BEAD ROAD", 15, INK, 0, 0, true)
		var road: Array = game.view.get("road", [])
		if game.ui_busy() and not road.is_empty():
			road = road.slice(0, road.size() - 1)
		var cell := (r.size.x - 20) / 6.0
		for i in 36:
			var col_i := floori(i / 6.0)
			var row_i := i % 6
			var c := Vector2(r.position.x + 10 + (row_i + 0.5) * cell, r.position.y + 42 + (col_i + 0.5) * cell)
			draw_arc(c, cell * 0.42, 0, TAU, 16, Color(WOOD, 0.25), 1.0, true)
			if i < road.size():
				var w := str(road[i])
				var col := BLUE if w == "player" else (RED if w == "banker" else Color("#3F8F3A"))
				draw_circle(c, cell * 0.4, col)
				text(c, w.substr(0, 1).to_upper(), 12, CREAM, 0, 0, true)
		var counts := {"player": 0, "banker": 0, "tie": 0}
		for w: Variant in road:
			counts[str(w)] = int(counts.get(str(w), 0)) + 1
		var y := r.position.y + 42 + cell * 6 + 22
		text(Vector2(r.position.x + 14, y), "Player  %d" % counts["player"], 14, BLUE, -1, 0, true)
		text(Vector2(r.position.x + 14, y + 22), "Banker  %d" % counts["banker"], 14, RED, -1, 0, true)
		text(Vector2(r.position.x + 14, y + 44), "Tie  %d" % counts["tie"], 14, Color("#3F8F3A"), -1, 0, true)

	func _side_at(p: Vector2) -> int:
		for i in 3:
			if _area(i).has_point(p):
				return i
		return -1

	func _hover(p: Vector2) -> void:
		_hover_side = _side_at(p)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover_side >= 0 else Control.CURSOR_ARROW

	func _click(p: Vector2, right: bool) -> bool:
		var i := _side_at(p)
		if right or i < 0 or game.ui_busy():
			return false
		game.ui_choice = i
		sfx(&"dice", -8.0, 1.8)
		game.ui_changed.emit()
		return true
