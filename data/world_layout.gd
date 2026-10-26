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


## -1 for the west cliff, +1 for the east cliff.
static func side_sign(cliff_id: int) -> float:
	return -1.0 if cliff_id == WEST else 1.0


## Converts plateau coordinates (d = metres back from the lip, z = along the canyon)
## to a world position at height y.
static func plateau_to_world(cliff_id: int, d: float, z: float, y: float) -> Vector3:
	return Vector3(side_sign(cliff_id) * (HALF_GAP + d), y, z)


## Y rotation that makes a node's forward (-Z) face the canyon from this cliff.
static func facing_canyon_yaw(cliff_id: int) -> float:
	return side_sign(cliff_id) * PI * 0.5


## The other player's cliff.
static func other_cliff(cliff_id: int) -> int:
	return EAST if cliff_id == WEST else WEST
