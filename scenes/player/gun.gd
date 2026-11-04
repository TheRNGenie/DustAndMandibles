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
## A flourish worth showing on your body to everyone else ("twirl", "reload_revolver").
signal flourished(kind: StringName)

## [Foundation] Guns are registered in Defs.WEAPONS with the rest of the content.
const WEAPONS: Dictionary = Defs.WEAPONS
const ORDER: Array[StringName] = [&"revolver", &"lever_rifle", &"coach_shotgun", &"blunderbuss", &"crank_gatling", &"elephant_gun", &"dino_rifle",
	&"derringer_pair", &"pepperbox", &"salt_shotgun", &"harpoon_pistol", &"bee_smoker", &"flare_gun", &"punt_gun", &"telescope_rifle"]
## Frontier guns that load every round in one go (a reload is one step).
const LOAD_ALL: Array[StringName] = [&"crank_gatling", &"pepperbox", &"derringer_pair"]
## Where some guns sit lower or closer than the standard rest spot (the smoker's
## can would block the view; the punt gun rides on the hip).
const REST_OFF: Dictionary = {&"bee_smoker": Vector3(0.03, -0.1, 0.04), &"punt_gun": Vector3(0.02, -0.05, 0.08),
	&"derringer_pair": Vector3(0.02, 0.0, 0.03), &"telescope_rifle": Vector3(0.0, -0.01, 0.02)}
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
	&"coach_shotgun": Vector3(0.0, -0.058, -0.4), &"blunderbuss": Vector3(0.0, -0.05, -0.4), &"crank_gatling": Vector3(0.06, -0.12, -0.45),
	&"elephant_gun": Vector3(-0.0077, -0.036, -0.2), # the scope's axis on your eye line
	&"dino_rifle": Vector3(-0.003, -0.072, -0.12),
	&"derringer_pair": Vector3(0.09, -0.11, -0.42), &"pepperbox": Vector3(0.0, -0.074, -0.46), &"harpoon_pistol": Vector3(0.0, -0.078, -0.44),
	&"flare_gun": Vector3(0.0, -0.08, -0.44), &"salt_shotgun": Vector3(0.0, -0.04, -0.36), &"punt_gun": Vector3(0.07, -0.21, -0.4),
	&"bee_smoker": Vector3(0.12, -0.27, -0.46), &"telescope_rifle": Vector3(0.0, -0.068, -0.16)}
## The Elephant Gun's lashed-on magnifying glass zooms in hard.
const AIM_ZOOM: Dictionary = {&"revolver": 1.4, &"lever_rifle": 2.2, &"coach_shotgun": 1.25, &"blunderbuss": 1.15, &"crank_gatling": 1.2, &"elephant_gun": 3.2, &"dino_rifle": 1.0,
	&"derringer_pair": 1.05, &"pepperbox": 1.2, &"harpoon_pistol": 1.35, &"flare_gun": 1.3, &"salt_shotgun": 1.25, &"punt_gun": 1.0,
	&"bee_smoker": 1.0, &"telescope_rifle": 4.5} # Telescope Rifle: the spyglass # Dino Rifle: its glass (DinoGlass) sets the zoom
## Player shot tracers per gun: colour, thickness (m), speed (m/s).
const TRACERS: Dictionary = {
	&"revolver": [Color("#FFC94A"), 0.055, 240.0],
	&"lever_rifle": [Color("#FFF1B0"), 0.045, 380.0],
	&"coach_shotgun": [Color("#FF9A3A"), 0.034, 200.0],
	&"blunderbuss": [Color("#FF5A2A"), 0.045, 160.0],
	&"crank_gatling": [Color("#FFD23F"), 0.04, 300.0],
	&"elephant_gun": [Color("#FFF6D0"), 0.09, 420.0],
	&"dino_rifle": [Color("#E8FFD0"), 0.08, 420.0],
	&"derringer_pair": [Color("#FFD27A"), 0.04, 220.0],
	&"pepperbox": [Color("#FFB04A"), 0.04, 220.0],
	&"salt_shotgun": [Color("#F4F8FF"), 0.03, 170.0], # rock salt
	&"harpoon_pistol": [Color("#C8A46A"), 0.022, 110.0], # the line
	&"flare_gun": [Color("#FF4A3A"), 0.12, 75.0], # the burning flare
	&"punt_gun": [Color("#FF8A3A"), 0.04, 170.0],
	&"bee_smoker": [Color("#D8D2C8"), 0.0, 1.0],
	&"telescope_rifle": [Color("#FFF8E0"), 0.06, 460.0],
}


