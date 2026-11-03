class_name PartnerTonic
extends RefCounted
## Sarsaparilla tonic: a crop you grow for your PARTNER. Hold a sarsaparilla
## root and left click to send them a tonic: the turrets on their cliff (the
## ones guarding YOUR wall) fire 15% faster for 60 s of wave time. Tonics stack
## up to 3 minutes; the clock only runs while a wave is on, so one sent between
## waves is never wasted. Pure rules here (unit-tested); Economy keeps the
## per-cliff timers and syncs them.

const ITEM := &"sarsaparilla"
## Seconds of wave time one tonic adds.
const DURATION := 60.0
## Longest a stack of tonics can run.
const MAX_TIME := 180.0
## Turrets under a tonic fire this much faster (0.15 = 15% more shots).
const FIRE_RATE_BONUS := 0.15


## Time left after one more tonic lands on a cliff with `left` seconds to go.
static func add(left: float) -> float:
	return minf(maxf(left, 0.0) + DURATION, MAX_TIME)


## A turret's shot interval multiplier for a cliff with `left` seconds of tonic.
static func interval_mult(left: float) -> float:
	return 1.0 / (1.0 + FIRE_RATE_BONUS) if left > 0.0 else 1.0


## Time left after `delta` seconds; only wave time counts.
static func tick(left: float, delta: float, in_wave: bool) -> float:
	return maxf(left - delta, 0.0) if in_wave else left


## Whose turrets a tonic from `cliff_id` helps: your partner, the cliff your
## own turrets cover (across the canyon; the butte opposite on Pinwheel Buttes).
static func partner_of(cliff_id: int) -> int:
	return WorldLayout.other_cliff(cliff_id)
