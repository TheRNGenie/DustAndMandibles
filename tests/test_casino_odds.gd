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


func test_shell_game_is_fair_with_small_edge() -> void:
	for bet: int in [10, 20, 50, 100]:
		var rtp := CasinoRules.shell_return_rate(bet)
		assert_true(rtp < 1.0, "shell %d returns %.3f" % [bet, rtp])
		assert_true(rtp > 0.92, "shell %d returns only %.3f" % [bet, rtp])
	assert_eq(CasinoRules.shell_payout(1, 1, 100), 285)
	assert_eq(CasinoRules.shell_payout(0, 2, 100), 0)


func test_shell_pea_is_uniform() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var counts := [0, 0, 0]
	for i in 9000:
		counts[CasinoRules.shell_pea(rng)] += 1
	for c: int in counts:
		assert_true(absf(c / 9000.0 - 1.0 / 3.0) < 0.03, "cup share %d" % c)


func test_race_odds_sum_and_edge() -> void:
	var total := 0.0
	for b: Array in CasinoRules.RACE_BEETLES:
		total += float(b[1])
	assert_almost(total, 1.0)
	for i in CasinoRules.RACE_BEETLES.size():
		for bet: int in [10, 20, 50, 100]:
			var rtp := CasinoRules.race_return_rate(i, bet)
			assert_true(rtp < 1.0, "beetle %d at %d returns %.3f" % [i, bet, rtp])
			assert_true(rtp > 0.88, "beetle %d at %d returns only %.3f" % [i, bet, rtp])
	# Long shots pay more than favourites.
	assert_true(CasinoRules.race_multiplier(3) > CasinoRules.race_multiplier(0))


func test_race_winner_follows_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wins := [0, 0, 0, 0]
	var n := 20000
	for i in n:
		wins[CasinoRules.race_winner(rng.randf())] += 1
	for i in 4:
		assert_true(absf(wins[i] / float(n) - float(CasinoRules.RACE_BEETLES[i][1])) < 0.015, "beetle %d won %d" % [i, wins[i]])


func test_race_animation_finishes_in_order() -> void:
	var times := CasinoRules.race_finish_times(2, 5.0, 99)
	for i in 4:
		if i != 2:
			assert_true(times[i] > times[2], "winner crosses first")
	assert_almost(CasinoRules.race_progress(0, 0.0, 5.0, 1), 0.0)
	assert_almost(CasinoRules.race_progress(0, 5.0, 5.0, 1), 1.0)
	# Monotonic enough to read as a race: never runs backwards much.
	var last := 0.0
	for k in 50:
		var p := CasinoRules.race_progress(1, k * 0.1, 5.0, 3)
		assert_true(p >= last - 0.05)
		last = p
