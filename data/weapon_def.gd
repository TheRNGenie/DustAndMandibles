class_name WeaponDef
extends Resource
## A player weapon. Bought (and upgraded) with chitin at the gun shop.

@export var id: StringName = &""
## Weapon Slots: which hotbar slot it lives in. Each slot holds one gun; buying
## another for a full slot sells the old one back at half price.
enum Slot { PRIMARY, SECONDARY, HEAVY }
@export var slot: Slot = Slot.PRIMARY
## Heavies: the crop one load of ammunition costs (one harvest fills the
## magazine: `mag_size` is the shots per harvest). &"" = ordinary ammunition.
@export var crop: StringName = &""
## Heavies: rounds one harvest of `crop` loads (they wait in the gun's crop
## reserve and go into the magazine as you reload).
@export var shots_per_harvest: int = 0
@export var display_name: String = ""
@export var description: String = ""
@export var damage: float = 25.0
@export var mag_size: int = 6
@export var fire_interval: float = 0.3
@export var reload_time: float = 1.4
## Shotguns fire several pellets, each a separate hitscan ray.
@export var pellets: int = 1
@export var spread_deg: float = 0.0
@export var range: float = 250.0
@export var pierce_armor: bool = false
## Chitin to buy it (0 = you start with it).
@export var price_chitin: int = 0
## Chitin per upgrade level (each: +25% damage, 15% faster reload).
@export var upgrade_costs: PackedInt32Array = PackedInt32Array([10, 25])
@export var shake: float = 0.15
## Hold the trigger to keep firing (the Crank Gatling).
@export var automatic: bool = false
## Seconds of cranking before an automatic weapon starts firing.
@export var spin_up: float = 0.0
@export var sound: StringName = &"revolver"

@export_group("Role feel")
## View kick per shot (degrees up, plus up to this much sideways at random).
## It eases back down over `recoil_recover` seconds.
@export var recoil_deg: float = 1.0
@export var recoil_yaw_deg: float = 0.2
@export var recoil_recover: float = 0.25
## Damage falloff: full damage up to falloff_start metres, easing to
## falloff_min x damage at falloff_end. Shotguns fall off fast; the rifle never does.
@export var falloff_start: float = 1000.0
@export var falloff_end: float = 1000.0
@export var falloff_min: float = 1.0
## Suppression: each hit slows the bug to this speed for `suppress_time` s (1 = none).
@export var suppress_slow: float = 1.0
@export var suppress_time: float = 0.0
## One-word job shown in the field guide and gun shop.
@export var role: String = ""

@export_group("Specials")
## What the gun does besides damage (GunRules): &"harpoon" reels small bugs in
## or pulls you to big ones and walls, &"flare" marks a bug for every turret,
## &"salt" makes climbers lose their grip, &"smoke" makes fliers and spiders
## drowsy. &"" = an ordinary gun.
@export var special: StringName = &""
## Pitch of the shot sound (new guns reuse the old recordings higher or lower),
## and an optional second sound layered on top.
@export var sound_pitch: float = 1.0
@export var sound_layer: StringName = &""
@export var sound_layer_pitch: float = 1.0
## Shoves the shooter back along the shot (m/s): the Punt Gun's kick.
@export var kickback: float = 0.0
## Extra multiplier on a weak-spot hit, on top of the weak spot's own x2 (crits).
@export var weak_bonus: float = 1.0
## How fast it comes up when you switch to it (1 = normal; the derringers are quick).
@export var draw_speed: float = 1.0


## Damage multiplier for a hit `dist` metres away.
func falloff(dist: float) -> float:
	if dist <= falloff_start or falloff_end <= falloff_start:
		return 1.0
	return lerpf(1.0, falloff_min, clampf((dist - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0))


## A gun's key numbers in one line, the same in the shop and the field guide:
## "Damage 30  ·  6 Rounds  ·  1.8 s Reload  ·  Pierces Armour".
func stat_line() -> String:
	if special == &"smoke":
		return "  ·  ".join(PackedStringArray(["No Damage", "%d s of Smoke" % roundi(mag_size * fire_interval),
				"Reaches %d m" % int(range), "Refills Itself"]))
	if automatic and damage <= 0.0:
		# Weapon Slots sprays that do no harm themselves (tar, rust).
		return "  ·  ".join(PackedStringArray(["No Damage", "%d s of Spray" % roundi(mag_size * fire_interval),
				"Reaches %d m" % int(range), "Refills Itself" if reload_time <= 0.0 else "%.1f s Reload" % reload_time]))
	if automatic and crop != &"":
		# Heavy sprays (fire, acid): damage a puff, seconds a harvest.
		return "  ·  ".join(PackedStringArray(["Damage %d a Puff" % int(damage), "%d s a Crop Load" % roundi(shots_per_harvest * fire_interval),
				"Reaches %d m" % int(range)]))
	if damage <= 0.0:
		return "  ·  ".join(PackedStringArray(["No Damage", "%d Round%s" % [mag_size, "" if mag_size == 1 else "s"],
				"%.1f s Reload" % reload_time, "Reaches %d m" % int(range)]))
	var splash := special == &"mortar" or special == &"rocket"
	var parts: PackedStringArray = ["Damage %d%s%s" % [int(damage), (" x%d" % pellets) if pellets > 1 else "", " Splash" if splash else ""],
			"%d Round%s" % [mag_size, "" if mag_size == 1 else "s"], "%.1f s Reload" % reload_time,
			"Pierces Armour" if pierce_armor else "Stopped by Armour"]
	if falloff_start < range:
		parts.append("Weaker Past %d m" % int(falloff_start))
	if weak_bonus > 1.0:
		parts.append("Weak Spots x%s" % String.num(WeakSpot.MULTIPLIER * weak_bonus, 1).trim_suffix(".0"))
	if crop != &"":
		parts.append("%d a Crop Load" % shots_per_harvest)
	return "  ·  ".join(parts)
