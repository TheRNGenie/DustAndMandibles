class_name LoadingGazette
extends LoadingScreen
## Newspaper Front Page: "The Dry Gulch Gazette" coming off the press. A
## yellowed broadsheet with its masthead and dateline, two columns of
## headlines and stories about where you're headed (fresh swarms, chitin
## prices, the airship casino), classified ads, smudged ink at the edges. The
## loading indicator is the press itself: an inked roller across the foot of the
## page turning, the page scrolling up out of it with new articles appearing.

const NEWS := Color("#E8DDBE")
const NEWS_DARK := Color("#CDBB8E")
const INK := Color("#221C18")

## Stories for any day: [headline, body]. {map} becomes the destination.
const STORIES: Array = [
	["FRESH SWARM SPOTTED SOUTH OF THE RIDGE", "Riders coming in off the flats report a column of beetles a mile long, moving at a walk and in no hurry. Homesteaders at {map} are advised to oil their guns, top up their water and keep the children indoors after dark."],
	["CHITIN PRICES SOAR", "Shell traded at a record forty cents the pound at the assay office this week, on the back of strong demand from the airship gunsmith. Old hands warn the price is only as good as the last swarm, and the last swarm was a big one."],
	["AIRSHIP CASINO DENIES LOADED DICE", "The management of the floating saloon wishes it known that every die aboard is honest, every wheel true and every beetle in the races sober. A gentleman of the Snake Eyes declined to comment, and smiled."],
	["WEATHER: DUST, WITH A CHANCE OF MANDIBLES", "Expect a hot wind out of the west, dust in the afternoon and the usual scratching at the cliff faces by nightfall. Lightning possible. Bring a hat."],
	["HOMESTEADERS HOLD THE LINE AT {map}", "Two cliffs, two crews and not a single turret pointed at its own back porch. The arrangement is peculiar, the settlers admit, but it works: each side covers the other, and the bugs fall in between."],
	["SEED MERCHANT SWEARS BY CHILI MORTARS", "\"A good chili crop is worth a dozen rifles,\" says the cart-man, who also sells chili seed. Farmers report the mortars do indeed make the bugs think twice, and the cooking better."],
	["BEETLE RACE RESULTS", "Ol' Rattler by a horn in the third, the favourite falling asleep on the back straight. Stewards are looking into it."],
	["LETTERS: ON THE MATTER OF SPIDERS", "Sir, I have seen a spider the size of a buckboard and I would ask your readers to stop telling me it was a tumbleweed. Yours, Concerned of the East Rim."],
]
const ADS: Array = [
	"PARTNERS WANTED. Double the guns, double the glory. Apply at the rim.",
	"FOR SALE: one water barrel, slightly perforated. Cheap.",
	"LOST: grappling hook, much loved. Reward for return, no questions.",
	"DENTISTRY & GUNSMITHING. Both done quick. Mind which chair.",
]

var _articles: Array = [] # [headline, body]
var _lead := ""


func _build() -> void:
	var order := range(STORIES.size())
	order.shuffle()
	# (Stories name the map, even on the way back to town.)
	var place := str(ctx.get("map", "Canyon"))
	place = "the " + place if place.find(" ") < 0 else place
	for i: int in order:
		_articles.append([str(STORIES[i][0]).replace("{map}", place.to_upper()), str(STORIES[i][1]).replace("{map}", place)])
	if str(ctx.get("to", "")) == "menu":
		_lead = "RIDERS RETURN TO TOWN"
	elif int(ctx.get("chapter", 0)) > 0:
		_lead = "CHAPTER %s: %s" % [roman(int(ctx["chapter"])), str(ctx.get("chapter_title", "")).to_upper()]
	else:
		_lead = "POSSE RIDES OUT FOR %s" % destination().to_upper()


func _page() -> Rect2:
	var w := minf(size.x * 0.86, size.y * 1.45)
	return Rect2(Vector2((size.x - w) * 0.5, 0), Vector2(w, size.y))


