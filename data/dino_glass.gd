class_name DinoGlass
extends RefCounted
## The Dino Rifle's magnifying glass is tied on by whoever sold it, and never
## twice the same way. Each one bought rolls one of six fits (equally likely),
## kept in bits 6-8 of the gun's code (WeaponMods), so it travels with the gun
## when it's dropped, stored, saved or picked up.
##
## Fields: name, blurb (shop note), zoom (aimed), lens (centre offset as a
## fraction of the screen's short side), size (lens radius scale), wobble (how
## far the lens swims, same units), cracked, scoped (false = you just look past
## it, iron sights), pos/rot (where the glass sits on the gun, gun space,
## degrees, about its lens).

const SHIFT := 6
const MASK := 7 << SHIFT

const VARIANTS: Array[Dictionary] = [
	{"name": "Dead Centre", "blurb": "Tied on true. A clean 3.5x right down the barrels.",
		"zoom": 3.5, "lens": Vector2.ZERO, "size": 1.0, "wobble": 0.0, "cracked": false, "scoped": true,
		"pos": Vector3.ZERO, "rot": Vector3.ZERO},
	{"name": "Sitting High", "blurb": "The glass rides a thumb's width high. Aim a touch under what you see.",
		"zoom": 3.0, "lens": Vector2(0.0, -0.13), "size": 0.9, "wobble": 0.0, "cracked": false, "scoped": true,
		"pos": Vector3(0.0, 0.016, 0.0), "rot": Vector3(-4.0, 0.0, 0.0)},
	{"name": "Twisted Left", "blurb": "Knotted crooked and off to the left. The cross isn't where the shot goes.",
		"zoom": 2.8, "lens": Vector2(-0.16, 0.04), "size": 0.85, "wobble": 0.0, "cracked": false, "scoped": true,
		"pos": Vector3(-0.016, 0.0, 0.0), "rot": Vector3(0.0, 14.0, -9.0)},
	{"name": "Too Far Back", "blurb": "Lashed right up by your eye. Big, bulging and it never sits still.",
		"zoom": 3.5, "lens": Vector2.ZERO, "size": 1.2, "wobble": 0.035, "cracked": false, "scoped": true,
		"pos": Vector3(0.0, 0.004, 0.12), "rot": Vector3.ZERO},
	{"name": "Cracked Lens", "blurb": "Full 3.5x, through a crack that runs right across it.",
		"zoom": 3.5, "lens": Vector2.ZERO, "size": 1.0, "wobble": 0.0, "cracked": true, "scoped": true,
		"pos": Vector3.ZERO, "rot": Vector3(0.0, 0.0, 6.0)},
	{"name": "Knocked Flat", "blurb": "The glass got knocked flat on the barrels. No zoom: you aim over it.",
		"zoom": 1.15, "lens": Vector2.ZERO, "size": 1.0, "wobble": 0.0, "cracked": false, "scoped": false,
		"pos": Vector3(0.0, -0.05, 0.0), "rot": Vector3(0.0, 0.0, 88.0)},
]


static func of(code: int) -> int:
	return clampi((code & MASK) >> SHIFT, 0, VARIANTS.size() - 1)


static func with_variant(code: int, v: int) -> int:
	return (code & ~MASK) | (clampi(v, 0, VARIANTS.size() - 1) << SHIFT)


static func get_fit(code: int) -> Dictionary:
	return VARIANTS[of(code)]


## A fresh roll for a new gun: every fit equally likely.
static func roll(rng: RandomNumberGenerator = null) -> int:
	return (rng.randi() if rng != null else randi()) % VARIANTS.size()
