extends Node
## The Rancher's Ledger at runtime (data and rules: PerkTable, PerkProfile,
## BrandRules). Owns this player's profile (user://profile.json), the loadouts
## of every human in the game, start-of-run perks, and the Brands a run pays.
##
## Multiplayer: each client sends its loadout to the host from the lobby
## (`_submit`), the host checks it (PerkProfile.sanitize) and mirrors everyone's
## loadouts back (`_sync`). Loadouts lock once the run starts. Host-owned
## effects (costs, turret stats, crop growth, start-of-run gifts, gun damage)
## ask `rank/more/less(peer_id, perk)`; the local player's own effects (reload,
## recoil, thirst, damage taken...) ask `local_*`. CPU partners have no perks.

signal profile_changed
signal loadouts_changed
## The run's Brands were worked out (and banked unless it was a test run).
signal run_banked(report: Dictionary)

const PATH := "user://profile.json"

var profile: PerkProfile
## peer id -> {perk id: rank}. Host-authoritative, mirrored on clients.
var loadouts: Dictionary = {}
## The report of the last run's Brands (BrandsReport shows it).
var last_report: Dictionary = {}

var _path := PATH
var _no_save := false
var _run_active := false
var _run_loadout: Dictionary = {}
## Host: peers that have used their Barn Raising free turret this run.
var _free_used: Dictionary = {}
## Host: turret damage source -> Scrap Scavenger multiplier (filled as turrets spawn).
var _turret_scrap: Dictionary = {}
## Client: our own Barn Raising was used (the host tells us).
var _local_free_used := false
var _saves := 0
var _banked: Dictionary = {}
var _bug_hooked: Object = null
## [Foundation hook] Continue last run: set by RunSaver before the resumed run
## starts, so the start-of-run gifts (already handed out) aren't given again.
var resumed := false
var _gun_hooked: Gun = null


func _ready() -> void:
	var name_flag := GameState.flag_value("--profile")
	if name_flag != "":
		_path = "user://profile_%s.json" % name_flag.validate_filename()
	var fresh := not FileAccess.file_exists(_path)
	profile = PerkProfile.load_from(_path)
	if fresh:
		_grandfather_look()
	if GameState.has_flag("--perkdemo"):
		_demo_profile()
	NetworkManager.connected_to_host.connect(_submit_local)
	NetworkManager.connected_to_host.connect(_submit_secrets) # Theme: Secrets the gunsmith checks
	NetworkManager.players_changed.connect(_on_players_changed)
	GameState.phase_changed.connect(_on_phase)
	GameState.game_over.connect(_on_game_over)
	if GameState.has_flag("--perkdemo") or GameState.flag_value("--perkover") != "" or GameState.has_flag("--perktest") \
			or GameState.flag_value("--perkshot") != "":
		var view := (load("res://scenes/debug/perks_view.gd") as GDScript).new() as Node
		view.name = "PerksView"
		add_child(view)


func _process(_delta: float) -> void:
	if _run_active and GameState.phase == GameState.Phase.LOBBY:
		_run_active = false # back at the menu (GameState.reset)
		resumed = false
		_run_loadout = {}
		_bug_hooked = null
		_gun_hooked = null
	if _run_active and (_gun_hooked == null or not is_instance_valid(_gun_hooked)):
		_hook_local_gun()


# ------------------------------------------------------------------ profile

func save() -> void:
	if _no_save:
		return
	profile.validate()
	profile.save(_path)


## Ledger screen: buy the next rank of a perk.
func unlock(id: StringName) -> bool:
	if not profile.unlock(id):
		return false
	_changed()
	return true


## Ledger screen: take a perk into the next run, or leave it at home.
func toggle(id: StringName) -> bool:
	if not loadout_editable() or not profile.toggle(id):
		return false
	_changed()
	return true


func clear_loadout() -> void:
	if not loadout_editable():
		return
	profile.loadout.clear()
	_changed()


func buy_cosmetic(slot: String, option: String) -> bool:
	if not profile.buy_cosmetic(slot, option):
		return false
	_changed()
	return true


