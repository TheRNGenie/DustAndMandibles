class_name Revolver
extends Node3D
## First-person revolver: 6 rounds, semi-auto, hitscan. In M0 hits are applied
## locally; in M1 `fired` will be routed to the host through request_fire().

signal fired(origin: Vector3, direction: Vector3)
signal ammo_changed(current: int, max_ammo: int)
signal reload_started(duration: float)

const MAX_AMMO := 6
const FIRE_INTERVAL := 0.3
const RELOAD_TIME := 1.4
const RANGE := 250.0
const DAMAGE := 25.0
const IMPACT_FORCE := 4.0
const REST_POS := Vector3(0.2, -0.19, -0.5)

var ammo: int = MAX_AMMO
var vfx: VfxPool
var _cooldown := 0.0
var _reload_left := 0.0
var _kick := 0.0
var _drum: MeshInstance3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_left := 0.0


func _ready() -> void:
	position = REST_POS
	var body := MeshInstance3D.new()
	body.mesh = WeaponBuilder.revolver_body()
	body.material_override = Materials.toon(0.004)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	_drum = MeshInstance3D.new()
	_drum.mesh = WeaponBuilder.revolver_drum()
	_drum.material_override = Materials.toon(0.004)
	_drum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drum.position = Vector3(0, 0.018, -0.005)
	add_child(_drum)
	_flash = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	quad.material = Materials.star(Palette.GLOW_YELLOW, 3.0)
	_flash.mesh = quad
	_flash.position = Vector3(0, 0.02, -0.28)
	_flash.visible = false
	add_child(_flash)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Palette.GLOW_YELLOW
	_flash_light.light_energy = 0.0
	_flash_light.omni_range = 6.0
	_flash_light.position = Vector3(0, 0.02, -0.35)
	add_child(_flash_light)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		_drum.rotate_z(delta * 14.0)
		if _reload_left <= 0.0:
			ammo = MAX_AMMO
			ammo_changed.emit(ammo, MAX_AMMO)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash.visible = false
			_flash_light.light_energy = 0.0
	# Recoil recovery and reload dip.
	_kick = move_toward(_kick, 0.0, delta * 6.0)
	var dip := 0.0
	if _reload_left > 0.0:
		dip = sin(clampf(1.0 - _reload_left / RELOAD_TIME, 0.0, 1.0) * PI)
	position = REST_POS + Vector3(0, -dip * 0.12, _kick * 0.06)
	rotation = Vector3(_kick * 0.5 - dip * 0.6, 0, dip * 0.5)


## Fires if possible (ammo, cooldown, effects). Hit resolution is done by the caller
## through raycast() / show_impact() / apply_hit_result(), so the host can confirm hits.
func trigger(camera: Camera3D) -> bool:
	if _cooldown > 0.0 or _reload_left > 0.0:
		return false
	if ammo <= 0:
		reload()
		return false
	ammo -= 1
	_cooldown = FIRE_INTERVAL
	_kick = 1.0
	_drum.rotate_z(TAU / 6.0)
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash_light.light_energy = 2.5
	_flash_left = 0.05
	ammo_changed.emit(ammo, MAX_AMMO)
	Audio.play_at(&"revolver", global_position, -2.0)
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	fired.emit(origin, dir)
	return true


func reload() -> void:
	if _reload_left > 0.0 or ammo == MAX_AMMO:
		return
	_reload_left = RELOAD_TIME
	reload_started.emit(RELOAD_TIME)
	Audio.play_at(&"reload", global_position, -6.0)


func is_reloading() -> bool:
	return _reload_left > 0.0


## Hitscan from origin along dir. Returns the intersect_ray result (empty on a miss).
func raycast(origin: Vector3, dir: Vector3, exclude: Array[RID]) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * RANGE)
	q.exclude = exclude
	q.collision_mask = WorldLayout.MASK_SHOTS
	return space.intersect_ray(q)


## Cosmetic: spark at the hit point and a nudge for loose physics props (tin cans).
## Runs on every peer that sees the shot; props are not synced.
func show_impact(hit: Dictionary, dir: Vector3) -> void:
	if hit.is_empty():
		return
	var pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var collider: Object = hit["collider"]
	if vfx != null:
		if collider is Hitbox:
			vfx.spark(pos, normal, Palette.ACID_GREEN)
			Audio.play_at(&"hit_tick", pos)
		else:
			vfx.spark(pos, normal)
	if collider is RigidBody3D:
		var rb := collider as RigidBody3D
		rb.apply_impulse(dir * IMPACT_FORCE, pos - rb.global_position)
		if rb.has_method("apply_hit"):
			rb.call("apply_hit", 0.0, pos, dir)


## Host only: applies damage to whatever was hit (bugs, through their Hitbox).
func apply_hit_result(hit: Dictionary, dir: Vector3, source: String, source_cliff: int) -> void:
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider is Hitbox:
		(collider as Hitbox).apply_hit(DAMAGE, hit["position"], dir, false, source, source_cliff)
