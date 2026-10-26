class_name WaveConfig
extends Resource
## Every wave tuning knob in one place (design doc: "Wave design and difficulty").

@export var budget_base: float = 20.0
@export var budget_linear: float = 12.0
@export var budget_quad: float = 1.5
@export var pulses_min: int = 3
@export var pulses_max: int = 5
## Seconds between pulses within a wave.
@export var pulse_interval: float = 9.0
## Share of the budget sent to the heavier cliff, for waves without a scripted split.
@export var split_min: float = 0.5
@export var split_max: float = 0.7
## Scripted share of the budget sent to the WEST cliff, waves 1..9 (design doc table).
@export var west_share: PackedFloat32Array = PackedFloat32Array([0.5, 0.6, 0.4, 0.6, 0.5, 0.65, 0.35, 0.6, 0.7])
@export var build_time_first: float = 300.0
@export var build_time_last: float = 300.0
@export var warning_time: float = 10.0
@export var last_wave: int = 10
@export var hp_multiplier: float = 1.0
## Extra bug HP per wave after the first (0.08 = +8% per wave).
@export var hp_per_wave: float = 0.08
@export var homestead_hp: float = 500.0
@export var start_scrap: int = 150
@export var max_active_bugs: int = 150


## Threat budget for wave w: 20 + 12w + 1.5w^2.
func budget(w: int) -> float:
	return budget_base + budget_linear * w + budget_quad * w * w


## Bug HP multiplier for wave w.
func hp_scale(w: int) -> float:
	return hp_multiplier * (1.0 + hp_per_wave * float(maxi(w - 1, 0)))


func build_time(w: int) -> float:
	var t := clampf(float(w - 1) / float(maxi(last_wave - 1, 1)), 0.0, 1.0)
	return lerpf(build_time_first, build_time_last, t)


## Share of the budget for the west cliff in wave w. `rng_roll` in 0..1 is used
## for unscripted waves, so the heavier side still alternates.
func west_share_for(w: int, rng_roll: float) -> float:
	if w >= 1 and w <= west_share.size():
		return west_share[w - 1]
	var heavy := lerpf(split_min, split_max, rng_roll)
	return heavy if w % 2 == 0 else 1.0 - heavy
