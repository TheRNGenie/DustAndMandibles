class_name Dynamite
extends Node3D
## The grapple's dynamite (Logan's request; rules in DynamiteRules). With the
## Powder Satchel bought at the gunsmith and the grapple launcher out:
##   R      a bundle of three sticks comes up in the left hand
##   R      again: the fuse is struck along the match strip on the launcher's
##          flank (a rasp, sparks, the fuse catches and sizzles), the arm winds
##          back and lobs it at the reticle; it lands where you aim (out to
##          DynamiteRules.THROW_RANGE) and goes up a moment later.
## Without the satchel, R with the grapple out does nothing (as before); with
## a gun out R still reloads. A few bundles are carried (DynamiteRules.MAX_BUNDLES);
## they come back slowly while you're up top and fill when a wave is held.
##
## Host-authoritative like the guns: the owner plays the hand and asks the host
## to throw; the host checks its own record (GunShop.dynamite: the satchel and
## mods; `host_bundles` here), launches the bundle on every peer, and applies
## the blast when its own copy goes up. Everyone sees the bundle in the hand
## (on the body: DummyRig.set_dynamite), the strike, the arc and the blast.
## Lives under the camera; the first-person hand is the owner's only.

enum Hand { DOWN, RAISING, READY, STRIKING, WINDUP, COOLDOWN }

var player: Player
## Satchel and mods (WeaponMods code), the owner's copy; set by the gunsmith.
var code := 0
## Bundles carried, the owner's copy (the host's own count is host_bundles).
var bundles := 0
var hand: Hand = Hand.DOWN
var _t := 0.0
var _queued := false
var _lit := false
var _no_bundle_note := 0
## Host: bundles this player carries and the restock clock.
var host_bundles := 0
var _restock_t := 0.0
## Every peer: bundles in flight from this player, by id.
var _flying: Dictionary = {}
static var _next_id := 1
## Debug screenshots: hold the hand at this point of the strike/windup (-1 = play).
var freeze := -1.0

var _hand_root: Node3D
var _arm_mi: MeshInstance3D
var _bundle_root: Node3D
var _fuse: FuseFx
var _strip: MeshInstance3D
var _strike_spark_done := false
static var _bundle_mesh: ArrayMesh
static var _strip_mesh: ArrayMesh

## Hand poses, camera space: where the bundle sits once raised, and tucked away below.
const READY_POS := Vector3(-0.24, -0.2, -0.56)
const READY_ROT := Vector3(-0.3, 0.25, 0.18)
const DOWN_POS := Vector3(-0.3, -0.55, -0.3)
## Where the strip sits on the launcher (gun-item space: the grit faces -X).
const STRIP_AT := Vector3(-0.04, 0.004, -0.105)


func _ready() -> void:
	if _bundle_mesh == null:
		_bundle_mesh = WeaponBuilder.dynamite_bundle()
		_strip_mesh = WeaponBuilder.match_strip()
	_hand_root = Node3D.new()
	add_child(_hand_root)
	_arm_mi = MeshInstance3D.new()
	_arm_mi.mesh = WeaponBuilder.left_item_arm(Settings.look)
	_arm_mi.material_override = Materials.toon(0.004)
	_arm_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hand_root.add_child(_arm_mi)
	_bundle_root = Node3D.new()
	_hand_root.add_child(_bundle_root)
	var b := MeshInstance3D.new()
	b.mesh = _bundle_mesh
	b.material_override = Materials.toon(0.004)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bundle_root.add_child(b)
	_fuse = FuseFx.new()
	_fuse.small = true
	_fuse.position = WeaponBuilder.DYNAMITE_FUSE_TIP
	_bundle_root.add_child(_fuse)
	_hand_root.visible = false
	if GameState.flag_value("--dynfreeze") != "":
		freeze = GameState.flag_value("--dynfreeze").to_float()
	GameState.phase_changed.connect(_on_phase)


func unlocked() -> bool:
	return DynamiteRules.unlocked(code)


## Does R belong to the dynamite right now? (Grapple out and the satchel bought.)
func owns_r() -> bool:
	return player.gun.holding == &"grapple" and unlocked() and not player.is_downed()


## What R does next, for the HUD hint ("" = nothing to show).
func hint() -> String:
	if not owns_r():
		return ""
	match hand:
		Hand.DOWN, Hand.COOLDOWN:
			return "Ready Dynamite" if bundles > 0 else ""
		Hand.RAISING, Hand.READY:
			return "Strike & Throw"
	return ""


