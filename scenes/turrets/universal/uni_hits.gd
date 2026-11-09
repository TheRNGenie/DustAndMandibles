class_name UniHits
extends RefCounted
## Host: a universal crop-fed gun's hits, for guns that aren't UniversalTurrets
## (the crewed ones): a bug takes the damage with the crop's armour rule and then
## the crop's effect (CropEffects); splashes and delayed shells do the same for
## every bug they catch. `t` is the gun (for its tier, cliff and owner), `crop`
## what it was loaded with when it fired.


## One bug hit. Returns the corn ricochet's end (Vector3.INF if none).
static func hit(t: Turret, crop: StringName, b: Bug, at: Vector3, dir: Vector3, damage: float, pierce: bool, source: String,
		crop_on: bool = true) -> Vector3:
	if b == null or not is_instance_valid(b) or not b.is_alive():
		return Vector3.INF
	b.note_crop_hit(crop, source) # (the kill tallies)
	b.receive_hit(damage, at, dir, pierce, 1.0, source, t.cliff_id, CropEffects.armour_ignored(crop, t.tier))
	if crop_on and crop != &"":
		return CropEffects.on_hit(crop, t, b, damage, b.global_position, source)
	return Vector3.INF


## A splash of radius `r` at `at` on bugs of one kind: fliers (`flying`), or
## climbers on `cliff`'s wall, or bugs on `cliff`'s ground (`climbing` false).
## Damage falls off to 45% at the rim. Returns how many it caught.
static func splash(t: Turret, crop: StringName, at: Vector3, r: float, damage: float, source: String, cliff: int,
		climbing: bool, flying: bool) -> int:
	var n_hit := 0
	if t == null or not is_instance_valid(t) or t.get_tree() == null:
		return 0
	for n: Node in t.get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden():
			continue
		if flying != (b.state == Bug.State.FLYING):
			continue
		if not flying and (b.cliff_id != cliff or b.is_climbing() != climbing):
			continue
		var d := b.global_position.distance_to(at)
		if d > r:
			continue
		hit(t, crop, b, b.global_position, (b.global_position - at).normalized(), damage * lerpf(1.0, 0.45, d / maxf(r, 0.01)), true,
				source, crop != &"corn" or n_hit == 0)
		n_hit += 1
	return n_hit


## A shell landing `after` seconds from now (the gun may be gone by then).
static func delayed_splash(t: Turret, crop: StringName, after: float, at: Vector3, r: float, damage: float, source: String,
		cliff: int, climbing: bool, flying: bool) -> void:
	var ref: WeakRef = weakref(t)
	t.get_tree().create_timer(after).timeout.connect(func() -> void:
		var gun := ref.get_ref() as Turret
		if gun != null:
			splash(gun, crop, at, r, damage, source, cliff, climbing, flying)
			if Turret.bug_manager != null:
				Turret.bug_manager.crop_burst.rpc(at, r * 0.8, CropEffects.color_of(crop)))
