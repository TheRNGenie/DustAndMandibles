class_name TutorialPlan
extends RefCounted
## The tutorial's scripted first wave as pure data (TutorialRun uses it through
## WaveDirector): six slow Dust Mites on your partner's wall in two small pulses.

## A Dust Mite at 60% speed with the same look and name (Defs.bug "@slow").
const SLOW_MITE := &"dust_mite@slow"


## The plan WaveDirector runs for the tutorial's first wave; `partner` is the
## cliff the mites climb (the one your turrets cover).
static func wave(partner: int) -> Dictionary:
	var shares: Array = []
	for cid in 2:
		shares.append(1.0 if cid == partner else 0.0)
	return {"groups": [
				{"bug": SLOW_MITE, "count": 3, "cliff": partner, "lane": 2, "pulse": 0},
				{"bug": SLOW_MITE, "count": 3, "cliff": partner, "lane": 1, "pulse": 1}],
			"pulses": 2, "pulse_times": [0.0, 9.0], "shape": WavePlanner.STEADY,
			"west_share": shares[0], "shares": shares, "spent": 6}
