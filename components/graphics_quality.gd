class_name GraphicsQuality
extends RefCounted
## Graphics quality presets (Low / Medium / High) and what each setting level
## means for the renderer. Settings stores the levels; world.gd, BugManager and
## the VFX read the numbers from here. High is the game's original look.

const LOW := 0
const MEDIUM := 1
const HIGH := 2

const PRESETS: Array[String] = ["low", "medium", "high"]
const NAMES: Array[String] = ["Low", "Medium", "High", "Custom"]

## Settings each preset sets (the rest - FOV, brightness, V-Sync - are the player's own).
const PRESET_VALUES: Dictionary = {
	"low": {"shadows": false, "shadow_detail": LOW, "msaa": 0, "render_scale": 0.75, "effects": LOW,
			"view_distance": LOW, "particles": LOW, "bug_detail": LOW},
	"medium": {"shadows": true, "shadow_detail": MEDIUM, "msaa": 1, "render_scale": 1.0, "effects": MEDIUM,
			"view_distance": MEDIUM, "particles": MEDIUM, "bug_detail": MEDIUM},
	"high": {"shadows": true, "shadow_detail": HIGH, "msaa": 1, "render_scale": 1.0, "effects": HIGH,
			"view_distance": HIGH, "particles": HIGH, "bug_detail": HIGH},
}
## The keys a preset drives: changing one by hand makes the quality "custom".
const PRESET_KEYS: Array[String] = ["shadows", "shadow_detail", "msaa", "render_scale", "effects",
		"view_distance", "particles", "bug_detail"]

# Per level: [Low, Medium, High].
const SHADOW_ATLAS: Array[int] = [2048, 4096, 4096]
const SHADOW_DISTANCE: Array[float] = [70.0, 110.0, 160.0]
const SHADOW_SPLITS: Array[int] = [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS]
const SHADOW_FILTER: Array[int] = [RenderingServer.SHADOW_QUALITY_HARD,
		RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW]
## Camera far plane (the far lands fade into the haze just before it): out to
## the escarpment on the horizon, 2 km away, on High.
const VIEW_FAR: Array[float] = [900.0, 1400.0, 2000.0]
## Viewport mesh LOD threshold (pixels of error allowed): higher drops detail sooner.
const LOD_THRESHOLD: Array[float] = [4.0, 2.0, 1.0]
## Share of each particle burst actually emitted.
const PARTICLE_RATIO: Array[float] = [0.5, 0.75, 1.0]
## Bug crowd: nearest bugs updated every tick, the next "far" band, script time
## (microseconds per tick) the rest share, and how close a bug wears a face.
const BUG_FULL_DETAIL: Array[int] = [16, 28, 40]
const BUG_FAR_BUDGET: Array[int] = [60, 80, 100]
const BUG_TURN_BUDGET_US: Array[float] = [2500.0, 4000.0, 5000.0]
const BUG_FACE_RANGE: Array[float] = [10.0, 14.0, 17.0]
## How often (at most, per second) a bug outside the full-detail few gets its
## turn: on screen, and off screen (where nothing of it is drawn). Its brain
## gets all the time in between, so bugs move the same at any rate.
const BUG_ON_SCREEN_HZ: Array[float] = [15.0, 20.0, 30.0]
const BUG_OFF_SCREEN_HZ: Array[float] = [4.0, 5.0, 6.0]


static func level(v: int) -> int:
	return clampi(v, LOW, HIGH)


## The preset the hardware probably suits: integrated graphics (or a software or
## virtual adapter) gets Low, a dedicated GPU High.
static func auto_preset(device_type: int, adapter_name: String) -> String:
	var n := adapter_name.to_lower()
	if device_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or device_type == RenderingDevice.DEVICE_TYPE_CPU:
		return "low"
	for weak: String in ["intel", "uhd", "iris", "vega 3", "vega 6", "vega 8", "radeon graphics", "llvmpipe", "swiftshader", "microsoft basic", "mali", "adreno"]:
		if n.contains(weak):
			return "low"
	return "high"


## The preset whose values these settings match, else "custom".
static func matching_preset(values: Dictionary) -> String:
	for p: String in PRESETS:
		var preset: Dictionary = PRESET_VALUES[p]
		var same := true
		for key: String in PRESET_KEYS:
			if not values.has(key) or not is_equal_approx(float(values[key]), float(preset[key])):
				same = false
				break
		if same:
			return p
	return "custom"
