extends Node3D
class_name SkyTerrain3D

const ISLAND_RADIUS := 36.0
const CRATER_X := -2.0
const CRATER_Z := -15.0
const CRATER_WATER_Y := 8.7

var water_mat: StandardMaterial3D
var islets: Array[Node3D] = []
var mist_puffs: Array[MeshInstance3D] = []

static func get_edge_radius(angle: float) -> float:
	return (
		ISLAND_RADIUS
		+ 1.6 * sin(angle * 3.0 + 0.4)
		+ 0.9 * cos(angle * 5.0 - 0.8)
		+ 0.5 * sin(angle * 7.0)
	)

static func get_river_x(z: float) -> float:
	var t := clampf((z + 11.0) / 40.0, 0.0, 1.0)
	return -2.0 + 10.5 * pow(t, 1.35) + 1.4 * sin(t * PI * 2.0)

static func get_terrain_height(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var angle := atan2(z, x)
	var max_r := get_edge_radius(angle)
	var norm_r := r / max_r

	if norm_r > 1.08:
		return -5.0

	var h := (
		2.2
		+ 0.85 * sin(x * 0.11 + 0.5) * cos(z * 0.1 + 0.3)
		+ 0.45 * cos((x + z) * 0.16)
	)

	var rim_falloff := clampf((1.0 - norm_r) / 0.22, 0.0, 1.0)
	h *= 0.35 + 0.65 * pow(rim_falloff, 0.6)

	var dc := sqrt(pow(x - CRATER_X, 2.0) + pow(z - CRATER_Z, 2.0))
	h += 9.0 * exp(-(dc * dc) / (2.0 * 9.5 * 9.5))
	if dc < 6.2:
		h -= 3.6 * exp(-(dc * dc) / (2.0 * 3.1 * 3.1))

	var d_obs := sqrt(pow(x - 16.0, 2.0) + pow(z + 6.0, 2.0))
	h += 2.6 * exp(-(d_obs * d_obs) / (2.0 * 6.5 * 6.5))

	var d_left := sqrt(pow(x + 17.0, 2.0) + pow(z + 7.0, 2.0))
	h += 2.1 * exp(-(d_left * d_left) / (2.0 * 6.0 * 6.0))

	if z > -11.5 and z < 34.0:
		var rx := get_river_x(z)
		var dist := absf(x - rx)
		if dist < 4.5:
			var carve := exp(-(dist * dist) / (2.0 * 1.65 * 1.65))
			var depth := 1.5 if z < -4.0 else 1.15
			h -= depth * carve

	if norm_r > 0.92:
		var t := maxf(0.0, 1.0 - (norm_r - 0.92) / 0.12)
		h *= t

	return h

func build(track_curve: Curve3D) -> void:
	_build_top_mesh()
	_build_underbelly()
	_build_vines()
	_build_water()
	_build_islets()
	_build_vegetation(track_curve)

func _build_top_mesh() -> void:
	var radial_segs := 72
	var ring_segs := 32
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grass_low := Color("#3f9627")
	var grass_high := Color("#65c43b")
	var rock_slope := Color("#7c5c40")
	var river_bed := Color("#376473")

	var verts: Array[Vector3] = []
	var cols: Array[Color] = []

	for ir in range(ring_segs + 1):
		var frac := float(ir) / ring_segs
		for ia in range(radial_segs + 1):
			var angle := (float(ia) / radial_segs) * TAU
			var r := frac * get_edge_radius(angle)
			var x := cos(angle) * r
			var z := sin(angle) * r
			var y := get_terrain_height(x, z)
			verts.append(Vector3(x, y, z))

			var c := grass_low.lerp(grass_high, clampf((y - 1.5) / 6.0, 0.0, 1.0))
			if y > 6.5:
				c = c.lerp(rock_slope, minf(0.65, (y - 6.5) / 4.5))
			if z > -11.0 and absf(x - get_river_x(z)) < 1.8:
				c = c.lerp(river_bed, 0.65)
			if frac > 0.94:
				c = c.lerp(rock_slope, 0.55)
			cols.append(c)

	var stride := radial_segs + 1
	for ir in range(ring_segs):
		for ia in range(radial_segs):
			var a := ir * stride + ia
			var b := (ir + 1) * stride + ia
			var c := (ir + 1) * stride + (ia + 1)
			var d := ir * stride + (ia + 1)
			for idx in [a, b, d, b, c, d]:
				st.set_color(cols[idx])
				st.add_vertex(verts[idx])

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)