## Owner: R with the launcher out.
func press() -> void:
	match hand:
		Hand.DOWN:
			if bundles <= 0:
				var now := Time.get_ticks_msec()
				if now - _no_bundle_note > 2500:
					_no_bundle_note = now
					Economy.notice.emit("No dynamite left. A bundle comes back every %d s up top, and the satchel fills when a wave is held." % int(DynamiteRules.RESTOCK_SECS))
				return
			_set_hand(Hand.RAISING)
			Audio.play_at(&"rustle", global_position, -8.0)
			_show_state.rpc(1)
		Hand.RAISING:
			_queued = true
		Hand.READY:
			_set_hand(Hand.STRIKING)


func _set_hand(h: Hand) -> void:
	hand = h
	_t = 0.0
	_strike_spark_done = false


func _on_phase(p: GameState.Phase) -> void:
	# A wave held: the satchel's topped up (host).
	if p == GameState.Phase.BUILD and multiplayer.is_server() and _host_code() != 0 and DynamiteRules.unlocked(_host_code()):
		_host_set_bundles(DynamiteRules.MAX_BUNDLES)


# ------------------------------------------------------------------ owner: the hand

func _process(delta: float) -> void:
	if player == null:
		return
	var mine := player.is_multiplayer_authority()
	if mine:
		_owner_tick(delta)
	_pose_strip(mine)


func _owner_tick(delta: float) -> void:
	var holding := player.gun.holding == &"grapple" and not player.is_downed() and not GameState.menu_open
	var lit_now := hand == Hand.STRIKING or hand == Hand.WINDUP
	# Put away (or downed) with a bundle up but not lit: it goes back in the satchel.
	# Once it's lit, the throw always finishes.
	if not holding and (hand == Hand.RAISING or hand == Hand.READY):
		_set_hand(Hand.DOWN)
		_show_state.rpc(0)
	if freeze < 0.0:
		_t += delta
	else:
		_freeze_pose()
	match hand:
		Hand.RAISING:
			if _t >= DynamiteRules.RAISE_TIME:
				_set_hand(Hand.STRIKING if _queued else Hand.READY)
				_queued = false
		Hand.STRIKING:
			var u := _t / DynamiteRules.STRIKE_TIME
			if u >= 0.25 and not _strike_spark_done:
				_strike_spark_done = true
				Audio.play_at(&"match_strike", global_position, -2.0)
			if u >= 0.55 and not _lit:
				_light(true)
				_show_state.rpc(2)
			if u >= 1.0:
				_set_hand(Hand.WINDUP)
		Hand.WINDUP:
			if _t >= DynamiteRules.WINDUP_TIME:
				_throw()
				_set_hand(Hand.COOLDOWN)
		Hand.COOLDOWN:
			if _t >= DynamiteRules.COOLDOWN:
				_set_hand(Hand.DOWN)
	if not lit_now and _lit and hand != Hand.STRIKING and hand != Hand.WINDUP:
		_light(false)
	_pose(holding)


func _light(on: bool) -> void:
	_lit = on
	_fuse.lit = on
	if on and player.gun.vfx != null:
		player.gun.vfx.spark(_fuse.global_position, Vector3.UP, Color("#FFD27A"))


## Debug: hold the hand somewhere in the strike (0..1) or the windup (1..2).
func _freeze_pose() -> void:
	if hand == Hand.DOWN and unlocked() and player.gun.holding == &"grapple":
		hand = Hand.STRIKING
	if freeze < 1.0:
		hand = Hand.STRIKING
		_t = freeze * DynamiteRules.STRIKE_TIME
		if freeze >= 0.55 and not _lit:
			_light(true)
	elif freeze < 2.0:
		hand = Hand.WINDUP
		_t = (freeze - 1.0) * DynamiteRules.WINDUP_TIME
		if not _lit:
			_light(true)
	else:
		hand = Hand.READY
		_t = 1.0


