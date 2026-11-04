class_name SiteManager
extends Node3D
## Canyon Expeditions: the raid sites on the canyon floor. Picks 3-5 sites from
## the map's bug tunnels with the run seed (SitePlan), builds their props on
## every peer, lays out the loot after every refill (each build phase: new loot,
## a little more danger as the waves climb), puts site bugs to sleep through
## BugManager, and runs the survey camp's traps, the nest's eggs and the
## railroad wreck's collapse. Host-authoritative: clients ask, the host decides
## and tells everyone. Loot goes into the backpack via ExpeditionApi only.
##
## Debug: --siteseed=N picks the run seed; --floor=N (scenes/debug/site_views.gd)
## stands you in site N.

static var instance: SiteManager

## Bear traps bite this hard; the dynamite tripwire blows this hard over BLAST_R.
const TRAP_DAMAGE := 30.0
const BLAST_DAMAGE := 70.0
const BLAST_R := 4.5
const FUSE := 1.1
## How far gunshot-free noises carry (metres).
const NOISE_SMASH := 18.0
const NOISE_TRAP := 22.0
const NOISE_BLAST := 40.0
const NOISE_COLLAPSE := 45.0
## Timber falls: damage to anyone within TIMBER_R of where one lands.
const TIMBER_DAMAGE := 35.0
const TIMBER_R := 2.2

var run_seed := -1
var sites: Array[SitePlan.Site] = []
## The wave whose refill is laid out now.
var gen_wave := 0
var _taken: Dictionary = {} # "site:slot" -> true
var _smashed: Dictionary = {} # "site:slot" -> true
var _cut_sites: Dictionary = {} # site -> true (its tunnel's next wave is cut)
var _collapsed: Dictionary = {} # site -> true
var _sprung: Dictionary = {} # "site:trap" -> true (sprung or disarmed)
var _loot_nodes: Dictionary = {} # "site:slot" -> SiteLoot
var _loot_lists: Dictionary = {} # site -> Array[SitePlan.Loot]
var _roots: Array[Node3D] = []
var _traps: Dictionary = {} # "site:trap" -> SiteTrap
var _wreck_clock: Dictionary = {} # site -> SitePlan.WreckClock (host)
var _ask_t := 0.0
var _walk_t := 0.0
var _floor_clock_t := 0.0


func _ready() -> void:
	instance = self
	SitePlan.reset_cuts()
	ExpeditionApi.debug_floor = GameState.flag_value("--floor") != ""
	if ExpeditionApi.debug_floor:
		var views: Node = load("res://scenes/debug/site_views.gd").new()
		views.name = "SiteViews"
		add_child(views)
	ExpeditionApi.connect_noise(_on_noise)
	if multiplayer.is_server():
		var s := int(GameState.flag_value("--siteseed")) if GameState.flag_value("--siteseed") != "" else SitePlan.roll_seed()
		_apply_seed(s)
		GameState.phase_changed.connect(_on_phase)
		if GameState.phase == GameState.Phase.BUILD:
			refill()


func _exit_tree() -> void:
	ExpeditionApi.disconnect_noise(_on_noise)
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	# Clients keep asking for the sites until the host's answer lands.
	if not multiplayer.is_server():
		if run_seed < 0:
			_ask_t -= delta
			if _ask_t <= 0.0:
				_ask_t = 1.5
				_want_state.rpc_id(1)
		return
	_floor_clock_t += delta
	if _floor_clock_t >= 0.25:
		for p: Node in get_tree().get_nodes_in_group("players"):
			var id := p.get_multiplayer_authority()
			ExpeditionApi.tick_floor_clock(id, ExpeditionApi.is_down(id), _floor_clock_t)
		_floor_clock_t = 0.0
	_walk_t -= delta
	if _walk_t <= 0.0:
		_walk_t = 0.15
		_host_walkovers()
		_host_traps()
	_host_wrecks(delta)


# ------------------------------------------------------------------ building

