extends BossBrain
## The Hive Mother (Story, chapter 10: The Reckoning). The Queen's mother,
## sealed in the lower hive until the board's second blast opened it: blind,
## scarred, crusted with hive amber. Three phases by her health:
## 1. Brood calls (her back glows through the crust for 2 s, then wolf spiders
##    and a brood mother up the wall beside her) and AMBER HAIL: rings glow
##    round 2 turrets on the far cliff for 1.6 s, then chunks of her crust land
##    there and gum every turret within 3.5 m (shoot the cocoons free).
## 2. Below 60%: hail on 3 turrets, scorpions join the brood, and every ~20 s
##    a DEEP HUM (a pale pulse round her): her brood within 30 m climbs 50%
##    faster for 6 s.
## 3. Below 30%: her amber crust falls away and HATCHES (hive drones), she
##    climbs 45% faster and takes 25% more, hails 4 turrets, hums every ~14 s
##    and shrieks (the Queen's stun ring) every ~15 s.
## The amber geode on her brow is her weak spot; her old plates are armoured
## from the front. The Reckoning pins her (IronMandible): when Silas Kettle's
## charge is lit under her gallery she stops dead and can't be hurt until it
## goes off. Pure numbers in _rules_mother.gd.

const Rules := preload("res://scenes/bugs/bosses/_rules_mother.gd")
const Cicada := preload("res://scenes/bugs/bosses/_rules_b.gd")
const BROOD_CHARGE := 2.0
const HAIL_CHARGE := 1.6
const HAIL_FLIGHT := 1.1
const HUM_CHARGE := 1.8
const SHRIEK_CHARGE := 2.5
const SHRIEK_RADIUS := 7.0
const SHRIEK_STUN := 3.5
const RESIN_SECONDS := 7.0
const RESIN_HP := 110.0
const REACH := 130.0
const AMBER := Color("#FFA62B")
const PALE := Color("#DDE8F0")
const SHRIEK := Color("#FF6A3D")

## Host: set by The Reckoning while Silas's fuse burns.
var pinned := false
var _phase := 1
var _brood_cd := 6.0
var _hail_cd := 4.0
var _hum_cd := 8.0
var _shriek_cd := 6.0
var _charging := &""
var _charge := 0.0
var _center := Vector3.ZERO
var _hail_at: Array = []
## Every peer.
var _show := &""
var _show_t := 0.0
var _enraged := false
var _pinned_seen := false
var _crown: MeshInstance3D
var _belly: MeshInstance3D
var _mouth: MeshInstance3D


func _attach() -> void:
	_crown = BossFx.glow_blob(0.36, AMBER)
	bug.add_child(_crown)
	_belly = BossFx.glow_blob(1.6, AMBER)
	bug.add_child(_belly)
	_mouth = BossFx.glow_blob(0.5, PALE)
	bug.add_child(_mouth)
	_place_glows()
	BossFx.set_glow(_belly, 0.0)
	BossFx.set_glow(_mouth, 0.0)


func _place_glows() -> void:
	_crown.position = local(bug.spec.get("crown", Vector3.ZERO))
	_belly.position = local(bug.spec.get("belly", Vector3.ZERO))
	_mouth.position = local(bug.spec.get("mouth_at", Vector3.ZERO))


# ------------------------------------------------------------------ host

func set_pinned(on: bool) -> void:
	if on == pinned:
		return
	pinned = on
	_charging = &""
	send(&"pinned", [on])


func think(delta: float) -> bool:
	if not bug.is_alive():
		return false
	if pinned:
		return true # holds still on the wall while Silas's fuse burns
	var p := Rules.phase(bug.health.hp / maxf(bug.health.max_hp, 1.0))
	if p != _phase:
		_phase = p
		send(&"phase", [p])
		match p:
			2:
				notify_defenders("The Hive Mother hums! Her brood climbs faster while she does: splash the wall round her.")
			3:
				notify_defenders("The Hive Mother's amber crust is falling away, and it's HATCHING!")
				spawn_minions(&"hive_drone", Rules.CRUST_HATCH, 3.0)
	if _charging != &"":
		_charge -= delta
		if _charge <= 0.0:
			var what := _charging
			_charging = &""
			match what:
				&"brood":
					_call_brood()
				&"hail":
					_hail()
				&"hum":
					_hum()
				&"shriek":
					_shriek()
		return _charging == &"shriek" or _charging == &"hum"
	if not (bug.state in [Bug.State.CLIMBING, Bug.State.CRESTING, Bug.State.BREACHING]):
		return false
	_brood_cd -= delta
	_hail_cd -= delta
	if Rules.hum_every(_phase) > 0.0:
		_hum_cd -= delta
	if Rules.shriek_every(_phase) > 0.0:
		_shriek_cd -= delta
	if _shriek_cd <= 0.0 and Rules.shriek_every(_phase) > 0.0:
		var pts: Array[Vector3] = []
		for t in far_turrets(REACH):
			pts.append(t.global_position)
		if pts.is_empty():
			_shriek_cd = 3.0
		else:
			_shriek_cd = Rules.shriek_every(_phase)
			_center = Cicada.densest(pts, SHRIEK_RADIUS)
			_begin(&"shriek", SHRIEK_CHARGE, [_center])
			return true
	if _hum_cd <= 0.0 and Rules.hum_every(_phase) > 0.0:
		_hum_cd = Rules.hum_every(_phase)
		_begin(&"hum", HUM_CHARGE, [])
		return true
	if _brood_cd <= 0.0:
		_brood_cd = Rules.brood_every(_phase)
		_begin(&"brood", BROOD_CHARGE, [])
		return false
	if _hail_cd <= 0.0 and (not bug.is_climbing() or bug.climb_y > 3.0):
		_hail_at = _pick_hail()
		if _hail_at.is_empty():
			_hail_cd = 2.0
		else:
			_hail_cd = Rules.hail_every(_phase)
			_begin(&"hail", HAIL_CHARGE, [_hail_at])
	return false


