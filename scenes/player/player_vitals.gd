class_name PlayerVitals
extends Node
## The local player's health, downed state and "use" key. Health lives on the
## owning peer; the host sends damage to it with an RPC. At 0 HP you're downed for
## 15 s, then respawn at your Homestead: nobody sits out a whole wave.
## Grown herbs work as medicine (hotbar slot 7).
## Hunger and thirst never hurt you: they only nudge. Running low slows your
## health regen and sprint a little and puts a slight sway in your aim. Eat a
## crop (left click with corn, pear or chili out) or drink from the bucket.

signal health_changed(hp: float, max_hp: float)
signal downed_changed(downed: bool, seconds: float)
signal prompt_changed(text: String)
## Fullness 0..1 (1 = fed / watered). Emitted a few times a second.
signal needs_changed(food: float, water: float)

const MAX_HP := 100.0
const DOWNED_TIME := 15.0
const REGEN_DELAY := 5.0
const REGEN_PER_SEC := 3.0
const INTERACT_REACH := 3.5
const HOLD_REPEAT := 0.3
const HERB_HEAL := 50.0
## Minutes from full to empty at a mild temperature (heat speeds thirst up).
const HUNGER_MINUTES := 22.0
const THIRST_MINUTES := 16.0
## Below this a need starts to nudge (and its HUD icon shows).
const NEED_LOW := 0.35
## What each thing you can eat or drink restores (food, water, hp).
const FEEDS := {
	&"corn": [0.45, 0.0, 0.0],
	&"prickly_pear": [0.3, 0.2, 20.0],
	&"chili": [0.35, -0.05, 0.0],
	&"water": [0.0, 0.7, 0.0],
}

var hp := MAX_HP
var downed := false
var _downed_left := 0.0
var _since_hit := 99.0
var _hold := 0.0
var _prompt := ""
var food := 1.0
var water := 1.0
var _warned := {}
var _needs_t := 0.0

@onready var player: Player = get_parent() as Player


func _process(delta: float) -> void:
	if not player.is_multiplayer_authority():
		return
	if downed:
		_downed_left -= delta
		downed_changed.emit(true, _downed_left)
		if _downed_left <= 0.0:
			downed = false
			hp = MAX_HP
			if player.on_trip(): # Canyon Expeditions: downed on the floor
				Economy.notice.emit("The airship crew hauled you up out of the canyon. Your sack's still down there.")
			player.respawn()
			downed_changed.emit(false, 0.0)
			health_changed.emit(hp, MAX_HP)
		return
	_since_hit += delta
	_tick_needs(delta)
	if _since_hit > REGEN_DELAY and hp < MAX_HP:
		hp = minf(hp + REGEN_PER_SEC * regen_mult() * delta, MAX_HP)
		health_changed.emit(hp, MAX_HP)
	_update_interact(delta)


## Hunger and thirst are switched off for now (owner's call, 2026-11-02): food
## and water stay full, so nothing slows, sways or shows. Flip to bring them back.
const NEEDS_ENABLED := false


func _tick_needs(delta: float) -> void:
	if not NEEDS_ENABLED:
		return
	if GameState.phase == GameState.Phase.LOBBY or GameState.phase == GameState.Phase.GAME_OVER:
		return
	var per_sec := delta / 60.0 * GameState.growth_scale()

	food = maxf(food - per_sec / HUNGER_MINUTES, 0.0)
	water = maxf(water - per_sec / THIRST_MINUTES * Weather.thirst_rate(GameState.temperature()), 0.0)
	_needs_t -= delta
	if _needs_t <= 0.0:
		_needs_t = 0.25
		needs_changed.emit(food, water)
		_warn(&"water", water, "You're parched: aim's getting shaky. Drink from the bucket (8, left click).")
		_warn(&"food", food, "Your belly's growling: you're slower to heal. Eat a crop (left click with it out).")


func _warn(id: StringName, v: float, text: String) -> void:
	if v < NEED_LOW and not _warned.get(id, false):
		_warned[id] = true
		Economy.notice.emit(text)
	elif v > NEED_LOW + 0.1:
		_warned[id] = false


## 0 when fine, rising to 1 as a need empties below NEED_LOW.
static func need_strain(v: float) -> float:
	return clampf((NEED_LOW - v) / NEED_LOW, 0.0, 1.0)


## Health regen (your "wind") multiplier: hunger and thirst each take up to 30%.
func regen_mult() -> float:
	var porch := 1.0
	if Homestead.porch_cliffs.has(player.cliff_id):
		var home := Homestead.of(player.cliff_id)
		if home != null and home.under_porch(player.global_position):
			porch = Homestead.PORCH_REGEN # resting under the shaded porch
	return (1.0 - 0.3 * need_strain(food) - 0.3 * need_strain(water)) * Perks.local_more(&"trail_rations") * porch # Perk: Second Wind


