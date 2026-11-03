class_name TurretEffects
extends RefCounted
## What each turret's shot does when it lands, by TurretDef.effect. Host only.
## Lobbed shots (mortar, dynamite) land after def.flight_time.

## Metres a heavy bug slips down the wall when a Water Cannon hits it.
const HEAVY_SLIP := 3.0

## Bosses only slip a little, and at most once every BOSS_SLIP_GAP seconds, so
## one Water Cannon can't hold a boss on the wall forever (the gap is shared with
## the Steam Cannon and Flood Gate: SpecialShotRules.slip_for).
const BOSS_SLIP := SpecialShotRules.BOSS_SLIP
const BOSS_SLIP_GAP := SpecialShotRules.BOSS_SLIP_GAP


static func _slip_for(target: Bug) -> float:
	return SpecialShotRules.slip_for(target, HEAVY_SLIP)


static func apply(t: Turret, target: Bug, aim: Vector3, damage: float) -> void:
	var source := "%s's %s" % [t.owner_name, t.def.display_name]
	var dir := (aim - t.muzzle_position()).normalized()
	if t is AmberTurret: # Hive amber: the Amber Kiln's molten lob (the bell and lance never come here)
		(t as AmberTurret).amber_shot(target, aim, damage)
		return
	match t.def.special:
		&"steam":
			_steam(t, target, aim, source)
			return
		&"flood":
			_flood(t, target, source)
			return
		&"twin":
			_twin(t, target, aim, damage, source)
			return
		&"bola":
			_bola(t, target, aim, dir, source)
			return
		TurretDef.SPECIAL_CHAIN, TurretDef.SPECIAL_PIERCE, TurretDef.SPECIAL_SPIKE: # Tiers: ricochet, pierce and rail spike
			_special(t, target, aim, dir, damage, source)
			return
	match t.def.effect:
		TurretDef.Effect.HITSCAN:
			target.receive_hit(damage, aim, dir, t.def.armor_pierce, 1.0, source, t.cliff_id)
		TurretDef.Effect.KNOCKBACK:
			target.receive_hit(damage, aim, dir, false, 1.0, source, t.cliff_id)
			BossFx.on_water(t, target) # Boss: the spray washes Acid Matriarch acid off nearby turrets
			if not target.is_alive():
				pass
			elif TurretDef.is_heavy(target.def):
				# Heavy bugs only slip a few metres down the wall.
				if target.is_climbing():
					target.climb_y = maxf(target.climb_y - _slip_for(target), 0.0)
			else:
				target.knock_off(source, t.cliff_id)
		TurretDef.Effect.PIN:
			target.receive_hit(damage, aim, dir, false, 1.0, source, t.cliff_id)
			target.status.root(t.def.effect_size)
			if t.def.anti_air:
				target.show_net.rpc(t.def.effect_size)
		TurretDef.Effect.SPLASH when t.def.anti_air:
			# Air bursts: after the shell's flight, everything flying in the cloud is hit.
			var bugs_ref: WeakRef = weakref(Turret.bug_manager) # weak: the world can be freed mid-flight
			var radius := t.def.effect_size * t.range_multiplier()
			var owner_cliff := t.cliff_id
			var tree := t.get_tree()
			var lead := aim + target.velocity_hint() * t.def.flight_time
			tree.create_timer(t.def.flight_time).timeout.connect(func() -> void:
				var bugs := bugs_ref.get_ref() as BugManager
				if bugs == null:
					return
				for n: Node in tree.get_nodes_in_group("bugs"):
					var b := n as Bug
					if b == null or not b.is_alive() or b.state != Bug.State.FLYING:
						continue
					var d := b.global_position.distance_to(lead)
					if d <= radius:
						b.receive_hit(damage * lerpf(1.0, 0.5, d / radius), lead, (b.global_position - lead).normalized(), true, 1.0, source, owner_cliff)
				bugs._explode.rpc(lead, radius))
		TurretDef.Effect.SPLASH when t.def.guards_plateau:
			# Plateau / house guards: burst over the bugs on your own ground.
			var radius := t.def.effect_size * t.range_multiplier()
			for n: Node in t.get_tree().get_nodes_in_group("bugs"):
				var b := n as Bug
				if b == null or not b.is_alive() or b.cliff_id != target.cliff_id or b.is_climbing():
					continue
				var d := b.global_position.distance_to(aim)
				if d <= radius:
					b.receive_hit(damage * lerpf(1.0, 0.4, d / radius), aim, (b.global_position - aim).normalized(), true, 1.0, source, t.cliff_id)
			Turret.bug_manager._explode.rpc(aim, radius)
		TurretDef.Effect.BURN, TurretDef.Effect.SPLASH:
			# Capture plain values: the turret may be destroyed while the shot is in the air.
			var bugs_ref: WeakRef = weakref(Turret.bug_manager) # weak: the world can be freed mid-flight
			var cliff := target.cliff_id
			var radius := t.def.effect_size * t.range_multiplier()
			var splash := t.def.effect == TurretDef.Effect.SPLASH
			var owner_cliff := t.cliff_id
			if GameState.weather == Weather.Kind.WINDY:
				# Lobbed shots drift with the wind.
				aim += Vector3(0, 0, WeatherFx.wind_sign() * randf_range(1.0, 3.0))
			t.get_tree().create_timer(t.def.flight_time).timeout.connect(func() -> void:
				var bugs := bugs_ref.get_ref() as BugManager
				if bugs == null:
					return
				if splash:
					bugs.splash(cliff, aim, radius, damage, source, owner_cliff)
				else:
					bugs.add_fire(cliff, aim, radius, damage, 5.0, source, owner_cliff))


