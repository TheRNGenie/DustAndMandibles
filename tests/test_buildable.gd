extends TestCase
## Build grid zones and placement rules (Buildable), plus build menu list consistency.


func test_off_grid_is_off() -> void:
	assert_eq(Buildable.zone(Vector2i(-1, 0)), Buildable.Zone.OFF)
	assert_eq(Buildable.zone(Vector2i(0, -1)), Buildable.Zone.OFF)
	assert_eq(Buildable.zone(Vector2i(Buildable.ROWS, 0)), Buildable.Zone.OFF)
	assert_eq(Buildable.zone(Vector2i(0, Buildable.COLS)), Buildable.Zone.OFF)


func test_grid_matches_plateau_width() -> void:
	assert_eq(Buildable.COLS * int(WorldLayout.CELL), int(WorldLayout.PLATEAU_WIDTH))


func test_front_rows() -> void:
	# A front cell away from the house, the paths and the landmarks.
	assert_eq(Buildable.zone(Vector2i(0, 5)), Buildable.Zone.TURRET)
	assert_eq(Buildable.zone(Vector2i(1, 5)), Buildable.Zone.TACTICAL)
	assert_eq(Buildable.zone(Vector2i(3, 5)), Buildable.Zone.PLOT)


func test_house_is_blocked() -> void:
	var h := Buildable.house_cells()
	assert_true(h.size.x > 0 and h.size.y > 0, "house rect not empty")
	for r in range(h.position.x, h.end.x):
		for c in range(h.position.y, h.end.y):
			var cell := Vector2i(r, c)
			if Buildable.zone(cell) != Buildable.Zone.OFF:
				assert_eq(Buildable.zone(cell), Buildable.Zone.HOUSE, str(cell))
				assert_false(Buildable.cell_ok_for(&"gatling_post", cell), "built in the house at %s" % str(cell))


func test_door_cell_is_path_in_front_of_house() -> void:
	var d := Buildable.door_cell()
	assert_eq(Buildable.zone(d), Buildable.Zone.PATH)
	assert_eq(d.x, Buildable.house_cells().position.x - 1)


func test_landmarks_blocked() -> void:
	for p: Vector2 in [Buildable.WINDMILL, Buildable.WATER_TOWER, Buildable.SALVAGE]:
		var cell := Buildable.cell_of(p.x, p.y)
		if Buildable.zone(cell) == Buildable.Zone.OFF:
			continue
		assert_false(Buildable.zone_ok(&"gatling_post", cell), "landmark at %s buildable" % str(p))
	for r: int in Buildable.FIELD_ROWS:
		for c: int in Buildable.FIELD_COLS:
			assert_eq(Buildable.zone(Vector2i(r, c)), Buildable.Zone.LANDMARK, "field %d,%d" % [r, c])


func test_farm_plot_footprint_needs_all_four_cells() -> void:
	assert_eq(Buildable.footprint(&"farm_plot", Vector2i(3, 3)).size(), 4)
	assert_eq(Buildable.footprint(&"gatling_post", Vector2i(3, 3)).size(), 1)
	assert_true(Buildable.cell_ok_for(&"farm_plot", Vector2i(3, 3)))
	# On the last row or column part of the plot hangs off the grid.
	assert_false(Buildable.cell_ok_for(&"farm_plot", Vector2i(Buildable.ROWS - 1, 3)))
	assert_false(Buildable.cell_ok_for(&"farm_plot", Vector2i(3, Buildable.COLS - 1)))


func test_house_turret_cells() -> void:
	var house_id := &""
	for id: StringName in Defs.TURRETS.keys():
		if Defs.is_house_turret(id):
			house_id = id
	assert_true(house_id != &"", "a house turret exists")
	assert_true(Buildable.cell_ok_for(house_id, Vector2i(-1, 0)))
	assert_true(Buildable.cell_ok_for(house_id, Vector2i(-1, HouseBuilder.MOUNTS.size() - 1)))
	assert_false(Buildable.cell_ok_for(house_id, Vector2i(-1, HouseBuilder.MOUNTS.size())))
	assert_false(Buildable.cell_ok_for(house_id, Vector2i(0, 5)), "house turret on the grid")
	assert_false(Buildable.cell_ok_for(&"gatling_post", Vector2i(-1, 0)), "grid turret on a house mount")


func test_cell_of_round_trips_cell_centres() -> void:
	for r in Buildable.ROWS:
		for c in Buildable.COLS:
			var d := Buildable.LIP_MARGIN + (float(r) + 0.5) * WorldLayout.CELL
			var z := -WorldLayout.PLATEAU_WIDTH * 0.5 + (float(c) + 0.5) * WorldLayout.CELL
			assert_eq(Buildable.cell_of(d, z), Vector2i(r, c))


func test_cliff_at() -> void:
	assert_eq(Buildable.cliff_at(Vector3(-40, 0, 0)), WorldLayout.WEST)
	assert_eq(Buildable.cliff_at(Vector3(40, 0, 0)), WorldLayout.EAST)
	assert_eq(Buildable.cliff_at(Vector3(0, 0, 0)), -1)


func test_tactical_ids_are_structures() -> void:
	for id: StringName in Buildable.TACTICAL:
		assert_true(Defs.STRUCTURES.has(id), "%s" % id)


func test_build_menu_lists_agree() -> void:
	var in_cats: Array = []
	for cat: Dictionary in Defs.BUILD_CATEGORIES:
		for id: StringName in cat["items"]:
			assert_false(in_cats.has(id), "%s listed twice" % id)
			in_cats.append(id)
	for id: StringName in Defs.BUILD_ORDER:
		assert_true(in_cats.has(id), "%s in BUILD_ORDER but no category" % id)
		assert_true(Defs.TURRETS.has(id) or Defs.STRUCTURES.has(id), "%s has no def" % id)
	for id: StringName in in_cats:
		assert_true(Defs.BUILD_ORDER.has(id), "%s in a category but not BUILD_ORDER" % id)
