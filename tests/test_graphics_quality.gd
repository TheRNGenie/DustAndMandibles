extends TestCase
## Graphics quality presets: the auto pick, preset matching, and the tables.


func test_auto_pick_by_gpu() -> void:
	assert_eq(GraphicsQuality.auto_preset(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, "AMD Radeon(TM) Graphics"), "low")
	assert_eq(GraphicsQuality.auto_preset(RenderingDevice.DEVICE_TYPE_OTHER, "Intel(R) UHD Graphics 620"), "low")
	assert_eq(GraphicsQuality.auto_preset(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, "NVIDIA GeForce RTX 3080"), "high")
	assert_eq(GraphicsQuality.auto_preset(RenderingDevice.DEVICE_TYPE_OTHER, "NVIDIA GeForce GTX 1060"), "high")


func test_presets_match_themselves() -> void:
	for p: String in GraphicsQuality.PRESETS:
		var values: Dictionary = (GraphicsQuality.PRESET_VALUES[p] as Dictionary).duplicate()
		assert_eq(GraphicsQuality.matching_preset(values), p)
		for key: String in GraphicsQuality.PRESET_KEYS:
			assert_true(values.has(key), "%s sets %s" % [p, key])


func test_hand_changes_make_custom() -> void:
	var values: Dictionary = (GraphicsQuality.PRESET_VALUES["high"] as Dictionary).duplicate()
	values["msaa"] = 3 # 8x MSAA, as the old default settings files might hold
	assert_eq(GraphicsQuality.matching_preset(values), "custom")


func test_old_default_settings_are_high() -> void:
	# A settings file saved before presets, with the old defaults, reads as High.
	var old := {"shadows": true, "msaa": 1, "render_scale": 1.0, "shadow_detail": 2, "effects": 2,
			"view_distance": 2, "particles": 2, "bug_detail": 2}
	assert_eq(GraphicsQuality.matching_preset(old), "high")


func test_high_keeps_the_original_numbers() -> void:
	var h := GraphicsQuality.HIGH
	assert_eq(GraphicsQuality.SHADOW_ATLAS[h], 4096)
	assert_almost(GraphicsQuality.SHADOW_DISTANCE[h], 160.0)
	assert_almost(GraphicsQuality.VIEW_FAR[h], 600.0)
	assert_eq(GraphicsQuality.BUG_FULL_DETAIL[h], 40)
	assert_almost(GraphicsQuality.BUG_TURN_BUDGET_US[h], 5000.0)
	assert_almost(GraphicsQuality.PARTICLE_RATIO[h], 1.0)


func test_levels_clamp() -> void:
	assert_eq(GraphicsQuality.level(-3), GraphicsQuality.LOW)
	assert_eq(GraphicsQuality.level(9), GraphicsQuality.HIGH)
