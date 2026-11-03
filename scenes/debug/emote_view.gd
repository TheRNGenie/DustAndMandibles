extends Node
## Debug: --emoteview=<t> stands four dummies in front of your camera, each
## holding one emote (tip hat, wave, point, shrug) frozen at t (0..1), so a
## --shot screenshot shows how they read in third person. Made by Emotes.
## --actids=a,b,... stands up those DummyActions moves instead (e.g. twirl,reload_revolver).

var _rigs: Array[DummyRig] = []


func _ready() -> void:
	for i in 40:
		await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var t := clampf(GameState.flag_value("--emoteview").to_float(), 0.0, 1.0)
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var ground := cam.global_position.y - 1.6
	var ids: Array[StringName] = DummyActions.EMOTES.duplicate()
	if GameState.flag_value("--actids") != "":
		ids.clear()
		for a in GameState.flag_value("--actids").split(","):
			ids.append(StringName(a))
	for i in ids.size():
		var rig := DummyRig.new()
		get_tree().current_scene.add_child(rig)
		rig.build(Palette.TEAM_WEST, false, Settings.look)
		rig.global_position = Vector3(cam.global_position.x, ground, cam.global_position.z) + fwd * 4.5 + right * (float(i) - (ids.size() - 1) * 0.5) * 1.3
		rig.look_at(Vector3(cam.global_position.x, ground, cam.global_position.z), Vector3.UP)
		rig.play_action(ids[i])
		rig.action_freeze = t
		_rigs.append(rig)


func _process(delta: float) -> void:
	for r in _rigs:
		r.animate(delta, 0.0, false, 0.0)
