class_name TutorialPlan
extends RefCounted
## The tutorial as pure data and rules (TutorialRun plays it): the steps and
## their cards, the scripted first wave (six slow Dust Mites on your partner's
## wall in two small pulses, through WaveDirector), and the small rules worth
## unit-testing on their own (the look step's timing, voice gating's line
## length, what the house step costs). No autoloads, so the tests can load it.

## A Dust Mite at 60% speed with the same look and name (Defs.bug "@slow").
const SLOW_MITE := &"dust_mite@slow"

enum Step { PAPER, MOVE, SHOOT, GUNS, PELL, IDEA, BUILD, SELL, TURRETS, LEVER, WAVE, WEATHER, FARM, GRAPPLE,
	AIRSHIP, ECONOMY, UPGRADES, SALVAGE, HOUSE, WORKSHOP, DONE }

## A "look at it" step: the marker held near the middle of the screen this long
## (looking away starts it over), and never before the card has been up LOOK_MIN s.
const DWELL := 1.5
const LOOK_MIN := 5.0
## A reading card takes Continue once it has been up this long.
const READ_MIN := 2.0
## Voice gating: a step never moves on before its line has been said. Each
## step's line is its card text ("line" overrides it) spoken by "voice" (a
## StoryChapter speaker id; VOICE when unset). A recorded line
## (VoiceLines.length_of) holds the step for its length; until the tutorial is
## voiced, a reading-time stand-in does (LINE_BASE + LINE_PER_WORD a word).
## A step with "voice": "" is read silently (no line, no hold).
const VOICE := "stroud"
const LINE_BASE := 1.5
const LINE_PER_WORD := 0.2
## The house step: the upgrades to buy (Homestead.UPGRADES ids), in the order
## the ledger allows them.
const HOUSE_UPGRADES: Array[StringName] = [&"board", &"reinforce", &"porch", &"floor2", &"floor3", &"tower"]
## The three parts the Workshop step hands out: one mount, one barrel, one load
## (CraftTable), which make one design.
const PARTS: Array[StringName] = [&"part_swivel", &"part_scatter", &"part_fire"]