func _build_underbelly() -> void:
	var u_rings := 12
	var u_rad := 44
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rock_dark := Color("#4a3829")
	var rock_mid := Color("#6e533d")
	var rock_light := Color("#86684e")

	var verts: Array[Vector3] = []
	var cols: Array[Color] = []

	for ir in range(u_rings + 1):
		var t := float(ir) / u_rings
		var depth := -pow(t, 1.15) * 16.5
		for ia in range(u_rad + 1):
			var angle := (float(ia) / u_rad) * TAU
			var max_r := get_edge_radius(angle)
			var jitter := 1.0 if (ir == 0 or ir == u_rings) else (0.86 + 0.24 * sin(angle * 7.0 + ir * 2.1) * cos(angle * 3.0 - ir))
			var r := max_r * (1.0 - pow(t, 0.85)) * jitter
			var x := cos(angle) * r
			var z := sin(angle) * r
			var y := (get_terrain_height(x, z) - 0.15) if ir == 0 else (depth + sin(angle * 5.0 + ir) * 0.6 * (1.0 - t))
			verts.append(Vector3(x, y, z))
			var c := rock_light.lerp(rock_mid, t).lerp(rock_dark, maxf(0.0, t - 0.35))
			cols.append(c)

	var stride := u_rad + 1
	for ir in range(u_rings):
		for ia in range(u_rad):
			var a := ir * stride + ia
			var b := (ir + 1) * stride + ia
			var c := (ir + 1) * stride + (ia + 1)
			var d := ir * stride + (ia + 1)
			for idx in [a, d, b, b, d, c]:
				st.set_color(cols[idx])
				st.add_vertex(verts[idx])

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)

func _build_vines() -> void:
	var vine_mat := StandardMaterial3D.new()
	vine_mat.albedo_color = Color("#5a4632")
	var coords := [
		Vector4(-26, -3, 10, 7.5),
		Vector4(-23, -3.5, 13, 5.2),
		Vector4(-18, -5, -18, 6.8),
		Vector4(-8, -7, 22, 8.0),
		Vector4(15, -5.5, 20, 6.0),
		Vector4(25, -3.2, -9, 5.5)
	]
	for v in coords:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.14
		cyl.bottom_radius = 0.03
		cyl.height = v.w
		cyl.radial_segments = 5
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = vine_mat
		mi.position = Vector3(v.x, v.y - v.w * 0.5, v.z)
		add_child(mi)

func _build_water() -> void:
	var img := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(128):
			var edge := absf(float(x) / 128.0 - 0.5) * 2.0
			var c := Color("#42c4f5").lerp(Color("#1e90d4"), edge)
			if ((x * 17 + y * 31) % 97) < 3 and (y % 18) < 10:
				c = c.lerp(Color.WHITE, 0.55)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)

	water_mat = StandardMaterial3D.new()
	water_mat.albedo_texture = tex
	water_mat.roughness = 0.25
	water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(1, 1, 1, 0.92)
	water_mat.uv1_scale = Vector3(1, 3, 1)

	# Crater lake
	var lake_mesh := CylinderMesh.new()
	lake_mesh.top_radius = 4.3
	lake_mesh.bottom_radius = 4.3
	lake_mesh.height = 0.1
	var lake := MeshInstance3D.new()
	lake.mesh = lake_mesh
	lake.material_override = water_mat
	lake.position = Vector3(CRATER_X, CRATER_WATER_Y, CRATER_Z)
	add_child(lake)

	# River ribbon
	var river_z_start := -11.2
	var river_z_end := 33.5
	var z := 24.0
	while z <= 36.0:
		var rx := get_river_x(z)
		if sqrt(rx * rx + z * z) >= get_edge_radius(atan2(z, rx)) - 0.3:
			river_z_end = z
			break
		z += 0.25

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 44
	var r_verts: Array[Vector3] = []
	var r_uvs: Array[Vector2] = []
	for i in range(steps + 1):
		var t := float(i) / steps
		var rz := lerpf(river_z_start, river_z_end, t)
		var cx := get_river_x(rz)
		var w := 1.65 + 0.35 * sin(t * PI)
		var cy := get_terrain_height(cx, rz) + 0.22
		r_verts.append(Vector3(cx - w, cy, rz))
		r_verts.append(Vector3(cx + w, cy, rz))
		r_uvs.append(Vector2(0, t * 4.0))
		r_uvs.append(Vector2(1, t * 4.0))
	for i in range(steps):
		var a := i * 2
		for idx in [a, a + 2, a + 1, a + 1, a + 2, a + 3]:
			st.set_uv(r_uvs[idx])
			st.add_vertex(r_verts[idx])
	st.generate_normals()
	var river := MeshInstance3D.new()
	river.mesh = st.commit()
	river.material_override = water_mat
	add_child(river)

	# Cliff waterfall
	var wf_x := get_river_x(river_z_end)
	var wf_y := get_terrain_height(wf_x, river_z_end) + 0.15
	var wf_h := 25.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.4, wf_h)
	var wf := MeshInstance3D.new()
	wf.mesh = plane
	wf.material_override = water_mat
	wf.position = Vector3(wf_x, wf_y - wf_h * 0.5, river_z_end + 0.55)
	wf.rotation.x = PI * 0.5
	add_child(wf)