## A stylized bullet from `from` to the end of each pellet's ray.
func draw_tracer(id: StringName, from: Vector3, to: Vector3) -> void:
	if vfx == null:
		return
	var s: Array = TRACERS.get(id, TRACERS[&"revolver"])
	vfx.bullet_streak(from, to, s[0], s[1], s[2])
	# Birds and vultures can be shot out of the sky (each peer's own sky).
	var life: Node = vfx.get("canyon_life")
	if life != null and is_instance_valid(life):
		life.call("shoot", from, to)


## World position of this gun's muzzle (the flash point).
func muzzle_global() -> Vector3:
	return _flash.global_position


## When each gun was put away (ms), for the smoker's fuel.
var _holstered_at: Dictionary = {}
## Derringers: the hand that fires next (0 right, 1 left).
var _hand_next := 0
## Bee Smoker: seconds since the last puff, and the fuel's fraction of a unit.
var _fuel_idle := 0.0
var _fuel_frac := 0.0


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
# ---- first-person feel (fed by Player every frame)
## Mouse movement since last frame (pixels), for the gun lagging behind your look.
var look_delta := Vector2.ZERO
var _sway := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _bob_phase := 0.0
var _move := 0.0
var _sprint := 0.0
var _slide_feel := 0.0
var _land := 0.0
var _land_vel := 0.0
var _air_feel := 0.0
## 1 right after switching weapons: the new one comes up from below.
var _raise := 0.0
## Revolver twirl round the trigger finger: time left, length, full turns.
var _twirl_left := 0.0
var _twirl_len := 1.0
var _twirl_turns := 2.0
const TWIRL_EQUIP := Vector2(0.62, 2.0)
const TWIRL_RELOAD := Vector2(0.42, 1.0)
## Debug (--twirlat=0..1): hold the twirl at that point (viewmodel screenshots).
var _twirl_freeze := -1.0
## Extra hand movement for held items (the lighter's flick), and where an item
## is held relative to the gun's rest spot.
var item_rot := Vector3.ZERO
var item_pos := Vector3.ZERO
## 0..1: the gun is lowered out of the way while your hands do something else.
var lowered := 0.0
var _lower_target := 0.0


## Rebuilds the first-person hands for a new outfit (dummy paint, coat sleeves).
func refresh_arms(look: Dictionary) -> void:
	for id: StringName in _models:
		(_models[id] as ViewModel).set_look(look)
	_hand.mesh = WeaponBuilder.item_arm(_team, look)


static func weapon(id: StringName) -> WeaponDef:
	return WEAPONS.get(id) as WeaponDef


func _ready() -> void:
	if GameState.flag_value("--twirlat") != "":
		_twirl_freeze = GameState.flag_value("--twirlat").to_float()
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


## Upgrade level (0-2) of a weapon you own.
func level_of(id: StringName) -> int:
	return WeaponMods.level(code_of(id))


## Level and mods packed together (see WeaponMods); what travels with the gun.
func code_of(id: StringName) -> int:
	return int(owned.get(id, 0))


# Effective stats of the gun in hand, with its mods.
func mag_size() -> int:
	return def.mag_size + WeaponMods.add(def.id, code_of(def.id), "mag") + PerkTable.bandolier_bonus(def.mag_size, Perks.local_rank(&"bandolier")) if def != null else 0 # Perk: Bandolier


func fire_interval() -> float:
	return def.fire_interval * WeaponMods.mult(def.id, code_of(def.id), "fire_interval") * Perks.local_less(&"hair_trigger") # Perk: Hair Trigger


func reload_time() -> float:
	return def.reload_time * WeaponMods.mult(def.id, code_of(def.id), "reload")


func spin_up_time() -> float:
	return def.spin_up * WeaponMods.mult(def.id, code_of(def.id), "spin_up")


func owns(id: StringName) -> bool:
	return owned.has(id)


