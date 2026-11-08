class_name SpecialRules
extends RefCounted
## Special weapons (slot 2, the Nov 2026 special weapons handoff): ten utility
## sidearms. Each has a base effect that works with no crop; a permanent crop
## upgrade (SpecialCrop, fitted at the CropBench) layers on top, applied on every
## hit at the gun's crop strength (crop_k). Host-side rules: PlayerNet routes a
## special's shot here instead of its own hitscan. Lasting things (bouncing
## bramble balls, spore pods, smoke clouds, trip wires, syringe carriers) are
## ticked by one helper node, SpecialZones. Visuals go to every peer through
## PlayerNet.special_fx (SpecialFx), tinted toward the crop's colour.
##
## Damage, magazine, range and reload are the WeaponDef's (data/weapons/special);
## the base effects' own numbers are the handoff's and live here.

const Zones := preload("res://scenes/fx/special_zones.gd")

const IDS: Array[StringName] = [&"crop_duster", &"barb_sling", &"signal_flare", &"crop_syringe", &"smoke_bellows",
	&"bramble_pistol", &"spore_launcher", &"venom_needle", &"trip_wire_gun", &"spark_pistol"]

## The HUD's "BASE:" label and the workbench's "Base Effect:" line.
const BASE: Dictionary = {&"crop_duster": "Wide Cone", &"barb_sling": "Multi-Projectile",
	&"signal_flare": "Turret Focus", &"crop_syringe": "Weaken Exoskeleton", &"smoke_bellows": "Drowsy Cloud",
	&"bramble_pistol": "Bouncing", &"spore_launcher": "Proximity Trap", &"venom_needle": "Weakened",
	&"trip_wire_gun": "Trip/Stumble", &"spark_pistol": "Chain Lightning"}

## One line on what the base effect does (workbench, field guide).
const BASE_TEXT: Dictionary = {&"crop_duster": "A wide 35 degree cone hits every bug in range.",
	&"barb_sling": "Five separate barbs a throw; each rolls the crop on its own.",
	&"signal_flare": "Every turret on both cliffs focuses the bug for 6 s.",
	&"crop_syringe": "Weakens the shell: +10% damage taken for 5 s. With a crop, the bug carries it to every bug it touches.",
	&"smoke_bellows": "A drowsy cloud: bugs inside move at half speed, fliers sink.",
	&"bramble_pistol": "The ball bounces 3 times off surfaces, hitting bugs near each bounce.",
	&"spore_launcher": "Sticky pods burst when a bug comes near, or after 3 s.",
	&"venom_needle": "Weakened: +15% damage taken for 4 s, and the crop at double strength.",
	&"trip_wire_gun": "Two anchors string a wire: bugs crossing it take damage and stumble 0.3 s.",
	&"spark_pistol": "Every shot chains to 2 more bugs nearby."}

## Weapons that apply their crop harder than the rest (the Venom Needle's concentrated dose).
const CROP_BOOST: Dictionary = {&"venom_needle": 2.0}

## The plain (no crop) colour of each weapon's shots.
const PLAIN: Dictionary = {&"crop_duster": Color("#CFC8BC"), &"barb_sling": Color("#9A9A9A"),
	&"signal_flare": Color("#FF3A26"), &"crop_syringe": Color("#D8C58A"), &"smoke_bellows": Color("#D9D6D0"),
	&"bramble_pistol": Color("#7A5A34"), &"spore_launcher": Color("#8FA070"), &"venom_needle": Color("#C8CCD2"),
	&"trip_wire_gun": Color("#B8BCC4"), &"spark_pistol": Color("#BFE2FF")}

# ------------------------------------------------------------------ base effects (the handoff's numbers)

