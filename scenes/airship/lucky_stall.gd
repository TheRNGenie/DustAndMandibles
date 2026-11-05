class_name LuckyStall
extends StaticBody3D
## Lucky Moreau's stall on the airship: a fence's booth in a dark corner of the
## deck (black lacquer and gold, a velvet curtain, a glass case of amber and
## engraved irons), and Lucky himself, a gambler in a duster with a pencil
## moustache. He trades in hive amber only (AmberRules.STOCK): Lucky's finish on
## a gunsmith's iron, an exclusive look, one-night favours and the three amber
## turret blueprints. He's only aboard once the story is past chapter 4 (or from
## wave 8 in a normal run; Amber.lucky_open), so every peer shows or hides the
## stall by itself. Sales go to the host like the gunsmith's (Amber.buy).

signal menu_changed

const TABS: Array[String] = ["Irons", "Wardrobe", "Favours", "Blueprints"]
const KINDS: Array[String] = ["gun", "look", "favour", "blueprint"]
## Lucky says his piece when you walk up within this.
const GREET_RANGE := 5.5

var keeper: Shopkeeper
var _bubble: Label3D
var _bubble_t := 0.0
var _greeted := false
var _open := false
var _col: CollisionShape3D


func _ready() -> void:
	collision_layer = WorldLayout.LAYER_STRUCTURE
	collision_mask = 0
	add_to_group("lucky_stall")
	var mi := MeshInstance3D.new()
	mi.mesh = stall_mesh()
	mi.material_override = Materials.toon(0.022)
	add_child(mi)
	_col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.9, 1.7)
	_col.shape = shape
	_col.position = Vector3(0, 1.45, 0.05)
	add_child(_col)
	# Lucky: a black gambler's hat, a pencil moustache and a duster, a bolo tie.
	keeper = Shopkeeper.new()
	keeper.name = "Lucky"
	keeper.position = Vector3(0.35, 0, 0.12)
	add_child(keeper)
	keeper.setup({"hat": "gambler", "facial": "pencil", "hair": "ponytail", "hair_color": "black", "outfit": "duster",
		"neck": "bolo", "extra": "none", "paint": "white"}, Color("#5A1E4A"))
	# Lucky himself leans on the rail beside the booth now (LuckyNpc); the booth
	# stands unattended (the dummy behind it is kept for the old views, hidden).
	keeper.visible = false
	# Warm amber light from the case and a lantern, and his painted sign.
	var glow := OmniLight3D.new()
	glow.light_color = AmberRules.GLOW
	glow.light_energy = 1.6
	glow.omni_range = 4.0
	glow.position = Vector3(0, 1.5, -0.4)
	add_child(glow)
	# His board on the roof's front edge: the name, and the small print.
	for line: Array in [["LUCKY'S CURIOS", 0.0034, 3.42, AmberRules.GLOW], ["no questions asked", 0.0019, 3.2, Palette.BONE]]:
		var sign := Label3D.new()
		sign.text = str(line[0])
		sign.font_size = 72
		sign.pixel_size = float(line[1])
		sign.outline_size = 14
		sign.modulate = line[3]
		sign.outline_modulate = Color("#1E1014")
		sign.position = Vector3(0, float(line[2]), -1.12)
		sign.rotation.y = PI
		sign.double_sided = false
		add_child(sign)
	_bubble = Label3D.new()
	_bubble.font_size = 44
	_bubble.pixel_size = 0.0032
	_bubble.outline_size = 12
	_bubble.width = 900.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.modulate = Palette.BONE
	_bubble.outline_modulate = Palette.OUTLINE
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position = Vector3(0.35, 2.15, -1.3)
	_bubble.visible = false
	add_child(_bubble)
	Amber.changed.connect(_changed)
	Economy.resources_changed.connect(_on_resources)
	_set_open(Amber.lucky_open())


func _exit_tree() -> void:
	if Amber.changed.is_connected(_changed):
		Amber.changed.disconnect(_changed)
	if Economy.resources_changed.is_connected(_on_resources):
		Economy.resources_changed.disconnect(_on_resources)


func _changed() -> void:
	menu_changed.emit()


func _on_resources(_c: int) -> void:
	menu_changed.emit()


