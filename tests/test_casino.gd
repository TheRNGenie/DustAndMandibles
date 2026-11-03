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


func test_blackjack_double_and_split() -> void:
	assert_true(CasinoRules.bj_can_double([5, 6]))
	assert_false(CasinoRules.bj_can_double([5, 6, 2]), "only on two cards")
	assert_false(CasinoRules.bj_can_double([1, 13]), "not on a natural")
	assert_true(CasinoRules.bj_can_split([8, 8], 1))
	assert_false(CasinoRules.bj_can_split([8, 8], 2), "one split a round")
	assert_false(CasinoRules.bj_can_split([10, 13], 1), "same rank only")
	# A doubled 20 against 18 pays even money on the doubled bet.
	assert_eq(CasinoRules.bj_settle([[5, 6, 9]], [40], [10, 8]), [80] as Array[int])
	# Split 21 on two cards is not a natural (1:1), and a split bust loses alone.
	assert_eq(CasinoRules.bj_settle([[1, 13], [1, 5, 10, 9]], [20, 20], [10, 9]), [40, 0] as Array[int])
	assert_eq(CasinoRules.bj_payout([1, 13], [10, 9], 20, true), 40)
	assert_eq(CasinoRules.bj_payout([10, 9], [10, 9], 20, true), 20)


func test_baccarat_banker_rule_and_calls() -> void:
	assert_true(CasinoRules.bac_banker_draws(5, -1), "player stood: banker draws on 0-5")
	assert_false(CasinoRules.bac_banker_draws(6, -1))
	assert_true(CasinoRules.bac_banker_draws(3, 9))
	assert_false(CasinoRules.bac_banker_draws(3, 8))
	assert_true(CasinoRules.bac_banker_draws(6, 7))
	assert_false(CasinoRules.bac_banker_draws(6, 5))
	assert_false(CasinoRules.bac_banker_draws(7, 1))
	assert_eq(CasinoRules.bac_explain([9, 13], [2, 3]), PackedStringArray(["Natural 9! No more cards."]))
	var calls := CasinoRules.bac_explain([2, 2, 6], [3, 3, 1])
	assert_eq(calls[0], "Player on 4 draws.")
	assert_eq(calls[1], "Banker on 6 draws against a Player third card of 6.")
	assert_eq(CasinoRules.bac_explain([3, 4], [2, 2, 5])[1], "Banker on 4 draws.")


func test_roulette_wheel_order() -> void:
	var order := CasinoRules.WHEEL_ORDER
	assert_eq(order.size(), 37)
	var seen := {}
	for n: int in order:
		seen[n] = true
	assert_eq(seen.size(), 37, "every number once")
	assert_eq(order[0], 0)
	assert_eq(order[1], 32)
	assert_eq(order[36], 26)
	for i in range(1, 37):
		var a := CasinoRules.roulette_colour(order[i])
		var b := CasinoRules.roulette_colour(order[i % 36 + 1])
		assert_true(a != b, "red and black alternate round the wheel (%d, %d)" % [order[i], order[i % 36 + 1]])


func test_roulette_layout_payouts() -> void:
	assert_eq(CasinoRules.roulette_settle({"n17": 10}, 17), 360)
	assert_eq(CasinoRules.roulette_settle({"n17": 10}, 18), 0)
	assert_eq(CasinoRules.roulette_settle({"red": 20, "black": 20}, 0), 0, "zero takes the outside bets")
	assert_eq(CasinoRules.roulette_settle({"n0": 10}, 0), 360)
	assert_eq(CasinoRules.roulette_settle({"dozen2": 10, "col3": 10}, 24), 60, "24: 2nd dozen and the top column")
	assert_eq(CasinoRules.roulette_settle({"dozen3": 10, "col1": 10}, 24), 0)
	assert_eq(CasinoRules.roulette_settle({"red": 10, "odd": 10, "low": 10, "n1": 10}, 1), 20 + 20 + 20 + 360)
	assert_true(CasinoRules.roulette_spot_wins("col1", 34) and CasinoRules.roulette_spot_wins("col2", 35) and CasinoRules.roulette_spot_wins("col3", 36))
	assert_true(CasinoRules.roulette_spot_wins("dozen1", 12) and CasinoRules.roulette_spot_wins("dozen3", 25))
	# Every spot returns its fair share less the zero (36/37) on average.
	for spot: String in ["n5", "red", "even", "high", "dozen1", "col2"]:
		var back := 0
		for n in 37:
			back += CasinoRules.roulette_settle({spot: 10}, n)
		assert_eq(back, 360, spot)
	var clean := CasinoRules.roulette_clean({"n40": 10, "red": -5, "black": 10, "odd": 400, "seven": 10, "col2": 20})
	assert_eq(clean, {"black": 10, "col2": 20})


func test_shell_moves_are_shared() -> void:
	var a := CasinoRules.shell_moves(1234)
	var b := CasinoRules.shell_moves(1234)
	assert_eq(a, b, "every peer animates the same shuffle")
	assert_true((a["swaps"] as Array).size() >= 5)
	for sw: Array in a["swaps"]:
		assert_true(int(sw[0]) < int(sw[1]) and int(sw[1]) <= 2)
	var t := CasinoRules.shell_tracked({"start": 0, "swaps": [[0, 1, 1.0], [1, 2, 1.0], [0, 1, 1.0]]})
	assert_eq(t, 2)


func test_prize_wheel_chitin_spins_favour_rare_wedges() -> void:
	var c := CasinoRules.wheel_rare_chance(&"chitin")
	var s := CasinoRules.wheel_rare_chance(&"scrap")
	assert_true(c > s * 2.0, "chitin rare %.2f vs scrap %.2f" % [c, s])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rare := {&"chitin": 0, &"scrap": 0}
	for cur: StringName in [&"chitin", &"scrap"]:
		for n in 4000:
			if CasinoRules.wheel_is_rare(CasinoRules.wheel_pick(rng, cur)):
				rare[cur] += 1
	assert_true(absf(rare[&"chitin"] / 4000.0 - c) < 0.03, "chitin picks match the odds")
	assert_true(absf(rare[&"scrap"] / 4000.0 - s) < 0.03, "scrap picks match the odds")
