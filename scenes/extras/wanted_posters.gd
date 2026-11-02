class_name WantedPosters
extends Node3D
## Wanted posters: the first time a brute or boss type (Rattler Beetle, Brood
## Mother, the Iron Tumbleweed...) crawls out, a poster with its picture and a
## bounty gets nailed to the side wall of both houses. The first one killed pays
## the bounty in scrap to whoever's turret or gun got it (with a feed line), and
## the posters get a red PAID stamp. Every peer makes its own posters from the
## replicated bugs; the host decides the payout and tells everyone.

const POSTER_SIZE := Vector2(0.62, 0.84)
const TEX_SIZE := Vector2i(248, 336)
const MAX_POSTERS := 4
## Along the side wall (house z), on solid logs only: the side window spans
## z -0.6..0.6 (HouseBuilder._build, `side` openings) and the corners stick out
## past +-2.4, so two posters fit either side of the window.
const SLOT_Z := [1.05, -1.05, 1.9, -1.9]
## Bounties by kind of bug (scrap).
const BOUNTY := {BugDef.Behavior.BOSS: 300, BugDef.Behavior.BROOD: 100, BugDef.Behavior.TANK: 60}

## base bug id -> {"vp": SubViewport, "stamp": Control, "paid": bool, "def": BugDef}
var _posters: Dictionary = {}
var _order: Array[StringName] = []


func _ready() -> void:
	_hook.call_deferred()


func _hook() -> void:
	var bm := BugManager.instance
	if bm == null:
		return
	bm.child_entered_tree.connect(_on_bug_added)
	if GameState.has_flag("--posters"):
		# Debug: put every bounty up at once (screenshots).
		for id: StringName in [&"rattler_beetle", &"brood_mother", &"iron_tumble"]:
			_post(Defs.bug(id))
		_set_paid(&"rattler_beetle", "Rancher")


static func bounty_of(def: BugDef) -> int:
	return int(BOUNTY.get(def.behavior, 0))


func _on_bug_added(n: Node) -> void:
	var bug := n as Bug
	if bug == null or bug.def == null or bounty_of(bug.def) <= 0:
		return
	var base := bug.def.base_id()
	if not _posters.has(base):
		_post(Defs.bug(base) if Defs.bug(base) != null else bug.def)
	if multiplayer.is_server() and not bool(_posters[base]["paid"]):
		bug.died.connect(_on_wanted_died, CONNECT_ONE_SHOT)


## Host: a wanted bug died. The first of its kind pays the bounty to the killer.
func _on_wanted_died(bug: Bug, source: String, source_cliff: int) -> void:
	var base := bug.def.base_id()
	if not _posters.has(base) or bool(_posters[base]["paid"]):
		return
	var amount := bounty_of(bug.def)
	var to_cliff := source_cliff if source_cliff == WorldLayout.WEST or source_cliff == WorldLayout.EAST else bug.cliff_id
	Economy.earn(to_cliff, {&"scrap": amount})
	var who := source if source != "" else "Somebody"
	_paid.rpc(base, who)
	BugManager.instance._announce_line.rpc("Bounty collected! %s got the %s: %d scrap" % [who, bug.def.display_name, amount])


@rpc("authority", "call_local", "reliable")
func _paid(base: StringName, who: String) -> void:
	_set_paid(base, who)


