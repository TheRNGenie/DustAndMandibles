class_name MovementThreats
extends Node
## Two wave events that ask for movement (movement plan #13 and #14), run by
## the host and mirrored on every peer by name.
##
## Acid nests: from wave NEST_WAVE (story: chapter 4 on), a flier lands under a
## cliff's lip, in front of one of its turrets, and builds a resin blob. After
## NEST_BUILD s it drips NEST_DPS onto every turret within NEST_RADIUS. Turrets
## can't touch it (it's no bug); a rider shoots it down (NEST_HP), best from a
## swing: a nest killed mid-grapple or mid-slingshot feeds the style combo.
## At most NEST_MAX per cliff.
##
## Glint beetles: from wave GLINT_WAVE, 1-2 a wave scurry along the face just
## under the lip of a cliff a rider stands on, at 1.5x walking speed, gone in
## GLINT_LIFE s. Harmless; worth GLINT_MULT (5x from wave 10) a normal kill to
## the team pot, and a kill keeps the killer's combo alive 3 s longer.

const NEST_WAVE := 5
const NEST_STORY_CHAPTER := 4
const NEST_BUILD := 5.0
const NEST_DPS := 10.0
const NEST_RADIUS := 5.0
const NEST_HP := 50.0
const NEST_MAX := 2
const GLINT_WAVE := 4
const GLINT_LIFE := 15.0
const GLINT_SPEED := 4.8 * 1.5
const GLINT_HP := 20.0
const GLINT_BASE_PAY := 8

var cliffs: CliffBuilder
var _plan: Array = [] ## [time, kind]
var _t := 0.0
var _n := 0
var _hp: Dictionary = {} ## host: node name -> hp


static func nest_count(wave: int, chapter: int) -> int:
	if chapter > 0:
		return 1 if chapter >= NEST_STORY_CHAPTER else 0
	return 0 if wave < NEST_WAVE else (1 if wave < 10 else 2)


static func glint_count(wave: int) -> int:
	return 0 if wave < GLINT_WAVE else (1 if wave < 8 else 2)


static func glint_mult(wave: int) -> int:
	return 5 if wave >= 10 else 3


func _ready() -> void:
	GameState.phase_changed.connect(_on_phase)


func _on_phase(p: GameState.Phase) -> void:
	if not multiplayer.is_server():
		return
	_plan.clear()
	if p == GameState.Phase.BUILD:
		# Nothing a wave left behind lingers into the build phase (Logan, Nov 11:
		# the green acid nests kept eating turrets wave after wave).
		_hp.clear()
		_clear_hazards.rpc()
	if p != GameState.Phase.WAVE or GameState.tutorial:
		return
	_t = 0.0
	var ch := Story.chapter()
	for i in nest_count(GameState.wave, ch.number if ch != null else 0):
		_plan.append([randf_range(10.0, 40.0), &"nest"])
	for i in glint_count(GameState.wave):
		_plan.append([randf_range(10.0, 45.0), &"glint"])
	_plan.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_t += delta
	while not _plan.is_empty() and _t >= float(_plan[0][0]):
		var kind: StringName = _plan.pop_front()[1]
		if kind == &"nest":
			_place_nest()
		else:
			_place_glint()
	# Built nests eat at the turrets under them.
	for n: Node in get_children():
		var nest := n as AcidNest
		if nest != null and nest.built():
			for t: Node in get_tree().get_nodes_in_group("turrets"):
				var tu := t as Turret
				if tu != null and tu.cliff_id == nest.cliff_id and tu.global_position.distance_to(nest.global_position) <= NEST_RADIUS + 1.5:
					tu.structure_damage(NEST_DPS * delta, "Acid Nest")


# ------------------------------------------------------------------ nests

