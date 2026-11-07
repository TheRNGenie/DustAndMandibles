class_name HyperLearn
extends Node
## Teaches the Hyper CPU its routes by trial: a real bot body (HyperPilot on a
## Player) flies the same leg again and again under different HyperPlans, and
## a cross-entropy search keeps whatever got there fastest. The winners go in
## the route book (data/hyper_routes.json), keyed "<map>/<leg>".
##
##   --hyperlearn=<leg>[,<leg>...] [--simspeed=N] [--hyperiters=N] [--hyperpop=N]
##   --hypershow[=<leg>,...]   fly the book's routes once each and print them
## Legs: run (along your own lip), cross (to your partner's lip), ship (from
## your lip onto the airship), home (off the airship to your lip).

const BOOK := "res://data/hyper_routes.json"
const LEGS := ["run", "cross", "ship", "home", "far", "tour"]
## Each candidate flies the leg from these offsets of its start (m along the
## lip, m back from it): a plan has to work from near enough, not one spot.
const STARTS := [Vector2(0, 0), Vector2(3, 2)]

var world: Node3D
var cliffs: CliffBuilder
var bot: Player
var pilot: HyperPilot
var cid := 0
var _rng := RandomNumberGenerator.new()


static func learning() -> bool:
	return GameState.has_flag("--hyperlearn") or GameState.flag_value("--hyperlearn") != ""


static func wanted() -> bool:
	return learning() or reel() or GameState.has_flag("--hypershow") or GameState.flag_value("--hypershow") != ""


## --hyperreel[=<leg>,...]: fly the book's routes in real time behind a chase
## camera, for recording with --write-movie.
static func reel() -> bool:
	return GameState.has_flag("--hyperreel") or GameState.flag_value("--hyperreel") != ""


## The bot body: a Player the pilot drives (host only; kept off the spawner).
static func spawn_bot(w: Node3D, cliff: int, at: Vector3) -> Player:
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	var pl := HyperPilot.new()
	pl.name = "Pilot"
	pl.setup(p)
	p.name = "Hyper%d" % cliff
	p.cliff_id = cliff
	p.set_multiplayer_authority(1)
	p.position = at
	p.rotation.y = WorldLayout.facing_canyon_yaw(cliff)
	w.add_child(p)
	p.add_child(pl)
	p.gun.vfx = w.get("vfx")
	return p


## Where a leg starts and ends on this map, for cliff `c`: [from, to, to_ship].
static func leg(w: Node3D, name: String, c: int) -> Array:
	var cb := w.get("cliffs") as CliffBuilder
	var home := cb.plateau_point(c, 6.0, 0.0) + Vector3.UP * 0.2
	var far := cb.plateau_point(WorldLayout.other_cliff(c), 6.0, 0.0) + Vector3.UP * 0.2
	var deck := deck_point(w)
	match name:
		"run": # along your own lip, end to end (the plateau's walls stand at +-20 m)
			return [cb.plateau_point(c, 8.0, -18.0) + Vector3.UP * 0.2, cb.plateau_point(c, 8.0, 18.0) + Vector3.UP * 0.2, false]
		"far": # back corner to the opposite front corner of your own plateau
			return [cb.plateau_point(c, 26.0, -18.0) + Vector3.UP * 0.2, cb.plateau_point(c, 4.0, 18.0) + Vector3.UP * 0.2, false]
		"tour": # your back corner to your partner's far back corner, across the canyon
			return [cb.plateau_point(c, 26.0, -18.0) + Vector3.UP * 0.2, cb.plateau_point(WorldLayout.other_cliff(c), 26.0, 18.0) + Vector3.UP * 0.2, false]
		"cross":
			return [home, far, false]
		"ship":
			return [home, deck, true]
		"home":
			return [deck, home, false]
	return [home, home, false]


static func deck_point(w: Node3D) -> Vector3:
	var ship := w.get_node_or_null("Airship") as Node3D
	if ship == null:
		return Airship.ring_position()
	return ship.to_global(Vector3(0, 0.3, AirshipBuilder.DECK_L * 0.5 - 1.2))