func _apply_seed(s: int) -> void:
	if run_seed == s and not sites.is_empty():
		return
	run_seed = s
	for r in _roots:
		r.queue_free()
	_roots.clear()
	_traps.clear()
	var tunnels: Array = []
	if Bug.cliffs != null:
		for i in Bug.cliffs.tunnel_count():
			tunnels.append(Bug.cliffs.tunnel(i))
	sites = SitePlan.generate(tunnels, s)
	for site in sites:
		if Bug.cliffs != null:
			site.pos.y = Bug.cliffs.floor_height(site.pos.x, site.pos.z)
		var root := Node3D.new()
		root.name = "Site%d_%s" % [site.index, site.kind_id()]
		add_child(root)
		root.global_transform = Transform3D(site.basis(), site.pos)
		_roots.append(root)
		SiteProps.build(root, site, self)
		if site.kind_id() == &"wreck": # the 1889 wreck: rusty iron, planks
			Materials.paint_live(root, Materials.RUSTIC, Materials.MAP_TRAIN)
		elif site.kind_id() == &"camp":
			Materials.paint_live(root, Materials.RUSTIC, Materials.MAP_RUINS)
	print("[sites] seed %d: %s" % [s, ", ".join(sites.map(func(x: SitePlan.Site) -> String: return "%s by tunnel %d" % [x.display_name(), x.tunnel]))])


## Called by SiteProps for each trap it lays.
func register_trap(site_index: int, k: int, trap: SiteTrap) -> void:
	_traps["%d:%d" % [site_index, k]] = trap


func site_root(index: int) -> Node3D:
	return _roots[index] if index >= 0 and index < _roots.size() else null


## Floor height under a site-local point (props sit on the real ground).
func ground_at(world: Vector3) -> float:
	return Bug.cliffs.floor_height(world.x, world.z) if Bug.cliffs != null else world.y


func _layout_loot() -> void:
	for k: String in _loot_nodes:
		var n: Node = _loot_nodes[k]
		if is_instance_valid(n):
			n.queue_free()
	_loot_nodes.clear()
	_loot_lists.clear()
	for site in sites:
		var list := SitePlan.loot_for(site.kind, site.seed, gen_wave)
		_loot_lists[site.index] = list
		for l in list:
			var key := "%d:%d" % [site.index, l.slot]
			var node := SiteLoot.new()
			node.setup(site.index, l, site.seed + l.slot)
			_roots[site.index].add_child(node)
			var w := site.at(l.local)
			node.global_position = Vector3(w.x, ground_at(w), w.z)
			node.rotation.y = float(l.slot) * 1.7
			_loot_nodes[key] = node
			node.visible = not _taken.has(key) and not _smashed.has(key) and not _collapsed.has(site.index)
			node.collision_layer = WorldLayout.LAYER_STRUCTURE if node.visible else 0
			if _smashed.has(key):
				_show_smashed(site.index, l.slot)


# ------------------------------------------------------------------ refill (host)

func _on_phase(p: GameState.Phase) -> void:
	if p == GameState.Phase.BUILD:
		refill()


## Host: new loot, traps re-armed, wrecks propped back up, fresh sleepers.
func refill() -> void:
	if not multiplayer.is_server():
		return
	gen_wave = maxi(GameState.wave, 1)
	_taken.clear()
	_smashed.clear()
	_cut_sites.clear()
	_collapsed.clear()
	_sprung.clear()
	for k: int in _wreck_clock:
		(_wreck_clock[k] as SitePlan.WreckClock).reset()
	_broadcast()
	_respawn_sleepers()


func _respawn_sleepers() -> void:
	var bm := BugManager.instance
	if bm == null:
		return
	for b in bm.site_bugs():
		b.queue_free()
	for site in sites:
		var cliff := 0
		if WorldLayout.map().is_canyon():
			cliff = int(WorldLayout.TUNNELS[site.tunnel % WorldLayout.TUNNELS.size()][0])
		for sl: Array in SitePlan.sleepers_for(site.kind, site.seed, gen_wave):
			var w := site.at(Vector2(float(sl[1]), float(sl[2])))
			w.y = ground_at(w)
			bm.spawn_site_bug(StringName(sl[0]), cliff, w, site.index, randf() * TAU)


