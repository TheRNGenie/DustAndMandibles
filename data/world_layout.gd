class_name WorldLayout
extends RefCounted
## Fixed world dimensions from the design doc ("World layout"). All values in metres.
## cliff_id 0 = west plateau (x < 0), 1 = east plateau (x > 0). The canyon runs along Z.

const WEST := 0
const EAST := 1

const GAP := 45.0
const HALF_GAP := 22.5
## Logan asked for a much deeper canyon than the doc's 28 m (see DECISIONS.md).
const CLIFF_HEIGHT := 60.0
const PLATEAU_WIDTH := 40.0 # along Z
const PLATEAU_DEPTH := 30.0 # away from the lip
const CELL := 2.0
const LANE_Z: Array[float] = [-16.0, -8.0, 0.0, 8.0, 16.0]
## Bug tunnels: down the canyon past both ends of the play area, in the foot of
## either wall ([cliff the tunnel is in, z]). Bugs crawl out and walk up the
## canyon floor into the play area before they climb.
const TUNNELS: Array = [[0, -62.0], [1, -68.0], [0, -76.0], [1, -58.0], [0, 60.0], [1, 66.0], [0, 74.0], [1, 56.0]]
const LEDGE_Y: Array[float] = [10.0, 20.0, 30.0, 40.0, 50.0]

## Terrain extent (bigger than the playable area so the canyon reads as a landscape).
const WORLD_HALF_Z := 90.0
const TERRAIN_DEPTH := 60.0

## Overhang of the lip (the face below sits this far back). Hides your own face from your turrets.
const OVERHANG := 2.2
const LIP_BAND_BOTTOM := CLIFF_HEIGHT - 1.4
const UNDERSIDE_BOTTOM := CLIFF_HEIGHT - 2.6
## Below this height the face gets rough noise and lane carving.
const ROUGH_TOP := CLIFF_HEIGHT - 3.5

## Physics layers (bit values).
const LAYER_WORLD := 1
const LAYER_PLAYER_BLOCKER := 2
const LAYER_BUG := 4
const LAYER_STRUCTURE := 8
## Traps players can walk over (wire, bear traps, dynamite crates).
const LAYER_TRAP := 16
## What player bullets hit.
const MASK_SHOTS := LAYER_WORLD | LAYER_BUG | LAYER_STRUCTURE | LAYER_TRAP

## Players who fall below this height are in the canyon and get hauled home.
const CANYON_FALL_Y := CLIFF_HEIGHT - 6.0


## -1 for the west cliff, +1 for the east cliff (canyon only: other maps use
## MapDef frames, see inward()).
static func side_sign(cliff_id: int) -> float:
	return -1.0 if cliff_id == WEST else 1.0


## The map this run plays on.
static func map() -> MapDef:
	return MapDef.get_current()


## How many cliffs (players' plateaus) the map has.
static func cliff_count() -> int:
	return MapDef.get_current().count()


## Horizontal direction from a cliff's lip out over the gap (into the canyon).
static func inward(cliff_id: int) -> Vector3:
	return MapDef.get_current().cliff(cliff_id).inward


## Converts plateau coordinates (d = metres back from the lip, z = along the lip)
## to a world position at height y.
static func plateau_to_world(cliff_id: int, d: float, z: float, y: float) -> Vector3:
	var m := MapDef.get_current()
	if m.is_canyon():
		return Vector3(side_sign(cliff_id) * (HALF_GAP + d), y, z)
	return m.to_world(cliff_id, m.prow_u(cliff_id, z) - d, z) + Vector3(0, y, 0)


## Y rotation that makes a node's forward (-Z) face the gap from this cliff.
static func facing_canyon_yaw(cliff_id: int) -> float:
	return MapDef.get_current().facing_yaw(cliff_id)


## The cliff this one's turrets mostly cover (on the canyon: the other player's cliff).
static func other_cliff(cliff_id: int) -> int:
	return MapDef.get_current().main_target(cliff_id)
