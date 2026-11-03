extends TestCase
## Ambient layers: the swarm swells with climbers and height, wind with weather,
## the wave music grows with the waves, and far shots echo.


func test_swarm_silent_without_climbers() -> void:
	var s := AmbienceMix.swarm_levels(0, 0.0, 0.0)
	assert_eq(s.x, AmbienceMix.SILENT_DB)
	assert_eq(s.y, AmbienceMix.SILENT_DB)


func test_swarm_grows_with_count_and_height() -> void:
	var few_low := AmbienceMix.swarm_levels(3, 3 * 0.3, 0.0)
	var many_low := AmbienceMix.swarm_levels(30, 30 * 0.3, 0.0)
	var many_high := AmbienceMix.swarm_levels(30, 30 * 0.95, 0.85)
	assert_true(many_low.x > few_low.x)
	assert_true(many_high.x > many_low.x)
	# The close skitter only comes in as they near the top.
	assert_true(many_low.y <= AmbienceMix.SILENT_DB + 0.1)
	assert_true(many_high.y > -12.0)
	# Never louder than the bed's ceiling (gunfire plays at 0 dB).
	assert_true(AmbienceMix.swarm_levels(750, 750.0, 1.0).x <= AmbienceMix.BED_DB + 0.01)
	assert_true(AmbienceMix.swarm_levels(750, 750.0, 1.0).y <= AmbienceMix.NEAR_DB + 0.01)


func test_wind_stronger_at_edge_and_in_storms() -> void:
	var calm := AmbienceMix.wind_db(Weather.Kind.CLEAR, 0.0, 0.0)
	assert_true(AmbienceMix.wind_db(Weather.Kind.CLEAR, 1.0, 0.0) > calm)
	assert_true(AmbienceMix.wind_db(Weather.Kind.DUST_STORM, 0.0, 0.0) > AmbienceMix.wind_db(Weather.Kind.WINDY, 0.0, 0.0))
	assert_true(AmbienceMix.wind_db(Weather.Kind.WINDY, 0.0, 0.0) > calm)
	assert_true(AmbienceMix.wind_db(Weather.Kind.DUST_STORM, 1.0, 1.0) <= -3.0)


func test_wave_music_builds() -> void:
	assert_eq(AmbienceMix.wave_track(1, Weather.Kind.CLEAR), &"wave_theme_1")
	assert_eq(AmbienceMix.wave_track(8, Weather.Kind.CLEAR), &"wave_theme_2")
	assert_eq(AmbienceMix.wave_track(2, Weather.Kind.BLOOD_MOON), &"wave_theme_2")
	assert_true(AmbienceMix.wave_music_db(9) > AmbienceMix.wave_music_db(1))
	assert_true(AmbienceMix.wave_music_db(40) <= -5.0)


func test_echo_only_for_far_shots() -> void:
	assert_true(AmbienceMix.echo_db(5.0) < -50.0)
	assert_true(AmbienceMix.echo_db(60.0) > AmbienceMix.echo_db(25.0))
	assert_true(AmbienceMix.echo_db(60.0) <= AmbienceMix.ECHO_DB)
	assert_true(AmbienceMix.echo_db(300.0) < AmbienceMix.echo_db(60.0))
