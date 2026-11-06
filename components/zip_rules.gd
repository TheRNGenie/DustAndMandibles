class_name ZipRules
extends RefCounted
## Deployable ziplines (movement plan #17): a Zipline Anchor made at the
## Workshop, fired (the Deploy Zipline key) into rock up to RANGE away; a rope
## runs from where you stood to the anchor for LIFE seconds. Anyone rides it
## either way (E near the rope), RIDE_MULT times a swing's speed. Each rider
## keeps MAX_PER_RIDER at once: a fourth snaps the oldest. Pure rules.

const ITEM := &"zip_anchor"
const RANGE := 40.0
const LIFE := 60.0
const MAX_PER_RIDER := 3
const RIDE_SPEED := 22.0 * 1.3
## Personal scrap and team chitin per anchor.
const COST_SCRAP := 15
const COST_CHITIN := 5


static func recipe(scrap_mult: float = 1.0) -> Dictionary:
	return {ResNames.PERSONAL_ID: roundi(COST_SCRAP * scrap_mult), ResNames.TEAM_ID: COST_CHITIN}


## Where along the rope (0 = a, 1 = b) a point sits, and how far off it is.
static func nearest(a: Vector3, b: Vector3, p: Vector3) -> Array:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return [t, p.distance_to(a + ab * t)]
