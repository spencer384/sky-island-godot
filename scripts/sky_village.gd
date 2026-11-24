extends Node3D

const SkyTerrain3D = preload("res://scripts/sky_terrain.gd")

var windmill_hubs: Array[Node3D] = []
var watermill_wheel: Node3D
var airship_node: Node3D
var airship_base_y := 0.0
var airship_prop: Node3D
var night_lights: Array[OmniLight3D] = []
var glow_mat: StandardMaterial3D
var stations: Array[Dictionary] = []

func build(track_curve: Curve3D) -> void:
	var cream := _mat("#f2e5cb", 0.84)
	var stone := _mat("#837c72", 0.92)
	var wood := _mat("#6b472b", 0.9)
	var dark_wood := _mat("#452b18", 0.9)
	var roof_red := _mat("#c43d2c", 0.74)
	var roof_blue := _mat("#2b5d94", 0.74)
	var roof_brown := _mat("#7d4a28", 0.8)
	var bronze := _mat("#a8652e", 0.38, 0.5)

	glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color("#fff1c4")
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("#ffaa3b")
	glow_mat.emission_energy_multiplier = 0.0

	_build_clock_tower(cream, stone, roof_red, bronze, dark_wood)
	_build_observatory(cream, bronze, dark_wood)
	_build_windmills(cream, wood, dark_wood, roof_brown)
	_build_cottages(cream, stone, wood, dark_wood, roof_red, roof_blue, roof_brown)
	_build_footbridge(wood, dark_wood)
	_build_lookout_and_gazebo(stone, wood, dark_wood, roof_red)
	_build_airship_and_dock(wood, dark_wood)
	_build_stations(track_curve, stone, dark_wood, roof_red)
	_build_streetlamps(track_curve, dark_wood)

