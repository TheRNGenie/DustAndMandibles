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


func test_slots_pay_back_fairly() -> void:
	var rate := CasinoRules.slot_return_rate()
	assert_true(rate > 0.7 and rate < 0.95, "slots return %.3f of stakes in scrap" % rate)


func test_slots_prizes() -> void:
	# Symbol order: BUG, CACTUS, CHILI, HORSESHOE, STAR.
	assert_eq(CasinoRules.slot_prize([0, 0, 0], 10), {})
	assert_eq(CasinoRules.slot_prize([1, 1, 0], 10), {&"scrap": 10}) # a pair returns the stake
	assert_eq(CasinoRules.slot_prize([0, 0, 1], 10), {}) # bug pairs pay nothing
	assert_eq(CasinoRules.slot_prize([3, 0, 3], 10), {&"scrap": 20})
	assert_eq(CasinoRules.slot_prize([2, 2, 2], 10), {&"scrap": 150, &"seed_chili": 3})
	assert_eq(CasinoRules.slot_prize([4, 4, 4], 10), {&"scrap": 600, &"upgrade_token": 1})
	assert_eq(CasinoRules.slot_prize([0, 1, 2], 10), {})


func test_prize_wheel_has_useful_prizes() -> void:
	var kinds: Dictionary = {}
	var busts := 0
	for w: Array in CasinoRules.WHEEL_WEDGES:
		if (w[1] as Dictionary).is_empty():
			busts += 1
		for k: Variant in (w[1] as Dictionary).keys():
			kinds[k] = true
	assert_eq(busts, 3)
	assert_true(kinds.has(&"upgrade_token") and kinds.has(&"seed_chili") and kinds.has(&"chitin"))


func test_prize_text() -> void:
	assert_eq(CasinoRules.prize_text({&"scrap": 600, &"upgrade_token": 1}), "600 scrap + 1 upgrade token")
	assert_eq(CasinoRules.prize_text({&"seed_chili": 3}), "3 chili seeds")


func test_turret_part_prizes() -> void:
	var has_part := false
	for w: Array in CasinoRules.WHEEL_WEDGES:
		has_part = has_part or (w[1] as Dictionary).has(CasinoRules.WHEEL_PART)
	assert_true(has_part, "the wheel has a turret part wedge")
	assert_true(CasinoRules.PART_CHANCE > 0.0 and CasinoRules.PART_CHANCE <= 0.1, "part bonuses stay modest")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var got := 0
	for i in 2000:
		var k := CasinoRules.part_bonus(rng)
		if k != &"":
			got += 1
			assert_true(CraftTable.is_part(k))
	assert_true(got > 40 and got < 180, "about 5 in 100 wins: %d" % got)
	assert_eq(CasinoRules.prize_text({&"part_swivel": 1}), "a Swivel mount")
