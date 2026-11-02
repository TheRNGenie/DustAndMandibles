extends Node
## Per-player resources (one stockpile per cliff). The host owns the ledger and
## broadcasts every change; clients just mirror it.

signal resources_changed(cliff_id: int)
## A message for the local player ("Not enough water...").
signal notice(text: String)

var ledger := EconomyLedger.new()

# ---- CPU teammates (see CpuBudget) ----
## With a CPU teammate the whole team shares one stockpile (kept under cliff 0).
var shared := false
## Everything the team has had of each resource (start + earned), for CPU shares.
var gained: Dictionary = {}
## CPU name -> {resource: amount spent}.
var cpu_spent: Dictionary = {}
## Each CPU's share of the pool (1 / team size).
var cpu_share := 0.0


func _ready() -> void:
	reset()
	GameState.phase_changed.connect.call_deferred(_on_phase_changed)


## Host: each build phase after a held wave pays both players the town bounty.
func _on_phase_changed(p: GameState.Phase) -> void:
	var held := _in_wave and p == GameState.Phase.BUILD
	_in_wave = p == GameState.Phase.WAVE
	if not held or not multiplayer.is_server():
		return
	var pay := EconomyLedger.wave_pay(GameState.wave - 1)
	for cid in 2:
		earn(cid, {&"scrap": pay})
		if cid == 0 or not GameState.is_solo():
			notify_cliff(cid, "Town bounty for holding wave %d: +%d scrap." % [GameState.wave - 1, pay])


## True during a wave (so the bounty is paid only for a wave actually held).
var _in_wave := false


## Host (or offline): back to starting resources.
func reset() -> void:
	ledger.reset({&"scrap": Defs.WAVE_CONFIG.start_scrap, &"water": 6, &"herbs": 1})
	gained.clear()
	cpu_spent.clear()
	if shared:
		_merge_pools()
	_push()


## Host: turn on the shared team pool for CPU teammates (`team_size` counts
## humans and CPUs). Both cliffs' stockpiles merge into one.
func enable_shared_pool(team_size: int, cpus: int) -> void:
	shared = true
	cpu_share = CpuBudget.share(cpus, team_size)
	_merge_pools()
	_push()


func _merge_pools() -> void:
	ledger.transfer(1, 0, (ledger.stock[1] as Dictionary).duplicate())
	gained.clear()
	for r: StringName in ledger.stock[0]:
		gained[r] = int(ledger.stock[0][r])


## The stockpile a cliff draws from (one shared pool with CPU teammates).
func _pool(cliff_id: int) -> int:
	return 0 if shared else cliff_id


## Host: may this CPU spend `cost` without going over its share?
func cpu_can_spend(cpu_name: String, cost: Dictionary) -> bool:
	return can_afford(0, cost) and CpuBudget.may_spend_all(cpu_spent.get(cpu_name, {}), cost, gained, cpu_share)


## Host: a CPU teammate spends from the shared pool, within its share.
func cpu_spend(cpu_name: String, cost: Dictionary) -> bool:
	if not cpu_can_spend(cpu_name, cost) or not spend(0, cost):
		return false
	cpu_record(cpu_name, cost)
	return true


## Host: count something a CPU paid for through another path (e.g. watering a crop).
func cpu_record(cpu_name: String, cost: Dictionary) -> void:
	var mine: Dictionary = cpu_spent.get(cpu_name, {})
	for r: StringName in cost:
		mine[r] = int(mine.get(r, 0)) + int(cost[r])
	cpu_spent[cpu_name] = mine


func amount(cliff_id: int, res: StringName) -> int:
	return ledger.amount(_pool(cliff_id), res)


func can_afford(cliff_id: int, cost: Dictionary) -> bool:
	return ledger.can_afford(_pool(cliff_id), cost)


## Host only. Returns false if the cliff can't afford it.
func spend(cliff_id: int, cost: Dictionary) -> bool:
	if not multiplayer.is_server():
		return false
	var ok := ledger.spend(_pool(cliff_id), cost)
	if ok:
		_push()
	return ok


## Host only.
func earn(cliff_id: int, amounts: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	ledger.earn(_pool(cliff_id), amounts)
	if shared:
		for r: StringName in amounts:
			gained[r] = int(gained.get(r, 0)) + maxi(int(amounts[r]), 0)
	_push()


## Whose stockpile pays when `peer_id` uses something on `cliff_id`: your own,
## or that cliff's when playing solo.
func payer_cliff(peer_id: int, cliff_id: int) -> int:
	if GameState.is_solo() or not NetworkManager.players.has(peer_id):
		return cliff_id
	return NetworkManager.cliff_of(peer_id)


## Host: a bandit takes up to `amount` of a resource. Returns what it got.
func steal(cliff_id: int, res: StringName, amount: int) -> int:
	if not multiplayer.is_server():
		return 0
	var take := mini(amount, ledger.amount(_pool(cliff_id), res))
	if take > 0:
		ledger.spend(_pool(cliff_id), {res: take})
		_push()
	return take


## Host: message whoever owns a cliff (both players when solo).
func notify_cliff(cliff_id: int, text: String) -> void:
	if GameState.is_solo():
		notify(multiplayer.get_unique_id(), text)
		return
	for id: int in NetworkManager.players:
		if NetworkManager.cliff_of(id) == cliff_id:
			notify(id, text)


## Host: show a short message to one player.
func notify(peer_id: int, text: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		notice.emit(text)
	else:
		_notice.rpc_id(peer_id, text)


@rpc("authority", "reliable")
func _notice(text: String) -> void:
	notice.emit(text)


func _push() -> void:
	if multiplayer.is_server() and NetworkManager.is_online():
		_sync.rpc(ledger.stock)
	for cid in 2:
		resources_changed.emit(cid)


@rpc("authority", "reliable")
func _sync(stock: Dictionary) -> void:
	ledger.stock = stock
	for cid in 2:
		resources_changed.emit(cid)