func _set_open(on: bool) -> void:
	_open = on
	visible = on
	_col.disabled = not on
	keeper.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	var want := Amber.lucky_open()
	if want != _open:
		_set_open(want)
	if not _open:
		return
	# The greeting, once each time someone walks up.
	var me := _local_player()
	var near := me != null and me.global_position.distance_to(global_position) < GREET_RANGE
	if near and not _greeted:
		_greeted = true
		say(AmberRules.LUCKY_GREETING)
	elif not near and me != null and me.global_position.distance_to(global_position) > GREET_RANGE + 3.0:
		_greeted = false
	if _bubble_t > 0.0:
		_bubble_t -= delta
		_bubble.visible = _bubble_t > 0.0


## Lucky says something (local: a speech line over his head).
func say(line: String, seconds: float = 6.0) -> void:
	_bubble.text = "\"%s\"" % line
	_bubble.visible = true
	_bubble_t = seconds


func _local_player() -> Player:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.is_multiplayer_authority():
			return n as Player
	return null


# ------------------------------------------------------------------ the menu

func interact_prompt() -> String:
	return "E: deal with Lucky Moreau (hive amber only)" if _open else ""


func local_interact(holding: bool) -> void:
	if not holding and _open and MenuScreen.instance != null:
		say(AmberRules.LUCKY_GREETING)
		MenuScreen.instance.open(self)


func menu_title() -> String:
	return "Lucky Moreau"


func menu_tagline() -> String:
	return "\"%s\"  Paid in hive amber, and only hive amber. Amber's yours alone: dig it up on the canyon floor." % AmberRules.LUCKY_GREETING


func menu_tabs() -> Array:
	return TABS


func menu_stock() -> Array:
	return [[AmberRules.ITEM, Economy.amount(_cliff(), AmberRules.ITEM)]]


func _cliff() -> int:
	var me := _local_player()
	return Economy.payer_cliff(multiplayer.get_unique_id(), me.cliff_id if me != null else 0)


func menu_items(tab: int) -> Array:
	var out: Array = []
	var amber := Economy.amount(_cliff(), AmberRules.ITEM)
	var me := multiplayer.get_unique_id()
	var player := _local_player()
	for item: Dictionary in AmberRules.STOCK:
		if str(item["kind"]) != KINDS[clampi(tab, 0, KINDS.size() - 1)]:
			continue
		var price := int(item["price"])
		var row := {"id": str(item["id"]), "price": UiStyle.cost(price, "amber"), "price_ok": amber >= price, "disabled": "",
				"buttons": [[&"buy", "Deal"]]}
		match str(item["kind"]):
			"gun":
				var gid: StringName = item["gun"]
				var fin: Dictionary = AmberRules.FINISHES[gid]
				row["name"] = str(fin["name"])
				row["icon"] = gid
				row["desc"] = "%s\n%s finished by Lucky: keeps its level and mods." % [fin["desc"], Gun.weapon(gid).display_name]
				if player != null and player.gun.owns(gid) and AmberRules.is_lucky(player.gun.code_of(gid)):
					row["disabled"] = "You carry it."
				elif player != null and not player.gun.owns(gid) and player.gun.owned.size() >= Gun.MAX_WEAPONS:
					row["disabled"] = "Your three weapon slots are full. Drop one first (Q)."
			"look":
				row["name"] = str(item["name"])
				row["icon"] = AmberRules.ITEM
				row["desc"] = str(item["desc"])
				if Perks.owns_look(str(item["slot"]), str(item["option"])):
					row["disabled"] = "In your wardrobe."
			"favour":
				var fav: Dictionary = AmberRules.FAVOURS[item["favour"]]
				row["name"] = str(fav["name"])
				row["icon"] = &"hammer" if item["favour"] == &"bounty" else &"house"
				row["desc"] = "%s\nOne night: paid at the next dawn after a wave is held." % fav["desc"]
				var why := Amber.sale_block(me, item) if multiplayer.is_server() else ""
				if why != "":
					row["disabled"] = why
			"blueprint":
				var tid: StringName = item["turret"]
				var d := Defs.turret(tid)
				row["name"] = AmberRules.BLUEPRINTS[tid]
				row["icon"] = IconStudio.turret(MenuScreen.instance, tid, Palette.team_color(_cliff())) if MenuScreen.instance != null else AmberRules.ITEM
				row["desc"] = "%s\n%s\nCraft at your Workshop: %d amber plus parts. The team fields one." % [d.description, d.stat_line(), AmberRules.amber_cost(tid)]
				if Amber.is_unlocked(tid):
					row["disabled"] = "The team has this blueprint."
		out.append(row)
	return out