func _state() -> Dictionary:
	return {"seed": run_seed, "wave": gen_wave, "taken": _taken.keys(), "smashed": _smashed.keys(),
			"collapsed": _collapsed.keys(), "sprung": _sprung.keys()}


func _broadcast() -> void:
	_apply_state(_state())
	if multiplayer.multiplayer_peer != null and not multiplayer.get_peers().is_empty():
		_sync.rpc(_state())


@rpc("any_peer", "reliable")
func _want_state() -> void:
	if multiplayer.is_server():
		_sync.rpc_id(multiplayer.get_remote_sender_id(), _state())


@rpc("authority", "call_remote", "reliable")
func _sync(state: Dictionary) -> void:
	_apply_state(state)


func _apply_state(state: Dictionary) -> void:
	_apply_seed(int(state["seed"]))
	gen_wave = int(state["wave"])
	_taken.clear()
	for k: Variant in state["taken"]:
		_taken[str(k)] = true
	_smashed.clear()
	for k: Variant in state["smashed"]:
		_smashed[str(k)] = true
	_collapsed.clear()
	for k: Variant in state["collapsed"]:
		_collapsed[int(k)] = true
	_sprung.clear()
	for k: Variant in state["sprung"]:
		_sprung[str(k)] = true
	_clear_smashed()
	_layout_loot()
	for k: String in _traps:
		(_traps[k] as SiteTrap).set_armed(not _sprung.has(k))
	for site in sites:
		SiteProps.set_collapsed(_roots[site.index], _collapsed.has(site.index))


# ------------------------------------------------------------------ taking loot

func request_take(site_index: int, slot: int) -> void:
	if multiplayer.is_server():
		_take(multiplayer.get_unique_id(), site_index, slot)
	else:
		_request_take.rpc_id(1, site_index, slot)


@rpc("any_peer", "reliable")
func _request_take(site_index: int, slot: int) -> void:
	if multiplayer.is_server():
		_take(multiplayer.get_remote_sender_id(), site_index, slot)


func _loot(site_index: int, slot: int) -> SitePlan.Loot:
	var list: Array = _loot_lists.get(site_index, [])
	return list[slot] if slot >= 0 and slot < list.size() else null


## Host: `peer` takes a pickup. What doesn't fit in the backpack stays put.
func _take(peer: int, site_index: int, slot: int) -> bool:
	var key := "%d:%d" % [site_index, slot]
	var l := _loot(site_index, slot)
	if l == null or _taken.has(key) or _smashed.has(key) or _collapsed.has(site_index):
		return false
	var want := 0
	for k: StringName in l.items:
		want += int(l.items[k])
	var fit := ExpeditionApi.add_to_backpack(peer, l.items)
	if fit <= 0:
		Economy.notify(peer, "Your backpack is full. Haul it up the rope first.")
		return false
	if fit < want:
		# Part of it fits: the rest stays on the ground for the next trip.
		var left := _shrink(l.items, want - fit)
		l.items = left
		if not multiplayer.get_peers().is_empty():
			_partial.rpc(site_index, slot, left)
		Economy.notify(peer, "Your backpack is full: you leave %s behind." % Economy.describe(left))
		return true
	_taken[key] = true
	_taken_fx.rpc(site_index, slot, peer)
	if l.items.has(SitePlan.JOURNAL_PAGE):
		Economy.notify(peer, "A page from Doc Whitlow's journal: \"%s\"" % SitePlan.journal_line(run_seed + site_index * 7 + gen_wave))
	elif l.look == &"blueprint":
		Economy.notify(peer, "%s: the parts for one, packed in the tube. Craft it at the Workshop." % l.label)
	elif l.look == &"amber":
		Economy.notify(peer, "Hive amber: %d chips, warm to the touch. It's yours alone; Lucky Moreau on the airship buys with nothing else." % int(l.items.get(AmberRules.ITEM, 0)))
	elif l.look == &"specimen":
		Economy.notify(peer, "A specimen jar for Doc. The airship market pays well for them.")
	elif l.look == &"trophy":
		Economy.notify(peer, "A boss trophy: an upgrade token tied to its horn, and %d chitin." % int(l.items.get(&"chitin", 0)))
	return true


