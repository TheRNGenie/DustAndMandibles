extends TestCase
## Settings > Controls > Reset Progress (Perks.reset_progress -> PerkProfile.reset_progress).


func test_reset_clears_notches_perks_cosmetics_and_codes() -> void:
	var p := PerkProfile.new()
	p.brands = 250
	p.lifetime_brands = 900
	p.ranks = {&"scrap_stash": 2}
	p.loadout = [&"scrap_stash"] as Array[StringName]
	p.cosmetics = ["hat:bowler"] as Array[String]
	p.secrets = ["weapon:dino_rifle", "ability:grapple_any"] as Array[String]
	p.runs = 12
	p.wins = 3
	p.best_wave = 18
	p.reset_progress()
	assert_eq(p.brands, 0)
	assert_eq(p.lifetime_brands, 0)
	assert_eq(p.ranks.size(), 0, "perks gone")
	assert_eq(p.loadout.size(), 0, "loadout gone")
	assert_eq(p.cosmetics.size(), 0, "bought looks gone")
	assert_eq(p.secrets.size(), 0, "codes gone")
	assert_eq([p.runs, p.wins, p.best_wave], [12, 3, 18], "run records stay")
