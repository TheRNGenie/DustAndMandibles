extends TestCase
## Canyon Extension and the badlands: tunnel tiers, the wave's split between
## them, the deep-tunnel trickle, the march's sound levels and the terrain field.


func _active_defs() -> Array[BugDef]:
	var out: Array[BugDef] = []
	for id: StringName in Defs.active_bug_ids():
		out.append(Defs.bug(id))
	return out


func test_tunnel_tiers_sit_where_the_plan_says() -> void:
	assert_eq(WorldLayout.all_tunnels().size(), 24)
	for i in WorldLayout.all_tunnels().size():
		var z := absf(float(WorldLayout.all_tunnels()[i][1]))
		match WorldLayout.tunnel_tier(i):
			0:
				assert_true(z >= 55.0 and z <= 80.0, "near %d" % i)
			1:
				assert_true(z >= 130.0 and z <= 170.0, "mid %d" % i)
			2:
				assert_true(z >= 220.0 and z <= 270.0, "deep %d" % i)
		assert_true(z < WorldLayout.WORLD_HALF_Z, "inside the straight corridor")
	assert_eq(WorldLayout.PLAY_HALF_Z, 90.0, "the play area is unchanged")


func test_tier_tunnel_index_stays_in_its_tier_and_skips_sealed() -> void:
	var cb := CliffBuilder.new(1234, MapDef.canyon())
	assert_eq(cb.tunnel_count(), 8, "expeditions and the story still see the near eight")
	assert_eq(cb.all_tunnel_count(), 24)
	for k in 20:
		assert_eq(WorldLayout.tunnel_tier(cb.tier_tunnel_index(1, k)), 1)
		assert_eq(WorldLayout.tunnel_tier(cb.tier_tunnel_index(2, k)), 2)
		assert_true(cb.tier_tunnel_index(0, k) < 8)
	cb.sealed.append(17)
	assert_eq(cb.tier_tunnel_index(2, 1), 18, "a sealed deep tunnel is skipped")
	var mouth: Vector3 = cb.tunnel(20)[0]
	assert_almost(mouth.z, float(WorldLayout.DEEP_TUNNELS[4][1]), 0.01)


func test_tier_shares_follow_the_table() -> void:
	assert_eq(WavePlanner.tier_shares(1), [1.0, 0.0, 0.0] as Array[float])
	assert_eq(WavePlanner.tier_shares(4), [1.0, 0.0, 0.0] as Array[float])
	assert_eq(WavePlanner.tier_shares(5), [0.6, 0.4, 0.0] as Array[float])
	assert_eq(WavePlanner.tier_shares(10), [0.3, 0.4, 0.3] as Array[float])
	assert_eq(WavePlanner.tier_shares(15), [0.3, 0.4, 0.3] as Array[float])
	assert_eq(WavePlanner.tier_shares(16), [0.2, 0.3, 0.5] as Array[float])
	assert_eq(WavePlanner.tier_shares(20), [0.2, 0.3, 0.5] as Array[float])
	assert_eq(WavePlanner.tier_shares(21), [0.15, 0.25, 0.6] as Array[float])


func test_planned_waves_split_bugs_by_tier() -> void:
	var p := WavePlanner.new(Defs.WAVE_CONFIG, _active_defs(), 42, MapDef.canyon())
	for w: int in [2, 7, 12, 18, 24]:
		var plan := p.plan(w)
		var by := [0, 0, 0]
		var total := 0
		for g: Dictionary in plan["groups"]:
			assert_true(g.has("tier"), "every group has a tier")
			by[int(g["tier"])] += int(g["count"])
			total += int(g["count"])
		var shares := WavePlanner.tier_shares(w)
		for t in 3:
			if shares[t] <= 0.0:
				assert_eq(by[t], 0, "wave %d tier %d closed" % [w, t])
			else:
				assert_almost(float(by[t]) / total, shares[t], 0.12, "wave %d tier %d" % [w, t])


func test_other_maps_stay_on_the_near_tier() -> void:
	var p := WavePlanner.new(Defs.WAVE_CONFIG, _active_defs(), 42, MapDef.mesa())
	for g: Dictionary in p.plan(14)["groups"]:
		assert_eq(int(g["tier"]), 0)


func test_trickle_keeps_every_deep_bug() -> void:
	var groups := [
		{"bug": &"dust_mite", "count": 40, "cliff": 0, "lane": 1, "pulse": 0, "tier": 2},
		{"bug": &"dust_mite", "count": 25, "cliff": 1, "lane": 3, "pulse": 2, "tier": 2},
		{"bug": &"dust_mite", "count": 30, "cliff": 1, "lane": 0, "pulse": 1, "tier": 0},
	]
	var chunks := WavePlanner.trickle_chunks(groups, 30.0)
	var n := 0
	for c: Array in chunks:
		n += int(c[1])
	assert_eq(n, 65, "every deep bug, none of the others")
	assert_true(chunks.size() >= 12, "spread over the span (a chunk every ~2.5 s)")
	assert_true(int(chunks[0][2]) != int(chunks[1][2]), "the cliffs take turns")
	assert_eq(WavePlanner.trickle_chunks([groups[2]], 30.0), [])


func test_march_levels() -> void:
	assert_eq(AmbienceMix.march_levels(0), Vector2.ZERO)
	assert_almost(AmbienceMix.march_levels(150).y, 0.0)
	assert_true(AmbienceMix.march_levels(350).y > 0.2)
	assert_almost(AmbienceMix.march_levels(800).y, 1.0)
	assert_true(AmbienceMix.march_levels(300).x > AmbienceMix.march_levels(30).x, "more floor bugs, more rumble")


func test_badlands_field() -> void:
	var cb := CliffBuilder.new(1234, MapDef.canyon())
	var land := BadlandsTerrain.new(cb)
	var lo := INF
	var hi := -INF
	for i in 400:
		var x := -1800.0 + float(i % 20) * 190.0
		var z := -1800.0 + float(i / 20) * 190.0
		var s := land.sample(x, z)
		lo = minf(lo, s.x)
		hi = maxf(hi, s.x)
		for k in [s.y, s.z, s.w]:
			assert_true(k >= 0.0 and k <= 1.0, "masks 0-1")
	assert_true(lo > WorldLayout.CLIFF_HEIGHT, "never down into the canyon's depth")
	assert_true(hi - lo > 25.0, "real relief: mesas and washes")
	assert_eq(land.sample(321.0, -654.0), BadlandsTerrain.new(cb).sample(321.0, -654.0), "seeded")
	assert_false(land.clear_of_canyon(0.0, 0.0), "no formations in the canyon")
	assert_false(land.clear_of_canyon(100.0, 250.0), "nor on the corridor's plateaus")
	assert_true(land.clear_of_canyon(600.0, 0.0))
