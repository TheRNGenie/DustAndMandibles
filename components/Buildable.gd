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
## lip walkway), and LANDMARK spots (the well, generator, water tower, starter field).

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
const WATER_TOWER := Vector2(28.0, -17.0)
## Waterworks: the well (a pump jack, MechWell, its beam pointing at the
## generator that drives it: trough toward the lip, crank end toward the engine)
## and the generator, on the same side of the yard as the water tower.
const WELL := Vector2(20.4, -12.0)
const GENERATOR := Vector2(24.2, -12.2)
## Where the waterworks face (their lever, tap and well open toward the yard).
const WATERWORKS_FACE := Vector2(21.0, -3.0)
## The big scrap heap beside the house (east of it, past the end of the field).
const SALVAGE := Vector2(25.0, 11.0)
## The campfire in front of the house, beside the path to the bridge (3 x 3 cells kept clear).
const CAMPFIRE := Vector2(14.0, -9.0)
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
	# The well: 2 cells wide, from the trough (row 8) to the crank (row 10).
	var wl := cell_of(WELL.x, WELL.y)
	if Rect2i(wl - Vector2i(1, 1), Vector2i(3, 2)).has_point(cell):
		return true
	var wt := cell_of(WATER_TOWER.x, WATER_TOWER.y)
	if Rect2i(wt - Vector2i(1, 1), Vector2i(3, 3)).has_point(cell):
		return true
	var gen := cell_of(GENERATOR.x, GENERATOR.y)
	if Rect2i(gen - Vector2i(1, 1), Vector2i(3, 3)).has_point(cell):
		return true
	var cf := cell_of(CAMPFIRE.x, CAMPFIRE.y)
	if Rect2i(cf - Vector2i(1, 1), Vector2i(3, 3)).has_point(cell):
		return true
	var sp := cell_of(SALVAGE.x, SALVAGE.y)
	if Rect2i(sp - Vector2i(2, 2), Vector2i(5, 5)).has_point(cell):
		return true
	for r: int in FIELD_ROWS:
		for c: int in FIELD_COLS:
			if Rect2i(Vector2i(r, c), Vector2i(2, 2)).has_point(cell):
				return true
	return false


## Cells an item covers when built at `cell` (farm plots take 2 x 2).
static func footprint(id: StringName, cell: Vector2i) -> Array[Vector2i]:
	if id == &"farm_plot" or Defs.is_crewed(id): # Crewed: crewed guns are 2 x 2 too
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
## Anything can go on any open grid cell (Logan's call): only the house, the
## landmarks (well, generator, water tower, scrap heap, starter fields) and off-grid are out.
static func zone_ok(_id: StringName, cell: Vector2i) -> bool:
	var z := zone(cell)
	return z == Zone.TURRET or z == Zone.TACTICAL or z == Zone.PLOT or z == Zone.PATH


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


## Turrets stack on scaffolds anywhere on the grid now.
static func is_turret_cell(cell: Vector2i) -> bool:
	return zone_ok(&"", cell)


static func is_structure_cell(cell: Vector2i) -> bool:
	return zone_ok(&"", cell)


## Which cliff a world position is on (behind which lip), or -1 over the gap.
static func cliff_at(pos: Vector3) -> int:
	return WorldLayout.map().cliff_at(pos)
