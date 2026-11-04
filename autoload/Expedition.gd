extends Node
## Canyon Expeditions (core): who is down on the canyon floor, their backpacks,
## dropped sacks, noise and the risk of staying down too long. Host-authoritative;
## every change is synced to every peer.
##
## Getting down: the rope anchor on each cliff's lip (RopeAnchor: E, ~8 s on a
## hand winch), or the grappling hook (Player.on_trip). Getting up: the same
## rope, a grapple, or hailing the airship (G on the floor, AIRSHIP_FARE chitin).
## Only in the build phase. While anyone is down their lever can't be thrown and
## the ready countdown can't start (GameState asks here).
##
## Contract with the floor sites (components/expedition_api.gd looks this
## autoload up by name, so keep these names):
##   add_to_backpack(peer_id, items) -> int, is_down(peer_id) -> bool,
##   make_noise(pos, radius), floor_time(peer_id) -> float,
##   signals went_down(peer_id), came_up(peer_id), noise(pos, radius).

signal went_down(peer_id: int)
signal came_up(peer_id: int)
## Host: a loud sound on the floor (gunshots call make_noise). Sleepy bugs listen.
signal noise(pos: Vector3, radius: float)
## Every peer: a backpack's contents changed.
signal backpack_changed(peer_id: int)
## Host (Story): a story item (story_items) came up out of the canyon in a
## backpack: it is not unpacked onto the stockpile; the chapter takes it.
signal story_item_up(peer_id: int, item: StringName, units: int)
## Host (Story): a downed player's story item, left where they fell (not in the sack).
signal story_item_dropped(peer_id: int, item: StringName, units: int, pos: Vector3)

const LootSackScript := preload("res://scenes/structures/loot_sack.gd")
const TunnelRumble := preload("res://scenes/bugs/tunnel_rumble.gd")

## Every peer: peer id -> true while that player is down in the canyon.
var down: Dictionary = {}
## Every peer: peer id -> {item: units}.
var packs: Dictionary = {}
## Host: what the last add_to_backpack couldn't fit ({item: units}).
var last_leftover: Dictionary = {}
## Story: items a chapter owns (the pump valve, the Queen Spider's gland, dynamite).
## They ride in backpacks like loot, but never land in the stockpile or a sack.
var story_items: Array[StringName] = []
## Story: a chapter that runs its own floor hunters (Down the Hole) turns the
## risk clock's rumbles and hunters off.
var risk_enabled := true
## Story: maps a position somewhere special (inside a tunnel set) to where a
## dropped sack or item should land on the canyon floor. Empty = as is.
var drop_point_hook: Callable

# Host: peer -> seconds down this build phase / extra risk from noise /
# seconds since the last rumble and hunt / hunters out after them.
var _floor_secs: Dictionary = {}
var _heat: Dictionary = {}
var _rumble_t: Dictionary = {}
var _hunt_t: Dictionary = {}
var _hunters: Dictionary = {}
# Every peer: sack id -> LootSack. Host: sack id -> wave it was dropped in.
var _sacks: Dictionary = {}
var _sack_wave: Dictionary = {}
var _next_sack := 0


func _ready() -> void:
	GameState.phase_changed.connect(_on_phase)
	NetworkManager.player_left.connect(_on_player_left)


# ------------------------------------------------------------------ the contract

## Host: put loot in a player's backpack. Returns how many units fitted (what
## didn't is in last_leftover). Synced to everyone.
func add_to_backpack(peer_id: int, items: Dictionary) -> int:
	if not multiplayer.is_server():
		return 0
	var pack := Backpack.make(packs.get(peer_id, {}))
	var n := pack.add(items)
	last_leftover = pack.leftover
	if n > 0:
		_set_pack(peer_id, pack.items)
	return n


## Host: take items out of a player's backpack (all or nothing). Synced.
func take_from_backpack(peer_id: int, items: Dictionary) -> bool:
	if not multiplayer.is_server():
		return false
	var have: Dictionary = (packs.get(peer_id, {}) as Dictionary).duplicate()
	for k: Variant in items:
		if int(have.get(StringName(k), 0)) < int(items[k]):
			return false
	for k: Variant in items:
		var key := StringName(k)
		have[key] = int(have[key]) - int(items[k])
		if int(have[key]) <= 0:
			have.erase(key)
	_set_pack(peer_id, have)
	return true


