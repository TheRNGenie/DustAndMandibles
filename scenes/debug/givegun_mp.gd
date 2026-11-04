extends Node
## Handing a gun to a partner, two-window network test (DebugTools starts it on
## --givegunmp=host|client; reuses the Hive amber harness's launch: --debug --direct,
## throwaway --profile=..., a --port of its own). Each logs "[givegun <side>]" lines.
##   host:   debug-grants itself the Dino Rifle (a glass fit), drops it at the
##           client's feet, and answers the client's asks (give it guns, drop
##           another Dino Rifle, put one in a chest). With --netlog the host logs
##           every client shot it confirms and the damage per pellet it applies.
##   client: (its profile has NOT entered the Dino Rifle's code) picks the rifle up,
##           then switches through every weapon slot, photographs the viewmodel
##           (--givegunshot=<prefix>: <prefix>_<step>_<weapon>.png), fires each one
##           and logs what it holds, which models are visible, ammo and the
##           host's record of its loadout. Then the same with three guns already
##           carried (drop one to make room), and through the storage chest. With
##           the rifle out it also switches to the grapple, Zippo, bucket, medicine
##           and empty hands (<prefix>_<step>_item<slot>.png): no gun model may show.
## Launch (two windows, display 1): host
##   --screen 0 --path . -- --debug --direct --windowed --port=249xx --host --menu --players=2
##     --profile=gg_h --givegunmp=host --netlog
## and client: same, with --join=127.0.0.1 --profile=gg_c --givegunmp=client --givegunshot=<dir>\c.png
## (--menu keeps the host's lobby open until the client is in; --givegunquit=S ends both).

var world: Node3D
var side := ""
var me: Player
var _t0 := 0


func _ready() -> void:
	world = get_tree().current_scene as Node3D
	side = GameState.flag_value("--givegunmp")
	_t0 = Time.get_ticks_msec()
	var quit_after := GameState.flag_value("--givegunquit").to_float() if GameState.flag_value("--givegunquit") != "" else 150.0
	get_tree().create_timer(quit_after).timeout.connect(get_tree().quit)
	Economy.notice.connect(func(text: String) -> void: _p("notice: " + text))
	var until := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		me = world.call("local_player") as Player
		if me != null and NetworkManager.players.size() >= 2 and get_tree().get_nodes_in_group("players").size() >= 2:
			break
		await get_tree().physics_frame
	if me == null:
		_p("FAIL no local player")
		return
	_p("ready: my peer %d cliff %d, players %s, I know the dino code: %s" % [multiplayer.get_unique_id(), me.cliff_id,
			str(NetworkManager.players.keys()), Perks.profile.has_secret("weapon", "dino_rifle")])
	for i in 90:
		await get_tree().physics_frame
	if side == "host":
		_host()
	elif side == "client":
		_client()


func _p(s: String) -> void:
	print("[givegun %s t=%.1f] %s" % [side, (Time.get_ticks_msec() - _t0) / 1000.0, s])


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _client_peer() -> int:
	for pid: int in NetworkManager.players:
		if pid != multiplayer.get_unique_id():
			return pid
	return 0


