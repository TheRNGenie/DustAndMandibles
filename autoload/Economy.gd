extends Node
## The team's resources. (Players see &"scrap" as "chitin" and &"chitin" as
## "scrap": ResNames, DECISIONS 162; the ids below are internal.) Scrap is one shared team pot (everyone builds from it
## and earns into it); chitin, water, crops, seeds and parts are personal, one
## stockpile per cliff (EconomyLedger keeps the split). The host owns the ledger
## and broadcasts every change; clients just mirror it.

signal resources_changed(cliff_id: int)
## A message for the local player ("Not enough water...").
signal notice(text: String)
## Every peer: a breaching bug carried this off a cliff (scrap comes out of the team pot; HUD shows the loss).
signal stolen_from(cliff_id: int, amounts: Dictionary)
## Every peer: a sarsaparilla tonic landed on `cliff_id` (PartnerTonic); `secs` left.
signal tonic_changed(cliff_id: int, secs: float)

var ledger := EconomyLedger.new()

# ---- CPU teammates (see CpuBudget) ----
## A CPU teammate is playing: it spends the team's scrap only up to its fair share.
var cpu_mode := false
## Everything the team has had of each shared resource (start + earned), for CPU shares.
var gained: Dictionary = {}
## CPU name -> {resource: amount spent}.
var cpu_spent: Dictionary = {}
## Each CPU's share of the team pot (1 / team size).
var cpu_share := 0.0

## Sarsaparilla tonic: cliff -> seconds of wave time left (PartnerTonic). Every
## peer counts it down; the host's sends keep everyone in step.
var tonic_left: Dictionary = {}


func _ready() -> void:
	reset()
	GameState.phase_changed.connect.call_deferred(_on_phase_changed)


## Host: each build phase after a held wave pays the team pot the town bounty
## (one bounty per cliff, as when every cliff had its own pile).
func _on_phase_changed(p: GameState.Phase) -> void:
	var held := _in_wave and p == GameState.Phase.BUILD
	_in_wave = p == GameState.Phase.WAVE
	if not held or not multiplayer.is_server():
		return
	var pay := EconomyLedger.wave_pay(GameState.wave - 1) * WorldLayout.cliff_count()
	earn(0, {&"scrap": pay})
	for id: int in _everyone():
		notify(id, "Town bounty for holding wave %d: +%s to the team pot." % [GameState.wave - 1, UiStyle.cost(pay, ResNames.TEAM_ID)])


## Every human peer (just us offline).
func _everyone() -> Array[int]:
	var out: Array[int] = []
	if NetworkManager.is_online() and not GameState.is_solo():
		for id: int in NetworkManager.players:
			out.append(id)
	if out.is_empty():
		out.append(multiplayer.get_unique_id())
	return out


## True during a wave (so the bounty is paid only for a wave actually held).
var _in_wave := false


func _process(delta: float) -> void:
	if tonic_left.is_empty():
		return
	var wave := GameState.phase == GameState.Phase.WAVE
	for cid: int in tonic_left.keys():
		var left := PartnerTonic.tick(float(tonic_left[cid]), delta, wave)
		if left <= 0.0:
			tonic_left.erase(cid)
			tonic_changed.emit(cid, 0.0)
		else:
			tonic_left[cid] = left


## Seconds of tonic left on a cliff's turrets.
func tonic(cliff_id: int) -> float:
	return float(tonic_left.get(cliff_id, 0.0))


## Shot interval multiplier for the turrets on `cliff_id` (faster under a tonic).
func tonic_interval_mult(cliff_id: int) -> float:
	return PartnerTonic.interval_mult(tonic(cliff_id))


## Host: `peer_id` (on `from_cliff`) brews a sarsaparilla root into a tonic for
## their partner. Returns whether it went out. `peer_id` -1 = a CPU teammate.
func send_tonic(peer_id: int, from_cliff: int) -> bool:
	if not multiplayer.is_server():
		return false
	var payer := from_cliff if peer_id < 0 else payer_cliff(peer_id, from_cliff)
	var to := PartnerTonic.partner_of(from_cliff)
	if to < 0 or to == from_cliff:
		return false
	# A player's tonic root comes from what they carry (PlayerCarry); the CPU's from the cliff.
	var carry := PlayerCarry.of(get_tree(), peer_id) if peer_id > 0 else null
	if carry != null:
		if not carry.take(PartnerTonic.ITEM, 1):
			notify(peer_id, "You aren't carrying any sarsaparilla root. Grow some: seeds at the airship market.")
			return false
	elif not spend(payer, {PartnerTonic.ITEM: 1}):
		if peer_id >= 0:
			notify(peer_id, "No sarsaparilla root left. Grow some: seeds at the airship market.")
		return false
	var left := PartnerTonic.add(tonic(to))
	_sync_tonic.rpc(to, left)
	var where := WorldLayout.map().name_of(to)
	var pct := int(round(PartnerTonic.FIRE_RATE_BONUS * 100.0))
	if peer_id >= 0:
		notify(peer_id, "Tonic sent! %s's turrets fire %d%% faster for %s of wave time." % [where, pct, UiStyle.clock(left)])
	for id: int in _everyone():
		if id != peer_id and (GameState.is_solo() or NetworkManager.cliff_of(id) == to):
			notify(id, "Your partner sent you a sarsaparilla tonic: your turrets fire %d%% faster for %s of wave time." % [pct, UiStyle.clock(left)])
	return true


