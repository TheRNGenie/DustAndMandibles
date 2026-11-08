class_name UniversalObstruction
extends UniversalTurret
## A universal crop-fed obstruction (the handoff's CF Obstructions): placed on
## the ground, inert until you load it with a sack of any crop (E / Q, once), and
## then it waits for bugs that make it onto your ground. One use: it isn't
## repaired or reloaded, and its sack isn't spent at the wave's end (it lasts
## until it goes off). Every kind applies the loaded crop to what it catches.
##   Crop Mine      the first bug on it sets it off: a blast round it
##   Stake Pit      the first bug in takes the spikes, then they break
##   Tangle Line    the first bug across the wire is wrapped and rooted
##   Crop Palisade  blocks the way; bugs touching it get the crop; chewed through
##                  (a sulfur-loaded one goes up when it falls)
##   Scatter Patch  slows and crops whatever walks through, until trampled flat

## Replicated: it has gone off (the trigger animation plays, then it's gone).
var gone_off := false
## Scatter Patch: tramples left.
var charges := 0
var _arm_t := 0.0
var _gone_t := 0.0
var _tick := 0.0

## How long after going off it's removed (the trigger animation plays first).
const GONE_AFTER := 0.9
## A mine's fuse after the plate clicks down.
const FUSE := 0.1


func setup(d: TurretDef, cid: int, c: Vector2i, pos: Vector3, owner_label: String, stack_level: int = 0) -> void:
	super.setup(d, cid, c, pos, owner_label, stack_level)
	charges = d.special_count
	# Low collision (players walk over it; the interact ray still finds it). The
	# palisade is a wall.
	for ch in get_children():
		if ch is CollisionShape3D:
			var shape := BoxShape3D.new()
			if d.special == &"palisade":
				shape.size = Vector3(1.9, 1.3, 0.45)
				(ch as CollisionShape3D).position = Vector3(0, 0.65, 0)
			else:
				shape.size = Vector3(1.2, 0.3, 1.2)
				(ch as CollisionShape3D).position = Vector3(0, 0.15, 0)
			(ch as CollisionShape3D).shape = shape
			break
	ctx.placed_age = 0.0


func _make_synchronizer() -> MultiplayerSynchronizer:
	var sync := super._make_synchronizer()
	for p: String in [".:gone_off", ".:charges"]:
		var path := NodePath(p)
		sync.replication_config.add_property(path)
		sync.replication_config.property_set_spawn(path, true)
		sync.replication_config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	return sync


# ------------------------------------------------------------------ host

func _think(delta: float) -> void:
	if gone_off:
		_gone_t += delta
		if _gone_t >= GONE_AFTER and health.hp > 0.0:
			health.take_damage(health.hp + 1.0, "spent", -1) # gone: the normal removal
		return
	if not can_fire() or BossFx.holds_fire(self):
		return
	_arm_t += delta
	if _arm_t < 0.4:
		return
	match def.special:
		&"palisade":
			_tick -= delta
			if _tick <= 0.0:
				_tick = 1.0
				for b: Bug in _plateau_bugs(def.special_radius):
					_hit(b, b.global_position, Vector3.UP, def.damage_at(tier), true, _source())
		&"patch":
			_tick -= delta
			if _tick <= 0.0:
				_tick = def.fire_interval
				for b: Bug in _plateau_bugs(def.effect_size * (1.0 + 0.15 * tier)):
					b.status.slow(0.65, 1.2)
					_hit(b, b.global_position, Vector3.UP, def.damage_at(tier), true, _source())
					charges -= 1
					shots += 1
				if charges <= 0:
					gone_off = true
		_:
			var got := _first_in()
			if got != null:
				_trigger(got)


## Bugs on this cliff's ground within `r` (not climbing, not flying).
func _plateau_bugs(r: float) -> Array[Bug]:
	var out: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden() or b.is_climbing() or b.state == Bug.State.FLYING:
			continue
		if b.cliff_id != cliff_id:
			continue
		var flat := Vector2(b.global_position.x - global_position.x, b.global_position.z - global_position.z)
		if flat.length() <= r + float(b.spec.get("body_radius", 0.4)):
			out.append(b)
	return out


