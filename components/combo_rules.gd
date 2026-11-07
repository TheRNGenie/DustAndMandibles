class_name ComboRules
extends RefCounted
## The style combo (movement plan #8): chain grapples, slides and mid-air kills
## without standing still. The count shows as a letter grade, C to S+; a higher
## count multiplies the team-pot pay of your own kills and the grapple
## slingshot's hit. Standing still too long or taking a hit breaks it. Pure
## rules (unit tested); StyleCombo tracks it on the player, HudCombo shows it.

const CAP := 30
## Combo per qualifying action (Logan: a half, so the grades take 2x the moves).
const PER_ACTION := 1.0 / 2.0
## Team-pot pay per combo point (+5%, so the cap is x2.5).
const PER := 0.05
const STILL_SECS := 2.0
## The grace shrinks 0.1 s every 5 waves, down to 1 s (late combos need tighter play).
const STILL_MIN := 1.0
const SLING_MIN := 80.0
const SLING_MAX := 200.0
## Grade bands: [lowest count, letter].
const GRADES: Array = [[30, "S+"], [20, "S"], [10, "A"], [5, "B"], [1, "C"]]
## Reach S in a wave and the combo stays at least this high until the wave ends.
const S_FLOOR := 20


## Hot Streak (movement plan #10): end a wave having reached this combo and
## the airship's shops take this much off your next purchase.
const STREAK: Array = [[25, 0.15], [15, 0.10]]


static func streak_cut(peak: int) -> float:
	for s: Array in STREAK:
		if peak >= int(s[0]):
			return float(s[1])
	return 0.0


## A price with a Hot Streak cut taken off (rounded up, never below 1).
static func cut_price(cost: int, cut: float) -> int:
	return cost if cut <= 0.0 or cost <= 0 else maxi(ceili(cost * (1.0 - cut)), 1)


static func grade(count: int) -> String:
	for g: Array in GRADES:
		if count >= int(g[0]):
			return str(g[1])
	return ""


## 0 (none) to 5 (S+), for comparing grades.
static func rank(count: int) -> int:
	var g := grade(count)
	return ["", "C", "B", "A", "S", "S+"].find(g)


static func mult(count: int) -> float:
	return 1.0 + clampi(count, 0, CAP) * PER


static func still_secs(wave: int) -> float:
	return maxf(STILL_SECS - 0.1 * floorf(maxi(wave, 0) / 5.0), STILL_MIN)


static func sling_damage(count: int) -> float:
	return lerpf(SLING_MIN, SLING_MAX, clampf(float(count) / CAP, 0.0, 1.0))


## Brand-themed colour per rank (1 C .. 5 S+), from the movement plan.
const RAMPS: Dictionary = {
	&"sheaf": ["#C9A86A", "#E2B84A", "#E8901A", "#E86A1A", "#B4552E"],
	&"irons": ["#9AA0A6", "#5E6A72", "#C9A24A", "#F07A2A", "#FFF4E0"],
	&"snake": ["#2E7D4F", "#E2B84A", "#B3261E", "#9B4DFF", "#FFD54A"],
	&"mandibles": ["#2E8C7E", "#9BE564", "#E8A13A", "#C8302C", "#F2C230"],
	&"none": ["#3E8E8A", "#9BD13A", "#E8A13A", "#C8302C", "#F2C230"],
}


static func color(brand: StringName, count: int) -> Color:
	var r := rank(count)
	var ramp: Array = RAMPS.get(brand, RAMPS[&"none"])
	return Color(str(ramp[clampi(r - 1, 0, 4)]))
