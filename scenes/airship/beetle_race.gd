class_name BeetleRace
extends CasinoTable
## Beetle racing: four painted beetles on a four-lane track. Pick one off the
## odds board (favourites pay little, long shots pay big, all about 95% back
## over time), and Race. The gate opens, they scuttle down their lanes with
## spurts and stalls, and the finish camera takes the photo. The host picks the
## winner by the odds and a seed, and every peer runs the same race (on the
## screen and on the little track on the deck table).

const RACE_TIME := 5.0
## The starting gate: the bell, then the gate drops.
const GATE := 1.2
const TRACK_X := 0.72
const LANE_Z := [-0.3, -0.1, 0.1, 0.3]
const COLORS := [Color("#C9302C"), Color("#2E6BB3"), Color("#E0A526"), Color("#3F8F3A")]

var _beetles: Array[Node3D] = []
var _t := GATE + RACE_TIME + 1.0
var _finish := PackedFloat32Array()
var _ticket := 0


func ui_anim() -> StringName:
	return &"dice"


func ui_title() -> String:
	return "Beetle Race"


func ui_tagline() -> String:
	return "Back a beetle off the odds board and watch them run."


func ui_rules() -> String:
	return "Pick a beetle and watch them scurry. The payout on each is shown: long shots pay more."


func _ready() -> void:
	super._ready()
	for i in 4:
		var b := Node3D.new()
		b.position = Vector3(TRACK_X, 0.995, LANE_Z[i])
		b.rotation.y = PI * 0.5 # face -X: left to right as you stand at the table
		add_child(b)
		var mi := MeshInstance3D.new()
		mi.mesh = _beetle_mesh(COLORS[i])
		mi.material_override = Materials.toon(0.008)
		b.add_child(mi)
		_beetles.append(b)
	if GameState.has_flag("--casinoshot") or GameState.flag_value("--casinoshot") != "":
		_casino_shot.call_deferred()


## Debug (screenshots): a camera over the new tables, a race and a shell game under way.
func _casino_shot() -> void:
	await get_tree().create_timer(4.5).timeout
	var shell := get_parent().get_node_or_null("ShellGame") as Node3D
	var focus: Node3D = shell if GameState.flag_value("--casinoshot").begins_with("shell") and shell != null else self
	var cam := Camera3D.new()
	get_parent().add_child(cam)
	cam.global_position = focus.to_global(Vector3(0.0, 1.85, -1.3))
	cam.look_at(focus.to_global(Vector3(0.0, 0.95, 0.0)))
	cam.current = true
	if multiplayer.is_server():
		_act(1, &"race", 3, 10)
		if shell != null:
			shell.call("_act", 1, &"play", 1, 10)
	if GameState.flag_value("--casinoshot").ends_with("menu") and MenuScreen.instance != null:
		MenuScreen.instance.open(focus)


## Lane lines, a start line and a chequered finish on the felt.
func _decorate(st: SurfaceTool) -> void:
	for z: float in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.987, z)), Vector3(1.6, 0.004, 0.012), Palette.BONE.darkened(0.1))
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(TRACK_X - 0.05, 0.988, 0)), Vector3(0.015, 0.004, 0.8), Palette.BONE)
	for k in 8:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-TRACK_X, 0.989, -0.35 + k * 0.1)), Vector3(0.05, 0.004, 0.05),
				Palette.OUTLINE if k % 2 == 0 else Palette.BONE)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-TRACK_X - 0.05, 0.989, -0.35 + k * 0.1)), Vector3(0.05, 0.004, 0.05),
				Palette.BONE if k % 2 == 0 else Palette.OUTLINE)


