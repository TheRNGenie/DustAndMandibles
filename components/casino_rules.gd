class_name CasinoRules
extends RefCounted
## Pure rules for the airship's table games (blackjack, baccarat, roulette), kept
## free of nodes so they can be unit tested. Cards are ints 1-13 (ace = 1).

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := ["s", "h", "d", "c"]
const RED_NUMBERS: Array[int] = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
## Roulette bets: id, label, payout (to 1).
const ROULETTE_BETS: Array[Array] = [["red", "Red", 1], ["black", "Black", 1], ["odd", "Odd", 1], ["even", "Even", 1],
	["low", "1-18", 1], ["high", "19-36", 1], ["dozen1", "1st dozen", 2], ["seven", "Lucky 7", 35]]


static func new_shoe(rng: RandomNumberGenerator, decks: int = 4) -> Array[int]:
	var shoe: Array[int] = []
	for d in decks * 4:
		for r in 13:
			shoe.append(r + 1)
	for i in range(shoe.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := shoe[i]
		shoe[i] = shoe[j]
		shoe[j] = tmp
	return shoe


static func card_text(c: int, rng_suit: int = 0) -> String:
	return RANKS[clampi(c, 1, 13) - 1] + SUITS[rng_suit % 4]


# ------------------------------------------------------------------ blackjack

## Best total for a blackjack hand (aces count 11 when that doesn't bust).
static func bj_value(hand: Array) -> int:
	var total := 0
	var aces := 0
	for c: int in hand:
		if c == 1:
			aces += 1
			total += 11
		else:
			total += mini(c, 10)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


static func bj_is_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and bj_value(hand) == 21


## Dealer draws to 17 (stands on all 17s).
static func bj_dealer_play(dealer: Array, shoe: Array) -> void:
	while bj_value(dealer) < 17 and not shoe.is_empty():
		dealer.append(shoe.pop_back())


## Total returned to the player for a finished hand (0 = lost the bet).
static func bj_payout(player: Array, dealer: Array, bet: int) -> int:
	var p := bj_value(player)
	var d := bj_value(dealer)
	if p > 21:
		return 0
	if bj_is_blackjack(player) and not bj_is_blackjack(dealer):
		return bet + int(bet * 1.5)
	if bj_is_blackjack(dealer) and not bj_is_blackjack(player):
		return 0
	if d > 21 or p > d:
		return bet * 2
	if p == d:
		return bet
	return 0


# ------------------------------------------------------------------ baccarat

static func bac_value(hand: Array) -> int:
	var total := 0
	for c: int in hand:
		total += 0 if c >= 10 else c
	return total % 10


## Deals a full coup with the standard third-card rules.
## Returns {"player": Array, "banker": Array, "winner": "player" | "banker" | "tie"}.
static func bac_deal(shoe: Array) -> Dictionary:
	var player: Array = [shoe.pop_back(), shoe.pop_back()]
	var banker: Array = [shoe.pop_back(), shoe.pop_back()]
	var pv := bac_value(player)
	var bv := bac_value(banker)
	if pv < 8 and bv < 8:
		var third := -1
		if pv <= 5:
			third = shoe.pop_back()
			player.append(third)
		if third < 0:
			if bv <= 5:
				banker.append(shoe.pop_back())
		else:
			var t := 0 if third >= 10 else third
			var draw := false
			match bv:
				0, 1, 2:
					draw = true
				3:
					draw = t != 8
				4:
					draw = t >= 2 and t <= 7
				5:
					draw = t >= 4 and t <= 7
				6:
					draw = t == 6 or t == 7
			if draw:
				banker.append(shoe.pop_back())
	pv = bac_value(player)
	bv = bac_value(banker)
	var winner := "tie" if pv == bv else ("player" if pv > bv else "banker")
	return {"player": player, "banker": banker, "winner": winner}


## Total returned for a baccarat bet ("player", "banker", "tie").
static func bac_payout(bet_on: String, winner: String, bet: int) -> int:
	if winner == "tie":
		return bet * 9 if bet_on == "tie" else bet # player/banker bets push on a tie
	if bet_on != winner:
		return 0
	return bet * 2 if winner == "player" else bet + int(floor(bet * 0.95))


# ------------------------------------------------------------------ roulette

static func roulette_wins(bet_id: String, n: int) -> bool:
	if n == 0:
		return false
	match bet_id:
		"red":
			return RED_NUMBERS.has(n)
		"black":
			return not RED_NUMBERS.has(n)
		"odd":
			return n % 2 == 1
		"even":
			return n % 2 == 0
		"low":
			return n <= 18
		"high":
			return n >= 19
		"dozen1":
			return n <= 12
		"seven":
			return n == 7
	return false


## Total returned for a roulette bet on number n (single-zero wheel).
static func roulette_payout(bet_index: int, n: int, bet: int) -> int:
	var b: Array = ROULETTE_BETS[bet_index]
	return bet * (int(b[2]) + 1) if roulette_wins(String(b[0]), n) else 0
