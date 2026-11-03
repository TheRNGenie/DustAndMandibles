extends TestCase
## Prompt text is split into a title and keycap hints for the prompt card.


func test_plant_prompt() -> void:
	var p := KeyHints.parse("Corn seeds: 3\nE: plant   F: change seed")
	assert_eq(p["title"], ["Corn Seeds: 3"])
	assert_eq(p["keys"], [["E", "Plant"], ["F", "Change Seed"]])


func test_title_before_key() -> void:
	var p := KeyHints.parse("Rain catcher: 12 water - E: fill your bucket (up to 6)")
	assert_eq(p["title"], ["Rain Catcher: 12 water"])
	assert_eq(p["keys"], [["E", "Fill Your Bucket (Up to 6)"]])


func test_no_keys_is_all_title() -> void:
	var p := KeyHints.parse("Corn growing: 40%")
	assert_eq(p["title"], ["Corn Growing: 40%"])
	assert_eq((p["keys"] as Array).size(), 0)