static func key(name: String) -> String:
	return "%s/%s" % [WorldLayout.map().id, name]


static func load_book() -> Dictionary:
	if not FileAccess.file_exists(BOOK):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOOK))
	return d if d is Dictionary else {}


static func route(name: String) -> Dictionary:
	var e: Variant = load_book().get(key(name), {})
	return (e as Dictionary).get("plan", {}) if e is Dictionary else {}


func run(w: Node3D) -> void:
	world = w
	cliffs = w.get("cliffs") as CliffBuilder
	_rng.seed = 7 + int(GameState.flag_value("--hyperseed"))
	var speed := 1.0 if reel() else maxf(GameState.flag_value("--simspeed").to_float(), 1.0)
	Engine.time_scale = speed
	Engine.physics_ticks_per_second = roundi(60.0 * speed)
	Engine.max_physics_steps_per_frame = roundi(8.0 * speed)
	for i in 30:
		await get_tree().process_frame
	var me := w.call("local_player") as Player
	if me != null:
		me.global_position = Vector3(0, 900, 0)
		me.process_mode = Node.PROCESS_MODE_DISABLED
		me.visible = false
	print("[hyper] spawning the bot")
	var first: Array = leg(w, "run", cid)
	bot = spawn_bot(w, cid, first[0])
	pilot = bot.pilot as HyperPilot
	for i in 10:
		await get_tree().physics_frame
	print("[hyper] bot up at %s" % str(bot.global_position))
	if reel():
		await _reel()
	elif learning():
		var legs := GameState.flag_value("--hyperlearn")
		for name: String in (LEGS if legs == "" or legs == "all" else Array(legs.split(","))):
			await _learn(name)
	else:
		var legs := GameState.flag_value("--hypershow")
		for name: String in (LEGS if legs == "" else Array(legs.split(","))):
			var plan := HyperPlan.chain() if GameState.flag_value("--hyperplan") == "chain" else route(name)
			var r := await trial(name, plan if not plan.is_empty() else HyperPlan.default(), Vector2.ZERO)
			print("[hyper] %s: %s" % [name, _fmt(r)])
	get_tree().quit()


## Fly `name` once under `plan` from start offset `off`. The result:
## {ok, t, top, slings, hops, swings, why, dist}.
var _leg_name := ""
## A try that takes this long has already lost (the learner tightens it).
var trial_limit := HyperPilot.TIMEOUT


func trial(name: String, plan: Dictionary, off: Vector2) -> Dictionary:
	_leg_name = name
	var l := leg(world, name, cid)
	var from: Vector3 = l[0]
	var to: Vector3 = l[1]
	var ship: bool = l[2]
	if name != "home":
		var dz := cliffs.plateau_point(cid, 0.0, 1.0) - cliffs.plateau_point(cid, 0.0, 0.0)
		from += dz.normalized() * off.x + WorldLayout.inward(cid) * -off.y
	else:
		from += Vector3(off.x, 0.0, off.y) * 0.3
	if name != "home":
		from = HyperPilot.ground(bot, from) + Vector3.UP * 0.1
	var face := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var xf := Transform3D(Basis.looking_at(face.normalized() if face.length() > 0.1 else Vector3.FORWARD, Vector3.UP), from)
	bot.pilot_reset(xf)
	for i in 3:
		await get_tree().physics_frame
	var res := {"ok": false, "why": ""}
	var done := [false]
	var on_ok := func(s: float) -> void:
		res["ok"] = true
		res["t"] = s
		done[0] = true
	var on_fail := func(why: String) -> void:
		res["why"] = why
		done[0] = true
	pilot.arrived.connect(on_ok, CONNECT_ONE_SHOT)
	pilot.failed.connect(on_fail, CONNECT_ONE_SHOT)
	pilot.timeout = trial_limit
	pilot.go(to, ship, plan)
	while not done[0]:
		await get_tree().physics_frame
	if pilot.arrived.is_connected(on_ok):
		pilot.arrived.disconnect(on_ok)
	if pilot.failed.is_connected(on_fail):
		pilot.failed.disconnect(on_fail)
	res["top"] = pilot.top_speed
	res["slings"] = pilot.slings
	res["hops"] = pilot.hops
	res["swings"] = pilot.swings
	res["path"] = pilot.path_len
	res["dist"] = bot.global_position.distance_to(to)
	if not res["ok"]:
		res["t"] = pilot.t
	return res


