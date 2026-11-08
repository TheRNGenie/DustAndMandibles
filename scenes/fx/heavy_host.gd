extends Node
## Host only: the universal crop-loaded heavies' shots as they play out
## (HeavyRules has the numbers, HeavyCrop the crops). One of these sits under
## the current scene while anything is pending: shells and grenades in the air,
## spikes, bolts and bolas in flight, the Spike Driver's second pulse, and the
## Powder Keg Launcher's kegs. It frees itself when idle.
## Visuals go to every peer through PlayerNet.heavy_fx (kinds in HeavyFx); the
## hitscan guns' tracers through PlayerNet.heavy_trace.

## Blast kills read as "<name>'s blast" so KillMethod counts them as explosives.
const BLAST := "'s blast"

## Things landing later: {at, kind, ...}.
var _pending: Array[Dictionary] = []
## Live kegs, oldest first: {id, pos, n, peer, ctx, dmg, radius, lit, waited, life, fuse, prox}.
var _kegs: Array[Dictionary] = []
var _next_keg := 1
var _net_ref: WeakRef


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		queue_free()
		return
	var now := _now()
	var i := 0
	while i < _pending.size():
		if now < float(_pending[i]["at"]):
			i += 1
			continue
		var p: Dictionary = _pending[i]
		_pending.remove_at(i)
		_land(p)
	_run_kegs(delta)
	if _pending.is_empty() and _kegs.is_empty():
		queue_free()


# ------------------------------------------------------------------ the shot

## One confirmed shot of `def` (loaded with `crop`) from `net`'s player.
## `muzzle`: the host's own shot (drawn here); `remote_muzzle`: a client's.
func fire(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, code: int, seed_value: int, crop: StringName,
		muzzle: Variant, remote_muzzle: Variant) -> void:
	_net_ref = weakref(net)
	var ctx := {"crop": crop, "rarity": WeaponMods.level(code), "source": net.player.display_name(),
			"cliff": net.player.cliff_id, "net": net, "chili_r": 1.5}
	var id := def.id
	var reach := Gun.range_for(id, code)
	var start: Vector3 = muzzle if muzzle is Vector3 else (remote_muzzle if remote_muzzle is Vector3 else origin + dir * 0.8)
	match def.special:
		&"uh_cannon", &"uh_gatling", &"uh_shot":
			ctx["chili_r"] = {&"uh_cannon": 2.5, &"uh_gatling": 1.0, &"uh_shot": 0.8}[def.special]
			_hitscan(net, def, origin, dir, code, seed_value, ctx, start, muzzle is Vector3)
		&"uh_spray":
			_spray(net, def, origin, dir, code, ctx, start)
		&"uh_mortar", &"uh_drum", &"uh_keg":
			_lob(net, def, origin, dir, code, ctx, start, reach)
		&"uh_spike", &"uh_crossbow", &"uh_bola":
			_fly(net, def, origin, dir, code, ctx, start, reach)


## Hand Cannon, Harvest Gatling, Crop Blunderbuss: a ray a pellet.
func _hitscan(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, code: int, seed_value: int, ctx: Dictionary,
		start: Vector3, own: bool) -> void:
	var id := def.id
	var reach := Gun.range_for(id, code)
	var pierce := Gun.pierce_for(id, code)
	var bounce := def.special == &"uh_shot" and WeaponMods.flag(id, code, "bounce")
	var ends: Array[Vector3] = []
	for d: Vector3 in Gun.shot_dirs(id, dir.normalized(), seed_value, code):
		var hit := net.player.gun.raycast(origin, d, [net.player.get_rid()], reach)
		var end: Vector3 = hit["position"] if not hit.is_empty() else origin + d * reach
		ends.append(end)
		if hit.is_empty():
			continue
		var dmg := Gun.damage_at(id, code, origin.distance_to(end))
		dmg *= Perks.gun_hit_mult(net.player.get_multiplayer_authority(), hit, origin.distance_to(end))
		var bug := _bug_of(hit)
		if bug != null:
			var hb := hit["collider"] as Hitbox
			var ric := HeavyCrop.strike(ctx, bug, dmg, end, d, pierce, hb.multiplier_at(end))
			if ric != Vector3.INF:
				_fx(&"ricochet", end, ric, HeavyRules.pack(ctx["crop"], 0), 0.0)
			if own:
				net.player.gun.show_impact(hit, d, true, dmg)
		else:
			Gun.apply_hit_result(hit, d, dmg, pierce, String(ctx["source"]), int(ctx["cliff"]))
			if own:
				net.player.gun.show_impact(hit, d)
			if bounce and not (hit["collider"] is Hitbox):
				# Scatter Bore: off the rock once, a little weaker.
				var out := ArmoryHeavyRules.bounce_dir(d, hit["normal"])
				var from: Vector3 = end + (hit["normal"] as Vector3).normalized() * 0.03
				var left := maxf(reach - origin.distance_to(end), 0.0)
				if left > 1.0:
					var hit2 := net.player.gun.raycast(from, out, [net.player.get_rid(), hit["rid"]], left)
					var b2 := _bug_of(hit2)
					if b2 != null:
						HeavyCrop.strike(ctx, b2, dmg * HeavyRules.SCATTER_BOUNCE_SHARE, hit2["position"], out, pierce)
	# Tracers: drawn here for the host's own shot; everyone else gets them from
	# heavy_trace (a client shooter draws its own, predicted).
	var x := HeavyRules.pack(ctx["crop"], ends.size())
	if own:
		HeavyFx.traces(def.id, start, ends, ctx["crop"])
	net.heavy_trace.rpc(def.id, start, PackedVector3Array(ends), x)


