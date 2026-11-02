class_name DummyActions
extends RefCounted
## Short acted-out moves the dummy plays when you use something: pulling a crop,
## planting a seed, tipping the bucket over a plot, working a pump, rummaging
## the scrap pile, yanking a slot lever, dealing cards, throwing dice, opening
## the chest, scribbling in the ledger, paying at a shop, swinging a hammer...
## Each is a pose over time t (0..1) layered on top of the walk/idle pose with
## weight w. Front is -Z: a positive X turn swings a limb forward, knees bend
## negative, and a negative torso X leans forward.

const DUR := {
	&"harvest": 0.95, &"plant": 1.1, &"water": 1.25, &"pump": 1.2, &"salvage": 1.15,
	&"loot": 1.0, &"slots": 1.0, &"cards": 1.0, &"dice": 1.05, &"roulette": 1.0,
	&"chest": 0.9, &"ledger": 1.15, &"buy": 0.85, &"pickup": 0.8, &"hammer": 1.1,
	&"zip": 0.6, &"wardrobe": 1.0,
	# Idle business for NPCs.
	&"stretch": 2.6, &"cross_arms": 5.0, &"wipe": 3.2, &"pocket_watch": 3.0,
	&"scratch_head": 2.0, &"look_around": 3.4, &"shift_weight": 3.0,
	# Emotes (the emote wheel).
	&"tip_hat": 1.3, &"wave": 1.6, &"point": 1.4, &"shrug": 1.2,
}
## The emote wheel's moves, clockwise from the top, with their names.
const EMOTES: Array[StringName] = [&"tip_hat", &"wave", &"point", &"shrug"]
const EMOTE_NAMES := {&"tip_hat": "Tip hat", &"wave": "Wave", &"point": "Point", &"shrug": "Shrug"}
## The idle moves shopkeepers pick from.
const IDLES: Array[StringName] = [&"stretch", &"cross_arms", &"wipe", &"pocket_watch", &"scratch_head", &"look_around", &"shift_weight"]


## Sounds played during each move: [fraction of the move, sound, volume dB].
const SFX := {
	&"harvest": [[0.52, &"harvest_pull", -2.0]],
	&"plant": [[0.1, &"plant_dig", -4.0]],
	&"pump": [[0.02, &"pump", -2.0]],
	&"salvage": [[0.05, &"salvage", -3.0]],
	&"loot": [[0.05, &"loot_crack", -2.0]],
	&"chest": [[0.2, &"chest_open", -2.0]],
	&"ledger": [[0.08, &"scribble", -6.0]],
	&"buy": [[0.35, &"register", -4.0]],
	&"pickup": [[0.45, &"equip", -2.0]],
	&"hammer": [[0.24, &"hammer_hit", -2.0], [0.74, &"hammer_hit", -2.0]],
	&"zip": [[0.25, &"zip_grab", -4.0]],
	&"slots": [[0.3, &"slot_lever", -2.0]],
	&"cards": [[0.42, &"card_flick", -4.0]],
	&"dice": [[0.0, &"dice", -3.0]],
	&"roulette": [[0.15, &"roulette_spin", -4.0]],
	&"water": [[0.1, &"equip", -10.0]],
	&"tip_hat": [[0.3, &"rustle", -12.0]],
	&"shrug": [[0.2, &"rustle", -14.0]],
}


static func has(id: StringName) -> bool:
	return DUR.has(id)


static func duration(id: StringName) -> float:
	return float(DUR.get(id, 1.0))


## Ease 0..1 between two moments of the move.
static func _seg(t: float, a: float, b: float) -> float:
	return smoothstep(a, b, t)


static func _rot(n: Node3D, r: Vector3, w: float) -> void:
	n.rotation = n.rotation.lerp(r, w)


## Crouch to `depth` (0 stand .. 1 deep squat), both legs; `lean` tips the torso.
static func _crouch(rig: DummyRig, depth: float, lean: float, w: float) -> void:
	for i in 2:
		_rot(rig._thighs[i], Vector3(1.25 * depth, 0, (0.18 if i == 1 else -0.18) * depth), w)
		_rot(rig._shins[i], Vector3(-2.0 * depth, 0, 0), w)
		_rot(rig._ankles[i], Vector3(0.75 * depth, 0, 0), w)
	rig._hips.position.y = lerpf(rig._hips.position.y, 0.95 - 0.4 * depth, w)
	_rot(rig._torso, Vector3(-lean, rig._torso.rotation.y * 0.3, 0), w)