## Crop Duster: the cone's half-angle (35 degrees across).
const DUSTER_HALF := 17.5
## Signal Flare: seconds every turret focuses the bug, and the flare's burn on it.
const FLARE_TIME := 6.0
const FLARE_BURN := 5.0
## Crop Syringe: +10% damage taken for 5 s; a crop makes it a carrier for 5 s.
const SYRINGE_WEAK := 0.10
const SYRINGE_WEAK_TIME := 5.0
const CARRIER_TIME := 5.0
## Smoke Bellows: the drowsy cloud (4 m, hangs 4 s after the last puff), half speed.
const CLOUD_RADIUS := 4.0
const CLOUD_TIME := 4.0
const CLOUD_SLOW := 0.5
## Bramble Pistol: bounces, the hit radius round each, ball speed and the
## longest leg after a bounce (m).
const BRAMBLE_BOUNCES := 3
const BRAMBLE_RADIUS := 2.0
const BRAMBLE_SPEED := 32.0
const BRAMBLE_LEG := 9.0
## Spore Launcher: proximity trigger, fuse, burst radius; launch speed and the
## floaty gravity of a pod.
const POD_TRIGGER := 2.0
const POD_FUSE := 3.0
const POD_BURST := 3.0
const POD_SPEED := 19.0
const POD_GRAVITY := 6.0
## Venom Needle: +15% damage taken for 4 s.
const VENOM_WEAK := 0.15
const VENOM_WEAK_TIME := 4.0
## Trip Wire Gun: longest wire, how long it lasts, triggers before it snaps, the stumble.
const WIRE_MAX := 15.0
const WIRE_TIME := 15.0
const WIRE_TRIGGERS := 5
const WIRE_STUMBLE := 0.3
## Spark Pistol: bugs it chains to, how far each jump reaches, the jumps' damage share.
const SPARK_CHAINS := 2
const SPARK_HOP := 5.0
const SPARK_CHAIN_SHARE := 8.0 / 12.0


static func is_special(id: StringName) -> bool:
	return IDS.has(id)


static func base_name(id: StringName) -> String:
	return str(BASE.get(id, ""))


static func base_text(id: StringName) -> String:
	return str(BASE_TEXT.get(id, ""))


## Crop strength of a shot from this gun: its rarity, times its own boost and
## the gunsmith's "dose" mods (Concentrated Dose, Coated Tip, Finer Grind).
static func crop_k(id: StringName, code: int) -> float:
	return SpecialCrop.level_k(code) * float(CROP_BOOST.get(id, 1.0)) * WeaponMods.mult(id, code, "dose")


## How much longer this gun's crop effects last ("linger" mods: Hollow Needle).
static func crop_t(id: StringName, code: int) -> float:
	return WeaponMods.mult(id, code, "linger")


## The special weapon in `owned` (id -> code), &"" if none.
static func held_in(owned: Dictionary) -> StringName:
	for id: StringName in owned:
		if is_special(id):
			return id
	return &""


## Shots of this gun's colour, tinted toward its crop.
static func shot_color(id: StringName, code: int) -> Color:
	return SpecialCrop.tint(PLAIN.get(id, Color.WHITE), SpecialCrop.crop_of(code))


## Fills itself back up while you're not puffing (like the Bee Smoker).
static func self_fills(id: StringName) -> bool:
	return id == &"smoke_bellows"


## Fired as a continuous spray (no tracer, no pellets drawn by the shooter).
static func is_spray(id: StringName) -> bool:
	return id == &"crop_duster" or id == &"smoke_bellows"


# ------------------------------------------------------------------ the shot

## One shot's context, shared by the rules and the zones.
class Shot:
	var net: PlayerNet
	var def: WeaponDef
	var id: StringName
	var code: int
	var crop: StringName
	var k: float
	## Crop durations multiplier (linger mods).
	var t := 1.0
	var src: String
	var cliff: int
	var color: Color
	var origin: Vector3

	func fx(kind: StringName, a: Vector3, b: Vector3, x: float) -> void:
		if is_instance_valid(net) and net.is_inside_tree():
			net.special_fx.rpc(kind, a, b, x, color)


static func shot_of(net: PlayerNet, def: WeaponDef, origin: Vector3, code: int) -> Shot:
	var s := Shot.new()
	s.net = net
	s.def = def
	s.id = def.id
	s.code = code
	s.crop = SpecialCrop.crop_of(code)
	s.k = crop_k(def.id, code)
	s.t = crop_t(def.id, code)
	s.src = net.player.display_name()
	s.cliff = net.player.cliff_id
	s.color = shot_color(def.id, code)
	s.origin = origin
	return s