## Crop Sprayer: every bug in the cone.
func _spray(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, code: int, ctx: Dictionary, start: Vector3) -> void:
	var reach := Gun.range_for(def.id, code)
	var cone := HeavyRules.spray_cone(code)
	var dmg := Gun.damage_for(def.id, code)
	ctx["chili_r"] = 1.2
	for b in _bugs():
		var p := _aim_point(b)
		if HeavyRules.in_cone(origin, dir, p, cone, reach):
			HeavyCrop.strike(ctx, b, dmg, p, dir, false)
	_fx(&"spray", start, dir.normalized(), HeavyRules.pack(ctx["crop"], cone), reach)


## Mortar, Drum Launcher, Powder Keg Launcher: a lob onto the aim point.
func _lob(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, code: int, ctx: Dictionary, start: Vector3, reach: float) -> void:
	var hit := net.player.gun.raycast(origin, dir, [net.player.get_rid()], reach)
	var land: Vector3
	var up := Vector3.UP
	if hit.is_empty():
		# Into the open: it comes down on whatever is under the end of the ray.
		var end := origin + dir.normalized() * reach
		var down := net.player.gun.raycast(end, Vector3.DOWN, [net.player.get_rid()], 400.0)
		land = down["position"] if not down.is_empty() else end
		up = down["normal"] if not down.is_empty() else Vector3.UP
	else:
		land = hit["position"]
		up = hit["normal"]
	var kind := def.special
	if kind == &"uh_mortar":
		land = HeavyRules.lob_target(start, land, HeavyRules.MORTAR_MIN)
	var span: Vector2 = {&"uh_mortar": HeavyRules.MORTAR_FLIGHT, &"uh_drum": HeavyRules.DRUM_FLIGHT, &"uh_keg": HeavyRules.KEG_FLIGHT}[kind]
	var flight := HeavyRules.lob_flight(start.distance_to(land), span, reach)
	var arc := 1.0 if kind == &"uh_mortar" else (2.0 if kind == &"uh_keg" else 0.0)
	_fx(&"lob", start, land, HeavyRules.pack(ctx["crop"], flight * 100.0), arc)
	var dmg := Gun.damage_for(def.id, code)
	var radius := (HeavyRules.MORTAR_RADIUS if kind == &"uh_mortar" else (HeavyRules.DRUM_RADIUS if kind == &"uh_drum" else HeavyRules.KEG_RADIUS)) \
			* HeavyRules.radius_mult(def.id, code)
	var edge := HeavyRules.MORTAR_EDGE if kind == &"uh_mortar" else (HeavyRules.DRUM_EDGE if kind == &"uh_drum" else HeavyRules.KEG_EDGE)
	_pending.append({"at": _now() + flight, "kind": kind, "pos": land + up * 0.2, "n": up, "ctx": ctx, "dmg": dmg,
			"radius": radius, "edge": edge, "code": code, "peer": net.player.get_multiplayer_authority(),
			"cluster": kind == &"uh_mortar" and WeaponMods.flag(def.id, code, "cluster")})


