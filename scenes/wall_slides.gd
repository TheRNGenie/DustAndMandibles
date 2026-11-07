class_name WallSlides
extends Node3D
## Wall slide zones (movement plan #18): smooth, faintly darker patches high on each
## canyon face over the bug lanes, just under the lip. Drop onto one from a
## swing and you slide down it slowly, free to shoot; jump to kick off. Sliding
## is never a fall into the canyon, but slide off the bottom without hooking on
## and you're falling. Each zone: an Area3D the player counts (like a ladder)
## and a faint dark skin laid on the rock itself (Logan: hard to tell apart from far away).

const LANES: Array[float] = [-16.0, -8.0, 8.0, 16.0]
const TOP := WorldLayout.CLIFF_HEIGHT - 4.0
const BOTTOM := WorldLayout.CLIFF_HEIGHT - 16.0
const WIDTH := 6.0
## The skin darkens the rock under it this much at its middle, fading to nothing at its edges.
const SKIN_DARK := 0.22

var cliffs: CliffBuilder


func build(c: CliffBuilder) -> void:
	cliffs = c
	for cid in WorldLayout.cliff_count():
		for z in LANES:
			_zone(cid, z)


func _zone(cid: int, z: float) -> void:
	var mid_y := (TOP + BOTTOM) * 0.5
	var n := cliffs.face_normal(cid, mid_y, z)
	var at := cliffs.face_point(cid, mid_y, z)
	var area := Area3D.new()
	area.name = "WallSlide%d_%d" % [cid, int(z)]
	area.collision_layer = 0
	area.collision_mask = 0xFFFF
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, TOP - BOTTOM, WIDTH) # (deep: the face bulges and dips under the lip)
	col.shape = box
	area.add_child(col)
	add_child(area)
	# The box's X runs out from the face (along the normal).
	area.global_transform = Transform3D(_basis(n), at + n * 0.4)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).wall_slide_count += 1
			(b as Player).wall_slide_normal = Vector3(n.x, 0.0, n.z).normalized())
	area.body_exited.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).wall_slide_count = maxi((b as Player).wall_slide_count - 1, 0))
	add_child(_skin(cid, z, n))


## X along the face's outward normal, Y up, Z along the canyon.
static func _basis(n: Vector3) -> Basis:
	var x := Vector3(n.x, 0.0, n.z).normalized()
	return Basis(x, Vector3.UP, x.cross(Vector3.UP).normalized())


## The faint dark patch, laid on the face point by point so it follows the rock.
func _skin(cid: int, z0: float, n: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nz := 4
	var ny := 10
	var pts: Array = []
	for j in ny + 1:
		var row: Array = []
		var y := lerpf(BOTTOM, TOP, float(j) / ny)
		for i in nz + 1:
			var z := z0 + lerpf(-WIDTH * 0.5, WIDTH * 0.5, float(i) / nz)
			row.append(cliffs.face_point(cid, y, z) + n * 0.12)
		pts.append(row)
	for j in ny:
		for i in nz:
			# Per corner: darkest in the middle, nothing at the edges (no hard outline).
			for q: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var u := 1.0 - absf(float(q.x) / nz * 2.0 - 1.0)
				var w := 1.0 - absf(float(q.y) / ny * 2.0 - 1.0)
				st.set_normal(n)
				st.set_color(Color(0, 0, 0, SKIN_DARK * smoothstep(0.0, 0.6, u) * smoothstep(0.0, 0.4, w)))
				st.add_vertex(pts[q.y][q.x])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # (a plain shade over the rock, no shine of its own)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
