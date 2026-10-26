class_name Gun
extends Node3D
## The local player's weapons: revolver (always owned), lever-action rifle and coach
## shotgun (bought with chitin at the gun shop), each with up to 2 upgrade levels.
## Hitscan: the shooter predicts hits, the host re-casts the same rays and applies
## damage (PlayerNet). Shotgun pellets use a shared seed so both sides agree.

signal fired(origin: Vector3, direction: Vector3)
signal ammo_changed(current: int, max_ammo: int)
signal reload_started(duration: float)
## Your own shot hit a bug (weak = the glowing weak spot). For hit markers.
signal hit_confirmed(weak: bool)
## The equipped weapon or the owned set changed (for the hotbar).
signal loadout_changed

const WEAPONS: Dictionary = {
	&"revolver": preload("res://data/weapons/revolver.tres"),
	&"lever_rifle": preload("res://data/weapons/lever_rifle.tres"),
	&"coach_shotgun": preload("res://data/weapons/coach_shotgun.tres"),
}
const ORDER: Array[StringName] = [&"revolver", &"lever_rifle", &"coach_shotgun"]
const MAX_RANGE := 300.0
const IMPACT_FORCE := 4.0
const REST_POS := Vector3(0.2, -0.19, -0.5)

var vfx: VfxPool
var def: WeaponDef
## id -> upgrade level (0-2) for every weapon you own.
var owned: Dictionary = {&"revolver": 0}
## The three weapon hotbar slots, filled in the order you get weapons ("" = empty).
var slots: Array[StringName] = [&"revolver", &"", &""]
const MAX_WEAPONS := 3
## Right-click aim: where the gun sits, and how far the view zooms in.
const AIM_POS: Dictionary = {&"revolver": Vector3(0.0, -0.075, -0.5), &"lever_rifle": Vector3(0.0, -0.056, -0.44),
	&"coach_shotgun": Vector3(0.0, -0.058, -0.4)}
const AIM_ZOOM: Dictionary = {&"revolver": 1.4, &"lever_rifle": 2.2, &"coach_shotgun": 1.25}
## Aimed shotguns spread this much less.
const AIM_SPREAD := 0.6

## 0 = hip, 1 = fully aimed down the sights.
var aim := 0.0
var aiming := false
var ammo: int = 6
var _ammo_by_weapon: Dictionary = {}
var _cooldown := 0.0
## Reload stages (Hunt: Showdown style): tip the gun into the reload posture,
## load one round at a time (fire between rounds to cancel), then close up.
enum Reload { NONE, OPEN, LOAD, CLOSE }
var _stage: Reload = Reload.NONE
var _stage_t := 0.0
var _stage_len := 0.0
var _open := 0.0
var _loaded_this_reload := 0
## Lever rifle: the chambered round is flicked out and caught at the start of a reload.
var _catching := false
const CATCH_TIME := 0.85
## Lever stroke after a rifle shot (1 = closed), cylinder angle, last pose values.
var _cycle := 1.0
var _drum_angle := 0.0
var _drum_target := 0.0
var _kick := 0.0
var _models: Dictionary = {}
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_left := 0.0
## What's in your hand instead of a gun ("" = a gun): the water bucket or a vegetable.
var holding: StringName = &""
var _item_mi: MeshInstance3D
var _hand: MeshInstance3D
var _arms: Dictionary = {}
var _team := Palette.TEAM_WEST


## Rebuilds the first-person hands for a new outfit (dummy paint, coat sleeves).
func refresh_arms(look: Dictionary) -> void:
	for id: StringName in _models:
		(_models[id] as ViewModel).set_look(look)
	_hand.mesh = WeaponBuilder.item_arm(_team, look)


static func weapon(id: StringName) -> WeaponDef:
	return WEAPONS.get(id) as WeaponDef


func _ready() -> void:
	position = REST_POS
	var mat := Materials.toon(0.004)
	var owner_player := get_parent().get_parent().get_parent() as Player
	var team := Palette.team_color(owner_player.cliff_id) if owner_player != null else Palette.TEAM_WEST
	for id: StringName in ORDER:
		var vm := ViewModel.new()
		add_child(vm)
		vm.build(id, team, Settings.look, mat)
		_models[id] = vm
	_hand = MeshInstance3D.new()
	_hand.mesh = WeaponBuilder.item_arm(team, Settings.look)
	_team = team
	_hand.material_override = mat
	_hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hand.visible = false
	add_child(_hand)
	_item_mi = MeshInstance3D.new()
	_item_mi.material_override = mat
	_item_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_item_mi.visible = false
	add_child(_item_mi)
	_flash = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = Materials.star(Palette.GLOW_YELLOW, 3.0)
	_flash.mesh = quad
	_flash.visible = false
	add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Palette.GLOW_YELLOW
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 6.0
	add_child(_flash_light)
	equip(&"revolver")


func level_of(id: StringName) -> int:
	return int(owned.get(id, 0))


func owns(id: StringName) -> bool:
	return owned.has(id)