func _set_paid(base: StringName, who: String) -> void:
	if not _posters.has(base):
		_post(Defs.bug(base))
	var p: Dictionary = _posters[base]
	p["paid"] = true
	var stamp := p["stamp"] as Control
	stamp.visible = true
	(stamp.get_meta("by") as Label).text = who.to_upper()
	(p["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	Audio.play_ui(&"coin", -6.0)


# ------------------------------------------------------------------ the posters

func _post(def: BugDef) -> void:
	if def == null or _posters.has(def.base_id()) or _order.size() >= MAX_POSTERS:
		return
	var base := def.base_id()
	var vp := _render(def)
	_posters[base] = {"vp": vp, "stamp": vp.get_node("Paper/Stamp"), "paid": false, "def": def}
	_order.append(base)
	var slot := _order.size() - 1
	for cid in 2:
		var home := Homestead.of(cid)
		if home != null:
			home.add_child(_make_quad(vp.get_texture(), slot))


## A poster on the house's left side wall (outside, facing away from the house),
## in a row along the wall at eye height, each a little crooked.
func _make_quad(tex: Texture2D, slot: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Wanted%d" % slot
	var x := -HouseBuilder.W * 0.5 - HouseBuilder.T * 0.5 - 0.22
	var z: float = SLOT_Z[mini(slot, SLOT_Z.size() - 1)]
	root.position = Vector3(x, 1.75 + (0.06 if slot % 2 == 0 else -0.04), z)
	root.rotation = Vector3(0, -PI * 0.5, deg_to_rad(-3.0 if slot % 2 == 0 else 4.0))
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = POSTER_SIZE
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# A nail at the top.
	var nail := MeshInstance3D.new()
	var st := MeshKit.begin()
	MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.022, 0.022, 0.03, 6, Palette.OUTLINE.lightened(0.25))
	nail.mesh = MeshKit.finish(st)
	nail.material_override = Materials.toon(0.01)
	nail.position = Vector3(0, POSTER_SIZE.y * 0.5 - 0.06, 0.02)
	root.add_child(nail)
	return root


## Draws the poster once into its own little viewport.
func _render(def: BugDef) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = "Poster_%s" % def.base_id()
	vp.size = TEX_SIZE
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var paper := PanelContainer.new()
	paper.name = "Paper"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#E9D6A8")
	sb.border_color = Color("#B89A63")
	sb.set_border_width_all(5)
	sb.set_content_margin_all(12)
	paper.add_theme_stylebox_override("panel", sb)
	paper.position = Vector2.ZERO
	paper.size = Vector2(TEX_SIZE)
	vp.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	paper.add_child(col)
	col.add_child(_ink("WANTED", 46, MenuScreen.INK))
	col.add_child(_ink("DEAD  OR  DEAD", 14, MenuScreen.INK.lightened(0.15)))
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#D9C08A")
	fsb.border_color = MenuScreen.INK
	fsb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.custom_minimum_size = Vector2(0, 150)
	col.add_child(frame)
	var pic := TextureRect.new()
	pic.texture = IconStudio.bug(self, def.id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(pic)
	var name_l := _ink(def.display_name.to_upper(), 19, MenuScreen.INK)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_l)
	col.add_child(_ink("REWARD  %d  SCRAP" % bounty_of(def), 20, Color("#7A1E14")))
	# The PAID stamp, hidden until the bounty is collected.
	var stamp := Control.new()
	stamp.name = "Stamp"
	stamp.visible = false
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.position = Vector2(0, 0)
	stamp.size = Vector2(TEX_SIZE)
	paper.add_child(stamp)
	var box := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0)
	ssb.border_color = Color("#B3261E", 0.9)
	ssb.set_border_width_all(6)
	ssb.set_corner_radius_all(6)
	ssb.set_content_margin_all(6)
	box.add_theme_stylebox_override("panel", ssb)
	box.position = Vector2(34, 120)
	box.rotation = deg_to_rad(-18.0)
	stamp.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", -6)
	box.add_child(inner)
	inner.add_child(_ink("PAID", 64, Color("#B3261E", 0.92)))
	var by := _ink("", 14, Color("#B3261E", 0.92))
	by.name = "By"
	inner.add_child(by)
	stamp.set_meta("by", by)
	# Re-render a few times (the bug picture renders in its own viewport), then stop.
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE)
	return vp


static func _ink(text: String, size: int, color: Color) -> Label:
	var l := MenuScreen.ink_label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
