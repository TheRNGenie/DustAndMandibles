class_name BeetleRace
extends CasinoTable
## Beetle racing: four little painted beetles on a four-lane track across the
## table. Pick one (the odds are shown: favourites pay little, long shots pay
## big, all about 95% back over time) and Race. The host picks the winner by
## the odds and a seed, and every peer runs the same scurrying race.

const RACE_TIME := 5.0
const TRACK_X := 0.72
const LANE_Z := [-0.3, -0.1, 0.1, 0.3]
const COLORS := [Color("#C9302C"), Color("#2E6BB3"), Color("#E0A526"), Color("#3F8F3A")]

var _beetles: Array[Node3D] = []
var _t := RACE_TIME + 1.0
var _finish := PackedFloat32Array()


func ui_anim() -> StringName:
	return &"dice"


func ui_title() -> String:
	return "Beetle Race"


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


func ui_actions() -> Array:
	return [] if _racing() else [[&"race", "Race!"]]


func _racing() -> bool:
	return _t < RACE_TIME + 1.0


func _act(peer_id: int, action: StringName, choice: int, bet: int) -> void:
	if action != &"race" or _racing():
		return
	bet = _valid_bet(bet)
	if not _take(peer_id, bet):
		return
	var pick := clampi(choice, 0, CasinoRules.RACE_BEETLES.size() - 1)
	var winner := CasinoRules.race_winner(_rng.randf())
	var won := CasinoRules.race_payout(pick, winner, bet)
	# Paid when the race is run, so the scrap counter doesn't give the result away.
	_pay_later(peer_id, {&"scrap": won} if won > 0 else {}, RACE_TIME + 0.5)
	var wname := str(CasinoRules.RACE_BEETLES[winner][0])
	_broadcast({"kind": "race", "peer": peer_id, "pick": pick, "winner": winner, "seed": _rng.randi(), "spinning": true,
			"result": ("%s wins! You collect %d scrap" % [wname, won]) if won > 0 else ("%s by a whisker. Your beetle lost" % wname)})


func _on_view() -> void:
	_t = 0.0
	_finish = CasinoRules.race_finish_times(int(view.get("winner", 0)), RACE_TIME, int(view.get("seed", 0)))
	Audio.play_at(&"bell", global_position + Vector3.UP, -14.0)


func _process(delta: float) -> void:
	if not _racing() or _finish.is_empty():
		return
	_t += delta
	var seed_v := int(view.get("seed", 0))
	for i in _beetles.size():
		var p := CasinoRules.race_progress(i, _t, _finish[i], seed_v)
		var b := _beetles[i]
		b.position.x = lerpf(TRACK_X - 0.08, -TRACK_X, p)
		var running := p > 0.0 and p < 1.0
		b.position.y = 0.995 + (absf(sin(_t * 30.0 + i)) * 0.006 if running else 0.0)
		b.rotation.z = sin(_t * 26.0 + i * 2.0) * 0.12 if running else 0.0
	if _t >= RACE_TIME + 1.0:
		view["spinning"] = false
		Audio.play_at(&"coin", global_position + Vector3.UP, -4.0)
		ui_changed.emit()
		# Back to the start line for the next race.
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if not _racing():
				for i in _beetles.size():
					_beetles[i].position = Vector3(TRACK_X, 0.995, LANE_Z[i]))


## The menu: the four runners with their payouts; the winner flagged after the race.
func _draw_view(table: VBoxContainer) -> void:
	var racing := str(view.get("kind", "")) == "race" and bool(view.get("spinning", false))
	var done := str(view.get("kind", "")) == "race" and not racing
	if racing:
		table.add_child(MenuScreen.ink_label("They're off!", 26, MenuScreen.PARCHMENT))
	for i in CasinoRules.RACE_BEETLES.size():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		var dot := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLORS[i]
		sb.set_corner_radius_all(10)
		sb.border_color = Palette.OUTLINE
		sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		dot.custom_minimum_size = Vector2(20, 20)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var won := done and int(view.get("winner", -1)) == i
		var name_l := MenuScreen.ink_label(str(CasinoRules.RACE_BEETLES[i][0]), 19, MenuScreen.GOLD if won else MenuScreen.PARCHMENT)
		name_l.custom_minimum_size.x = 170
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_l)
		var odds := MenuScreen.ink_label("pays x%.1f" % CasinoRules.race_multiplier(i), 16, MenuScreen.PARCHMENT_DARK)
		odds.custom_minimum_size.x = 100
		row.add_child(odds)
		var tag := MenuScreen.ink_label("WINNER" if won else "", 16, MenuScreen.GOLD)
		tag.custom_minimum_size.x = 80
		row.add_child(tag)
		table.add_child(row)
