class_name Buildable
extends RefCounted
## The build grid: 2 m cells on each plateau. Turrets go on the "turret line",
## the first rows back from the lip. Cell = Vector2i(row, col): row counts back
## from the lip, col runs along the canyon from -Z to +Z.

const TURRET_ROWS := 3
const COLS := 20 # 40 m plateau width / 2 m cells
const LIP_MARGIN := 1.0 # metres between the lip and row 0


static func cell_center(cliffs: CliffBuilder, cliff_id: int, cell: Vector2i) -> Vector3:
	var d := LIP_MARGIN + (float(cell.x) + 0.5) * WorldLayout.CELL
	var z := -WorldLayout.PLATEAU_WIDTH * 0.5 + (float(cell.y) + 0.5) * WorldLayout.CELL
	return cliffs.plateau_point(cliff_id, d, z)


## Cell under a world position, or Vector2i(-1, -1) if it's off the grid.
static func world_to_cell(cliffs: CliffBuilder, cliff_id: int, pos: Vector3) -> Vector2i:
	var pc := cliffs.plateau_coords(cliff_id, pos)
	var row := int(floor((pc.x - LIP_MARGIN) / WorldLayout.CELL))
	var col := int(floor((pc.y + WorldLayout.PLATEAU_WIDTH * 0.5) / WorldLayout.CELL))
	if row < 0 or col < 0 or col >= COLS or row >= int(WorldLayout.PLATEAU_DEPTH / WorldLayout.CELL):
		return Vector2i(-1, -1)
	return Vector2i(row, col)


## Traps and structures go behind the turret line, inside the playable plateau.
static func is_structure_cell(cell: Vector2i) -> bool:
	var rows := int(WorldLayout.PLATEAU_DEPTH / WorldLayout.CELL) - 1
	return cell.x >= TURRET_ROWS and cell.x < rows and cell.y >= 0 and cell.y < COLS


static func cell_ok_for(id: StringName, cell: Vector2i) -> bool:
	if Defs.is_turret(id) and Defs.turret(id).guards_plateau:
		return is_turret_cell(cell) or is_structure_cell(cell)
	return is_turret_cell(cell) if Defs.is_turret(id) else is_structure_cell(cell)


static func is_turret_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < TURRET_ROWS and cell.y >= 0 and cell.y < COLS


## Which cliff a world position is on (by side of the canyon), or -1 over the gap.
static func cliff_at(pos: Vector3) -> int:
	if pos.x < -WorldLayout.HALF_GAP + 0.5:
		return WorldLayout.WEST
	if pos.x > WorldLayout.HALF_GAP - 0.5:
		return WorldLayout.EAST
	return -1
