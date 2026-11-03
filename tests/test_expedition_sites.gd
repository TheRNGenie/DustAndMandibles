extends TestCase
## Canyon Expeditions, the sites: generation from each map's tunnels, loot
## tables, the egg-smash cut to a tunnel's next wave and the wreck's collapse clock.


func _tunnels(map_id: StringName) -> Array:
	var cb := CliffBuilder.new(1234, MapDef.by_id(map_id))
	var out: Array = []
	for i in cb.tunnel_count():
		out.append(cb.tunnel(i))
	return out


func test_generation_is_deterministic() -> void:
	for map_id: StringName in MapDef.IDS:
		var t := _tunnels(map_id)
		var a := SitePlan.generate(t, 4242)
		var b := SitePlan.generate(t, 4242)
		assert_eq(a.size(), b.size(), String(map_id))
		for i in a.size():
			assert_eq(a[i].kind, b[i].kind, "%s site %d kind" % [map_id, i])
			assert_eq(a[i].tunnel, b[i].tunnel, "%s site %d tunnel" % [map_id, i])
			assert_true(a[i].pos.is_equal_approx(b[i].pos), "%s site %d pos" % [map_id, i])


func test_count_and_spacing_per_map() -> void:
	for map_id: StringName in MapDef.IDS:
		var t := _tunnels(map_id)
		for s in 40:
			var sites := SitePlan.generate(t, s * 7919 + 3)
			assert_true(sites.size() >= SitePlan.MIN_SITES and sites.size() <= SitePlan.MAX_SITES,
					"%s seed %d: %d sites" % [map_id, s, sites.size()])
			var kinds := {}
			var tunnels := {}
			for x in sites:
				assert_false(kinds.has(x.kind), "%s: one of each kind" % map_id)
				assert_false(tunnels.has(x.tunnel), "%s: one site per tunnel" % map_id)
				kinds[x.kind] = true
				tunnels[x.tunnel] = true
				for y in sites:
					if y != x:
						assert_true(Vector2(x.pos.x - y.pos.x, x.pos.z - y.pos.z).length() >= SitePlan.MIN_SEPARATION - 0.01)


func test_different_seeds_differ() -> void:
	var t := _tunnels(MapDef.CANYON)
	var seen := {}
	for s in 12:
		var sites := SitePlan.generate(t, s + 100)
		seen[str(sites.map(func(x: SitePlan.Site) -> String: return "%d@%d" % [x.kind, x.tunnel]))] = true
	assert_true(seen.size() > 4, "seeds give different layouts")


func test_loot_tables() -> void:
	for kind in SitePlan.KIND_IDS.size():
		var a := SitePlan.loot_for(kind, 77, 3)
		var b := SitePlan.loot_for(kind, 77, 3)
		assert_true(a.size() >= 3, "kind %d has loot" % kind)
		assert_eq(SitePlan.totals(a), SitePlan.totals(b), "kind %d deterministic" % kind)
		for l in a:
			assert_true(l.local.length() < SitePlan.RADIUS + 1.0)
	# Each kind's signature haul.
	var mouth := SitePlan.totals(SitePlan.loot_for(SitePlan.Kind.MOUTH, 5, 1))
	var parts := 0
	for k: StringName in mouth:
		if CraftTable.is_part(k):
			parts += int(mouth[k])
	assert_true(parts >= 1 and int(mouth.get(&"chitin", 0)) > 0, "tunnel mouth: parts and chitin")
	assert_true(int(SitePlan.totals(SitePlan.loot_for(SitePlan.Kind.NEST, 5, 1)).get(SitePlan.NEST_EGG, 0)) >= 6, "nest: eggs")
	var camp := SitePlan.totals(SitePlan.loot_for(SitePlan.Kind.CAMP, 5, 1))
	assert_eq(int(camp.get(SitePlan.SPECIMEN, 0)), 1)
	assert_eq(int(camp.get(SitePlan.JOURNAL_PAGE, 0)), 1)
	var bones := SitePlan.totals(SitePlan.loot_for(SitePlan.Kind.BONEYARD, 5, 1))
	assert_eq(int(bones.get(&"upgrade_token", 0)), 1, "bone yard: a boss trophy")
	# The wreck is scrap by the cartload: more than a cliff's wave pay.
	var wreck := SitePlan.totals(SitePlan.loot_for(SitePlan.Kind.WRECK, 5, 1))
	assert_true(int(wreck.get(&"scrap", 0)) > EconomyLedger.wave_pay(1) * 2, "wreck scrap %d" % int(wreck.get(&"scrap", 0)))
	# Refills bring new loot, and more of it later.
	assert_true(SitePlan.totals(SitePlan.loot_for(SitePlan.Kind.WRECK, 5, 10)).get(&"scrap", 0) > wreck[&"scrap"])


