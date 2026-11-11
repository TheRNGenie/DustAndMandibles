class_name Hotbar
extends Node
## The local player's hotbar, keys 1-8:
##   1-3  weapon slots (Weapon Slots): 1 primary, 2 secondary, 3 heavy
##   4-6  pickup slots: whatever harvest you're carrying (sarsaparilla first, then
##        corn, prickly pear, chili); left click with sarsaparilla out sends your
##        partner a tonic (PartnerTonic)
##   7    medicine: herbs (left click with them out heals 50 HP)
##   8    water bucket
##   9    crop bag (always carried; it replaced the Zippo): hold right click to
##        pick a crop, left click a crop-fed turret within 15 m to feed it (CropBag)
##   0    grappling hook launcher (always carried)
## Mouse wheel steps through the slots that hold something (left click with the
## medicine out takes a dose). Pressing the number
## of what you're already holding puts it away (empty hands).
## Q drops what's in your hand: a weapon, or one of the crop, medicine or water
## you're holding (it lands at your feet for anyone to pick up).
## While the build tool (B) is open, number keys pick what to build instead.

signal changed

## Slots 4-6 show the first three you carry, in this order (PlayerCarry, Nov 11:
## the crops you carry, not the cliff's stock; the HUD's strip shows them all).
const PICKUP_ITEMS: Array[StringName] = [&"sarsaparilla", &"corn", &"prickly_pear", &"chili", &"cotton", &"sulfur_root",
	&"barrel_cactus", &"tumbleweed_vine"]
const NAMES: Dictionary = {&"sarsaparilla": "Tonic", &"corn": "Corn", &"prickly_pear": "Pear", &"chili": "Chili", &"herbs": "Medicine", &"water": "Bucket", &"grapple": "Grapple", &"crop_bag": "Crop Bag",
	&"cotton": "Cotton", &"sulfur_root": "Sulfur", &"barrel_cactus": "Cactus", &"tumbleweed_vine": "Tumbleweed"}

const SLOTS := 10

var player: Player
var selected := 0