## Takes `n` units off the end of `items` (what's left on the ground).
static func _shrink(items: Dictionary, n: int) -> Dictionary:
	var out := {}
	var left := n
	var keys := items.keys()
	keys.reverse()
	for k: Variant in keys:
		var have := int(items[k])
		var keep := mini(have, left)
		if keep > 0:
			out[k] = keep
		left -= keep
	return out


@rpc("authority", "call_remote", "reliable")
func _partial(site_index: int, slot: int, left: Dictionary) -> void:
	var l := _loot(site_index, slot)
	if l != null:
		l.items = left


@rpc("authority", "call_local", "reliable")
func _taken_fx(site_index: int, slot: int, _peer: int) -> void:
	var key := "%d:%d" % [site_index, slot]
	_taken[key] = true
	var n := _loot_nodes.get(key) as SiteLoot
	if n != null and is_instance_valid(n):
		Audio.play_at(&"loot_crack" if n.loot.look in [&"chitin", &"egg"] else &"salvage", n.global_position)
		n.visible = false
		n.collision_layer = 0


## Host: walk-over pickups (chitin, loose scrap) go to whoever steps on them.
func _host_walkovers() -> void:
	for k: String in _loot_nodes:
		var n := _loot_nodes[k] as SiteLoot
		if n == null or not n.visible or not n.loot.walk:
			continue
		for p: Node in get_tree().get_nodes_in_group("players"):
			var pl := p as Node3D
			if pl.global_position.distance_to(n.global_position) < 1.3:
				if _take(pl.get_multiplayer_authority(), n.site_index, n.loot.slot):
					break


# ------------------------------------------------------------------ eggs

## Clutches still to smash at a nest before its tunnel's next wave is cut.
func smash_needed(site_index: int) -> int:
	if _cut_sites.has(site_index):
		return 0
	var list: Array = _loot_lists.get(site_index, [])
	var clutches := 0
	var smashed := 0
	for l: SitePlan.Loot in list:
		if l.look == &"egg":
			clutches += 1
			if _smashed.has("%d:%d" % [site_index, l.slot]):
				smashed += 1
	return maxi(SitePlan.smash_quota(clutches) - smashed, 0)


func request_smash(site_index: int, slot: int) -> void:
	if multiplayer.is_server():
		_smash(multiplayer.get_unique_id(), site_index, slot)
	else:
		_request_smash.rpc_id(1, site_index, slot)


@rpc("any_peer", "reliable")
func _request_smash(site_index: int, slot: int) -> void:
	if multiplayer.is_server():
		_smash(multiplayer.get_remote_sender_id(), site_index, slot)


## Host: a clutch of eggs is smashed. Smash enough of a nest's clutches and its
## tunnel sends 20% fewer bugs next wave. Smashing is loud.
func _smash(peer: int, site_index: int, slot: int) -> bool:
	var key := "%d:%d" % [site_index, slot]
	var l := _loot(site_index, slot)
	if l == null or l.look != &"egg" or _taken.has(key) or _smashed.has(key):
		return false
	_smashed[key] = true
	_smash_fx.rpc(site_index, slot)
	var at := site_root(site_index).global_position
	ExpeditionApi.make_noise(at, NOISE_SMASH)
	if smash_needed(site_index) == 0 and not _cut_sites.has(site_index):
		_cut_sites[site_index] = true
		var next := GameState.wave + (1 if GameState.phase == GameState.Phase.WAVE else 0)
		SitePlan.smash(sites[site_index].tunnel, next)
		Economy.notify(peer, "The brood is smashed: that tunnel sends a fifth fewer bugs next wave.")
	return true


@rpc("authority", "call_local", "reliable")
func _smash_fx(site_index: int, slot: int) -> void:
	_smashed["%d:%d" % [site_index, slot]] = true
	var n := _loot_nodes.get("%d:%d" % [site_index, slot]) as SiteLoot
	if n != null and is_instance_valid(n):
		n.visible = false
		n.collision_layer = 0
		Audio.play_crunch(n.global_position, 0.0, 0.85)
		if BugManager.instance != null and BugManager.instance.vfx != null:
			BugManager.instance.vfx.pop(n.global_position + Vector3(0, 0.4, 0), SiteBuilder.EGG_GLOW, 1.2)
	_show_smashed(site_index, slot)