## Switches to an owned weapon.
func equip(id: StringName) -> void:
	if not owns(id):
		return
	if def != null and owned.has(def.id):
		_ammo_by_weapon[def.id] = ammo
	def = weapon(id)
	holding = &""
	_item_mi.visible = false
	_hand.visible = false
	ammo = int(_ammo_by_weapon.get(id, def.mag_size))
	_stage = Reload.NONE
	_open = 0.0
	_cycle = 1.0
	for k: StringName in _models:
		(_models[k] as Node3D).visible = k == id
	var muzzle_z := -0.28 if id == &"revolver" else -0.62
	_flash.position = Vector3(0, 0.02, muzzle_z)
	_flash_light.position = Vector3(0, 0.02, muzzle_z - 0.05)
	ammo_changed.emit(ammo, def.mag_size)
	loadout_changed.emit()


## Removes a weapon (dropped). Switches to another weapon, or empty hands.
func remove_weapon(id: StringName) -> void:
	owned.erase(id)
	var i := slots.find(id)
	if i >= 0:
		slots[i] = &""
	_ammo_by_weapon.erase(id)
	if def != null and def.id == id:
		def = null
		for w in slots:
			if w != &"":
				equip(w)
				return
		hold_item(&"none")
	loadout_changed.emit()


## Puts the gun away and holds the water bucket or a vegetable instead.
func hold_item(id: StringName) -> void:
	holding = id
	for k: StringName in _models:
		(_models[k] as Node3D).visible = false
	_item_mi.mesh = WeaponBuilder.held_item(id) if id != &"none" else null
	_item_mi.visible = id != &"none"
	_hand.visible = id != &"none"
	loadout_changed.emit()


## Owner: the host confirmed a purchase or upgrade.
func grant(id: StringName, level: int) -> void:
	owned[id] = level
	if not slots.has(id):
		var free := slots.find(&"")
		if free >= 0:
			slots[free] = id
	loadout_changed.emit()


## Damage per pellet for a weapon at an upgrade level (same formula on every peer).
static func damage_for(id: StringName, level: int) -> float:
	return weapon(id).damage * (1.0 + 0.25 * level)


## The ray directions for one shot. Shotguns scatter pellets from a shared seed.
static func shot_dirs(id: StringName, dir: Vector3, seed_value: int) -> Array[Vector3]:
	var d := weapon(id)
	var out: Array[Vector3] = []
	if d.pellets <= 1:
		out.append(dir.normalized())
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	var real_up := right.cross(dir).normalized()
	var spread := tan(deg_to_rad(d.spread_deg))
	if seed_value & 1:
		spread *= AIM_SPREAD # odd seed = the shooter was aiming
	for i in d.pellets:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread
		out.append((dir.normalized() + right * cos(a) * r + real_up * sin(a) * r).normalized())
	return out


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_advance_reload(delta)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
			_flash_light.light_energy = 0.0
	_kick = move_toward(_kick, 0.0, delta * 6.0)
	_open = move_toward(_open, 1.0 if (_stage == Reload.OPEN or _stage == Reload.LOAD) else 0.0, delta / 0.3)
	if def != null:
		_cycle = minf(_cycle + delta / maxf(def.fire_interval * 0.8, 0.1), 1.0)
	_drum_angle = move_toward(_drum_angle, _drum_target, delta * 9.0)
	var vm := _models.get(def.id) as ViewModel if def != null else null
	if vm != null:
		var load_t := clampf(_stage_t / maxf(_stage_len, 0.001), 0.0, 1.0)
		var catch_t := load_t if (_stage == Reload.OPEN and _catching) else -1.0
		vm.pose(_open, load_t, _stage == Reload.LOAD, _cycle, _drum_angle, _loaded_this_reload, catch_t)
	aim = move_toward(aim, 1.0 if aiming else 0.0, delta * 7.0)
	var aim_pos: Vector3 = AIM_POS.get(def.id, REST_POS) if def != null else REST_POS
	position = REST_POS.lerp(aim_pos, aim) + Vector3(0, 0, _kick * 0.06 * (1.0 - aim * 0.5))
	rotation = Vector3(_kick * 0.5, 0, 0)


## Times for this gun: tipping in, each round, closing up (faster with upgrades).
func _times() -> Vector3:
	var k := pow(0.85, level_of(def.id))
	match def.id:
		&"lever_rifle":
			return Vector3(0.3, def.reload_time * 0.2, 0.35) * k
		&"coach_shotgun":
			return Vector3(0.35, def.reload_time * 0.25, 0.3) * k
	return Vector3(0.35, def.reload_time * 0.3, 0.3) * k