## The first bug to step on it (mine, stake pit) or across its wire (tangle line).
func _first_in() -> Bug:
	if def.id == &"cf_tangle_line":
		var a := global_transform * Vector3(-1.0, 0, 0)
		var b2 := global_transform * Vector3(1.0, 0, 0)
		for b: Bug in _plateau_bugs(1.6):
			var p := Geometry3D.get_closest_point_to_segment(b.global_position, a, b2)
			if Vector2(p.x - b.global_position.x, p.z - b.global_position.z).length() <= def.special_radius:
				return b
		return null
	var list := _plateau_bugs(def.special_radius)
	return list[0] if not list.is_empty() else null


func _source() -> String:
	return "%s's %s" % [owner_name, def.display_name]


func _trigger(b: Bug) -> void:
	gone_off = true
	shots += 1
	var src := _source()
	match def.id:
		&"cf_crop_mine":
			var me: WeakRef = weakref(self)
			var at := global_position + Vector3.UP * 0.2
			var tgt := b
			get_tree().create_timer(FUSE).timeout.connect(func() -> void:
				var t := me.get_ref() as UniversalObstruction
				if t != null:
					t._blast(tgt, at, src))
		&"cf_stake_pit":
			_hit(b, b.global_position, Vector3.UP, def.damage_at(tier, TurretDef.is_heavy(b.def)), true, src)
		&"cf_tangle_line":
			_hit(b, b.global_position, Vector3.UP, def.damage_at(tier), false, src)
			if b.is_alive():
				var s := def.effect_size * CropEffects.strength(tier)
				b.status.root(s)
				b.crop_tag_once(CropEffects.TAG_VINES, s)


## Host: the mine goes up: every bug on this ground within its radius.
func _blast(target: Bug, at: Vector3, src: String) -> void:
	var r := def.effect_size * (1.0 + 0.1 * tier)
	for b: Bug in _plateau_bugs(r):
		var d := b.global_position.distance_to(at)
		_hit(b, b.global_position, (b.global_position - at).normalized(), def.damage_at(tier) * lerpf(1.0, 0.45, d / r), true, src,
				b == target or crop != &"corn")
	if Turret.bug_manager != null:
		Turret.bug_manager.crop_burst.rpc(at, r, CropEffects.color_of(crop))


## Host: the palisade (or anything) falling. A sulfur-loaded one goes up.
func _on_destroyed(source: String, source_cliff: int) -> void:
	if multiplayer.is_server() and def.special == &"palisade" and crop == &"sulfur_root" and not gone_off:
		var r := 2.5
		for b: Bug in _plateau_bugs(r):
			_hit(b, b.global_position, Vector3.UP, 60.0 * CropEffects.strength(tier), true, _source())
		if Turret.bug_manager != null:
			Turret.bug_manager.crop_burst.rpc(global_position + Vector3.UP * 0.5, r, CropEffects.color_of(crop))
	super._on_destroyed(source, source_cliff)


## Obstructions keep their sack through the wave's end.
func _on_phase_changed(p: GameState.Phase) -> void:
	_in_wave = p == GameState.Phase.WAVE


func needs_repair() -> bool:
	return false


func upgrade_cost() -> int:
	return -1


# ------------------------------------------------------------------ every peer

func _aim_visual(delta: float) -> void:
	ctx.placed_age += delta
	if gone_off and not ctx.triggered:
		ctx.triggered = true
		ctx.trigger_age = 0.0
		_on_gone_off_fx()
	if ctx.triggered:
		ctx.trigger_age += delta
	if def.special == &"patch":
		ctx.hp_frac = clampf(float(charges) / maxf(float(def.special_count), 1.0), 0.0, 1.0)
	super._aim_visual(delta)
	if def.special != &"patch":
		ctx.hp_frac = health.fraction()


func _draw_shot() -> void:
	ctx.shots = shots
	ctx.shot_age = 0.0


## Every peer: the moment it goes off (the anim does the rest).
func _on_gone_off_fx() -> void:
	var col := CropEffects.color_of(crop)
	if vfx == null:
		return
	match def.id:
		&"cf_stake_pit":
			vfx.splinters(global_position + Vector3.UP * 0.3, 1.0)
			vfx.pop(global_position + Vector3.UP * 0.4, col, 0.8)
			Audio.play_at(&"armor_ping", global_position)
		&"cf_tangle_line":
			vfx.dust_burst(global_position, Vector3.UP, 0.6)
			Audio.play_at(&"throw", global_position)
		&"cf_scatter_patch":
			vfx.dust_burst(global_position, Vector3.UP, 0.8)
		&"cf_crop_mine":
			vfx.dust_burst(global_position, Vector3.UP, 1.4)
