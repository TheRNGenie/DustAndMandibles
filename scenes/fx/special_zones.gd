class_name SpecialZones
extends Node
## Host only: the special weapons' lasting things (SpecialRules), ticked each
## physics frame and freed when nothing is left:
##   bramble   a bouncing bramble ball's bounces, dealt as the ball reaches each
##   pods      spore pods stuck to rock or a bug, bursting near a bug or on a fuse
##   clouds    Smoke Bellows clouds: drowsy, and the crop every second inside
##   wires     trip wires: damage, a stumble and the crop for each bug crossing
##   carriers  Crop Syringe carriers passing their crop to every bug they touch

## How often clouds and carriers look for bugs (s), and how often each bug in a
## cloud (or touched by a carrier) takes the crop again.
const TICK := 0.25
const CROP_EVERY := 1.0
## Clouds: a puff this close to one of yours thickens it instead of making
## another; most clouds one shooter keeps.
const CLOUD_MERGE := 2.2
const CLOUD_MAX := 4
## Clouds: drowsy time a tick refreshes, and the small hit Corn and Chili need
## to do anything in a cloud (they ricochet / splash off it).
const CLOUD_DROWSY := 0.6
const CLOUD_CROP_HIT := 4.0
## Herbs poison in a cloud or from a carrier is worked out from this much damage.
const DOSE := 8.0
## Spore pods: most down at once per shooter (the oldest bursts early).
const POD_MAX := 6
## Wires: how close to the wire a bug counts as crossing it, how often the same
## bug can set it off again, most wires per shooter.
const WIRE_REACH := 0.8
## The bug's body reaches this far below its centre (its legs) and above (its back).
const WIRE_BELOW := 0.6
const WIRE_ABOVE := 1.8
const WIRE_REPEAT := 1.2
const WIRE_MAX := 3
## Carriers: touching means centres this close.
const CARRIER_TOUCH := 1.6

static var _inst: SpecialZones

var bramble: Array = [] # {s, t, at, r}
var pods: Array = [] # {s, at, n, bug, t, armed}
var clouds: Array = [] # {s, at, r, t, life, fx_t}
var wires: Array = [] # {s, a, b, t, left, id}
var carriers: Array = [] # {s, bug, t}
var _tick := 0.0
## [instance id of a bug, what touched it] -> last time it took the crop.
var _last: Dictionary = {}
var _now := 0.0
var _wire_ids := 0


static func of(net: Node) -> SpecialZones:
	if is_instance_valid(_inst) and not _inst.is_queued_for_deletion() and _inst.is_inside_tree():
		return _inst
	var z := SpecialZones.new()
	z.name = "SpecialZones"
	net.get_tree().current_scene.add_child(z)
	_inst = z
	return z


func _bugs() -> Array[Bug]:
	var out: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and not b.is_hidden():
			out.append(b)
	return out


## May `key` give `b` the crop again yet? (once every CROP_EVERY)
func _due(b: Bug, key: int, every: float = CROP_EVERY) -> bool:
	var k := [b.get_instance_id(), key]
	if _now - float(_last.get(k, -100.0)) < every:
		return false
	_last[k] = _now
	return true


# ------------------------------------------------------------------ adding

func add_bramble(s: SpecialRules.Shot, hits: Array, r: float) -> void:
	for h: Array in hits:
		bramble.append({"s": s, "t": float(h[0]), "at": h[1], "r": r})


func add_pod(s: SpecialRules.Shot, at: Vector3, normal: Vector3, bug: Bug, flight: float) -> void:
	var mine := pods.filter(func(p: Dictionary) -> bool: return (p["s"] as SpecialRules.Shot).net == s.net)
	if mine.size() >= POD_MAX:
		(mine[0] as Dictionary)["t"] = 0.0 # the oldest goes off now
	var fuse := SpecialRules.POD_FUSE
	pods.append({"s": s, "at": at, "n": normal, "bug": bug, "t": fuse + flight, "armed": flight})


