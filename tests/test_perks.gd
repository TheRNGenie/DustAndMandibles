extends TestCase
## Rancher's Ledger: perk table, profile (unlocks, loadout, save/load), Brands.


func _rich(brands: int = 1000) -> PerkProfile:
	var p := PerkProfile.new()
	p.brands = brands
	return p


func test_table_is_well_formed() -> void:
	var seen: Dictionary = {}
	for p: Dictionary in PerkTable.PERKS:
		var id: StringName = p["id"]
		assert_false(seen.has(id), "duplicate perk %s" % id)
		seen[id] = true
		assert_true(PerkTable.TREES.has(p["tree"]), "%s has a known tree" % id)
		var costs: Array = p["costs"]
		assert_true(costs.size() >= 1 and costs.size() <= 3, "%s has 1-3 ranks" % id)
		for i in range(1, costs.size()):
			assert_true(int(costs[i]) > int(costs[i - 1]), "%s: each rank costs more" % id)
		assert_true(str(p["owner"]) == "local" or str(p["owner"]) == "host", "%s owner" % id)
		if str(p["fmt"]) == "pct":
			# Modest: no single percentage perk goes past 25% a rank or 50% maxed.
			assert_true(float(p["per_rank"]) <= 0.25, "%s per rank is modest" % id)
			assert_true(PerkTable.amount(id, costs.size()) <= 0.5 + 0.001, "%s maxed is modest" % id)
		assert_false(str(p["desc"]).is_empty(), "%s has a description" % id)
	for tree in PerkTable.TREES:
		var n := PerkTable.in_tree(tree).size()
		assert_true(n >= 10 and n <= 12, "tree %s has 10-12 perks (has %d)" % [tree, n])


func test_amounts_and_text() -> void:
	assert_almost(PerkTable.amount(&"quick_hands", 2), 0.16)
	assert_almost(PerkTable.amount(&"quick_hands", 9), 0.24, 0.001, "rank clamps to max")
	assert_eq(PerkTable.value_text(&"quick_hands", 3), "24%")
	assert_eq(PerkTable.value_text(&"scrap_stash", 2), "40")
	assert_eq(PerkTable.describe(&"quick_hands", 0), "Reload 8% faster.", "unowned shows rank 1")
	var lo := {&"bulk_lumber": 2, &"long_sights": 1}
	assert_almost(PerkTable.less(lo, &"bulk_lumber"), 0.9)
	assert_almost(PerkTable.more(lo, &"long_sights"), 1.05)
	assert_almost(PerkTable.more(lo, &"marksman"), 1.0, 0.001, "not taken = no effect")


func test_scale_cost_rounds_and_floors_at_one() -> void:
	var c := PerkTable.scale_cost({&"scrap": 40, &"chitin": 3, &"water": 0}, 0.85)
	assert_eq(c[&"scrap"], 34)
	assert_eq(c[&"chitin"], 3)
	assert_eq(c[&"water"], 0)
	assert_eq(PerkTable.scale_cost({&"chitin": 1}, 0.5)[&"chitin"], 1, "never below 1")


func test_bandolier_bonus() -> void:
	assert_eq(PerkTable.bandolier_bonus(6, 1), 1)
	assert_eq(PerkTable.bandolier_bonus(8, 2), 2)
	assert_eq(PerkTable.bandolier_bonus(60, 2), 12, "the Gatling gets 10% a rank")
	assert_eq(PerkTable.bandolier_bonus(2, 2), 0, "shotguns get nothing")


func test_unlock_spends_brands_and_ranks_up() -> void:
	var p := _rich(100)
	assert_true(p.unlock(&"quick_hands"))
	assert_eq(p.brands, 85)
	assert_eq(p.rank(&"quick_hands"), 1)
	assert_eq(p.next_cost(&"quick_hands"), 30)
	assert_true(p.unlock(&"quick_hands"))
	assert_true(p.unlock(&"quick_hands"), "55 left pays the 50 for rank 3")
	assert_eq(p.brands, 5)
	assert_eq(p.next_cost(&"quick_hands"), -1, "maxed")


func test_unlock_needs_brands_and_stops_at_max() -> void:
	var p := _rich(10)
	assert_false(p.unlock(&"quick_hands"))
	assert_eq(p.unlock_block(&"quick_hands"), "Needs 5 more Notches.")
	p.brands = 1000
	assert_true(p.unlock(&"barn_raising"))
	assert_false(p.unlock(&"barn_raising"), "single-rank perk can't rank up")
	assert_eq(p.unlock_block(&"barn_raising"), "Fully ranked.")
	assert_eq(PerkTable.spent_to(&"quick_hands", 3), 95)


