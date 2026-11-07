class_name StyleCombo
extends Node
## A player's style combo (ComboRules). The owner counts it: grapple hook-ons
## and let-gos, slide starts and mid-air kills each add one; standing still past
## the grace or taking a hit breaks it. The count goes to the host, which pays
## that rider's kills into the team pot at ComboRules.mult (host keeps
## `counts` by rider name, the kill feed's source).

signal changed(count: int, broke: bool)

## Host: rider display name -> their combo count.
static var counts: Dictionary = {}
## Host: rider peer id -> Hot Streak cut on their next airship purchase (ComboRules.STREAK).
static var streaks: Dictionary = {}

var player: Player
var count := 0
## This wave's best combo (Hot Streak).
var peak := 0
## Reached S during this wave: the combo can't fall below S until the wave ends (Logan).
var _s_lock := false
## Fractional gain carried between actions (a brand can add more than one per action).
var _gain := 0.0
var _still := 0.0
var _hp := -1.0


func setup(p: Player) -> void:
	player = p
	if not player.is_multiplayer_authority():
		return
	player.grapple.hooked.connect(add)
	player.grapple.let_go.connect(add)
	player.slide_started.connect(add)
	player.vitals.health_changed.connect(_on_health)
	GameState.phase_changed.connect(_on_phase)
	# Debug: --combo=N starts with that combo (screenshots of the grades).
	if GameState.debug_enabled() and GameState.flag_value("--combo") != "":
		var n := clampi(int(GameState.flag_value("--combo")), 0, ComboRules.CAP)
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			_set_count(n, false)
			_still = -1e9) # (held for the picture)


func bind_bugs(bugs: BugManager) -> void:
	if player.is_multiplayer_authority() and not bugs.bug_killed.is_connected(_on_kill):
		bugs.bug_killed.connect(_on_kill)


## The style combo is the Attack on Mandibles brand's own mechanic (Logan,
## 2026-11-07): riders of every other brand have none.
static func active() -> bool:
	return Brand.local_id() == BrandTable.MANDIBLES


## One qualifying action.
func add() -> void:
	if not player.is_multiplayer_authority() or GameState.phase == GameState.Phase.LOBBY or not active():
		return
	_gain += ComboRules.PER_ACTION * BrandTable.combo_gain(Brand.local_id()) # Attack on Mandibles: +25%
	var whole := int(_gain)
	_gain -= whole
	_set_count(mini(count + whole, ComboRules.CAP), false)


## More grace before standing still breaks it (a Glint Beetle kill: 3 s).
func extend(seconds: float) -> void:
	_still -= seconds


func break_combo() -> void:
	_gain = 0.0
	if _s_lock:
		if count > ComboRules.S_FLOOR:
			_set_count(ComboRules.S_FLOOR, false) # kept at S till the wave's over
		return
	if count > 0:
		_set_count(0, true)


func _process(delta: float) -> void:
	if player == null or not player.is_multiplayer_authority() or count <= 0:
		return
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.0 or not player.is_on_floor()
	_still = minf(_still, 0.0) if moving else _still + delta # (a negative _still is extra grace)
	if _still >= ComboRules.still_secs(GameState.wave):
		_still = 0.0
		break_combo()


func _on_health(hp: float, _max_hp: float) -> void:
	if _hp >= 0.0 and hp < _hp - 0.01:
		break_combo()
	_hp = hp


func _on_kill(_bug: String, _bug_cliff: int, source: String, _source_cliff: int, _loot: Dictionary) -> void:
	if source != player.display_name():
		return
	if count >= ComboRules.CAP:
		player.add_shake(0.25) # S+: every kill lands with a punch
	if not player.is_on_floor():
		add()


func _on_phase(p: GameState.Phase) -> void:
	if p != GameState.Phase.WAVE:
		_s_lock = false
	if p == GameState.Phase.WAVE:
		peak = count
	elif p == GameState.Phase.BUILD and GameState.wave > 1:
		var cut := ComboRules.streak_cut(peak)
		if cut > 0.0:
			local_streak = maxf(local_streak, cut)
			Economy.notice.emit("Hot Streak! Lucky Moreau tips his hat: %d%% off your next purchase aboard the Lucky Mandible." % roundi(cut * 100.0))
		if multiplayer.is_server():
			_note_streak(player.get_multiplayer_authority(), peak)
		elif NetworkManager.is_online():
			_tell_streak.rpc_id(1, peak)
		peak = count


@rpc("any_peer", "reliable")
func _tell_streak(p: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		_note_streak(multiplayer.get_remote_sender_id(), p)


static func _note_streak(peer: int, p: int) -> void:
	var cut := ComboRules.streak_cut(p)
	if cut > float(streaks.get(peer, 0.0)):
		streaks[peer] = cut


## Host: the Hot Streak cut waiting for this rider's next purchase (0 if none).
static func streak_for(peer: int) -> float:
	return float(streaks.get(peer, 0.0))


## Local: your Hot Streak cut waiting at the shops (shown in their taglines).
static var local_streak := 0.0


static func streak_note() -> String:
	return "HOT STREAK: %d%% off your next purchase. " % roundi(local_streak * 100.0) if local_streak > 0.0 else ""


## Host: the purchase went through: the streak's spent (and the rider's banner goes).
static func use_streak(peer: int) -> void:
	streaks.erase(peer)
	for n: Node in NetworkManager.get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p != null and p.get_multiplayer_authority() == peer and p.combo != null:
			if peer == p.multiplayer.get_unique_id():
				p.combo._streak_spent()
			else:
				p.combo._streak_spent.rpc_id(peer)


@rpc("authority", "reliable")
func _streak_spent() -> void:
	local_streak = 0.0


func _set_count(n: int, broke: bool) -> void:
	if n == count and not broke:
		return
	count = n
	peak = maxi(peak, n)
	if n >= ComboRules.S_FLOOR and GameState.phase == GameState.Phase.WAVE:
		_s_lock = true
	_still = 0.0
	if GameState.has_flag("--combolog"):
		print("[combo] %s: %d %s%s" % [player.display_name(), count, ComboRules.grade(count), " (broke)" if broke else ""])
	changed.emit(count, broke)
	if multiplayer.is_server():
		counts[player.display_name()] = count
	elif NetworkManager.is_online():
		_tell_host.rpc_id(1, count)


@rpc("any_peer", "reliable")
func _tell_host(n: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		counts[player.display_name()] = clampi(n, 0, ComboRules.CAP)


## Host: a kill's team-pot pay scaled by the killer's combo (1x for turrets and CPUs).
static func scale_pay(source: String, amount: float) -> float:
	return amount * ComboRules.mult(int(counts.get(source, 0)))