func _place_nest() -> void:
	var turrets := get_tree().get_nodes_in_group("turrets").filter(func(t: Node) -> bool:
		return t is Turret and not (t as Turret).is_queued_for_deletion() and _nests_on((t as Turret).cliff_id) < NEST_MAX)
	if turrets.is_empty():
		return
	var t := turrets[randi() % turrets.size()] as Turret
	var y := WorldLayout.UNDERSIDE_BOTTOM - 0.6
	var at := cliffs.face_point(t.cliff_id, y, t.global_position.z) + cliffs.face_normal(t.cliff_id, y, t.global_position.z) * 0.4
	_n += 1
	var nm := "Nest%d" % _n
	_hp[nm] = NEST_HP
	_spawn_nest.rpc(nm, t.cliff_id, at)
	Economy.notify_cliff(t.cliff_id, "A flier is building an acid nest under your lip by the %s! Swing out and shoot it down." % t.def.display_name)


func _nests_on(cid: int) -> int:
	var n := 0
	for c: Node in get_children():
		if c is AcidNest and (c as AcidNest).cliff_id == cid and not c.is_queued_for_deletion():
			n += 1
	return n


## Every peer: free the nests and glints, and anything else in "bug_hazards".
@rpc("authority", "call_local", "reliable")
func _clear_hazards() -> void:
	for c: Node in get_children():
		if c is AcidNest or c is GlintBeetle:
			c.queue_free()
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group("bug_hazards"):
			n.queue_free()


@rpc("authority", "call_local", "reliable")
func _spawn_nest(nm: String, cid: int, at: Vector3) -> void:
	var nest := AcidNest.new()
	nest.add_to_group("bug_hazards")
	nest.name = nm
	nest.cliff_id = cid
	nest.director = self
	add_child(nest)
	nest.global_position = at


# ------------------------------------------------------------------ glint beetles

func _place_glint() -> void:
	var on: Array[int] = []
	for n: Node in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p != null and not on.has(p.cliff_id):
			on.append(p.cliff_id)
	if on.is_empty():
		return
	var cid: int = on[randi() % on.size()]
	var z0 := randf_range(-WorldLayout.PLATEAU_WIDTH * 0.45, WorldLayout.PLATEAU_WIDTH * 0.45)
	var dir := 1.0 if randf() < 0.5 else -1.0
	_n += 1
	var nm := "Glint%d" % _n
	_hp[nm] = GLINT_HP
	_spawn_glint.rpc(nm, cid, z0, dir)
	Economy.notify_cliff(cid, "A Glint Beetle is scurrying along your cliff face! Worth %dx a kill. Catch it!" % glint_mult(GameState.wave))


@rpc("authority", "call_local", "reliable")
func _spawn_glint(nm: String, cid: int, z0: float, dir: float) -> void:
	var g := GlintBeetle.new()
	g.name = nm
	g.cliff_id = cid
	g.z0 = z0
	g.dir = dir
	g.director = self
	add_child(g)


# ------------------------------------------------------------------ hits (host)

func hit(target: Node, dmg: float, source: String, source_cliff: int) -> void:
	if not multiplayer.is_server() or not _hp.has(String(target.name)):
		return
	if source.contains("'s ") or source == "Acid Nest":
		return # turrets can't touch these
	_hp[String(target.name)] = float(_hp[String(target.name)]) - dmg
	if float(_hp[String(target.name)]) > 0.0:
		return
	_hp.erase(String(target.name))
	if target is GlintBeetle:
		var pay := StyleCombo.scale_pay(source, float(GLINT_BASE_PAY * glint_mult(GameState.wave)))
		Economy.earn(maxi(source_cliff, 0), {&"scrap": roundi(pay)})
		Economy.notify_cliff(maxi(source_cliff, 0), "%s caught a Glint Beetle: +%s to the team pot!" % [source, UiStyle.cost(roundi(pay), ResNames.TEAM_ID)])
	_killed.rpc(String(target.name), source)