# ------------------------------------------------------------------ tiers: specials

## Bugs a ricochet, a pierce or a spike can also hit (alive, seen, targetable).
static func _others(t: Turret) -> Array[Bug]:
	var out: Array[Bug] = []
	if Turret.bug_manager == null:
		return out
	for n: Node in Turret.bug_manager.get_children():
		var b := n as Bug
		if b != null and b.is_alive() and not b.is_hidden() and not b.untargetable():
			out.append(b)
	return out


## One extra hit at a fraction of the turret's shot, scaled for heavy bugs.
static func _hit(t: Turret, b: Bug, frac: float, dir: Vector3, source: String) -> void:
	b.receive_hit(t.def.damage_at(t.tier, TurretDef.is_heavy(b.def)) * frac, b.global_position, dir, t.def.armor_pierce, 1.0, source, t.cliff_id)


## Debug (--tiertest): per special, hits landed and extra bugs reached by them.
static var special_stats: Dictionary = {}


static func _tally(kind: StringName, extra: int) -> void:
	special_stats[kind] = int(special_stats.get(kind, 0)) + 1
	var key := StringName("%s_extra" % kind)
	special_stats[key] = int(special_stats.get(key, 0)) + extra


static func _special(t: Turret, target: Bug, aim: Vector3, dir: Vector3, damage: float, source: String) -> void:
	var d := t.def
	target.receive_hit(damage, aim, dir, d.armor_pierce, 1.0, source, t.cliff_id)
	var others := _others(t)
	others.erase(target)
	match d.special:
		TurretDef.SPECIAL_CHAIN:
			var pts := PackedVector3Array([aim])
			var hops := TierRules.chain_path(target.global_position, _positions(others), d.special_count, d.special_radius)
			for i in hops.size():
				var b := others[hops[i]]
				_hit(t, b, pow(d.special_falloff, i + 1), (b.global_position - pts[pts.size() - 1]).normalized(), source)
				pts.append(b.global_position)
			_tally(d.special, hops.size())
			if pts.size() > 1:
				t.special_fx.rpc(d.special, pts, 0.0)
		TurretDef.SPECIAL_PIERCE:
			var line := TierRules.pierce_line(t.muzzle_position(), aim, _positions(others), d.special_count, d.special_radius)
			for i in line.size():
				_hit(t, others[line[i]], pow(d.special_falloff, i + 1), dir, source)
			_tally(d.special, line.size())
			if not line.is_empty():
				t.special_fx.rpc(d.special, PackedVector3Array([aim, others[line[line.size() - 1]].global_position]), 0.0)
		TurretDef.SPECIAL_SPIKE:
			var wall := target.global_basis.y if target.is_climbing() else -dir
			var climbers: Array[Bug] = []
			for b in others:
				if b.is_climbing() and b.cliff_id == target.cliff_id:
					climbers.append(b)
			var line := TierRules.spike_line(aim, dir, wall, _positions(climbers), d.special_radius)
			for i in line.size():
				_hit(t, climbers[line[i]], pow(d.special_falloff, i + 1), dir, source)
			_tally(d.special, line.size())
			# The spike ends in the last bug it went through and nails it to the rock.
			var last: Bug = climbers[line[line.size() - 1]] if not line.is_empty() else target
			if last.is_alive():
				last.status.root(d.special_pin)
			t.special_fx.rpc(d.special, PackedVector3Array([aim, last.global_position]), d.special_pin)


static func _positions(bugs: Array[Bug]) -> PackedVector3Array:
	var out := PackedVector3Array()
	for b in bugs:
		out.append(b.global_position)
	return out


# ------------------------------------------------------------------ special shots
# Who they catch and what they do: SpecialShotRules. What they look like: SpecialShotFx.