## Host: one shot of special weapon `def` from `origin` along `dir` (normalised).
static func fire(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, code: int, seed_value: int) -> void:
	var s := shot_of(net, def, origin, code)
	var muzzle := net.player.gun.muzzle_global() if net.player.is_multiplayer_authority() else origin
	match def.id:
		&"crop_duster":
			_duster(s, dir)
		&"smoke_bellows":
			_bellows(s, dir)
		&"bramble_pistol":
			_bramble(s, dir, muzzle)
		&"spore_launcher":
			_spore(s, dir, muzzle)
		&"trip_wire_gun":
			_anchor(s, dir, muzzle)
		_:
			_hitscan(s, dir, seed_value, muzzle)


## The live bugs the shooter can affect.
static func _bugs(net: Node) -> Array[Bug]:
	var out: Array[Bug] = []
	for n: Node in net.get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and not b.is_hidden():
			out.append(b)
	return out


## Host: damage one bug and run the crop on it. `mult` is the hitbox's weak-spot
## multiplier. Draws the corn ricochet if there was one.
static func hit_bug(s: Shot, b: Bug, dmg: float, point: Vector3, dir: Vector3, mult: float = 1.0) -> void:
	if b == null or not is_instance_valid(b) or not b.is_alive():
		return
	if dmg > 0.0:
		b.receive_hit(dmg, point, dir, Gun.pierce_for(s.id, s.code), mult, s.src, s.cliff, SpecialCrop.armour_ignored(s.crop, s.k))
	var ric := SpecialCrop.on_hit(s.crop, b, maxf(dmg, 1.0), point, s.k, s.src, s.cliff, s.t)
	if ric != Vector3.INF:
		s.fx(&"sp_ricochet", point, ric, 0.0)


## The bug a hitscan ray struck (null for rock, buildings, sky).
static func bug_of(hit: Dictionary) -> Bug:
	if hit.is_empty():
		return null
	var hb := hit["collider"] as Hitbox
	var b := hb.target as Bug if hb != null else null
	return b if b != null and is_instance_valid(b) and b.is_alive() else null


## Barb Sling, Signal Flare, Crop Syringe, Venom Needle, Spark Pistol: rays
## (the Sling's five barbs are five pellets), then each gun's own effect.
static func _hitscan(s: Shot, dir: Vector3, seed_value: int, muzzle: Vector3) -> void:
	var net := s.net
	var reach := Gun.range_for(s.id, s.code)
	for d in Gun.shot_dirs(s.id, dir, seed_value, s.code):
		var hit := net.player.gun.raycast(s.origin, d, [net.player.get_rid()], reach)
		var end: Vector3 = hit["position"] if not hit.is_empty() else s.origin + d * reach
		s.fx(&"sp_shot", muzzle, end, float(IDS.find(s.id)))
		if GameState.has_flag("--spdebug"):
			print("[special] %s ray hit %s at %s" % [s.id, str(hit.get("collider")), str(hit.get("position"))])
		if hit.is_empty():
			continue
		var dist := s.origin.distance_to(end)
		var dmg := Gun.damage_at(s.id, s.code, dist)
		dmg *= Perks.gun_hit_mult(net.player.get_multiplayer_authority(), hit, dist)
		var b := bug_of(hit)
		if b == null:
			Gun.apply_hit_result(hit, d, dmg, Gun.pierce_for(s.id, s.code), s.src, s.cliff)
			s.fx(&"sp_impact", end, hit["normal"], 0.0)
			continue
		var hb := hit["collider"] as Hitbox
		hit_bug(s, b, dmg, end, d, hb.multiplier_at(end) if hb != null else 1.0)
		s.fx(&"sp_impact", end, hit["normal"], 1.0)
		match s.id:
			&"signal_flare":
				if b.is_alive():
					var ft := FLARE_TIME * WeaponMods.mult(s.id, s.code, "burn_time")
					b.status.mark(ft)
					b.status.burn(FLARE_BURN * WeaponMods.mult(s.id, s.code, "burn_dps") * GunRarity.damage_mult(WeaponMods.level(s.code)), ft, s.src, s.cliff)
					b.show_flare.rpc(ft)
			&"crop_syringe":
				if b.is_alive():
					b.status.weaken(SYRINGE_WEAK_TIME, SYRINGE_WEAK)
					s.fx(&"sp_crack", b.global_position, Vector3.ZERO, SYRINGE_WEAK_TIME)
					if s.crop != &"":
						Zones.of(net).add_carrier(s, b, CARRIER_TIME * WeaponMods.mult(s.id, s.code, "carrier"))
			&"venom_needle":
				if b.is_alive():
					b.status.weaken(VENOM_WEAK_TIME, VENOM_WEAK)
					s.fx(&"sp_crack", b.global_position, Vector3.ZERO, VENOM_WEAK_TIME)
			&"spark_pistol":
				_chain(s, b, dmg)


