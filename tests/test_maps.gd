extends TestCase
## Maps: the canyon stays the two-cliff map it always was; Three-Cliff Mesa and
## Pinwheel Buttes split each lip between the cliffs it covers.


func test_canyon_is_the_default_and_unchanged() -> void:
	var m := MapDef.canyon()
	assert_eq(m.count(), 2)
	assert_eq(m.main_target(0), 1)
	assert_eq(m.main_target(1), 0)
	for col in Buildable.COLS:
		assert_eq(m.covered_cliff(0, col), 1)
		assert_eq(m.covered_cliff(1, col), 0)
	assert_almost(m.facing_yaw(0), -PI * 0.5)
	assert_almost(m.facing_yaw(1), PI * 0.5)
	assert_eq(m.cliff_at(Vector3(-40, 0, 0)), 0)
	assert_eq(m.cliff_at(Vector3(40, 0, 0)), 1)
	assert_eq(m.cliff_at(Vector3.ZERO), -1)
	assert_eq(m.name_of(0), "West Cliff")
	assert_eq(m.name_of(1), "East Cliff")


func test_mesa_splits_each_lip_between_both_neighbours() -> void:
	var m := MapDef.mesa()
	assert_eq(m.count(), 3)
	for cid in 3:
		var left := m.covered_cliff(cid, 0)
		var right := m.covered_cliff(cid, Buildable.COLS - 1)
		assert_true(left != cid and right != cid and left != right, "cliff %d covers both neighbours" % cid)
		assert_almost(m.cover_share(cid, left), 0.5)
		assert_almost(m.cover_share(cid, right), 0.5)
		# The left half covers the neighbour on the left (negative v).
		assert_true((m.cliff(left).origin - m.cliff(cid).origin).dot(m.cliff(cid).along) < 0.0)
	assert_eq(m.tunnels.size(), 6)


func test_buttes_centre_covers_the_opposite_butte() -> void:
	var m := MapDef.buttes()
	assert_eq(m.count(), 4)
	for cid in 4:
		var opposite := (cid + 2) % 4
		assert_almost(m.cover_share(cid, opposite), 0.6)
		assert_eq(m.covered_cliff(cid, Buildable.COLS / 2), opposite)
		var edges := [m.covered_cliff(cid, 0), m.covered_cliff(cid, Buildable.COLS - 1)]
		assert_true(not edges.has(cid) and not edges.has(opposite) and edges[0] != edges[1], "edges cover the two neighbours")
		assert_almost(m.cover_share(cid, edges[0]), 0.2)
		assert_eq(m.defenders_of(cid).size(), 3)
	assert_eq(m.name_of(0), "North Butte")


func test_frames_round_trip_and_face_the_middle() -> void:
	for m: MapDef in [MapDef.mesa(), MapDef.buttes()]:
		for cid in m.count():
			# A point behind the lip is on this cliff, and back again.
			var p := m.to_world(cid, m.prow_u(cid, 7.0) - 12.0, 7.0)
			var uv := m.local_uv(cid, p)
			assert_almost(uv.y, 7.0, 0.001)
			assert_almost(m.prow_u(cid, uv.y) - uv.x, 12.0, 0.001)
			assert_eq(m.cliff_at(p), cid, "%s cliff %d" % [m.id, cid])
			# Inward points at the middle; yaw turns -Z to inward.
			var to_mid := (m.center - m.cliff(cid).origin).normalized()
			assert_almost(to_mid.dot(m.cliff(cid).inward), 1.0, 0.0001)
			var fwd := Basis(Vector3.UP, m.facing_yaw(cid)) * Vector3.FORWARD
			assert_almost(fwd.dot(m.cliff(cid).inward), 1.0, 0.0001)
		assert_eq(m.cliff_at(m.center), -1)


func test_butte_lip_is_a_v() -> void:
	var m := MapDef.buttes()
	assert_almost(m.prow_u(0, 0.0), 0.0)
	assert_almost(m.prow_u(0, 12.0), 0.0)
	assert_true(m.prow_u(0, 20.0) < -5.0, "edge faces fall back")
	assert_almost(m.prow_u(0, -20.0), m.prow_u(0, 20.0))


func test_planner_spends_on_every_cliff() -> void:
	var defs: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		defs.append(Defs.bug(id))
	for m: MapDef in [MapDef.mesa(), MapDef.buttes()]:
		var p := WavePlanner.new(Defs.WAVE_CONFIG, defs, 99, m)
		var plan := p.plan(4)
		var shares: Array = plan["shares"]
		assert_eq(shares.size(), m.count())
		var total := 0.0
		for s: float in shares:
			total += s
		assert_almost(total, 1.0, 0.0001)
		var seen := {}
		for g: Dictionary in plan["groups"]:
			assert_true(int(g["cliff"]) >= 0 and int(g["cliff"]) < m.count())
			seen[int(g["cliff"])] = true
		assert_eq(seen.size(), m.count(), "%s: bugs for every cliff" % m.id)


func test_canyon_planner_shares_match_west_share() -> void:
	var defs: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		defs.append(Defs.bug(id))
	var plan := WavePlanner.new(Defs.WAVE_CONFIG, defs, 5, MapDef.canyon()).plan(3)
	var shares: Array = plan["shares"]
	assert_almost(float(shares[0]), float(plan["west_share"]))
	assert_almost(float(shares[1]), 1.0 - float(plan["west_share"]))
	assert_eq(WavePlanner.heaviest([0.5, 0.5], true), 0)
	assert_eq(WavePlanner.heaviest([0.2, 0.5, 0.3]), 1)
	assert_eq(WavePlanner.heaviest([0.25, 0.25, 0.25, 0.25]), -1)


func test_turret_cover_rule() -> void:
	# Buttes: a centre-column turret on North covers South only.
	assert_true(Targeting.cliff_allows(0, 2, true, 2))
	assert_false(Targeting.cliff_allows(0, 1, true, 2), "not the neighbour")
	assert_false(Targeting.cliff_allows(0, 0, true, 0), "never its own cliff")
	assert_false(Targeting.cliff_allows(0, 2, false, 2), "never a breacher")


func test_shared_pool_splits_evenly_on_four_cliffs() -> void:
	var stock := {0: {&"scrap": 103}, 1: {&"scrap": 0}, 2: {&"scrap": 0}, 3: {&"scrap": 0}}
	var out := RunSave.fit_stock(stock, true, false)
	assert_eq(int(out[1][&"scrap"]), 25)
	assert_eq(int(out[3][&"scrap"]), 25)
	assert_eq(int(out[0][&"scrap"]), 28)
	var back := RunSave.fit_stock(out, false, true)
	assert_eq(int(back[0][&"scrap"]), 103)
	assert_eq(int(back[2][&"scrap"]), 0)


func test_players_per_map() -> void:
	assert_eq(MapDef.players_of(MapDef.CANYON), 2)
	assert_eq(MapDef.players_of(MapDef.MESA), 3)
	assert_eq(MapDef.players_of(MapDef.BUTTES), 4)
	assert_eq(MapDef.by_id(&"nonsense").id, MapDef.CANYON)
