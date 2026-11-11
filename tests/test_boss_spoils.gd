extends TestCase
## Boss spoils (Nov 11 playtest fixes): every cliff gets the same at the wave's end.


func test_a_boss_always_leaves_iron_and_two_parts() -> void:
	var got := BossSpoils.roll(true, false, 0.99, 0.99)
	assert_eq(int(got.get(GunRarity.ITEM, 0)), 1, "Meteor Iron")
	var parts := 0
	for k: Variant in got:
		if k != GunRarity.ITEM:
			parts += int(got[k])
	assert_eq(parts, BossSpoils.BOSS_PARTS)


func test_heavy_bugs_roll_and_plain_bugs_leave_nothing() -> void:
	assert_true(BossSpoils.roll(false, true, 0.99, 0.99).is_empty(), "unlucky heavy")
	assert_eq(int(BossSpoils.roll(false, true, 0.0, 0.99).get(GunRarity.ITEM, 0)), 1, "lucky iron")
	assert_true(BossSpoils.roll(false, false, 0.0, 0.0).is_empty(), "not heavy, not a boss")


func test_spoils_add_up() -> void:
	var into := {}
	BossSpoils.add(into, {GunRarity.ITEM: 1})
	BossSpoils.add(into, {GunRarity.ITEM: 1, &"gear": 2})
	assert_eq(int(into[GunRarity.ITEM]), 2)
	assert_eq(int(into[&"gear"]), 2)