func _draw() -> void:
	var s := sc()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2A201A"))
	var pg := _page()
	draw_rect(pg, NEWS)
	draw_texture_rect(grain(), pg, true, Color(0.5, 0.4, 0.2, 0.2))
	# The body, scrolling up out of the press (drawn first: the masthead and
	# the roller sit over it).
	var top := pg.position.y + 250.0 * s
	var roller_y := size.y - 110.0 * s
	var col_w := (pg.size.x - 150.0 * s) * 0.5
	var speed := 34.0 * s
	var scroll := t * speed
	# The page starts already printed down to the press, and keeps coming.
	var y0 := top + 24.0 * s - scroll
	var colx := [pg.position.x + 60.0 * s, pg.position.x + 90.0 * s + col_w]
	var ci := 0
	var cy := [y0, y0 + 120.0 * s]
	var i := 0
	# Lay articles into the two columns (repeating) until both are past the roller.
	while (float(cy[0]) < roller_y + 40.0 * s or float(cy[1]) < roller_y + 40.0 * s) and i < 60:
		ci = 0 if float(cy[0]) <= float(cy[1]) else 1
		var a: Array = _articles[i % _articles.size()]
		var h := _article(Vector2(float(colx[ci]), float(cy[ci])), col_w, str(a[0]), str(a[1]), top, roller_y)
		cy[ci] = float(cy[ci]) + h + 26.0 * s
		if i % 3 == 2:
			cy[ci] = float(cy[ci]) + _ad(Vector2(float(colx[ci]), float(cy[ci])), col_w, str(ADS[(i / 3) % ADS.size()]), top, roller_y) + 26.0 * s
		i += 1
	# Column rule.
	draw_line(Vector2(pg.position.x + 75.0 * s + col_w, top), Vector2(pg.position.x + 75.0 * s + col_w, roller_y), Color(INK, 0.5), 1.5 * s)
	# Masthead (opaque, over the scrolling body).
	draw_rect(Rect2(pg.position, Vector2(pg.size.x, 250.0 * s)), NEWS)
	draw_texture_rect(grain(), Rect2(pg.position, Vector2(pg.size.x, 250.0 * s)), true, Color(0.5, 0.4, 0.2, 0.2))
	var mid := pg.position.x + pg.size.x * 0.5
	var ewert := font(EWERT)
	text(ewert, Vector2(mid, pg.position.y + 82.0 * s), "THE DRY GULCH GAZETTE", fit_px(ewert, "THE DRY GULCH GAZETTE", 92.0, pg.size.x * 0.9), INK)
	for yy: float in [138.0, 144.0]:
		draw_line(Vector2(pg.position.x + 40.0 * s, pg.position.y + yy * s), Vector2(pg.end.x - 40.0 * s, pg.position.y + yy * s), INK, (3.0 if yy < 140.0 else 1.2) * s)
	var tf := font(TYPE)
	text(tf, Vector2(pg.position.x + 50.0 * s, pg.position.y + 162.0 * s), "VOL. XII  ·  NO. %d" % (30 + absi(rng.seed) % 60), 18.0, INK, HORIZONTAL_ALIGNMENT_LEFT)
	text(tf, Vector2(mid, pg.position.y + 162.0 * s), "ALL THE NEWS THAT FITS, AND SOME THAT DOESN'T", 18.0, INK)
	text(tf, Vector2(pg.end.x - 50.0 * s, pg.position.y + 162.0 * s), "PRICE 5 CENTS", 18.0, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_line(Vector2(pg.position.x + 40.0 * s, pg.position.y + 180.0 * s), Vector2(pg.end.x - 40.0 * s, pg.position.y + 180.0 * s), INK, 1.2 * s)
	var rye := font(RYE)
	text(rye, Vector2(mid, pg.position.y + 216.0 * s), _lead, fit_px(rye, _lead, 44.0, pg.size.x * 0.9), INK)
	draw_line(Vector2(pg.position.x + 40.0 * s, pg.position.y + 246.0 * s), Vector2(pg.end.x - 40.0 * s, pg.position.y + 246.0 * s), INK, 2.0 * s)
	_roller(pg, roller_y)
	# Smudged ink round the page's edges.
	for k in 10:
		var a := 0.06 * (1.0 - k / 10.0)
		draw_rect(Rect2(pg.position + Vector2(k * 4.0 * s, 0), Vector2(4.0 * s, pg.size.y)), Color(0.15, 0.1, 0.06, a))
		draw_rect(Rect2(Vector2(pg.end.x - (k + 1) * 4.0 * s, 0), Vector2(4.0 * s, pg.size.y)), Color(0.15, 0.1, 0.06, a))
	vignette(0.5)


## One story at `p` in a column `w` wide: a headline, a short rule, the body
## set in the typewriter face. Returns its height; drawn only where it's on
## the page (between the masthead and the press).
func _article(p: Vector2, w: float, head: String, body: String, top: float, bottom: float) -> float:
	var s := sc()
	var hf := font(BARLOW_XB)
	var hs := int(round(30.0 * s))
	var bf := font(TYPE)
	var bs := int(round(17.0 * s))
	var head_h := hf.get_multiline_string_size(head, HORIZONTAL_ALIGNMENT_CENTER, w, hs).y
	var body_h := bf.get_multiline_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, w, bs).y
	var h := head_h + 18.0 * s + body_h
	if p.y + h > top and p.y < bottom:
		draw_multiline_string(hf, p + Vector2(0, hf.get_ascent(hs)), head, HORIZONTAL_ALIGNMENT_CENTER, w, hs, -1, INK)
		var ry := p.y + head_h + 6.0 * s
		draw_line(Vector2(p.x + w * 0.35, ry), Vector2(p.x + w * 0.65, ry), Color(INK, 0.7), 1.5 * s)
		# Fresh off the roller the ink is darker and a touch smeared.
		var wet := clampf(1.0 - (bottom - p.y) / (220.0 * s), 0.0, 1.0)
		draw_multiline_string(bf, Vector2(p.x, ry + 12.0 * s + bf.get_ascent(bs)), body, HORIZONTAL_ALIGNMENT_LEFT, w, bs, -1, Color(INK, 0.82 + 0.15 * wet))
		if wet > 0.0:
			draw_multiline_string(bf, Vector2(p.x + 1.5 * s, ry + 13.0 * s + bf.get_ascent(bs)), body, HORIZONTAL_ALIGNMENT_LEFT, w, bs, -1, Color(INK, 0.18 * wet))
	return h