@rpc("authority", "call_local", "reliable")
func _killed(nm: String, source: String) -> void:
	var n := get_node_or_null(NodePath(nm))
	if n == null:
		return
	Audio.play_at(&"hammer_hit" if n is AcidNest else &"coin", (n as Node3D).global_position, 0.0, 0.7)
	# The killer's style combo: a nest from the rope, any glint (and 3 s more grace).
	for p: Node in get_tree().get_nodes_in_group("players"):
		var pl := p as Player
		if pl == null or not pl.is_multiplayer_authority() or pl.display_name() != source:
			continue
		if n is GlintBeetle:
			pl.combo.add()
			pl.combo.extend(3.0)
		elif pl.grapple.is_active() or pl.slingshot.flying():
			pl.combo.add()
	n.queue_free()


## A resin blob under a cliff's lip: grows for NEST_BUILD s, then drips acid.
class AcidNest extends Node3D:
	var cliff_id := 0
	var director: MovementThreats
	var _age := 0.0
	var _blob: MeshInstance3D

	func _ready() -> void:
		add_to_group("acid_nests")
		_blob = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.9
		s.height = 1.4
		_blob.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#7FA82A")
		m.emission_enabled = true
		m.emission = Color("#9BD13A")
		m.emission_energy_multiplier = 0.6
		m.roughness = 0.2
		_blob.material_override = m
		add_child(_blob)
		add_child(Hitbox.make(self, 1.0, Vector3.ZERO))
		_blob.scale = Vector3.ONE * 0.2

	func built() -> bool:
		return _age >= MovementThreats.NEST_BUILD

	func _process(delta: float) -> void:
		_age += delta
		var k := clampf(_age / MovementThreats.NEST_BUILD, 0.2, 1.0)
		var wob := 1.0 + 0.06 * sin(_age * 5.0)
		_blob.scale = Vector3(k * wob, k / wob, k * wob)

	func receive_hit(damage: float, _point: Vector3, _dir: Vector3, _pierce: bool, multiplier: float, source: String, source_cliff: int) -> void:
		director.hit(self, damage * multiplier, source, source_cliff)


## A small gold beetle scurrying along the face under the lip; every peer
## works out the same path from its start (no syncing needed).
class GlintBeetle extends Node3D:
	var cliff_id := 0
	var z0 := 0.0
	var dir := 1.0
	var director: MovementThreats
	var _t := 0.0

	func _ready() -> void:
		add_to_group("glint_beetles")
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.35
		s.height = 0.4
		mi.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = Palette.GLOW_YELLOW
		m.emission_enabled = true
		m.emission = Palette.GLOW_YELLOW
		m.emission_energy_multiplier = 1.2
		m.metallic = 0.8
		m.roughness = 0.2
		mi.material_override = m
		add_child(mi)
		var glow := OmniLight3D.new()
		glow.light_color = Palette.GLOW_YELLOW
		glow.light_energy = 1.5
		glow.omni_range = 3.0
		add_child(glow)
		add_child(Hitbox.make(self, 0.6, Vector3.ZERO))
		_place()

	func _process(delta: float) -> void:
		_t += delta
		_place()
		if _t >= MovementThreats.GLINT_LIFE and multiplayer.is_server():
			director._killed.rpc(String(name), "")

	func _place() -> void:
		var half := WorldLayout.PLATEAU_WIDTH * 0.5 - 1.0
		# Back and forth along the face, turning at the plateau's ends.
		var run := z0 + dir * MovementThreats.GLINT_SPEED * _t
		var span := half * 2.0
		var u := fposmod(run + half, span * 2.0)
		var z := (u if u <= span else span * 2.0 - u) - half
		var y := WorldLayout.CLIFF_HEIGHT - 4.0 + 0.6 * sin(_t * 3.0)
		var cl := director.cliffs
		global_position = cl.face_point(cliff_id, y, z) + cl.face_normal(cliff_id, y, z) * 0.35

	func receive_hit(damage: float, _point: Vector3, _dir: Vector3, _pierce: bool, multiplier: float, source: String, source_cliff: int) -> void:
		director.hit(self, damage * multiplier, source, source_cliff)