func _pose(holding: bool) -> void:
	var show := holding and hand != Hand.DOWN
	_hand_root.visible = show
	if not show:
		if holding:
			player.gun.item_pos = Vector3.ZERO
			player.gun.item_rot = Vector3.ZERO
		return
	_bundle_root.visible = hand != Hand.COOLDOWN
	var ready := Transform3D(Basis.from_euler(READY_ROT), READY_POS)
	var xf := ready
	# The launcher turns its flank (and the strip) toward the bundle for the strike,
	# and the bundle tips over in the fist, fuse toward the strip (`grip`).
	var turn := 0.0
	var grip := 0.0
	match hand:
		Hand.RAISING:
			var k := _ease(_t / DynamiteRules.RAISE_TIME)
			xf = Transform3D(Basis.from_euler(READY_ROT + Vector3(-0.9, 0.0, 0.4) * (1.0 - k)), DOWN_POS.lerp(READY_POS, k))
		Hand.READY:
			# A little idle sway, the bundle hefted.
			var s := sin(Time.get_ticks_msec() / 1000.0 * 2.2)
			xf = Transform3D(Basis.from_euler(READY_ROT + Vector3(0.03 * s, 0.0, 0.02 * s)), READY_POS + Vector3(0, 0.004 * s, 0))
		Hand.STRIKING:
			var u := clampf(_t / DynamiteRules.STRIKE_TIME, 0.0, 1.0)
			turn = _ease(u / 0.3) * (1.0 - _ease((u - 0.8) / 0.2))
			grip = _ease(u / 0.3)
			xf = _strike_pose(u, ready)
		Hand.WINDUP:
			var u := clampf(_t / DynamiteRules.WINDUP_TIME, 0.0, 1.0)
			var back := Transform3D(Basis.from_euler(Vector3(0.7, 0.4, 0.35)), Vector3(-0.3, -0.02, -0.36))
			var fwd := Transform3D(Basis.from_euler(Vector3(-1.1, 0.1, 0.0)), Vector3(-0.12, 0.02, -0.62))
			var after := _strike_pose(1.0, ready)
			grip = 1.0 - _ease(u / 0.5)
			if u < 0.65:
				xf = after.interpolate_with(back, _ease(u / 0.65))
			else:
				xf = back.interpolate_with(fwd, _ease((u - 0.65) / 0.35))
		Hand.COOLDOWN:
			var u := clampf(_t / DynamiteRules.COOLDOWN, 0.0, 1.0)
			var fwd := Transform3D(Basis.from_euler(Vector3(-1.1, 0.1, 0.0)), Vector3(-0.12, 0.02, -0.62))
			xf = fwd.interpolate_with(Transform3D(Basis.from_euler(Vector3(-1.6, 0.2, 0.3)), DOWN_POS), _ease(u * 1.6))
	_hand_root.transform = xf
	_bundle_root.transform = _grip(grip)
	player.gun.item_pos = Vector3(-0.07, 0.035, 0.03) * turn
	player.gun.item_rot = Vector3(0.1, -0.55, 0.35) * turn


## The strike, u 0..1: over to the back end of the strip, the fuse drawn hard
## along it toward the muzzle (it catches half way), then pulled up and away.
func _strike_pose(u: float, ready: Transform3D) -> Transform3D:
	# The wrist turns over and the bundle tips in the fist (_grip), so the fuse
	# points right at the strip while the forearm still comes up from below.
	var b := Basis.from_euler(STRIKE_ROT)
	var ends := _strip_ends()
	var tip := _grip(1.0) * WeaponBuilder.DYNAMITE_FUSE_TIP
	var off := Vector3(-0.004, 0.003, 0)
	var at_back := Transform3D(b, ends[0] - b * tip + off)
	var at_front := Transform3D(b, ends[1] - b * tip + off)
	var lifted := Transform3D(b.rotated(Vector3.FORWARD, -0.3), ends[1] - b * tip + Vector3(-0.07, 0.05, 0.05))
	if u < 0.3:
		return ready.interpolate_with(at_back, _ease(u / 0.3))
	if u < 0.75:
		return at_back.interpolate_with(at_front, _ease((u - 0.3) / 0.45))
	return at_front.interpolate_with(lifted, _ease((u - 0.75) / 0.25))


const STRIKE_ROT := Vector3(-0.25, -0.15, -0.6)


## The bundle in the fist: upright (0) or tipped over toward the strip (1),
## held further down so the fuse end reaches.
static func _grip(k: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -0.75) * k), Vector3(0.0, 0.05, 0.0) * k)


## The strip's two ends in camera space ([back, front]).
func _strip_ends() -> Array:
	var item := player.gun.item_node()
	var half := Vector3(0, 0, WeaponBuilder.MATCH_STRIP_LEN * 0.45)
	if item == null:
		return [Vector3(0.12, -0.2, -0.42), Vector3(0.12, -0.2, -0.54)]
	var to_cam := (get_parent() as Node3D).global_transform.affine_inverse() * item.global_transform
	var face := Vector3(0.004, 0, 0) # the grit side (the strip is turned round: see _pose_strip)
	return [to_cam * (STRIP_AT + half + face), to_cam * (STRIP_AT - half + face)]


