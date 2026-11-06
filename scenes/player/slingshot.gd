class_name Slingshot
extends Node
## The grapple slingshot (movement plan #16): flung off the rope near the
## swing's top speed, you fly as a weapon until you land. Every bug you pass
## through takes ComboRules.sling_damage(your combo) once. The owner checks the
## flight and tells the host what it hit; the host checks the distance and
## deals the damage with your name on it (so the kill counts for your combo).

const RADIUS := 1.8
const MAX_FLIGHT := 2.0

var player: Player
var _left := 0.0
var _hit: Dictionary = {}


func setup(p: Player) -> void:
	player = p
	if player.is_multiplayer_authority():
		player.grapple.slung.connect(_on_slung)


func flying() -> bool:
	return _left > 0.0


func _on_slung(_v: Vector3) -> void:
	if GameState.has_flag("--combolog"):
		print("[sling] flung, combo %d" % player.combo.count)
	_left = MAX_FLIGHT
	_hit.clear()
	player.combo.add()
	player.add_shake(0.12)
	Audio.play_at(&"slide", player.global_position, -2.0, 1.4)


func _physics_process(delta: float) -> void:
	if _left <= 0.0 or player == null or not player.is_multiplayer_authority():
		return
	_left -= delta
	if (player.is_on_floor() and _left < MAX_FLIGHT - 0.15) or player.grapple.is_active():
		_left = 0.0
		return
	var bm := WaveDirector.bug_manager
	if bm == null:
		return
	var at := player.global_position + Vector3.UP * 0.9
	for c: Node in bm.get_children():
		var b := c as Bug
		if b == null or not b.is_alive() or _hit.has(b.get_instance_id()):
			continue
		if b.global_position.distance_to(at) <= RADIUS + float(b.spec.get("scale", 1.0)) * 0.6:
			_hit[b.get_instance_id()] = true
			var dmg := ComboRules.sling_damage(player.combo.count) * BrandTable.sling_mult(Brand.local_id()) # Attack on Mandibles: +20%
			Audio.play_at(&"hammer_hit", b.global_position, -2.0, 0.8)
			player.add_shake(0.1)
			if multiplayer.is_server():
				_strike(b, dmg)
			else:
				_strike_on_host.rpc_id(1, bm.get_path_to(b), dmg)


@rpc("any_peer", "reliable")
func _strike_on_host(path: NodePath, dmg: float) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.get_multiplayer_authority():
		return
	var bm := WaveDirector.bug_manager
	var b := bm.get_node_or_null(path) as Bug if bm != null else null
	# The host's copy of the rider lags a little: allow some slack.
	if b == null or not b.is_alive() or b.global_position.distance_to(player.global_position) > RADIUS + 6.0:
		return
	_strike(b, minf(dmg, ComboRules.SLING_MAX * (1.0 + BrandTable.SLING_DAMAGE)))


func _strike(b: Bug, dmg: float) -> void:
	var dir := player.velocity.normalized() if player.velocity.length() > 0.1 else Vector3.FORWARD
	b.receive_hit(dmg, b.global_position, dir, true, 1.0, player.display_name(), player.cliff_id)