## Spark Pistol: from the struck bug, jump to the nearest unstruck bug within
## SPARK_HOP, then from that one, SPARK_CHAINS times.
static func _chain(s: Shot, first: Bug, dmg: float) -> void:
	var struck: Array[Bug] = [first]
	var from := first
	var hops := SPARK_CHAINS + WeaponMods.add(s.id, s.code, "chains")
	var hop := SPARK_HOP * WeaponMods.mult(s.id, s.code, "radius")
	for i in hops:
		var best: Bug = null
		var best_d := hop
		for b: Bug in _bugs(s.net):
			if struck.has(b) or b.cliff_id != first.cliff_id:
				continue
			var d := b.global_position.distance_to(from.global_position)
			if d < best_d:
				best_d = d
				best = b
		if best == null:
			return
		s.fx(&"sp_arc", from.global_position + Vector3.UP * 0.3, best.global_position + Vector3.UP * 0.3, 0.0)
		var share := 1.0 if WeaponMods.flag(s.id, s.code, "chain_full") else SPARK_CHAIN_SHARE
		hit_bug(s, best, dmg * share, best.global_position, (best.global_position - from.global_position).normalized())
		struck.append(best)
		from = best


## Crop Duster: one puff hits every bug in the cone.
static func _duster(s: Shot, dir: Vector3) -> void:
	var reach := Gun.range_for(s.id, s.code)
	var half := DUSTER_HALF * WeaponMods.mult(s.id, s.code, "spread")
	for b: Bug in _bugs(s.net):
		var at := b.global_position + Vector3.UP * 0.3
		if SpecialShotRules.in_cone(s.origin, dir, at, half, reach):
			hit_bug(s, b, Gun.damage_at(s.id, s.code, s.origin.distance_to(at)), at, (at - s.origin).normalized())
	s.fx(&"sp_dust", s.origin, dir, reach)


## Smoke Bellows: a puff lays (or thickens) a cloud where the spout points.
static func _bellows(s: Shot, dir: Vector3) -> void:
	var reach := Gun.range_for(s.id, s.code)
	var hit := s.net.player.gun.raycast(s.origin, dir, [s.net.player.get_rid()], reach)
	var at: Vector3 = (hit["position"] as Vector3) - dir * 1.0 if not hit.is_empty() else s.origin + dir * reach
	var r := CLOUD_RADIUS * WeaponMods.mult(s.id, s.code, "radius")
	Zones.of(s.net).puff_cloud(s, at, r, CLOUD_TIME * WeaponMods.mult(s.id, s.code, "effect"))