func test_loadout_needs_unlock_and_caps_at_twelve() -> void:
	var p := _rich(100000)
	assert_false(p.toggle(&"quick_hands"), "locked perks can't be taken")
	var ids := PerkTable.ids()
	for id in ids:
		p.unlock(id)
	for i in 12:
		assert_true(p.toggle(ids[i]))
	assert_eq(p.loadout.size(), 12)
	assert_false(p.toggle(ids[12]), "13th is refused")
	assert_eq(p.add_block(ids[12]), "Loadout full (12).")
	assert_true(p.toggle(ids[0]), "taking one out works")
	assert_eq(p.loadout.size(), 11)
	assert_true(p.toggle(ids[12]))


func test_loadout_ranks_and_sanitize() -> void:
	var p := _rich(1000)
	p.unlock(&"bulk_lumber")
	p.unlock(&"bulk_lumber")
	p.toggle(&"bulk_lumber")
	assert_eq(p.loadout_ranks(), {&"bulk_lumber": 2})
	var raw := {"bulk_lumber": 9, "made_up": 1, "tinker": 0, "salvager": 1}
	var s := PerkProfile.sanitize(raw)
	assert_eq(s.get(&"bulk_lumber"), 3, "rank clamped")
	assert_false(s.has(&"made_up"))
	assert_false(s.has(&"tinker"), "rank 0 dropped")
	assert_eq(s.get(&"salvager"), 1)
	var many: Dictionary = {}
	for id in PerkTable.ids():
		many[String(id)] = 1
	assert_eq(PerkProfile.sanitize(many).size(), PerkTable.MAX_LOADOUT, "a peer can't send more than 12")
	assert_eq(PerkProfile.sanitize("junk"), {})


func test_round_trip_and_validation() -> void:
	var p := _rich(500)
	p.unlock(&"green_thumb")
	p.toggle(&"green_thumb")
	p.buy_cosmetic("hat", "sombrero")
	p.bank_run(30, 7, false)
	var q := PerkProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	assert_eq(q.brands, p.brands)
	assert_eq(q.rank(&"green_thumb"), 1)
	assert_true(q.in_loadout(&"green_thumb"))
	assert_true(q.owns_cosmetic("hat", "sombrero"))
	assert_eq(q.runs, 1)
	assert_eq(q.best_wave, 7)
	# A hand-edited save with a locked perk in the loadout and a bad rank.
	var bad := PerkProfile.from_dict({"brands": -5, "ranks": {"tinker": 7}, "loadout": ["tinker", "green_thumb", "nope"]})
	assert_eq(bad.brands, 0)
	assert_eq(bad.rank(&"tinker"), 2)
	assert_eq(bad.loadout, [&"tinker"] as Array[StringName])


func test_cosmetics() -> void:
	var p := _rich(30)
	assert_true(p.owns_cosmetic("hat", "cattleman"), "free options are owned")
	assert_false(p.owns_cosmetic("hat", "sombrero"))
	assert_false(p.buy_cosmetic("hat", "sombrero"), "40 > 30")
	assert_true(p.buy_cosmetic("hat", "ten_gallon"))
	assert_eq(p.brands, 5)
	for slot: String in PerkTable.COSMETICS:
		assert_true(DummyLook.SLOTS.has(slot), "cosmetic slot %s exists" % slot)
		for opt: String in PerkTable.COSMETICS[slot]:
			var found := false
			for o: Array in DummyLook.SLOTS[slot][1]:
				found = found or o[0] == opt
			assert_true(found, "cosmetic %s:%s exists" % [slot, opt])
			assert_true(DummyLook.default_look()[slot] != opt, "the default %s is never locked" % slot)


func test_brand_earnings() -> void:
	var lost := BrandRules.earnings(6, 20, 5, false, true)
	assert_eq(lost["total"], 5 + 18 + 10)
	var won := BrandRules.earnings(20, 20, 50, true, true)
	assert_eq(won["total"], 5 + 60 + 40 + 25, "saves capped at 20")
	var solo := BrandRules.earnings(3, 20, 9, false, false)
	assert_eq(solo["total"], 5 + 9, "no partner, no saves")
	var endless := BrandRules.earnings(23, 20, 0, false, true)
	assert_eq(endless["total"], 5 + 60 + 12)
	assert_eq(BrandRules.earnings(0, 20, 0, false, true)["total"], 5, "even wave 1 pays something")


func test_new_gun_and_engineer_perks() -> void:
	assert_eq(PerkTable.describe(&"lucky_shot", 2), "Your gun hits have a 10% chance to do double damage.")
	assert_eq(PerkTable.describe(&"point_blank", 1), "Gun hits within 8 m do 12% more damage.")
	assert_eq(PerkTable.describe(&"overtime", 2), "When a wave ends, turrets you built patch 30% of their HP.")
	assert_eq(PerkTable.describe(&"scrap_scavenger", 1), "Kills by turrets you built drop 15% more scrap.")