@rpc("authority", "call_local", "reliable")
func _sync_tonic(cliff_id: int, secs: float) -> void:
	tonic_left[cliff_id] = secs
	tonic_changed.emit(cliff_id, secs)


## Host (or offline): back to starting resources.
func reset() -> void:
	ledger.reset({&"scrap": Defs.WAVE_CONFIG.start_scrap, &"water": 0, &"herbs": 3}, WorldLayout.cliff_count()) # no water until the first wave starts the pumps (Logan)
	gained.clear()
	cpu_spent.clear()
	tonic_left.clear()
	for r: StringName in EconomyLedger.SHARED:
		gained[r] = ledger.team_amount(r)
	_push()


## Host: CPU teammates are playing (`team_size` counts humans and CPUs). Each
## may spend 1 / team size of the team's scrap; their chitin is their own.
func enable_cpu_budget(team_size: int, cpus: int) -> void:
	cpu_mode = true
	cpu_share = CpuBudget.share(cpus, team_size)
	_push()


## Host: may this CPU (on `cliff_id`) pay `cost`? Shared resources (scrap) only
## up to its fair share of everything the team has had; its own stockpile freely.
func cpu_can_spend(cpu_name: String, cost: Dictionary, cliff_id: int) -> bool:
	if not can_afford(cliff_id, cost):
		return false
	var shared_part := {}
	for r: StringName in cost:
		if EconomyLedger.is_shared(r):
			shared_part[r] = cost[r]
	return CpuBudget.may_spend_all(cpu_spent.get(cpu_name, {}), shared_part, gained, cpu_share)


## Host: a CPU teammate pays, within its share of the team pot.
func cpu_spend(cpu_name: String, cost: Dictionary, cliff_id: int) -> bool:
	if not cpu_can_spend(cpu_name, cost, cliff_id) or not spend(cliff_id, cost):
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
	return ledger.amount(cliff_id, res)


## The team pot's scrap (what everyone builds from).
func team_scrap() -> int:
	return ledger.team_amount(&"scrap")


func can_afford(cliff_id: int, cost: Dictionary) -> bool:
	return ledger.can_afford(cliff_id, cost)


## Host only. Returns false if the cliff can't afford it.
func spend(cliff_id: int, cost: Dictionary) -> bool:
	if not multiplayer.is_server():
		return false
	var ok := ledger.spend(cliff_id, cost)
	if ok:
		_push()
	return ok


## Host only.
func earn(cliff_id: int, amounts: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	ledger.earn(cliff_id, amounts)
	for r: StringName in amounts:
		if EconomyLedger.is_shared(r):
			gained[r] = int(gained.get(r, 0)) + maxi(int(amounts[r]), 0)
	_push()


## Host: move personal resources (chitin, crops...) to another cliff (F7 gives).
## Scrap is already everyone's, so it never moves.
func give(from_cliff: int, to_cliff: int, amounts: Dictionary) -> bool:
	if not multiplayer.is_server():
		return false
	var ok := ledger.transfer(from_cliff, to_cliff, amounts)
	if ok:
		_push()
	return ok


## Whose stockpile pays when `peer_id` uses something on `cliff_id`: your own,
## or that cliff's when playing solo. (Scrap always comes from the team pot.)
func payer_cliff(peer_id: int, cliff_id: int) -> int:
	if GameState.is_solo() or not NetworkManager.players.has(peer_id):
		return cliff_id
	return NetworkManager.cliff_of(peer_id)


## Host: a bandit takes up to `amount` of a resource. Returns what it got.
func steal(cliff_id: int, res: StringName, amount: int) -> int:
	if not multiplayer.is_server():
		return 0
	var take := mini(amount, ledger.amount(cliff_id, res))
	if take > 0:
		ledger.spend(cliff_id, {res: take})
		_push()
	return take


## Host: a bug that breached grabs what it can of `wanted` ({res: amount}).
## Returns what it actually took (empty if the stockpile was bare).
func breach_steal(cliff_id: int, wanted: Dictionary) -> Dictionary:
	var got := {}
	for r: StringName in wanted:
		var n := steal(cliff_id, r, int(wanted[r]))
		if n > 0:
			got[r] = n
	if not got.is_empty():
		_show_stolen.rpc(cliff_id, got)
	return got


@rpc("authority", "call_local", "reliable")
func _show_stolen(cliff_id: int, amounts: Dictionary) -> void:
	stolen_from.emit(cliff_id, amounts)


## "12 chitin and 2 scrap" for messages (player-facing names, ResNames).
static func describe(amounts: Dictionary) -> String:
	return BreachRules.describe(amounts)


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


## The ledger changed: tell everyone once, at the end of this frame, however
## many kills and purchases changed it in between (one RPC, one signal per cliff).
func _push() -> void:
	if _dirty:
		return
	_dirty = true
	_flush.call_deferred()


var _dirty := false


func _flush() -> void:
	if not _dirty:
		return
	_dirty = false
	if multiplayer.is_server() and NetworkManager.is_online():
		_sync.rpc(ledger.stock, cpu_mode)
	for cid in ledger.cliff_ids():
		resources_changed.emit(cid)


## The whole ledger (team pot under EconomyLedger.TEAM) and whether a CPU plays.
@rpc("authority", "reliable")
func _sync(stock: Dictionary, cpus: bool = false) -> void:
	ledger.stock = stock
	cpu_mode = cpus
	for cid in ledger.cliff_ids():
		resources_changed.emit(cid)