## One knee down, the other up (planting, rummaging close to the ground).
static func _kneel(rig: DummyRig, lean: float, w: float) -> void:
	_rot(rig._thighs[0], Vector3(1.45, 0, -0.1), w)
	_rot(rig._shins[0], Vector3(-1.5, 0, 0), w)
	_rot(rig._ankles[0], Vector3(0.05, 0, 0), w)
	_rot(rig._thighs[1], Vector3(-0.05, 0, 0.08), w)
	_rot(rig._shins[1], Vector3(-1.55, 0, 0), w)
	_rot(rig._ankles[1], Vector3(-0.6, 0, 0), w)
	rig._hips.position.y = lerpf(rig._hips.position.y, 0.6, w)
	_rot(rig._torso, Vector3(-lean, 0, 0), w)


static func _stand(rig: DummyRig, w: float) -> void:
	for i in 2:
		_rot(rig._thighs[i], Vector3(0.02, 0, 0), w * 0.6)
		_rot(rig._shins[i], Vector3(-0.05, 0, 0), w * 0.6)
		_rot(rig._ankles[i], Vector3(0.03, 0, 0), w * 0.6)


static func _arm(rig: DummyRig, i: int, sh: Vector3, el: float, w: float) -> void:
	_rot(rig._shoulders[i], sh, w)
	rig._elbows[i].rotation.x = lerpf(rig._elbows[i].rotation.x, el, w)


static func _head(rig: DummyRig, r: Vector3, w: float) -> void:
	_rot(rig._head, r, w)