func menu_press(id: Variant, _action: StringName) -> void:
	var sid := str(id)
	if AmberRules.stock_item(sid).is_empty():
		return
	if multiplayer.is_server():
		Amber.buy(multiplayer.get_unique_id(), sid)
	else:
		_request_buy.rpc_id(1, sid)
	Audio.play_at(&"register", global_position, -2.0)


@rpc("any_peer", "reliable")
func _request_buy(sid: String) -> void:
	if multiplayer.is_server():
		Amber.buy(multiplayer.get_remote_sender_id(), sid)


# ------------------------------------------------------------------ the booth

## Lucky's booth. Local: customers stand on -Z; Lucky between the counter and
## the curtain at +Z.
static func stall_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6612
	var st := MeshKit.begin()
	var lacquer := Color("#2A1A1C")
	var velvet := Color("#5A1E4A")
	var gold := Color("#E8B84A")
	# Counter: black lacquer with gold edging, a felt top.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 0.55, -0.6)), Vector3(2.8, 1.1, 0.5), lacquer, 0.01, rng)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.11, -0.6)), Vector3(2.86, 0.04, 0.56), Color("#1E4A30"))
	for y: float in [0.06, 1.08]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, y, -0.86)), Vector3(2.86, 0.05, 0.02), gold)
	for x: float in [-1.0, 0.0, 1.0]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 0.58, -0.865)), Vector3(0.5, 0.7, 0.01), lacquer.lightened(0.08))
		MeshKit.add_cylinder(st, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.58, -0.87)), 0.08, 0.08, 0.01, 10, gold)
	# Back wall hung with a velvet curtain in folds, side walls, a sloping roof with a fringe.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 1.4, 0.72)), Vector3(3.0, 2.8, 0.1), lacquer, 0.02, rng)
	for i in 12:
		var x := -1.35 + i * 0.245
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(x, 1.35, 0.62)), 0.075, 0.09, 2.5, 6, velvet.darkened(0.15 * (i % 2)))
	for x: float in [-1.45, 1.45]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 1.4, 0.0)), Vector3(0.12, 2.8, 1.5), lacquer, 0.02, rng)
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 1.4, -0.76)), Vector3(0.14, 2.8, 0.04), gold)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 2.95, -0.05)), Vector3(3.3, 0.1, 2.0), velvet.darkened(0.3), 0.02, rng)
	# The name board on the roof's front edge (the lettering is a Label3D).
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 3.3, -1.08)), Vector3(2.3, 0.5, 0.06), lacquer)
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(0, 3.3, -1.075)), Vector3(2.38, 0.56, 0.04), gold)
	for x: float in [-0.9, 0.9]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(x, 3.0, -1.0)), Vector3(0.05, 0.3, 0.05), gold.darkened(0.2))
	for i in 16:
		var x := -1.55 + i * 0.207
		MeshKit.add_cylinder(st, Transform3D(Basis(), Vector3(x, 2.66, -1.02)), 0.02, 0.035, 0.22, 5, gold)
	# A glass display case on the counter: amber chunks on velvet, an engraved revolver.
	var case_c := Vector3(-0.7, 1.28, -0.6)
	MeshKit.add_box(st, Transform3D(Basis(), case_c + Vector3(0, -0.13, 0)), Vector3(0.9, 0.04, 0.4), velvet)
	for i in 4:
		var p := case_c + Vector3(-0.3 + i * 0.18, -0.07, rng.randf_range(-0.08, 0.08))
		MeshKit.add_ellipsoid(st, Transform3D(Basis(Vector3(rng.randf(), 1, rng.randf()).normalized(), rng.randf() * TAU), p), Vector3(0.06, 0.05, 0.05), 5, 8, AmberRules.COLOR.lerp(AmberRules.DEEP, rng.randf() * 0.4), 0.15, rng, 0.75)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.4), case_c + Vector3(0.28, -0.09, 0.02)), Vector3(0.24, 0.03, 0.06), gold.darkened(0.1))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.4), case_c + Vector3(0.35, -0.09, 0.08)), Vector3(0.05, 0.03, 0.1), Palette.BONE)
	for x: float in [-0.45, 0.45]:
		for z: float in [-0.2, 0.2]:
			MeshKit.add_box(st, Transform3D(Basis(), case_c + Vector3(x, 0.03, z)), Vector3(0.02, 0.3, 0.02), gold)
	MeshKit.add_box(st, Transform3D(Basis(), case_c + Vector3(0, 0.18, 0)), Vector3(0.92, 0.02, 0.42), gold.darkened(0.1))
	# Cards fanned and a pair of dice by the till.
	for i in 5:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, -0.5 + i * 0.22), Vector3(0.5 + i * 0.04, 1.14, -0.62)), Vector3(0.06, 0.004, 0.09), Palette.BONE if i != 2 else Color("#C8362B"))
	for i in 2:
		MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.6 * i), Vector3(0.95 + i * 0.1, 1.16, -0.5)), Vector3(0.05, 0.05, 0.05), Palette.BONE)
	# A brass till.
	MeshKit.add_box(st, Transform3D(Basis(), Vector3(1.1, 1.24, -0.62)), Vector3(0.3, 0.22, 0.24), gold.darkened(0.15))
	# Shelves on the back wall: jars of amber, a rack of irons, a strongbox with the railroad's brand.
	for y: float in [1.55, 2.05]:
		MeshKit.add_box(st, Transform3D(Basis(), Vector3(-0.55, y, 0.55)), Vector3(1.1, 0.04, 0.22), lacquer.lightened(0.1))
		for k in 4:
			var p := Vector3(-0.95 + k * 0.26, y + 0.12, 0.55)
			MeshKit.add_cylinder(st, Transform3D(Basis(), p + Vector3(0, -0.02, 0)), 0.065, 0.065, 0.16, 10, AmberRules.COLOR.lerp(AmberRules.DEEP, 0.2 * (k % 2)), true, 0.45)
			MeshKit.add_cylinder(st, Transform3D(Basis(), p + Vector3(0, 0.11, 0)), 0.072, 0.072, 0.025, 10, gold)
	for i in 3:
		var x := 0.6 + i * 0.28
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.12), Vector3(x, 1.85, 0.6)), Vector3(0.06, 1.1, 0.05), gold.darkened(0.25))
		MeshKit.add_box(st, Transform3D(Basis(Vector3.BACK, 0.12), Vector3(x - 0.05, 1.4, 0.6)), Vector3(0.09, 0.4, 0.06), AmberRules.DEEP)
	var box := Vector3(-1.05, 0.25, 0.25)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.3), box), Vector3(0.6, 0.45, 0.42), Palette.METAL.darkened(0.3), 0.01, rng)
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.3), box + Vector3(0, 0.15, 0)), Vector3(0.62, 0.05, 0.44), gold.darkened(0.2))
	MeshKit.add_box(st, Transform3D(Basis(Vector3.UP, 0.3), box + Vector3(0.05, 0.0, -0.22)), Vector3(0.24, 0.12, 0.01), Palette.BONE.darkened(0.2))
	# The lantern: amber glass in a gold frame, hung from the roof at the front.
	var lamp := Vector3(1.15, 2.3, -0.75)
	MeshKit.add_limb(st, lamp + Vector3(0, 0.3, 0), lamp + Vector3(0, 0.12, 0), 0.01, gold, 4)
	MeshKit.add_box(st, Transform3D(Basis(), lamp), Vector3(0.18, 0.24, 0.18), AmberRules.GLOW, 0.0, null, 1.0)
	MeshKit.add_box(st, Transform3D(Basis(), lamp + Vector3(0, 0.13, 0)), Vector3(0.22, 0.03, 0.22), gold)
	MeshKit.add_box(st, Transform3D(Basis(), lamp + Vector3(0, -0.13, 0)), Vector3(0.22, 0.03, 0.22), gold)
	return MeshKit.finish(st)
