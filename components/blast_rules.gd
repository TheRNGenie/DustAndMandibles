class_name BlastRules
extends RefCounted
## Story chapter 7, Down the Hole: the rules of the dynamite job in one place,
## no nodes or networking, so they can be unit-tested. DownTheHole (the set
## piece) and CliffBuilder (which tunnel is the main one) ask here.
##
## The job: carry dynamite crates (heavy, in the backpack) from the pile at the
## rope foot into the main tunnel, set a charge at every marked spot, light the
## fuse at the mouth and get above the lip before it blows.

## Units of dynamite in one crate's backpack weight (Backpack.WEIGHTS): two
## crates fill a pack.
const ITEM := &"dynamite"
## How far the tunnel set is built under the mouth (the player steps through a
## fade; bugs in it walk its floor, see Bug.UNDERGROUND_Y).
const SET_DROP := 160.0
## Seconds of fuse.
const FUSE := 45.0
## Within this of the mouth (on the floor) the blast downs you; inside the
## tunnel it always does. Further out on the floor it still knocks you about.
const KILL_RADIUS := 26.0
const HURT_RADIUS := 70.0
const HURT_DAMAGE := 30.0
## Hunters: seconds between packs at the mouth (fewer charges set = slower),
## and most alive at once.
const HUNT_GAP_START := 16.0
const HUNT_GAP_MIN := 6.0
const HUNT_GAP_PER_CHARGE := 2.0
const HUNT_GAP_LIT := 5.0
const MAX_HUNTERS_BASE := 4
const MAX_HUNTERS_PER_RIDER := 2
const HUNTERS: Array[StringName] = [&"wolf_spider", &"dust_mite", &"dust_mite", &"wolf_spider", &"rattler_beetle"]


## Charges (and crates) the job needs for `riders` players: a crate a rider
## plus two, so a solo run carries three and a posse of four carries six.
static func crates_needed(riders: int, base: int = 2, per_rider: int = 1) -> int:
	return maxi(base + per_rider * clampi(riders, 1, 4), 1)


## Crates still on the pile: what's needed less what's set, carried or dropped.
static func on_pile(needed: int, set_count: int, carried: int, dropped: int) -> int:
	return maxi(needed - set_count - carried - dropped, 0)


## Seconds between hunter packs.
static func hunt_gap(charges_set: int, lit: bool) -> float:
	if lit:
		return HUNT_GAP_LIT
	return maxf(HUNT_GAP_START - HUNT_GAP_PER_CHARGE * float(charges_set), HUNT_GAP_MIN)


## How many come out in one pack (1 for one rider down, up to 3).
static func hunt_pack(riders_down: int, lit: bool) -> int:
	return clampi(1 + riders_down / 2 + (1 if lit else 0), 1, 3)


static func max_hunters(riders: int) -> int:
	return MAX_HUNTERS_BASE + MAX_HUNTERS_PER_RIDER * clampi(riders, 1, 4)


## Damage the blast does to someone down in the canyon `dist` metres from the
## mouth (`inside` the tunnel: always fatal). 0 = untouched.
static func blast_damage(dist: float, inside: bool) -> float:
	if inside or dist <= KILL_RADIUS:
		return 99999.0
	if dist <= HURT_RADIUS:
		return HURT_DAMAGE
	return 0.0


## Screen shake for a player `dist` metres from the blast (everyone feels it).
static func blast_shake(dist: float) -> float:
	return clampf(1.0 - dist / 160.0, 0.35, 1.0)


## Where the charge spots go along a tunnel `length` metres deep: spread from
## `first` metres in to the end, alternating walls. [[metres in, side -1/+1], ...]
static func charge_spots(count: int, first: float, length: float) -> Array:
	var out: Array = []
	for i in count:
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		out.append([lerpf(first, length, t), -1.0 if i % 2 == 0 else 1.0])
	return out


## The main tunnel: the mouth nearest any rope foot (the walk with the dynamite).
static func pick_main(mouths: Array[Vector3], feet: Array[Vector3]) -> int:
	var best := 0
	var best_d := INF
	for i in mouths.size():
		for f in feet:
			var d := Vector2(mouths[i].x - f.x, mouths[i].z - f.z).length()
			if d < best_d:
				best_d = d
				best = i
	return best


## "0:23" for the fuse.
static func fuse_text(secs: float) -> String:
	var s := maxi(ceili(secs), 0)
	return "%d:%02d" % [s / 60, s % 60]