func puff_cloud(s: SpecialRules.Shot, at: Vector3, r: float, life: float) -> void:
	var mine: Array = []
	for c: Dictionary in clouds:
		if (c["s"] as SpecialRules.Shot).net != s.net:
			continue
		mine.append(c)
		if (c["at"] as Vector3).distance_to(at) <= CLOUD_MERGE:
			c["at"] = (c["at"] as Vector3).lerp(at, 0.25)
			c["t"] = life
			c["s"] = s # (the latest crop)
			if _now - float(c["fx_t"]) > 0.45:
				c["fx_t"] = _now
				s.fx(&"sp_cloud", c["at"], Vector3.ZERO, r)
			return
	if mine.size() >= CLOUD_MAX:
		clouds.erase(mine[0])
	clouds.append({"s": s, "at": at, "r": r, "t": life, "fx_t": _now})
	s.fx(&"sp_cloud", at, Vector3.ZERO, r)


func add_wire(s: SpecialRules.Shot, a: Vector3, b: Vector3, life: float, triggers: int) -> void:
	var mine := wires.filter(func(w: Dictionary) -> bool: return (w["s"] as SpecialRules.Shot).net == s.net)
	if mine.size() >= WIRE_MAX:
		_end_wire(mine[0])
	_wire_ids += 1
	wires.append({"s": s, "a": a, "b": b, "t": life, "left": triggers, "id": -_wire_ids})
	if GameState.has_flag("--spdebug"):
		print("[special] wire %s -> %s for %.0f s" % [a, b, life])
	s.fx(&"sp_wire", a, b, life)


func add_carrier(s: SpecialRules.Shot, bug: Bug, seconds: float) -> void:
	for c: Dictionary in carriers:
		if c["bug"] == bug:
			c["t"] = seconds
			c["s"] = s
			return
	carriers.append({"s": s, "bug": bug, "t": seconds})
	s.fx(&"sp_carrier", bug.global_position, Vector3.ZERO, seconds)


# ------------------------------------------------------------------ ticking

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_now += delta
	_tick_bramble(delta)
	_tick_pods(delta)
	_tick -= delta
	var look := _tick <= 0.0
	if look:
		_tick = TICK
	var bugs: Array[Bug] = []
	if look or not wires.is_empty():
		bugs = _bugs()
	_tick_clouds(delta, bugs, look)
	_tick_wires(delta, bugs)
	_tick_carriers(delta, bugs, look)
	if bramble.is_empty() and pods.is_empty() and clouds.is_empty() and wires.is_empty() and carriers.is_empty():
		_last.clear()
		queue_free()


func _tick_bramble(delta: float) -> void:
	for i in range(bramble.size() - 1, -1, -1):
		var h: Dictionary = bramble[i]
		h["t"] = float(h["t"]) - delta
		if float(h["t"]) > 0.0:
			continue
		bramble.remove_at(i)
		var s: SpecialRules.Shot = h["s"]
		var at: Vector3 = h["at"]
		var r: float = h["r"]
		var dmg := Gun.damage_for(s.id, s.code)
		for b: Bug in _bugs():
			if b.global_position.distance_to(at) <= r + 0.4:
				SpecialRules.hit_bug(s, b, dmg, b.global_position, (b.global_position - at).normalized())


func _tick_pods(delta: float) -> void:
	for i in range(pods.size() - 1, -1, -1):
		var p: Dictionary = pods[i]
		p["t"] = float(p["t"]) - delta
		p["armed"] = float(p["armed"]) - delta
		var bug: Variant = p["bug"]
		if is_instance_valid(bug) and bug is Bug and (bug as Bug).is_alive():
			p["at"] = (bug as Bug).global_position # stuck to a bug: it rides along
		var go := float(p["t"]) <= 0.0
		if not go and float(p["armed"]) <= 0.0:
			var at: Vector3 = p["at"]
			for b: Bug in _bugs():
				if b != bug and b.global_position.distance_to(at) <= SpecialRules.POD_TRIGGER:
					go = true
					break
		if go:
			pods.remove_at(i)
			_burst(p)


func _burst(p: Dictionary) -> void:
	var s: SpecialRules.Shot = p["s"]
	var at: Vector3 = p["at"]
	var r := SpecialRules.POD_BURST * WeaponMods.mult(s.id, s.code, "radius")
	var dmg := Gun.damage_for(s.id, s.code)
	for b: Bug in _bugs():
		var d := b.global_position.distance_to(at)
		if d <= r:
			SpecialRules.hit_bug(s, b, dmg * lerpf(1.0, 0.6, d / r), b.global_position, (b.global_position - at).normalized())
	s.fx(&"sp_burst", at, p["n"], r)