## Spike Driver, Crop Crossbow, Bola Launcher: a projectile that flies, then lands.
func _fly(net: PlayerNet, def: WeaponDef, origin: Vector3, dir: Vector3, code: int, ctx: Dictionary, start: Vector3, reach: float) -> void:
	var hit := net.player.gun.raycast(origin, dir, [net.player.get_rid()], reach)
	var end: Vector3 = hit["position"] if not hit.is_empty() else origin + dir.normalized() * reach
	var n: Vector3 = hit["normal"] if not hit.is_empty() else -dir.normalized()
	var speed: float = {&"uh_spike": HeavyRules.SPIKE_SPEED, &"uh_crossbow": HeavyRules.BOLT_SPEED, &"uh_bola": HeavyRules.BOLA_SPEED}[def.special]
	var flight := maxf(start.distance_to(end) / speed, 0.03)
	var bug := _bug_of(hit)
	var mult := (hit["collider"] as Hitbox).multiplier_at(end) if bug != null else 1.0
	if GameState.has_flag("--heavylog"):
		print("[heavy] %s flies %.1f m, hit %s, bug %s" % [def.special, start.distance_to(end), "nothing" if hit.is_empty() else str(hit["collider"]), bug])
	var stuck := 0.0
	if not hit.is_empty() and bug == null:
		stuck = HeavyRules.SPIKE_LINGER if def.special == &"uh_spike" else HeavyRules.BOLT_LINGER
	_fx(StringName(String(def.special).substr(3)), start, end, HeavyRules.pack(ctx["crop"], flight * 100.0), stuck, n)
	if hit.is_empty() and def.special != &"uh_spike":
		return # into the sky
	_pending.append({"at": _now() + flight, "kind": def.special, "pos": end, "n": n, "dir": dir.normalized(), "ctx": ctx,
			"dmg": Gun.damage_for(def.id, code), "code": code, "bug": weakref(bug) if bug != null else null, "mult": mult,
			"wall": not hit.is_empty() and bug == null, "id": def.id})


# ------------------------------------------------------------------ landing

func _land(p: Dictionary) -> void:
	var ctx: Dictionary = p["ctx"]
	match StringName(p["kind"]):
		&"uh_mortar", &"uh_drum":
			_blast(ctx, p["pos"], p["n"], float(p["radius"]), float(p["dmg"]), float(p["edge"]))
			if bool(p.get("cluster", false)):
				for k in HeavyRules.CLUSTER_COUNT:
					var a := TAU * (float(k) + randf() * 0.4) / HeavyRules.CLUSTER_COUNT
					var off := Vector3(cos(a), 0.0, sin(a)) * HeavyRules.CLUSTER_SCATTER
					_pending.append({"at": _now() + 0.25 + 0.08 * k, "kind": &"bomblet", "pos": (p["pos"] as Vector3) + off,
							"n": p["n"], "ctx": ctx, "dmg": float(p["dmg"]) * HeavyRules.CLUSTER_SHARE})
		&"bomblet":
			_blast(ctx, p["pos"], p["n"], HeavyRules.CLUSTER_RADIUS, float(p["dmg"]), HeavyRules.MORTAR_EDGE)
		&"chili":
			_blast(ctx, p["pos"], p["n"], float(p["radius"]), float(p["dmg"]), 0.5, false)
		&"uh_keg":
			_lay_keg(p)
		&"uh_spike":
			_spike(p, 1.0, true)
		&"spike_pulse":
			_spike(p, HeavyRules.SPIKE_PULSE_SHARE, false)
		&"uh_crossbow":
			_bolt(p)
		&"uh_bola":
			_bola(p)


## A blast: every bug in the radius, less toward the edge; then the crop on each
## (corn bounces once off the nearest; chili sets off a second blast).
func _blast(ctx: Dictionary, center: Vector3, n: Vector3, radius: float, dmg: float, edge: float, chili_again: bool = true) -> void:
	var source := String(ctx["source"]) + BLAST
	var cliff := int(ctx["cliff"])
	var area := ctx.duplicate()
	area["area"] = true
	area["source"] = source
	var hits: Array = []
	for b in _bugs():
		var d := b.global_position.distance_to(center)
		var share := HeavyRules.blast_share(d, radius, edge)
		if share > 0.0:
			hits.append([d, b, share])
	hits.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
	var hit_cliff := -1
	for i in hits.size():
		var b: Bug = hits[i][1]
		if not is_instance_valid(b) or not b.is_alive():
			continue
		if hit_cliff < 0 and b.is_climbing():
			hit_cliff = b.cliff_id
		area["first"] = i == 0
		var ric := HeavyCrop.strike(area, b, dmg * float(hits[i][2]), b.global_position, (b.global_position - center).normalized(), true)
		if ric != Vector3.INF:
			_fx(&"ricochet", b.global_position, ric, HeavyRules.pack(ctx["crop"], 0), 0.0)
	BossFx.on_splash(hit_cliff if hit_cliff >= 0 else WorldLayout.other_cliff(cliff), center, radius, dmg, source, cliff)
	_fx(&"blast", center, n, HeavyRules.pack(ctx["crop"], radius * 10.0), 0.0)
	if chili_again and StringName(ctx["crop"]) == &"firecracker_chili":
		# Chili: the shell's blast, then the chili's own.
		_pending.append({"at": _now() + 0.22, "kind": &"chili", "pos": center, "n": n, "ctx": ctx,
				"dmg": dmg * HeavyCrop.CHILI_BLAST_SHARE, "radius": HeavyCrop.chili_blast_radius(radius, int(ctx["rarity"]))})


