class_name WaveConfig
extends Resource
## Every wave tuning knob in one place (design doc: "Wave design and difficulty").

@export var budget_base: float = 20.0
@export var budget_linear: float = 12.0
@export var budget_quad: float = 1.5
@export var pulses_min: int = 4
@export var pulses_max: int = 5
## Seconds between pulses within a wave.
@export var pulse_interval: float = 9.0
## Waves up to early_waves pulse every early_pulse_interval s instead (more action early).
@export var early_waves: int = 5
@export var early_pulse_interval: float = 6.5
## Share of the budget sent to the heavier cliff, for waves without a scripted split.
@export var split_min: float = 0.5
@export var split_max: float = 0.7
## Scripted share of the budget sent to the WEST cliff, waves 1..9 (design doc table).
@export var west_share: PackedFloat32Array = PackedFloat32Array([0.5, 0.6, 0.4, 0.6, 0.5, 0.65, 0.35, 0.6, 0.7])
@export var build_time_first: float = 300.0
@export var build_time_last: float = 300.0
@export var warning_time: float = 10.0
## The run is won after this wave; players may then keep going (endless).
@export var last_wave: int = 20
@export var hp_multiplier: float = 1.0
## Extra bug HP per wave after the first (0.10 = +10% per wave). Kept well under
## count_growth: later waves are mostly MORE bugs, not spongier ones.
@export var hp_per_wave: float = 0.10
## Extra bug damage per wave after the first (0.10 = +10% per wave).
@export var damage_per_wave: float = 0.10
@export var homestead_hp: float = 500.0
@export var start_scrap: int = 150
@export var max_active_bugs: int = 750
## Bugs in wave 1 (both cliffs together); each later wave brings `count_growth` times as many.
@export var count_base: float = 65.0
@export var count_growth: float = 1.25
## From this wave on, the count grows by `late_growth` a wave instead (balance
## pass: 1.25x compounding outran every economy; the walls at 10-15 were the curve).
@export var late_from: int = 8
@export var late_growth: float = 1.18
## From this wave on, HP grows by `late_hp_per_wave` a wave instead.
@export var late_hp_from: int = 10
@export var late_hp_per_wave: float = 0.06
## A boss wave sends this much less of the regular pack (the boss takes its place).
@export var boss_count_cut: float = 0.25
## Most bugs one wave sends (they come out as the field's live cap frees up);
## a wave planned bigger sends this many, each tougher (WaveDirector.overflow_hp).
@export var max_wave_bugs: int = 5000

@export_group("Wave shapes")
## Every this many waves is a boss wave (brutes up front, the boss once it's unlocked).
@export var boss_every: int = 5
## Steady stream: many small pulses this far apart.
@export var steady_pulses: int = 8
@export var steady_interval: float = 6.0
## One big rush: everything within a few seconds (spread a little so spawning can't hitch).
@export var rush_pulses: int = 3
@export var rush_interval: float = 1.2
## Two pushes: two tight bursts this many seconds apart.
@export var push_gap: float = 35.0
## Share of each cliff's budget spent on fliers in a flier-heavy wave.
@export var flier_share: float = 0.45
## Share of each cliff's budget spent on brutes (tanks, brood mothers) in a boss wave.
@export var brute_share: float = 0.4

@export_group("Kill-method variants")
## Kills of one bug type by one method (bullets, fire, explosives) before its variant shows up.
@export var variant_kills: int = 60
## Once a variant is unlocked, the share of that type's groups that come as the variant.
@export var variant_share: float = 0.35


## How many bugs wave w sends (wave 1 = count_base, +25% a wave to wave
## `late_from`, then +18% a wave; a boss wave a quarter fewer).
func bug_count(w: int, boss_cut: bool = true) -> int:
	var early := mini(maxi(w, 1), late_from) - 1
	var late := maxi(w - late_from, 0)
	var n := count_base * pow(count_growth, float(early)) * pow(late_growth, float(late))
	if boss_cut and boss_every > 0 and w > 0 and w % boss_every == 0:
		n *= 1.0 - boss_count_cut
	return int(round(n))


## Threat budget for wave w: 20 + 12w + 1.5w^2.
func budget(w: int) -> float:
	return budget_base + budget_linear * w + budget_quad * w * w


## Bug HP multiplier for wave w.
func hp_scale(w: int) -> float:
	var early := mini(maxi(w, 1), late_hp_from) - 1
	var late := maxi(w - late_hp_from, 0)
	return hp_multiplier * (1.0 + hp_per_wave * float(early) + late_hp_per_wave * float(late))


## Bug damage multiplier for wave w (bites on structures and players).
func damage_scale(w: int) -> float:
	return 1.0 + damage_per_wave * float(maxi(w - 1, 0))


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