## Secrets screen: try a code. Returns {"ok": bool, "added": [{"kind", "id"} new to this profile]}.
func redeem_secret(code: String) -> Dictionary:
	var unlocks := SecretCodes.rewards(code)
	if unlocks.is_empty():
		return {"ok": false, "added": []}
	var added := profile.unlock_secret(unlocks)
	if not added.is_empty():
		_changed()
		_submit_secrets()
	return {"ok": true, "added": added}


## Host: does this rider have a secret unlocked? (Your own from the profile,
## others from what their game sent when they connected.)
func has_secret(peer_id: int, kind: StringName, id: StringName) -> bool:
	if peer_id == multiplayer.get_unique_id() or peer_id <= 0 and not NetworkManager.is_online():
		return profile.has_secret(String(kind), String(id))
	return (peer_secrets.get(peer_id, []) as Array).has(SecretCodes.key(String(kind), String(id)))


## Host: peer id -> that rider's secret keys ("weapon:dino_rifle").
var peer_secrets: Dictionary = {}


func _submit_secrets() -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_got_secrets.rpc_id(1, PackedStringArray(profile.secrets))


@rpc("any_peer", "reliable")
func _got_secrets(keys: PackedStringArray) -> void:
	if not multiplayer.is_server():
		return
	var clean: Array = []
	for k: String in keys:
		if k.contains(":") and clean.size() < 64:
			clean.append(k)
	peer_secrets[multiplayer.get_remote_sender_id()] = clean


func owns_look(slot: String, option: String) -> bool:
	return profile.owns_cosmetic(slot, option)


## Loadouts can change in the menu and lobby, not once a run is under way.
func loadout_editable() -> bool:
	return not _run_active


func _changed() -> void:
	save()
	profile_changed.emit()
	if NetworkManager.is_online() and GameState.phase == GameState.Phase.LOBBY:
		if multiplayer.is_server():
			loadouts[1] = profile.loadout_ranks()
			_broadcast()
		else:
			_submit_local()


## A brand-new profile keeps whatever you're already wearing, so nobody loses a look.
func _grandfather_look() -> void:
	for slot: String in PerkTable.COSMETICS:
		var opt := str(Settings.look.get(slot, ""))
		if PerkTable.cosmetic_price(slot, opt) > 0:
			profile.cosmetics.append(PerkTable.cosmetic_key(slot, opt))
	save()


# ------------------------------------------------------------------ queries

## This peer's loadout {id: rank}: your own (locked in for the run) or a synced one.
func loadout_of(peer_id: int) -> Dictionary:
	if peer_id <= 0:
		return {}
	if peer_id == multiplayer.get_unique_id():
		return _run_loadout if _run_active else profile.loadout_ranks()
	return loadouts.get(peer_id, {})


func rank(peer_id: int, id: StringName) -> int:
	return int(loadout_of(peer_id).get(id, 0))


func amount(peer_id: int, id: StringName) -> float:
	return PerkTable.amount_in(loadout_of(peer_id), id)


func more(peer_id: int, id: StringName) -> float:
	return PerkTable.more(loadout_of(peer_id), id)


func less(peer_id: int, id: StringName) -> float:
	return PerkTable.less(loadout_of(peer_id), id)


func local_rank(id: StringName) -> int:
	return rank(multiplayer.get_unique_id(), id)


func local_more(id: StringName) -> float:
	return more(multiplayer.get_unique_id(), id)


func local_less(id: StringName) -> float:
	return less(multiplayer.get_unique_id(), id)


## The human who owns a cliff (0 for a CPU partner's cliff). Solo: you own both.
func peer_for_cliff(cid: int) -> int:
	if not NetworkManager.is_online() or GameState.is_solo():
		return multiplayer.get_unique_id()
	for id: int in NetworkManager.players:
		if NetworkManager.cliff_of(id) == cid:
			return id
	return 0


func cliff_more(cid: int, id: StringName) -> float:
	return more(peer_for_cliff(cid), id)


func _cliff_of_peer(peer_id: int) -> int:
	if NetworkManager.is_online():
		return NetworkManager.cliff_of(peer_id)
	if GameState.flag_value("--cliff") != "": # Maps:
		return int(GameState.flag_value("--cliff"))
	return WorldLayout.EAST if GameState.has_flag("--east") else WorldLayout.WEST


