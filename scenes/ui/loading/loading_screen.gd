class_name LoadingScreen
extends Control
## The themed screen shown while something loads (Logan: "better loading
## screens than just a cut to black... a themed background with a loading
## circle"). SceneFade fades one in instead of plain black, feeds it `progress`
## (0..1) as the load moves along, and fades it away when the new screen runs
## smoothly. Two styles, both the canyon vista drawn in code (Logan kept these
## two, Nov 2026; the wanted poster, field guide page, brand plate and Gazette
## are retired to D:/DustAndMandibles-archive/retired/loading_screens):
##   vista     LoadingVista  layered canyon silhouettes drifting, a dynamite fuse burning along
##   cylinder  LoadingVista  the same canyon by night, a revolver cylinder lighting its chambers
## `ctx` says what's loading (SceneFade.context()): "to" (world / menu / first /
## cover), "map" (display name), "endless", "tutorial", "chapter" (number),
## "chapter_title", "wave", "brand", "bug" (a bug id for the field guide).

const STYLES: Array[StringName] = [&"vista", &"cylinder"]

const RYE := "res://assets/fonts/Rye-Regular.ttf"
const EWERT := "res://assets/fonts/Ewert-Regular.ttf"
const SANCREEK := "res://assets/fonts/Sancreek-Regular.ttf"
const TYPE := "res://assets/fonts/SpecialElite-Regular.ttf"
const BARLOW := "res://assets/fonts/BarlowSemiCondensed-Medium.ttf"
const BARLOW_BOLD := "res://assets/fonts/BarlowCondensed-Bold.ttf"
const BARLOW_XB := "res://assets/fonts/BarlowCondensed-ExtraBold.ttf"

## How far the load has got (SceneFade sets it); `shown` eases after it.
var progress := 0.0
var shown := 0.0
var ctx: Dictionary = {}
## What a long wait is waiting on ("Waiting for your posse"), from SceneFade;
## each style letters it beside its spinner, with moving dots. Empty: nothing.
var note := ""
## Seconds on screen.
var t := 0.0
var rng := RandomNumberGenerator.new()

static var _fonts: Dictionary = {}
static var _last_pick := -1


static func make(style: StringName, context: Dictionary = {}) -> LoadingScreen:
	var s := LoadingVista.new()
	if style == &"cylinder":
		s.meter = &"cylinder"
	s.ctx = context
	s.name = "Loading_%s" % style
	return s


## The style that suits a load: the dynamite fuse at dawn on first launch and
## for story chapters, the night cylinder on the way back to town and for loads
## inside the menus, and for a ride out the two take turns (never the same one
## twice running). --loadstyle=<id> forces one.
static func pick(context: Dictionary) -> StringName:
	var forced := GameState.flag_value("--loadstyle")
	if STYLES.has(StringName(forced)):
		return StringName(forced)
	match str(context.get("to", "world")):
		"menu", "cover":
			return &"cylinder"
		"first":
			return &"vista"
	if int(context.get("chapter", 0)) > 0:
		return &"vista" # (a chapter keeps its own hour of the day)
	var pool: Array[StringName] = [&"vista", &"cylinder"]
	var i := randi() % pool.size()
	if i == _last_pick and pool.size() > 1:
		i = (i + 1) % pool.size()
	_last_pick = i
	return pool[i]


static func font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[path]


## A slanted copy of a face (the naturalist's hand, an italic byline).
static func slanted(path: String, slant: float = 0.22) -> Font:
	var key := "%s@%s" % [path, slant]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = font(path)
		v.variation_transform = Transform2D(Vector2(1, 0), Vector2(-slant, 1), Vector2.ZERO)
		_fonts[key] = v
	return _fonts[key]


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	rng.seed = hash(str(ctx)) ^ Time.get_ticks_usec()
	_build()
	resized.connect(_on_resized)


func _process(delta: float) -> void:
	t += delta
	# Ease toward the real progress, and creep a little on a long wait so it
	# never looks stuck (never past what's actually been reached plus a bit).
	var goal := clampf(progress, 0.0, 1.0)
	shown = move_toward(shown, goal, delta * (1.6 if goal > shown + 0.2 else 0.7))
	_tick(delta)
	queue_redraw()


## Build the screen's nodes (fonts, labels): override.
func _build() -> void:
	pass


## Per frame (after `t` and `shown` move): override.
func _tick(_delta: float) -> void:
	pass


func _on_resized() -> void:
	pass


## Pixels per 1080p pixel (the screens are laid out at 1920 x 1080).
func sc() -> float:
	return maxf(size.y, 1.0) / 1080.0


## Text centred on `c` (or from its left/right edge), sized in 1080p pixels.
func text(f: Font, c: Vector2, s: String, px: float, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER,
		width: float = -1.0, outline: int = 0, outline_col: Color = Color.BLACK) -> void:
	var fs := int(round(px * sc()))
	var w := width if width > 0.0 else f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := c.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	var base := c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	if outline > 0:
		draw_string_outline(f, Vector2(x, base), s, align if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT, w, fs, outline, outline_col)
	draw_string(f, Vector2(x, base), s, align if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT, w, fs, col)


## Text width at a 1080p size (screen pixels).
func text_w(f: Font, s: String, px: float) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(px * sc()))).x


## Fits `s` to `max_w` screen pixels by shrinking from `px` (1080p pixels).
func fit_px(f: Font, s: String, px: float, max_w: float) -> float:
	var w := text_w(f, s, px)
	return px if w <= max_w else px * max_w / w


## A soft ring of dark at the screen's edges.
func vignette(strength: float = 0.55, col: Color = Color(0, 0, 0)) -> void:
	draw_texture_rect(vignette_tex(), Rect2(Vector2.ZERO, size), false, Color(col, strength))


static var _vig: Texture2D


static func vignette_tex() -> Texture2D:
	if _vig == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.12), Color(1, 1, 1, 1)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.08, 1.08)
		tex.width = 256
		tex.height = 256
		_vig = tex
	return _vig


## A tiling grain (soft noise) for paper, leather and newsprint.
static var _grain_tex: Texture2D


static func grain() -> Texture2D:
	if _grain_tex == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.08
		n.fractal_octaves = 4
		var nt := NoiseTexture2D.new()
		nt.noise = n
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		_grain_tex = nt
	return _grain_tex


## The waiting line with its dots (or `fallback` when there's no note).
func note_text(fallback: String = "") -> String:
	if note == "":
		return fallback
	return note + ".".repeat(1 + int(t * 2.5) % 3)


## The destination's line: "The Canyon", "Chapter III: Dry Bones", "Back to Town".
func destination() -> String:
	if str(ctx.get("to", "")) == "menu":
		return "Back to Town"
	var m := str(ctx.get("map", "Canyon"))
	return "The " + m if m.find(" ") < 0 and not m.begins_with("The ") else m


static func roman(n: int) -> String:
	var vals := [10, 9, 5, 4, 1]
	var syms := ["X", "IX", "V", "IV", "I"]
	var out := ""
	for i in vals.size():
		while n >= int(vals[i]):
			out += str(syms[i])
			n -= int(vals[i])
	return out