static func _beetle_mesh(c: Color) -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.03, 0.01)), Vector3(0.032, 0.022, 0.045), 4, 8, c)
	MeshKit.add_ellipsoid(st, Transform3D(Basis(), Vector3(0, 0.028, -0.042)), Vector3(0.018, 0.015, 0.016), 3, 6, Palette.OUTLINE)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.05, 0.01)), Vector3(0.003, 0.004, 0.07), Palette.OUTLINE)
	for s: float in [-1.0, 1.0]:
		for k in 3:
			var hip := Vector3(s * 0.022, 0.02, -0.02 + k * 0.025)
			MeshKit.add_limb(st, hip, hip + Vector3(s * 0.03, -0.018, (k - 1) * 0.012), 0.004, Palette.OUTLINE, 3)
	return MeshKit.finish(st)


func ui_choices() -> Array:
	var out: Array = []
	for i in CasinoRules.RACE_BEETLES.size():
		out.append("%s  x%.1f" % [CasinoRules.RACE_BEETLES[i][0], CasinoRules.race_multiplier(i)])
	return out


func board_picks() -> bool:
	return true


func ui_actions() -> Array:
	return [] if _racing() else [[&"race", "Race!"]]


func ui_cheat() -> Array:
	return ["Dope Your Beetle", "race"]


func make_board() -> CasinoBoard:
	return RaceBoard.new(self)


func anim_length() -> float:
	return GATE + RACE_TIME + 1.0 if str(view.get("kind", "")) == "race" else 0.0


func busy_text() -> String:
	return "And they're off!"


func result_text() -> String:
	if str(view.get("kind", "")) != "race":
		return "Pick a beetle on the odds board, then race."
	return result_line()


func _racing() -> bool:
	return _t < GATE + RACE_TIME + 1.0


## A decimal payout (stake included) as bookie's odds: 2.4 -> "7-5".
static func odds_text(mult: float) -> String:
	var net := mult - 1.0
	for den: int in [1, 2, 4, 5, 10]:
		var num := net * den
		if absf(num - roundf(num)) < 0.01:
			return "%d-%d" % [roundi(num), den]
	return "%.1f-1" % net


func _act(peer_id: int, action: StringName, choice: int, bet: int) -> void:
	if (action != &"race" and action != &"cheat") or _racing():
		return
	bet = _valid_bet(bet)
	if action == &"cheat" and _cheat(peer_id, "race", bet) <= 0: # Brand: Snake Eyes doped beetle
		return
	if not _take(peer_id, bet):
		return
	var pick := clampi(choice, 0, CasinoRules.RACE_BEETLES.size() - 1)
	var winner := CasinoRules.race_winner(_rng.randf())
	if action == &"cheat" and winner != pick:
		winner = CasinoRules.race_winner(_rng.randf()) # the doped beetle gets a second wind
	var won := CasinoRules.race_payout(pick, winner, bet)
	# Paid when the race is run, so the scrap counter doesn't give the result away.
	_pay_later(peer_id, {&"scrap": won} if won > 0 else {}, GATE + RACE_TIME + 0.5)
	_ticket += 1
	var wname := str(CasinoRules.RACE_BEETLES[winner][0])
	_broadcast({"kind": "race", "peer": peer_id, "pick": pick, "bet": bet, "winner": winner, "seed": _rng.randi(), "spinning": true,
			"ticket": 1000 + _ticket * 7 % 9000, "win": won,
			"result": ("%s wins! You collect %d scrap" % [wname, won]) if won > 0 else ("%s by a whisker. Your beetle lost" % wname)})


func _on_view() -> void:
	_t = 0.0
	_finish = CasinoRules.race_finish_times(int(view.get("winner", 0)), RACE_TIME, int(view.get("seed", 0)))
	Audio.play_at(&"bell", global_position + Vector3.UP, -14.0)


## How far along (0..1) beetle i is `t` seconds after the race view arrived.
func progress(i: int, t: float) -> float:
	if _finish.size() <= i:
		return 0.0
	return CasinoRules.race_progress(i, t - GATE, _finish[i], int(view.get("seed", 0)))