## Switches to an owned weapon.
func equip(id: StringName) -> void:
	if not owns(id):
		return
	if def != null and owned.has(def.id):
		_ammo_by_weapon[def.id] = ammo
		_holstered_at[def.id] = Time.get_ticks_msec()
	def = weapon(id)
	holding = &""
	_item_mi.visible = false
	_hand.visible = false
	ammo = int(_ammo_by_weapon.get(id, mag_size()))
	_stage = Reload.NONE
	_open = 0.0
	_cycle = 1.0
	for k: StringName in _models:
		(_models[k] as Node3D).visible = k == id
	if _raise < 0.5 and is_inside_tree():
		Audio.play_at(&"equip", global_position, -10.0)
	_raise = 1.0
	_twirl_left = 0.0
	if id == &"revolver" and is_inside_tree() and not GameState.has_flag("--notwirl"):
		# Drawn with a spin round the trigger finger.
		_start_twirl(TWIRL_EQUIP)
	var muzzle_z := -0.28 if id == &"revolver" else -0.62
	_flash.position = FrontierGuns.MUZZLE.get(id, Vector3(0, 0.02, muzzle_z))
	_flash_light.position = _flash.position + Vector3(0, 0, -0.05)
	_hand_next = 0
	if id == &"bee_smoker" and _holstered_at.has(id):
		# The burlap kept smouldering in the holster.
		var away := (Time.get_ticks_msec() - int(_holstered_at[id])) / 1000.0
		ammo = int(GunRules.refill(float(ammo), away, maxf(away - GunRules.FUEL_DELAY, 0.0), level_of(id), float(mag_size())))
	ammo_changed.emit(ammo, mag_size())
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
	for c in _item_mi.get_children():
		c.queue_free()
	var model_id: StringName = {&"water": &"bucket", &"grapple": &"grapple"}.get(id, &"")
	var model := GunModels.make(model_id) if model_id != &"" else null
	if model != null:
		_item_mi.mesh = null
		_item_mi.add_child(model)
		# Put the part you hold in the fist: the launcher's grip, the bucket's rope handle.
		if model_id == &"grapple":
			model.position = Vector3(-0.019, 0.027, 0.068)
		elif model_id == &"bucket":
			model.position = Vector3(0.0, -0.115, 0.03)
	else:
		_item_mi.mesh = WeaponBuilder.held_item(id) if id != &"none" else null
	_item_mi.visible = id != &"none"
	_hand.visible = id != &"none"
	_raise = 1.0
	loadout_changed.emit()


## The held item's node (the grapple launcher's model hangs off it), for the
## dynamite's match strip.
func item_node() -> Node3D:
	return _item_mi if holding != &"" and holding != &"none" else null


## Owner: the host confirmed a purchase or upgrade.
func grant(id: StringName, level: int) -> void:
	owned[id] = level
	if not slots.has(id):
		var free := slots.find(&"")
		if free >= 0:
			slots[free] = id
	loadout_changed.emit()


## Damage per pellet for a weapon with its level and mods (same formula on every peer).
static func damage_for(id: StringName, code: int) -> float:
	return weapon(id).damage * (1.0 + 0.25 * WeaponMods.level(code)) * WeaponMods.mult(id, code, "damage")


static func range_for(id: StringName, code: int) -> float:
	return weapon(id).range * WeaponMods.mult(id, code, "range")


## Damage of one pellet/bullet that hit `dist` metres from the shooter (falloff).
static func damage_at(id: StringName, code: int, dist: float) -> float:
	return damage_for(id, code) * weapon(id).falloff(dist)


static func pierce_for(id: StringName, code: int) -> bool:
	return weapon(id).pierce_armor or WeaponMods.flag(id, code, "pierce")


## The ray directions for one shot. Shotguns scatter pellets from a shared seed;
## single-bullet guns with a spread wobble one ray from the same seed.
static func shot_dirs(id: StringName, dir: Vector3, seed_value: int, code: int = 0) -> Array[Vector3]:
	var d := weapon(id)
	var out: Array[Vector3] = []
	var pellets := d.pellets + WeaponMods.add(id, code, "pellets")
	if pellets <= 1 and d.spread_deg <= 0.0:
		out.append(dir.normalized())
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	var real_up := right.cross(dir).normalized()
	var spread := tan(deg_to_rad(d.spread_deg * WeaponMods.mult(id, code, "spread")))
	if seed_value & 1:
		spread *= AIM_SPREAD # odd seed = the shooter was aiming
	for i in maxi(pellets, 1):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread
		out.append((dir.normalized() + right * cos(a) * r + real_up * sin(a) * r).normalized())
	return out


