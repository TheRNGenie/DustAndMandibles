extends Node
## The brand each rider burns on at the start of a run (rules and numbers:
## BrandTable). Chosen on the branding-iron screen in the lobby (BrandScreen),
## synced like perk loadouts: a client sends its pick to the host, the host
## checks it and mirrors everyone's picks back; picks lock once the run starts.
## Host-owned effects ask of(peer) / of_cliff(cid); the local player's own
## (reload) ask local_id(). The CPU partner gets a brand too (key 0).
## The local player's brand also picks the UI theme set (UiStyle.apply).
##
## Also keeps the airship casino's pit boss: every Snake Eyes cheat that gets
## past him raises "heat" (the next is likelier to be caught, BrandTable), and a
## caught rider is barred from the tables for a wave and starts cold again
## (bans are mirrored so the game screens can say so).
##
## Flags: --brand=sheaf|irons|snake|none picks on start (tests skip the screen).

signal changed
## Host -> everyone: a cheat was caught (the game screen shows it).
signal caught(peer_id: int)

const CPU_KEY := 0

## peer id (0 = CPU partner) -> brand id. Host-authoritative, mirrored on clients.
var picks: Dictionary = {}
## This rider's own pick ("" until chosen this run).
var local: StringName = &""
## peer id -> wave the ban runs until (mirrored).
var bans: Dictionary = {}
var _heat: Dictionary = {} # host: peer id -> cheats that got past the pit boss since he last caught them
var _run_active := false


func _ready() -> void:
	UiStyle.install()
	NetworkManager.connected_to_host.connect(_submit_local)
	NetworkManager.players_changed.connect(_on_players_changed)
	GameState.phase_changed.connect(_on_phase)
	var flag := GameState.flag_value("--brand")
	if flag != "":
		choose(BrandTable.valid(flag))
	if GameState.flag_value("--uigallery") != "": # every screen photographed in turn (scenes/debug/ui_gallery.gd)
		var gallery := (load("res://scenes/debug/ui_gallery.gd") as GDScript).new() as Node
		gallery.name = "UiGallery"
		add_child(gallery)
	if GameState.flag_value("--themeview") != "" or GameState.flag_value("--brandview") != "":
		var view := (load("res://scenes/debug/theme_views.gd") as GDScript).new() as Node
		view.name = "ThemeViews"
		add_child(view)


func _process(_delta: float) -> void:
	if _run_active and GameState.phase == GameState.Phase.LOBBY:
		_run_active = false # back at the menu (GameState.reset): pick again next run
		bans.clear()
		_heat.clear()
		if GameState.flag_value("--brand") == "":
			local = &""
			picks.clear()
			UiStyle.apply(&"base")
			changed.emit()


# ------------------------------------------------------------------ choosing

## Lobby: burn this brand on (or none). Re-themes the UI at once.
func choose(id: StringName) -> bool:
	if not editable():
		return false
	local = BrandTable.valid(id)
	UiStyle.apply(BrandTable.theme_of(local))
	if NetworkManager.is_online() and not multiplayer.is_server():
		_submit_local()
	else:
		picks[_me()] = local
		_broadcast()
	changed.emit()
	return true


func editable() -> bool:
	return not _run_active


func has_chosen() -> bool:
	return local != &""


func _me() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


# ------------------------------------------------------------------ queries

## A rider's brand (none if they haven't picked).
func of(peer_id: int) -> StringName:
	if peer_id == _me() and local != &"":
		return local
	return BrandTable.valid(picks.get(peer_id, BrandTable.NONE))


func local_id() -> StringName:
	return of(_me())


## The brand of whoever owns a cliff (the CPU partner's on its cliff).
func of_cliff(cid: int) -> StringName:
	var peer := Perks.peer_for_cliff(cid)
	return of(peer) if peer > 0 else BrandTable.valid(picks.get(CPU_KEY, BrandTable.NONE))


## The brand on a peer's player (lobby roster, map, feed): "" for none.
func mark_of(peer_id: int) -> StringName:
	var b := of(peer_id)
	return &"" if b == BrandTable.NONE else b


# ------------------------------------------------------------------ effects (host unless noted)

## Crop growth multiplier on a cliff's plateau.
func growth_mult(cid: int) -> float:
	return BrandTable.growth_mult(of_cliff(cid))


func harvest(peer_id: int, h: Dictionary) -> Dictionary:
	var out := BrandTable.scale_yield(h, of(peer_id), randf())
	if out != h and not h.is_empty():
		Economy.notify(peer_id, "The Sheaf: a fuller harvest.")
	return out


func water_bonus(peer_id: int, take: int) -> int:
	return BrandTable.water_bonus(take, of(peer_id))


func seed_cost(peer_id: int, cost: int) -> int:
	return BrandTable.seed_cost(cost, of(peer_id))


## Local: reload time multiplier.
func reload_mult() -> float:
	return BrandTable.reload_mult(local_id())


## A kill's loot, with the killer's Crossed Irons bonus (source_cliff = the killer's cliff).
func kill_loot(loot: Dictionary, source_cliff: int) -> Dictionary:
	if source_cliff < 0:
		return loot
	return BrandTable.kill_loot(loot, of_cliff(source_cliff))


func heap_loot(peer_id: int, chitin: int) -> Dictionary:
	return BrandTable.heap_loot(chitin, of(peer_id))


## Damage multiplier for a hit by this peer on a bug (Snake Eyes vs bosses).
func boss_mult(peer_id: int, bug: Object) -> float:
	var b := bug as Bug
	if b == null or b.def == null or b.def.boss_tip == "":
		return 1.0
	return BrandTable.boss_mult(of(peer_id))


