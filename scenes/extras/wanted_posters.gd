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
	if GameState.has_flag("--posters") or GameState.flag_value("--posters") != "":
		# Debug: put every bounty up at once (screenshots).
		var ids: Array[StringName] = [&"rattler_beetle", &"brood_mother", &"iron_tumble"]
		if GameState.flag_value("--posters") != "":
			# --posters=queen_spider,tumble_titan,... picks which.
			ids.clear()
			for id in GameState.flag_value("--posters").split(","):
				ids.append(StringName(id))
		for id: StringName in ids:
			_post(Defs.bug(id))
		if _posters.has(&"rattler_beetle"):
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
	var to_cliff := source_cliff if source_cliff >= 0 and source_cliff < WorldLayout.cliff_count() else bug.cliff_id # Maps:
	Economy.earn(to_cliff, {&"scrap": amount})
	var who := source if source != "" else "Somebody"
	_paid.rpc(base, who)
	BugManager.instance._announce_line.rpc("Bounty collected! %s got the %s: %s" % [who, bug.def.display_name.trim_prefix("The "), UiStyle.cost(amount, ResNames.TEAM_ID)])


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
	if def == null or _posters.has(def.base_id()):
		return
	var slot := _order.size()
	if _order.size() >= MAX_POSTERS:
		# Wall's full: a new bounty is nailed over the oldest one already paid
		# (bosses keep coming, every one gets its poster).
		var old := &""
		for b: StringName in _order:
			if bool(_posters[b]["paid"]):
				old = b
				break
		if old == &"":
			return
		slot = int(_posters[old]["slot"])
		_take_down(old)
	var base := def.base_id()
	var vp := _render(def)
	_posters[base] = {"vp": vp, "stamp": vp.get_node("Paper/Stamp"), "paid": false, "def": def, "slot": slot, "quads": []}
	_order.append(base)
	for cid in WorldLayout.cliff_count(): # Maps:
		var home := Homestead.of(cid)
		if home != null:
			var q := _make_quad(vp.get_texture(), slot)
			home.add_child(q)
			(_posters[base]["quads"] as Array).append(q)


func _take_down(base: StringName) -> void:
	var p: Dictionary = _posters[base]
	for q: Node in p.get("quads", []):
		if is_instance_valid(q):
			q.queue_free()
	(p["vp"] as Node).queue_free()
	_posters.erase(base)
	_order.erase(base)


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
	paper.add_theme_stylebox_override("panel", UiStyle.aged_paper(sb.bg_color, sb.border_color, 5, 12.0))
	paper.position = Vector2.ZERO
	paper.size = Vector2(TEX_SIZE)
	vp.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	paper.add_child(col)
	col.add_child(_ink("WANTED", 46, MenuScreen.CARD_INK))
	# Bosses carry their crime; everyone else is just wanted.
	col.add_child(_ink(def.wanted_for if def.wanted_for != "" else "DEAD  OR  DEAD", 14 if def.wanted_for.length() < 26 else 12, MenuScreen.CARD_INK.lightened(0.15)))
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#D9C08A")
	fsb.border_color = MenuScreen.CARD_INK
	fsb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.custom_minimum_size = Vector2(0, 150)
	col.add_child(frame)
	var pic := TextureRect.new()
	pic.texture = UiStyle.plate(def.id) if UiStyle.plate(def.id) != null else IconStudio.bug(self, def.id) # the painted plate
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(pic)
	var name_l := _ink(def.display_name.to_upper(), 19, MenuScreen.CARD_INK)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_l)
	col.add_child(_ink("REWARD  %d  %s" % [bounty_of(def), ResNames.team().to_upper()], 20, Color("#7A1E14")))
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
	var vp_ref: WeakRef = weakref(vp) # weak: the poster can be freed first
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		var v := vp_ref.get_ref() as SubViewport
		if v != null:
			v.render_target_update_mode = SubViewport.UPDATE_ONCE)
	return vp


static func _ink(text: String, size: int, color: Color) -> Label:
	var l := MenuScreen.ink_label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
