extends Node
## Rock chips off the cliff face where big bugs climb: every metre or two a
## Rattler, Brood Mother or boss hauls itself up, a few stones break off under
## its claws and tumble down the wall; a bigger slab and a puff of dust where it
## heaves over the lip. Every peer draws it from the bugs it already has (the
## climb height replicates), so there's nothing to send. Only big bugs are
## watched (BugManager registers them), a few times a second, and the bursts
## come from VfxPool's small pools, so a 750-bug wave costs next to nothing.

const SCAN := 0.15
## Metres climbed between chip bursts: tanks and brood mothers, bosses.
const STEP_BIG := 1.8
const STEP_BOSS := 1.1
## Bursts per scan at most (a crowd of tanks can't flood the pool).
const PER_SCAN := 3

var vfx: Node3D

var _scan := 0.0
## [bug, last climb height, last state]
var _big: Array = []


## BugManager: a big bug came into the world.
func watch(bug: Node3D) -> void:
	_big.append([bug, float(bug.get("climb_y")), int(bug.get("state"))])


func _process(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0 or _big.is_empty():
		return
	_scan = SCAN
	var budget := PER_SCAN
	var i := _big.size() - 1
	while i >= 0:
		var e: Array = _big[i]
		var ref: Variant = e[0]
		if not is_instance_valid(ref) or not (ref as Node).is_inside_tree():
			_big.remove_at(i)
			i -= 1
			continue
		var bug := ref as Bug
		var y := bug.climb_y
		var st := bug.state
		if st == Bug.State.CLIMBING and budget > 0:
			var boss := bug.def != null and bug.def.behavior == BugDef.Behavior.BOSS
			var step := STEP_BOSS if boss else STEP_BIG
			if y - float(e[1]) >= step:
				e[1] = y
				budget -= 1
				_chip(bug, (1.3 if boss else 0.8) * clampf(bug.def.size, 0.8, 2.0))
			elif y < float(e[1]):
				e[1] = y # knocked off / re-climbing
		elif int(e[2]) == Bug.State.CLIMBING and st == Bug.State.CRESTING and budget > 0:
			# Heaving over the lip: a slab breaks away.
			budget -= 1
			_chip(bug, 1.8 * clampf(bug.def.size, 0.8, 2.0))
		e[2] = st
		i -= 1


func _chip(bug: Bug, size: float) -> void:
	if vfx == null or not bug.is_visible_in_tree():
		return
	var out := bug.global_basis.y.normalized()
	# From the rock under its belly, a little to one side.
	var at := bug.global_position - out * 0.4 + bug.global_basis.x * randf_range(-0.6, 0.6)
	vfx.call("rock_chips", at, out, size)
