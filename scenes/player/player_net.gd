class_name PlayerNet
extends Node
## Networking for one player: state replicated by the sibling MultiplayerSynchronizer
## (20 Hz, interpolated on the other peer) and host-confirmed shooting.
## Movement is owned by the player's own peer; hits are decided by the host.

## Replicated state, written by the owning peer.
var sync_pos: Vector3
var sync_yaw: float
var sync_pitch: float
var sync_sliding: bool
var sync_downed: bool
## The gun in hand ("" when holding an item), so others see it in your fist.
var sync_weapon: StringName = &"revolver"
## Your outfit (DummyLook) as JSON, so the other player sees how you're dressed.
var sync_look: String = ""
var _applied_look := ""
var _look_hash := 0

@onready var player: Player = get_parent() as Player

const SMOOTHING := 14.0


func _physics_process(delta: float) -> void:
	if player.is_multiplayer_authority():
		sync_pos = player.global_position
		sync_yaw = player.rotation.y
		sync_pitch = player.head.rotation.x
		sync_sliding = player.is_sliding()
		sync_downed = player.vitals.downed
		var g := player.gun
		sync_weapon = g.def.id if (g.holding == &"" and g.def != null) else &""
		player.rig.set_weapon(sync_weapon)
		var look: Dictionary = player.bot_look if player.bot else Settings.look
		var h := hash(look)
		if h != _look_hash: # (only when the outfit changes, not every tick)
			_look_hash = h
			sync_look = JSON.stringify(look)
	else:
		player.rig.set_weapon(sync_weapon)
	if sync_look != _applied_look and sync_look != "":
		_applied_look = sync_look
		player.rig.apply_look(DummyLook.clean(JSON.parse_string(sync_look)))
		if player.is_multiplayer_authority() and not player.bot:
			player.gun.refresh_arms(Settings.look)
	if not player.is_multiplayer_authority():
		# Remote players follow their owner's replicated position every tick.
		var k := 1.0 - exp(-SMOOTHING * delta)
		if player.global_position.distance_to(sync_pos) > 6.0:
			player.global_position = sync_pos # teleport (respawn, mantle)
		else:
			player.global_position = player.global_position.lerp(sync_pos, k)
		player.rotation.y = lerp_angle(player.rotation.y, sync_yaw, k)
		player.head.rotation.x = lerpf(player.head.rotation.x, sync_pitch, k)
		player.set_remote_pose(sync_sliding)


## Sets the initial replicated state so the other peer doesn't lerp from the origin.
func prime() -> void:
	sync_pos = player.global_position
	sync_yaw = player.rotation.y


## Host: damage this player (from a breacher). Health lives on the owning peer.
func server_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if player.is_multiplayer_authority():
		player.vitals.apply_damage(amount)
		return
	# A remote player: every chewing bug hits every tick, so add it up and send
	# it 10 times a second, reliably (a dropped packet would drop the damage).
	if _owed <= 0.0:
		player.get_tree().create_timer(0.1, true).timeout.connect(_send_owed)
	_owed += amount


var _owed := 0.0


func _send_owed() -> void:
	if _owed > 0.0 and multiplayer.is_server() and is_instance_valid(player) and player.is_inside_tree():
		_take_damage.rpc_id(player.get_multiplayer_authority(), _owed)
	_owed = 0.0


@rpc("any_peer", "call_remote", "reliable")
func _take_damage(amount: float) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		player.vitals.apply_damage(amount)


## Owner: brew a sarsaparilla root into a tonic for your partner (PartnerTonic).
func request_tonic() -> void:
	Audio.play_ui(&"herb_eat", -6.0)
	if multiplayer.is_server():
		Economy.send_tonic(multiplayer.get_unique_id(), player.cliff_id)
	else:
		_request_tonic.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_tonic() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		Economy.send_tonic(multiplayer.get_remote_sender_id(), player.cliff_id)


