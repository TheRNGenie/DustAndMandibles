extends TestCase
## Sarsaparilla Root: a crop you grow for your partner. Its tonic stacks, runs
## only on wave time, and speeds up the partner's turrets; the crop is wired
## into every list a crop needs (seeds, market, plots, guide, hotbar, chest).


func test_one_tonic_lasts_a_minute_and_stacks_to_a_cap() -> void:
	assert_almost(PartnerTonic.add(0.0), 60.0)
	assert_almost(PartnerTonic.add(30.0), 90.0, 0.001, "a second tonic adds on")
	assert_almost(PartnerTonic.add(170.0), PartnerTonic.MAX_TIME, 0.001, "capped")
	assert_almost(PartnerTonic.add(-5.0), 60.0, 0.001, "nothing negative carries over")


func test_clock_runs_only_in_waves() -> void:
	assert_almost(PartnerTonic.tick(60.0, 1.5, true), 58.5)
	assert_almost(PartnerTonic.tick(60.0, 30.0, false), 60.0, 0.001, "build phase: paused")
	assert_almost(PartnerTonic.tick(0.5, 2.0, true), 0.0, 0.001, "never below zero")


func test_turrets_fire_fifteen_percent_faster_under_a_tonic() -> void:
	assert_almost(PartnerTonic.interval_mult(0.0), 1.0)
	var m := PartnerTonic.interval_mult(12.0)
	assert_true(m < 1.0, "shorter gap between shots")
	assert_almost(1.0 / m, 1.15, 0.001, "15% more shots")


func test_crop_is_registered_with_its_seed() -> void:
	var c := Defs.crop(&"sarsaparilla")
	assert_true(c != null, "crop def loads")
	if c == null:
		return
	assert_eq(c.seed_item, &"seed_sarsaparilla")
	assert_true(c.harvest.has(PartnerTonic.ITEM), "harvest gives tonic roots")
	assert_true(EconomyLedger.RESOURCES.has(&"seed_sarsaparilla"))
	assert_true(EconomyLedger.RESOURCES.has(PartnerTonic.ITEM))
	assert_false(EconomyLedger.is_shared(PartnerTonic.ITEM), "roots are personal")
	assert_true(CropPlot.SEEDS.has(&"sarsaparilla"), "plantable (F cycles to it)")
	assert_true(c.role != "", "has a job line")


func test_seed_is_sold_at_the_airship_market_and_roots_sell_for_your_scrap() -> void:
	assert_true(VendorCart.SEEDS.has(&"seed_sarsaparilla"))
	assert_eq(MarketPrices.seed_price(Defs.crop(&"sarsaparilla")), MarketPrices.FLAT_SEED)
	assert_eq(MarketPrices.currency(PartnerTonic.ITEM), ResNames.PERSONAL_ID, "the one crop that pays your own scrap (Logan, Nov 11)")


func test_hotbar_chest_and_guide_know_it() -> void:
	assert_eq(Hotbar.PICKUP_ITEMS[0], PartnerTonic.ITEM, "first pickup slot (4) when carried")
	assert_true(Hotbar.NAMES.has(PartnerTonic.ITEM))
	assert_true(StorageChest.ITEMS.has(PartnerTonic.ITEM), "can be left in a deposit box")
	assert_true(FieldGuide.CROP_ORDER.has(&"sarsaparilla"))
	assert_false(FieldGuide.entry("crops", &"sarsaparilla").is_empty(), "field guide entry")
	assert_false((FieldGuide.text().get("basics", {}) as Dictionary).is_empty(), "basics help tab text")


func test_models_build_for_every_stage() -> void:
	for stage in CropBuilder.STAGES:
		var m := CropBuilder.patch(&"sarsaparilla", stage)
		assert_true(m != null and m.get_surface_count() > 0, "stage %d mesh" % stage)
	var ripe := CropBuilder.patch(&"sarsaparilla", 4).get_aabb()
	var young := CropBuilder.patch(&"sarsaparilla", 2).get_aabb()
	assert_true(ripe.size.y > young.size.y, "grows taller")
	assert_true(CropBuilder.packet(&"sarsaparilla").get_surface_count() > 0, "seed packet")
	var held := WeaponBuilder.held_item(PartnerTonic.ITEM)
	assert_true(held != null and held.get_surface_count() > 0, "held root bundle (hotbar icon)")
