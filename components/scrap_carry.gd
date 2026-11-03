class_name ScrapCarry
extends RefCounted
## Perk: Scrap Scavenger: a scrap multiplier on small kills. Rounding each kill on its
## own loses the bonus (1 scrap x1.25 rounds back to 1), so the fraction is carried
## over to the next kill on the same cliff: over many kills you get exactly scrap x mult.

## cliff id -> fractional scrap still owed.
var _carry: Dictionary = {}


## Whole scrap for this kill on `cliff`, keeping the leftover fraction for later.
func scale(cliff: int, scrap: int, mult: float) -> int:
	if is_equal_approx(mult, 1.0):
		return scrap
	var total := float(scrap) * mult + float(_carry.get(cliff, 0.0))
	var whole := maxi(floori(total + 0.0001), 0)
	_carry[cliff] = maxf(total - float(whole), 0.0)
	return whole
