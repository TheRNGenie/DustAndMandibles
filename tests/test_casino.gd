extends TestCase
## Airship table games: blackjack totals and payouts, baccarat drawing rules, roulette bets.


func test_blackjack_aces_soften() -> void:
	assert_eq(CasinoRules.bj_value([1, 13]), 21)
	assert_eq(CasinoRules.bj_value([1, 1, 9]), 21)
	assert_eq(CasinoRules.bj_value([1, 5, 10]), 16)
	assert_eq(CasinoRules.bj_value([10, 12, 2]), 22)


func test_blackjack_payouts() -> void:
	assert_eq(CasinoRules.bj_payout([1, 12], [10, 9], 20), 50) # natural pays 3:2
	assert_eq(CasinoRules.bj_payout([10, 9], [10, 8], 20), 40)
	assert_eq(CasinoRules.bj_payout([10, 8], [10, 8], 20), 20) # push
	assert_eq(CasinoRules.bj_payout([10, 8, 5], [10, 6], 20), 0) # bust loses even if dealer busts later
	assert_eq(CasinoRules.bj_payout([10, 8], [10, 6, 9], 20), 40) # dealer bust


func test_dealer_stands_on_17() -> void:
	var dealer := [10, 7]
	var shoe := [5]
	CasinoRules.bj_dealer_play(dealer, shoe)
	assert_eq(dealer.size(), 2)
	dealer = [10, 2]
	shoe = [3, 4]
	CasinoRules.bj_dealer_play(dealer, shoe)
	assert_eq(CasinoRules.bj_value(dealer), 19) # draws 4 (16), then 3


func test_baccarat_naturals_stand() -> void:
	# pop_back deals from the end: player 9 (4+5), banker 3 (1+2), no third cards.
	var shoe := [7, 7, 2, 1, 5, 4]
	var r := CasinoRules.bac_deal(shoe)
	assert_eq((r["player"] as Array).size(), 2)
	assert_eq(r["winner"], "player")


func test_baccarat_banker_rule_on_three() -> void:
	# Player 1+2 = 3 draws an 8; banker 1+2 = 3 must NOT draw against an 8.
	var shoe := [9, 8, 2, 1, 2, 1]
	var r := CasinoRules.bac_deal(shoe)
	assert_eq((r["player"] as Array).size(), 3)
	assert_eq((r["banker"] as Array).size(), 2)


func test_baccarat_payouts() -> void:
	assert_eq(CasinoRules.bac_payout("player", "player", 20), 40)
	assert_eq(CasinoRules.bac_payout("banker", "banker", 20), 39)
	assert_eq(CasinoRules.bac_payout("tie", "tie", 20), 180)
	assert_eq(CasinoRules.bac_payout("player", "tie", 20), 20)
	assert_eq(CasinoRules.bac_payout("banker", "player", 20), 0)


func test_roulette_bets() -> void:
	assert_eq(CasinoRules.roulette_payout(0, 1, 20), 40) # 1 is red
	assert_eq(CasinoRules.roulette_payout(1, 1, 20), 0)
	assert_eq(CasinoRules.roulette_payout(7, 7, 20), 720) # lucky 7 pays 35:1
	assert_eq(CasinoRules.roulette_payout(0, 0, 20), 0) # zero loses outside bets
	assert_eq(CasinoRules.roulette_payout(6, 12, 20), 60)