## Humans in this run (peer ids).
func _humans() -> Array[int]:
	var out: Array[int] = []
	if NetworkManager.is_online():
		for id: int in NetworkManager.players:
			out.append(id)
	else:
		out.append(multiplayer.get_unique_id())
	return out


# ------------------------------------------------------------------ costs

## Scrap a build costs this peer: Barn Raising makes the first turret free,
## Bulk Lumber takes a cut off everything.
func build_cost(peer_id: int, id: StringName) -> int:
	var base := Defs.cost_of(id)
	if Defs.is_turret(id) and rank(peer_id, &"barn_raising") > 0 and not _free_used_by(peer_id):
		return 0
	return int(PerkTable.scale_cost({&"scrap": base}, less(peer_id, &"bulk_lumber"))[&"scrap"])


func _free_used_by(peer_id: int) -> bool:
	if multiplayer.is_server():
		return _free_used.has(peer_id)
	return _local_free_used if peer_id == multiplayer.get_unique_id() else true


## Host: a peer paid for a build (uses up Barn Raising on a turret).
func note_built(peer_id: int, id: StringName) -> void:
	if not multiplayer.is_server() or not Defs.is_turret(id) or rank(peer_id, &"barn_raising") <= 0 or _free_used.has(peer_id):
		return
	_free_used[peer_id] = true
	Economy.notify(peer_id, "Barn Raising: the neighbours put up your %s for free." % Defs.name_of(id))
	if peer_id != multiplayer.get_unique_id():
		_set_free_used.rpc_id(peer_id)


@rpc("authority", "reliable")
func _set_free_used() -> void:
	_local_free_used = true


## A whole-number price after a "less" perk (never below 1 unless it was free).
func discount(peer_id: int, perk: StringName, cost: int) -> int:
	return int(PerkTable.scale_cost({&"x": cost}, less(peer_id, perk))[&"x"])


## A {res: n} cost after a "less" perk.
func discount_cost(peer_id: int, perk: StringName, cost: Dictionary) -> Dictionary:
	return PerkTable.scale_cost(cost, less(peer_id, perk))


## Shop rows (MenuScreen items) with the local player's discount applied to
## their "price" text ("12 chitin", "25 scrap + 10 chitin"), price_ok rechecked.
func discount_menu(items: Array, perk: StringName, payer_cliff: int) -> Array:
	var me := multiplayer.get_unique_id()
	if rank(me, perk) <= 0:
		return items
	for item: Dictionary in items:
		var cost := _parse_price(str(item.get("price", "")))
		if cost.is_empty():
			continue
		var cut := discount_cost(me, perk, cost)
		item["price"] = Homestead.cost_text(cut)
		item["price_ok"] = Economy.can_afford(payer_cliff, cut)
		if str(item.get("note", "")) == "":
			item["note"] = "%s -%s" % [PerkTable.get_perk(perk)["name"], PerkTable.value_text(perk, rank(me, perk))]
	return items


static func _parse_price(text: String) -> Dictionary:
	var out: Dictionary = {}
	for part in text.split("+"):
		var bits := part.strip_edges().split(" ", false)
		if bits.size() != 2 or not bits[0].is_valid_int():
			return {}
		out[StringName(bits[1])] = int(bits[0])
	return out


## Host: a harvest with Bumper Crop's chance of one more of the main crop.
func bumper_harvest(peer_id: int, harvest: Dictionary) -> Dictionary:
	if harvest.is_empty() or randf() >= amount(peer_id, &"bumper_crop"):
		return harvest
	var out := harvest.duplicate()
	var main: Variant = out.keys()[0]
	out[main] = int(out[main]) + 1
	Economy.notify(peer_id, "Bumper crop! One extra.")
	return out


## Point Blank: hits closer than this (metres) count.
const POINT_BLANK_RANGE := 8.0


