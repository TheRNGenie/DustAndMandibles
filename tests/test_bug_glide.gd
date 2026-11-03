extends TestCase
## Glide (LegBatch / bug_glide.gdshaderinc): a bug updated every few physics
## ticks must be drawn moving every frame, without jumps, and land exactly on
## its real position.


## Where the shader draws a piece written at `at` with glide `c`, at render time `t`.
func _drawn(at: Vector3, c: Color, t: float) -> Vector3:
	return at + LegBatch.glide_offset(c, t)


func test_no_glide_is_drawn_in_place() -> void:
	assert_eq(LegBatch.glide_offset(Color(), 5.0), Vector3.ZERO)
	# Past its end tick a glide is spent: drawn where it was written.
	assert_eq(LegBatch.glide_offset(Color(1, 0, 0, 10.0), 10.0), Vector3.ZERO)
	assert_eq(LegBatch.glide_offset(Color(1, 0, 0, 10.0), 12.5), Vector3.ZERO)


func test_glide_starts_where_drawn_and_lands_on_target() -> void:
	var from := Vector3(1, 2, 3)
	var to := Vector3(2, 2, 5)
	var c := LegBatch.glide_from(from, to, 100, 4)
	assert_true(_drawn(to, c, 100.0).distance_to(from) < 0.0001, "starts where it was drawn")
	assert_true(_drawn(to, c, 102.0).distance_to(from.lerp(to, 0.5)) < 0.0001, "halfway at half time")
	assert_true(_drawn(to, c, 104.0).distance_to(to) < 0.0001, "lands on the real position")


## A bug walking at a steady pace, updated every 3 ticks (20 Hz), drawn at
## 144 fps: every frame moves it, by a steady amount.
func test_steady_walker_moves_every_frame() -> void:
	var speed := 0.05 # m per tick
	var at := Vector3.ZERO
	var c := Color()
	var last_tick := 0
	var prev := Vector3.ZERO
	var steps: Array[float] = []
	var frame_t := 0.0
	for tick in range(3, 60):
		if tick % 3 == 0:
			var drawn := _drawn(at, c, float(tick))
			var real := Vector3(speed * tick, 0, 0)
			c = LegBatch.glide_from(drawn, real, tick, tick - last_tick)
			at = real
			last_tick = tick
		# Frames rendered before the next tick.
		while frame_t < float(tick + 1):
			if frame_t >= float(tick) and tick > 6:
				var p := _drawn(at, c, frame_t)
				steps.append(p.distance_to(prev))
				prev = p
			elif frame_t >= float(tick):
				prev = _drawn(at, c, frame_t)
			frame_t += 60.0 / 144.0
	var lo := 1.0e9
	var hi := 0.0
	for d in steps:
		lo = minf(lo, d)
		hi = maxf(hi, d)
	assert_true(lo > 0.0, "a frame where the bug stood still")
	assert_true(hi < lo * 1.05 + 0.0001, "uneven steps %.4f..%.4f" % [lo, hi])


## Updates at uneven gaps (the turn budget): the drawn path never jumps.
func test_uneven_updates_never_jump() -> void:
	var at := Vector3.ZERO
	var c := Color()
	var last := 0
	var prev := Vector3.ZERO
	var worst := 0.0
	var gaps := [2, 5, 3, 1, 4, 6, 2, 3]
	var tick := 0
	var est := 1.0
	for g: int in gaps:
		var next := tick + g
		# Frames between this update and the next (4 per tick).
		for k in g * 4:
			var t := float(tick) + float(k) / 4.0
			var p := _drawn(at, c, t)
			if tick > 0 or k > 0:
				worst = maxf(worst, p.distance_to(prev))
			prev = p
		tick = next
		var real := Vector3(0.1 * tick, 0, 0.02 * tick)
		var drawn := _drawn(at, c, float(tick))
		est = LegBatch.next_gap(est, tick - last)
		c = LegBatch.glide_from(drawn, real, tick, roundi(est))
		at = real
		last = tick
	# A quarter tick of a ~0.1 m/tick walk is ~0.026 m; a step to catch up on a
	# late update stays well under a jump.
	assert_true(worst < 0.06, "drawn path jumped %.3f m" % worst)