func _build_islets() -> void:
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color("#48a632")
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color("#6b513b")

	var cfgs := [
		Vector4(-45, 3.5, -10, 2.2),
		Vector4(-49, -5.5, 9, 1.6),
		Vector4(-39, -12.5, 24, 2.6),
		Vector4(47, 5.5, -16, 1.9),
		Vector4(39, -8.0, 27, 1.8)
	]
	for idx in range(cfgs.size()):
		var cfg: Vector4 = cfgs[idx]
		var isl := Node3D.new()
		var cap := MeshInstance3D.new()
		var cap_m := CylinderMesh.new()
		cap_m.top_radius = cfg.w
		cap_m.bottom_radius = cfg.w * 0.9
		cap_m.height = 0.7
		cap_m.radial_segments = 7
		cap.mesh = cap_m
		cap.material_override = grass_mat
		cap.position.y = 0.2
		isl.add_child(cap)

		var base := MeshInstance3D.new()
		var base_m := CylinderMesh.new()
		base_m.top_radius = cfg.w * 0.92
		base_m.bottom_radius = 0.05
		base_m.height = cfg.w * 1.9
		base_m.radial_segments = 7
		base.mesh = base_m
		base.material_override = rock_mat
		base.position.y = -cfg.w * 0.95
		isl.add_child(base)

		isl.position = Vector3(cfg.x, cfg.y, cfg.z)
		isl.set_meta("base_y", cfg.y)
		isl.set_meta("phase", float(idx) * 1.3)
		add_child(isl)
		islets.append(isl)

func _build_vegetation(track_curve: Curve3D) -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("#5c3b24")
	var pine_mats: Array[StandardMaterial3D] = []
	for hex in ["#186629", "#217d33", "#2c943e"]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		pine_mats.append(m)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color("#45a82c")

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var baked := track_curve.get_baked_points()
	var placed := 0
	var attempts := 0
	while placed < 155 and attempts < 1400:
		attempts += 1
		var angle := rng.randf() * TAU
		var r := 4.0 + rng.randf() * 31.0
		var x := cos(angle) * r
		var z := sin(angle) * r
		if r > get_edge_radius(angle) - 2.2:
			continue
		if Vector2(x - CRATER_X, z - CRATER_Z).length() < 6.4:
			continue
		if z > -12.0 and absf(x - get_river_x(z)) < 3.4:
			continue
		if Vector2(x + 1.0, z - 2.0).length() < 9.5:
			continue
		if x > 26.0 and absf(z - 2.0) < 4.5:
			continue

		var near_track := false
		for i in range(0, baked.size(), 4):
			var pt := baked[i]
			if Vector2(x - pt.x, z - pt.z).length() < 2.9:
				near_track = true
				break
		if near_track:
			continue

		var y := get_terrain_height(x, z)
		var sc := 0.75 + rng.randf() * 0.65
		var tree := Node3D.new()
		var trunk := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.18
		tm.bottom_radius = 0.28
		tm.height = 1.2
		tm.radial_segments = 6
		trunk.mesh = tm
		trunk.material_override = trunk_mat
		trunk.position.y = 0.6
		tree.add_child(trunk)

		if rng.randf() < 0.72:
			for i in range(3):
				var cone := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.02
				cm.bottom_radius = 1.25 - i * 0.28
				cm.height = 1.9 - i * 0.25
				cm.radial_segments = 7
				cone.mesh = cm
				cone.material_override = pine_mats[i]
				cone.position.y = 1.65 + i * 1.05
				tree.add_child(cone)
		else:
			var crown := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.15
			sm.height = 2.3
			sm.radial_segments = 7
			sm.rings = 4
			crown.mesh = sm
			crown.material_override = leaf_mat
			crown.position.y = 2.05
			tree.add_child(crown)

		tree.position = Vector3(x, y - 0.1, z)
		tree.scale = Vector3.ONE * sc
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)
		placed += 1

func update_terrain(delta: float, elapsed: float) -> void:
	if water_mat:
		water_mat.uv1_offset.y -= delta * 0.75
	for isl in islets:
		var by: float = isl.get_meta("base_y")
		var ph: float = isl.get_meta("phase")
		isl.position.y = by + sin(elapsed * 0.7 + ph) * 0.55