## Spike Driver: the spike lands. `share` 1 for the spike, less for the Resonant
## Spike's later pulse (which shakes nothing loose).
func _spike(p: Dictionary, share: float, first: bool) -> void:
	var ctx: Dictionary = p["ctx"]
	var code := int(p["code"])
	var at: Vector3 = p["pos"]
	var dmg := float(p["dmg"])
	var ref: WeakRef = p.get("bug")
	var struck: Bug = ref.get_ref() as Bug if ref != null else null
	if first and struck != null and struck.is_alive():
		HeavyCrop.strike(ctx, struck, dmg, at, p["dir"], false, float(p["mult"]))
	var wave := HeavyRules.spike_wave(code)
	var knock := HeavyRules.spike_knock(code)
	var area := ctx.duplicate()
	area["area"] = true
	var i := 0
	for b in _bugs():
		if b == struck:
			continue
		var d := b.global_position.distance_to(at)
		if d > wave:
			continue
		area["first"] = i == 0
		i += 1
		HeavyCrop.strike(area, b, dmg * HeavyRules.SPIKE_WAVE_SHARE * share, b.global_position, (b.global_position - at).normalized(), false)
		if first and d <= knock and b.is_alive() and b.boss == null and b.is_climbing():
			b.knock_off(String(ctx["source"]), int(ctx["cliff"])) # shaken clean off the wall
	if first and struck != null and struck.is_alive() and struck.boss == null and struck.is_climbing():
		struck.knock_off(String(ctx["source"]), int(ctx["cliff"]))
	_fx(&"wave", at, p["n"], HeavyRules.pack(ctx["crop"], wave * 10.0), share)
	if first and WeaponMods.flag(StringName(p["id"]), code, "pulse"):
		var again := p.duplicate()
		again["kind"] = &"spike_pulse"
		again["at"] = _now() + HeavyRules.SPIKE_PULSE_DELAY
		again["bug"] = null
		_pending.append(again)


## Crop Crossbow: the bolt arrives (on the bug it was fired at, wherever it went).
func _bolt(p: Dictionary) -> void:
	var ref: WeakRef = p.get("bug")
	var b: Bug = ref.get_ref() as Bug if ref != null else null
	if b == null or not b.is_alive():
		return
	var ctx: Dictionary = p["ctx"]
	var at := _aim_point(b)
	var ric := HeavyCrop.strike(ctx, b, float(p["dmg"]), at, p["dir"], false, float(p["mult"]))
	if ric != Vector3.INF:
		_fx(&"ricochet", at, ric, HeavyRules.pack(ctx["crop"], 0), 0.0)
	if b.is_alive() and WeaponMods.flag(StringName(p["id"]), int(p["code"]), "bleed"):
		b.status.burn(HeavyRules.BLEED_DAMAGE / HeavyRules.BLEED_TIME, HeavyRules.BLEED_TIME, String(ctx["source"]), int(ctx["cliff"]))
	_fx(&"stick", at, p["dir"], HeavyRules.pack(ctx["crop"], 0), HeavyRules.BOLT_LINGER)


## Bola Launcher: the bola wraps its bug (held fast) and clips one or two beside it.
func _bola(p: Dictionary) -> void:
	var ref: WeakRef = p.get("bug")
	var b: Bug = ref.get_ref() as Bug if ref != null else null
	var ctx: Dictionary = p["ctx"]
	var code := int(p["code"])
	if b == null or not b.is_alive():
		_fx(&"bola_drop", p["pos"], p["n"], HeavyRules.pack(ctx["crop"], 0), 0.0)
		return
	var at := _aim_point(b)
	var hold := HeavyRules.bola_hold(b.boss != null, code)
	HeavyCrop.strike(ctx, b, float(p["dmg"]), at, p["dir"], false, float(p["mult"]))
	if b.is_alive():
		b.status.root(hold)
	_fx(&"wrap", at, Vector3.UP, HeavyRules.pack(ctx["crop"], hold * 100.0), float(b.spec.get("body_radius", 0.5)))
	var side := ctx.duplicate()
	side["area"] = true
	var near := HeavyCrop.bugs_near(b.global_position, HeavyRules.bola_swing(code), b)
	near.sort_custom(func(a: Bug, c: Bug) -> bool:
		return a.global_position.distance_to(b.global_position) < c.global_position.distance_to(b.global_position))
	for i in mini(near.size(), HeavyRules.bola_clips(code)):
		var o: Bug = near[i]
		HeavyCrop.strike(side, o, float(p["dmg"]) * HeavyRules.BOLA_SIDE_SHARE, _aim_point(o), (o.global_position - at).normalized(), false)
		_fx(&"clip", at, _aim_point(o), HeavyRules.pack(ctx["crop"], 0), 0.0)