func _tick_clouds(delta: float, bugs: Array[Bug], look: bool) -> void:
	for i in range(clouds.size() - 1, -1, -1):
		var c: Dictionary = clouds[i]
		c["t"] = float(c["t"]) - delta
		if float(c["t"]) <= 0.0:
			clouds.remove_at(i)
			continue
		if not look:
			continue
		var s: SpecialRules.Shot = c["s"]
		var at: Vector3 = c["at"]
		var r: float = c["r"]
		for b: Bug in bugs:
			if b.global_position.distance_to(at) > r:
				continue
			# Drowsy: half speed, and drowsy fliers sink (Bug reads is_drowsy).
			b.status.smoke(SpecialRules.CLOUD_SLOW * WeaponMods.mult(s.id, s.code, "slow"), CLOUD_DROWSY)
			if s.crop != &"" and _due(b, s.net.get_instance_id() if is_instance_valid(s.net) else 0):
				_dose(s, b)


## The crop on a bug from a cloud or a carrier (no hit of its own: Corn and
## Chili get a little one so they have something to bounce or burst off).
func _dose(s: SpecialRules.Shot, b: Bug) -> void:
	if s.crop == &"corn" or s.crop == &"firecracker_chili":
		SpecialRules.hit_bug(s, b, CLOUD_CROP_HIT, b.global_position, Vector3.UP)
	else:
		SpecialCrop.apply_status(s.crop, b, DOSE, s.k, s.src, s.cliff, s.t)


func _tick_wires(delta: float, bugs: Array[Bug]) -> void:
	for i in range(wires.size() - 1, -1, -1):
		var w: Dictionary = wires[i]
		w["t"] = float(w["t"]) - delta
		if float(w["t"]) <= 0.0:
			_end_wire(w)
			continue
		var s: SpecialRules.Shot = w["s"]
		var a: Vector3 = w["a"]
		var bb: Vector3 = w["b"]
		for b: Bug in bugs:
			if int(w["left"]) <= 0:
				break
			var p := b.global_position
			if not crosses(a, bb, p) or not _due(b, int(w["id"]), WIRE_REPEAT):
				continue
			w["left"] = int(w["left"]) - 1
			SpecialRules.hit_bug(s, b, Gun.damage_for(s.id, s.code), p, Vector3.UP)
			if b.is_alive():
				b.status.stun(SpecialRules.WIRE_STUMBLE)
				if WeaponMods.flag(s.id, s.code, "barbed"):
					b.status.slow(0.6, 1.5)
			s.fx(&"sp_wire_hit", a, bb, float(w["left"]))
		if int(w["left"]) <= 0:
			_end_wire(w)


func _end_wire(w: Dictionary) -> void:
	if not wires.has(w):
		return
	wires.erase(w)
	(w["s"] as SpecialRules.Shot).fx(&"sp_wire_end", w["a"], w["b"], 0.0)


func _tick_carriers(delta: float, bugs: Array[Bug], look: bool) -> void:
	for i in range(carriers.size() - 1, -1, -1):
		var c: Dictionary = carriers[i]
		c["t"] = float(c["t"]) - delta
		var bug: Variant = c["bug"]
		if float(c["t"]) <= 0.0 or not is_instance_valid(bug) or not (bug is Bug) or not (bug as Bug).is_alive():
			carriers.remove_at(i)
			continue
		if not look:
			continue
		var s: SpecialRules.Shot = c["s"]
		var at := (bug as Bug).global_position
		var key := (bug as Bug).get_instance_id()
		for b: Bug in bugs:
			if b == bug or b.cliff_id != (bug as Bug).cliff_id:
				continue
			if b.global_position.distance_to(at) <= CARRIER_TOUCH and _due(b, key):
				_dose(s, b)
				s.fx(&"sp_spread", at, b.global_position, 0.0)


## Is a bug centred at `p` touching the wire a-b? Close to it across the
## ground (or wall), and the wire somewhere between its feet and its back.
static func crosses(a: Vector3, b: Vector3, p: Vector3) -> bool:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var q := a + ab * t
	var off := p - q
	var up := Vector3.UP
	var across := off - up * off.dot(up)
	return across.length() <= WIRE_REACH and off.dot(up) > -WIRE_BELOW and off.dot(up) < WIRE_ABOVE


static func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t).distance_to(p)