func _mat(hex: String, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = rough
	m.metallic = metal
	return m

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_cyl(parent: Node3D, top_r: float, bot_r: float, h: float, segs: int, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_warm_light(parent: Node3D, pos: Vector3, energy := 1.6, rng := 10.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color("#ffbb55")
	l.light_energy = 0.0
	l.omni_range = rng
	l.position = pos
	l.set_meta("night_energy", energy)
	parent.add_child(l)
	night_lights.append(l)

func _build_clock_tower(cream: Material, stone: Material, roof_red: Material, bronze: Material, dark_wood: Material) -> void:
	var x := -7.5
	var z := -2.5
	var y := SkyTerrain3D.get_terrain_height(x, z)
	var t := Node3D.new()
	_add_box(t, Vector3(2.6, 5.8, 2.6), Vector3(0, 2.9, 0), cream)
	_add_box(t, Vector3(2.85, 0.3, 2.85), Vector3(0, 5.8, 0), stone)
	var roof := _add_cyl(t, 0.05, 2.1, 2.8, 4, Vector3(0, 7.35, 0), roof_red)
	roof.rotation.y = PI * 0.25
	_add_cyl(t, 0.03, 0.1, 1.1, 6, Vector3(0, 9.1, 0), bronze)

	for cz in [1.32, -1.32]:
		var dial := _add_cyl(t, 0.6, 0.6, 0.06, 16, Vector3(0, 4.4, cz), _mat("#fcf8ef", 0.5))
		dial.rotation.x = PI * 0.5
		var h_hand := _add_box(t, Vector3(0.06, 0.34, 0.04), Vector3(0.08, 4.5, cz + (0.04 if cz > 0 else -0.04)), dark_wood)
		h_hand.rotation.z = -0.5

	_add_warm_light(t, Vector3(0, 3.8, 2.0), 2.0, 12.0)
	t.position = Vector3(x, y - 0.1, z)
	add_child(t)

func _build_observatory(cream: Material, bronze: Material, dark_wood: Material) -> void:
	var x := 15.5
	var z := -5.5
	var y := SkyTerrain3D.get_terrain_height(x, z)
	var obs := Node3D.new()
	_add_cyl(obs, 2.4, 2.6, 3.2, 16, Vector3(0, 1.6, 0), cream)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.42
	sm.height = 4.84
	dome.mesh = sm
	dome.material_override = bronze
	dome.position = Vector3(0, 3.2, 0)
	obs.add_child(dome)
	var scope := _add_cyl(obs, 0.22, 0.32, 2.2, 10, Vector3(0, 4.5, 1.45), bronze)
	scope.rotation.x = PI / 3.0
	_add_warm_light(obs, Vector3(0, 2.0, 3.2), 1.6, 11.0)
	obs.position = Vector3(x, y - 0.2, z)
	add_child(obs)

func _build_windmills(cream: Material, wood: Material, dark_wood: Material, roof_brown: Material) -> void:
	var cfgs := [
		Vector3(-16.5, -7.5, 0.4),
		Vector3(11.5, 2.5, -0.35),
		Vector3(-5.5, -18.5, 0.2)
	]
	for cfg in cfgs:
		var y := SkyTerrain3D.get_terrain_height(cfg.x, cfg.y)
		var wm := Node3D.new()
		_add_cyl(wm, 1.15, 1.65, 4.6, 12, Vector3(0, 2.3, 0), cream)
		_add_cyl(wm, 1.38, 1.38, 1.4, 12, Vector3(0, 5.25, 0), roof_brown).mesh.top_radius = 0.05

		var hub := Node3D.new()
		hub.position = Vector3(0, 4.1, 1.25)
		for b in range(4):
			var blade := Node3D.new()
			blade.rotation.z = b * PI * 0.5
			_add_box(blade, Vector3(0.1, 2.6, 0.08), Vector3(0, 1.3, 0), wood)
			_add_box(blade, Vector3(0.68, 2.0, 0.04), Vector3(0.32, 1.55, 0.03), _mat("#f3ebd8"))
			hub.add_child(blade)
		wm.add_child(hub)
		windmill_hubs.append(hub)

		_add_warm_light(wm, Vector3(0, 2.2, 2.2), 1.2, 9.0)
		wm.position = Vector3(cfg.x, y - 0.15, cfg.y)
		wm.rotation.y = cfg.z
		add_child(wm)

func _build_cottages(cream: Material, stone: Material, wood: Material, dark_wood: Material, r_red: Material, r_blue: Material, r_brown: Material) -> void:
	var list := [
		[-3.8, 7.2, 0.35, r_red, true],
		[-9.8, 3.2, 0.5, r_red, false],
		[-5.5, 2.2, 0.15, r_brown, false],
		[3.5, 1.8, -0.45, r_blue, false],
		[4.5, -4.5, -0.2, r_red, false],
		[-3.2, -7.8, 0.25, r_blue, false],
		[9.5, -9.5, -0.5, r_red, false]
	]
	for item in list:
		var x: float = item[0]
		var z: float = item[1]
		var y := SkyTerrain3D.get_terrain_height(x, z)
		var h := Node3D.new()
		_add_box(h, Vector3(2.3, 1.65, 2.0), Vector3(0, 0.825, 0), cream)
		var roof := _add_cyl(h, 0.05, 1.88, 1.35, 4, Vector3(0, 2.3, 0), item[3])
		roof.rotation.y = PI * 0.25
		_add_box(h, Vector3(0.32, 0.9, 0.32), Vector3(0.65, 2.4, -0.35), stone)
		for wx in [-0.65, 0.65]:
			_add_box(h, Vector3(0.42, 0.42, 0.04), Vector3(wx, 0.95, 1.02), glow_mat)
		if item[4]:
			watermill_wheel = Node3D.new()
			for i in range(6):
				var sp := _add_box(watermill_wheel, Vector3(0.08, 1.65, 0.14), Vector3.ZERO, dark_wood)
				sp.rotation.x = i * PI / 6.0
			watermill_wheel.position = Vector3(1.32, 0.65, 0)
			h.add_child(watermill_wheel)
		_add_warm_light(h, Vector3(0, 1.2, 1.6), 1.35, 9.0)
		h.position = Vector3(x, y - 0.1, z)
		h.rotation.y = item[2]
		add_child(h)

func _build_footbridge(wood: Material, dark_wood: Material) -> void:
	var bz := 2.8
	var bx := SkyTerrain3D.get_river_x(bz)
	var by := SkyTerrain3D.get_terrain_height(bx, bz) + 0.85
	var b := Node3D.new()
	_add_box(b, Vector3(4.4, 0.18, 1.35), Vector3.ZERO, wood)
	for rz in [-0.6, 0.6]:
		_add_box(b, Vector3(4.4, 0.08, 0.08), Vector3(0, 0.55, rz), dark_wood)
	b.position = Vector3(bx, by, bz)
	add_child(b)

func _build_lookout_and_gazebo(stone: Material, wood: Material, dark_wood: Material, r_red: Material) -> void:
	var ly := SkyTerrain3D.get_terrain_height(-0.5, 19.5)
	var lt := Node3D.new()
	for px in [-0.7, 0.7]:
		for pz in [-0.7, 0.7]:
			_add_box(lt, Vector3(0.14, 3.2, 0.14), Vector3(px, 1.6, pz), dark_wood)
	_add_box(lt, Vector3(1.9, 0.15, 1.9), Vector3(0, 2.3, 0), wood)
	var lroof := _add_cyl(lt, 0.05, 1.5, 1.1, 4, Vector3(0, 3.7, 0), r_red)
	lroof.rotation.y = PI * 0.25
	lt.position = Vector3(-0.5, ly - 0.1, 19.5)
	add_child(lt)

	var gy := SkyTerrain3D.get_terrain_height(-6.8, -17.5)
	var gaz := Node3D.new()
	_add_cyl(gaz, 1.2, 1.3, 0.2, 6, Vector3(0, 0.1, 0), stone)
	var groof := _add_cyl(gaz, 0.05, 1.45, 0.9, 6, Vector3(0, 1.9, 0), r_red)
	gaz.position = Vector3(-6.8, gy - 0.1, -17.5)
	add_child(gaz)

func _build_airship_and_dock(wood: Material, dark_wood: Material) -> void:
	var start_x := 31.5
	var dock_len := 13.0
	var dock_y := SkyTerrain3D.get_terrain_height(31.5, 2.0) + 0.5
	var dock := Node3D.new()
	_add_box(dock, Vector3(dock_len, 0.25, 2.4), Vector3(start_x + dock_len * 0.5, dock_y, 2.0), wood)
	for i in range(4):
		var px := start_x + 2.0 + i * 3.0
		for pz in [-1.0, 1.0]:
			_add_cyl(dock, 0.14, 0.12, 8.5, 6, Vector3(px, dock_y - 3.6, 2.0 + pz), dark_wood)
	add_child(dock)

	airship_node = Node3D.new()
	var tan_mat := _mat("#d8c296", 0.72)
	var fin_mat := _mat("#8f4736", 0.75)
	var hull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.2
	sm.height = 6.4
	hull.mesh = sm
	hull.scale = Vector3(2.55, 0.92, 0.92)
	hull.material_override = tan_mat
	airship_node.add_child(hull)

	_add_box(airship_node, Vector3(2.2, 1.4, 0.12), Vector3(-6.5, 1.2, 0), fin_mat)
	_add_box(airship_node, Vector3(4.2, 1.15, 1.45), Vector3(0.3, -3.55, 0), wood)
	for wx in [-1.1, 0.0, 1.1]:
		_add_box(airship_node, Vector3(0.55, 0.42, 1.5), Vector3(0.3 + wx, -3.5, 0), glow_mat)
	_add_warm_light(airship_node, Vector3(0.3, -3.6, 0), 2.2, 14.0)

	airship_prop = Node3D.new()
	airship_prop.position = Vector3(-1.95, -3.55, 0)
	_add_box(airship_prop, Vector3(0.08, 1.2, 0.18), Vector3.ZERO, dark_wood)
	_add_box(airship_prop, Vector3(0.08, 0.18, 1.2), Vector3.ZERO, dark_wood)
	airship_node.add_child(airship_prop)

	airship_base_y = dock_y + 5.8
	airship_node.position = Vector3(44.0, airship_base_y, -1.5)
	airship_node.rotation.y = -0.22
	add_child(airship_node)

func _build_stations(track_curve: Curve3D, stone: Material, dark_wood: Material, roof_red: Material) -> void:
	var station_defs := [
		{ "name": "天空島中央站", "u": 0.28, "color": Color("#ffd166") },
		{ "name": "風車磨坊站", "u": 0.56, "color": Color("#6ecbff") },
		{ "name": "天文台山麓站", "u": 0.80, "color": Color("#ff8fa3") },
		{ "name": "飛艇碼頭站", "u": 0.02, "color": Color("#80ed99") }
	]
	var total_len := track_curve.get_baked_length()
	for sdef in station_defs:
		var u: float = sdef["u"]
		var pt := track_curve.sample_baked(u * total_len)
		var ahead := track_curve.sample_baked(fmod(u + 0.01, 1.0) * total_len)
		var tan := (ahead - pt).normalized()
		var side := tan.cross(Vector3.UP).normalized()
		var pos := pt - side * 2.5
		var y := SkyTerrain3D.get_terrain_height(pos.x, pos.z)

		var st := Node3D.new()
		_add_box(st, Vector3(3.8, 0.35, 2.1), Vector3(0, 0.18, 0), stone)
		for px in [-1.5, 1.5]:
			for pz in [-0.8, 0.8]:
				_add_box(st, Vector3(0.14, 1.6, 0.14), Vector3(px, 1.0, pz), dark_wood)
		_add_box(st, Vector3(4.2, 0.22, 2.5), Vector3(0, 1.9, 0), roof_red)
		_add_box(st, Vector3(1.1, 0.45, 0.08), Vector3(1.25, 1.32, -0.45), _mat("#1b4b8a", 0.5))
		_add_warm_light(st, Vector3(0, 1.5, 0.8), 2.2, 12.0)

		st.position = Vector3(pos.x, y - 0.05, pos.z)
		add_child(st)
		st.look_at(Vector3(pt.x, y - 0.05, pt.z), Vector3.UP)

		# Trackside delivery target beacon (ring + vertical light beam + floating crate)
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = sdef["color"]
		ring_mat.emission_enabled = true
		ring_mat.emission = sdef["color"]
		ring_mat.emission_energy_multiplier = 2.0
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color.a = 0.85

		var beacon := Node3D.new()
		beacon.position = pt + Vector3(0, 0.35, 0)
		beacon.visible = false

		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.4
		tm.outer_radius = 1.75
		ring.mesh = tm
		ring.material_override = ring_mat
		beacon.add_child(ring)

		var beam := MeshInstance3D.new()
		var bm_cyl := CylinderMesh.new()
		bm_cyl.top_radius = 0.35
		bm_cyl.bottom_radius = 0.65
		bm_cyl.height = 9.0
		beam.mesh = bm_cyl
		var beam_mat := ring_mat.duplicate()
		beam_mat.albedo_color.a = 0.25
		beam.material_override = beam_mat
		beam.position.y = 4.5
		beacon.add_child(beam)

		var crate := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(0.95, 0.95, 0.95)
		crate.mesh = c_box
		crate.material_override = _mat("#f5b73b", 0.35)
		crate.position.y = 3.2
		beacon.add_child(crate)

		add_child(beacon)

		stations.append({
			"name": sdef["name"],
			"u": u,
			"pos": pt,
			"ring": beacon,
			"crate": crate
		})

func _build_streetlamps(track_curve: Curve3D, dark_wood: Material) -> void:
	var total_len := track_curve.get_baked_length()
	for i in range(16):
		var u := float(i) / 16.0
		var pt := track_curve.sample_baked(u * total_len)
		var ahead := track_curve.sample_baked(fmod(u + 0.01, 1.0) * total_len)
		var tan := (ahead - pt).normalized()
		var side := tan.cross(Vector3.UP).normalized()
		var pos := pt + side * 1.75
		var ly := SkyTerrain3D.get_terrain_height(pos.x, pos.z)
		if absf(pt.y - ly) > 1.2:
			continue
		var lamp := Node3D.new()
		_add_cyl(lamp, 0.05, 0.08, 1.65, 6, Vector3(0, 0.82, 0), dark_wood)
		_add_box(lamp, Vector3(0.26, 0.3, 0.26), Vector3(0, 1.7, 0), glow_mat)
		if i % 2 == 0:
			_add_warm_light(lamp, Vector3(0, 1.7, 0), 1.1, 8.5)
		lamp.position = Vector3(pos.x, ly - 0.05, pos.z)
		add_child(lamp)

func set_time_mode(mode: String) -> void:
	var is_night := mode == "night"
	var is_dusk := mode == "dusk"
	glow_mat.emission_energy_multiplier = 2.0 if is_night else (0.85 if is_dusk else 0.0)
	for l in night_lights:
		var ne: float = l.get_meta("night_energy")
		l.light_energy = ne if is_night else (ne * 0.35 if is_dusk else 0.0)

func update_village(delta: float, elapsed: float) -> void:
	for i in range(windmill_hubs.size()):
		windmill_hubs[i].rotation.z += delta * (0.55 + i * 0.08)
	if watermill_wheel:
		watermill_wheel.rotation.x += delta * 1.4
	if airship_node:
		airship_node.position.y = airship_base_y + sin(elapsed * 0.85) * 0.45
		airship_node.rotation.z = sin(elapsed * 0.6) * 0.025
	if airship_prop:
		airship_prop.rotation.x += delta * 10.0
	for st in stations:
		var r: Node3D = st["ring"]
		if r.visible:
			r.scale = Vector3.ONE * (1.0 + 0.1 * sin(elapsed * 4.5))
			var crate: Node3D = st["crate"]
			crate.rotation.y += delta * 2.2
			crate.position.y = 3.2 + sin(elapsed * 3.5) * 0.35
