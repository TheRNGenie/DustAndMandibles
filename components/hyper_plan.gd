class_name HyperPlan
extends RefCounted
## One way to fly a leg, for the Hyper CPU (HyperPilot): how many slide-hops to
## chain, which swings to take on the way (each a hook direction relative to
## the goal and when to let go), and when to pull in to the goal. A plan is a
## Dictionary so the route book (data/hyper_routes.json) stores it as is; the
## learner (HyperLearn) searches over the flat vector form.

## Swing slots a plan can use.
const SLOTS := 8

## [name, low, high] for each flat parameter; swing parameters repeat per slot.
const BASE: Array = [
	["hops", 0.0, 12.0],      # slide-hops to chain before (and between) swings
	["hop_min", 4.0, 30.0],   # no more hops this close to the goal (m)
	["hook_dist", 12.0, 88.0], # pull in to the goal from this far (m)
	["n_sw", 0.0, 8.0],       # swings to take on the way
	["steer", 8.0, 70.0],     # air-steer once the flight is this far off line (deg)
	["lead", 0.0, 1.0],       # aim the final pull this far past the goal (share of 6 m)
	# The slingshot chain (auto > 0.5): instead of the slots, hook the best anchor
	# ahead each time the launcher's ready, let go at the sling, again and again.
	["auto", 0.0, 1.0],
	["vmax", 20.0, 140.0],    # stop chaining at this speed (m/s)
	["chain_stop", 15.0, 150.0], # ...or this close to the goal (m)
	["c_hold", 0.05, 1.0],    # ride each rope at least this long (s)
	["c_rel", -0.3, 0.9],     # let go once climbing at this share of your speed
	["c_up", 0.0, 2.0],       # how much a high anchor beats a far-ahead one
]
const SLOT: Array = [
	["yaw", -80.0, 80.0],     # hook bearing off the goal's (deg)
	["pitch", 5.0, 80.0],     # hook elevation (deg)
	["rel", -0.3, 0.9],       # let go once climbing at this share of your speed
	["max", 0.4, 4.0],        # longest the swing may last (s)
	["jump", 0.0, 1.0],       # > 0.5: let go with a jump (a little extra lift)
	["hold", 0.05, 1.5],      # ride the rope at least this long (s)
]


static func size() -> int:
	return BASE.size() + SLOT.size() * SLOTS


static func bounds() -> Array:
	var out: Array = BASE.duplicate()
	for i in SLOTS:
		out.append_array(SLOT)
	return out


## A sensible first guess: hop in, two swings, pull in from 60 m.
static func default() -> Dictionary:
	var v := PackedFloat32Array()
	for b: Array in bounds():
		v.append((float(b[1]) + float(b[2])) * 0.5)
	var plan := decode(v)
	plan["hops"] = 4
	plan["n_sw"] = 2
	plan["hook_dist"] = 60.0
	plan["auto"] = 0.0
	for s: Dictionary in plan["swings"]:
		s["yaw"] = 0.0
		s["pitch"] = 35.0
		s["rel"] = 0.25
		s["hold"] = 0.18
	return plan


## A guess at the fastest thing the rope allows: hook on, let go almost at
## once (still at the swing's top speed, so the slingshot fires), hook again
## the moment the launcher's ready, over and over. The learner starts from here too.
static func chain() -> Dictionary:
	var plan := default()
	plan["hops"] = 2
	plan["n_sw"] = SLOTS
	plan["hook_dist"] = 30.0
	plan["auto"] = 1.0
	plan["vmax"] = 70.0
	plan["chain_stop"] = 40.0
	plan["c_hold"] = 0.1
	plan["c_rel"] = 0.0
	plan["c_up"] = 0.8
	for s: Dictionary in plan["swings"]:
		s["yaw"] = 0.0
		s["pitch"] = 20.0
		s["rel"] = -0.3
		s["hold"] = 0.08
		s["max"] = 1.0
	return plan


static func clamp_vec(v: PackedFloat32Array) -> PackedFloat32Array:
	var b := bounds()
	var out := v.duplicate()
	for i in out.size():
		out[i] = clampf(out[i], float(b[i][1]), float(b[i][2]))
	return out


static func decode(v: PackedFloat32Array) -> Dictionary:
	var c := clamp_vec(v)
	var plan := {
		"hops": roundi(c[0]),
		"hop_min": c[1],
		"hook_dist": c[2],
		"n_sw": roundi(c[3]),
		"steer": c[4],
		"lead": c[5],
		"auto": c[6],
		"vmax": c[7],
		"chain_stop": c[8],
		"c_hold": c[9],
		"c_rel": c[10],
		"c_up": c[11],
	}
	var swings: Array = []
	for i in SLOTS:
		var o := BASE.size() + i * SLOT.size()
		swings.append({"yaw": c[o], "pitch": c[o + 1], "rel": c[o + 2], "max": c[o + 3], "jump": c[o + 4] > 0.5, "hold": c[o + 5]})
	plan["swings"] = swings
	return plan


static func encode(plan: Dictionary) -> PackedFloat32Array:
	var v := PackedFloat32Array([
		float(plan.get("hops", 4)), float(plan.get("hop_min", 10.0)), float(plan.get("hook_dist", 60.0)),
		float(plan.get("n_sw", 2)), float(plan.get("steer", 30.0)), float(plan.get("lead", 0.3)),
		float(plan.get("auto", 0.0)), float(plan.get("vmax", 60.0)), float(plan.get("chain_stop", 50.0)),
		float(plan.get("c_hold", 0.1)), float(plan.get("c_rel", 0.0)), float(plan.get("c_up", 0.8)),
	])
	var swings: Array = plan.get("swings", [])
	for i in SLOTS:
		var s: Dictionary = swings[i] if i < swings.size() else {}
		v.append_array([float(s.get("yaw", 0.0)), float(s.get("pitch", 35.0)), float(s.get("rel", 0.25)),
				float(s.get("max", 2.0)), 1.0 if bool(s.get("jump", false)) else 0.0, float(s.get("hold", 0.18))])
	return clamp_vec(v)