## Per step: card title and body (short), the sub-tasks ticked off one by one,
## the keys shown ([action, words]; "accept" is Enter / pad A), the marker's
## caption, and whether it's a "look at it" step ("look") or a reading card
## ("read": no tasks, Continue carries on; "paper": shown as the Gazette's
## front page, TutorialGazette, instead of a card). Optional "voice" / "line"
## name the step's voice line (see VOICE).
const STEPS: Array[Dictionary] = [
	{"title": "The Territorial Gazette", "body": "The railroad's Dry Gulch Reclamation Charter: free title to homesteaders who hold the canyon rims.",
		"voice": "", "line": "",
		"tasks": [], "keys": [], "read": true, "paper": true},
	{"title": "Find Your Feet", "voice": "stroud", "line": "Morning, ranchers. Captain Ada Stroud, up on the Lucky Mandible. That's your homestead on the West Cliff. Stretch your legs and have a look round.",
		"body": "This is your homestead on the West Cliff. Walk about and have a look round.",
		"tasks": ["Walk a Few Steps", "Look Around"], "keys": [["move", "Move"], ["jump", "Jump"], ["sprint", "Sprint"]]},
	{"title": "Shoot the Dust Mites", "voice": "stroud", "line": "See those bugs on the far wall? Practice. Step up to your edge and pop them.",
		"body": "Practice bugs are climbing the far wall across the canyon. Step up to your edge and pop them.",
		"tasks": ["Dust Mites Shot"], "keys": [["fire", "Shoot"], ["reload", "Reload"]], "marker": "Dust Mite"},
	{"title": "Pick Your Iron", "voice": "kettle", "line": "Silas Kettle, gunsmith. That revolver's six honest shots. I sell rifles that punch through a shell, shotguns for close work, and a few odd ones that do tricks. You can carry three.",
		"body": "Every rancher starts with the Revolver: six true shots. The gunsmith sells more. Rifles hit hard and far, through armour; shotguns shred up close; odd ones do tricks, like rock salt that knocks climbers down or a flare every turret shoots at. You carry three.",
		"tasks": [], "keys": [["select_1", "Your Guns (1 to 3)"], ["accept", "Continue"]], "read": true},
	{"title": "Pell's Toes", "voice": "stroud", "line": "Now, the law. No barrel dips more than thirty degrees below the horizon. In seventy-one Governor Pell fired down from the rim at a rattlesnake and shot off three of his own toes. If a Governor can't shoot downhill safely, no man can. Pell's Toes, folks call it.",
		"body": "Territorial law: no barrel dips more than thirty degrees below the horizon. In 1871 Governor Horace Pell fired down from the rim at a rattlesnake and shot off three of his own toes. \"If a Governor can't shoot downhill safely, no man can.\" Folks call it Pell's Toes.",
		"tasks": [], "keys": [["accept", "Continue"]], "read": true},
	{"title": "Across the Canyon", "voice": "stroud", "line": "Which leaves you in a fix. Your turrets can't touch your own wall, so they shoot across the canyon and cover your partner's. Your partner's guns cover you. Your life and your living are in their hands, and theirs in yours.",
		"body": "Which leaves you in a fix. Turrets on your lip can't reach your own wall, so they shoot across the canyon: the green patch is the wall one would cover. Your partner's guns cover yours. Your life and your living are in their hands, and theirs in yours.",
		"tasks": ["Look at the Covered Wall"], "keys": [], "marker": "Covered Wall", "look": true},
	{"title": "Build a Gatling Post", "voice": "stroud", "line": "Open the build menu, pick a Gatling Post and set it on the marked lip. It's paid from the scrap pot you share.",
		"body": "Open the build menu, pick the Gatling Post and place it on the marked lip. Turrets cost scrap from the team pot you share with your partner.",
		"tasks": ["Open the Build Menu", "Pick the Gatling Post", "Place It on Your Lip"],
		"keys": [["build_menu", "Build Menu"], ["fire", "Place"], ["alt_fire", "Cancel"]], "marker": "Your Lip"},
	{"title": "Sell It and Build Again", "voice": "stroud", "line": "Changed your mind? Sell it back for half the scrap. Then put it up again.",
		"body": "Changed your mind? Aim at a build and sell it for half its scrap back, then put it up again.",
		"tasks": ["Sell the Gatling Post", "Place It Again"], "keys": [["demolish", "Sell"], ["build_menu", "Build Menu"]], "marker": "Gatling Post"},
	{"title": "Kinds of Turret", "voice": "stroud", "line": "Turrets come in kinds. Gatlings for swarms. Rifle nests for the big, armoured brutes. Mortars for crowds. Water knocks them off the wall, lassos pin them, and Duck Guns and flak take the fliers. Better turrets come at wave five and wave ten, and Y steps one up a tier.",
		"body": "Gatlings spray small bugs. Rifle nests land one heavy shot on big, armoured ones. Mortars splash crowds. Water cannons knock climbers off; lassos and bolas pin them. Duck Guns and flak shoot fliers. Mid turrets unlock at wave 5, Late at wave 10.",
		"tasks": [], "keys": [["upgrade", "Upgrade a Turret"], ["tier_up", "Step It Up a Tier"], ["accept", "Continue"]], "marker": "Gatling Post", "read": true},
	{"title": "Throw Your Lever", "voice": "stroud", "line": "That breaker on your generator is how you say you're ready. Every lever thrown, the engines start, the pump fills your tower, and the wave comes.",
		"body": "The breaker on your generator is how you ready up. Once every lever is thrown the engines start, the pump fills your water tower and the wave comes.",
		"tasks": ["Throw the Lever"], "keys": [["interact", "Throw Lever"]], "marker": "Generator"},
	{"title": "Hold the Wave", "voice": "stroud", "line": "Here they come. Slow ones. Your Gatling has them covered, so lend it a hand.",
		"body": "A few slow Dust Mites climb the far wall: your Gatling Post has it covered, so help it out. While the engine runs, the pump fills your tower.",
		"tasks": ["Wave Held"], "keys": [["fire", "Shoot"]], "marker": "Dust Mite"},
	{"title": "Weather", "voice": "stroud", "line": "Every wave brings its own sky. Rain feeds the crops. Heat slows your turrets. Wind spoils your aim. Fog and dust blind the guns, so hang a lantern. Lightning wrecks turrets. Snow kills crops, but it slows the bugs too.",
		"body": "Each wave brings its own sky. Rain waters crops and grows them faster. Heat slows turrets and dries crops. Wind throws shots off. Fog and dust storms cut how far turrets see (lanterns help). Lightning can wreck a turret; snow kills crops but slows bugs.",
		"tasks": [], "keys": [["accept", "Continue"]], "read": true},
	{"title": "Plant a Crop", "voice": "stroud", "line": "Now, supper. Fill your bucket at the well, plant that corn, water it, and pick it. I've hurried it along for you, just this once.",
		"body": "Plots grow food. Plant a seed, water it from your bucket and it grows (fast, just this once), then harvest it. The well trough and the water tower tap fill the bucket.",
		"tasks": ["Fill Your Bucket", "Plant the Corn", "Water the Seedling", "Harvest the Corn"],
		"keys": [["select_8", "Bucket"], ["interact", "Fill, Plant, Water, Pick"], ["cycle_option", "Change Seed"]], "marker": "Well"},
	{"title": "The Grappling Hook", "voice": "stroud", "line": "Your grapple. Right click hooks on and swings you. Left click reels you in, and holding it on a swing climbs the rope. There's a toggle in your settings if your finger tires, and Silas sells dynamite for it.",
		"body": "Aim at anything solid. Right click hooks on and swings you; let go to drop. Left click hooks and reels you in, or hold it on a swing to climb the rope. Settings > Controls can make right click a toggle. The gunsmith sells dynamite for it.",
		"tasks": ["Take Out the Grapple", "Swing (Right Click)", "Reel In (Left Click)"],
		"keys": [["select_10", "Grapple"], ["alt_fire", "Swing"], ["fire", "Reel In"], ["jump", "Let Go"]], "marker": "Water Tower"},
	{"title": "The Lucky Mandible", "voice": "pearl", "line": "Pearl Doyle, casino deck. Up here there's a market, Silas's gun counter, and my tables, if you're feeling lucky. Climb an arch and grapple the ring under the stern. This once, the Captain's sending a lift. Now go sell that corn.",
		"body": "The airship over the canyon holds the market, the gunsmith and a casino (slots, cards, the prize wheel). To board, climb an arch and grapple the ring under its stern: it hauls you up. This once, Enter takes you. Then sell your corn.",
		"tasks": ["Go Aboard", "Sell Your Corn at the Market"], "keys": [["accept", "Take Me Aboard"], ["cycle_option", "Pick"], ["interact", "Sell"]], "marker": "Market"},
	{"title": "Scrap and Chitin", "voice": "stroud", "line": "Scrap's the team pot. Every dead bug pays some, and so do the bounty for each night held, the scrap heap and any crops you sell. It buys turrets, seed and timber. Chitin's yours alone. The bigger bugs carry it, shells drop where bugs die on your rim, and chilies fetch it at market. Silas takes it for guns.",
		"body": "Scrap is the team pot: every bug killed, the bounty for each wave held, the scrap heap and crops sold. It buys turrets, seeds and the house. Chitin is yours: bigger bugs carry it, shells drop where bugs die on your plateau, and chilies sell for it. It buys guns and upgrades.",
		"tasks": [], "keys": [["accept", "Continue"]], "marker": "Market", "read": true},
	{"title": "Gun Upgrades", "voice": "kettle", "line": "Bring me a gun and some chitin. Two levels, each one harder hitting and quicker to load. Then three jobs per gun that change how she handles. A hair trigger, a longer barrel. The work stays with the gun.",
		"body": "The gunsmith works on any gun you own, for chitin: two levels, each +25% damage and quicker reloads, then three one-off mods per gun that change how it handles, like a hair trigger or a longer barrel. Upgrades stay with the gun.",
		"tasks": [], "keys": [["cycle_option", "Pick"], ["interact", "Buy"], ["accept", "Continue"]], "marker": "Gunsmith", "read": true},
	{"title": "The Scrap Heap", "voice": "stroud", "line": "Back home. That heap of junk by your house is free scrap for the team pot, and it piles up again every morning. Pick it over each day, before the coyotes do.",
		"body": "Back home. The junk heap by your house is free scrap for the team pot. Salvage it, and check it every morning: it fills up again each day.",
		"tasks": ["Salvage the Scrap Heap"], "keys": [["interact", "Salvage"]], "marker": "Scrap Heap"},
	{"title": "Upgrade the House", "voice": "stroud", "line": "Now the house. The ledger inside sells upgrades. The railroad's paying this once, so buy the lot. Upper floors mean more turret mounts, and the lookout lets your guns see further.",
		"body": "The ledger in your house sells upgrades for scrap and chitin; this once the tutorial pays. Buy the lot: upper floors add house turret mounts, the lookout adds range.",
		"tasks": ["Board Up the Windows", "Reinforce the Walls", "Build the Shaded Porch", "Build the Second Floor", "Build the Lookout Floor", "Build the Zip-Line Tower"],
		"keys": [["interact", "Open the Ledger"]], "marker": "House Ledger"},
	{"title": "Craft a Turret", "voice": "kettle", "line": "Buy a workshop and I'll show you a trick. A mount, a barrel and a load make a turret nobody's built before. Parts come off tough bugs, and out of whatever the canyon hides. Here's three to start.",
		"body": "Buy the Workshop at the ledger. Its bench joins three parts, a mount, a barrel and a load, into a turret of your own design. Parts come from tough bugs and from what the canyon hides. Here are three to try.",
		"tasks": ["Build the Workshop", "Craft a Turret at the Bench", "Place It (Crafted Tab)"],
		"keys": [["interact", "Ledger / Bench"], ["build_menu", "Build Menu"], ["fire", "Place"]], "marker": "House Ledger"},
]


