extends Node
## Hive amber, the run's side of it (rules and numbers: AmberRules). Keeps:
##   - which amber turret blueprints the team can craft this run (every rider's
##     own saved ones, Story.progress.amber_blueprints, plus anything Lucky sold
##     or the story found this run). Host-authoritative, mirrored to everyone.
##   - Lucky Moreau's sales (host checks and charges amber, like the gunsmith).
##   - one-night favours bought from Lucky, paid out at the next dawn.
##   - the one-of-each count of the amber turrets the team fields.
##
## API for story code (host):
##   Amber.grant(peer_id, units, why="")   amber into that rider's own pile
##                                         (they're told "+N hive amber (why).")
##   Amber.grant_cliff(cliff_id, units)    amber into a cliff's pile
##   Amber.grant_all(units, why="")        every held cliff gets `units`
##   Story.unlock_amber_blueprint(id)      (-> Amber.unlock_blueprint) a turret
##                                         blueprint for the team this run and
##                                         for every rider's saved progress
## Debug: --amber=N (N amber on every cliff at the start), --amberall (every
## blueprint known), --lucky (Lucky's stall open whatever the wave).

signal changed

## Blueprints the team holds this run (AmberRules.IDS members). Every peer.
var unlocked: Array[StringName] = []
## Host: favours waiting for the next dawn: [{"favour", "cliff", "peer"}].
var pending: Array[Dictionary] = []
var _was_wave := false


func _ready() -> void:
	GameState.phase_changed.connect(_on_phase)


## Every peer, when a world loads: back to this rider's own blueprints; clients
## tell the host theirs (the host merges everyone's and mirrors the set back).
func world_ready() -> void:
	pending.clear()
	_was_wave = false
	unlocked.clear()
	for id: StringName in _own_blueprints():
		_add(id)
	if not multiplayer.is_server():
		_tell.rpc_id(1, _own_ids())
	else:
		_push()
		# Debug: --amber=N puts N amber on every cliff once the run is set up.
		var n := GameState.flag_value("--amber").to_int()
		if n > 0 and GameState.debug_enabled():
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				for cid in Economy.ledger.cliff_ids():
					Economy.earn(cid, {AmberRules.ITEM: n}))
	changed.emit()


func _own_blueprints() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: String in Story.progress.amber_blueprints:
		if AmberRules.is_amber(StringName(s)):
			out.append(StringName(s))
	if GameState.has_flag("--amberall") and GameState.debug_enabled():
		for id in AmberRules.IDS:
			if not out.has(id):
				out.append(id)
	return out


func _own_ids() -> Array:
	return _own_blueprints().map(func(s: StringName) -> String: return String(s))


func _add(id: StringName) -> bool:
	if not AmberRules.is_amber(id) or unlocked.has(id):
		return false
	unlocked.append(id)
	return true


@rpc("any_peer", "reliable")
func _tell(ids: Array) -> void:
	if not multiplayer.is_server():
		return
	var any := false
	for v: Variant in ids:
		any = _add(StringName(str(v))) or any
	_push()
	if any:
		changed.emit()


func _push() -> void:
	if multiplayer.is_server() and NetworkManager.is_online() and not multiplayer.get_peers().is_empty():
		_mirror.rpc(unlocked.map(func(s: StringName) -> String: return String(s)))


@rpc("authority", "call_remote", "reliable")
func _mirror(ids: Array) -> void:
	unlocked.clear()
	for v: Variant in ids:
		_add(StringName(str(v)))
	changed.emit()


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


## Host (story code, Lucky): the team learns blueprint `id` for this run, and
## every rider keeps it in their saved progress. Returns false if unknown.
func unlock_blueprint(id: StringName, announce: bool = true) -> bool:
	if not AmberRules.is_amber(id):
		return false
	if not multiplayer.is_server():
		_save_blueprint(String(id)) # a client can only note it for itself
		return true
	var fresh := _add(id)
	_push()
	_save_blueprint(String(id))
	if NetworkManager.is_online() and not multiplayer.get_peers().is_empty():
		_save_blueprint.rpc(String(id))
	if fresh and announce:
		for pid: int in Economy._everyone():
			Economy.notify(pid, "%s! Craft it at your Workshop from hive amber and rare parts." % AmberRules.BLUEPRINTS[id])
	changed.emit()
	return true