var _smashed_nodes: Array[Node] = []


func _show_smashed(site_index: int, slot: int) -> void:
	var n := _loot_nodes.get("%d:%d" % [site_index, slot]) as SiteLoot
	if n == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = SiteBuilder.smashed_eggs(slot)
	mi.material_override = Materials.toon(0.01)
	_roots[site_index].add_child(mi)
	mi.global_position = n.global_position
	_smashed_nodes.append(mi)


func _clear_smashed() -> void:
	for n in _smashed_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_smashed_nodes.clear()


# ------------------------------------------------------------------ noise

## Every sleeper within `radius` of a noise wakes up (host).
func _on_noise(pos: Vector3, radius: float) -> void:
	if not multiplayer.is_server() or BugManager.instance == null:
		return
	for b in BugManager.instance.site_bugs():
		if b.hunter != null and b.global_position.distance_to(pos) <= radius:
			b.hunter.wake()


# ------------------------------------------------------------------ traps (host)

func request_disarm(site_index: int, k: int) -> void:
	if multiplayer.is_server():
		_disarm(site_index, k)
	else:
		_request_disarm.rpc_id(1, site_index, k)


@rpc("any_peer", "reliable")
func _request_disarm(site_index: int, k: int) -> void:
	if multiplayer.is_server():
		_disarm(site_index, k)


func _disarm(site_index: int, k: int) -> void:
	var key := "%d:%d" % [site_index, k]
	if _sprung.has(key):
		return
	_sprung[key] = true
	_trap_fx.rpc(site_index, k, false)


func _host_traps() -> void:
	for key: String in _traps:
		if _sprung.has(key):
			continue
		var trap := _traps[key] as SiteTrap
		for p: Node in get_tree().get_nodes_in_group("players"):
			var pl := p as Player
			if pl == null or not trap.triggered_by(pl.global_position):
				continue
			_sprung[key] = true
			_trap_fx.rpc(trap.site_index, trap.trap_index, true)
			if trap.kind == &"bear":
				pl.net.server_damage(TRAP_DAMAGE)
				Economy.notify(pl.get_multiplayer_authority(), "A bear trap! Watch your step round the old camp.")
				ExpeditionApi.make_noise(trap.global_position, NOISE_TRAP)
			else:
				Economy.notify(pl.get_multiplayer_authority(), "You hear a fuse fizz at your ankle. RUN!")
				get_tree().create_timer(FUSE, false).timeout.connect(_blast.bind(trap.global_position))
			break


func _blast(at: Vector3) -> void:
	if BugManager.instance != null:
		BugManager.instance._explode.rpc(at + Vector3(0, 0.4, 0), BLAST_R)
		for b in BugManager.instance.site_bugs():
			var d := b.global_position.distance_to(at)
			if d < BLAST_R:
				b.receive_hit(BLAST_DAMAGE * lerpf(1.0, 0.4, d / BLAST_R), at, (b.global_position - at).normalized(), true, 1.0, "dynamite", -1)
	for p: Node in get_tree().get_nodes_in_group("players"):
		var pl := p as Player
		var d := pl.global_position.distance_to(at)
		if d < BLAST_R:
			pl.net.server_damage(BLAST_DAMAGE * lerpf(1.0, 0.35, d / BLAST_R))
	ExpeditionApi.make_noise(at, NOISE_BLAST)


@rpc("authority", "call_local", "reliable")
func _trap_fx(site_index: int, k: int, fired: bool) -> void:
	var key := "%d:%d" % [site_index, k]
	_sprung[key] = true
	var trap := _traps.get(key) as SiteTrap
	if trap == null:
		return
	trap.set_armed(false)
	if fired and trap.kind == &"bear":
		Audio.play_at(&"hammer_hit", trap.global_position, 4.0, 0.7)
	elif not fired:
		Audio.play_at(&"reload", trap.global_position)


# ------------------------------------------------------------------ the wreck (host)