func _player_of(peer: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer:
			return n as Player
	return null


# ------------------------------------------------------------------ host

func _host() -> void:
	var cp := _client_peer()
	_p("secrets the client sent: %s (has dino: %s)" % [str(Perks.peer_secrets.get(cp, [])), Perks.has_secret(cp, &"weapon", &"dino_rifle")])
	await _give_self_dino(2)
	await _drop_for_client()


func _give_self_dino(glass: int) -> void:
	var code := DinoGlass.with_variant(0, glass)
	if not GunShop.loadouts.has(1):
		GunShop.loadouts[1] = {&"revolver": 0}
	GunShop.loadouts[1][&"dino_rifle"] = code
	me.net.grant_weapon(&"dino_rifle", code)
	await _wait(0.5)
	_p("host holds %s code %d, loadout %s" % [str(me.gun.slots), me.gun.code_of(&"dino_rifle"), str(GunShop.loadouts[1])])


## Host: drop our Dino Rifle at the client's feet.
func _drop_for_client() -> void:
	var cpl := _player_of(_client_peer())
	me.gun.equip(&"dino_rifle")
	await _wait(0.3)
	var level := me.gun.code_of(&"dino_rifle")
	me.gun.remove_weapon(&"dino_rifle")
	var pos := cpl.global_position + Vector3.UP * 0.6 if cpl != null else me.global_position
	me.net._host_drop(multiplayer.get_unique_id(), &"dino_rifle", level, pos)
	_p("dropped the dino rifle (code %d) at %s; host loadout %s" % [level, str(pos), str(GunShop.loadouts.get(1))])


## Client asks: put a Dino Rifle (glass fit) into my chest / on the ground at my feet.
@rpc("any_peer", "reliable")
func ask_host(what: String, arg: int) -> void:
	if not multiplayer.is_server():
		return
	var cp := multiplayer.get_remote_sender_id()
	_p("client asks: %s %d" % [what, arg])
	match what:
		"grant":
			var id: StringName = [&"lever_rifle", &"coach_shotgun", &"elephant_gun", &"blunderbuss"][arg]
			if not GunShop.loadouts.has(cp):
				GunShop.loadouts[cp] = {&"revolver": 0}
			GunShop.loadouts[cp][id] = 0
			_player_of(cp).net.grant_weapon(id, 0)
		"drop_dino":
			await _give_self_dino(arg)
			await _drop_for_client()
		"chest_dino":
			# Into the host's own house chest (host stores it the normal way).
			await _give_self_dino(arg)
			var chest := Homestead.of(me.cliff_id).get_node("Chest") as StorageChest
			chest.menu_press("w:dino_rifle", &"store")
			await _wait(0.5)
			_p("host chest now %s" % str(chest.weapons))
		"report":
			_p("REPORT client loadout on host %s" % str(GunShop.loadouts.get(cp)))
	_ack.rpc_id(cp, what)


@rpc("authority", "reliable")
func _ack(what: String) -> void:
	_acks.append(what)


var _acks: Array = []


# ------------------------------------------------------------------ client

func _ask(what: String, arg: int = 0) -> void:
	_acks.clear()
	ask_host.rpc_id(1, what, arg)
	var until := Time.get_ticks_msec() + 8000
	while not _acks.has(what) and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	await _wait(0.6)


func _pickup(id: StringName) -> WeaponPickup:
	for n: Node in world.find_children("Pickup*", "WeaponPickup", true, false):
		var p := n as WeaponPickup
		if p.weapon_id == id and not p.is_queued_for_deletion():
			return p
	return null


func _pick_up_dino(tag: String) -> void:
	var until := Time.get_ticks_msec() + 8000
	var pk := _pickup(&"dino_rifle")
	while pk == null and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		pk = _pickup(&"dino_rifle")
	if pk == null:
		_p("%s: FAIL no dino pickup" % tag)
		return
	_p("%s: pickup %s says '%s'" % [tag, pk.name, pk.interact_prompt()])
	pk.local_interact(false)
	await _wait(1.0)
	_state(tag + " after pickup")


func _client() -> void:
	var prefix := GameState.flag_value("--givegunshot").replace(".png", "")
	_state("start")
	# A: just the revolver, the host drops its Dino Rifle for us.
	await _pick_up_dino("A")
	await _cycle("A", prefix)
	await _items("A", prefix)
	# B: carrying three guns already.
	var hb := me.get_node("Hotbar") as Hotbar
	me.gun.equip(&"dino_rifle")
	hb._drop()
	await _wait(0.8)
	_state("B dropped dino")
	await _ask("grant", 0)
	await _ask("grant", 1)
	_state("B three guns")
	var pk := _pickup(&"dino_rifle")
	if pk != null:
		pk.local_interact(false)
		await _wait(0.8)
	_state("B pickup with full slots (want refused)")
	me.gun.equip(&"coach_shotgun")
	hb._drop()
	await _wait(0.8)
	_state("B dropped shotgun")
	await _pick_up_dino("B")
	await _cycle("B", prefix)
	# C: holding the rifle (not the revolver) when it arrives, another fit.
	me.gun.equip(&"dino_rifle")
	hb._drop()
	await _wait(0.8)
	me.gun.equip(&"lever_rifle")
	await _wait(0.5)
	await _pick_up_dino("C")
	await _cycle("C", prefix)
	# D: through the chest: store ours, take it back; then take one from the host's chest.
	var chest := Homestead.of(me.cliff_id).get_node("Chest") as StorageChest
	chest.menu_press("w:dino_rifle", &"store")
	await _wait(1.0)
	_state("D stored in my chest (chest %s)" % str(chest.weapons))
	chest.menu_press("w:dino_rifle", &"take")
	await _wait(1.0)
	_state("D took it back")
	await _cycle("D", prefix)
	chest.menu_press("w:dino_rifle", &"store")
	await _wait(1.0)
	await _ask("chest_dino", 4)
	var hchest := Homestead.of(WorldLayout.other_cliff(me.cliff_id)).get_node("Chest") as StorageChest
	_state("E host chest %s" % str(hchest.weapons))
	hchest.menu_press("w:dino_rifle", &"take")
	await _wait(1.0)
	_state("E took the host's from its chest")
	await _cycle("E", prefix)
	await _items("E", prefix)
	await _ask("report")
	_p("DONE")


## Every weapon slot in turn: equip through the hotbar, photograph, fire, log.
func _cycle(tag: String, prefix: String) -> void:
	var hb := me.get_node("Hotbar") as Hotbar
	for i in 3:
		var id := hb.slot_item(i)
		if id == &"":
			continue
		hb.use_slot(i, false)
		await _wait(0.9)
		var shown := _visible_models()
		var ok: bool = shown.size() == 1 and shown[0] == String(id) and me.gun.def != null and me.gun.def.id == id
		var a0 := me.gun.ammo
		var fired := _fire()
		await _wait(0.2)
		_p("%s slot %d %s: def %s holding '%s' visible %s %s | fire %s ammo %d -> %d (mag %d) stage reloading %s aiming %s raise %.2f | gates: menu %s mouse %d downed %s build %s" % [
				tag, i + 1, id, me.gun.def.id if me.gun.def != null else "<none>", me.gun.holding, str(shown), "OK" if ok else "WRONG MODEL",
				fired, a0, me.gun.ammo, me.gun.mag_size(), me.gun.is_reloading(), me.gun.aiming, me.gun._raise,
				GameState.menu_open, Input.mouse_mode, me.vitals.downed, me.build_mode != null and me.build_mode.active])
		if prefix != "":
			await RenderingServer.frame_post_draw
			var path := "%s_%s_%d_%s.png" % [prefix, tag, i + 1, id]
			get_viewport().get_texture().get_image().save_png(path)
		await _wait(0.4)


## With the Dino Rifle last in hand, put it away for each item slot (and empty
## hands): no gun model may show, and the left click mustn't fire a gun.
func _items(tag: String, prefix: String) -> void:
	var hb := me.get_node("Hotbar") as Hotbar
	var dslot := me.gun.slots.find(&"dino_rifle")
	for i: int in [9, 8, 7, 6, dslot]:
		hb.use_slot(dslot, false)
		await _wait(0.6)
		if i == dslot:
			hb.use_slot(dslot) # pressed again: empty hands
		else:
			hb.use_slot(i, false)
		await _wait(0.9)
		var shown := _visible_models()
		var fired := _fire()
		_p("%s item slot %d: holding '%s' def %s visible guns %s %s | fire %s" % [tag, i + 1, me.gun.holding,
				me.gun.def.id if me.gun.def != null else "<none>", str(shown), "OK" if shown.is_empty() else "WRONG MODEL", fired])
		if prefix != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s_%s_item%d.png" % [prefix, tag, i + 1])
	hb.use_slot(dslot, false)
	await _wait(0.6)


## Fire the gun in hand the way Player._handle_weapon does.
func _fire() -> bool:
	var cam := me.camera
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	if me.gun.def != null and me.gun.def.automatic:
		me.gun.spin = 1.0
	if me.gun.trigger(cam):
		me.net.fire(from, dir)
		return true
	return false


func _visible_models() -> Array:
	var out: Array = []
	for id: StringName in me.gun._models:
		if (me.gun._models[id] as Node3D).visible:
			out.append(String(id))
	return out


func _state(tag: String) -> void:
	var g := me.gun
	_p("%s: owned %s slots %s def %s holding '%s' visible %s ammo-by-weapon %s" % [tag, str(g.owned), str(g.slots),
			g.def.id if g.def != null else "<none>", g.holding, str(_visible_models()), str(g._ammo_by_weapon)])
