class_name LatchDirector
extends Node
## Latch bugs (movement plan #5). From wave FIRST_WAVE, 1-3 times a wave (count_for) a
## climbing bug scuttles up under a turret line and clamps onto the face just
## below the lip. Clamped, turrets can't hurt it (it's tucked under them) and
## every turret within RADIUS fires SLOW times slower. Only a rider close
## enough to touch it (grapple down, then whip or shoot from POINT_BLANK) can
## pry it off: that kills it. CPU partners clear the ones on their own cliff
## after CPU_DELAY s. Host runs it; turrets ask `jam_mult`.

const FIRST_WAVE := 3
const RADIUS := 8.0
const SLOW := 2.0 ## fire interval x2 = 50% slower
const POINT_BLANK := 6.0
const CPU_DELAY := 5.0
const DEPTH := 6.0 ## metres under the lip it clamps at

## Every latched bug (all peers: the latch is mirrored on the bug).
static var latched: Array[Bug] = []

var _plan: Array[float] = []
var _t := 0.0


func _ready() -> void:
	GameState.phase_changed.connect(_on_phase)


func _on_phase(p: GameState.Phase) -> void:
	if not multiplayer.is_server():
		return
	if p == GameState.Phase.WAVE and GameState.wave >= FIRST_WAVE and not GameState.tutorial:
		_t = 0.0
		_plan.clear()
		for i in count_for(GameState.wave):
			_plan.append(randf_range(8.0, 35.0))
		_plan.sort()
	elif p != GameState.Phase.WAVE:
		_plan.clear()


func _process(delta: float) -> void:
	_prune()
	if not multiplayer.is_server():
		return
	_t += delta
	while not _plan.is_empty() and _t >= _plan[0]:
		_plan.pop_front()
		_latch_one()
	_cpu_clear(delta)


## Latches a wave: 1 at waves 3-5, 2 at 6-10, 3 from 11.
static func count_for(wave: int) -> int:
	if wave < FIRST_WAVE:
		return 0
	return 1 if wave <= 5 else (2 if wave <= 10 else 3)


static func _prune() -> void:
	for i in range(latched.size() - 1, -1, -1):
		var b := latched[i]
		if not is_instance_valid(b) or not b.is_alive() or not b.latched:
			latched.remove_at(i)


## Turret fire interval multiplier at `pos` on cliff `cid`.
static func jam_mult(cid: int, pos: Vector3) -> float:
	for b in latched:
		if is_instance_valid(b) and b.cliff_id == cid and b.global_position.distance_to(pos) <= RADIUS:
			return SLOW
	return 1.0


## Host: a climbing bug on a cliff that has turrets scuttles under one and clamps on.
func _latch_one() -> void:
	var bm := WaveDirector.bug_manager
	if bm == null:
		return
	var picks: Array[Bug] = []
	for c: Node in bm.get_children():
		var b := c as Bug
		if b != null and b.is_alive() and b.state == Bug.State.CLIMBING and b.boss == null and not b.latched \
				and b.def.behavior != BugDef.Behavior.TANK and b.site < 0:
			picks.append(b)
	picks.shuffle()
	for b in picks:
		var turrets := get_tree().get_nodes_in_group("turrets").filter(func(t: Node) -> bool:
			return t is Turret and (t as Turret).cliff_id == b.cliff_id and not (t as Turret).is_queued_for_deletion())
		if turrets.is_empty():
			continue
		var t := turrets[randi() % turrets.size()] as Turret
		b.latch_at(t.global_position.z, WorldLayout.CLIFF_HEIGHT - DEPTH)
		# It jams that cliff's turrets (which cover the partner), so the partner,
		# whose own turrets face this wall, swings over to pry it off.
		Economy.notify_cliff(b.cliff_id, "A %s has clamped on under your %s and jammed your guns!" % [b.def.display_name, t.def.display_name])
		for cid in WorldLayout.cliff_count():
			if cid != b.cliff_id:
				Economy.notify_cliff(cid, "A %s is jamming the guns that cover you on %s. Swing over and pry it off up close!" % [b.def.display_name, WorldLayout.map().name_of(b.cliff_id)])
		return


var _cpu_t: Dictionary = {}


## Host: CPU partners pry off the latches on their own cliff, slowly but surely.
func _cpu_clear(delta: float) -> void:
	for b in latched:
		if not is_instance_valid(b) or not _cpu_cliff(b.cliff_id):
			continue
		var k := b.get_instance_id()
		_cpu_t[k] = float(_cpu_t.get(k, 0.0)) + delta
		if float(_cpu_t[k]) >= CPU_DELAY:
			_cpu_t.erase(k)
			b.unlatch_kill("CPU", b.cliff_id)


static func _cpu_cliff(cid: int) -> bool:
	return NetworkManager.has_cpu() and NetworkManager.cpu_cliffs().has(cid)
