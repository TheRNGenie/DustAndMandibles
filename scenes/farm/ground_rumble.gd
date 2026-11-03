class_name GroundRumble
extends Node
## The ground rumbling as the pumps come on (Waterworks), on every peer: a deep
## rumble (a CC0 recording, see audio/CREDITS.txt), a light screen shake that
## ramps in and out on the local player, and dust boiling out of every tunnel.
## The host's warning clock brings the first bugs out a couple of seconds after.

const TunnelRumble := preload("res://scenes/bugs/tunnel_rumble.gd")

var seconds := 3.5
var _t := 0.0


static func play(parent: Node, duration: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var r := GroundRumble.new()
	r.name = "GroundRumble"
	r.seconds = duration
	parent.add_child(r)


func _ready() -> void:
	Audio.play_ui(&"ground_rumble", -3.0)
	var cl := Bug.cliffs
	if cl != null:
		for i in cl.tunnel_count():
			var tn: Array = cl.tunnel(i)
			TunnelRumble.play(get_parent(), tn[0], tn[1], 0.7, seconds, false)


func _process(delta: float) -> void:
	_t += delta
	var target := Waterworks.rumble_shake(_t, seconds)
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority() and n is Player:
			# Hold the camera shake at the rumble's level (Player decays it each frame).
			var p := n as Player
			var now: float = p.get("_shake")
			if now < target:
				p.add_shake(target - now)
	if _t > seconds + 0.2:
		queue_free()
