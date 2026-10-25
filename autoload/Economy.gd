extends Node
## Per-player resources (one stockpile per cliff). The host owns the ledger and
## broadcasts every change; clients just mirror it.

signal resources_changed(cliff_id: int)

var ledger := EconomyLedger.new()


func _ready() -> void:
	reset()


## Host (or offline): back to starting resources.
func reset() -> void:
	ledger.reset({&"scrap": Defs.WAVE_CONFIG.start_scrap})
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
