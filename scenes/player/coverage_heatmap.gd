class_name CoverageHeatmap
extends MeshInstance3D
## Build-mode overlay on your partner's cliff wall (the one your turrets defend):
## each stretch is tinted by how many of your existing turrets cover it. Red = no
## turret reaches it, amber = one, green = two or more. Built from CoverageMap,
## so it only rebuilds when turrets change (or you look at the other wall).

const FACE_OFFSET := 1.0
const ALPHA := 0.36

var _wall := -1
var _dirty := true


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, ALPHA)
	material_override = m
	visible = false


## Show the heat map on `wall` (or hide it with -1).
func show_wall(wall: int) -> void:
	var cm := CoverageMap.instance
	if wall < 0 or cm == null or cm.cliffs == null or cm.points[0].is_empty():
		visible = false
		return
	if not cm.changed.is_connected(_mark):
		cm.changed.connect(_mark)
	if wall != _wall:
		_wall = wall
		_dirty = true
	if _dirty:
		_dirty = false
		_build(cm)
	visible = true


func _mark() -> void:
	_dirty = true


func _build(cm: CoverageMap) -> void:
	var st := MeshKit.begin()
	var pts := cm.points[_wall]
	var off := PackedVector3Array()
	off.resize(pts.size())
	for r in cm.rows:
		for c in cm.cols:
			var i := r * cm.cols + c
			off[i] = pts[i] + cm.cliffs.face_normal(_wall, cm.y_of(r), CoverageMap.z_of(c)) * FACE_OFFSET
	for r in cm.rows - 1:
		for c in cm.cols - 1:
			var i := r * cm.cols + c
			# A stretch is only as covered as its weakest corner.
			var n := mini(mini(cm.count_at(_wall, r, c), cm.count_at(_wall, r, c + 1)),
					mini(cm.count_at(_wall, r + 1, c), cm.count_at(_wall, r + 1, c + 1)))
			var col := CoverageMap.heat_color(n)
			var a := off[i]
			var b := off[i + 1]
			var d := off[i + cm.cols]
			var e := off[i + cm.cols + 1]
			var nrm := (b - a).cross(d - a).normalized()
			MeshKit.tri(st, a, b, e, nrm, nrm, nrm, col, nrm)
			MeshKit.tri(st, a, e, d, nrm, nrm, nrm, col, nrm)
	mesh = MeshKit.finish(st)
