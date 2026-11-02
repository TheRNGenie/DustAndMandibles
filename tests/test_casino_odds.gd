extends TestCase
## Casino odds: the house keeps a small edge on every bet, and no bet is a money printer.


func test_shoe_has_every_card() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var shoe := CasinoRules.new_shoe(rng, 4)
	assert_eq(shoe.size(), 4 * 52)
	var counts := {}
	for c in shoe:
		counts[c] = int(counts.get(c, 0)) + 1
	for r in range(1, 14):
		assert_eq(int(counts.get(r, 0)), 16, "rank %d" % r)


func test_roulette_every_bet_has_house_edge() -> void:
	# Exact expected return over the 37 pockets of a single-zero wheel.
	for i in CasinoRules.ROULETTE_BETS.size():
		var back := 0
		for n in 37:
			back += CasinoRules.roulette_payout(i, n, 100)
		var rtp := float(back) / (37.0 * 100.0)
		assert_true(rtp < 1.0, "%s returns %.3f" % [CasinoRules.ROULETTE_BETS[i][0], rtp])
		assert_true(rtp > 0.9, "%s returns only %.3f" % [CasinoRules.ROULETTE_BETS[i][0], rtp])


func test_roulette_red_black_split() -> void:
	var red := 0
	var black := 0
	for n in range(1, 37):
		if CasinoRules.roulette_wins("red", n):
			red += 1
		if CasinoRules.roulette_wins("black", n):
			black += 1
	assert_eq(red, 18)
	assert_eq(black, 18)
	assert_false(CasinoRules.roulette_wins("red", 0))
	assert_false(CasinoRules.roulette_wins("black", 0))


func test_baccarat_returns_near_real_odds() -> void:
	# Monte Carlo: banker ~98.9%, player ~98.8%, tie ~85.6% returned. Allow slack.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var back := {"player": 0, "banker": 0, "tie": 0}
	var rounds := 20000
	var shoe := CasinoRules.new_shoe(rng, 8)
	for i in rounds:
		if shoe.size() < 10:
			shoe = CasinoRules.new_shoe(rng, 8)
		var coup := CasinoRules.bac_deal(shoe)
		for k: String in back.keys():
			back[k] += CasinoRules.bac_payout(k, String(coup["winner"]), 100)
	for k: String in back.keys():
		var rtp := float(back[k]) / float(rounds * 100)
		assert_true(rtp < 1.03 and rtp > 0.8, "%s returns %.3f" % [k, rtp])
	assert_true(float(back["banker"]) / float(rounds * 100) < 1.0 + 0.02, "banker edge")


func test_blackjack_dealer_never_stops_below_17_with_cards_left() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var shoe: Array = Array(CasinoRules.new_shoe(rng, 4))
	for i in 200:
		if shoe.size() < 20:
			shoe = Array(CasinoRules.new_shoe(rng, 4))
		var dealer: Array = [shoe.pop_back(), shoe.pop_back()]
		CasinoRules.bj_dealer_play(dealer, shoe)
		assert_true(CasinoRules.bj_value(dealer) >= 17)


func test_blackjack_odd_bet_blackjack_rounds_down() -> void:
	# 3:2 on an odd bet: 5 returns 5 + 7.
	assert_eq(CasinoRules.bj_payout([1, 13], [10, 9], 5), 12)
	assert_eq(CasinoRules.bj_payout([1, 13], [1, 12], 5), 5, "both blackjack push")
	assert_eq(CasinoRules.bj_payout([10, 5, 9], [10, 7], 5), 0, "player bust loses even if dealer busts later")