## Lower is better: seconds when it arrives, a heavy penalty (less the
## closer it got) when it falls or runs out of time.
static func score(r: Dictionary) -> float:
	if bool(r["ok"]):
		return float(r["t"])
	return 100.0 + float(r["dist"]) * 0.5


func _learn(name: String) -> void:
	var iters := int(GameState.flag_value("--hyperiters")) if GameState.flag_value("--hyperiters") != "" else 14
	var pop := int(GameState.flag_value("--hyperpop")) if GameState.flag_value("--hyperpop") != "" else 24
	var elite := maxi(pop / 4, 2)
	var b := HyperPlan.bounds()
	var n := b.size()
	var start := route(name)
	if GameState.flag_value("--hyperstart") == "chain":
		start = HyperPlan.chain() # (search around the slingshot chain instead)
	var mean := HyperPlan.encode(start if not start.is_empty() else HyperPlan.default())
	var sd := PackedFloat32Array()
	for i in n:
		sd.append((float(b[i][2]) - float(b[i][1])) * 0.35)
	var best := {"score": INF}
	var t0 := Time.get_ticks_msec()
	for it in iters:
		var scored: Array = []
		for k in pop:
			var v := mean.duplicate() if k == 0 else _sample(mean, sd)
			if it == 0 and k == 1:
				v = HyperPlan.encode(HyperPlan.chain())
			v = HyperPlan.clamp_vec(v)
			var plan := HyperPlan.decode(v)
			var total := 0.0
			var worst := {}
			for off: Vector2 in STARTS:
				var r := await trial(name, plan, off)
				total += score(r)
				if worst.is_empty() or score(r) > score(worst):
					worst = r
			var s := total / STARTS.size()
			scored.append([s, v, worst])
			if s < float(best["score"]):
				best = {"score": s, "plan": plan, "res": worst}
		scored.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
		# Refit the search to the elite (smoothed, with a floor so it keeps exploring).
		for i in n:
			var m := 0.0
			for e in elite:
				m += (scored[e][1] as PackedFloat32Array)[i]
			m /= elite
			var var_sum := 0.0
			for e in elite:
				var_sum += pow((scored[e][1] as PackedFloat32Array)[i] - m, 2.0)
			var floor_sd := (float(b[i][2]) - float(b[i][1])) * 0.03
			mean[i] = lerpf(mean[i], m, 0.8)
			sd[i] = maxf(lerpf(sd[i], sqrt(var_sum / elite), 0.8), floor_sd)
		if float(best["score"]) < 100.0:
			trial_limit = clampf(float(best["score"]) * 2.5 + 3.0, 8.0, HyperPilot.TIMEOUT)
		print("[hyper] learn %s iter %d: best %.2f s (this round %.2f, elite %.2f)  %s  real %.0f s" % [name, it + 1,
				float(best["score"]), float(scored[0][0]), float(scored[elite - 1][0]), _fmt(best["res"]), (Time.get_ticks_msec() - t0) / 1000.0])
	_save(name, best)


func _sample(mean: PackedFloat32Array, sd: PackedFloat32Array) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	for i in mean.size():
		v.append(mean[i] + _rng.randfn(0.0, sd[i]))
	return v