## Units of `item` in a player's backpack (every peer).
func pack_count(peer_id: int, item: StringName) -> int:
	return int((packs.get(peer_id, {}) as Dictionary).get(item, 0))


## Every peer: is this player down on the canyon floor?
func is_down(peer_id: int) -> bool:
	return down.has(peer_id)


## Anyone down at all? (every peer)
func anyone_down() -> bool:
	return not down.is_empty()


## Host: a loud sound at `pos` carrying `radius` metres (gunshots call this).
## Clients forward it to the host. `heat` is what it adds to the risk clock of
## anyone down there in earshot (a gunshot's ExpeditionRules.SHOT_HEAT; the
## grapple's dynamite much more).
func make_noise(pos: Vector3, radius: float, heat: float = ExpeditionRules.SHOT_HEAT) -> void:
	if radius <= 0.0:
		return
	if not multiplayer.is_server():
		_req_noise.rpc_id(1, pos, radius)
		return
	noise.emit(pos, radius)
	# Noise near someone on the floor brings the bugs sooner.
	for peer: int in down:
		var pl := player_node(peer)
		if pl == null:
			continue
		var h := float(_heat.get(peer, 0.0))
		_heat[peer] = h + ExpeditionRules.shot_heat(pl.global_position.distance_to(pos), radius, h, heat)


@rpc("any_peer", "reliable")
func _req_noise(pos: Vector3, radius: float) -> void:
	if multiplayer.is_server():
		make_noise(pos, minf(radius, ExpeditionRules.LOUD_GUN_NOISE))


## Host: seconds this player has been down this build phase (all trips together).
func floor_time(peer_id: int) -> float:
	return float(_floor_secs.get(peer_id, 0.0))


## Seconds on the risk clock: time down plus noise (host).
func risk(peer_id: int) -> float:
	return floor_time(peer_id) + float(_heat.get(peer_id, 0.0))


# ------------------------------------------------------------------ backpacks

func pack_of(peer_id: int) -> Dictionary:
	return packs.get(peer_id, {})


func local_pack() -> Dictionary:
	return pack_of(multiplayer.get_unique_id())


## The local player's walking speed from their pack's weight.
func local_speed_mult() -> float:
	return Backpack.speed_for(Backpack.weigh(local_pack()))


func _set_pack(peer_id: int, items: Dictionary) -> void:
	_sync_pack.rpc(peer_id, items)


@rpc("authority", "call_local", "reliable")
func _sync_pack(peer_id: int, items: Dictionary) -> void:
	if items.is_empty():
		packs.erase(peer_id)
	else:
		packs[peer_id] = items
	backpack_changed.emit(peer_id)


## Host: unpack a player's backpack onto their cliff's stockpile.
func _deposit(peer_id: int) -> void:
	var all_items: Dictionary = packs.get(peer_id, {})
	if all_items.is_empty():
		return
	var split := ExpeditionRules.split_story(all_items, story_items)
	var items: Dictionary = split[0]
	_set_pack(peer_id, {})
	for k: Variant in split[1]:
		story_item_up.emit(peer_id, StringName(k), int(split[1][k]))
	if items.is_empty():
		return
	var cid := Economy.payer_cliff(peer_id, _cliff_of(peer_id))
	Economy.earn(cid, items)
	Economy.notify(peer_id, "Unpacked onto your stockpile: %s." % ExpeditionRules.describe(items))


# ------------------------------------------------------------------ down / up

## Owner: this player went below the lip on an expedition (or came back up).
func report_trip(is_down_now: bool) -> void:
	if multiplayer.is_server():
		_set_down(multiplayer.get_unique_id(), is_down_now)
	else:
		_req_down.rpc_id(1, is_down_now)


@rpc("any_peer", "reliable")
func _req_down(is_down_now: bool) -> void:
	if multiplayer.is_server():
		_set_down(multiplayer.get_remote_sender_id(), is_down_now)