func _advance_reload(delta: float) -> void:
	if _stage == Reload.NONE or def == null:
		return
	_stage_t += delta
	if _stage_t < _stage_len:
		return
	var times := _times()
	match _stage:
		Reload.OPEN:
			_catching = false
			if def.id == &"coach_shotgun":
				(_models[def.id] as ViewModel).eject_shells()
				ammo = 0
				ammo_changed.emit(ammo, def.mag_size)
			_begin(Reload.LOAD, times.y)
		Reload.LOAD:
			ammo = mini(ammo + 1, def.mag_size)
			_loaded_this_reload += 1
			ammo_changed.emit(ammo, def.mag_size)
			Audio.play_at(&"reload", global_position, -10.0)
			if def.id == &"revolver":
				_drum_target += TAU / 6.0
			if ammo < def.mag_size:
				_begin(Reload.LOAD, times.y)
			else:
				_begin(Reload.CLOSE, times.z)
		Reload.CLOSE:
			_stage = Reload.NONE
			if def.id == &"coach_shotgun":
				_kick = 0.4 # snapped shut
			elif def.id == &"lever_rifle":
				_cycle = 0.0 # work the lever to chamber a round
			Audio.play_at(&"reload", global_position, -6.0)


func _begin(stage: Reload, length: float) -> void:
	_stage = stage
	_stage_t = 0.0
	_stage_len = length


## Fires if possible (ammo, cooldown, effects). Hit resolution is done by PlayerNet.
func trigger(camera: Camera3D) -> bool:
	if holding != &"" or def == null:
		return false
	if _stage != Reload.NONE:
		# Like Hunt: fire between rounds to stop reloading (the shotgun has to
		# snap shut first).
		if def.id == &"coach_shotgun":
			if _stage != Reload.CLOSE:
				_begin(Reload.CLOSE, _times().z)
			return false
		if ammo <= 0 or _stage == Reload.CLOSE:
			return false
		_stage = Reload.NONE
	if _cooldown > 0.0:
		return false
	if ammo <= 0:
		reload()
		return false
	ammo -= 1
	_cooldown = def.fire_interval
	_kick = 1.0 + def.shake
	if def.id == &"revolver":
		_drum_target += TAU / 6.0
	elif def.id == &"lever_rifle":
		_cycle = 0.0 # work the lever
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash_light.light_energy = 2.5
	_flash_left = 0.05
	ammo_changed.emit(ammo, def.mag_size)
	Audio.play_at(def.sound, global_position, -2.0)
	var p := get_parent().get_parent().get_parent() as Player
	if p != null:
		p.add_shake(def.shake)
	fired.emit(camera.global_position, -camera.global_transform.basis.z)
	return true


## Right mouse held: aim if a gun is out and not reloading.
func set_aiming(on: bool) -> void:
	on = on or GameState.has_flag("--aim") # debug screenshots
	aiming = on and holding == &"" and def != null and _stage == Reload.NONE


## How much the view is zoomed right now (1 = not at all).
func zoom_factor() -> float:
	if def == null:
		return 1.0
	return lerpf(1.0, float(AIM_ZOOM.get(def.id, 1.3)), aim)


func reload() -> void:
	if holding != &"" or def == null or _stage != Reload.NONE or ammo == def.mag_size:
		return
	var times := _times()
	_loaded_this_reload = 0
	_catching = def.id == &"lever_rifle" and ammo > 0
	_begin(Reload.OPEN, CATCH_TIME if _catching else times.x)
	if _catching:
		Audio.play_at(&"reload", global_position, -4.0)
	var rounds := def.mag_size if def.id == &"coach_shotgun" else def.mag_size - ammo
	reload_started.emit(times.x + times.y * rounds + times.z)
	Audio.play_at(&"reload", global_position, -6.0)


func is_reloading() -> bool:
	return _stage != Reload.NONE


## Hitscan from origin along dir. Returns the intersect_ray result (empty on a miss).
func raycast(origin: Vector3, dir: Vector3, exclude: Array[RID], max_range: float = MAX_RANGE) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range)
	q.exclude = exclude
	q.collision_mask = WorldLayout.MASK_SHOTS
	return space.intersect_ray(q)


## Cosmetic: spark at the hit point and a nudge for loose props. `mine` adds
## damage numbers and hit markers for your own shots.
func show_impact(hit: Dictionary, dir: Vector3, mine: bool = false, dmg: float = 25.0) -> void:
	if hit.is_empty():
		return
	var pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var collider: Object = hit["collider"]
	if vfx != null:
		if collider is Hitbox:
			vfx.spark(pos, normal, Palette.ACID_GREEN)
			Audio.play_at(&"hit_tick", pos)
			if mine:
				var weak := (collider as Hitbox).multiplier > 1.0
				vfx.damage_number(pos, dmg * (collider as Hitbox).multiplier, weak)
				hit_confirmed.emit(weak)
		else:
			vfx.spark(pos, normal)
	if collider is RigidBody3D:
		var rb := collider as RigidBody3D
		rb.apply_impulse(dir * IMPACT_FORCE, pos - rb.global_position)
		if rb.has_method("apply_hit"):
			rb.call("apply_hit", 0.0, pos, dir)


## Host only: applies damage to whatever was hit (bugs, through their Hitbox; crates).
static func apply_hit_result(hit: Dictionary, dir: Vector3, dmg: float, pierce: bool, source: String, source_cliff: int) -> void:
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider != null and not (collider is RigidBody3D) and collider.has_method("apply_hit"):
		collider.call("apply_hit", dmg, hit["position"], dir, pierce, source, source_cliff)