# ------------------------------------------------------------------ kegs

func _lay_keg(p: Dictionary) -> void:
	var peer := int(p["peer"])
	var mine: Array[Dictionary] = []
	for k in _kegs:
		if int(k["peer"]) == peer:
			mine.append(k)
	if HeavyRules.keg_to_pop(mine.size()) >= 0:
		_keg_boom(mine[0])
	var code := int(p["code"])
	var pos: Vector3 = p["pos"]
	var lit := -1.0
	if _in_wave() and _nearest_bug(pos) <= HeavyRules.KEG_LIGHT_NEAR:
		lit = 0.0 # fired into a fight: the fuse is burning
	var k := {"id": _next_keg, "pos": pos, "n": p["n"], "peer": peer, "ctx": p["ctx"], "dmg": float(p["dmg"]),
			"radius": float(p["radius"]), "lit": lit, "waited": 0.0, "life": HeavyRules.keg_life(code),
			"fuse": HeavyRules.keg_fuse(code), "prox": HeavyRules.keg_prox(code)}
	_next_keg += 1
	_kegs.append(k)
	_fx(&"keg", pos, p["n"], HeavyRules.pack((p["ctx"] as Dictionary)["crop"], _keg_tag(k)), lit)


func _run_kegs(delta: float) -> void:
	if _kegs.is_empty():
		return
	var wave := _in_wave()
	var i := 0
	while i < _kegs.size():
		var k: Dictionary = _kegs[i]
		if float(k["lit"]) >= 0.0:
			k["lit"] = float(k["lit"]) + delta
		elif wave:
			k["waited"] = float(k["waited"]) + delta
		var what := HeavyRules.keg_tick(float(k["lit"]), float(k["fuse"]), float(k["waited"]), float(k["life"]),
				_nearest_bug(k["pos"]), float(k["prox"]))
		if what == "boom":
			_keg_boom(k)
			continue
		if what == "gone":
			_kegs.remove_at(i)
			_fx(&"keg_gone", k["pos"], Vector3.ZERO, _keg_tag(k), 0.0)
			continue
		i += 1


func _keg_boom(k: Dictionary) -> void:
	_kegs.erase(k)
	_fx(&"keg_gone", k["pos"], Vector3.ZERO, _keg_tag(k), 1.0)
	_blast(k["ctx"], k["pos"], k["n"], float(k["radius"]), float(k["dmg"]), HeavyRules.KEG_EDGE)


## A keg's id as the visuals know it (0..999).
static func _keg_tag(k: Dictionary) -> float:
	return fposmod(float(k["id"]), 1000.0)


func _nearest_bug(at: Vector3) -> float:
	var best := INF
	for b in _bugs():
		best = minf(best, b.global_position.distance_to(at) - float(b.spec.get("body_radius", 0.0)) * 0.5)
	return best


# ------------------------------------------------------------------ helpers

## Every peer's visual, through the last shooter's PlayerNet (any of them sends the same rpc).
func _fx(kind: StringName, a: Vector3, b: Vector3, x: float, y: float, n: Vector3 = Vector3.ZERO) -> void:
	var pn := _net_ref.get_ref() as PlayerNet if _net_ref != null else null
	if pn != null and pn.is_inside_tree():
		pn.heavy_fx.rpc(kind, a, b, x, y, n)
	else:
		HeavyFx.play(kind, a, b, x, y, n)


func _bugs() -> Array[Bug]:
	var out: Array[Bug] = []
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b != null and b.is_alive() and not b.is_hidden():
			out.append(b)
	return out


func _bug_of(hit: Dictionary) -> Bug:
	if hit.is_empty():
		return null
	var hb := hit["collider"] as Hitbox
	if hb == null:
		return null
	var b := hb.target as Bug
	return b if b != null and is_instance_valid(b) else null


static func _aim_point(b: Bug) -> Vector3:
	return b.global_position + b.global_basis.y * float(b.spec.get("clearance", 0.5)) * 0.5


func _in_wave() -> bool:
	return GameState.phase == GameState.Phase.WAVE


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