# ------------------------------------------------------------------ the pit boss

func is_banned(peer_id: int) -> bool:
	return GameState.wave < int(bans.get(peer_id, -1))


func local_banned() -> bool:
	return is_banned(_me())


func ban_wave(peer_id: int) -> int:
	return int(bans.get(peer_id, -1))


## Zipline anchors' scrap price for this rider (Attack on Mandibles makes them cheaper).
func zip_cost_mult(peer_id: int) -> float:
	return BrandTable.zip_cost_mult(of(peer_id))


## Local: can this rider cheat at the tables right now?
func local_can_cheat() -> bool:
	return BrandTable.can_cheat(local_id()) and not local_banned()


## Local: the risk of being caught on the next cheat at `game`.
func local_risk(game: String) -> float:
	return BrandTable.catch_chance(game, _local_heat_count)


var _local_heat_count := 0


## Host: a rider tries a cheat. Returns 1 = unnoticed, 0 = not allowed, -1 = caught (now barred).
func cheat(peer_id: int, game: String) -> int:
	if not multiplayer.is_server():
		return 0
	if not BrandTable.can_cheat(of(peer_id)) or is_banned(peer_id):
		return 0
	var heat := int(_heat.get(peer_id, 0))
	var risk := BrandTable.catch_chance(game, heat)
	if GameState.has_flag("--cheatlog"):
		print("[brand] peer %d cheats at %s: risk %.2f" % [peer_id, game, risk])
	var forced := GameState.flag_value("--caught")
	if (forced == "" and randf() < risk) or forced == "yes":
		_heat[peer_id] = 0 # kicked off: the next cheat starts at the base risk again
		_send_heat(peer_id, 0)
		bans[peer_id] = BrandTable.ban_until(GameState.wave)
		_sync_bans()
		Economy.notify(peer_id, "The pit boss caught you cheating! You're barred from the tables until wave %d." % int(bans[peer_id]))
		if NetworkManager.is_online():
			_caught_fx.rpc(peer_id)
		else:
			_caught_fx(peer_id)
		return -1
	_heat[peer_id] = heat + 1
	_send_heat(peer_id, heat + 1)
	return 1


func _send_heat(peer_id: int, n: int) -> void:
	if peer_id == _me():
		_local_heat_count = n
	elif NetworkManager.is_online():
		_set_heat.rpc_id(peer_id, n)


@rpc("authority", "reliable")
func _set_heat(n: int) -> void:
	_local_heat_count = n


@rpc("authority", "call_local", "reliable")
func _caught_fx(peer_id: int) -> void:
	caught.emit(peer_id)


func _sync_bans() -> void:
	if NetworkManager.is_online():
		_set_bans.rpc(bans)
	changed.emit()


@rpc("authority", "reliable")
func _set_bans(b: Dictionary) -> void:
	bans.clear()
	for k: Variant in b:
		bans[int(k)] = int(b[k])
	changed.emit()


# ------------------------------------------------------------------ networking

func _submit_local() -> void:
	if NetworkManager.is_online() and not multiplayer.is_server() and local != &"":
		_submit.rpc_id(1, String(local))


@rpc("any_peer", "reliable")
func _submit(id: String) -> void:
	if not multiplayer.is_server() or _run_active:
		return
	picks[multiplayer.get_remote_sender_id()] = BrandTable.valid(id)
	_broadcast()


func _broadcast() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if local != &"":
		picks[_me()] = local
	if NetworkManager.is_online():
		var wire: Dictionary = {}
		for k: int in picks:
			wire[k] = String(picks[k])
		_sync.rpc(wire)
	changed.emit()


@rpc("authority", "reliable")
func _sync(wire: Dictionary) -> void:
	picks.clear()
	for k: Variant in wire:
		picks[int(k)] = BrandTable.valid(wire[k])
	# A continued run hands us back the brand we rode with.
	var mine := multiplayer.get_unique_id()
	if picks.has(mine) and picks[mine] != local:
		local = picks[mine]
		UiStyle.apply(BrandTable.theme_of(local))
	changed.emit()


func _on_players_changed() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	for id: int in picks.keys():
		if id != 1 and id != CPU_KEY and not NetworkManager.players.has(id):
			picks.erase(id)
	if NetworkManager.has_cpu() and not picks.has(CPU_KEY):
		picks[CPU_KEY] = BrandTable.cpu_pick(randi())
	elif not NetworkManager.has_cpu():
		picks.erase(CPU_KEY)
	_broadcast()


func _on_phase(p: GameState.Phase) -> void:
	if p != GameState.Phase.BUILD or _run_active:
		return
	_run_active = true
	_heat.clear()
	_local_heat_count = 0
	if multiplayer.is_server():
		if NetworkManager.has_cpu() and not picks.has(CPU_KEY):
			picks[CPU_KEY] = BrandTable.cpu_pick(randi())
		_broadcast()


# ------------------------------------------------------------------ run save

## Host: brands by cliff for the run save {cliff: id} (the CPU's cliff too).
func save_state() -> Dictionary:
	var out: Dictionary = {}
	for cid in WorldLayout.cliff_count(): # Maps: every cliff on the map
		out[cid] = String(of_cliff(cid))
	return out


## Host, resuming: put everyone back in the brand they rode with.
func restore_state(by_cliff: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	for key: Variant in by_cliff:
		var cid := int(key)
		var id := BrandTable.valid(by_cliff[key])
		var peer := Perks.peer_for_cliff(cid)
		if peer > 0:
			picks[peer] = id
			if peer == _me():
				local = id
				UiStyle.apply(BrandTable.theme_of(id))
		else:
			picks[CPU_KEY] = id
	_broadcast()
	changed.emit()