func _host_wrecks(delta: float) -> void:
	for site in sites:
		if site.kind != SitePlan.Kind.WRECK:
			continue
		if not _wreck_clock.has(site.index):
			_wreck_clock[site.index] = SitePlan.WreckClock.new()
		var clock := _wreck_clock[site.index] as SitePlan.WreckClock
		var inside := false
		for p: Node in get_tree().get_nodes_in_group("players"):
			var pl := p as Node3D
			if Vector2(pl.global_position.x - site.pos.x, pl.global_position.z - site.pos.z).length() < SitePlan.RADIUS + 1.0 \
					and ExpeditionApi.is_down(pl.get_multiplayer_authority()):
				inside = true
				break
		match clock.tick(delta, inside):
			&"creak":
				_creak.rpc(site.index)
			&"collapse":
				_collapsed[site.index] = true
				var drops: Array = []
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([site.seed, gen_wave, "collapse"])
				for k in 7:
					drops.append(site.at(Vector2(rng.randf_range(-SitePlan.RADIUS, SitePlan.RADIUS), rng.randf_range(-SitePlan.RADIUS, SitePlan.RADIUS))))
				# Timbers land right on anyone still inside, too.
				for p: Node in get_tree().get_nodes_in_group("players"):
					var pl := p as Node3D
					if Vector2(pl.global_position.x - site.pos.x, pl.global_position.z - site.pos.z).length() < SitePlan.RADIUS + 1.0:
						drops.append(pl.global_position)
				_collapse.rpc(site.index, drops)
				get_tree().create_timer(SiteProps.TIMBER_FALL, false).timeout.connect(_timber_damage.bind(drops))
				ExpeditionApi.make_noise(site.pos, NOISE_COLLAPSE)


func _timber_damage(drops: Array) -> void:
	for p: Node in get_tree().get_nodes_in_group("players"):
		var pl := p as Player
		for at: Vector3 in drops:
			if Vector2(pl.global_position.x - at.x, pl.global_position.z - at.z).length() < TIMBER_R:
				pl.net.server_damage(TIMBER_DAMAGE)
				break


@rpc("authority", "call_local", "reliable")
func _creak(site_index: int) -> void:
	var root := site_root(site_index)
	if root == null:
		return
	Audio.play_at(&"airship_creak", root.global_position, 8.0, 0.6)
	Audio.play_at(&"ground_rumble", root.global_position, 0.0, 1.3)
	if BugManager.instance != null and BugManager.instance.vfx != null:
		BugManager.instance.vfx.shake_requested.emit(root.global_position, 0.25)
		BugManager.instance.vfx.dust_burst(root.global_position + Vector3(0, 3.0, 0), Vector3.DOWN, 1.5)
	Economy.notice.emit("The railroad wreck groans and shifts. Get out before it comes down!")


@rpc("authority", "call_local", "reliable")
func _collapse(site_index: int, drops: Array) -> void:
	_collapsed[site_index] = true
	var root := site_root(site_index)
	if root == null:
		return
	SiteProps.collapse(root, drops, BugManager.instance.vfx if BugManager.instance != null else null)
	for k: String in _loot_nodes:
		var n := _loot_nodes[k] as SiteLoot
		if n.site_index == site_index:
			n.visible = false
			n.collision_layer = 0


# ------------------------------------------------------------------ queries

## For the overview map and the field guide: [[world pos, kind, name], ...].
func markers() -> Array:
	var out: Array = []
	for s in sites:
		out.append([s.pos, s.kind, s.display_name()])
	return out


func loot_left(site_index: int) -> int:
	var n := 0
	for l: SitePlan.Loot in _loot_lists.get(site_index, []):
		var key := "%d:%d" % [site_index, l.slot]
		if not _taken.has(key) and not _smashed.has(key) and not _collapsed.has(site_index):
			n += 1
	return n


func is_collapsed(site_index: int) -> bool:
	return _collapsed.has(site_index)


## Debug/tests: the wreck clock of a site (host).
func wreck_clock(site_index: int) -> SitePlan.WreckClock:
	if not _wreck_clock.has(site_index):
		_wreck_clock[site_index] = SitePlan.WreckClock.new()
	return _wreck_clock[site_index]