static func pose(rig: DummyRig, id: StringName, t: float, w: float) -> void:
	var life := rig._life
	match id:
		&"harvest":
			# Squat, grab the plant with both hands, then a big yank upward.
			var yank := _seg(t, 0.5, 0.68)
			var down := 1.0 - yank * 0.55
			_crouch(rig, 0.85 * down, 0.55 - yank * 0.5, w)
			for i in 2:
				var s := -1.0 if i == 0 else 1.0
				_arm(rig, i, Vector3(0.55 + yank * 1.25, s * 0.25, s * 0.15), 0.25 + yank * 1.4, w)
			_head(rig, Vector3(-0.35 + yank * 0.4, 0, 0), w)
		&"plant":
			# Kneel, poke a hole with two fingers, drop the seed, pat it down.
			_kneel(rig, 0.45, w)
			var poke := absf(sin(t * PI * 3.0)) if t < 0.6 else 0.0
			var pat := absf(sin((t - 0.6) * PI * 5.0)) if t >= 0.6 else 0.0
			_arm(rig, 1, Vector3(0.5 - poke * 0.25 - pat * 0.15, 0.15, 0.08), 0.15 + pat * 0.5, w)
			_arm(rig, 0, Vector3(0.6, 0.1, -0.2), 0.8, w)
			_head(rig, Vector3(-0.45, 0.1, 0), w)
		&"water":
			# Lift the bucket out front and tip it, swaying the pour along the row.
			_stand(rig, w)
			var tip := _seg(t, 0.15, 0.4)
			var sway := sin(t * PI * 2.0) * 0.2 * tip
			_arm(rig, 1, Vector3(0.9 + tip * 0.15, sway, 0.05), 0.2 + tip * 0.15, w)
			_arm(rig, 0, Vector3(0.85 + tip * 0.2, -0.45 + sway, -0.05), 0.45, w)
			_rot(rig._torso, Vector3(-0.22 * tip, sway * 0.5, 0), w)
			_head(rig, Vector3(-0.4, 0, 0), w)
		&"pump":
			# Work the pump handle: two full strokes.
			_crouch(rig, 0.18, 0.3, w)
			var stroke := sin(t * PI * 4.0) * 0.5 + 0.5
			_arm(rig, 1, Vector3(0.45 + stroke * 0.55, -0.15, 0.0), 0.85 - stroke * 0.35, w)
			_arm(rig, 0, Vector3(0.45 + stroke * 0.55, 0.15, 0.0), 0.85 - stroke * 0.35, w)
			_head(rig, Vector3(-0.25 + stroke * 0.1, 0, 0), w)
		&"salvage":
			# Down on a knee, rummaging with both hands, then pull a piece out.
			_kneel(rig, 0.55, w)
			var lift := _seg(t, 0.7, 0.88)
			for i in 2:
				var dig := sin(t * PI * 6.0 + i * PI) * (1.0 - lift)
				_arm(rig, i, Vector3(0.65 + dig * 0.3 + lift * 0.9, (-0.2 if i == 0 else 0.2), 0.0), 0.4 + dig * 0.3 + lift * 0.9, w)
			_head(rig, Vector3(-0.4 + lift * 0.3, 0, 0), w)
		&"loot":
			# Crouch over the carcass and wrench a plate of chitin free.
			var tug := sin(t * PI * 3.0) * (1.0 - _seg(t, 0.75, 0.9))
			var free := _seg(t, 0.72, 0.85)
			_crouch(rig, 0.6, 0.6 - free * 0.3, w)
			_arm(rig, 1, Vector3(0.6 + tug * 0.2 + free * 1.0, 0.1, 0.1), 0.4 + tug * 0.3 + free * 0.8, w)
			_arm(rig, 0, Vector3(0.7, -0.1, -0.15), 0.6, w)
			_head(rig, Vector3(-0.35, 0, 0), w)
		&"slots":
			# Reach up for the lever, haul it down hard, lean in to watch the reels.
			_stand(rig, w)
			var up := _seg(t, 0.0, 0.3)
			var haul := _seg(t, 0.32, 0.48)
			_arm(rig, 1, Vector3(1.4 + up * 1.15 - haul * 1.65, 0.0, 0.35), 0.5 - haul * 0.3, w)
			_arm(rig, 0, Vector3(0.9, -0.3, -0.1), 0.6, w)
			_rot(rig._torso, Vector3(-0.08 - haul * 0.2, -0.1, 0), w)
			_head(rig, Vector3(-0.05 - haul * 0.15, 0.1, 0), w)
		&"cards":
			# Hands low on the felt, a flick of the right wrist to deal or turn a card.
			_stand(rig, w)
			var flick := sin(_seg(t, 0.35, 0.6) * PI)
			_arm(rig, 1, Vector3(0.5 + flick * 0.35, -0.2 - flick * 0.35, 0.0), 1.0 - flick * 0.5, w)
			_arm(rig, 0, Vector3(0.5, 0.25, 0.0), 1.05, w)
			_rot(rig._torso, Vector3(-0.2, 0, 0), w)
			_head(rig, Vector3(-0.35, 0, 0), w)
		&"dice":
			# Shake the dice by the ear, then a long throw down the table.
			_stand(rig, w)
			var shake := sin(life * 38.0) * 0.12 * (1.0 - _seg(t, 0.55, 0.62))
			var throw := _seg(t, 0.58, 0.75)
			_arm(rig, 1, Vector3(lerpf(1.6 + shake, 1.15, throw), lerpf(0.4, -0.1, throw), 0.25), lerpf(1.6 + shake, 0.1, throw), w)
			_arm(rig, 0, Vector3(0.5, 0.2, -0.1), 0.9, w)
			_rot(rig._torso, Vector3(-0.3 * throw, -0.25 + throw * 0.4, 0), w)
			_head(rig, Vector3(-0.15 * throw, 0, 0), w)
		&"roulette":
			# Spin the wheel with a sweep of the arm, then drop the ball in.
			_stand(rig, w)
			var sweep := _seg(t, 0.15, 0.45)
			_arm(rig, 1, Vector3(0.85, 0.6 - sweep * 1.3, 0.1), 0.5, w)
			_arm(rig, 0, Vector3(0.6 + _seg(t, 0.55, 0.75) * 0.3, 0.3, -0.1), 0.7, w)
			_rot(rig._torso, Vector3(-0.15, 0.2 - sweep * 0.4, 0), w)
			_head(rig, Vector3(-0.3, 0, 0), w)
		&"chest":
			# Bend to the chest and heave the lid up with both hands.
			var heave := _seg(t, 0.3, 0.65)
			_crouch(rig, 0.35, 0.5 - heave * 0.3, w)
			for i in 2:
				var s := -1.0 if i == 0 else 1.0
				_arm(rig, i, Vector3(0.75 + heave * 1.1, s * 0.15, 0.0), 0.3 + heave * 0.4, w)
			_head(rig, Vector3(-0.3, 0, 0), w)
		&"ledger":
			# Book held open in the left hand, the right scribbling a line or two.
			_stand(rig, w)
			_arm(rig, 0, Vector3(0.45, -0.45, -0.1), 1.3, w)
			var scr := sin(life * 22.0) * 0.06
			_arm(rig, 1, Vector3(0.5 + scr, 0.35 + sin(life * 9.0) * 0.08, 0.0), 1.3, w)
			_head(rig, Vector3(-0.55, 0, 0), w)
		&"buy":
			# Hold the coin out across the counter, then pocket the goods.
			_stand(rig, w)
			var out := sin(_seg(t, 0.0, 0.85) * PI)
			_arm(rig, 1, Vector3(0.4 + out * 1.0, 0.0, 0.05), 0.9 - out * 0.8, w)
			_rot(rig._torso, Vector3(-0.12 * out, 0, 0), w)
			_head(rig, Vector3(-0.1 - sin(t * PI * 2.0) * 0.12, 0, 0), w)
		&"pickup":
			# Reach and take it off the rack.
			_stand(rig, w)
			var reach := sin(t * PI)
			_arm(rig, 1, Vector3(0.6 + reach * 1.0, 0.0, 0.05), 0.8 - reach * 0.6, w)
			_head(rig, Vector3(-0.1, 0, 0), w)
		&"hammer":
			# Two quick hammer blows.
			_crouch(rig, 0.25, 0.35, w)
			var blow := absf(sin(t * PI * 2.0))
			_arm(rig, 1, Vector3(0.75 + blow * 1.75, 0.0, 0.1), 0.4 + blow * 1.3, w)
			_arm(rig, 0, Vector3(0.75, -0.2, -0.1), 0.6, w)
			_head(rig, Vector3(-0.35, 0, 0), w)
		&"zip":
			# Both hands up to grab the handle.
			for i in 2:
				_arm(rig, i, Vector3(2.9, 0.0, (-0.2 if i == 0 else 0.2)), 0.2, w)
			_head(rig, Vector3(0.2, 0, 0), w)
		&"stretch":
			# Arms up overhead, a lean back, a little shake out.
			var up := sin(t * PI)
			for i in 2:
				var s := -1.0 if i == 0 else 1.0
				_arm(rig, i, Vector3(2.9 * up, 0.0, s * 0.25 * up), 0.3 + 0.5 * (1.0 - up), w)
			_rot(rig._torso, Vector3(0.18 * up, 0, sin(life * 3.0) * 0.04 * up), w)
			_head(rig, Vector3(0.35 * up, 0, 0), w)
		&"cross_arms":
			# Arms folded, weight on one leg, now and then a glance.
			for i in 2:
				var s := -1.0 if i == 0 else 1.0
				_arm(rig, i, Vector3(0.4, s * 0.75, 0.0), 1.75 + (0.1 if i == 1 else 0.0), w)
			rig._hips.position.x = lerpf(rig._hips.position.x, 0.05, w)
			_rot(rig._torso, Vector3(0.04, 0.0, -0.05), w)
			_head(rig, Vector3(-0.05, sin(t * PI * 2.0) * 0.4, 0.06), w)
		&"wipe":
			# Wiping the counter in circles.
			var c := t * PI * 8.0
			_arm(rig, 1, Vector3(0.7 + sin(c) * 0.1, 0.25 + cos(c) * 0.25, 0.0), 0.7 + cos(c) * 0.2, w)
			_arm(rig, 0, Vector3(0.5, -0.3, 0.0), 1.0, w)
			_rot(rig._torso, Vector3(-0.22, cos(c) * 0.06, 0), w)
			_head(rig, Vector3(-0.45, 0, 0), w)
		&"pocket_watch":
			# Fish out the watch, check the time, a slow look up.
			var check := _seg(t, 0.2, 0.35) * (1.0 - _seg(t, 0.8, 0.95))
			_arm(rig, 0, Vector3(0.7 * check + 0.05, -0.35 * check, 0.0), 1.5 * check + 0.2, w)
			_arm(rig, 1, Vector3(0.6 * check + 0.05, 0.45 * check, 0.0), 1.5 * check + 0.2, w)
			_head(rig, Vector3(-0.55 * check + 0.15 * _seg(t, 0.65, 0.8), 0, 0), w)
		&"scratch_head":
			var sc := sin(life * 18.0) * 0.08
			_arm(rig, 1, Vector3(2.55 + sc, 0.25, 0.35), 2.3 - sc, w)
			_head(rig, Vector3(0.05, -0.15, 0.12), w)
		&"look_around":
			# A slow look left, then right, then back.
			_head(rig, Vector3(0.05, sin(t * TAU) * 0.75, 0), w)
			_rot(rig._torso, Vector3(0, sin(t * TAU) * 0.18, 0), w)
		&"shift_weight":
			# Settle onto one hip, hand on the belt.
			var sh := _seg(t, 0.1, 0.4) * (1.0 - _seg(t, 0.75, 1.0))
			rig._hips.position.x = lerpf(rig._hips.position.x, 0.07 * sh, w)
			_rot(rig._torso, Vector3(0, 0, -0.08 * sh), w)
			_arm(rig, 1, Vector3(0.15, 0.0, 0.45 * sh + 0.1), 1.3 * sh + 0.2, w)
		&"wardrobe":
			# Straighten the hat and give the vest a tug.
			_arm(rig, 0, Vector3(2.4, 0.2, -0.35), 2.0, w)
			_arm(rig, 1, Vector3(0.35 + sin(t * PI) * 0.4, 0.25, 0.05), 1.2, w)
			_head(rig, Vector3(-0.1, sin(t * PI * 2.0) * 0.2, 0), w)
		&"tip_hat":
			# Hand up to the brim, a slow nod with the hat tipped, back down.
			_stand(rig, w)
			var up := _seg(t, 0.0, 0.3) * (1.0 - _seg(t, 0.78, 1.0))
			var nod := sin(_seg(t, 0.3, 0.75) * PI)
			_arm(rig, 1, Vector3(2.4 * up + 0.1 + nod * 0.15, -0.2 * up, 0.35 * up), 2.0 * up + 0.2, w)
			_rot(rig._torso, Vector3(-0.12 * nod, 0, 0), w)
			_head(rig, Vector3(-0.35 * nod, 0, 0), w)
		&"wave":
			# Arm up high, a few broad waves overhead.
			_stand(rig, w)
			var up := _seg(t, 0.0, 0.2) * (1.0 - _seg(t, 0.82, 1.0))
			var sway := sin(life * 11.0) * up
			_arm(rig, 1, Vector3(2.6 * up + 0.1, 0.0, (0.45 + sway * 0.35) * up), (0.45 + sway * 0.25) * up + 0.2, w)
			_head(rig, Vector3(0.12 * up, 0, 0.06 * up), w)
		&"point":
			# A straight arm out at whatever you're looking at, held a beat.
			_stand(rig, w)
			var out := _seg(t, 0.0, 0.25) * (1.0 - _seg(t, 0.8, 1.0))
			var jab := sin(_seg(t, 0.25, 0.45) * PI) * 0.12
			_arm(rig, 1, Vector3(1.5 * out + 0.05 + jab, 0.0, 0.05), 0.08, w)
			_rot(rig._torso, Vector3(-0.08 * out, -0.15 * out, 0), w)
			_head(rig, Vector3(0, 0.1 * out, 0), w)
		&"shrug":
			# Palms up, elbows out, head tipped: who knows.
			_stand(rig, w)
			var sh := _seg(t, 0.0, 0.25) * (1.0 - _seg(t, 0.75, 1.0))
			for i in 2:
				var s := -1.0 if i == 0 else 1.0
				_arm(rig, i, Vector3(0.2 * sh, -s * 0.65 * sh, s * 0.1 * sh), 1.25 * sh + 0.15, w)
			_rot(rig._torso, Vector3(0.06 * sh, 0, 0), w)
			_head(rig, Vector3(0.05 * sh, 0, 0.22 * sh), w)