func test_sleepers_grow_with_waves() -> void:
	for kind in SitePlan.KIND_IDS.size():
		var early := SitePlan.sleepers_for(kind, 9, 1)
		var late := SitePlan.sleepers_for(kind, 9, 12)
		assert_true(late.size() >= early.size(), "kind %d" % kind)
		for s: Array in late:
			assert_true(Defs.bug(StringName(s[0])) != null, "sleeper %s exists" % s[0])
	assert_true(SitePlan.sleepers_for(SitePlan.Kind.NEST, 9, 12).size() > SitePlan.sleepers_for(SitePlan.Kind.NEST, 9, 1).size())


func test_egg_smash_cuts_that_tunnel_next_wave() -> void:
	SitePlan.reset_cuts()
	assert_eq(SitePlan.smash_quota(4), 2)
	assert_eq(SitePlan.smash_quota(3), 2)
	SitePlan.smash(3, 5)
	assert_true(SitePlan.is_cut(3, 5))
	assert_false(SitePlan.is_cut(3, 6), "only the next wave")
	assert_false(SitePlan.is_cut(2, 5), "only that tunnel")
	# Over a wave the tunnel sends 80% of its bugs (fractions carried between groups).
	var sent := 0
	var planned := 0
	for i in 20:
		planned += 3
		sent += SitePlan.cut_count(3, 5, 3)
	assert_eq(sent, 48, "60 planned -> 48 sent")
	assert_eq(SitePlan.cut_count(2, 5, 3), 3, "other tunnels untouched")
	assert_eq(SitePlan.cut_count(3, 6, 3), 3, "the wave after is untouched")
	SitePlan.reset_cuts()


func test_wreck_collapse_clock() -> void:
	var c := SitePlan.WreckClock.new()
	var events: Array[StringName] = []
	var t := 0.0
	while t < SitePlan.WRECK_COLLAPSE + 1.0:
		var e := c.tick(0.5, true)
		t += 0.5
		if e != &"":
			events.append(e)
			if e == &"creak":
				assert_almost(t, SitePlan.WRECK_WARN, 0.51)
			else:
				assert_almost(t, SitePlan.WRECK_COLLAPSE, 0.51)
	assert_eq(events, [&"creak", &"collapse"] as Array[StringName])
	assert_true(c.collapsed)
	# Stepping out lets it settle; a short visit never brings it down.
	var d := SitePlan.WreckClock.new()
	for i in 20:
		d.tick(1.0, i % 3 != 2)
	assert_false(d.collapsed, "in and out doesn't collapse it as fast")
	d.reset()
	assert_almost(d.t, 0.0)


func test_new_items_sell() -> void:
	assert_true(MarketPrices.BASE.has(SitePlan.NEST_EGG), "eggs sell at the airship market")
	assert_true(VendorCart.ITEMS.has(SitePlan.NEST_EGG))
	assert_true(MarketPrices.BASE.has(SitePlan.SPECIMEN))