## Host: damage multiplier for one of this peer's gun hits (Heavy Slugs,
## Marksman on the weak spot, Lucky Shot, Point Blank within `dist` metres).
func gun_hit_mult(peer_id: int, hit: Dictionary, dist: float = -1.0) -> float:
	var m := more(peer_id, &"heavy_slugs")
	if rank(peer_id, &"marksman") > 0 and not hit.is_empty():
		var hb := hit.get("collider") as Hitbox
		if hb != null and hb.multiplier_at(hit["position"]) > 1.0:
			m *= more(peer_id, &"marksman")
	if dist >= 0.0 and dist <= POINT_BLANK_RANGE:
		m *= more(peer_id, &"point_blank")
	if randf() < amount(peer_id, &"lucky_shot"):
		m *= 2.0
	if not hit.is_empty(): # Brand: Snake Eyes hit bosses harder
		var hb2 := hit.get("collider") as Hitbox
		if hb2 != null:
			m *= Brand.boss_mult(peer_id, hb2.target)
	return m


## Every peer, as a turret spawns: the builder's Engineer perks.
func apply_turret(t: Turret, peer_id: int) -> void:
	var lo := loadout_of(peer_id)
	if lo.is_empty():
		return
	t.perk_range = PerkTable.more(lo, &"long_sights")
	t.perk_rate = PerkTable.less(lo, &"well_oiled")
	t.perk_hp = PerkTable.more(lo, &"reinforced_frames")
	t.perk_mend = PerkTable.amount_in(lo, &"overtime")
	var scrap := PerkTable.more(lo, &"scrap_scavenger")
	if scrap != 1.0:
		_turret_scrap["%s's %s" % [t.owner_name, t.def.display_name]] = scrap
	if t.perk_hp != 1.0:
		t.health.setup(t.def.hp_at(t.tier) * t.perk_hp)


## Scrap Scavenger: scrap multiplier for a kill by this damage source
## ("Logan's Chili Mortar"), 1.0 for anything else.
func kill_scrap_mult(source: String) -> float:
	return float(_turret_scrap.get(source, 1.0))


## Overtime (host): when a wave ends, each turret patches its builder's share of its HP.
func _overtime_mend() -> void:
	if not multiplayer.is_server():
		return
	for n: Node in get_tree().get_nodes_in_group("turrets"):
		var t := n as Turret
		if t != null and t.perk_mend > 0.0 and t.health != null and t.health.hp > 0.0:
			t.repair(t.health.max_hp * t.perk_mend)


# ------------------------------------------------------------------ wardrobe

## Wardrobe: grey out options still to be bought with Brands (labels say so).
func lock_look_row(row: Container, slot: String) -> void:
	var opts: Array = DummyLook.SLOTS[slot][1]
	for i in mini(row.get_child_count(), opts.size()):
		var b := row.get_child(i) as Button
		var opt := str(opts[i][0])
		if b != null and SecretCodes.is_secret_look(slot, opt) and not owns_look(slot, opt):
			b.visible = false # Theme: secret looks stay hidden until their code is entered
		elif b != null and not owns_look(slot, opt):
			b.disabled = true
			b.tooltip_text = "Buy it with Notches in the Rancher's Ledger (main menu)."
			_price_chip(b, PerkTable.cosmetic_price(slot, opt))


