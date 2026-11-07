extends TestCase
## HyperPlan (the Hyper CPU's route parameters) and PilotInput (its key presses).


func test_round_trip() -> void:
	var back := HyperPlan.decode(HyperPlan.encode(HyperPlan.chain()))
	assert_eq(int(back["n_sw"]), HyperPlan.SLOTS, "chain plan swings")
	assert_eq(int(back["hops"]), 2, "chain plan hops")
	assert_eq((back["swings"] as Array).size(), HyperPlan.SLOTS, "slot count")
	assert_almost(float(back["swings"][3]["hold"]), 0.08, 0.001, "hold kept")


func test_clamps_and_old_plans() -> void:
	var v := PackedFloat32Array()
	for i in HyperPlan.size():
		v.append(1e6)
	var plan := HyperPlan.decode(v)
	assert_eq(int(plan["hops"]), 12, "hops clamped")
	assert_true(float(plan["hook_dist"]) <= 88.0, "hook distance clamped")
	# A plan saved before a parameter existed still loads (defaults fill in).
	var old := {"hops": 1, "n_sw": 1, "hook_dist": 50.0, "swings": [{"yaw": 10.0, "pitch": 30.0}]}
	assert_eq(HyperPlan.encode(old).size(), HyperPlan.size(), "old plan encodes to the full size")


func test_pilot_input_taps() -> void:
	var it := PilotInput.new()
	it.press(&"jump")
	assert_true(it.just(&"jump") and it.held(&"jump"), "a press is down and new")
	it.begin_tick()
	assert_true(not it.just(&"jump") and it.held(&"jump"), "next tick: held, not new")
	it.hold(&"jump")
	assert_false(it.just(&"jump"), "holding a held key isn't a new press")
	it.release(&"jump")
	it.hold(&"jump")
	assert_true(it.just(&"jump"), "released and pressed again: new")
	it.release_all()
	assert_false(it.held(&"jump"), "release_all lets go")
