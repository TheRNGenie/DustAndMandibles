class_name CropBench
extends Node3D
## The Workshop's "Special Weapon" tab (special weapons handoff; Logan: the one
## workbench, a new section in its menu): fits your special weapon (slot 2) with
## one permanent crop upgrade for one sack of that crop from your cliff's stores,
## or takes it off for free. The crop lives in the gun's code (SpecialCrop), so it
## stays through drops, pickups and saves. A child of the Workshop: three crop
## jars on its bench that glow as a crop goes on. Only your own cliff's works.

var home: Homestead
var workshop: Workshop
var _glow: OmniLight3D
var _jar_mats: Array[StandardMaterial3D] = []
var _tween: Tween
## This rider has fitted a crop here at least once (hides the HUD's workbench hint).
static var used_once := false


func _ready() -> void:
	_add_jars()
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, 0.35, 0)
	_glow.omni_range = 2.6
	_glow.light_energy = 0.0
	add_child(_glow)


## Three glass crop jars at the back of the bench; they glow with the crop being fitted.
func _add_jars() -> void:
	var cols: Array[Color] = [SpecialCrop.COLORS[&"corn"], SpecialCrop.COLORS[&"herbs"], SpecialCrop.COLORS[&"firecracker_chili"]]
	for i in 3:
		var jar := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.065
		m.bottom_radius = 0.07
		m.height = 0.2
		m.radial_segments = 10
		jar.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cols[i].darkened(0.15)
		mat.emission_enabled = true
		mat.emission = cols[i]
		mat.emission_energy_multiplier = 0.15
		mat.roughness = 0.2
		jar.material_override = mat
		jar.position = Vector3(-0.2 + i * 0.2, 0.1, 0.0)
		add_child(jar)
		_jar_mats.append(mat)
		var lid := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.06
		lm.bottom_radius = 0.06
		lm.height = 0.03
		lid.mesh = lm
		lid.material_override = Materials.toon_house(0.02)
		lid.position = jar.position + Vector3(0, 0.115, 0)
		add_child(lid)


func _cliff() -> int:
	return Economy.payer_cliff(multiplayer.get_unique_id(), home.cliff_id if home != null else 0)


func _local_gun() -> Gun:
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == multiplayer.get_unique_id():
			return (n as Player).gun
	return null


static func crop_icon(crop: StringName) -> Variant:
	var path := "res://assets/icons/%s.png" % CropEffects.sack_of(crop)
	return load(path) if ResourceLoader.exists(path) else &"seed"


## The tab's rows (Workshop.menu_items). Ids: "crop:<crop>", "crop:remove".
func menu_items() -> Array:
	var cid := _cliff()
	var gun := _local_gun()
	var id := SpecialRules.held_in(gun.owned) if gun != null else &""
	var out: Array = []
	if id == &"":
		out.append({"id": "", "name": "No Special Weapon", "icon": &"hammer",
				"desc": "Buy a special weapon at the gunsmith (slot 2), then bring it here.",
				"price": "", "price_ok": true, "disabled": "Nothing to fit.", "buttons": []})
		return out
	var w := Gun.weapon(id)
	var code := gun.code_of(id)
	var now := SpecialCrop.crop_of(code)
	var k := SpecialRules.crop_k(id, code)
	out.append({"id": "", "name": w.display_name.to_upper(), "icon": crop_icon(now) if now != &"" else &"hammer",
			"desc": "Current: %s\nBase Effect: %s. %s" % [SpecialCrop.preview(now, k) if now != &"" else "No Crop - Plain",
				SpecialRules.base_name(id), SpecialRules.base_text(id)],
			"price": "", "price_ok": true, "disabled": "", "buttons": []})
	out.append({"id": "crop:remove", "name": "Remove Crop", "icon": &"hammer",
			"desc": "Back to plain shots. The base effect stays.", "price": "Free", "price_ok": true,
			"disabled": "" if now != &"" else "No crop fitted.", "buttons": [[&"remove", "Remove"]]})
	for crop: StringName in CropEffects.IDS:
		var sack := CropEffects.sack_of(crop)
		var n := Economy.amount(cid, sack) if sack != &"" else 0
		var why := ""
		if crop == now:
			why = "Already fitted."
		elif n <= 0:
			why = "No %s sacks. Harvest some first." % CropEffects.short_name(crop)
		out.append({"id": "crop:" + String(crop), "name": "%s - %s" % [CropEffects.short_name(crop), CropEffects.effect_name(crop)],
				"icon": crop_icon(crop), "desc": SpecialCrop.preview(crop, k), "price": "1 Sack", "price_ok": n > 0,
				"note": UiStyle.held(n), "disabled": why, "buttons": [[&"apply", "Apply"]]})
	return out


