class_name ShellGame
extends CasinoTable
## The shell game: three tin cups, one dried pea. Pay your stake and the dealer
## shows you the pea, covers it and works the cups round the felt (his quick
## passes are hard to follow), finishing with the "whirl": all three bunched and
## spun. Then you click a cup and he lifts it. The pea's last cup is the host's
## fair 1-in-3 pick, so a right guess pays 2.85x the stake (about 95% back over
## time). The cups move on every peer's screen and on the deck table.

const REVEAL_TIME := 1.4
## How long a waiting round holds the table before someone else may play.
const ABANDON := 60.0
## Left to right as you stand at the table (the felt faces you from its -Z side).
const CUP_X := [0.45, 0.0, -0.45]

var _cups: Array[Node3D] = []
var _pea: MeshInstance3D
var _round: Dictionary = {} # host: {"peer", "bet", "pea", "seed", "at"}


func ui_anim() -> StringName:
	return &"cards"


func ui_title() -> String:
	return "Shell Game"


func ui_tagline() -> String:
	return "Watch the pea, follow the cups, then pick one."


func ui_rules() -> String:
	return "Find the pea under one of three cups. Guess right and win %.2fx your stake." % CasinoRules.SHELL_RETURN


func _ready() -> void:
	super._ready()
	for i in 3:
		var cup := Node3D.new()
		cup.position = Vector3(CUP_X[i], 0.99, -0.05)
		add_child(cup)
		var mi := MeshInstance3D.new()
		mi.mesh = _cup_mesh()
		mi.material_override = Materials.toon(0.01)
		cup.add_child(mi)
		_cups.append(cup)
	_pea = MeshInstance3D.new()
	var st := MeshKit.begin()
	MeshKit.add_ellipsoid(st, Transform3D(), Vector3(0.035, 0.03, 0.035), 4, 6, Color("#C9A86A"))
	_pea.mesh = MeshKit.finish(st)
	_pea.material_override = Materials.toon(0.01)
	_pea.visible = false
	add_child(_pea)


static func _cup_mesh() -> ArrayMesh:
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.11, 0.075, 0.2, 10, Color("#8C949C"))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.205, 0)), 0.078, 0.07, 0.015, 10, Color("#6E767E"))
	MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(0, 0.01, 0)), 0.115, 0.115, 0.02, 10, Color("#5C646B"), false)
	return MeshKit.finish(st)


func board_picks() -> bool:
	return true


func ui_choices() -> Array:
	return ["Left cup", "Middle cup", "Right cup"]


func _phase() -> String:
	return str(view.get("phase", "")) if str(view.get("kind", "")) == "shell" else ""


## The player whose cups are on the felt has to pick.
func waiting_pick() -> bool:
	return _phase() == "shuffle" and not ui_busy()


func ui_actions() -> Array:
	if _phase() == "shuffle":
		if int(view.get("peer", 0)) == multiplayer.get_unique_id() and not ui_busy():
			return [[&"pick0", "Left Cup"], [&"pick1", "Middle Cup"], [&"pick2", "Right Cup"]]
		return []
	return [[&"play", "Play"]]


func ui_cheat() -> Array:
	return ["Peek Under the Cups", "shell"] if _phase() != "shuffle" else []


func ui_press(id: StringName) -> void:
	if String(id).begins_with("pick"):
		ui_act(&"pick", String(id).substr(4).to_int(), 0)
	else:
		super.ui_press(id)


func make_board() -> CasinoBoard:
	return ShellBoard.new(self)


func anim_length() -> float:
	match _phase():
		"shuffle":
			return shuffle_length(CasinoRules.shell_moves(int(view.get("seed", 0))))
		"reveal":
			return REVEAL_TIME
	return 0.0


func busy_text() -> String:
	return "Keep your eye on the pea..." if _phase() == "shuffle" else "Let's see..."


func result_text() -> String:
	match _phase():
		"shuffle":
			if int(view.get("peer", 0)) == multiplayer.get_unique_id():
				return "Where's the pea? Click a cup."
			return "Waiting for the player to pick a cup."
		"reveal":
			return result_line()
	return "Pay your stake and the dealer starts the cups moving."