## The plan WaveDirector runs for the tutorial's first wave; `partner` is the
## cliff the mites climb (the one your turrets cover).
static func wave(partner: int) -> Dictionary:
	var shares: Array = []
	for cid in 2:
		shares.append(1.0 if cid == partner else 0.0)
	return {"groups": [
				{"bug": SLOW_MITE, "count": 3, "cliff": partner, "lane": 2, "pulse": 0},
				{"bug": SLOW_MITE, "count": 3, "cliff": partner, "lane": 1, "pulse": 1}],
			"pulses": 2, "pulse_times": [0.0, 9.0], "shape": WavePlanner.STEADY,
			"west_share": shares[0], "shares": shares, "spent": 6}


## --tutorialstep: a number or a step's name ("house", "grapple").
static func step_from_flag(v: String) -> int:
	if v == "":
		return 0
	if v.is_valid_int():
		return clampi(int(v), 0, Step.DONE)
	var i := (Step.keys() as Array).find(v.to_upper())
	return i if i >= 0 else 0


## The look step is done: the wall held in the sights for DWELL seconds, with
## the card up at least LOOK_MIN.
static func look_done(dwell: float, on_card: float) -> bool:
	return dwell >= DWELL and on_card >= LOOK_MIN


## A step's voice line: [speaker, text].
static func line_of(def: Dictionary) -> Array:
	return [str(def.get("voice", VOICE)), str(def.get("line", def.get("body", "")))]


## Seconds a line holds its step: the recording's length when it's voiced,
## else a reading-time stand-in.
static func line_time(who: String, line: String) -> float:
	if who == "" or line == "":
		return 0.0
	var v := VoiceLines.length_of(who, line)
	if v > 0.0:
		return v + 0.3
	return LINE_BASE + line.split(" ", false).size() * LINE_PER_WORD


## The scrap and chitin for every HOUSE_UPGRADES item of `upgrades`
## (Homestead.UPGRADES) not in `owned`.
static func house_cost(upgrades: Array, owned: Array[StringName]) -> Dictionary:
	var total := {}
	for u: Dictionary in upgrades:
		if not HOUSE_UPGRADES.has(u["id"]) or owned.has(u["id"]):
			continue
		for k: StringName in u["cost"]:
			total[k] = int(total.get(k, 0)) + int(u["cost"][k])
	return total