## A boxed classified ad.
func _ad(p: Vector2, w: float, words: String, top: float, bottom: float) -> float:
	var s := sc()
	var f := font(BARLOW_BOLD)
	var fs := int(round(20.0 * s))
	var th := f.get_multiline_string_size(words, HORIZONTAL_ALIGNMENT_CENTER, w - 30.0 * s, fs).y
	var h := th + 50.0 * s
	if p.y + h > top and p.y < bottom:
		var r := Rect2(p, Vector2(w, h))
		draw_rect(r, Color(INK, 0.9), false, 2.0 * s)
		draw_rect(r.grow(-5.0 * s), Color(INK, 0.6), false, 1.0 * s)
		text(font(TYPE), Vector2(p.x + w * 0.5, p.y + 16.0 * s), "— CLASSIFIED —", 14.0, Color(INK, 0.7))
		draw_multiline_string(f, Vector2(p.x + 15.0 * s, p.y + 30.0 * s + f.get_ascent(fs)), words, HORIZONTAL_ALIGNMENT_CENTER, w - 30.0 * s, fs, -1, INK)
	return h


## The press roller across the foot of the page: an inked iron drum turning
## (ridges sliding over it), gear wheels with spokes at both ends, the paper
## below it still blank.
func _roller(pg: Rect2, y: float) -> void:
	var s := sc()
	draw_rect(Rect2(Vector2(pg.position.x, y + 30.0 * s), Vector2(pg.size.x, size.y - y)), NEWS)
	var r := 34.0 * s
	var x0 := pg.position.x - 30.0 * s
	var x1 := pg.end.x + 30.0 * s
	# Drum, shaded like a cylinder.
	var bands := 10
	for i in bands:
		var k := float(i) / (bands - 1)
		var shade := 0.35 + 0.55 * sin(k * PI)
		draw_rect(Rect2(Vector2(x0, y - r + 2.0 * r * float(i) / bands), Vector2(x1 - x0, 2.0 * r / bands + 1.0)), Color(0.12, 0.11, 0.1).lerp(Color(0.42, 0.4, 0.38), shade * 0.6))
	# Ink ridges travelling down the drum's face as it turns.
	for i in 6:
		var a := fposmod(t * 2.2 + i * TAU / 6.0, TAU)
		if a < PI:
			var yy := y - cos(a) * r
			draw_line(Vector2(x0, yy), Vector2(x1, yy), Color(0, 0, 0, 0.35 * sin(a)), 3.0 * s)
	draw_line(Vector2(x0, y - r * 0.55), Vector2(x1, y - r * 0.55), Color(1, 1, 1, 0.12), 3.0 * s)
	# Gear wheels at the ends.
	for gx: float in [x0, x1]:
		var c := Vector2(gx, y)
		draw_circle(c, r * 1.55, Color("#3A3530"))
		for i in 14:
			var a := t * 2.2 + TAU * float(i) / 14.0
			draw_line(c + Vector2(cos(a), sin(a)) * r * 1.45, c + Vector2(cos(a), sin(a)) * r * 1.75, Color("#3A3530"), 9.0 * s)
		for i in 5:
			var a := t * 2.2 + TAU * float(i) / 5.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * r * 1.3, Color("#6A625A"), 6.0 * s)
		draw_circle(c, r * 0.45, Color("#8A8078"))
		draw_circle(c, r * 0.2, Color("#2A2520"))
	text(font(BARLOW_BOLD), Vector2(pg.position.x + pg.size.x * 0.5, y + 70.0 * s), note_text("HOT OFF THE PRESS").to_upper(), 22.0, Color(INK, 0.55))
