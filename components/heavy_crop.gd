class_name HeavyCrop
extends RefCounted
## Host: what a universal heavy's hit does, by the crop in it (HeavyRules). The
## same nine effects as the crop-fed turrets (CropEffects' numbers), scaled by
## the gun's upgrade (HeavyRules.CROP_STEPS) instead of a turret's tier:
##   Corn       the shot bounces on to a second bug at 50% damage
##   Chili      a splash round each hit (blast weapons get a second blast instead)
##   Pear       ignores half the bug's armour
##   Cotton     -25% speed for 2 s, stacking to -50%
##   Herbs      poison over 3 s, stacking 3 times
##   Sulfur     a bug it kills goes up (30% of its max HP within 2 m)
##   Cactus     stops it 0.5 s
##   Tumbleweed 15% a hit: rooted 1 s
##   Sarsaparilla marked: +20% damage from everything for 3 s
##
## `ctx` carries the shot: {crop, rarity, source, cliff, chili_r (this gun's
## splash radius for a chili hit), area (true for a blast or shockwave hit, where
## corn and chili act once per blast, not per bug), net (the shooter's PlayerNet,
## for visuals)}.

## Corn's bounce reaches this far for its second bug.
const RICOCHET_RANGE := 6.0


## Share of a bug's armour a shot from `ctx` ignores.
static func armour_ignored(ctx: Dictionary) -> float:
	if StringName(ctx.get("crop", &"")) != &"prickly_pear":
		return 0.0
	return minf(CropEffects.PIERCE_SHARE * HeavyRules.crop_strength(&"prickly_pear", int(ctx.get("rarity", 0))), 0.9)


## One hit of `dmg` on bug `b` at `point` from direction `dir`, then the crop's
## effect. `mult` is the hitbox multiplier (weak spots). Returns where a corn
## ricochet went (Vector3.INF if none) so the caller can draw it.
static func strike(ctx: Dictionary, b: Bug, dmg: float, point: Vector3, dir: Vector3, pierce: bool, mult: float = 1.0) -> Vector3:
	if b == null or not is_instance_valid(b) or not b.is_alive():
		return Vector3.INF
	var crop: StringName = ctx.get("crop", &"")
	var r := int(ctx.get("rarity", 0))
	var k := HeavyRules.crop_strength(crop, r)
	var source := String(ctx.get("source", ""))
	var cliff := int(ctx.get("cliff", -1))
	if crop == &"sulfur_root":
		# Volatile before the hit, so the shot that kills it sets it off.
		b.status.volatile(CropEffects.VOLATILE_TIME, k, source, cliff)
	b.receive_hit(dmg, point, dir, pierce, mult, source, cliff, armour_ignored(ctx))
	return after_hit(ctx, b, dmg, point)


## The crop's effect on `b` after a hit of `dmg` (strike calls this; a blast that
## already dealt its own damage can call it straight).
static func after_hit(ctx: Dictionary, b: Bug, dmg: float, point: Vector3) -> Vector3:
	var crop: StringName = ctx.get("crop", &"")
	var r := int(ctx.get("rarity", 0))
	var k := HeavyRules.crop_strength(crop, r)
	var source := String(ctx.get("source", ""))
	var cliff := int(ctx.get("cliff", -1))
	var area := bool(ctx.get("area", false))
	var out := Vector3.INF
	match crop:
		&"corn":
			if not area or bool(ctx.get("first", false)):
				var other := nearest_other(b, point, RICOCHET_RANGE)
				if other != null:
					other.receive_hit(dmg * CropEffects.RICOCHET_SHARE * k, other.global_position,
							(other.global_position - point).normalized(), false, 1.0, source, cliff)
					out = other.global_position
		&"firecracker_chili":
			if not area:
				var rad := float(ctx.get("chili_r", 1.5)) * k
				for o: Bug in bugs_near(point, rad, b):
					var d := o.global_position.distance_to(point)
					o.receive_hit(dmg * CropEffects.EXPLOSIVE_SHARE * lerpf(1.0, 0.5, d / maxf(rad, 0.01)), o.global_position,
							(o.global_position - point).normalized(), true, 1.0, source + "'s blast", cliff)
		&"cotton":
			if b.is_alive():
				b.status.crop_slow(CropEffects.SLOW_STEP * k, minf(CropEffects.SLOW_MAX * k, 0.8), CropEffects.SLOW_TIME)
				b.crop_tag_once(CropEffects.TAG_THREAD, CropEffects.SLOW_TIME)
		&"herbs":
			if b.is_alive():
				b.status.poison(dmg * CropEffects.POISON_SHARE * k / CropEffects.POISON_TIME, CropEffects.POISON_TIME,
						CropEffects.POISON_STACKS, source, cliff)
				b.crop_tag_once(CropEffects.TAG_POISON, CropEffects.POISON_TIME)
		&"sulfur_root":
			if b.is_alive() and not b.status.is_volatile():
				b.status.volatile(CropEffects.VOLATILE_TIME, k, source, cliff)
		&"barrel_cactus":
			if b.is_alive():
				var s := CropEffects.STAGGER_HEAVY * k
				b.status.stun(s)
				b.crop_tag_once(CropEffects.TAG_STAGGER, s)
		&"tumbleweed_vine":
			if b.is_alive() and randf() < CropEffects.ENTANGLE_CHANCE * k:
				b.status.root(CropEffects.ENTANGLE_TIME)
				b.crop_tag_once(CropEffects.TAG_VINES, CropEffects.ENTANGLE_TIME)
		&"sarsaparilla":
			if b.is_alive():
				b.status.crop_mark(CropEffects.MARK_TIME, CropEffects.MARK_BONUS * k)
				b.crop_tag_once(CropEffects.TAG_MARK, CropEffects.MARK_TIME)
	return out


## Chili in a blast weapon: the second blast's damage share and radius growth.
const CHILI_BLAST_SHARE := 0.35
const CHILI_BLAST_GROW := 1.25


static func chili_blast_radius(radius: float, rarity: int) -> float:
	return radius * CHILI_BLAST_GROW * HeavyRules.crop_strength(&"firecracker_chili", rarity)


## The live, visible bugs within `r` of `at` (not `skip`), anywhere.
static func bugs_near(at: Vector3, r: float, skip: Bug = null) -> Array[Bug]:
	var out: Array[Bug] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for n: Node in tree.get_nodes_in_group("bugs"):
		var o := n as Bug
		if o == null or o == skip or not o.is_alive() or o.is_hidden():
			continue
		if o.global_position.distance_to(at) <= r:
			out.append(o)
	return out


static func nearest_other(b: Bug, at: Vector3, r: float) -> Bug:
	var best: Bug = null
	var best_d := r
	for o: Bug in bugs_near(at, r, b):
		var d := o.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = o
	return best
