extends BossBrain
## The Mirage Mantis (only hunts in dust storms). Always a heat-haze shimmer;
## every ~5 s she fades almost out of sight (never fully) for about a second, and
## turrets lose her while she's faded. A lantern post near her keeps her solid.
## Host decides the fades and the lantern light; every peer draws them.

const CYCLE := 5.0
const FADE_TIME := 1.1
## How solid she looks faded (never 0: a ripple stays).
const FADED := 0.1
## A lantern this many times its reveal radius away keeps her in sight.
const LANTERN_K := 1.8
## Haze shimmer in plain sight and faded.
const HAZE := 0.55

var _mat: ShaderMaterial
## Every peer (from the host's events).
var _fading := false
var _lit := false
var _solid := 1.0
var _parts_shown := true
## Host.
var _cd := 3.0
var _left := 0.0
var _lantern_check := 0.0


func _attach() -> void:
	if bug._solo != null:
		_mat = BossBuilder.mirage_material()
		bug._solo.material_override = _mat
		_mat.set_shader_parameter("haze", HAZE)


func think(delta: float) -> bool:
	if not bug.is_alive():
		return false
	_lantern_check -= delta
	if _lantern_check <= 0.0:
		_lantern_check = 0.25
		var lit := _near_lantern()
		if lit != _lit:
			send(&"lit", [lit])
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0 or _lit:
			_left = 0.0
			send(&"fade", [false])
	else:
		_cd -= delta
		if _cd <= 0.0:
			_cd = CYCLE + randf_range(-0.7, 0.7)
			if not _lit and not bug.is_hidden():
				_left = FADE_TIME
				send(&"fade", [true])
	return false


func _near_lantern() -> bool:
	for l: Node in bug.get_tree().get_nodes_in_group("lanterns"):
		var n := l as Node3D
		if n != null and n.has_method("reveal_radius") and n.global_position.distance_to(bug.global_position) <= float(n.call("reveal_radius")) * LANTERN_K:
			return true
	return false


func on_event(kind: StringName, args: Array) -> void:
	match kind:
		&"fade":
			_fading = bool(args[0])
			if _fading:
				# A dry rustle and a puff of sand as she slips into the haze.
				Audio.play_at(&"rustle", bug.global_position, -2.0, 0.6)
				if fx() != null:
					fx().dust(bug.global_position, Vector3.UP, 0.8)
		&"lit":
			_lit = bool(args[0])
			if _lit:
				Audio.play_at(&"zippo_strike", bug.global_position, -6.0, 0.8)


func untargetable() -> bool:
	return _fading and not _lit


func visual(delta: float) -> void:
	age += delta
	var want := FADED if untargetable() else 1.0
	# Quick to vanish, a little slower to come back.
	_solid = move_toward(_solid, want, delta * (4.0 if want < _solid else 2.5))
	if _mat != null:
		_mat.set_shader_parameter("solid", _solid)
		_mat.set_shader_parameter("haze", lerpf(HAZE, 1.0, 1.0 - _solid) * (0.4 if _lit else 1.0))
	# Her legs and eyes go with her body (else they'd hang in mid air).
	var show := _solid > 0.35 and not bug.is_hidden()
	if show != _parts_shown:
		_parts_shown = show
		bug._legs.set_shown(show)
		if bug._face != null:
			bug._face.visible = show


func hud_status() -> String:
	if _lit:
		return "LIT UP"
	return "FADED" if untargetable() else ""
