class_name GrappleRules
extends RefCounted
## The grapple's rules that are worth unit-testing on their own (no nodes, no
## input): when a swing lets go (hold or toggle, Settings.grapple_swing_toggle),
## and with another weapon out on Free Hands.


## Does the swing let go this tick? Jump always does. With the launcher out:
## letting go of right click (hold), or clicking it again (toggle), but never
## the click that hooked on (`fresh_hook`). With another weapon out (the Free
## Hands secret) only jump does.
static func swing_lets_go(holding: bool, toggle: bool, alt_down: bool, alt_clicked: bool, jumped: bool, fresh_hook: bool) -> bool:
	if jumped:
		return true
	if not holding:
		return false
	if toggle:
		return alt_clicked and not fresh_hook
	return not alt_down
