class_name CasinoRules
extends RefCounted
## Pure rules for the airship's games (blackjack, baccarat, roulette, slots, prize wheel), kept
## free of nodes so they can be unit tested. Cards are ints 1-13 (ace = 1).

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := ["s", "h", "d", "c"]
const RED_NUMBERS: Array[int] = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
## Roulette bets: id, label, payout (to 1).
const ROULETTE_BETS: Array[Array] = [["red", "Red", 1], ["black", "Black", 1], ["odd", "Odd", 1], ["even", "Even", 1],
	["low", "1-18", 1], ["high", "19-36", 1], ["dozen1", "1st dozen", 2], ["seven", "Lucky 7", 35]]
## Slot machine: Symbol, weight, payout multiplier for three of a kind, multiplier for a pair.
const SLOT_SYMBOLS: Array[Array] = [["BUG", 30, 0, 0], ["CACTUS", 25, 10, 1], ["CHILI", 20, 15, 1], ["HORSESHOE", 15, 25, 2], ["STAR", 10, 60, 2]]
## Extra prizes on top of the scrap for three of a kind.
const SLOT_BONUS: Dictionary = {"CHILI": {&"seed_chili": 3}, "STAR": {&"upgrade_token": 1}}
## Prize wheel wedges: label, prize.
const WHEEL_WEDGES: Array[Array] = [
	["BUST", {}], ["50 SCRAP", {&"scrap": 50}], ["UPGRADE TOKEN", {&"upgrade_token": 1}], ["BUST", {}],
	["120 SCRAP", {&"scrap": 120}], ["3 CHILI SEEDS", {&"seed_chili": 3}], ["BUST", {}], ["JACKPOT 25 CHITIN", {&"chitin": 25}],
	["30 SCRAP", {&"scrap": 30}], ["4 HERBS", {&"herbs": 4}], ["TURRET PART", {&"turret_part": 1}],
]
## A wheel prize that stands for one random crafting part (CraftTable.random_part).
const WHEEL_PART := &"turret_part"
## Chance that a winning hand, spin or pull also pays out a random turret part.
const PART_CHANCE := 0.05


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


## Slot machine: scrap payout multiplier for three reels.
static func slot_payout(reels: Array) -> int:
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return int(SLOT_SYMBOLS[reels[0]][2])
	for i in 3:
		if reels[i] == reels[(i + 1) % 3]:
			return int(SLOT_SYMBOLS[reels[i]][3])
	return 0


## Slot machine: everything three reels win at a stake: scrap plus any bonus prize.
static func slot_prize(reels: Array, bet: int) -> Dictionary:
	var out: Dictionary = {}
	var win := bet * slot_payout(reels)
	if win > 0:
		out[&"scrap"] = win
	if reels[0] == reels[1] and reels[1] == reels[2]:
		var extra: Dictionary = SLOT_BONUS.get(String(SLOT_SYMBOLS[reels[0]][0]), {})
		out.merge(extra)
	return out


## Slot machine: exact share of stakes paid back in scrap (for tests and tuning).
static func slot_return_rate() -> float:
	var total := 0.0
	for s: Array in SLOT_SYMBOLS:
		total += float(s[1])
	var rate := 0.0
	for a in SLOT_SYMBOLS.size():
		for b in SLOT_SYMBOLS.size():
			for c in SLOT_SYMBOLS.size():
				var p := float(SLOT_SYMBOLS[a][1]) * float(SLOT_SYMBOLS[b][1]) * float(SLOT_SYMBOLS[c][1]) / pow(total, 3)
				rate += p * slot_payout([a, b, c])
	return rate


## A winner's bonus: a random turret part key now and then (PART_CHANCE), else &"".
static func part_bonus(rng: RandomNumberGenerator) -> StringName:
	if rng.randf() >= PART_CHANCE:
		return &""
	return CraftTable.random_part(rng)


## "120 scrap + 1 upgrade token" for result lines.
static func prize_text(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: Variant in amounts.keys():
		var n := int(amounts[k])
		if CraftTable.is_part(StringName(k)):
			parts.append(("a %s" % CraftTable.part_name(StringName(k))) if n == 1 else ("%d x %s" % [n, CraftTable.part_name(StringName(k))]))
			continue
		var label := String(k).replace("seed_", "").replace("_", " ")
		if String(k).begins_with("seed_"):
			label += " seed" if n == 1 else " seeds"
		elif String(k) == "upgrade_token" and n > 1:
			label += "s"
		parts.append("%d %s" % [n, label])
	return " + ".join(parts)


# ------------------------------------------------------------------ shell game

## Three cups, one pea. A correct pick returns this many times the stake
## (1 in 3 chance, so about 95% back over time).
const SHELL_RETURN := 2.85
const SHELL_CUPS := 3


## Where the pea is: a fair, uniform pick of the three cups.
static func shell_pea(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, SHELL_CUPS - 1)


## Total returned for picking `pick` when the pea is under `pea` (0 = lost).
static func shell_payout(pick: int, pea: int, bet: int) -> int:
	return floori(bet * SHELL_RETURN) if pick == pea else 0


## Exact share of stakes paid back by the shell game at a stake.
static func shell_return_rate(bet: int) -> float:
	var back := 0
	for pea in SHELL_CUPS:
		back += shell_payout(0, pea, bet)
	return float(back) / float(bet * SHELL_CUPS)


# ------------------------------------------------------------------ beetle racing

## The four beetles: name, chance to win. Each pays back about RACE_RETURN of
## the stake on average, so long shots pay big and favourites pay little.
const RACE_BEETLES: Array[Array] = [["Dusty", 0.40], ["Ol' Sarge", 0.30], ["Pinchy", 0.20], ["Long Shot Lou", 0.10]]
const RACE_RETURN := 0.95


## Total returned per scrap staked on beetle i if it wins (decimal odds, e.g. 2.3).
static func race_multiplier(i: int) -> float:
	return snappedf(RACE_RETURN / float(RACE_BEETLES[i][1]), 0.1)


## Total returned for a bet on beetle `pick` when `winner` crossed first.
static func race_payout(pick: int, winner: int, bet: int) -> int:
	return floori(bet * race_multiplier(pick)) if pick == winner else 0


## Which beetle wins for a uniform roll in [0, 1).
static func race_winner(roll: float) -> int:
	var acc := 0.0
	for i in RACE_BEETLES.size():
		acc += float(RACE_BEETLES[i][1])
		if roll < acc:
			return i
	return RACE_BEETLES.size() - 1


## Exact share of stakes paid back betting on beetle i at a stake.
static func race_return_rate(i: int, bet: int) -> float:
	var back := 0.0
	for w in RACE_BEETLES.size():
		back += float(RACE_BEETLES[w][1]) * race_payout(i, w, bet)
	return back / float(bet)


## Seconds after the start each beetle crosses the line: the winner at `length`,
## the rest strung out behind (deterministic from `seed_value`, so every peer
## animates the same race).
static func race_finish_times(winner: int, length: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	for i in RACE_BEETLES.size():
		out.append(length if i == winner else length + rng.randf_range(0.25, 1.4))
	return out


## How far along the track (0..1) beetle i is at time t: a lurching run with
## spurts and stalls that still arrives exactly at its finish time.
static func race_progress(i: int, t: float, finish: float, seed_value: int) -> float:
	if t <= 0.0:
		return 0.0
	if t >= finish:
		return 1.0
	var u := t / finish
	var wob := sin(u * PI * (2.0 + float((seed_value + i * 7) % 3))) * 0.06 * sin(u * PI)
	return clampf(u + wob, 0.0, 1.0)