static func handles(id: Variant) -> bool:
	return str(id).begins_with("crop:")


func menu_press(id: Variant, action: StringName) -> void:
	var crop := &"" if action == &"remove" else StringName(str(id).trim_prefix("crop:"))
	if crop != &"" and not CropEffects.is_crop(crop):
		return
	if multiplayer.is_server():
		_fit(multiplayer.get_unique_id(), crop)
	else:
		_request_fit.rpc_id(1, String(crop))


@rpc("any_peer", "reliable")
func _request_fit(crop: String) -> void:
	if multiplayer.is_server():
		_fit(multiplayer.get_remote_sender_id(), StringName(crop))


## Host: fit `crop` (&"" = take it off) to this rider's special weapon.
func _fit(peer_id: int, crop: StringName) -> void:
	if home == null:
		return
	if not GameState.is_solo() and NetworkManager.cliff_of(peer_id) != home.cliff_id:
		Economy.notify(peer_id, "That's your partner's workshop. Use your own.")
		return
	var owned: Dictionary = GunShop.loadouts.get(peer_id, {})
	var id := SpecialRules.held_in(owned)
	if id == &"":
		Economy.notify(peer_id, "You have no special weapon. The gunsmith sells them.")
		return
	var code := int(owned[id])
	if SpecialCrop.crop_of(code) == crop:
		return
	var w := Gun.weapon(id)
	if crop != &"":
		var cid := Economy.payer_cliff(peer_id, home.cliff_id)
		if not Economy.spend(cid, {CropEffects.sack_of(crop): 1}):
			Economy.notify(peer_id, "That takes a sack of %s." % CropEffects.short_name(crop))
			return
		Economy.notify(peer_id, "%s fitted with %s: %s" % [w.display_name, CropEffects.short_name(crop),
				SpecialCrop.effect_text(crop, SpecialRules.crop_k(id, code))])
	else:
		Economy.notify(peer_id, "%s back to plain shots." % w.display_name)
	code = SpecialCrop.with_crop(code, crop)
	owned[id] = code
	GunShop.loadouts[peer_id] = owned
	for n: Node in get_tree().get_nodes_in_group("players"):
		if n.get_multiplayer_authority() == peer_id:
			(n as Player).net.grant_weapon(id, code)
	_fitted_fx.rpc(String(crop), peer_id)


## Every peer: the bench glows the crop's colour (white for a removal), a stamp.
@rpc("authority", "call_local", "reliable")
func _fitted_fx(crop: String, peer_id: int) -> void:
	var c := StringName(crop)
	if c != &"" and peer_id == multiplayer.get_unique_id():
		used_once = true
	var col := SpecialCrop.color_of(c) if c != &"" else Color("#FFF8EC")
	Audio.play_at(&"build", global_position + Vector3.UP, -2.0, 1.3)
	if _tween != null:
		_tween.kill()
	_glow.light_color = col
	for m in _jar_mats:
		m.emission = col
	_tween = create_tween()
	_tween.tween_property(_glow, "light_energy", 2.2, 1.0)
	_tween.parallel().tween_method(_jar_glow, 0.15, 1.6, 1.0)
	_tween.tween_property(_glow, "light_energy", 0.0, 1.5)
	_tween.parallel().tween_method(_jar_glow, 1.6, 0.15, 1.5)
	if workshop != null:
		workshop.menu_changed.emit()


func _jar_glow(e: float) -> void:
	for m in _jar_mats:
		m.emission_energy_multiplier = e