func _begin(what: StringName, seconds: float, args: Array) -> void:
	_charging = what
	_charge = seconds
	send(&"charge", [what, seconds] + args)


func _call_brood() -> void:
	var near := 0
	for c in bug.get_parent().get_children():
		var b := c as Bug
		if b != null and b != bug and b.is_alive() and b.cliff_id == bug.cliff_id and b.global_position.distance_to(bug.global_position) < 20.0:
			near += 1
	var called := 0
	for e: Array in Rules.brood(_phase):
		var n := Rules.room(near + called, int(e[1]))
		if n > 0:
			spawn_minions(e[0], n, 3.5)
			called += n
	send(&"brood", [called])
	if called > 0:
		notify_defenders("The Hive Mother called up a brood of %d!" % called)


## Turrets for the hail: the nearest few on the far cliff, not already gummed,
## spread out (no two picks within a hail radius of each other).
func _pick_hail() -> Array:
	var f := fx()
	if f == null:
		return []
	var options: Array[Turret] = []
	for t in far_turrets(115.0):
		if not f.is_webbed(t):
			options.append(t)
	options.sort_custom(func(a: Turret, b: Turret) -> bool:
		return a.global_position.distance_squared_to(bug.global_position) < b.global_position.distance_squared_to(bug.global_position))
	var out: Array = []
	for t in options:
		var ok := true
		for q: Vector3 in out:
			if q.distance_to(t.global_position) < Rules.HAIL_RADIUS * 1.5:
				ok = false
		if ok:
			out.append(t.global_position)
		if out.size() >= Rules.hail_targets(_phase):
			break
	return out


func _hail() -> void:
	if not bug.is_alive():
		return
	var spots := _hail_at.duplicate()
	send(&"hail", [spots])
	var hp := RESIN_HP * Defs.WAVE_CONFIG.damage_scale(GameState.wave) * 0.5
	bug.get_tree().create_timer(HAIL_FLIGHT).timeout.connect(func() -> void:
		var f := fx()
		if f == null:
			return
		var n := 0
		for t in far_turrets(REACH + 10.0):
			for q: Vector3 in spots:
				if t.global_position.distance_to(q) <= Rules.HAIL_RADIUS and not f.is_webbed(t):
					f.web(t, RESIN_SECONDS, hp)
					n += 1
					break
		if n > 0:
			notify_defenders("The Hive Mother's amber hail gummed %d turret%s!" % [n, "" if n == 1 else "s"]))


func _hum() -> void:
	var n := 0
	for c in bug.get_parent().get_children():
		var b := c as Bug
		if b != null and b != bug and b.is_alive() and b.global_position.distance_to(bug.global_position) <= Rules.HUM_RADIUS:
			b.status.slow(Rules.HUM_SPEED, Rules.HUM_SECONDS) # (a "slow" over 1 is a haste)
			n += 1
	send(&"hum", [n])


func _shriek() -> void:
	var n := 0
	for t in far_turrets(REACH + SHRIEK_RADIUS):
		if t.global_position.distance_to(_center) <= SHRIEK_RADIUS and fx() != null:
			fx().stun(t, SHRIEK_STUN)
			n += 1
	send(&"shriek", [_center])
	if n > 0:
		notify_defenders("The Hive Mother's shriek stunned %d turret%s!" % [n, "" if n == 1 else "s"])


func body_damage(damage: float, _point: Vector3, _source: String, _source_cliff: int) -> float:
	if pinned:
		return 0.0
	return damage * Rules.damage_taken(_phase)


func speed_mult() -> float:
	if pinned:
		return 0.0
	return Rules.speed(_phase if host() else (3 if _enraged else 1))


func on_death(source: String, _source_cliff: int) -> void:
	notify_defenders("%s brought down THE HIVE MOTHER!" % who(source))
	send(&"dead", [])


# ------------------------------------------------------------------ every peer

