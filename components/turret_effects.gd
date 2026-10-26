class_name TurretEffects
extends RefCounted
## What each turret's shot does when it lands, by TurretDef.effect. Host only.
## Lobbed shots (mortar, dynamite) land after def.flight_time.

static func apply(t: Turret, target: Bug, aim: Vector3, damage: float) -> void:
	var source := "%s's %s" % [t.owner_name, t.def.display_name]
	var dir := (aim - t.muzzle_position()).normalized()
	match t.def.effect:
		TurretDef.Effect.HITSCAN:
			target.receive_hit(damage, aim, dir, t.def.armor_pierce, 1.0, source, t.cliff_id)
		TurretDef.Effect.KNOCKBACK:
			target.receive_hit(damage, aim, dir, false, 1.0, source, t.cliff_id)
			if target.is_alive():
				target.knock_off(source, t.cliff_id)
		TurretDef.Effect.PIN:
			target.receive_hit(damage, aim, dir, false, 1.0, source, t.cliff_id)
			target.status.root(t.def.effect_size)
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