## Bramble Pistol: the ball's whole path is worked out now (straight legs,
## reflected off whatever it meets); the zones deal each bounce as it gets there.
static func _bramble(s: Shot, dir: Vector3, muzzle: Vector3) -> void:
	var net := s.net
	var bounces := BRAMBLE_BOUNCES + WeaponMods.add(s.id, s.code, "bounces")
	var from := s.origin
	var d := dir
	var leg := Gun.range_for(s.id, s.code)
	var path: Array[Vector3] = [muzzle]
	var t := 0.0
	var hits: Array = [] # [time, point]
	for i in bounces:
		var hit := net.player.gun.raycast(from + d * 0.05, d, [net.player.get_rid()], leg)
		if hit.is_empty():
			path.append(from + d * leg)
			break
		var p: Vector3 = hit["position"]
		var n: Vector3 = hit["normal"]
		t += from.distance_to(p) / BRAMBLE_SPEED
		path.append(p)
		hits.append([t, p])
		d = d.bounce(n).normalized() if n.length() > 0.1 else -d
		from = p + n * 0.1
		leg = BRAMBLE_LEG
	Zones.of(net).add_bramble(s, hits, BRAMBLE_RADIUS * WeaponMods.mult(s.id, s.code, "radius"))
	var at_t := 0.0
	for i in path.size() - 1:
		s.fx(&"sp_bramble", path[i], path[i + 1], at_t)
		at_t += path[i].distance_to(path[i + 1]) / BRAMBLE_SPEED


## Spore Launcher: lob a pod along a floaty arc; it sticks where it lands.
static func _spore(s: Shot, dir: Vector3, muzzle: Vector3) -> void:
	var net := s.net
	var vel := dir * POD_SPEED
	var p := s.origin
	var step := 0.05
	var t := 0.0
	var reach := Gun.range_for(s.id, s.code)
	var landed := {}
	while t < 4.0 and s.origin.distance_to(p) < reach:
		var nxt := p + vel * step
		vel += Vector3.DOWN * POD_GRAVITY * step
		var hit := net.player.gun.raycast(p, (nxt - p).normalized(), [net.player.get_rid()], p.distance_to(nxt) + 0.01)
		t += step
		if not hit.is_empty():
			landed = hit
			p = hit["position"]
			break
		p = nxt
	# A pod that hits a bug drops where it struck, unless Sticky Coating holds it on.
	var bug := bug_of(landed) if WeaponMods.flag(s.id, s.code, "sticky") else null
	var normal: Vector3 = landed["normal"] if not landed.is_empty() else Vector3.UP
	s.fx(&"sp_lob", muzzle, p, t)
	Zones.of(net).add_pod(s, p, normal, bug, t)


## Trip Wire Gun: the first shot sets an anchor; the second strings the wire.
static func _anchor(s: Shot, dir: Vector3, muzzle: Vector3) -> void:
	var net := s.net
	var reach := Gun.range_for(s.id, s.code)
	var hit := net.player.gun.raycast(s.origin, dir, [net.player.get_rid()], reach)
	if hit.is_empty() or bug_of(hit) != null:
		s.fx(&"sp_shot", muzzle, s.origin + dir * reach if hit.is_empty() else hit["position"], float(IDS.find(s.id)))
		Economy.notify(net.player.get_multiplayer_authority(), "The anchor needs rock or wood to bite into.")
		return
	var p: Vector3 = hit["position"]
	s.fx(&"sp_anchor", muzzle, p, 0.0)
	if GameState.has_flag("--spdebug"):
		print("[special] anchor at %s (first: %s)" % [p, str(net.get_meta(&"sp_anchor") if net.has_meta(&"sp_anchor") else null)])
	var first: Variant = net.get_meta(&"sp_anchor") if net.has_meta(&"sp_anchor") else null
	if first is Vector3 and (first as Vector3).distance_to(p) <= WIRE_MAX and (first as Vector3).distance_to(p) > 0.8:
		net.remove_meta(&"sp_anchor")
		Zones.of(net).add_wire(s, first, p, WIRE_TIME * WeaponMods.mult(s.id, s.code, "effect"),
				WIRE_TRIGGERS + WeaponMods.add(s.id, s.code, "triggers"))
	else:
		if first is Vector3:
			Economy.notify(net.player.get_multiplayer_authority(), "Too far for one wire (%d m most): that's a new first anchor." % int(WIRE_MAX))
		net.set_meta(&"sp_anchor", p)