## A locked look's price as a small chip inside its button (padlock and "25 Notches").
static func _price_chip(b: Button, price: int) -> void:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "ChipPanel"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(h)
	h.add_child(UiStyle.mark("lock", UiStyle.c("gold"), 11))
	var l := MenuScreen.ink_label(UiStyle.cost(price, "Notches"), 12, UiStyle.c("gold"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_child(chip)
	var w := b.get_combined_minimum_size().x
	var cw := chip.get_combined_minimum_size().x
	b.custom_minimum_size.x = w + cw + 10
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.anchor_top = 0.5
	chip.anchor_bottom = 0.5
	chip.offset_left = -cw - 5
	chip.offset_right = -5
	var ch := chip.get_combined_minimum_size().y
	chip.offset_top = -ch * 0.5
	chip.offset_bottom = ch * 0.5


# ------------------------------------------------------------------ networking

func _submit_local() -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_submit.rpc_id(1, _to_wire(profile.loadout_ranks()))


@rpc("any_peer", "reliable")
func _submit(raw: Dictionary) -> void:
	if not multiplayer.is_server() or _run_active:
		return
	loadouts[multiplayer.get_remote_sender_id()] = PerkProfile.sanitize(raw)
	if GameState.has_flag("--netlog"):
		print("[perks] host got peer %d loadout %s" % [multiplayer.get_remote_sender_id(), str(loadouts[multiplayer.get_remote_sender_id()])])
	_broadcast()


func _broadcast() -> void:
	if multiplayer.is_server():
		loadouts[1] = _run_loadout if _run_active else profile.loadout_ranks()
		var wire: Dictionary = {}
		for id: int in loadouts:
			wire[id] = _to_wire(loadouts[id])
		if NetworkManager.is_online():
			_sync.rpc(wire)
	loadouts_changed.emit()


@rpc("authority", "reliable")
func _sync(wire: Dictionary) -> void:
	loadouts.clear()
	for id: Variant in wire:
		loadouts[int(id)] = PerkProfile.sanitize(wire[id])
	loadouts_changed.emit()
	if GameState.has_flag("--netlog"):
		print("[perks] peer %d mirrored loadouts for %s" % [multiplayer.get_unique_id(), str(loadouts.keys())])


static func _to_wire(lo: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in lo:
		out[String(id)] = int(lo[id])
	return out


func _on_players_changed() -> void:
	if not multiplayer.is_server():
		return
	for id: int in loadouts.keys():
		if id != 1 and not NetworkManager.players.has(id):
			loadouts.erase(id)
	if NetworkManager.is_online():
		_broadcast()


## Lobby roster: "  ·  7 perks".
func roster_note(peer_id: int) -> String:
	var n := loadout_of(peer_id).size()
	return "  ·  %d Perk%s" % [n, "" if n == 1 else "s"] if n > 0 else ""


# ------------------------------------------------------------------ the run

func _on_phase(p: GameState.Phase) -> void:
	if p == GameState.Phase.BUILD and _run_active:
		_overtime_mend() # a wave just ended
	if p != GameState.Phase.BUILD or _run_active:
		return
	_run_active = true
	_run_loadout = profile.loadout_ranks()
	_free_used.clear()
	_local_free_used = false
	_turret_scrap.clear()
	_saves = 0
	_banked = {"waves": 0, "saves": 0, "won": false, "rode": false}
	last_report = {}
	_hook_bugs()
	if multiplayer.is_server():
		_broadcast()
		# Give clients a moment to spawn their players before handing out guns.
		get_tree().create_timer(1.0).timeout.connect(_start_of_run)


func _hook_bugs() -> void:
	var bm: Object = WaveDirector.bug_manager
	if bm != null and is_instance_valid(bm) and bm != _bug_hooked and bm.has_signal("bug_killed"):
		bm.connect("bug_killed", _on_bug_killed)
		_bug_hooked = bm


func _on_bug_killed(_bug: String, bug_cliff: int, _source: String, source_cliff: int, _loot: Dictionary) -> void:
	if source_cliff < 0 or bug_cliff < 0 or source_cliff == bug_cliff or GameState.is_solo():
		return
	var me := _local_player()
	if me != null and source_cliff == me.cliff_id:
		_saves += 1


## Dead-Eye Refund: hook the local gun's weak-spot hits.
func _hook_local_gun() -> void:
	var p := _local_player()
	if p == null or p.gun == null:
		return
	_gun_hooked = p.gun
	p.gun.hit_confirmed.connect(func(weak: bool) -> void:
		if not weak or not is_instance_valid(p) or p.gun.def == null:
			return
		if randf() < local_rank(&"dead_eye") * float(PerkTable.get_perk(&"dead_eye")["per_rank"]) \
				and p.gun.ammo < p.gun.mag_size():
			p.gun.ammo += 1
			p.gun.ammo_changed.emit(p.gun.ammo, p.gun.mag_size()))


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority() and n is Player:
			return n as Player
	return null


## Host: start-of-run perks for every human.
func _start_of_run() -> void:
	if not multiplayer.is_server() or not _run_active:
		return
	if resumed: # [Foundation hook] a continued run had its gifts the first time
		resumed = false
		return
	for peer in _humans():
		var lo := loadout_of(peer)
		if lo.is_empty():
			continue
		var cid := _cliff_of_peer(peer)
		var got: PackedStringArray = []
		var gifts: Dictionary = {}
		if lo.has(&"scrap_stash"):
			gifts[&"scrap"] = roundi(PerkTable.amount_in(lo, &"scrap_stash"))
		if lo.has(&"full_pantry"):
			gifts[&"water"] = 4
			gifts[&"herbs"] = 1
		if lo.has(&"homestead_plot"):
			gifts[&"seed_corn"] = 2
			if _free_build(peer, &"farm_plot", cid, _plot_cells()):
				got.append("a farm plot")
		if not gifts.is_empty():
			Economy.earn(cid, gifts)
			var names := {&"scrap": "scrap for the team pot", &"water": "water", &"herbs": "herbs", &"seed_corn": "corn seeds"}
			for r: StringName in gifts:
				got.append("%d %s" % [int(gifts[r]), names.get(r, String(r))])
		if lo.has(&"old_scaffolds"):
			var n := 0
			for i in 2:
				if _free_build(peer, &"scaffold", cid, _scaffold_cells()):
					n += 1
			if n > 0:
				got.append("%d scaffold%s" % [n, "" if n == 1 else "s"])
		if lo.has(&"stout_timbers"):
			for c in WorldLayout.cliff_count():
				if peer_for_cliff(c) == peer:
					GameState.raise_homestead_max(c, roundf(GameState.homestead_max[c] * PerkTable.amount_in(lo, &"stout_timbers")))
			got.append("a stouter Homestead")
		if lo.has(&"starting_iron"):
			var owned: Dictionary = GunShop.loadouts.get(peer, {&"revolver": 0})
			if not owned.has(&"lever_rifle"):
				owned[&"lever_rifle"] = 0
				GunShop.loadouts[peer] = owned
				var pl := _player_of(peer)
				if pl != null:
					pl.net.grant_weapon(&"lever_rifle", 0)
				got.append("a lever-action rifle")
		if not got.is_empty():
			Economy.notify(peer, "Rancher's Ledger: you start with %s." % ", ".join(got))
			if GameState.has_flag("--netlog"):
				print("[perks] host gave peer %d (cliff %d): %s" % [peer, cid, ", ".join(got)])


# [Foundation hook] Run save: each player's locked loadout and Barn Raising state.

## Host: what the run save keeps for this peer.
func run_state_of(peer_id: int) -> Dictionary:
	return {"loadout": _to_wire(loadout_of(peer_id)), "free_used": _free_used.has(peer_id)}


## Host, resuming a run: lock this peer back into its saved loadout (theirs
## too, on their machine) and whether Barn Raising's free turret is spent.
func restore_run_state(peer_id: int, state: Dictionary) -> void:
	if not multiplayer.is_server() or peer_id <= 0:
		return
	var lo := PerkProfile.sanitize(state.get("loadout", {}))
	var used := bool(state.get("free_used", false))
	if used:
		_free_used[peer_id] = true
	else:
		_free_used.erase(peer_id)
	if peer_id == multiplayer.get_unique_id():
		_run_loadout = lo
	else:
		loadouts[peer_id] = lo
		_restore_local.rpc_id(peer_id, _to_wire(lo), used)
	_broadcast()


@rpc("authority", "reliable")
func _restore_local(wire: Dictionary, used: bool) -> void:
	_run_loadout = PerkProfile.sanitize(wire)
	_local_free_used = used
	loadouts_changed.emit()


func _player_of(peer_id: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id and n is Player:
			return n as Player
	return null


func _free_build(peer: int, id: StringName, cid: int, cells: Array[Vector2i]) -> bool:
	var bm := BuildManager.instance
	if bm == null:
		return false
	for cell in cells:
		# Each gift gets its own cell (a scaffold would otherwise stack a level).
		if bm.is_free_for(id, cid, cell) and not bm.cell_taken(cid, cell):
			return bm.free_build(peer, id, cid, cell)
	return false


## Field spots first, then anywhere a plot fits.
static func _plot_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: int in Buildable.FIELD_ROWS:
		for c: int in Buildable.FIELD_COLS:
			out.append(Vector2i(r, c))
	for r in Buildable.ROWS:
		for c in Buildable.COLS:
			out.append(Vector2i(r, c))
	return out


## Turret-line cells spread across the lip, away from the middle.
static func _scaffold_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: int in [6, 14, 3, 17, 9, 11, 1, 19, 5, 15]:
		out.append(Vector2i(0, c))
	return out


func _on_game_over(won: bool, _reason: String) -> void:
	if not _run_active:
		return
	if Story.active():
		return # Story: the chapter pays its own Notches (StoryDirector reports them)
	var last := GameState.config().last_wave
	var held := GameState.wave if won else GameState.wave - 1
	held = maxi(held, 0)
	var has_partner := not GameState.is_solo()
	var full := BrandRules.earnings(held, last, _saves, won, has_partner)
	# An endless run banks again when it finally falls: only pay what's new.
	var before := BrandRules.earnings(int(_banked["waves"]), last, int(_banked["saves"]), bool(_banked["won"]), has_partner)
	var earned := int(full["total"]) - (int(before["total"]) if bool(_banked["rode"]) else 0)
	var test_run := (GameState.has_flag("--debug") and not GameState.has_flag("--perkearn")) or GameState.tutorial # the tutorial pays no Notches
	if not test_run:
		profile.bank_run(earned, GameState.wave, won)
		save()
		profile_changed.emit()
	_banked = {"waves": held, "saves": _saves, "won": won or bool(_banked["won"]), "rode": true}
	last_report = {"earned": earned, "lines": full["lines"], "total_run": full["total"], "banked": not test_run,
		"brands": profile.brands, "won": won}
	run_banked.emit(last_report)


# ------------------------------------------------------------------ debug

## --perkdemo: a profile with some Brands, unlocks and a loadout (never saved).
func _demo_profile() -> void:
	_no_save = true
	profile = PerkProfile.new()
	profile.brands = 245
	profile.lifetime_brands = 910
	profile.runs = 14
	profile.wins = 3
	profile.best_wave = 20
	for id: StringName in [&"quick_hands", &"quick_hands", &"steady_hand", &"heavy_slugs", &"dead_eye", &"starting_iron",
			&"green_thumb", &"green_thumb", &"green_thumb", &"deep_well", &"homestead_plot", &"carpenter", &"trail_rations",
			&"tough_hide", &"barn_raising", &"bulk_lumber", &"bulk_lumber", &"chitin_smith", &"old_scaffolds",
			&"long_sights", &"well_oiled", &"reinforced_frames", &"tinker", &"scrap_stash", &"scrap_stash"]:
		profile.brands += profile.next_cost(id)
		profile.unlock(id)
	for id: StringName in [&"quick_hands", &"heavy_slugs", &"dead_eye", &"starting_iron", &"green_thumb", &"homestead_plot",
			&"carpenter", &"barn_raising", &"bulk_lumber", &"old_scaffolds", &"long_sights", &"scrap_stash"]:
		profile.toggle(id)
	profile.cosmetics.append("hat:ten_gallon")
	if GameState.flag_value("--perkset") == "b":
		# Everything maxed and a different twelve (tests the rest of the hooks).
		for id in PerkTable.ids():
			while profile.next_cost(id) > 0:
				profile.brands += profile.next_cost(id)
				profile.unlock(id)
		profile.loadout.clear()
		for id: StringName in [&"well_oiled", &"reinforced_frames", &"chitin_smith", &"stout_timbers", &"full_pantry",
				&"tough_hide", &"bandolier", &"carpenter", &"tinker", &"salvager", &"scrap_stash", &"old_scaffolds"]:
			profile.toggle(id)
	elif GameState.flag_value("--perkset") == "c":
		# The newer perks (Lucky Shot, Point Blank, Overtime, Scrap Scavenger), maxed.
		profile.loadout.clear()
		for id: StringName in [&"lucky_shot", &"point_blank", &"overtime", &"scrap_scavenger"]:
			while profile.next_cost(id) > 0:
				profile.brands += profile.next_cost(id)
				profile.unlock(id)
			profile.toggle(id)