## The match strip rides on the launcher whenever you've the satchel (hold_item
## rebuilds the launcher, so it's put back when it goes missing).
func _pose_strip(mine: bool) -> void:
	var want := mine and unlocked() and player.gun.holding == &"grapple"
	var item := player.gun.item_node() if mine else null
	if want and item != null and (_strip == null or not is_instance_valid(_strip) or _strip.get_parent() != item):
		_strip = MeshInstance3D.new()
		_strip.mesh = _strip_mesh
		_strip.material_override = Materials.toon(0.003)
		_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_strip.position = STRIP_AT
		_strip.rotation.y = PI # (the grit outward, on the launcher as it's held)
		item.add_child(_strip)
	if _strip != null and is_instance_valid(_strip):
		_strip.visible = want


static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Owner: let go of the bundle at the reticle.
func _throw() -> void:
	var cam := player.camera
	var from := _fuse.global_position.lerp(_bundle_root.global_position, 0.5)
	var eye := cam.global_position
	var aim := -cam.global_transform.basis.z
	var skip: Array[RID] = [player.get_rid()]
	var q := PhysicsRayQueryParameters3D.create(eye, eye + aim * DynamiteRules.THROW_RANGE,
			WorldLayout.LAYER_WORLD | WorldLayout.LAYER_STRUCTURE | WorldLayout.LAYER_BUG, skip)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var target := DynamiteRules.throw_target(eye, aim, hit["position"] if not hit.is_empty() else null)
	var vel := DynamiteRules.launch_velocity(from, target, DynamiteRules.flight_time(from, target))
	bundles = maxi(bundles - 1, 0) # predicted; the host's count follows
	_light(false)
	Audio.play_at(&"throw", from, -2.0, 0.85)
	player.act_body(&"throw_dynamite")
	_show_state.rpc(0)
	if multiplayer.is_server():
		_host_throw(multiplayer.get_unique_id(), from, vel)
	else:
		_request_throw.rpc_id(1, from, vel)


# ------------------------------------------------------------------ host

func _host_code() -> int:
	return int(GunShop.dynamite.get(player.get_multiplayer_authority(), 0))


@rpc("any_peer", "reliable")
func _request_throw(from: Vector3, vel: Vector3) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority():
		_host_throw(multiplayer.get_remote_sender_id(), from, vel)


func _host_throw(peer_id: int, from: Vector3, vel: Vector3) -> void:
	var c := _host_code()
	if not DynamiteRules.unlocked(c) or not DynamiteRules.valid_throw(from, player.global_position, vel):
		return
	if host_bundles <= 0:
		_host_set_bundles(0) # put the owner's prediction right
		return
	if not GameState.has_flag("--dynamiteinf"):
		_host_set_bundles(host_bundles - 1)
	var id := _next_id
	_next_id += 1
	if GameState.has_flag("--dynlog"):
		print("[dynamite] peer %d threw #%d from %s at %s (%d left)" % [peer_id, id, str(from.snapped(Vector3.ONE * 0.1)), str(vel.snapped(Vector3.ONE * 0.1)), host_bundles])
	_spawn.rpc(id, from, vel)


func _physics_process(delta: float) -> void:
	if player == null or not multiplayer.is_server():
		return
	var c := _host_code()
	if not DynamiteRules.unlocked(c):
		return
	# Restock while up top; nothing comes back down on the canyon floor.
	if host_bundles < DynamiteRules.MAX_BUNDLES and not Expedition.is_down(player.get_multiplayer_authority()):
		var r := DynamiteRules.restock(host_bundles, _restock_t, delta)
		_restock_t = float(r[1])
		if int(r[0]) != host_bundles:
			_host_set_bundles(int(r[0]))


## Host: the gunsmith fitted the satchel (or a mod): a full satchel the first time.
func host_granted(new_code: int, was: int) -> void:
	if DynamiteRules.unlocked(new_code) and not DynamiteRules.unlocked(was):
		_restock_t = 0.0
		_host_set_bundles(DynamiteRules.MAX_BUNDLES)


func _host_set_bundles(n: int) -> void:
	host_bundles = clampi(n, 0, DynamiteRules.MAX_BUNDLES)
	if player.is_multiplayer_authority():
		bundles = host_bundles
	else:
		_set_bundles.rpc_id(player.get_multiplayer_authority(), host_bundles)