func _act(peer_id: int, action: StringName, choice: int, bet: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if action == &"pick":
		if _round.is_empty() or int(_round["peer"]) != peer_id:
			return
		if now < float(_round["at"]) + shuffle_length(CasinoRules.shell_moves(int(_round["seed"]))) - 0.2:
			return
		var pick := clampi(choice, 0, 2)
		var pea := int(_round["pea"])
		var bet_r := int(_round["bet"])
		var won := CasinoRules.shell_payout(pick, pea, bet_r)
		_pay_later(peer_id, {&"scrap": won} if won > 0 else {}, 0.5)
		var names := ["left", "middle", "right"]
		_broadcast({"kind": "shell", "phase": "reveal", "peer": peer_id, "pick": pick, "pea": pea, "bet": bet_r, "win": won,
				"result": ("Under the %s cup! You win %s" % [names[pea], UiStyle.cost(won, ResNames.TEAM_ID)]) if won > 0 else ("Nope, it was under the %s cup" % names[pea])})
		_round = {}
		return
	if action != &"play" and action != &"cheat":
		return
	if not _round.is_empty() and now - float(_round["at"]) < ABANDON:
		Economy.notify(peer_id, "Wait for the current game to finish.")
		return
	bet = _valid_bet(bet)
	if action == &"cheat" and _cheat(peer_id, "shell", bet) <= 0: # Brand: Snake Eyes peek
		return
	if not _take(peer_id, bet):
		return
	var seed_v := _rng.randi()
	_round = {"peer": peer_id, "bet": bet, "pea": CasinoRules.shell_pea(_rng), "seed": seed_v, "at": now}
	_broadcast({"kind": "shell", "phase": "shuffle", "peer": peer_id, "seed": seed_v, "bet": bet,
			"peek": int(_round["pea"]) if action == &"cheat" else -1})


func _on_view() -> void:
	_pea.visible = false
	Audio.play_at(&"card_flick", global_position + Vector3.UP, -6.0)


# ------------------------------------------------------------------ the moves

## The dealer's routine: [kind, start, end, a, b] with kind "show" (the pea
## under cup a), "swap" (slots a and b trade cups) or "whirl" (all three).
static func timeline(moves: Dictionary) -> Array:
	var out: Array = []
	out.append(["show", 0.0, 1.3, int(moves["start"]), 0])
	var t := 1.45
	for sw: Array in moves["swaps"]:
		var d := 0.62 / float(sw[2])
		out.append(["swap", t, t + d, int(sw[0]), int(sw[1])])
		t += d + 0.06
	out.append(["whirl", t, t + 1.7, 0, 0])
	return out


static func shuffle_length(moves: Dictionary) -> float:
	var tl := timeline(moves)
	return float(tl[tl.size() - 1][2]) + 0.15


## Where cup c (named by the slot it starts in) is `t` seconds into the
## shuffle: x in slots (-1 left .. 1 right), depth (+ toward you), lift (0..1).
static func cup_pose(c: int, t: float, moves: Dictionary) -> Vector3:
	var slot := c
	for seg: Array in timeline(moves):
		var t0 := float(seg[1])
		var t1 := float(seg[2])
		if t < t0:
			break
		var f := clampf((t - t0) / (t1 - t0), 0.0, 1.0)
		var e := f * f * (3.0 - 2.0 * f)
		match str(seg[0]):
			"show":
				if t < t1 and slot == int(seg[3]):
					var lift := clampf(minf(f / 0.2, (0.85 - f) / 0.2), 0.0, 1.0)
					return Vector3(slot - 1, 0.0, lift)
			"swap":
				var a := int(seg[3])
				var b := int(seg[4])
				if t < t1:
					# One cup passes in front of the other.
					if slot == a:
						return Vector3(lerpf(a - 1, b - 1, e), sin(e * PI), 0.0)
					if slot == b:
						return Vector3(lerpf(b - 1, a - 1, e), -sin(e * PI), 0.0)
				elif slot == a:
					slot = b
				elif slot == b:
					slot = a
			"whirl":
				var turns := TAU * 2.6
				if t >= t1:
					return Vector3(_whirl_slot(c) - 1, 0.0, 0.0)
				var spin := f * turns + c * TAU / 3.0
				if f < 0.22:
					var g := f / 0.22
					var s0 := c * TAU / 3.0 + 0.22 * turns
					return Vector3(lerpf(slot - 1, cos(s0) * 0.42, g), lerpf(0.0, sin(s0), g), 0.0)
				if f > 0.8:
					var g := (f - 0.8) / 0.2
					var s1 := c * TAU / 3.0 + 0.8 * turns
					return Vector3(lerpf(cos(s1) * 0.42, _whirl_slot(c) - 1, g * g * (3.0 - 2.0 * g)), lerpf(sin(s1), 0.0, g), 0.0)
				return Vector3(cos(spin) * 0.42, sin(spin), 0.0)
	return Vector3(slot - 1, 0.0, 0.0)


## Where each cup comes out of the whirl (they look alike: only the spacing matters).
static func _whirl_slot(c: int) -> int:
	return [1, 2, 0][c]


func _process(_delta: float) -> void:
	if _cups.is_empty() or str(view.get("kind", "")) != "shell":
		return
	var t := view_age()
	if _phase() == "shuffle":
		var moves := CasinoRules.shell_moves(int(view.get("seed", 0)))
		if t > shuffle_length(moves) + 1.0:
			return
		var start := int(moves["start"])
		for c in 3:
			var p := cup_pose(c, t, moves)
			_cups[c].position = Vector3(-0.45 * p.x, 0.99 + p.z * 0.16, -0.05 - p.y * 0.12)
			_cups[c].rotation.x = -p.z * 0.35
		_pea.visible = cup_pose(start, t, moves).z > 0.05
		_pea.position = Vector3(CUP_X[start], 1.01, -0.05)
	elif _phase() == "reveal" and t < REVEAL_TIME + 1.0:
		var pick := int(view.get("pick", 0))
		var pea := int(view.get("pea", 0))
		for i in 3:
			var lift := 0.0
			if i == pick:
				lift = clampf(t / 0.35, 0.0, 1.0)
			elif i == pea:
				lift = clampf((t - 0.6) / 0.35, 0.0, 1.0)
			_cups[i].position = Vector3(CUP_X[i], 0.99 + lift * 0.18, -0.05)
			_cups[i].rotation.x = -lift * 0.35
		_pea.position = Vector3(CUP_X[pea], 1.01, -0.05)
		_pea.visible = true


# ------------------------------------------------------------------ the felt

class ShellBoard extends CasinoBoard:
	const SPREAD := 230.0
	var shell: ShellGame
	var _hover_cup := -1

	func _init(g: CasinoGame) -> void:
		super._init(g)
		shell = g as ShellGame
		custom_minimum_size = Vector2(0, 452)

	func _base_y() -> float:
		return 318.0

	func _tick() -> void:
		var ph := shell._phase()
		if ph == "shuffle":
			var moves := CasinoRules.shell_moves(int(game.view.get("seed", 0)))
			var tl := ShellGame.timeline(moves)
			for i in tl.size():
				var seg: Array = tl[i]
				if due("seg%d" % i, float(seg[1])):
					match str(seg[0]):
						"show":
							pass
						"swap":
							sfx(&"dice", -12.0, 0.8 + float(i) * 0.04)
						"whirl":
							sfx(&"roulette_spin", -10.0, 2.2)
				if str(seg[0]) == "show" and due("down", float(seg[2]) * 0.8):
					sfx(&"dice", -6.0, 0.6)
			if due("done", ShellGame.shuffle_length(moves) - 0.1):
				sfx(&"dice", -6.0, 0.7)
		elif ph == "reveal":
			if due("lift", 0.05):
				sfx(&"card_flick", -6.0, 0.7)
			if due("lift2", 0.6) and int(game.view.get("pick", 0)) != int(game.view.get("pea", 0)):
				sfx(&"card_flick", -6.0, 0.7)
			if due("verdict", 0.5):
				sfx(&"coin" if int(game.view.get("win", 0)) > 0 else &"hit_tick", -6.0)

	func _draw_game() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# A plank table with a strip of felt: the shell man's pitch.
		rrect(r, WOOD_DARK, 22)
		rrect(r.grow(-6), Color("#7A4A26"), 18)
		for k in 9:
			var y := 12.0 + k * 50.0
			draw_line(Vector2(12, y), Vector2(size.x - 12, y), Color(0, 0, 0, 0.18), 2.0)
		var mat := Rect2(70, 150, size.x - 140, 250)
		rrect(mat, FELT, 30, 4, GOLD_DARK)
		draw_texture_rect(UiStyle.vignette(), mat, false, Color(1, 1, 1, 0.5))
		text(Vector2(size.x * 0.5, 60), "FIND THE PEA", 38, GOLD, 0, 6, true, Color("#3A0806"))
		text(Vector2(size.x * 0.5, 100), "Pays %.2f to 1 . One Pea . Three Cups . Honest Dealing*" % (CasinoRules.SHELL_RETURN - 1.0), 14, CREAM, 0, 3, true)
		text(Vector2(size.x - 24, size.y - 20), "*mostly", 11, Color(1, 1, 1, 0.45), 1)
		var mid := Vector2(size.x * 0.5, _base_y())
		var ph := shell._phase()
		var t := age()
		var poses: Array = []
		var pea_slot := -1
		var pea_shown := false
		if ph == "shuffle":
			var moves := CasinoRules.shell_moves(int(game.view.get("seed", 0)))
			for c in 3:
				poses.append(ShellGame.cup_pose(c, t, moves))
			var start := int(moves["start"])
			pea_slot = start
			pea_shown = (poses[start] as Vector3).z > 0.05
		elif ph == "reveal":
			var pick := int(game.view.get("pick", 0))
			var pea := int(game.view.get("pea", 0))
			for i in 3:
				var lift := 0.0
				if i == pick:
					lift = clampf(t / 0.3, 0.0, 1.0)
				elif i == pea:
					lift = clampf((t - 0.6) / 0.3, 0.0, 1.0)
				poses.append(Vector3(i - 1, 0, lift))
			pea_slot = pea
			pea_shown = true
		else:
			for i in 3:
				poses.append(Vector3(i - 1, 0, 0))
		# The pea under its cup.
		if pea_shown and pea_slot >= 0:
			var pp := mid + Vector2((pea_slot - 1) * SPREAD, 8)
			draw_set_transform(pp + Vector2(2, 4), 0.0, Vector2(1, 0.5))
			draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.3))
			draw_set_transform_matrix(Transform2D.IDENTITY)
			draw_circle(pp, 10, Color("#C9A86A"))
			draw_circle(pp + Vector2(-3, -3), 3.5, Color("#F2E0B0"))
		# Snake Eyes: the cheat's sly glint over the pea's real cup.
		var peek := int(game.view.get("peek", -1))
		if ph == "shuffle" and peek >= 0 and mine() and not game.ui_busy():
			var gp := mid + Vector2((peek - 1) * SPREAD, -150)
			poly(star_points(gp, 12, 4, 4, Time.get_ticks_msec() / 400.0), Color(1, 0.95, 0.6, 0.85))
		# Cups, back to front.
		var order := [0, 1, 2]
		order.sort_custom(func(a: int, b: int) -> bool: return (poses[a] as Vector3).y < (poses[b] as Vector3).y)
		for c: int in order:
			var p: Vector3 = poses[c]
			var slot_x := p.x
			var depth := p.y
			var at := mid + Vector2(slot_x * SPREAD, depth * 34.0)
			var k := 1.0 + depth * 0.1
			var hot := ph == "shuffle" and mine() and not game.ui_busy() and _hover_cup == roundi(slot_x + 1.0)
			_cup(at, k, p.z, hot)
		if ph == "reveal" and not game.ui_busy():
			var pick := int(game.view.get("pick", 0))
			var won := int(game.view.get("win", 0)) > 0
			var bp := mid + Vector2((pick - 1) * SPREAD, 70)
			var label := "WINNER!" if won else "EMPTY"
			var w := text_width(label, 18, true) + 22
			rrect(Rect2(bp.x - w * 0.5, bp.y - 16, w, 32), Color("#2E7D32") if won else RED, 8, 2, CREAM)
			text(bp, label, 18, CREAM, 0, 0, true)
		# Your stake on the mat.
		var bet := int(game.view.get("bet", 0)) if ph == "shuffle" else game.stake()
		chip_stack(Vector2(120, 370), 22, bet, 1.0 if ph == "shuffle" else 0.6)

	## A tin cup upside down on the felt, `lift` raising and tipping it.
	func _cup(base: Vector2, k: float, lift: float, hot: bool) -> void:
		var up := lift * 85.0
		var tip := -lift * 0.35
		draw_set_transform(base + Vector2(0, 6), 0.0, Vector2(1, 0.32))
		draw_circle(Vector2.ZERO, 66 * k * (1.0 - lift * 0.3), Color(0, 0, 0, 0.3 * (1.0 - lift * 0.5)))
		draw_set_transform(base - Vector2(0, up), tip, Vector2(k, k))
		var w0 := 64.0
		var w1 := 44.0
		var h := 120.0
		var body := PackedVector2Array([Vector2(-w0, 0), Vector2(-w1, -h), Vector2(w1, -h), Vector2(w0, 0)])
		poly(body, Color("#8C949C"))
		poly(PackedVector2Array([Vector2(-w0, 0), Vector2(-w1, -h), Vector2(-w1 + 18, -h), Vector2(-w0 + 24, 0)]), Color("#B9C0C7"))
		poly(PackedVector2Array([Vector2(w0 - 20, 0), Vector2(w1 - 12, -h), Vector2(w1, -h), Vector2(w0, 0)]), Color("#5C646B"))
		for ring_y: float in [-30.0, -82.0]:
			var ww := lerpf(w0, w1, -ring_y / h)
			draw_line(Vector2(-ww, ring_y), Vector2(ww, ring_y), Color(0, 0, 0, 0.25), 3.0)
		draw_set_transform(base - Vector2(0, up) + Vector2(0, -h * k).rotated(tip), tip, Vector2(k, k * 0.3))
		draw_circle(Vector2.ZERO, w1, Color("#6E767E"))
		draw_set_transform(base - Vector2(0, up), tip, Vector2(k, k * 0.3))
		draw_arc(Vector2.ZERO, w0, 0, PI, 24, Color("#4A5056"), 6.0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if hot:
			draw_set_transform(base, 0.0, Vector2(k, k))
			draw_polyline(PackedVector2Array([Vector2(-w0 - 6, 4), Vector2(-w1 - 6, -h - 6), Vector2(w1 + 6, -h - 6), Vector2(w0 + 6, 4), Vector2(-w0 - 6, 4)]), GOLD, 4.0, true)
			draw_set_transform_matrix(Transform2D.IDENTITY)

	func _cup_at(p: Vector2) -> int:
		var mid := Vector2(size.x * 0.5, _base_y())
		for i in 3:
			var c := mid + Vector2((i - 1) * SPREAD, -60)
			if absf(p.x - c.x) < 75 and absf(p.y - c.y) < 80:
				return i
		return -1

	func _hover(p: Vector2) -> void:
		_hover_cup = _cup_at(p)
		var can := shell._phase() == "shuffle" and mine() and not game.ui_busy()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can and _hover_cup >= 0 else Control.CURSOR_ARROW

	func _click(p: Vector2, right: bool) -> bool:
		if right or shell._phase() != "shuffle" or not mine() or game.ui_busy():
			return false
		var i := _cup_at(p)
		if i < 0:
			return false
		game.ui_act(&"pick", i, 0)
		return true