func _process(delta: float) -> void:
	if not _racing() or _finish.is_empty():
		return
	_t += delta
	for i in _beetles.size():
		var p := progress(i, _t)
		var b := _beetles[i]
		b.position.x = lerpf(TRACK_X - 0.08, -TRACK_X, p)
		var running := p > 0.0 and p < 1.0
		b.position.y = 0.995 + (absf(sin(_t * 30.0 + i)) * 0.006 if running else 0.0)
		b.rotation.z = sin(_t * 26.0 + i * 2.0) * 0.12 if running else 0.0
	if _t >= GATE + RACE_TIME + 1.0:
		view["spinning"] = false
		Audio.play_at(&"coin", global_position + Vector3.UP, -4.0)
		ui_changed.emit()
		# Back to the start line for the next race.
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if not _racing():
				for i in _beetles.size():
					_beetles[i].position = Vector3(TRACK_X, 0.995, LANE_Z[i]))


# ------------------------------------------------------------------ the track

class RaceBoard extends CasinoBoard:
	var race: BeetleRace
	var _hover_row := -1

	func _init(g: CasinoGame) -> void:
		super._init(g)
		race = g as BeetleRace
		custom_minimum_size = Vector2(0, 452)

	func _track() -> Rect2:
		return Rect2(20, 64, size.x - 330, 248)

	func _start_x() -> float:
		return _track().position.x + 96

	func _finish_x() -> float:
		return _track().end.x - 40

	func _running() -> bool:
		return str(game.view.get("kind", "")) == "race"

	func _tick() -> void:
		if not _running():
			return
		if due("bell", 0.05):
			sfx(&"bell", -8.0, 1.2)
		if due("gate", BeetleRace.GATE):
			sfx(&"hammer_hit", -6.0, 1.3)
			sfx(&"skitter", -6.0, 1.2)
		for k in 4:
			if due("skit%d" % k, BeetleRace.GATE + 0.9 + k * 1.0):
				sfx(&"skitter", -10.0, 1.1 + k * 0.08)
		if due("finish", BeetleRace.GATE + BeetleRace.RACE_TIME):
			sfx(&"bell", -6.0, 1.0)
		if due("photo", BeetleRace.GATE + BeetleRace.RACE_TIME + 0.4):
			sfx(&"zippo_close", -4.0, 1.4)
		if due("pay", game.anim_length()) and int(game.view.get("win", 0)) > 0:
			sfx(&"coin", -4.0)

	func _draw_game() -> void:
		var r := Rect2(Vector2.ZERO, size)
		rrect(r, WOOD_DARK, 22)
		rrect(r.grow(-6), Color("#8A5A32"), 18)
		text(Vector2(_track().get_center().x, 34), "THE MANDIBLE DERBY", 30, GOLD, 0, 6, true, Color("#3A0806"))
		var tr := _track()
		var t := age() if _running() else -1.0
		# Dirt lanes with chalk lines.
		rrect(tr, Color("#C9A26B"), 10, 3, Color("#5A3A1E"))
		var lane_h := tr.size.y / 4.0
		for i in 4:
			var lr := Rect2(tr.position.x, tr.position.y + i * lane_h, tr.size.x, lane_h)
			if i % 2 == 1:
				draw_rect(lr.grow(-2), Color(0, 0, 0, 0.05))
			if i == _hover_row and not game.ui_busy():
				draw_rect(lr.grow(-2), Color(1, 1, 1, 0.12))
			if i == game.ui_choice:
				draw_rect(lr.grow(-2), Color(1, 0.85, 0.3, 0.16))
			if i > 0:
				_dashed(Vector2(tr.position.x + 6, lr.position.y), Vector2(tr.end.x - 6, lr.position.y))
			# Lane number in the stall.
			rrect(Rect2(tr.position.x + 8, lr.get_center().y - 13, 26, 26), BeetleRace.COLORS[i], 13, 2, CREAM)
			text(Vector2(tr.position.x + 21, lr.get_center().y), str(i + 1), 14, CREAM, 0, 0, true)
		# Pebbles in the dirt (fixed, so they don't crawl).
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for k in 70:
			var p := Vector2(rng.randf_range(tr.position.x + 40, tr.end.x - 10), rng.randf_range(tr.position.y + 4, tr.end.y - 4))
			draw_circle(p, rng.randf_range(1.0, 2.5), Color(0.5, 0.36, 0.2, 0.35))
		# Start gate and the chequered finish.
		var gate_open := t >= BeetleRace.GATE
		var sx := _start_x()
		draw_line(Vector2(sx + 14, tr.position.y), Vector2(sx + 14, tr.end.y), CREAM, 3.0)
		for i in 5:
			var y := tr.position.y + i * lane_h
			rrect(Rect2(sx - 30, y - 4, 44, 8), Color("#5C646B"), 2)
		if not gate_open:
			for i in 4:
				var y := tr.position.y + i * lane_h
				draw_line(Vector2(sx + 16, y + 4), Vector2(sx + 16, y + lane_h - 4), Color("#B3261E"), 5.0)
		var fx := _finish_x()
		for k in int(tr.size.y / 10.0):
			for j in 2:
				var col := INK if (k + j) % 2 == 0 else CREAM
				draw_rect(Rect2(fx + j * 10, tr.position.y + k * 10, 10, 10), col)
		text(Vector2(fx + 10, tr.position.y - 12), "FINISH", 12, CREAM, 0, 3, true)
		# The runners.
		for i in 4:
			var p := race.progress(i, t) if _running() else 0.0
			var x := lerpf(sx, fx + 4, p)
			var y := tr.position.y + (i + 0.5) * lane_h
			var moving := _running() and p > 0.0 and p < 1.0
			var gait := t * 26.0 + i * 1.7 if moving else 0.0
			if moving:
				for k in 3:
					var dp := Vector2(x - 34 - k * 12, y + sin(t * 9.0 + k + i) * 6)
					draw_circle(dp, 5.0 + k * 2.0, Color(0.85, 0.72, 0.5, 0.35 - k * 0.1))
			beetle(Vector2(x, y + (sin(gait * 0.5) * 1.5 if moving else 0.0)), BeetleRace.COLORS[i], gait, i + 1)
		_odds_board(Rect2(size.x - 300, 14, 284, 300))
		_slip(Rect2(20, 324, 300, 114))
		if _running() and t >= BeetleRace.GATE + BeetleRace.RACE_TIME + 0.3:
			_photo(Rect2(352, 322, size.x - 352 - 316, 120), t)
		else:
			text(Vector2(352 + (size.x - 668) * 0.5, 380), "Photo Finish Camera Ready", 14, Color(1, 1, 1, 0.5), 0, 0, true)

	func _dashed(a: Vector2, b: Vector2) -> void:
		var d := a.distance_to(b)
		var n := int(d / 16.0)
		for k in n:
			var f0 := float(k) / n
			if k % 2 == 0:
				draw_line(a.lerp(b, f0), a.lerp(b, f0 + 0.5 / n), Color(1, 1, 1, 0.75), 2.0)

	## A racing beetle from above, facing right: six legs in a tripod gait.
	func beetle(c: Vector2, col: Color, gait: float, num: int, k: float = 1.0) -> void:
		var leg := Color("#2A1A0F")
		for side: float in [-1.0, 1.0]:
			for j in 3:
				var hip := c + Vector2((j - 1) * 9.0, side * 7.0) * k
				var phase := gait + (PI if (j + int(side > 0.0)) % 2 == 0 else 0.0)
				var swing := sin(phase) * 7.0
				var knee := hip + Vector2(swing * 0.5 + (j - 1) * 3.0, side * 9.0) * k
				var foot := knee + Vector2(swing + (j - 1) * 5.0, side * 6.0) * k
				draw_polyline(PackedVector2Array([hip, knee, foot]), leg, 2.2 * k, true)
		# Antennae.
		for side: float in [-1.0, 1.0]:
			var a := c + Vector2(20, side * 3) * k
			draw_polyline(PackedVector2Array([a, a + Vector2(8, side * 6) * k, a + Vector2(13, side * 5) * k]), leg, 1.6 * k, true)
		draw_set_transform(c + Vector2(-2, 0) * k, 0.0, Vector2(1.0, 0.72) * k)
		draw_circle(Vector2.ZERO, 16, col.darkened(0.35))
		draw_circle(Vector2(-1, -1), 15, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_line(c + Vector2(-16, 0) * k, c + Vector2(10, 0) * k, Color(0, 0, 0, 0.45), 1.5 * k)
		draw_circle(c + Vector2(14, 0) * k, 7 * k, leg)
		draw_circle(c + Vector2(-6, -5) * k, 3 * k, Color(1, 1, 1, 0.35))
		draw_circle(c + Vector2(-4, 0) * k, 6.5 * k, CREAM)
		text(c + Vector2(-4, 0.5) * k, str(num), int(10 * k), INK, 0, 0, true)

	func _odds_board(r: Rect2) -> void:
		rrect(r, WOOD, 8)
		rrect(r.grow(-8), Color("#25302A"), 4)
		text(Vector2(r.get_center().x, r.position.y + 28), "TODAY'S ODDS", 20, Color("#F2EEE0"), 0, 0, true)
		draw_line(Vector2(r.position.x + 20, r.position.y + 48), Vector2(r.end.x - 20, r.position.y + 48), Color(1, 1, 1, 0.4), 1.5)
		for i in 4:
			var row := _row_rect(i)
			var picked := i == game.ui_choice
			if picked:
				rrect(row, Color(1, 0.9, 0.5, 0.18), 6, 2, GOLD)
			elif i == _hover_row and not game.ui_busy():
				rrect(row, Color(1, 1, 1, 0.08), 6)
			var won := _running() and not game.ui_busy() and int(game.view.get("winner", -1)) == i
			draw_circle(Vector2(row.position.x + 18, row.get_center().y), 9, BeetleRace.COLORS[i])
			text(Vector2(row.position.x + 18, row.get_center().y), str(i + 1), 11, CREAM, 0, 0, true)
			text(Vector2(row.position.x + 36, row.get_center().y - 9), str(CasinoRules.RACE_BEETLES[i][0]), 17, GOLD if won else Color("#F2EEE0"), -1)
			var mult := CasinoRules.race_multiplier(i)
			text(Vector2(row.position.x + 36, row.get_center().y + 12), "pays x%.1f" % mult, 12, Color(1, 1, 1, 0.6), -1)
			text(Vector2(row.end.x - 10, row.get_center().y - (6 if won else 0)), BeetleRace.odds_text(mult), 22, Color("#F2EEE0"), 1, 0, true)
			if won:
				text(Vector2(row.end.x - 10, row.get_center().y + 15), "WINNER", 11, GOLD, 1, 0, true)

	func _row_rect(i: int) -> Rect2:
		var r := Rect2(size.x - 300, 14, 284, 300)
		return Rect2(r.position.x + 16, r.position.y + 60 + i * 58, r.size.x - 32, 52)

	## Your bet slip: the ticket with the beetle, stake and what it pays.
	func _slip(r: Rect2) -> void:
		var pick := int(game.view.get("pick", game.ui_choice)) if _running() and game.ui_busy() else game.ui_choice
		var bet := int(game.view.get("bet", game.stake())) if _running() and game.ui_busy() else game.stake()
		draw_set_transform(r.get_center(), -0.03, Vector2.ONE)
		var lr := Rect2(-r.size * 0.5, r.size)
		rrect(lr, Color("#F4ECD6"), 4, 1, Color(0, 0, 0, 0.3))
		for k in 14:
			draw_circle(Vector2(lr.position.x + 10 + k * 21, lr.position.y), 4, Color("#8A5A32"))
		text(lr.position + Vector2(14, 20), "BET SLIP", 15, Color("#7A1E18"), -1, 0, true)
		var no := int(game.view.get("ticket", 1000)) if _running() else 0
		text(Vector2(lr.end.x - 12, lr.position.y + 20), "No. %04d" % no if no > 0 else "No. ----", 12, INK, 1)
		draw_line(lr.position + Vector2(12, 34), Vector2(lr.end.x - 12, lr.position.y + 34), Color(0, 0, 0, 0.3), 1.0)
		text(lr.position + Vector2(14, 52), "To Win:  #%d %s" % [pick + 1, CasinoRules.RACE_BEETLES[pick][0]], 15, INK, -1)
		text(lr.position + Vector2(14, 74), "Stake:  %d Scrap" % bet, 14, INK, -1)
		text(lr.position + Vector2(14, 94), "Returns:  %d Scrap" % CasinoRules.race_payout(pick, pick, bet), 14, INK, -1)
		if _running() and not game.ui_busy() and mine():
			var won := int(game.view.get("win", 0)) > 0
			draw_set_transform(r.get_center() + Vector2(90, 18), -0.3, Vector2.ONE)
			var s := "PAID" if won else "LOST"
			rrect(Rect2(-46, -18, 92, 36), Color(0, 0, 0, 0), 6, 3, Color("#2E7D32") if won else RED)
			text(Vector2.ZERO, s, 22, Color("#2E7D32") if won else RED, 0, 0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	## The finish camera's print: the line, each beetle's nose as the winner crossed.
	func _photo(r: Rect2, t: float) -> void:
		var drop := clampf((t - BeetleRace.GATE - BeetleRace.RACE_TIME - 0.3) / 0.35, 0.0, 1.0)
		var lr := Rect2(r.position + Vector2(0, (1.0 - drop) * 50.0), r.size)
		rrect(lr.grow(4), Color(0, 0, 0, 0.3), 4)
		rrect(lr, Color("#F7F2E6"), 3)
		var pic := Rect2(lr.position + Vector2(8, 8), Vector2(lr.size.x - 16, lr.size.y - 30))
		draw_rect(pic, Color("#BFA478"))
		var fx := pic.position.x + pic.size.x * 0.72
		var winner := int(game.view.get("winner", 0))
		var at := race._finish[winner] + BeetleRace.GATE if race._finish.size() > winner else 0.0
		var lane := pic.size.y / 4.0
		for i in 4:
			var y := pic.position.y + (i + 0.5) * lane
			draw_line(Vector2(pic.position.x, y + lane * 0.5), Vector2(pic.end.x, y + lane * 0.5), Color(0, 0, 0, 0.12), 1.0)
			var p := race.progress(i, at)
			var x := fx - (1.0 - p) * pic.size.x * 2.5 - 14.0
			if x > pic.position.x + 10:
				beetle(Vector2(x, y), BeetleRace.COLORS[i].lerp(Color("#6B5034"), 0.45), 0.0, i + 1, 0.5)
		draw_line(Vector2(fx, pic.position.y), Vector2(fx, pic.end.y), Color("#3A2A18"), 2.0)
		draw_rect(pic, Color(0.45, 0.3, 0.1, 0.16))
		text(Vector2(lr.position.x + 10, lr.end.y - 11), "PHOTO FINISH", 12, INK, -1, 0, true)
		text(Vector2(lr.end.x - 10, lr.end.y - 11), "1st  #%d %s" % [winner + 1, CasinoRules.RACE_BEETLES[winner][0]], 13, Color("#7A1E18"), 1, 0, true)

	func _row_at(p: Vector2) -> int:
		for i in 4:
			if _row_rect(i).has_point(p):
				return i
		var tr := _track()
		if tr.has_point(p):
			return clampi(int((p.y - tr.position.y) / (tr.size.y / 4.0)), 0, 3)
		return -1

	func _hover(p: Vector2) -> void:
		_hover_row = _row_at(p)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover_row >= 0 else Control.CURSOR_ARROW

	func _click(p: Vector2, right: bool) -> bool:
		var i := _row_at(p)
		if right or i < 0 or game.ui_busy():
			return false
		game.ui_choice = i
		sfx(&"dice", -8.0, 1.8)
		game.ui_changed.emit()
		return true
