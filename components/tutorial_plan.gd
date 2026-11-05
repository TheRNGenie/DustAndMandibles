class_name TutorialPlan
extends RefCounted
## The tutorial as pure data and rules (TutorialRun plays it): the steps and
## their cards, the scripted first wave (six slow Dust Mites on your partner's
## wall in two small pulses, through WaveDirector), and the small rules worth
## unit-testing on their own (the look step's timing, voice gating's line
## length, what the house step costs). No autoloads, so the tests can load it.

## A Dust Mite at 60% speed with the same look and name (Defs.bug "@slow").
const SLOW_MITE := &"dust_mite@slow"
## The tutorial's wave: this many slow mites, in this many pulses this far apart.
const WAVE_MITES := 48
const WAVE_PULSES := 6
const WAVE_GAP := 5.0
## The farm step's starting seeds, waiting in the house chest.
const CHEST_SEEDS := {&"seed_corn": 2}
## What starts in the house chest (Logan): the bucket and three doses of medicine.
const CHEST_START := {&"bucket": 1, &"herbs": 3}
## Gear lying in the house, Homestead-local: the revolver beside the ledger,
## the zippo and grapple on the table. [kind, caption, position, yaw]
const GEAR: Array = [
	[&"revolver", "revolver", Vector3(2.95, 1.01, -1.7), 0.4],
	[&"lighter", "zippo", Vector3(-1.95, 0.85, -0.5), 0.3],
	[&"grapple", "grapple", Vector3(-1.2, 0.86, -0.65), -0.5]]


