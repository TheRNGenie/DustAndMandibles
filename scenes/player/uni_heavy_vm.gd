class_name UniHeavyVM
extends RefCounted
## First person: the moving parts of a universal crop-loaded heavy (UniHeavies),
## on top of what ViewModel already does for every Weapon Slots gun (the lever,
## the pump, the loaded round). Gun feeds it each frame (tick) and ViewModel
## hands it the pose (pose, crank). Handoff Part 4 / Part 5:
##   empty: the barrel tips up into an idle carry, the ring goes dark
##   loading: the port opens (door / rack / feed cap), the sack comes in, it shuts,
##            the ring lights, a 0.3 s pulse of the crop washes over the gun
##   swapping crops: a burst of the old crop's colour is thrown out first
##   drum and bola launchers turn a chamber each shot; the gatling's barrels
##   and crank spin with the wind-up; the crossbow's limbs snap and re-draw

## How far each gun's port opens (radians about X; the rack slides, the cap pulls).
const DOOR_OPEN: Dictionary = {&"crop_mortar": 1.4, &"hand_cannon": 1.5, &"drum_launcher": 1.6,
	&"harvest_gatling": 1.7, &"powder_keg_launcher": 1.2, &"crop_blunderbuss": -1.4}
## Barrel up in the empty carry (radians) and how quickly it gets there.
const CARRY_UP := 0.75
const CARRY_RATE := 3.0
const PULSE_TIME := 0.3

var vm: ViewModel
var id: StringName
var _parts: Dictionary = {}
var _carry := 1.0
var _empty := true
var _crop := &""
var _shown := "?"
var _pulse := 0.0
var _shots := -1
var _turn := 0.0
var _turn_target := 0.0
var _spin_angle := 0.0
var _draw := 1.0
var _rarity := -1
var _scale := 1.0


func _init(view: ViewModel) -> void:
	vm = view
	id = view.id
	for c: Node in view.get_children():
		if c is Node3D:
			_parts[String(c.name).to_lower().replace(" ", "_")] = c


func part(name: String) -> Node3D:
	return _parts.get(name) as Node3D


## Every frame from Gun: what's in the gun and how many shots it has fired.
func tick(crop: StringName, ammo: int, shots: int, delta: float, rarity: int = 0) -> void:
	if rarity != _rarity:
		_rarity = rarity
		_scale = UniHeavies.TRIM_SCALE[clampi(rarity, 0, UniHeavies.TRIM_SCALE.size() - 1)]
		UniHeavies.show_trim(vm, rarity)
	_empty = crop == &"" or ammo <= 0
	_crop = crop if not _empty else &""
	_carry = move_toward(_carry, 1.0 if _empty else 0.0, delta * CARRY_RATE)
	_pulse = maxf(_pulse - delta, 0.0)
	var boost := 1.0 + 2.5 * (_pulse / PULSE_TIME)
	var key := "%s:%d" % [_crop, roundi(boost * 4.0)]
	if key != _shown:
		_shown = key
		UniHeavies.tint(vm, _crop, boost)
	# A chamber's worth of turn per shot (drum: six tubes, bola: four slots).
	if _shots < 0:
		_shots = shots
	if shots != _shots:
		var step := TAU / 6.0 if id == &"drum_launcher" else (TAU / 4.0 if id == &"bola_launcher" else 0.0)
		_turn_target += step * float(shots - _shots)
		_shots = shots
	_turn = move_toward(_turn, _turn_target, delta * 9.0)
	var cyl := part("cylinder")
	if cyl != null:
		cyl.rotation.z = _turn


## The sack went in (Gun.heavy_confirmed): pulse the new crop, and throw out the old.
func loaded(old: StringName, crop: StringName) -> void:
	_pulse = PULSE_TIME
	if old != &"" and old != crop and vm.is_inside_tree():
		var v := VfxPool.instance
		if v != null and is_instance_valid(v):
			v.pop(vm.global_position + vm.global_basis * (ArmoryGuns.muzzle(id) * 0.5), HeavyRules.color_of(old), 0.18)


## After ViewModel's own pose: this gun's loading posture and moving parts.
## `e` 0..1 into the loading posture, `load_t` the sack going in, `cycle` the
## shot cycle (0 right after a shot, 1 settled).
func pose(e: float, load_t: float, loading: bool, cycle: float) -> void:
	var up := CARRY_UP * _carry * (1.0 - e)
	# Tipped up and toward you to pour the sack in; barrel up when it's empty.
	vm.transform = Transform3D(Basis.from_euler(Vector3(0.5 * e + up, 0.22 * e, 0.3 * e)).scaled(Vector3.ONE * _scale),
			Vector3(-0.04 * e, 0.02 * e - 0.05 * up, 0.06 * e + 0.05 * up))
	var door := part("door")
	if door != null:
		if id == &"bola_launcher":
			door.position = ArmoryGuns.pivot(id, "door") + Vector3(0, 0, -0.035 * e)
		else:
			door.rotation.x = float(DOOR_OPEN.get(id, 1.2)) * e
	var rack := part("rack")
	if rack != null:
		rack.position = ArmoryGuns.pivot(id, "rack") + Vector3(0.04 * e, 0, 0)
	var rod := part("rod")
	if rod != null:
		var tamp := sin(clampf(load_t, 0.0, 1.0) * PI) if loading else 0.0
		rod.position = ArmoryGuns.pivot(id, "rod") + Vector3(0, 0, 0.1 * tamp)
	if id == &"crop_crossbow":
		# The string snaps forward with the shot, the lever draws it back.
		var drawn := 0.0 if _empty else smoothstep(0.35, 1.0, clampf(cycle, 0.0, 1.0))
		_draw = drawn
		var l := part("limb_l")
		var r := part("limb_r")
		if l != null and r != null:
			l.rotation.y = -0.14 * (1.0 - drawn)
			r.rotation.y = 0.14 * (1.0 - drawn)
		var s := part("string")
		if s != null:
			s.scale = Vector3(1.0, 1.0, lerpf(0.06, 1.0, drawn))


## The gatling's wind-up (ViewModel.turn_crank): barrels and crank go round, the
## support hand on the handle.
func crank(amount: float, delta: float) -> void:
	var spinner := part("spinner")
	var handle := part("crank")
	if spinner == null or handle == null:
		return
	_spin_angle += amount * 26.0 * delta
	spinner.rotation.z = _spin_angle
	if ArmoryGuns.part_axis(id, "crank") == "z": # (the fal Harvest Gatling's crank turns on the barrel line)
		handle.rotation.z = -_spin_angle * 0.5
	else:
		handle.rotation.x = -_spin_angle * 0.5
	if vm.left != null and vm.transform.basis.get_euler().y < 0.02:
		var rest: Vector3 = WeaponBuilder.left_fist(id)
		vm.left.position = handle.position + handle.basis * (rest - handle.position)
