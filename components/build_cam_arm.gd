class_name BuildCamArm
extends RefCounted
## The spring-arm maths behind build mode's third-person camera (BuildCamera),
## kept pure so it can be unit-tested: where the arm points, how long it is, and
## how it snaps in when rock or a wall is in the way and eases back out.

## Arm offset from the eye: back, up, and a little to the right (over the shoulder).
const BACK := 3.4
const UP := 1.9
const SIDE := 0.55
## Never closer to the eye than this (inside your own hat otherwise).
const MIN_ARM := 0.6
## How fast the arm grows back out once nothing's in the way (m/s); it shrinks at once.
const EASE_OUT := 6.0


## Full arm length (what the camera keeps when nothing's in the way), about 4 m.
static func full_arm() -> float:
	return Vector3(SIDE, UP, BACK).length()


## The length to use this frame, given the full length, the free fraction a
## probe found (1 = clear) and the length last frame (0 = just switched on).
static func arm_length(full: float, free_fraction: float, current: float, delta: float) -> float:
	var allowed := maxf(full * clampf(free_fraction, 0.0, 1.0), MIN_ARM)
	if current <= 0.0 or allowed <= current:
		return allowed
	return minf(current + EASE_OUT * delta, allowed)


## The arm's direction from the eye for a flat forward direction (unit vector).
static func arm_dir(flat_fwd: Vector3) -> Vector3:
	var right := flat_fwd.cross(Vector3.UP).normalized()
	return (-flat_fwd * BACK + Vector3.UP * UP + right * SIDE).normalized()