func _ready() -> void:
	player.gun.loadout_changed.connect(func() -> void: changed.emit())
	if player.carry != null:
		player.carry.changed.connect(func() -> void: changed.emit())
	Economy.resources_changed.connect(func(_c: int) -> void: changed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if GameState.menu_open or player.is_downed():
		return
	if event.is_action_pressed("drop_item"):
		_drop()
		get_viewport().set_input_as_handled()
		return
	if player.build_mode.active:
		return
	if event.is_action_pressed("fire") and player.gun.holding == &"herbs":
		player.vitals.use_medicine()
	elif event.is_action_pressed("fire") and player.gun.holding == PartnerTonic.ITEM:
		player.net.request_tonic()
	elif event.is_action_pressed("fire") and PlayerVitals.FEEDS.has(player.gun.holding):
		player.vitals.eat_or_drink(player.gun.holding)
	if event.is_action_pressed("next_item") or event.is_action_pressed("prev_item"):
		_scroll(1 if event.is_action_pressed("next_item") else -1)
		get_viewport().set_input_as_handled()
		return
	for i in SLOTS:
		if event.is_action_pressed("select_%d" % (i + 1)):
			use_slot(i)
			get_viewport().set_input_as_handled()
			return


## Tutorial (Logan): gear you haven't picked up yet (crop bag, grapple, water =
## the bucket, herbs): its slot stays empty until TutorialRun unlocks it.
static var locked: Dictionary = {}


## The item id in slot i ("" when empty).
func slot_item(i: int) -> StringName:
	var id := _slot_raw(i)
	return &"" if locked.has(id) else id


func _slot_raw(i: int) -> StringName:
	if i < 3:
		return player.gun.slots[i]
	if i < 6:
		var carried: Array[StringName] = []
		for item in PICKUP_ITEMS:
			if _carried(item) > 0:
				carried.append(item)
		return carried[i - 3] if i - 3 < carried.size() else &""
	if i == 8:
		return CropBagUI.ITEM
	if i == 9:
		return &"grapple"
	return &"herbs" if i == 6 else &"water"


## The next slot (either way) that holds something, wrapping round.
func _scroll(step: int) -> void:
	var start := selected if selected >= 0 else (0 if step > 0 else SLOTS - 1)
	for k in range(1, SLOTS + 1):
		var i := posmod(start + step * k, SLOTS)
		if slot_item(i) != &"":
			use_slot(i, false)
			return


func use_slot(i: int, toggle: bool = true) -> void:
	var id := slot_item(i)
	if id == &"":
		return
	# Pressing the slot you're already holding puts it away.
	if toggle and bool(slot_info(i)["selected"]):
		player.gun.hold_item(&"none")
		selected = -1
		changed.emit()
		return
	if i < 3:
		player.gun.equip(id)
	else:
		player.gun.hold_item(id)
		if i < 6:
			player.gun.heavy_pick = HeavyRules.crop_of_item(id) # a crop picked on 4-6: R on the heavy loads its sack
		if id == PartnerTonic.ITEM:
			Economy.notice.emit("Left Click: send your partner a sarsaparilla tonic (their turrets fire %d%% faster)." % int(round(PartnerTonic.FIRE_RATE_BONUS * 100.0)))
	selected = i
	changed.emit()


func _drop() -> void:
	var gun := player.gun
	var held := gun.holding
	if held == &"none" or (held == &"" and gun.def == null):
		Economy.notice.emit("Your hands are empty.")
		return
	if held == &"grapple" or held == CropBagUI.ITEM:
		Economy.notice.emit("You always keep the %s." % NAMES[held].to_lower())
		return
	if held == &"":
		player.net.drop_weapon(gun.def.id)
	else:
		player.net.drop_item(held)
	changed.emit()


func _cliff() -> int:
	return player.cliff_id


## How many of food item `item` you carry (PlayerCarry); the cliff's stock for anything else.
func _carried(item: StringName) -> int:
	var c := PlayerCarry.crop_of_item(item)
	if c != &"" and player.carry != null:
		return player.carry.amount(c)
	return Economy.amount(_cliff(), item)


## Hotbar labels where the gun's first word won't do.
const SHORT_NAMES: Dictionary = {&"coach_shotgun": "Shotgun", &"salt_shotgun": "Salt Gun", &"bee_smoker": "Smoker",
	&"flare_gun": "Flare Gun", &"punt_gun": "Punt Gun", &"derringer_pair": "Derringers", &"harpoon_pistol": "Harpoon",
	&"telescope_rifle": "Telescope",
	&"volcanic_repeater": "Repeater", &"mares_leg": "Mare's Leg", &"double_rifle": "Double", &"trench_broom": "Broom",
	&"ricochet_rifle": "Ricochet", &"howdah_pistol": "Howdah", &"sharps_carbine": "Sharps", &"trapdoor_springfield": "Trapdoor",
	&"screamer_pistol": "Screamer", &"tar_sprayer": "Tar", &"flashbang_pistol": "Flashbang", &"pepper_bomb_pistol": "Pepper",
	&"concussion_pistol": "Concussion", &"chain_binder": "Chain", &"rust_duster": "Duster", &"glow_worm_launcher": "Glow-Worm",
	&"caltrops_launcher": "Caltrops", &"phosphor_grenade": "Phosphor", 
	&"swivel_gun": "Swivel",
	# Universal crop-loaded heavies.
	&"crop_mortar": "Mortar", &"hand_cannon": "Cannon", &"crop_sprayer": "Sprayer", &"spike_driver": "Spikes",
	&"drum_launcher": "Drum", &"harvest_gatling": "Gatling", &"crop_crossbow": "Crossbow", &"bola_launcher": "Bolas",
	&"powder_keg_launcher": "Kegs", &"crop_blunderbuss": "Bell"}


## For the HUD: item id, label, count text, selected?
func slot_info(i: int) -> Dictionary:
	var id := slot_item(i)
	var info := {"id": id, "label": "", "count": "", "selected": false}
	if id == &"":
		return info
	if i < 3:
		info["label"] = SHORT_NAMES.get(id, Gun.weapon(id).display_name.split(" ")[0])
		info["selected"] = player.gun.holding == &"" and player.gun.def != null and player.gun.def.id == id
		var lvl := player.gun.level_of(id)
		var mods := WeaponMods.count(player.gun.code_of(id))
		info["count"] = (GunRarity.name_of(lvl)[0] if lvl > 0 else "") + "*".repeat(mods) # Rarity: U, R, E, L
		var spare := player.gun.reserve_of(id)
		if spare >= 0:
			info["count"] += " +%d" % spare # Weapon Slots: heavies' crop-loaded rounds in reserve
		info["rarity"] = lvl
		if AmberRules.is_lucky(player.gun.code_of(id)): # Hive amber: Lucky Moreau's finish
			info["label"] = AmberRules.finish_name(id, player.gun.code_of(id)).split(" ")[0]
			info["count"] += "$"
	else:
		info["label"] = NAMES.get(id, String(id))
		info["count"] = "" if id == &"grapple" else "x%d" % _carried(id)
		if PlayerCarry.crop_of_item(id) != &"" and player.carry != null:
			info["count"] = "%d/%d" % [_carried(id), PlayerCarry.CAP] # (carried crops: "12/25")
		if id == CropBagUI.ITEM: # the set crop's cellar sacks ("" when nothing is set)
			var bag := player.crop_bag
			info["count"] = "x%d" % bag.sacks_of(bag.set_crop) if bag != null and bag.set_crop != &"" else ""
		if id == &"grapple" and player.dynamite != null and player.dynamite.unlocked():
			info["count"] = "x%d" % player.dynamite.bundles # the dynamite bundles in your satchel
		info["selected"] = player.gun.holding == id
	return info