## Automatic weapons: is the trigger held, and how wound-up the barrels are (0..1).
var trigger_held := false
var spin := 0.0


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if def != null and def.automatic:
		var want := 1.0 if trigger_held and holding == &"" and _stage == Reload.NONE else 0.0
		spin = move_toward(spin, want, delta / maxf(spin_up_time() if want > 0.0 else spin_up_time() * 2.0, 0.05))
	else:
		spin = 0.0
	_advance_reload(delta)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
			_flash_light.light_energy = 0.0
	_kick = move_toward(_kick, 0.0, delta * 6.0)
	_open = move_toward(_open, 1.0 if (_stage == Reload.OPEN or _stage == Reload.LOAD) else 0.0, delta / 0.3)
	if def != null:
		_cycle = minf(_cycle + delta / maxf(fire_interval() * 0.8, 0.1), 1.0)
	_drum_angle = move_toward(_drum_angle, _drum_target, delta * 9.0)
	var vm := _models.get(def.id) as ViewModel if def != null else null
	if def != null and def.special == &"smoke" and holding == &"":
		_refill_fuel(delta)
	if vm != null:
		vm.frontier_tick(delta)
		vm.set_loaded(ammo > 0 or _stage == Reload.CLOSE)
		var load_t := clampf(_stage_t / maxf(_stage_len, 0.001), 0.0, 1.0)
		var catch_t := load_t if (_stage == Reload.OPEN and _catching) else -1.0
		vm.pose(_open, load_t, _stage == Reload.LOAD, _cycle, _drum_angle, _loaded_this_reload, catch_t)
		if def.id == &"revolver":
			_twirl_left = maxf(_twirl_left - delta, 0.0)
			if _twirl_freeze >= 0.0:
				_twirl_len = TWIRL_EQUIP.x
				_twirl_turns = TWIRL_EQUIP.y
				_twirl_left = _twirl_len * (1.0 - _twirl_freeze)
			vm.twirl(twirl_angle())
		vm.turn_crank(spin, delta)
	aim = move_toward(aim, 1.0 if aiming else 0.0, delta * 7.0)
	# Elephant Gun: once the glass is up to your eye you look through it (the HUD
	# draws the lens), so the gun itself steps out of view.
	if def != null and (def.id == &"elephant_gun" or def.id == &"dino_rifle") and _models.has(def.id):
		(_models[def.id] as Node3D).visible = not is_scoped()
	if def != null and def.id == &"dino_rifle" and _models.has(def.id):
		(_models[def.id] as ViewModel).set_glass(DinoGlass.of(code_of(def.id))) # this gun's glass fit
	if def != null and _models.has(def.id):
		(_models[def.id] as ViewModel).set_finish(AmberRules.is_lucky(code_of(def.id))) # Hive amber: Lucky's finish
	if def != null and def.id == &"telescope_rifle" and _models.has(def.id):
		(_models[def.id] as Node3D).visible = not is_scoped()
	var rest: Vector3 = REST_POS + (REST_OFF.get(def.id, Vector3.ZERO) if def != null else Vector3.ZERO)
	var aim_pos: Vector3 = AIM_POS.get(def.id, rest) if def != null else rest
	_feel_step(delta)
	var off := _feel_offset()
	var held := holding != &"" and holding != &"none"
	position = rest.lerp(aim_pos, aim) + Vector3(0, 0, _kick * 0.06 * (1.0 - aim * 0.5)) + off[0] + (item_pos if held else Vector3.ZERO)
	rotation = Vector3(_kick * 0.5, 0, 0) + off[1] + (item_rot if held else Vector3.ZERO)


## Player: how you're moving this frame (speed m/s, sprinting, on the ground, sliding).
func feel(speed: float, sprinting: bool, on_floor: bool, sliding: bool, delta: float) -> void:
	var k := clampf(speed / 9.5, 0.0, 1.0) if on_floor and not sliding else 0.0
	_move = lerpf(_move, k, clampf(delta * 8.0, 0.0, 1.0))
	if on_floor and speed > 0.5 and not sliding:
		_bob_phase += delta * (5.0 + speed * 0.75)
	_sprint = move_toward(_sprint, 1.0 if sprinting and not aiming else 0.0, delta * 5.0)
	_slide_feel = move_toward(_slide_feel, 1.0 if sliding else 0.0, delta * 6.0)
	_air_feel = move_toward(_air_feel, 0.0 if on_floor else 1.0, delta * 4.0)


