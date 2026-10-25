class_name Palette
extends RefCounted
## The locked colour palette from the design doc ("Palette (lock it early)").

const SKY_TOP := Color("#4FB8D8")
const SKY_HORIZON := Color("#F7D9A0")
const SAND := Color("#E8B26A")
const ROCK_A := Color("#C8643C")
const ROCK_B := Color("#A84A32")
const ROCK_C := Color("#E08A4E")
const SHADOW_TINT := Color("#5A3A6B")
const WOOD := Color("#8A5A3B")
const WOOD_DARK := Color("#6B4229")
const METAL := Color("#6E7B85")
const BEETLE_TEAL := Color("#2E8C7E")
const SPIDER_PLUM := Color("#6B3D7A")
const MITE_RUST := Color("#B5532E")
const GLOW_YELLOW := Color("#FFD23F")
const ACID_GREEN := Color("#9BE564")
const TEAM_WEST := Color("#E0483C")
const TEAM_EAST := Color("#3C7BE0")
const OUTLINE := Color("#2B1B17")

# Extra props colours, kept inside the same family.
const CACTUS := Color("#5E9B4A")
const CACTUS_DARK := Color("#46803A")
const ROOF := Color("#A84A32")
const DIRT_DARK := Color("#7A4A2E")
const BONE := Color("#F2E3C2")


static func team_color(cliff_id: int) -> Color:
	return TEAM_WEST if cliff_id == WorldLayout.WEST else TEAM_EAST