func _save(name: String, best: Dictionary) -> void:
	if not best.has("plan"):
		return
	var book := load_book()
	var k := key(name)
	var old: Variant = book.get(k, {})
	var r: Dictionary = best["res"]
	if old is Dictionary and (old as Dictionary).has("score") and float(old["score"]) <= float(best["score"]):
		print("[hyper] %s: kept the book's route (%.2f s beats %.2f s)" % [name, float(old["score"]), float(best["score"])])
		return
	book[k] = {"plan": best["plan"], "score": snappedf(float(best["score"]), 0.01), "top_speed": snappedf(float(r.get("top", 0.0)), 0.1),
			"slings": int(r.get("slings", 0)), "learned": Time.get_date_string_from_system()}
	# --hyperout=<path>: write there instead (parallel learners, merged after).
	var out := GameState.flag_value("--hyperout") if GameState.flag_value("--hyperout") != "" else BOOK
	if out != BOOK:
		book = {k: book[k]}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(book, "\t", true))
	f.close()
	print("[hyper] %s: saved %.2f s to the route book" % [name, float(best["score"])])


static func _fmt(r: Dictionary) -> String:
	return "%s %.2f s, top %.1f m/s, %d hops, %d swings, %d slings, %.0f m flown%s" % ["ok" if r.get("ok", false) else "FAIL",
			float(r.get("t", 0.0)), float(r.get("top", 0.0)), int(r.get("hops", 0)), int(r.get("swings", 0)),
			int(r.get("slings", 0)), float(r.get("path", 0.0)), "" if r.get("ok", false) else " (%s, %.0f m short)" % [str(r.get("why", "")), float(r.get("dist", 0.0))]]


# ------------------------------------------------------------------ the reel

var _cam: Camera3D
var _label: Label
var _cam_on := false


func _reel() -> void:
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 3000.0
	world.add_child(_cam)
	_cam.current = true
	var hud := world.get("hud") as CanvasItem
	if hud == null:
		var h2: Variant = world.get("hud")
		if h2 is CanvasLayer:
			(h2 as CanvasLayer).visible = false
	else:
		hud.visible = false
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(40, 30)
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_label)
	var legs := GameState.flag_value("--hyperreel")
	for entry: String in (["run", "far", "cross", "ship", "home", "tour", "tour!"] if legs == "" else Array(legs.split(","))):
		# "<leg>!": the same leg as an all-out slingshot chain (top speed over time).
		var name := entry.trim_suffix("!")
		var plan := HyperPlan.chain() if entry.ends_with("!") else route(name)
		_cam_on = true
		var r := await trial(name, plan if not plan.is_empty() else HyperPlan.default(), Vector2.ZERO)
		print("[hyper] reel %s: %s" % [name, _fmt(r)])
		_label.text = "%s   %.2f s   top %.0f m/s   %d slingshots" % [_title(name), float(r["t"]), float(r["top"]), int(r["slings"])]
		await get_tree().create_timer(2.0).timeout
		_cam_on = false


static func _title(name: String) -> String:
	return {"tour": "Corner to corner", "far": "Length of the lip", "cross": "Across the canyon",
			"ship": "Up to the airship", "home": "Back home", "run": "Along the lip"}.get(name, name)


func _process(delta: float) -> void:
	if _cam == null or bot == null:
		return
	var v := bot.velocity
	var h := Vector3(v.x, 0.0, v.z)
	var back := -h.normalized() if h.length() > 2.0 else bot.global_basis.z
	var want := bot.global_position + back * (6.0 + h.length() * 0.12) + Vector3.UP * 2.6
	var k := 1.0 - exp(-delta * 6.0)
	if _cam.global_position.distance_to(want) > 60.0:
		_cam.global_position = want
	else:
		_cam.global_position = _cam.global_position.lerp(want, k)
	_cam.look_at(bot.global_position + Vector3.UP * 1.0 + h * 0.15, Vector3.UP)
	_cam.fov = lerpf(_cam.fov, clampf(70.0 + v.length() * 0.5, 70.0, 100.0), k)
	if _cam_on and pilot.flying():
		_label.text = "%s   %.1f s   %3.0f m/s%s" % [_title(_leg_name), pilot.t, v.length(),
				"   SLING x%d" % pilot.slings if pilot.slings > 0 else ""]