## Player: you just landed; `strength` 0..1 from how hard.
func land(strength: float) -> void:
	_land_vel -= clampf(strength, 0.0, 1.0) * 6.0


func set_lowered(on: bool) -> void:
	_lower_target = 1.0 if on else 0.0


func _feel_step(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	# Look sway: a spring pulled by mouse movement, so the gun trails your view.
	var pull := look_delta * 0.0016 * (1.0 - aim * 0.75)
	look_delta = Vector2.ZERO
	_sway_vel += (-_sway * 140.0 - _sway_vel * 16.0) * dt - pull * 60.0
	_sway += _sway_vel * dt
	_sway = _sway.clamp(Vector2(-0.12, -0.12), Vector2(0.12, 0.12))
	# Landing: a damped dip.
	_land_vel += (-_land * 120.0 - _land_vel * 14.0) * dt
	_land += _land_vel * dt
	_raise = move_toward(_raise, 0.0, dt * 3.6 * (def.draw_speed if def != null else 1.0))
	lowered = move_toward(lowered, _lower_target, dt * 5.0)


## [position offset, rotation offset] from sway, bob, sprint, landing, switching.
func _feel_offset() -> Array:
	var calm := 1.0 - aim * 0.85
	var bob_x := sin(_bob_phase) * 0.012 * _move * calm
	var bob_y := -absf(cos(_bob_phase)) * 0.011 * _move * calm
	var pos := Vector3(bob_x + _sway.x * 0.18, bob_y + _sway.y * 0.15 + _land * 0.03, 0.0)
	var rot := Vector3(_sway.y * 0.6 + _land * 0.12, _sway.x * 0.8, -_sway.x * 0.9 + sin(_bob_phase) * 0.02 * _move * calm)
	# Sprint: carried low and canted across the chest.
	pos += Vector3(-0.03, -0.05, 0.03) * _sprint
	rot += Vector3(-0.28, 0.42, 0.22) * _sprint
	# Slide: tucked in and tilted.
	pos += Vector3(-0.02, -0.02, 0.02) * _slide_feel
	rot += Vector3(0.0, 0.0, 0.32) * _slide_feel
	# In the air: the gun floats up a touch.
	pos.y += 0.012 * _air_feel
	# Switching: rises from below with a little roll.
	var r := _raise * _raise
	pos += Vector3(0.02, -0.28, 0.06) * r
	rot += Vector3(-0.7, 0.0, 0.35) * r
	# Lowered while the hands work.
	var l := smoothstep(0.0, 1.0, lowered)
	pos += Vector3(0.05, -0.36, 0.1) * l
	rot += Vector3(-0.9, 0.2, 0.4) * l
	return [pos, rot]


## Times for this gun: tipping in, each round, closing up (faster with upgrades).
func _times() -> Vector3:
	var k := pow(0.85, level_of(def.id)) * Perks.local_less(&"quick_hands") * Brand.reload_mult() # Perk: Quick Hands; Brand: Crossed Irons
	match def.id:
		&"lever_rifle":
			return Vector3(0.3, reload_time() * 0.2, 0.35) * k
		&"coach_shotgun":
			return Vector3(0.35, reload_time() * 0.25, 0.3) * k
		&"blunderbuss":
			return Vector3(0.4, reload_time() * 0.6, 0.4) * k
		&"crank_gatling":
			return Vector3(0.45, reload_time() * 0.6, 0.4) * k
		&"elephant_gun", &"dino_rifle":
			# Break it open, thumb in two fat cartridges one at a time, snap it shut.
			return Vector3(0.6, reload_time() * 0.5, 0.55) * k
		&"derringer_pair":
			# Flick both open, thumb four in, flick them shut: under a second.
			return Vector3(0.15, reload_time() * 0.6, 0.15) * k
		&"pepperbox":
			# All six nipples capped and loaded from a block in one go.
			return Vector3(0.35, reload_time() * 0.7, 0.3) * k
		&"salt_shotgun":
			return Vector3(0.35, reload_time() * 0.16, 0.3) * k
		&"telescope_rifle":
			return Vector3(0.4, reload_time() * 0.15, 0.4) * k
		&"harpoon_pistol", &"flare_gun":
			return Vector3(0.35, reload_time() * 0.55, 0.3) * k
		&"punt_gun":
			# Break the iron open, heave the spent case out, the new shell in, close it.
			return Vector3(0.9, reload_time() * 0.55, 0.85) * k
	return Vector3(0.35, reload_time() * 0.3, 0.3) * k


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
				ammo_changed.emit(ammo, mag_size())
			_begin(Reload.LOAD, times.y)
		Reload.LOAD:
			# The gatling swaps a whole drum at once.
			ammo = mag_size() if LOAD_ALL.has(def.id) else mini(ammo + 1, mag_size())
			_loaded_this_reload += 1
			ammo_changed.emit(ammo, mag_size())
			_foley("load", -8.0)
			if def.id == &"revolver":
				_drum_target += TAU / 6.0
			if ammo < mag_size():
				_begin(Reload.LOAD, times.y)
			else:
				_begin(Reload.CLOSE, times.z)
		Reload.CLOSE:
			_stage = Reload.NONE
			if def.id == &"revolver" and not GameState.has_flag("--notwirl"):
				# Gate snapped shut: a quick spin back into the hand.
				_start_twirl(TWIRL_RELOAD)
			if def.id == &"coach_shotgun":
				_kick = 0.4 # snapped shut
			elif def.id == &"lever_rifle":
				_cycle = 0.0 # work the lever to chamber a round
			_foley("close", -5.0)


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
	if def.automatic and spin < 1.0:
		return false # still winding the crank up
	if ammo <= 0:
		if def.special != &"smoke": # the smoker just waits for its fuel
			reload()
		return false
	ammo -= 1
	_twirl_left = 0.0 # a shot cuts any flourish short
	_cooldown = fire_interval()
	_kick = 1.0 + def.shake
	if def.id == &"revolver" or def.id == &"pepperbox":
		_drum_target += TAU / 6.0
	elif def.id == &"lever_rifle" or def.id == &"salt_shotgun" or def.id == &"telescope_rifle":
		_cycle = 0.0 # work the lever / pump / bolt
	var vm := _models.get(def.id) as ViewModel
	if def.id == &"derringer_pair":
		# Right, left, right, left: each pistol kicks in its own hand.
		vm.hand_kick(_hand_next)
		var off: Vector3 = vm.left.position - (WeaponBuilder.RIGHT_HAND[def.id][0] as Vector3) if _hand_next == 1 else Vector3.ZERO
		_flash.position = (FrontierGuns.MUZZLE[def.id] as Vector3) + off
		_hand_next = 1 - _hand_next
	elif def.id == &"harpoon_pistol":
		vm.spin_reel(60.0)
	if def.special == &"smoke":
		_fuel_idle = 0.0
		_kick = 0.0
	else:
		_flash.visible = true
		_flash.rotation.z = randf() * TAU
		_flash_light.light_energy = 2.5 if def.id != &"flare_gun" else 5.0
		_flash_light.light_color = Color("#FF5A3A") if def.id == &"flare_gun" else Palette.GLOW_YELLOW
		_flash_left = 0.05 if def.id != &"flare_gun" else 0.18
	ammo_changed.emit(ammo, mag_size())
	play_shot_sound(def, global_position, -2.0, _shot_count)
	_shot_count += 1
	var p := get_parent().get_parent().get_parent() as Player
	if p != null:
		p.add_shake(def.shake)
		if p.is_multiplayer_authority():
			# Per-gun role feel: the rifle and shotguns kick hard, the revolver barely.
			p.add_recoil(def.recoil_deg * (0.7 if aiming else 1.0), def.recoil_yaw_deg, def.recoil_recover)
	fired.emit(camera.global_position, -camera.global_transform.basis.z)
	return true


var _shot_count := 0


## A gun's shot sound (pitched, with its layer). The smoker only wheezes every
## third puff, and quietly.
static func play_shot_sound(d: WeaponDef, at: Vector3, volume_db: float, count: int = 0) -> void:
	if d.special == &"smoke":
		if count % 3 == 0:
			Audio.play_at(d.sound, at, volume_db - 12.0, d.sound_pitch)
		return
	Audio.play_at(d.sound, at, volume_db, d.sound_pitch)
	if d.sound_layer != &"":
		Audio.play_at(d.sound_layer, at, volume_db - 3.0, d.sound_layer_pitch)


## Bee Smoker: the burlap smoulders back up while you're not puffing.
func _refill_fuel(delta: float) -> void:
	_fuel_idle += delta
	if ammo >= mag_size():
		_fuel_frac = 0.0
		return
	var f := GunRules.refill(float(ammo) + _fuel_frac, _fuel_idle, delta, level_of(def.id), float(mag_size()))
	var whole := int(f)
	_fuel_frac = f - whole
	if whole != ammo:
		ammo = whole
		ammo_changed.emit(ammo, mag_size())


## Right mouse held: aim if a gun is out and not reloading.
func set_aiming(on: bool) -> void:
	on = on or GameState.has_flag("--aim") # debug screenshots
	aiming = on and holding == &"" and def != null and _stage == Reload.NONE


## How much the view is zoomed right now (1 = not at all).
## Looking through the Elephant Gun's lashed-on glass (fully aimed).
func is_scoped() -> bool:
	if def != null and def.id == &"dino_rifle":
		return holding == &"" and aim > 0.85 and bool(DinoGlass.get_fit(code_of(def.id))["scoped"])
	return def != null and (def.id == &"elephant_gun" or def.id == &"telescope_rifle") and holding == &"" and aim > 0.85


func zoom_factor() -> float:
	if def == null:
		return 1.0
	var zoom := float(AIM_ZOOM.get(def.id, 1.3)) * WeaponMods.mult(def.id, code_of(def.id), "zoom")
	if def.id == &"dino_rifle":
		zoom *= float(DinoGlass.get_fit(code_of(def.id))["zoom"])
	return lerpf(1.0, zoom, aim)


func reload() -> void:
	if holding != &"" or def == null or _stage != Reload.NONE or ammo == mag_size() or def.special == &"smoke":
		return
	var times := _times()
	_loaded_this_reload = 0
	_catching = def.id == &"lever_rifle" and ammo > 0
	_begin(Reload.OPEN, CATCH_TIME if _catching else times.x)
	if _catching:
		_foley("open", -4.0)
	var rounds := mag_size() if def.id == &"coach_shotgun" else (1 if LOAD_ALL.has(def.id) else mag_size() - ammo)
	reload_started.emit(times.x + times.y * rounds + times.z)
	if def.id == &"revolver":
		flourished.emit(&"reload_revolver")
	if not _catching:
		_foley("open", -5.0)


func _start_twirl(spec: Vector2) -> void:
	_twirl_len = spec.x
	_twirl_turns = spec.y
	_twirl_left = spec.x
	Audio.play_at(&"spur", global_position, -16.0)
	flourished.emit(&"twirl")


## The revolver's spin right now (radians): fast off the finger, settling
## into the grip with a little overshoot.
func twirl_angle() -> float:
	if _twirl_left <= 0.0:
		return 0.0
	var t := 1.0 - _twirl_left / maxf(_twirl_len, 0.001)
	var e := 1.0 - pow(1.0 - t, 3.0)
	var settle := sin(clampf((t - 0.8) / 0.2, 0.0, 1.0) * PI) * 0.12
	return -TAU * _twirl_turns * e + settle


func is_twirling() -> bool:
	return _twirl_left > 0.0


## This gun's reload sound for a step ("open", "load", "close"), or the generic click.
func _foley(step: String, volume_db: float) -> void:
	var id := StringName("%s_%s" % [FrontierGuns.FOLEY.get(def.id, def.id), step]) if def != null else &"reload"
	Audio.play_at(id if Audio.has_sound(id) else &"reload", global_position, volume_db)


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
				# [Foundation hook] one hitbox per bug now: the weak spot is read from the hit point.
				var mult := (collider as Hitbox).multiplier_at(pos)
				var weak := mult > 1.0
				vfx.damage_number(pos, dmg * mult, weak)
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
	elif collider != null and not collider.has_method("apply_hit"):
		BossFx.on_world_hit(hit["position"]) # Boss: shooting the corpse pile apart starves the Bone Collector
