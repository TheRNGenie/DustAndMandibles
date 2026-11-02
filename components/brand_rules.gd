class_name BrandRules
extends RefCounted
## How many Brands a run pays (pure, unit-tested). Every rancher who rode out
## gets a little; each wave held pays, waves past the last one (endless) pay
## more, each time your turrets saved your partner pays (up to a cap, so a long
## run can't be farmed on saves alone), and holding the canyon pays a bonus.

const RODE_OUT := 5
const PER_WAVE := 3
const PER_ENDLESS_WAVE := 4
const PER_SAVE := 2
const MAX_SAVES := 20
const WIN_BONUS := 25


## `waves_held`: waves fully cleared this run (endless ones included);
## `last_wave`: the wave count that wins; `saves`: kills your turrets made on
## your partner's cliff; `has_partner`: a human or CPU on the other cliff.
## Returns {"total": int, "lines": [[label, detail, amount], ...]}.
static func earnings(waves_held: int, last_wave: int, saves: int, won: bool, has_partner: bool) -> Dictionary:
	var lines: Array = []
	lines.append(["Rode out", "", RODE_OUT])
	var normal := clampi(waves_held, 0, last_wave)
	var extra := maxi(waves_held - last_wave, 0)
	if normal > 0:
		lines.append(["Waves held", "%d x %d" % [normal, PER_WAVE], normal * PER_WAVE])
	if extra > 0:
		lines.append(["Endless waves", "%d x %d" % [extra, PER_ENDLESS_WAVE], extra * PER_ENDLESS_WAVE])
	if has_partner and saves > 0:
		var counted := mini(saves, MAX_SAVES)
		var detail := "%d x %d" % [counted, PER_SAVE]
		if saves > MAX_SAVES:
			detail += " (max %d)" % MAX_SAVES
		lines.append(["Saved your partner", detail, counted * PER_SAVE])
	if won:
		lines.append(["Held the canyon", "", WIN_BONUS])
	var total := 0
	for l: Array in lines:
		total += int(l[2])
	return {"total": total, "lines": lines}
