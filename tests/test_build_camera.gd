extends TestCase
## Build mode's third-person camera: a spring arm about 4 m back and up from
## the eye that snaps in when something's in the way and eases back out.

const SettingsScript := preload("res://autoload/Settings.gd")
const InputScript := preload("res://autoload/InputSetup.gd")


func test_arm_is_about_four_metres_behind_and_above() -> void:
	var full := BuildCamArm.full_arm()
	assert_true(full > 3.5 and full < 4.5, "about 4 m (%.2f)" % full)
	var dir := BuildCamArm.arm_dir(Vector3(0, 0, -1)) # looking north (-Z)
	assert_true(dir.z > 0.6, "behind you")
	assert_true(dir.y > 0.3, "above you")
	assert_true(dir.x > 0.0, "a little over the right shoulder")
	assert_almost(dir.length(), 1.0)


func test_spring_arm_snaps_in_at_once() -> void:
	var full := BuildCamArm.full_arm()
	assert_almost(BuildCamArm.arm_length(full, 0.5, full, 0.016), full * 0.5, 0.001, "rock halfway: in at once")
	assert_almost(BuildCamArm.arm_length(full, 0.0, full, 0.016), BuildCamArm.MIN_ARM, 0.001, "never inside your hat")


func test_spring_arm_eases_back_out() -> void:
	var full := BuildCamArm.full_arm()
	var a := BuildCamArm.arm_length(full, 1.0, 1.0, 0.1)
	assert_almost(a, 1.0 + BuildCamArm.EASE_OUT * 0.1, 0.001, "grows gradually")
	assert_almost(BuildCamArm.arm_length(full, 1.0, full - 0.01, 1.0), full, 0.001, "stops at full length")
	assert_almost(BuildCamArm.arm_length(full, 1.0, 0.0, 0.016), full, 0.001, "first frame: straight to place")


func test_setting_is_saved_and_rebindable() -> void:
	assert_true(SettingsScript.SAVED_KEYS.has("build_cam_third"), "remembered between sessions")
	assert_true(SettingsScript.REMAPPABLE.has("build_camera"), "on the Controls tab")
	assert_true(InputScript.KEY_BINDINGS.has("build_camera"))
	var keys: Array = InputScript.KEY_BINDINGS["build_camera"]
	for action: String in InputScript.KEY_BINDINGS:
		if action != "build_camera" and not action.begins_with("debug"):
			for k: int in InputScript.KEY_BINDINGS[action]:
				assert_false(keys.has(k), "its key is free (clashes with %s)" % action)