func _set_down(peer_id: int, is_down_now: bool) -> void:
	if is_down_now == down.has(peer_id):
		return
	if is_down_now and GameState.phase != GameState.Phase.BUILD:
		return
	_sync_down.rpc(peer_id, is_down_now)
	if is_down_now:
		GameState.on_player_down(peer_id)
	else:
		_deposit(peer_id)
		_recall_hunters(peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_down(peer_id: int, is_down_now: bool) -> void:
	if is_down_now:
		down[peer_id] = true
		went_down.emit(peer_id)
	else:
		down.erase(peer_id)
		came_up.emit(peer_id)


## Owner: downed on the canyon floor. The host drops your pack where you fell.
func report_downed(pos: Vector3) -> void:
	if multiplayer.is_server():
		_downed(multiplayer.get_unique_id(), pos)
	else:
		_req_downed.rpc_id(1, pos)


@rpc("any_peer", "reliable")
func _req_downed(pos: Vector3) -> void:
	if multiplayer.is_server():
		_downed(multiplayer.get_remote_sender_id(), pos)


func _downed(peer_id: int, pos: Vector3) -> void:
	var all_items: Dictionary = packs.get(peer_id, {})
	if all_items.is_empty():
		return
	if drop_point_hook.is_valid():
		pos = drop_point_hook.call(pos)
	var split := ExpeditionRules.split_story(all_items, story_items)
	_set_pack(peer_id, {})
	for k: Variant in split[1]:
		story_item_dropped.emit(peer_id, StringName(k), int(split[1][k]), pos)
	drop_sack(pos, split[0], _name_of(peer_id))


# ------------------------------------------------------------------ the airship

## Owner: hail the airship from the floor (G). The host takes the fare and
## sends the hook down.
func request_hail() -> void:
	if multiplayer.is_server():
		_hail(multiplayer.get_unique_id())
	else:
		_req_hail.rpc_id(1)


@rpc("any_peer", "reliable")
func _req_hail() -> void:
	if multiplayer.is_server():
		_hail(multiplayer.get_remote_sender_id())


func _hail(peer_id: int) -> void:
	if not is_down(peer_id):
		return
	var cid := Economy.payer_cliff(peer_id, _cliff_of(peer_id))
	if not Economy.spend(cid, {&"chitin": ExpeditionRules.AIRSHIP_FARE}):
		Economy.notify(peer_id, "The airship wants %d chitin to haul you up. Climb, or bring some home first." % ExpeditionRules.AIRSHIP_FARE)
		return
	_haul.rpc_id(peer_id)


## Owner: the airship's hook is on its way.
@rpc("authority", "call_local", "reliable")
func _haul() -> void:
	var pl := player_node(multiplayer.get_unique_id())
	if pl != null:
		pl.start_airship_haul()


# ------------------------------------------------------------------ sacks

## Host: a lootable sack at `pos` (anyone can grab it; it stays until the next wave ends).
func drop_sack(pos: Vector3, items: Dictionary, who: String = "") -> void:
	if not multiplayer.is_server() or items.is_empty():
		return
	_next_sack += 1
	_sack_wave[_next_sack] = GameState.wave
	_spawn_sack.rpc(_next_sack, pos, items, who)


@rpc("authority", "call_local", "reliable")
func _spawn_sack(id: int, pos: Vector3, items: Dictionary, who: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var s: StaticBody3D = LootSackScript.new()
	s.name = "LootSack%d" % id
	s.set("sack_id", id)
	s.set("items", items)
	s.set("owner_name", who)
	scene.add_child(s)
	var floor_y := Bug.cliffs.floor_height(pos.x, pos.z) if Bug.cliffs != null and pos.y < WorldLayout.CANYON_FALL_Y else pos.y
	s.global_position = Vector3(pos.x, floor_y, pos.z)
	_sacks[id] = s


## Owner: grab what fits from a sack.
func request_sack(id: int) -> void:
	if multiplayer.is_server():
		_take_sack(multiplayer.get_unique_id(), id)
	else:
		_req_sack.rpc_id(1, id)


@rpc("any_peer", "reliable")
func _req_sack(id: int) -> void:
	if multiplayer.is_server():
		_take_sack(multiplayer.get_remote_sender_id(), id)


func _take_sack(peer_id: int, id: int) -> void:
	var s: Node = _sacks.get(id)
	if s == null or not is_instance_valid(s):
		return
	var items: Dictionary = s.get("items")
	var n := add_to_backpack(peer_id, items)
	if n <= 0:
		Economy.notify(peer_id, "Your backpack's full.")
		return
	var rest := last_leftover
	Economy.notify(peer_id, "Into your backpack: %s." % ExpeditionRules.describe(ExpeditionRules.taken(items, rest)))
	if rest.is_empty():
		_remove_sack.rpc(id)
	else:
		_update_sack.rpc(id, rest)


@rpc("authority", "call_local", "reliable")
func _update_sack(id: int, items: Dictionary) -> void:
	var s: Node = _sacks.get(id)
	if s != null and is_instance_valid(s):
		s.set("items", items)


@rpc("authority", "call_local", "reliable")
func _remove_sack(id: int) -> void:
	var s: Node = _sacks.get(id)
	_sacks.erase(id)
	_sack_wave.erase(id)
	if s != null and is_instance_valid(s):
		s.queue_free()


func sack_count() -> int:
	return _sacks.size()


# ------------------------------------------------------------------ phases

func _on_phase(p: GameState.Phase) -> void:
	if p == GameState.Phase.LOBBY or p == GameState.Phase.GAME_OVER:
		_clear()
		return
	if not multiplayer.is_server():
		return
	if p == GameState.Phase.BUILD:
		_floor_secs.clear()
		_heat.clear()
		_rumble_t.clear()
		_hunt_t.clear()
		for id: int in _sack_wave.keys():
			if ExpeditionRules.sack_expired(int(_sack_wave[id]), GameState.wave):
				_remove_sack.rpc(id)
	else:
		# The wave's coming: nobody stays down (the airship hauls them up) and
		# the floor hunters go home.
		if not down.is_empty():
			_force_up.rpc()
		for peer: int in _hunters.keys():
			_recall_hunters(peer, true)


@rpc("authority", "call_local", "reliable")
func _force_up() -> void:
	var pl := player_node(multiplayer.get_unique_id())
	if pl != null and pl.on_trip():
		Economy.notice.emit("The wave's coming: the airship hauls you up out of the canyon.")
		pl.respawn()


func _clear() -> void:
	down.clear()
	risk_enabled = true
	drop_point_hook = Callable()
	packs.clear()
	_floor_secs.clear()
	_heat.clear()
	_hunters.clear()
	for id: int in _sacks.keys():
		var s: Node = _sacks[id]
		if s != null and is_instance_valid(s):
			s.queue_free()
	_sacks.clear()
	_sack_wave.clear()


func _on_player_left(peer_id: int) -> void:
	if multiplayer.is_server() and down.has(peer_id):
		_sync_down.rpc(peer_id, false)
		_recall_hunters(peer_id, true)
	packs.erase(peer_id)


# ------------------------------------------------------------------ risk (host)

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	if GameState.phase != GameState.Phase.BUILD:
		return
	for peer: int in down:
		if not risk_enabled:
			_floor_secs[peer] = floor_time(peer) + delta
			continue
		_floor_secs[peer] = floor_time(peer) + delta
		var r := risk(peer)
		var stage := ExpeditionRules.risk_stage(r)
		if stage >= 1:
			_rumble_t[peer] = float(_rumble_t.get(peer, ExpeditionRules.RUMBLE_EVERY)) + delta
			if float(_rumble_t[peer]) >= ExpeditionRules.RUMBLE_EVERY:
				_rumble_t[peer] = 0.0
				_rumble_near(peer, stage)
		if stage >= 2:
			_hunt_t[peer] = float(_hunt_t.get(peer, ExpeditionRules.HUNT_EVERY)) + delta
			if float(_hunt_t[peer]) >= ExpeditionRules.HUNT_EVERY:
				_hunt_t[peer] = 0.0
				_send_hunters(peer, r)


## The tunnel nearest a player: [mouth, way out], or [].
func _nearest_tunnel(pos: Vector3) -> Array:
	var cl := Bug.cliffs
	if cl == null or cl.tunnel_count() == 0:
		return []
	var best: Array = []
	var best_d := INF
	for i in cl.tunnel_count():
		if cl.sealed.has(i):
			continue # Story: blown shut
		var tn: Array = cl.tunnel(i)
		var d := (tn[0] as Vector3).distance_to(pos)
		if d < best_d:
			best_d = d
			best = tn
	return best


func _rumble_near(peer: int, stage: int) -> void:
	var pl := player_node(peer)
	if pl == null:
		return
	var tn := _nearest_tunnel(pl.global_position)
	if tn.is_empty():
		return
	_rumble.rpc_id(peer, tn[0], tn[1], 0.4 if stage < 2 else 0.8)


## The ground rumbles (the local player is down too long): a shake, the deep
## rumble, dust out of the nearest tunnel.
@rpc("authority", "call_local", "reliable")
func _rumble(mouth: Vector3, way_out: Vector3, strength: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	TunnelRumble.play(scene, mouth, way_out, 0.6 + strength, 2.5, false)
	Audio.play_ui(&"ground_rumble", -10.0 + strength * 8.0)
	var pl := player_node(multiplayer.get_unique_id())
	if pl != null:
		pl.add_shake(0.25 + strength * 0.45)
	if strength < 0.5:
		Economy.notice.emit("The ground rumbles under your boots. Something down here is waking up.")
	else:
		Economy.notice.emit("Bugs are stirring in the tunnels. Get back up!")


func _send_hunters(peer: int, r: float) -> void:
	var bm := BugManager.instance
	var pl := player_node(peer)
	if bm == null or pl == null or not is_instance_valid(bm):
		return
	var alive: Array = (_hunters.get(peer, []) as Array).filter(func(b: Variant) -> bool: return is_instance_valid(b) and (b as Bug).is_alive())
	var n := ExpeditionRules.hunters_to_send(r, alive.size())
	var tn := _nearest_tunnel(pl.global_position)
	if n <= 0 or tn.is_empty():
		_hunters[peer] = alive
		return
	var mouth: Vector3 = tn[0]
	var out: Vector3 = tn[1]
	var cid := _cliff_nearest(mouth)
	for i in n:
		var kind: StringName = ExpeditionRules.HUNTER_BUGS[i % ExpeditionRules.HUNTER_BUGS.size()]
		var pos := mouth - out * (1.2 + float(i) * 1.4) + Vector3(0, 0, randf_range(-1.0, 1.0))
		var b := bm.spawn_at(kind, cid, 0, mouth.z, 0.0, Bug.State.CROSSING, pos) as Bug
		if b == null:
			continue
		b.hunt_peer = peer
		b.hunt_home = mouth - out * 1.5
		b.floor_bug = true
		alive.append(b)
	_hunters[peer] = alive
	bm.rpc("_rumble", mouth, out, 1.0) # dust and a thud at the mouth (every peer)


## Host: the hunters after `peer` head back into their tunnel (`now`: just vanish).
func _recall_hunters(peer: int, now: bool = false) -> void:
	for b: Variant in _hunters.get(peer, []):
		if not is_instance_valid(b):
			continue
		if now:
			(b as Bug).queue_free()
		else:
			(b as Bug).hunt_peer = -1 # FloorHunt walks it home
	_hunters.erase(peer)


func _cliff_nearest(pos: Vector3) -> int:
	var best := 0
	var best_d := INF
	for cid in WorldLayout.cliff_count():
		if Bug.cliffs == null:
			break
		var d := Bug.cliffs.face_point(cid, 0.0, pos.z).distance_to(pos)
		if d < best_d:
			best_d = d
			best = cid
	return best


# ------------------------------------------------------------------ lookups

func player_node(peer_id: int) -> Player:
	var tree := get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("players"):
		if n is Player and n.get_multiplayer_authority() == peer_id:
			return n as Player
	return null


func _cliff_of(peer_id: int) -> int:
	if NetworkManager.players.has(peer_id):
		return NetworkManager.cliff_of(peer_id)
	var pl := player_node(peer_id)
	return pl.cliff_id if pl != null else 0


func _name_of(peer_id: int) -> String:
	if NetworkManager.players.has(peer_id):
		return str((NetworkManager.players[peer_id] as Dictionary)["name"])
	var pl := player_node(peer_id)
	return pl.display_name() if pl != null else "Someone"


## Names of the players down in the canyon right now, except `except_peer`.
func names_down(except_peer: int = 0) -> PackedStringArray:
	var out: PackedStringArray = []
	for peer: int in down:
		if peer != except_peer:
			out.append(_name_of(peer))
	return out