func on_event(kind: StringName, args: Array) -> void:
	var f := fx()
	match kind:
		&"phase":
			_enraged = int(args[0]) >= 3
			Audio.play_at(&"mother_roar", world(bug.spec.get("mouth_at", Vector3.ZERO)), 4.0, 1.0)
			if f != null:
				f.shake(bug.global_position, 0.8)
				if _enraged:
					# The crust comes away in a shower of amber.
					for k in 8:
						f.pop(bug.global_position + Vector3(randf_range(-2.5, 2.5), randf_range(0, 3.5), randf_range(-2.5, 2.5)), AMBER, 1.4)
					f.rocks(bug.global_position, 1.5)
		&"pinned":
			_pinned_seen = bool(args[0])
			if f != null and _pinned_seen:
				f.shake(bug.global_position, 0.5)
			Audio.play_at(&"ground_rumble", bug.global_position, 4.0, 0.6)
		&"charge":
			_show = args[0]
			_show_t = float(args[1])
			match _show:
				&"brood":
					Audio.play_at(&"beetle_hiss", bug.global_position, 4.0, 0.4)
				&"hail":
					if f != null:
						for q: Vector3 in (args[2] as Array):
							f.ground_ring(q, Rules.HAIL_RADIUS, AMBER, HAIL_CHARGE)
					Audio.play_at(&"bell", bug.global_position, -4.0, 0.45)
				&"hum":
					Audio.play_at(&"ground_rumble", bug.global_position, 6.0, 0.5)
				&"shriek":
					if f != null:
						f.ground_ring(args[2], SHRIEK_RADIUS, SHRIEK, SHRIEK_CHARGE)
					Audio.play_at(&"bell", args[2], -2.0, 0.5)
		&"brood":
			_show = &""
			if f != null:
				f.pop(world(bug.spec.get("belly", Vector3.ZERO)), AMBER, 2.8)
				f.dust(bug.global_position, Vector3.UP, 3.0)
			Audio.play_at(&"beetle_hiss", bug.global_position, 6.0, 0.6)
		&"hail":
			_show = &""
			if f != null:
				for q: Vector3 in (args[0] as Array):
					f.lob(world(bug.spec.get("belly", Vector3.ZERO)), q, HAIL_FLIGHT, AMBER)
			Audio.play_at(&"mortar", bug.global_position, 0.0, 0.6)
		&"hum":
			_show = &""
			if f != null:
				f.shockwave(bug.global_position, bug.global_position + Vector3.UP * 0.5, Rules.HUM_RADIUS * 0.5, PALE)
				f.shake(bug.global_position, 0.35)
			Audio.play_at(&"ground_rumble", bug.global_position, 8.0, 0.4)
		&"shriek":
			_show = &""
			var head := world(bug.spec.get("mouth_at", Vector3.ZERO))
			if f != null:
				f.shockwave(head, (args[0] as Vector3) + Vector3.UP, SHRIEK_RADIUS, SHRIEK)
				f.shake(args[0], 0.6)
			Audio.play_at(&"mother_roar", head, 6.0, 0.95)
			Audio.play_at(&"thunder", args[0], 2.0, 1.1)
		&"dead":
			if f != null:
				f.shake(bug.global_position, 1.2)
				f.pop(world(bug.spec.get("crown", Vector3.ZERO)), AMBER, 3.5)
				f.rocks(bug.global_position, 2.5)
			Audio.play_at(&"mother_roar", bug.global_position, 6.0, 0.85)


func visual(delta: float) -> void:
	age += delta
	if _show_t > 0.0:
		_show_t -= delta
		if _show_t <= 0.0 and not host():
			_show = &""
	if host() and _charging == &"":
		_show = &""
	if _crown == null:
		return
	_place_glows()
	# The geode smoulders always (it's the target) and blazes when she's enraged or pinned.
	var crown := 0.35 + 0.1 * sin(age * 2.0)
	if _enraged:
		crown = 0.6 + 0.25 * sin(age * 8.0)
	if _pinned_seen:
		crown = 0.85 + 0.15 * sin(age * 30.0)
	BossFx.set_glow(_crown, crown)
	_crown.scale = Vector3.ONE * (0.8 + crown * 0.5)
	var belly := 0.0
	if _show == &"brood" or _show == &"hail":
		belly = 0.55 + 0.45 * sin(age * 14.0)
	BossFx.set_glow(_belly, belly)
	_belly.scale = Vector3.ONE * (0.7 + belly * 0.6)
	var mouth := 0.0
	if _show == &"hum" or _show == &"shriek":
		mouth = 0.6 + 0.4 * sin(age * 24.0)
	BossFx.set_glow(_mouth, mouth)


func hud_status() -> String:
	if _pinned_seen:
		return "PINNED"
	match _show:
		&"brood":
			return "CALLING HER BROOD"
		&"hail":
			return "AMBER HAIL"
		&"hum":
			return "HUMMING"
		&"shriek":
			return "SHRIEKING"
	return "ENRAGED" if _enraged else ""