## Sprint speed multiplier: up to 8% slower when both run dry.
func sprint_mult() -> float:
	return (1.0 - 0.04 * need_strain(food) - 0.04 * need_strain(water)) * Perks.local_more(&"fleet_foot") # Perk: Fleet Foot


## Aim sway amount 0..1 (thirst counts most).
func sway() -> float:
	return clampf(need_strain(water) * 0.7 + need_strain(food) * 0.3, 0.0, 1.0)


## Owner: eat or drink what's in your hand (host spends 1 from the stockpile).
func eat_or_drink(kind: StringName) -> void:
	if downed or not FEEDS.has(kind):
		return
	var f: Array = FEEDS[kind]
	if not NEEDS_ENABLED and float(f[2]) <= 0.0:
		return # nothing to gain from eating or drinking while needs are off
	if food > 0.97 and water > 0.97 and float(f[2]) <= 0.0:
		Economy.notice.emit("You're not hungry or thirsty.")
		return
	player.net.request_consume(kind)


## Owner: use one herb from the stockpile to heal (host checks the stockpile).
func use_medicine() -> void:
	if downed or hp >= MAX_HP - 1.0:
		return
	player.net.request_consume(&"herbs")


## Owner: the host approved using an herb.
func consumed(kind: StringName) -> void:
	if FEEDS.has(kind):
		var f: Array = FEEDS[kind]
		food = clampf(food + float(f[0]), 0.0, 1.0)
		water = clampf(water + float(f[1]), 0.0, 1.0)
		hp = minf(hp + float(f[2]), MAX_HP)
		needs_changed.emit(food, water)
	else:
		hp = minf(hp + HERB_HEAL * Perks.local_more(&"herbalist"), MAX_HP) # Perk: Herbalist
	health_changed.emit(hp, MAX_HP)
	Audio.play_ui(&"herb_eat", -4.0)


## Runs on the owning peer.
func apply_damage(amount: float) -> void:
	if downed or (GameState.god_mode and GameState.debug_enabled()):
		return
	amount *= Perks.local_less(&"tough_hide") # Perk: Tough Hide
	hp = maxf(hp - amount, 0.0)
	_since_hit = 0.0
	health_changed.emit(hp, MAX_HP)
	if hp <= 0.0:
		downed = true
		_downed_left = DOWNED_TIME * Perks.local_less(&"back_in_saddle") # Perk: Back in the Saddle
		downed_changed.emit(true, _downed_left)
		# Canyon Expeditions: down on the canyon floor, your backpack drops where you fell.
		if player.on_trip():
			Expedition.report_downed(player.global_position)


func _update_interact(delta: float) -> void:
	if player.crewing != null:
		# Crewed: in a gun's seat the card shows its controls; E leaves (CrewedTurret).
		var crew_text := player.crewing.crew_prompt()
		if crew_text != _prompt:
			_prompt = crew_text
			prompt_changed.emit(crew_text)
		_hold = 0.0
		return
	var target := _look_target()
	var text := ""
	var bag := player.crop_bag
	if bag != null and bag.is_out() and CropBag.feedable(target, player.cliff_id):
		text = CropBagUI.prompt(target as Node, bag.set_crop) # the crop bag's turret card
	elif target != null and target.has_method("interact_prompt"):
		text = str(target.call("interact_prompt"))
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
	if target == null or GameState.menu_open or _far:
		_hold = 0.0
		return
	# F cycles options on things that have them (seed on a plot, item at a shop).
	if Input.is_action_just_pressed("cycle_option") and target.has_method("cycle_option"):
		target.call("cycle_option")
		_prompt = ""
	if Input.is_action_just_pressed("interact"):
		_hold = HOLD_REPEAT
		var act := Player.action_for(target)
		target.call("local_interact", false)
		if act[0] != &"" and not (player.fp_hands != null and player.fp_hands.is_playing()):
			player.act(act[0], act[1])
	elif Input.is_action_pressed("interact"):
		_hold -= delta
		if _hold <= 0.0:
			_hold = HOLD_REPEAT
			target.call("local_interact", true)


## What E would use (within INTERACT_REACH). With the crop bag out the look
## reaches CropBagUI.REACH, but past arm's length only a crop-fed turret on your
## own cliff answers (the bag's target; everything else stays at 3.5 m).
## The look target is past arm's length (only the crop bag's card shows; E does nothing).
var _far := false


func _look_target() -> Object:
	var cam := player.camera
	var from := cam.global_position
	var bag_out := player.crop_bag != null and player.crop_bag.is_out()
	var reach := CropBagUI.REACH if bag_out else INTERACT_REACH
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * reach,
			WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE | WorldLayout.LAYER_TRAP)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var c: Object = hit["collider"]
	if c == null or not c.has_method("local_interact"):
		return null
	_far = from.distance_to(hit["position"]) > INTERACT_REACH
	if _far and not (bag_out and CropBag.feedable(c, player.cliff_id)):
		return null
	return c
