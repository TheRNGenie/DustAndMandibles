class_name Buildable
extends RefCounted
## The build grid: 2 m cells on each plateau. Cell = Vector2i(row, col): row
## counts back from the lip, col runs along the canyon from -Z to +Z.
##
## Zones, front to back:
##   row 0       TURRET    the cliff edge: cliff turrets and scaffolding
##   row 1       TACTICAL  traps, wire, palisades, lanterns
##   rows 2..13  PLOT      anything that isn't a cliff turret (farm plots are 2x2)
## Kept clear: the house and a 1-cell PATH around it, a 1-cell path from the front
## door to the bridge (along the door's row, then down the south edge to the
## lip walkway), and LANDMARK spots (windmill and well, water tower, starter field).

enum Zone { OFF, TURRET, TACTICAL, PLOT, HOUSE, PATH, LANDMARK }

const TURRET_ROWS := 1
const ROWS := 14
const COLS := 20 # 40 m plateau width / 2 m cells
const LIP_MARGIN := 1.0 # metres between the lip and row 0

## Plateau coordinates (d back from the lip, z along the canyon) of fixed things.
const HOUSE_D := 23.0
const HOUSE_Z := 1.0 # the door sits on a cell centre (col 10)
const HOUSE_HALF_W := 4.7 # along z, including the flagpole
const HOUSE_FRONT := 5.2 # porch front, metres in front of the house centre
const HOUSE_BACK := 3.0
const WINDMILL := Vector2(20.0, -13.0)
const WATER_TOWER := Vector2(28.0, -17.0)
const SALVAGE := Vector2(27.7, 1.0)
## Starter farm field: 3 x 4 farm plots (2 x 2 cells each) beside the house.
const FIELD_COLS := [14, 16, 18]
const FIELD_ROWS := [8, 6, 4, 2]

const TACTICAL: Array[StringName] = [&"barbed_wire", &"bear_trap", &"dynamite_crate", &"palisade", &"lantern_post"]


static func cell_center(cliffs: CliffBuilder, cliff_id: int, cell: Vector2i) -> Vector3:
	var d := LIP_MARGIN + (float(cell.x) + 0.5) * WorldLayout.CELL
	var z := -WorldLayout.PLATEAU_WIDTH * 0.5 + (float(cell.y) + 0.5) * WorldLayout.CELL
	return cliffs.plateau_point(cliff_id, d, z)


## Cell under a world position, or Vector2i(-1, -1) if it's off the grid.
static func world_to_cell(cliffs: CliffBuilder, cliff_id: int, pos: Vector3) -> Vector2i:
	var pc := cliffs.plateau_coords(cliff_id, pos)
	var row := int(floor((pc.x - LIP_MARGIN) / WorldLayout.CELL))
	var col := int(floor((pc.y + WorldLayout.PLATEAU_WIDTH * 0.5) / WorldLayout.CELL))
	if row < 0 or col < 0 or col >= COLS or row >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(row, col)


static func cell_of(d: float, z: float) -> Vector2i:
	return Vector2i(int(floor((d - LIP_MARGIN) / WorldLayout.CELL)), int(floor((z + WorldLayout.PLATEAU_WIDTH * 0.5) / WorldLayout.CELL)))


static func house_cells() -> Rect2i:
	var a := cell_of(HOUSE_D - HOUSE_FRONT, HOUSE_Z - HOUSE_HALF_W)
	var b := cell_of(HOUSE_D + HOUSE_BACK, HOUSE_Z + HOUSE_HALF_W)
	return Rect2i(a, b - a + Vector2i.ONE)


static func door_cell() -> Vector2i:
	var h := house_cells()
	return Vector2i(h.position.x - 1, cell_of(HOUSE_D, HOUSE_Z).y)


static func zone(cell: Vector2i) -> Zone:
	if cell.x < 0 or cell.y < 0 or cell.x >= ROWS or cell.y >= COLS:
		return Zone.OFF
	var h := house_cells()
	if h.has_point(cell):
		return Zone.HOUSE
	if h.grow(1).has_point(cell):
		return Zone.PATH
	var door := door_cell()
	if cell.x == door.x and cell.y <= door.y:
		return Zone.PATH # along the door's row toward the bridge side
	if cell.y == 0 and cell.x <= door.x:
		return Zone.PATH # down the south edge to the lip walkway
	if _landmark(cell):
		return Zone.LANDMARK
	if cell.x < TURRET_ROWS:
		return Zone.TURRET
	if cell.x == TURRET_ROWS:
		return Zone.TACTICAL
	return Zone.PLOT


static func _landmark(cell: Vector2i) -> bool:
	var wm := cell_of(WINDMILL.x, WINDMILL.y)
	if Rect2i(wm - Vector2i(1, 1), Vector2i(3, 4)).has_point(cell):
		return true
	var wt := cell_of(WATER_TOWER.x, WATER_TOWER.y)
	if Rect2i(wt - Vector2i(1, 1), Vector2i(3, 3)).has_point(cell):
		return true
	for r: int in FIELD_ROWS:
		for c: int in FIELD_COLS:
			if Rect2i(Vector2i(r, c), Vector2i(2, 2)).has_point(cell):
				return true
	return false


## Cells an item covers when built at `cell` (farm plots take 2 x 2).
static func footprint(id: StringName, cell: Vector2i) -> Array[Vector2i]:
	if id == &"farm_plot":
		return [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]
	return [cell]


## Where an item built at `cell` stands (the middle of its footprint).
static func footprint_center(cliffs: CliffBuilder, cliff_id: int, id: StringName, cell: Vector2i) -> Vector3:
	var fp := footprint(id, cell)
	var sum := Vector3.ZERO
	for c in fp:
		sum += cell_center(cliffs, cliff_id, c)
	return sum / float(fp.size())


## Is this one cell the right kind of ground for the item?
static func zone_ok(id: StringName, cell: Vector2i) -> bool:
	var z := zone(cell)
	if id == &"scaffold" or (Defs.is_turret(id) and not Defs.turret(id).guards_plateau):
		return z == Zone.TURRET
	if TACTICAL.has(id):
		return z == Zone.TACTICAL or z == Zone.PLOT
	return z == Zone.PLOT


## House turrets use cell (-1, mount index) instead of a grid cell.
static func cell_ok_for(id: StringName, cell: Vector2i) -> bool:
	if Defs.is_house_turret(id):
		return cell.x == -1 and cell.y >= 0 and cell.y < HouseBuilder.MOUNTS.size()
	if cell.x < 0:
		return false
	for c in footprint(id, cell):
		if not zone_ok(id, c):
			return false
	return true


static func is_turret_cell(cell: Vector2i) -> bool:
	return zone(cell) == Zone.TURRET


static func is_structure_cell(cell: Vector2i) -> bool:
	var z := zone(cell)
	return z == Zone.TACTICAL or z == Zone.PLOT


## Which cliff a world position is on (by side of the canyon), or -1 over the gap.
static func cliff_at(pos: Vector3) -> int:
	if pos.x < -WorldLayout.HALF_GAP + 0.5:
		return WorldLayout.WEST
	if pos.x > WorldLayout.HALF_GAP - 0.5:
		return WorldLayout.EAST
	return -1