## Every peer: keep it in this rider's story progress (saved).
@rpc("authority", "call_remote", "reliable")
func _save_blueprint(id: String) -> void:
	if not Story.progress.amber_blueprints.has(id):
		Story.progress.amber_blueprints.append(id)
		Story.save()
	_add(StringName(id))
	changed.emit()


# ------------------------------------------------------------------ granting amber

## Host: `units` of amber into `peer_id`'s own pile (your cliff's, solo: the
## cliff you play). `why` says where it came from: "+N hive amber (why)."
func grant(peer_id: int, units: int, why: String = "") -> void:
	if not multiplayer.is_server() or units <= 0:
		return
	var cid := Economy.payer_cliff(peer_id, NetworkManager.cliff_of(peer_id) if NetworkManager.players.has(peer_id) else 0)
	Economy.earn(cid, {AmberRules.ITEM: units})
	Economy.notify(peer_id, _grant_line(units, why))


## Host: `units` of amber into a cliff's pile.
func grant_cliff(cliff_id: int, units: int) -> void:
	if multiplayer.is_server() and units > 0:
		Economy.earn(cliff_id, {AmberRules.ITEM: units})


## Host: every cliff someone holds gets `units` (a story reward for the posse).
func grant_all(units: int, why: String = "") -> void:
	if not multiplayer.is_server() or units <= 0:
		return
	var done: Array[int] = []
	for pid: int in Economy._everyone():
		var cid := Economy.payer_cliff(pid, NetworkManager.cliff_of(pid) if NetworkManager.players.has(pid) else 0)
		if not done.has(cid):
			done.append(cid)
			Economy.earn(cid, {AmberRules.ITEM: units})
		Economy.notify(pid, _grant_line(units, why))


## "+6 hive amber (the Board's strongroom)." (it used to show only the bare `why`).
static func _grant_line(units: int, why: String) -> String:
	return "+%d hive amber%s." % [units, " (%s)" % why if why != "" else ""]


# ------------------------------------------------------------------ one of each

## Amber turrets of this kind standing anywhere (every cliff).
func placed_count(id: StringName) -> int:
	var n := 0
	var tree := get_tree()
	if tree == null:
		return 0
	for t: Node in tree.get_nodes_in_group("turrets"):
		if t is Turret and (t as Turret).def != null and (t as Turret).def.id == id and not t.is_queued_for_deletion():
			n += 1
	return n


## Ready-made ones waiting in any stockpile.
func held_count(id: StringName) -> int:
	var n := 0
	for cid in Economy.ledger.cliff_ids():
		n += Economy.amount(cid, id)
	return n


## Why `id` can't be crafted right now ("" = it can, given the parts).
func craft_block(id: StringName) -> String:
	if not is_unlocked(id):
		return "Needs its blueprint: found in %s, or sold by Lucky Moreau on the airship." % AmberRules.FOUND_IN[id]
	if not AmberRules.can_craft_another(placed_count(id), held_count(id)):
		return AmberRules.limit_text(id)
	return ""


# ------------------------------------------------------------------ Lucky Moreau

func lucky_open() -> bool:
	if GameState.has_flag("--lucky") and GameState.debug_enabled():
		return true
	var ch := Story.chapter() if Story.active() else null
	return AmberRules.lucky_open(ch.number if ch != null else 0, GameState.wave)