## Owner: ask the host to spend 1 food or water so you can eat or drink.
func request_consume(kind: StringName) -> void:
	if multiplayer.is_server():
		_consume(multiplayer.get_unique_id(), kind)
	else:
		_request_consume.rpc_id(1, kind)


@rpc("any_peer", "reliable")
func _request_consume(kind: StringName) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		_consume(multiplayer.get_remote_sender_id(), kind)


func _consume(peer_id: int, kind: StringName) -> void:
	var payer := Economy.payer_cliff(peer_id, player.cliff_id)
	if not Economy.spend(payer, {kind: 1}):
		Economy.notify(peer_id, "No %s left in your stockpile. Grow some!" % String(kind))
		return
	if peer_id == multiplayer.get_unique_id():
		player.vitals.consumed(kind)
	else:
		_consumed.rpc_id(peer_id, kind)


@rpc("any_peer", "reliable")
func _consumed(kind: StringName) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		player.vitals.consumed(kind)


## Host: hand a bought or upgraded weapon to this player's own Gun.
func grant_weapon(id: StringName, level: int) -> void:
	if player.is_multiplayer_authority():
		_apply_grant(id, level)
	else:
		_grant.rpc_id(player.get_multiplayer_authority(), id, level)


@rpc("any_peer", "reliable")
func _grant(id: StringName, level: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_apply_grant(id, level)


func _apply_grant(id: StringName, level: int) -> void:
	var before := player.gun.code_of(id) if player.gun.owns(id) else -1
	player.gun.grant(id, level)
	var gun_name := Gun.weapon(id).display_name
	if before < 0:
		player.gun.equip(id)
		Economy.notice.emit("You got the %s! It's on your hotbar." % gun_name)
	elif WeaponMods.level(level) > WeaponMods.level(before):
		Economy.notice.emit("%s is now %s." % [gun_name, GunRarity.label(WeaponMods.level(level))])
	elif WeaponMods.names(id, level & ~before) != "": # (Lucky's finish alone: Amber.buy says so itself)
		Economy.notice.emit("%s fitted with: %s." % [gun_name, WeaponMods.names(id, level & ~before)])


## Owner: drop a weapon at your feet (anyone can pick it up again).
func drop_weapon(id: StringName) -> void:
	var level := player.gun.code_of(id)
	player.gun.remove_weapon(id)
	var pos := player.global_position + -player.global_transform.basis.z * 1.2 + Vector3.UP * 0.6
	if multiplayer.is_server():
		_host_drop(multiplayer.get_unique_id(), id, level, pos)
	else:
		_request_drop.rpc_id(1, id, level, pos)


## Owner: drop one of the crop / medicine / water you're holding.
func drop_item(item: StringName) -> void:
	var pos := player.global_position + -player.global_transform.basis.z * 1.2 + Vector3.UP * 0.6
	if multiplayer.is_server():
		_host_drop_item(multiplayer.get_unique_id(), item, pos)
	else:
		_request_drop_item.rpc_id(1, item, pos)


@rpc("any_peer", "reliable")
func _request_drop_item(item: StringName, pos: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		_host_drop_item(multiplayer.get_remote_sender_id(), item, pos)


func _host_drop_item(peer_id: int, item: StringName, pos: Vector3) -> void:
	if not Hotbar.NAMES.has(item) or item == &"grapple" or item == &"lighter":
		return
	if not Economy.spend(Economy.payer_cliff(peer_id, player.cliff_id), {item: 1}):
		return
	PickupManager.instance.spawn_item(item, pos)


@rpc("any_peer", "reliable")
func _request_drop(id: StringName, level: int, pos: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		_host_drop(multiplayer.get_remote_sender_id(), id, level, pos)


func _host_drop(peer_id: int, id: StringName, level: int, pos: Vector3) -> void:
	var owned: Dictionary = GunShop.loadouts.get(peer_id, {&"revolver": 0})
	if not owned.has(id):
		return
	owned.erase(id)
	GunShop.loadouts[peer_id] = owned
	PickupManager.instance.spawn_weapon(id, level, pos)


## Called by the owning peer after the gun fired.
func fire(origin: Vector3, dir: Vector3) -> void:
	var gun := player.gun
	var id := gun.def.id
	var level := gun.code_of(id)
	var seed_value := randi() & ~1
	if gun.aim > 0.6:
		seed_value |= 1 # aimed shots spread less (see Gun.shot_dirs)
	var muzzle := gun.muzzle_global()
	var def := gun.def
	if def.special == &"smoke":
		_smoke_fx(muzzle, dir)
	elif multiplayer.is_server():
		pass # the host's own shot: _server_fire casts each pellet once and draws it too
	else:
		for d in Gun.shot_dirs(id, dir, seed_value, level):
			var hit := gun.raycast(origin, d, [player.get_rid()], Gun.range_for(id, level))
			var dmg := Gun.damage_at(id, level, origin.distance_to(hit["position"])) if not hit.is_empty() else Gun.damage_for(id, level)
			dmg *= _crit(def, hit)
			gun.show_impact(hit, d, true, dmg) # client-side prediction
			var end: Vector3 = hit["position"] if not hit.is_empty() else origin + d * Gun.range_for(id, level)
			gun.draw_tracer(id, muzzle, end)
			if def.special == &"harpoon":
				_harpoon_self(hit)
	if multiplayer.is_server():
		_server_fire(origin, dir, id, level, seed_value, muzzle)
	else:
		_request_fire.rpc_id(1, origin, dir, id, level, seed_value)


@rpc("any_peer", "call_remote", "reliable")
func _request_fire(origin: Vector3, dir: Vector3, id: StringName, level: int, seed_value: int) -> void:
	if not multiplayer.is_server() or Gun.weapon(id) == null:
		return
	if multiplayer.get_remote_sender_id() != player.get_multiplayer_authority():
		return
	if GameState.has_flag("--netlog"):
		print("[host] confirmed %s shot from peer %d" % [String(id), multiplayer.get_remote_sender_id()])
	# Trust the host's own record of this gun (level and mods), not the sender's.
	var owned: Dictionary = GunShop.loadouts.get(multiplayer.get_remote_sender_id(), {})
	var code := int(owned.get(id, 0))
	if GameState.has_flag("--netlog"):
		print("[host] %s shot from peer %d: host code %d (sender said %d), %.1f damage a pellet" % [String(id), multiplayer.get_remote_sender_id(), code, level, Gun.damage_for(id, code)])
	if Gun.weapon(id).special == &"smoke":
		_show_remote_shot(origin, dir, id, seed_value, code)
		_server_fire(origin, dir, id, code, seed_value)
		return
	# The host draws this client's shot from the same rays that deal its damage.
	var def := Gun.weapon(id)
	Gun.play_shot_sound(def, player.global_position + Vector3.UP * 1.4, -4.0, seed_value >> 1)
	_server_fire(origin, dir, id, code, seed_value, null, _remote_muzzle())
	player.flash_body()


## Host: applies damage for every pellet, then tells every other peer to draw the shot.
## `muzzle` set: the host's own shot, drawn here as it's cast (no second ray);
## `remote_muzzle` set: a client's shot, drawn the same way from their body.
func _server_fire(origin: Vector3, dir: Vector3, id: StringName, level: int, seed_value: int, muzzle: Variant = null, remote_muzzle: Variant = null) -> void:
	var def := Gun.weapon(id)
	if def.special == &"smoke":
		_server_smoke(origin, dir.normalized(), level)
		_fire_fx.rpc(origin, dir, id, seed_value, level)
		return
	var salted: Array[Bug] = []
	for d in Gun.shot_dirs(id, dir.normalized(), seed_value, level):
		var hit := player.gun.raycast(origin, d, [player.get_rid()], Gun.range_for(id, level))
		if muzzle is Vector3:
			_draw_own_pellet(id, level, def, origin, d, hit, muzzle)
		elif remote_muzzle is Vector3: # a client's shot, as the host sees it
			player.gun.show_impact(hit, d)
			player.gun.draw_tracer(id, remote_muzzle, hit["position"] if not hit.is_empty() else origin + d * Gun.range_for(id, level))
		if hit.is_empty():
			if def.special == &"flare":
				# Into the open sky: it hangs there and sinks, lighting what's below.
				_flare_at.rpc(origin + d * minf(Gun.range_for(id, level), 60.0), true)
			continue
		# Per-gun roles: shotguns lose punch with distance; the Gatling pins bugs down.
		var dmg := Gun.damage_at(id, level, origin.distance_to(hit["position"]))
		dmg *= Perks.gun_hit_mult(player.get_multiplayer_authority(), hit, origin.distance_to(hit["position"])) # Perk: Heavy Slugs / Marksman / Lucky Shot / Point Blank
		dmg *= _crit(def, hit) # Telescope Rifle: weak-spot crits
		Gun.apply_hit_result(hit, d, dmg, Gun.pierce_for(id, level), player.display_name(), player.cliff_id)
		if def.special != &"":
			_server_special(def, hit, salted)
		if def.suppress_slow < 1.0:
			var hb := hit["collider"] as Hitbox
			var bug := hb.target as Bug if hb != null else null
			if bug != null and is_instance_valid(bug) and bug.is_alive():
				bug.status.slow(def.suppress_slow, def.suppress_time)
	for b in salted:
		GunRules.salt_hit(b) # once per shot, however many grains hit
	# Canyon Expeditions: gunshots carry (sleeping floor bugs hear them; the whip is quiet).
	Expedition.make_noise(origin, ExpeditionRules.gun_noise(def.special, def.kickback, Gun.shot_dirs(id, dir.normalized(), seed_value, level).size()))
	_fire_fx.rpc(origin, dir, id, seed_value, level)


## One pellet of your own shot, as you see it: the impact, its number and the tracer.
func _draw_own_pellet(id: StringName, level: int, def: WeaponDef, origin: Vector3, d: Vector3, hit: Dictionary, muzzle: Vector3) -> void:
	var gun := player.gun
	var dmg := Gun.damage_at(id, level, origin.distance_to(hit["position"])) if not hit.is_empty() else Gun.damage_for(id, level)
	dmg *= _crit(def, hit)
	gun.show_impact(hit, d, true, dmg)
	var end: Vector3 = hit["position"] if not hit.is_empty() else origin + d * Gun.range_for(id, level)
	gun.draw_tracer(id, muzzle, end)
	if def.special == &"harpoon":
		_harpoon_self(hit)


## Weak-spot crit multiplier of a hit for this gun (1 = none).
static func _crit(def: WeaponDef, hit: Dictionary) -> float:
	if def.weak_bonus <= 1.0 or hit.is_empty():
		return 1.0
	var hb := hit["collider"] as Hitbox
	return GunRules.crit_mult(def.weak_bonus, hb != null and hb.multiplier_at(hit["position"]) > 1.0)


## Host: a frontier gun's special on one hit (GunRules): rock salt (collected,
## applied once per shot), the harpoon reeling a small bug in, a flare marking a
## bug for every turret or burning where it struck rock.
func _server_special(def: WeaponDef, hit: Dictionary, salted: Array[Bug]) -> void:
	var hb := hit["collider"] as Hitbox
	var bug := hb.target as Bug if hb != null else null
	var alive := bug != null and is_instance_valid(bug) and bug.is_alive()
	match def.special:
		&"salt":
			if alive and not salted.has(bug):
				salted.append(bug)
		&"harpoon":
			if alive and GunRules.harpoon_for_bug(bug) == GunRules.Harpoon.REEL:
				_reel(bug)
		&"flare":
			if alive:
				bug.status.mark(GunRules.MARK_TIME)
				bug.show_flare.rpc(GunRules.MARK_TIME)
			else:
				_flare_at.rpc(hit["position"] + (hit["normal"] as Vector3) * 0.15, false)


## Host: the harpoon reels a small bug in: off the wall (it drops), or dragged
## across the ground / out of the air to just in front of the shooter.
func _reel(bug: Bug) -> void:
	bug.status.root(GunRules.REEL_HOLD)
	match bug.state:
		Bug.State.CLIMBING:
			bug.knock_off(player.display_name(), player.cliff_id)
		Bug.State.BREACHING, Bug.State.FLYING, Bug.State.CROSSING:
			bug.ground_pos = GunRules.reel_point(bug.ground_pos, player.global_position + Vector3.UP * 0.8)


## Owner: the harpoon bit into rock or a big bug: you get reeled in to it.
func _harpoon_self(hit: Dictionary) -> void:
	if hit.is_empty():
		return
	var hb := hit["collider"] as Hitbox
	var action := GunRules.harpoon_action(false, true)
	if hb != null:
		var bug := hb.target as Bug
		action = GunRules.harpoon_for_bug(bug) if bug != null else GunRules.Harpoon.NONE
	if action == GunRules.Harpoon.PULL and player.grapple != null:
		player.grapple.harpoon_pull(hit["position"])


## Host: one puff of the Bee Smoker; every flier and spider in the cloud goes drowsy.
func _server_smoke(origin: Vector3, dir: Vector3, level: int) -> void:
	for n: Node in player.get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden():
			continue
		if GunRules.in_smoke(origin, dir, b.global_position, Gun.range_for(&"bee_smoker", level)):
			GunRules.smoke_hit(b, WeaponMods.level(level))


func _smoke_fx(muzzle: Vector3, dir: Vector3) -> void:
	var vfx := player.gun.vfx
	if vfx != null:
		vfx.bee_smoke(muzzle, dir)


## Every peer: a flare burning at `pos` (`sky`: it hangs in the air and sinks).
@rpc("any_peer", "call_local", "reliable")
func _flare_at(pos: Vector3, sky: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0:
		return
	var f := SignalFlare.make(GunRules.MARK_TIME + (3.0 if sky else 0.0))
	f.sink = 1.2 if sky else 0.0
	player.get_tree().current_scene.add_child(f)
	f.global_position = pos


@rpc("any_peer", "call_remote", "reliable")
func _fire_fx(origin: Vector3, dir: Vector3, id: StringName, seed_value: int, code: int = 0) -> void:
	if multiplayer.get_remote_sender_id() != 1 or player.is_multiplayer_authority():
		return # only the host sends this, and the shooter already predicted it
	_show_remote_shot(origin, dir, id, seed_value, code)


func _show_remote_shot(origin: Vector3, dir: Vector3, id: StringName, seed_value: int, code: int = 0) -> void:
	var def := Gun.weapon(id)
	Gun.play_shot_sound(def, player.global_position + Vector3.UP * 1.4, -4.0, seed_value >> 1)
	var muzzle := _remote_muzzle()
	if def.special == &"smoke":
		_smoke_fx(muzzle + dir.normalized() * 0.4, dir)
		return
	for d in Gun.shot_dirs(id, dir.normalized(), seed_value, code):
		var hit := player.gun.raycast(origin, d, [player.get_rid()], Gun.range_for(id, code))
		player.gun.show_impact(hit, d)
		var end: Vector3 = hit["position"] if not hit.is_empty() else origin + d * Gun.range_for(id, code)
		player.gun.draw_tracer(id, muzzle, end)
	player.flash_body()


## Where another player's shots seem to leave from (their body, not a view model).
func _remote_muzzle() -> Vector3:
	return player.global_position + Vector3.UP * 1.3 + player.global_transform.basis.x * 0.3


# ------------------------------------------------------------------ rocks

const ROCK_GRAVITY := 18.0
const ROCK_LIFE := 3.0
static var _rock_mesh: ArrayMesh


## Owner: lob a rock. Everyone sees it fly; the thrower decides what it hits.
## Owner: a whip lash landed its crack. The host works out what it caught.
func melee(origin: Vector3, dir: Vector3, crack: int) -> void:
	_crack_fx.rpc(crack)
	if multiplayer.is_server():
		_server_melee(origin, dir)
	else:
		_request_melee.rpc_id(1, origin, dir)


@rpc("any_peer", "reliable")
func _request_melee(origin: Vector3, dir: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		# Ignore lashes from far away from where the host sees the player.
		if origin.distance_to(player.global_position) < 4.0:
			_server_melee(origin, dir)


func _server_melee(origin: Vector3, dir: Vector3) -> void:
	# The host's own record of this player's whip.
	var c := int(GunShop.whips.get(player.get_multiplayer_authority(), 0))
	for b in Whip.targets(player.get_tree(), origin, dir, [player.get_rid()], Whip.reach_for(c)):
		b.receive_hit(Whip.damage_for(c) * Perks.more(player.get_multiplayer_authority(), &"whip_hand") * Brand.boss_mult(player.get_multiplayer_authority(), b), b.global_position, dir, false, 1.0, player.display_name(), player.cliff_id) # Perk: Whip Hand
		if b.is_alive():
			b.status.root(Whip.stun_for(c))


@rpc("any_peer", "call_local", "unreliable")
func _crack_fx(crack: int) -> void:
	Audio.play_at(StringName("whip_crack_%d" % (clampi(crack, 0, 2) + 1)), player.global_position + Vector3.UP * 1.5, -2.0)


func throw_rock(origin: Vector3, vel: Vector3) -> void:
	_spawn_rock.rpc(origin, vel)


@rpc("any_peer", "call_local", "reliable")
func _spawn_rock(origin: Vector3, vel: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != player.get_multiplayer_authority() and multiplayer.get_remote_sender_id() != 0:
		return
	if _rock_mesh == null:
		_rock_mesh = PropBuilder.rock(4711, 0.14)
	var rock := Rock.new()
	rock.mesh = _rock_mesh
	rock.material_override = Materials.toon(0.01)
	rock.vel = vel
	rock.thrower = player
	rock.authoritative = player.is_multiplayer_authority()
	player.get_tree().current_scene.add_child(rock)
	rock.global_position = origin
	Audio.play_at(&"throw", origin, -4.0)


@rpc("any_peer", "call_local", "reliable")
func _bonked(dir: Vector3, strength: float) -> void:
	player.bonk(dir, strength)
	Audio.play_at(&"armor_ping", player.global_position + Vector3.UP * 1.5, -2.0)


## A thrown rock: flies on a lob, tumbles, bonks the first player or bug it meets.
class Rock extends MeshInstance3D:
	var vel := Vector3.ZERO
	var thrower: Player
	var authoritative := false
	var _t := 0.0
	var _spin := Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t > ROCK_LIFE:
			queue_free()
			return
		var from := global_position
		vel.y -= ROCK_GRAVITY * delta
		var to := from + vel * delta
		rotation += _spin * delta
		var q := PhysicsRayQueryParameters3D.create(from, to, WorldLayout.LAYER_WORLD | WorldLayout.LAYER_BUG | WorldLayout.LAYER_STRUCTURE | 1)
		if is_instance_valid(thrower):
			q.exclude = [thrower.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		# Players are capsules on the default layer: check them by distance (cheap, two players).
		for n: Node in get_tree().get_nodes_in_group("players"):
			var p := n as Player
			if p == thrower:
				continue
			var c := p.global_position + Vector3.UP * 1.0
			if _seg_dist(from, to, c) < 0.6:
				if authoritative:
					p.net._bonked.rpc(vel.normalized(), 1.0)
				queue_free()
				return
		if not hit.is_empty():
			global_position = hit["position"]
			var col := hit["collider"] as Object
			if authoritative and col is Hitbox:
				# Bugs barely notice, but they do frown at you.
				var b := (col as Hitbox).get_parent()
				if b != null and b.has_node("Face"):
					(b.get_node("Face") as BugFace).wince()
			Audio.play_at(&"hit_tick", global_position, -8.0)
			queue_free()
			return
		global_position = to

	static func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		return (a + ab * t).distance_to(p)