@rpc("any_peer", "reliable")
func _set_bundles(n: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		bundles = n


## Host: the bundle went up. Everything inside the radius takes the blast;
## the noise carries further than anything else in the canyon.
func _host_blast(id: int, pos: Vector3, normal: Vector3) -> void:
	var c := _host_code()
	var peer := player.get_multiplayer_authority()
	var source := "%s's Dynamite" % player.display_name()
	var radius := DynamiteRules.radius_for(c)
	var hits := 0
	for n: Node in get_tree().get_nodes_in_group("bugs"):
		var b := n as Bug
		if b == null or not b.is_alive() or b.is_hidden():
			continue
		var dist := b.global_position.distance_to(pos)
		var dmg := DynamiteRules.damage_at(c, dist, float(b.spec["body_radius"]))
		if dmg <= 0.0:
			continue
		hits += 1
		b.receive_hit(dmg * Brand.boss_mult(peer, b), pos, (b.global_position - pos).normalized(), true, 1.0, source, player.cliff_id)
		if not b.is_alive():
			continue
		if DynamiteRules.burns(c):
			b.status.burn(DynamiteRules.BURN_DPS, DynamiteRules.BURN_SECS, "%s's Coal Oil" % player.display_name(), player.cliff_id)
			b.show_flare.rpc(DynamiteRules.BURN_SECS) # it burns where everyone can see it (and lights it up for the turrets, as a flare does)
		if b.is_climbing():
			b.status.root(DynamiteRules.CLIMBER_STUN) # shaken on its line
		if b.hunter != null:
			b.hunter.lure(pos, DynamiteRules.LURE_SECS)
	BossFx.on_splash(-1, pos, radius, DynamiteRules.damage_for(c), source, player.cliff_id)
	# Canyon Expeditions: the loudest thing there is. Every sleeper in earshot
	# wakes and comes to look; anyone down there feels it on their risk clock.
	Expedition.make_noise(pos, DynamiteRules.NOISE, DynamiteRules.NOISE_HEAT)
	if BugManager.instance != null:
		for b in BugManager.instance.site_bugs():
			if b.hunter != null and b.global_position.distance_to(pos) <= DynamiteRules.NOISE:
				b.hunter.wake()
				b.hunter.lure(pos, DynamiteRules.LURE_SECS)
	if GameState.has_flag("--dynlog"):
		print("[dynamite] #%d went off at %s: %d bugs in %.1f m (code %d)" % [id, str(pos.snapped(Vector3.ONE * 0.1)), hits, radius, c])
	_blast.rpc(id, pos, normal, radius)


@rpc("any_peer", "call_local", "reliable")
func _spawn(id: int, from: Vector3, vel: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 and sender != 0:
		return
	var b := DynamiteBundle.new()
	b.id = id
	b.origin = from
	b.vel = vel
	b.authoritative = multiplayer.is_server()
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p is CollisionObject3D:
			b.skip.append((p as CollisionObject3D).get_rid())
	if b.authoritative:
		b.went_off.connect(func(bb: DynamiteBundle, at: Vector3, nrm: Vector3) -> void: _host_blast(bb.id, at, nrm))
	_flying[id] = b
	get_tree().current_scene.add_child(b)


@rpc("any_peer", "call_local", "reliable")
func _blast(id: int, pos: Vector3, normal: Vector3, radius: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 and sender != 0:
		return
	var b := _flying.get(id) as DynamiteBundle
	_flying.erase(id)
	if b != null and is_instance_valid(b):
		b.remove()
	var scene := get_tree().current_scene
	DynamiteBlast.play(scene, pos, radius, normal)
	# Everyone in the blast is blown about (never hurt): each peer flops every
	# body it sees, and its own player takes the shove and the tumble.
	for p: Node in get_tree().get_nodes_in_group("players"):
		var pl := p as Player
		if pl == null:
			continue
		var centre := pl.global_position + Vector3.UP * 0.9
		var d := centre.distance_to(pos)
		var k := DynamiteRules.knock_strength(d, radius)
		if k > 0.0:
			pl.blast_knock((centre - pos + Vector3.UP * 0.6).normalized(), k)
		if pl.is_multiplayer_authority():
			pl.add_shake(clampf(1.2 - d / 60.0, 0.0, 1.0))
			if d < 30.0:
				Audio.play_ui(&"ground_rumble", -4.0 - d * 0.2)


# ------------------------------------------------------------------ the body (everyone)

## Owner -> everyone: 0 nothing in the left hand, 1 a bundle up, 2 its fuse lit.
@rpc("authority", "call_local", "reliable")
func _show_state(state: int) -> void:
	if player != null and player.rig != null:
		player.rig.set_dynamite(state)


## Host: hand this player a dynamite code (the gunsmith, and the --dynamite debug flag).
func grant(new_code: int) -> void:
	if not multiplayer.is_server():
		return
	var was := _host_code()
	GunShop.dynamite[player.get_multiplayer_authority()] = new_code
	host_granted(new_code, was)
	if player.is_multiplayer_authority():
		code = new_code
	else:
		_set_code.rpc_id(player.get_multiplayer_authority(), new_code)


@rpc("any_peer", "reliable")
func _set_code(c: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		code = c