## Host: `peer_id` buys stock item `stock_id` from Lucky (on `cliff_id`'s stall:
## everything is paid from the buyer's own amber).
func buy(peer_id: int, stock_id: String) -> void:
	if not multiplayer.is_server():
		return
	var item := AmberRules.stock_item(stock_id)
	if item.is_empty() or not lucky_open():
		return
	var payer := Economy.payer_cliff(peer_id, NetworkManager.cliff_of(peer_id) if NetworkManager.players.has(peer_id) else 0)
	var price := int(item["price"])
	var why := sale_block(peer_id, item)
	if why != "":
		Economy.notify(peer_id, why)
		return
	if not Economy.spend(payer, {AmberRules.ITEM: price}):
		Economy.notify(peer_id, "Lucky taps the counter. \"That's %d amber, friend. Come back when you've been down the hole.\"" % price)
		return
	match str(item["kind"]):
		"gun":
			_sell_gun(peer_id, StringName(item["gun"]))
		"look":
			if peer_id != multiplayer.get_unique_id():
				_grant_look.rpc_id(peer_id, str(item["slot"]), str(item["option"]))
			else:
				_grant_look(str(item["slot"]), str(item["option"]))
			Economy.notify(peer_id, "%s: it's in your wardrobe." % str(item["name"]))
		"favour":
			var f: StringName = item["favour"]
			pending.append({"favour": f, "cliff": payer, "peer": peer_id})
			Economy.notify(peer_id, "Lucky winks. \"%s, tomorrow at dawn. You never saw me.\"" % AmberRules.FAVOURS[f]["name"])
		"blueprint":
			unlock_blueprint(StringName(item["turret"]))
	_sold.rpc()


## Why this rider can't buy that from Lucky right now ("" = they can, if they pay).
func sale_block(peer_id: int, item: Dictionary) -> String:
	match str(item.get("kind", "")):
		"gun":
			var gid: StringName = item["gun"]
			var owned: Dictionary = GunShop.loadouts.get(peer_id, {&"revolver": 0})
			if owned.has(gid) and AmberRules.is_lucky(int(owned[gid])):
				return "You already carry Lucky's %s." % AmberRules.FINISHES[gid]["name"]
			if not owned.has(gid) and owned.size() >= Gun.MAX_WEAPONS:
				return "Your three weapon slots are full. Drop one first (Q)."
		"blueprint":
			if is_unlocked(StringName(item["turret"])):
				return "The team already has that blueprint."
		"favour":
			for p: Dictionary in pending:
				if p["favour"] == item["favour"] and int(p["peer"]) == peer_id:
					return "Lucky already owes you that one. One a night."
	return ""


func _sell_gun(peer_id: int, gid: StringName) -> void:
	if not GunShop.loadouts.has(peer_id):
		GunShop.loadouts[peer_id] = {&"revolver": 0}
	var owned: Dictionary = GunShop.loadouts[peer_id]
	var code := AmberRules.with_lucky(int(owned.get(gid, 0)))
	owned[gid] = code
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id and n is Player:
			(n as Player).net.grant_weapon(gid, code)
	Economy.notify(peer_id, "Lucky slides it across the counter: the %s. \"Don't ask where it's been.\"" % AmberRules.FINISHES[gid]["name"])


## The buyer's own machine: an exclusive look into their wardrobe (saved).
@rpc("authority", "reliable")
func _grant_look(slot: String, option: String) -> void:
	var key := PerkTable.cosmetic_key(slot, option)
	if not Perks.profile.cosmetics.has(key):
		Perks.profile.cosmetics.append(key)
		if not GameState.has_flag("--debug"):
			Perks.save()
	Perks.profile_changed.emit() # (worn from the Wardrobe, like any look)


@rpc("authority", "call_local", "reliable")
func _sold() -> void:
	changed.emit()


# ------------------------------------------------------------------ favours

## Host: the dawn after a held wave pays out every favour bought before it.
func _on_phase(p: GameState.Phase) -> void:
	var dawn := _was_wave and p == GameState.Phase.BUILD
	_was_wave = p == GameState.Phase.WAVE
	if not dawn or not multiplayer.is_server() or pending.is_empty():
		return
	var due := pending.duplicate()
	pending.clear()
	for f: Dictionary in due:
		var fav: Dictionary = AmberRules.FAVOURS[f["favour"]]
		Economy.earn(int(f["cliff"]), (fav["gives"] as Dictionary).duplicate())
		var line := "Lucky's favour: %s (%s)." % [fav["name"], Economy.describe(fav["gives"])]
		if f["favour"] == &"bounty":
			for pid: int in Economy._everyone():
				Economy.notify(pid, "Lucky's bounty top-up: +%d scrap to the team pot." % int(fav["gives"][&"scrap"]))
		else:
			Economy.notify(int(f["peer"]), line)
