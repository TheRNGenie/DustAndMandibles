class_name FloorHunt
extends RefCounted
## Canyon Expeditions: the brain of an awake bug hunting a player on the canyon
## floor (host only; Bug._think hands CROSSING bugs with a hunt_peer here).
## It runs at the player and bites; once the player is back up (or downed, or
## the bug was called home: hunt_peer -1) it goes back to its tunnel and is gone.


static func think(bug: Bug, delta: float) -> void:
	var peer := bug.hunt_peer
	var pl: Player = null
	if peer > 0:
		pl = Expedition.player_node(peer)
		if pl == null or not Expedition.is_down(peer) or pl.is_downed():
			pl = null
	var spd := bug.def.walk_speed * ExpeditionRules.HUNTER_SPEED * bug.speed() * delta
	if pl == null:
		# Home: back into the tunnel, and gone.
		var home := Vector3(bug.hunt_home.x - bug.ground_pos.x, 0.0, bug.hunt_home.z - bug.ground_pos.z)
		if home.length() <= spd + 0.5:
			bug.floor_bug = false
			bug.queue_free()
		else:
			bug.ground_pos += home.normalized() * spd
		return
	var to := Vector3(pl.global_position.x - bug.ground_pos.x, 0.0, pl.global_position.z - bug.ground_pos.z)
	var reach := ExpeditionRules.HUNTER_REACH + bug.crowd_r
	if to.length() > reach:
		bug.ground_pos += to.normalized() * minf(spd, to.length() - reach * 0.8)
	elif pl.global_position.y < Bug.cliffs.floor_height(pl.global_position.x, pl.global_position.z) + 3.0:
		# Close and on the ground (not hanging on a rope out of reach): it bites.
		pl.net.server_damage(bug.def.breach_dps * delta * Defs.WAVE_CONFIG.damage_scale(GameState.wave))