enum Step { PAPER, MOVE, SHOOT, GUNS, PELL, IDEA, BUILD, SELL, TURRETS, LEVER, WAVE, WEATHER, FARM, MEDICINE, GRAPPLE,
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
	{"title": "Find Your Feet", "voice": "stroud", "line": "Morning, ranchers. Captain Ada Stroud, up on the Lucky Mandible. That's your homestead on the West Cliff. Stretch your legs and have a look round. Give a jump, and try a slide while you're running.",
		"body": "This is your homestead on the West Cliff. Walk about, look around, jump, and slide while you run.",
		"tasks": ["Walk a Few Steps", "Look Around", "Jump", "Slide While Running"], "keys": [["move", "Move"], ["jump", "Jump"], ["sprint", "Sprint"], ["slide", "Slide"]]},
	{"title": "Shoot the Dust Mites", "voice": "stroud", "line": "See those bugs on the far wall? Practice. Fetch your revolver from beside the ledger, step up to your edge and pop them.",
		"body": "Practice bugs are climbing the far wall across the canyon. Your revolver lies beside the ledger in the house: take it, step up to your edge and pop them.",
		"tasks": ["Grab Your Revolver", "Dust Mites Shot"], "keys": [["fire", "Shoot"], ["reload", "Reload"]], "marker": "Dust Mite"},
	{"title": "Pick Your Iron", "voice": "kettle", "line": "Silas Kettle, gunsmith. That revolver's six honest shots. I sell rifles that punch through a shell, shotguns for close work, and a few odd ones that do tricks. You can carry three.",
		"body": "Every rancher starts with the Revolver: six true shots. The gunsmith sells more. Rifles hit hard and far, through armour; shotguns shred up close; odd ones do tricks, like rock salt that knocks climbers down or a flare every turret shoots at. You carry three.",
		"tasks": [], "keys": [["select_1", "Your Guns (1 to 3)"], ["accept", "Continue"]], "read": true},
	{"title": "Pell's Toes", "voice": "stroud", "line": "Now, the law. No barrel dips more than thirty degrees below the horizon. In seventy-one Governor Pell fired down from the rim at a rattlesnake and shot off three of his own toes. If a Governor can't shoot downhill safely, no man can. Pell's Toes, folks call it.",
		"body": "Territorial law: no barrel dips more than thirty degrees below the horizon. In 1871 Governor Horace Pell fired down from the rim at a rattlesnake and shot off three of his own toes. \"If a Governor can't shoot downhill safely, no man can.\" Folks call it Pell's Toes.",
		"tasks": [], "keys": [["accept", "Continue"]], "read": true},
	{"title": "Across the Canyon", "voice": "stroud", "line": "Which leaves you in a fix. Your turrets can't touch your own wall, so they shoot across the canyon and cover your partner's. Your partner's guns cover you. Your life and your living are in their hands, and theirs in yours.",
		"body": "Which leaves you in a fix. Turrets on your lip can't reach your own wall, so they shoot across the canyon: the green patch is the wall one would cover. Your partner's guns cover yours. Your life and your living are in their hands, and theirs in yours.",
		"tasks": ["Look at the Covered Wall"], "keys": [], "marker": "Covered Wall", "look": true},
	{"title": "Build a Rifle Nest", "voice": "stroud", "line": "Open the build menu, pick a Buffalo Rifle Nest and set it on the marked lip. It's paid from the scrap pot you share.",
		"body": "Open the build menu, pick the Buffalo Rifle Nest and place it on the marked lip. Turrets cost scrap from the team pot you share with your partner.",
		"tasks": ["Open the Build Menu", "Pick the Rifle Nest", "Place It on Your Lip"],
		"keys": [["build_menu", "Build Menu"], ["fire", "Place"], ["alt_fire", "Cancel"]], "marker": "Your Lip"},
	{"title": "Sell It for a Gatling", "voice": "stroud", "line": "Big shots are wasted on little bugs. Sell it back for half the scrap and put a Gatling Post up in its place.",
		"body": "Changed your mind? Aim at a build and sell it for half its scrap back. Then place a Gatling Post on your lip: it sprays small bugs.",
		"tasks": ["Sell the Rifle Nest", "Place a Gatling Post"], "keys": [["demolish", "Sell"], ["build_menu", "Build Menu"]], "marker": "Rifle Nest"},
	{"title": "Kinds of Turret", "voice": "stroud", "line": "Turrets come in kinds. Gatlings for swarms. Rifle nests for the big, armoured brutes. Mortars for crowds. Water knocks them off the wall, lassos pin them, and Duck Guns and flak take the fliers. Any turret can be upgraded, and better designs turn up as time goes on.",
		"body": "Gatlings spray small bugs. Rifle nests land one heavy shot on big, armoured ones. Mortars splash crowds. Water cannons knock climbers off; lassos and bolas pin them. Duck Guns and flak shoot fliers. Turrets can be upgraded, and better designs come along with time.",
		"tasks": [], "keys": [["upgrade", "Upgrade a Turret"], ["accept", "Continue"]], "marker": "Your Turret", "read": true},
	{"title": "Start the Pump", "voice": "stroud", "line": "Only way to get water in these parts is a deep mechanical well, and if we're getting any farming done around here, we need water. Trouble is, that pump wakes up the critters nearby whenever it's running. Throw the breaker on your generator when you're set.",
		"body": "Out here, water only comes up from deep mechanical wells, and your crops need it. Throw the breaker on your generator to start the engine and the pump. The racket wakes the bugs nearby: a wave comes while it runs.",
		"tasks": ["Throw the Lever"], "keys": [["interact", "Throw Lever"]], "marker": "Generator"},
	{"title": "Hold the Wave", "voice": "stroud", "line": "Here they come, a whole swarm of slow ones. Your Gatling has them covered, so lend it a hand.",
		"body": "A swarm of slow Dust Mites climbs the far wall: your Gatling Post has it covered, so help it out. While the engine runs, the pump fills your tower.",
		"tasks": ["Wave Held"], "keys": [["fire", "Shoot"]], "marker": "Dust Mite"},
	{"title": "Weather", "voice": "stroud", "line": "Every wave brings its own sky. Rain feeds the crops. Heat slows your turrets. Wind spoils your aim. Fog and dust blind the guns, so hang a lantern. Lightning wrecks turrets. Snow kills crops, but it slows the bugs too. Your zippo's on the table inside. Flip it open and light it; you'll want it on dark nights.",
		"body": "Each wave brings its own sky. Rain waters crops and grows them faster. Heat slows turrets and dries crops. Wind throws shots off. Fog and dust storms cut how far turrets see (lanterns help). Lightning can wreck a turret; snow kills crops but slows bugs. Take your zippo from the table and light it for the dark.",
		"tasks": ["Grab Your Zippo", "Flip It Open and Light It"], "keys": [["interact", "Take"], ["select_9", "Zippo"], ["alt_fire", "Flip Open"], ["fire", "Light"]], "marker": "Zippo"},
	{"title": "Plant a Crop", "voice": "stroud", "line": "Now, supper. Your bucket and seed corn are in the chest inside the house. Fetch them, fill your bucket at the well, plant that corn, water it, and pick it. I've hurried it along for you, just this once.",
		"body": "Plots grow food. Your bucket and seeds wait in the chest inside your house: take them, plant a seed, water it from your bucket and it grows (fast, just this once), then harvest it. The well trough and the water tower tap fill the bucket.",
		"tasks": ["Take the Bucket and Seeds from the Chest", "Fill Your Bucket", "Plant the Corn", "Water the Seedling", "Harvest the Corn"],
		"keys": [["interact", "Open Chest, Fill, Plant, Water, Pick"], ["select_8", "Bucket"], ["cycle_option", "Change Seed"]], "marker": "House Chest"},
	{"title": "Medicine", "voice": "stroud", "line": "Sage is your medicine out here, and there's three doses in your chest. Take them. Use one and it patches you up quick. Grow it from sage seed and keep a few on hand. It fetches a good price, but don't sell your last.",
		"body": "Medicine is sage, grown from sage seed. Take the three doses from your chest. With it out, left click heals 50 health. It won't help once you're down. It sells well, but keep a few for bad days.",
		"tasks": ["Take Your Medicine from the Chest"], "keys": [["interact", "Open Chest"], ["select_7", "Medicine"], ["fire", "Use It"]], "marker": "House Chest"},
	{"title": "The Grappling Hook", "voice": "stroud", "line": "Your grapple's on the table inside. Right click hooks on and swings you. Left click reels you in, and holding it on a swing climbs the rope. And I hear the gunsmith has a real good idea what to do with it.",
		"body": "Take the grapple from the table in the house. Aim at anything solid. Right click hooks on and swings you; let go to drop. Left click hooks and reels you in, or hold it on a swing to climb the rope. The gunsmith has ideas for it, too.",
		"tasks": ["Grab the Grapple", "Take Out the Grapple", "Swing (Right Click)", "Reel In (Left Click)", "Reel In While Swinging"],
		"keys": [["select_10", "Grapple"], ["alt_fire", "Swing"], ["fire", "Reel In"], ["jump", "Let Go"]], "marker": "Water Tower", "tip": "Settings > Controls > Grapple: Right-Click Swing can be Hold (swing while the button's down) or Toggle (click to hook on, click again to let go)."},
	{"title": "The Lucky Mandible", "voice": "pearl", "line": "Pearl Doyle, casino deck. Up here there's a market, Silas's gun counter, and my tables, if you're feeling lucky. And Lucky Moreau, leaning on the rail. Trades in things nobody else will touch, and he knows a sight more about this canyon than he lets on. Climb an arch and grapple the ring under the stern. This once, the Captain's sending a lift. Now go sell that corn.",
		"body": "The airship over the canyon holds the market, the gunsmith and a casino (slots, cards, the prize wheel). Lucky Moreau trades at the rail, in things nobody else sells. To board, climb an arch and grapple the ring under its stern: it hauls you up. This once, Enter takes you. Then sell your corn.",
		"tasks": ["Go Aboard", "Sell Your Corn at the Market"], "keys": [["accept", "Take Me Aboard"], ["cycle_option", "Pick"], ["interact", "Sell"]], "marker": "Market"},
	{"title": "Scrap and Chitin", "voice": "stroud", "line": "Scrap's the team pot. Every dead bug pays some, and so do the bounty for each night held, the scrap heap and any crops you sell. It buys turrets, seed and timber. Chitin's yours alone. The bigger bugs carry it, shells drop where bugs die on your rim, and chilies fetch it at market. Silas takes it for guns.",
		"body": "Scrap is the team pot: every bug killed, the bounty for each wave held, the scrap heap and crops sold. It buys turrets, seeds and the house. Chitin is yours: bigger bugs carry it, shells drop where bugs die on your plateau, and chilies sell for it. It buys guns and upgrades.",
		"tasks": [], "keys": [["accept", "Continue"]], "marker": "Market", "read": true},
	{"title": "Gun Upgrades", "voice": "kettle", "line": "Bring me a gun and some chitin. I can outfit these fine pieces of weaponry however you like, from making 'em harder hitting and quicker to load, to some more... custom modifications. The work stays with the gun.",
		"body": "The gunsmith works on any gun you own, for chitin: harder hitting and quicker to load, then custom mods that change how it handles, like a hair trigger or a longer barrel. Upgrades stay with the gun.",
		"tasks": [], "keys": [["cycle_option", "Pick"], ["interact", "Buy"], ["accept", "Continue"]], "marker": "Gunsmith", "read": true},
	{"title": "The Scrap Heap", "voice": "stroud", "line": "Back home. That heap of junk by your house is free scrap for the team pot, and it piles up again every morning. Pick it over each day.",
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
	# A spectacle (Logan): as many slow Dust Mites as the Gatling Post can mow
	# down (up to 50), in pulses, all on the two lanes it covers.
	var groups: Array = []
	var times: Array = []
	for p in WAVE_PULSES:
		times.append(p * WAVE_GAP)
		for lane: int in [1, 2]:
			groups.append({"bug": SLOW_MITE, "count": WAVE_MITES / (WAVE_PULSES * 2), "cliff": partner, "lane": lane, "pulse": p})
	return {"groups": groups, "pulses": WAVE_PULSES, "pulse_times": times, "shape": WavePlanner.STEADY,
			"west_share": shares[0], "shares": shares, "spent": WAVE_MITES}


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
