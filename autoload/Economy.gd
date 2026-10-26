extends Node
## Per-player resources (one stockpile per cliff). The host owns the ledger and
## broadcasts every change; clients just mirror it.

signal resources_changed(cliff_id: int)
## A message for the local player ("Not enough water...").
signal notice(text: String)

var ledger := EconomyLedger.new()


func _ready() -> void:
	reset()


## Host (or offline): back to starting resources.
func reset() -> void:
	ledger.reset({&"scrap": Defs.WAVE_CONFIG.start_scrap, &"water": 4, &"food": 4})
	_push()


func amount(cliff_id: int, res: StringName) -> int:
	return ledger.amount(cliff_id, res)


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
	var take := mini(amount, ledger.amount(cliff_id, res))
	if take > 0:
		ledger.spend(cliff_id, {res: take})
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
