class_name TurretEffects
extends RefCounted
## What each turret's shot does when it lands, by TurretDef.effect. Host only.
## Lobbed shots (mortar, dynamite) land after def.flight_time.

## Metres a heavy bug slips down the wall when a Water Cannon hits it.
const HEAVY_SLIP := 3.0

## Bosses only slip a little, and at most once every BOSS_SLIP_GAP seconds, so
## one Water Cannon can't hold a boss on the wall forever.
const BOSS_SLIP := 1.0
const BOSS_SLIP_GAP := 6.0


static func _slip_for(target: Bug) -> float:
	if target.boss == null:
		return HEAVY_SLIP
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(target.get_meta(&"water_slip_t", -100.0)) < BOSS_SLIP_GAP:
		return 0.0
	target.set_meta(&"water_slip_t", now)
	return BOSS_SLIP


static func apply(t: Turret, target: Bug, aim: Vector3, damage: float) -> void:
	var source := "%s's %s" % [t.owner_name, t.def.display_name]
	var dir := (aim - t.muzzle_position()).normalized()
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
			var bugs := Turret.bug_manager
			var radius := t.def.effect_size * t.range_multiplier()
			var owner_cliff := t.cliff_id
			var tree := t.get_tree()
			var lead := aim + target.velocity_hint() * t.def.flight_time
			tree.create_timer(t.def.flight_time).timeout.connect(func() -> void:
				if not is_instance_valid(bugs):
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
			var bugs := Turret.bug_manager
			var cliff := target.cliff_id
			var radius := t.def.effect_size * t.range_multiplier()
			var splash := t.def.effect == TurretDef.Effect.SPLASH
			var owner_cliff := t.cliff_id
			if GameState.weather == Weather.Kind.WINDY:
				# Lobbed shots drift with the wind.
				aim += Vector3(0, 0, WeatherFx.wind_sign() * randf_range(1.0, 3.0))
			t.get_tree().create_timer(t.def.flight_time).timeout.connect(func() -> void:
				if not is_instance_valid(bugs):
					return
				if splash:
					bugs.splash(cliff, aim, radius, damage, source, owner_cliff)
				else:
					bugs.add_fire(cliff, aim, radius, damage, 5.0, source, owner_cliff))


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