static func _steam(t: Turret, target: Bug, aim: Vector3, source: String) -> void:
	var muzzle := t.muzzle_position()
	var axis := (aim - muzzle).normalized()
	var reach := t.def.range * t.range_multiplier() + 4.0
	var caught: Array = [target]
	for b in Turret.bug_manager.climbers_on(target.cliff_id):
		if b != target and not b.untargetable() and SpecialShotRules.in_cone(muzzle, axis, b.global_position, SpecialShotRules.STEAM_HALF_ANGLE_DEG, reach):
			caught.append(b)
	BossFx.on_water(t, target) # steam is water too: it washes acid off nearby turrets
	for b: Bug in caught:
		var dmg := t.def.damage_at(t.tier, TurretDef.is_heavy(b.def))
		b.receive_hit(dmg, b.global_position, (b.global_position - muzzle).normalized(), false, 1.0, source, t.cliff_id)
	SpecialShotRules.steam_wash(caught, t.def.special_count, source, t.cliff_id)


static func _flood(t: Turret, target: Bug, source: String) -> void:
	var cliff := target.cliff_id
	var centre := target.lane_z
	var half := t.def.effect_size * 0.5
	var owner_cliff := t.cliff_id
	var dmg := t.def.damage_at(t.tier)
	var bugs_ref: WeakRef = weakref(Turret.bug_manager)
	var tree := t.get_tree()
	BossFx.on_water(t, target)
	# The water reaches the far lip, then runs down the band: each bug is washed
	# as the sheet's front passes it.
	tree.create_timer(SpecialShotRules.FLOOD_ARRIVE).timeout.connect(func() -> void:
		var bugs := bugs_ref.get_ref() as BugManager
		if bugs == null:
			return
		for b: Bug in SpecialShotRules.flood_band(bugs.climbers_on(cliff), centre, half):
			var wait := maxf(WorldLayout.CLIFF_HEIGHT - b.climb_y, 0.0) / SpecialShotRules.FLOOD_SPEED
			var bref: WeakRef = weakref(b)
			tree.create_timer(maxf(wait, 0.01)).timeout.connect(func() -> void:
				var bb := bref.get_ref() as Bug
				if bb != null and bb.is_alive():
					bb.receive_hit(dmg, bb.global_position, Vector3.DOWN, false, 1.0, source, owner_cliff)
					SpecialShotRules.flood_wash([bb], source, owner_cliff)))


static func _twin(t: Turret, target: Bug, aim: Vector3, damage: float, source: String) -> void:
	var bugs_ref: WeakRef = weakref(Turret.bug_manager)
	var cliff := target.cliff_id
	var radius := t.def.effect_size * t.range_multiplier()
	var owner_cliff := t.cliff_id
	var dps := SpecialShotRules.TWIN_FIRE_DPS * t.def.damage_at(t.tier) / maxf(t.def.damage, 0.001)
	if GameState.weather == Weather.Kind.WINDY:
		aim += Vector3(0, 0, WeatherFx.wind_sign() * randf_range(1.0, 3.0))
	var fire_at := SpecialShotRules.twin_fire_point(aim)
	t.get_tree().create_timer(t.def.flight_time).timeout.connect(func() -> void:
		var bugs := bugs_ref.get_ref() as BugManager
		if bugs == null:
			return
		bugs.splash(cliff, aim, radius, damage, source, owner_cliff)
		bugs.add_fire(cliff, fire_at, radius, dps, SpecialShotRules.TWIN_FIRE_TIME, source + SpecialShotRules.FIRE_SHELL, owner_cliff))


static func _bola(t: Turret, target: Bug, aim: Vector3, dir: Vector3, source: String) -> void:
	var caught := SpecialShotRules.bola_pick(target, Turret.bug_manager.climbers_on(target.cliff_id), t.def.special_count)
	var refs: Array = caught.map(func(b: Bug) -> WeakRef: return weakref(b))
	var dmg := t.def.damage_at(t.tier)
	var secs := t.def.effect_size
	var owner_cliff := t.cliff_id
	t.get_tree().create_timer(maxf(t.def.flight_time, 0.01)).timeout.connect(func() -> void:
		for r: WeakRef in refs:
			var b := r.get_ref() as Bug
			if b == null or not b.is_alive():
				continue
			b.receive_hit(dmg, aim, dir, false, 1.0, source, owner_cliff)
			var hold := SpecialShotRules.bola_time(b, secs)
			if hold > 0.0 and b.is_alive():
				b.status.root(hold)
				b.show_bola.rpc(hold))


## Colour of the shot's streak or lob.
static func shot_color(def: TurretDef) -> Color:
	match def.effect:
		TurretDef.Effect.KNOCKBACK:
			return Palette.SKY_TOP.lightened(0.3)
		TurretDef.Effect.BURN:
			return Palette.TEAM_WEST
		TurretDef.Effect.SPLASH:
			return Palette.WOOD
		TurretDef.Effect.PIN:
			return Palette.BONE.darkened(0.2)
	return Palette.GLOW_YELLOW
