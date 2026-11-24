extends Node3D

const SkyTerrain3D = preload("res://scripts/sky_terrain.gd")

var track_curve: Curve3D
var loco: Node3D
var carriages: Array[Node3D] = []
var wheels: Array[MeshInstance3D] = []
var side_rods: Array[MeshInstance3D] = []
var window_glow_mat: StandardMaterial3D
var head_light: OmniLight3D

var smoke_puffs: Array[MeshInstance3D] = []
var smoke_cursor := 0
var smoke_timer := 0.0

var progress_u := 0.15
var speed_u := 0.018
var target_throttle := 0.55
var steam_pressure := 100.0
var rod_phase := 0.0

var whistle_player: AudioStreamPlayer
var whistle_playback: AudioStreamGeneratorPlayback
var whistle_time := 0.0

static func create_track_curve() -> Curve3D:
	var curve := Curve3D.new()
	var num_pts := 32
	for i in range(num_pts):
		var a := (float(i) / num_pts) * TAU
		var rx := 25.5 + 2.2 * cos(a * 2.0)
		var rz := 24.5 + 1.8 * sin(a * 3.0)
		var x := cos(a) * rx
		var z := sin(a) * rz
		var y := SkyTerrain3D.get_terrain_height(x, z) + 0.25
		if z > 14.0 and absf(x - SkyTerrain3D.get_river_x(z)) < 5.2:
			y = maxf(y, 2.55)
		curve.add_point(Vector3(x, y, z))
	curve.closed = true
	return curve

func build(curve: Curve3D) -> void:
	track_curve = curve
	_build_track()
	_build_ck124()
	_build_carriages()
	_build_smoke_pool()
	_setup_whistle_audio()

func _mat(hex: String, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
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

func _add_cyl(parent: Node3D, r: float, h: float, segs: int, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_track() -> void:
	var tie_mat := _mat("#5c4028", 0.92)
	var rail_mat := _mat("#9ca5ad", 0.35, 0.75)
	var stone_mat := _mat("#7b746a", 0.92)
	var total_len := track_curve.get_baked_length()
	var tie_count := int(total_len / 0.85)

	for i in range(tie_count):
		var u := float(i) / tie_count
		var pos := track_curve.sample_baked(u * total_len)
		var ahead := track_curve.sample_baked(fmod(u + 0.005, 1.0) * total_len)
		var tan := (ahead - pos).normalized()

		var tie := _add_box(self, Vector3(1.55, 0.12, 0.26), pos, tie_mat)
		tie.look_at(pos + tan, Vector3.UP)

		var seg_len := total_len / tie_count
		for side_x in [-0.46, 0.46]:
			var rail := _add_box(tie, Vector3(0.1, 0.1, seg_len * 1.08), Vector3(side_x, 0.1, 0), rail_mat)
			rail.material_override = rail_mat

		var ground_y := SkyTerrain3D.get_terrain_height(pos.x, pos.z)
		if pos.y - ground_y > 0.75 and i % 3 == 0:
			var pier_h := pos.y - ground_y + 0.5
			var pier := _add_box(self, Vector3(1.3, pier_h, 0.65), Vector3(pos.x, ground_y + pier_h * 0.5 - 0.3, pos.z), stone_mat)
			pier.look_at(Vector3(ahead.x, pier.position.y, ahead.z), Vector3.UP)

func _build_ck124() -> void:
	loco = Node3D.new()
	add_child(loco)

	var black := _mat("#1b1e22", 0.42, 0.35)
	var chassis_m := _mat("#2b2f35", 0.55, 0.45)
	var red := _mat("#c8251e", 0.45)
	var brass := _mat("#e6b446", 0.28, 0.7)
	var silver := _mat("#cfd6de", 0.3, 0.75)

	window_glow_mat = StandardMaterial3D.new()
	window_glow_mat.albedo_color = Color("#ffe29a")
	window_glow_mat.emission_enabled = true
	window_glow_mat.emission = Color("#ffaa33")
	window_glow_mat.emission_energy_multiplier = 0.0

	_add_box(loco, Vector3(1.16, 0.34, 3.35), Vector3(0, 0.48, 0), chassis_m)

	# Red buffer beams (front & back in -Z forward)
	for bz in [-1.68, 1.68]:
		_add_box(loco, Vector3(1.24, 0.3, 0.14), Vector3(0, 0.46, bz), red)

	# Boiler (note: Godot forward is -Z)
	var boiler := _add_cyl(loco, 0.45, 1.95, 16, Vector3(0, 1.04, -0.5), black)
	boiler.rotation.x = PI * 0.5

	for bz in [0.1, -0.45, -1.0]:
		var band := _add_cyl(loco, 0.465, 0.05, 16, Vector3(0, 1.04, bz), brass)
		band.rotation.x = PI * 0.5

	# Side water tanks
	for tx in [-0.52, 0.52]:
		_add_box(loco, Vector3(0.28, 0.68, 1.32), Vector3(tx, 0.96, -0.28), black)
		_add_box(loco, Vector3(0.04, 0.16, 0.46), Vector3(tx + (0.15 if tx > 0 else -0.15), 0.88, 0.82), brass)

	# Steam dome & stack
	_add_cyl(loco, 0.22, 0.36, 12, Vector3(0, 1.54, -0.45), black)
	_add_cyl(loco, 0.15, 0.65, 12, Vector3(0, 1.68, -1.18), black)
	var ring := _add_cyl(loco, 0.17, 0.06, 12, Vector3(0, 2.0, -1.18), brass)

	# Cab & coal bunker
	_add_box(loco, Vector3(1.22, 1.15, 1.0), Vector3(0, 1.18, 0.85), black)
	_add_box(loco, Vector3(1.16, 0.72, 0.5), Vector3(0, 0.96, 1.52), black)
	_add_box(loco, Vector3(1.32, 0.12, 1.15), Vector3(0, 1.78, 0.85), chassis_m)

	# Headlight
	_add_box(loco, Vector3(0.22, 0.22, 0.22), Vector3(0, 1.56, -1.52), window_glow_mat)
	head_light = OmniLight3D.new()
	head_light.light_color = Color("#ffd27d")
	head_light.light_energy = 0.0
	head_light.omni_range = 14.0
	head_light.position = Vector3(0, 1.56, -1.9)
	loco.add_child(head_light)

	# 2-6-2 Wheels + connecting rods
	for wz in [0.45, -0.25, -0.95]:
		for wx in [-0.58, 0.58]:
			var w := _add_cyl(loco, 0.34, 0.1, 14, Vector3(wx, 0.34, wz), red)
			w.rotation.z = PI * 0.5
			wheels.append(w)
	for wz in [1.25, -1.45]:
		for wx in [-0.56, 0.56]:
			var w := _add_cyl(loco, 0.19, 0.1, 10, Vector3(wx, 0.2, wz), chassis_m)
			w.rotation.z = PI * 0.5
			wheels.append(w)
	for rx in [-0.65, 0.65]:
		var rod := _add_box(loco, Vector3(0.05, 0.08, 1.55), Vector3(rx, 0.28, -0.25), silver)
		side_rods.append(rod)

func _build_carriages() -> void:
	var chassis_m := _mat("#2b2f35", 0.55, 0.45)
	var tra_blue := _mat("#1d4e89", 0.48)
	var white := _mat("#f4f6f8", 0.6)
	var roof_gray := _mat("#6b727a", 0.65)

	for _c in range(2):
		var car := Node3D.new()
		_add_box(car, Vector3(1.12, 0.24, 2.35), Vector3(0, 0.36, 0), chassis_m)
		_add_box(car, Vector3(1.1, 0.92, 2.2), Vector3(0, 0.94, 0), tra_blue)
		_add_box(car, Vector3(1.125, 0.11, 2.22), Vector3(0, 0.7, 0), white)
		_add_box(car, Vector3(1.2, 0.18, 2.3), Vector3(0, 1.46, 0), roof_gray)
		for wx in [-0.56, 0.56]:
			for wz in [-0.65, 0.0, 0.65]:
				_add_box(car, Vector3(0.03, 0.34, 0.38), Vector3(wx, 1.05, wz), window_glow_mat)
		for wz in [-0.78, 0.78]:
			for wx in [-0.56, 0.56]:
				var w := _add_cyl(car, 0.22, 0.1, 10, Vector3(wx, 0.24, wz), chassis_m)
				w.rotation.z = PI * 0.5
				wheels.append(w)
		add_child(car)
		carriages.append(car)

func _build_smoke_pool() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	sm.radial_segments = 6
	sm.rings = 4
	for _i in range(36):
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.96, 0.98, 0.72)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		mi.visible = false
		mi.set_meta("life", 0.0)
		mi.set_meta("max_life", 1.6)
		mi.set_meta("vel", Vector3.ZERO)
		add_child(mi)
		smoke_puffs.append(mi)

func _setup_whistle_audio() -> void:
	whistle_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.2
	whistle_player.stream = gen
	whistle_player.volume_db = -10.0
	add_child(whistle_player)
	whistle_player.play()
	whistle_playback = whistle_player.get_stream_playback()

func trigger_whistle() -> void:
	whistle_time = 0.85
	for _i in range(6):
		_spawn_smoke(1.6)

func _spawn_smoke(mult := 1.0) -> void:
	var p := smoke_puffs[smoke_cursor]
	smoke_cursor = (smoke_cursor + 1) % smoke_puffs.size()
	p.position = loco.to_global(Vector3(0, 2.15, -1.18))
	p.scale = Vector3.ONE * 0.6
	p.visible = true
	p.set_meta("life", 0.0)
	p.set_meta("max_life", 1.5 + randf() * 0.6)
	p.set_meta("vel", Vector3(randf_range(-0.3, 0.3), 1.3 + randf() * 0.6 * mult, randf_range(-0.3, 0.3)))

func set_time_mode(mode: String) -> void:
	var is_night := mode == "night"
	var is_dusk := mode == "dusk"
	window_glow_mat.emission_energy_multiplier = 1.8 if is_night else (0.85 if is_dusk else 0.0)
	head_light.light_energy = 1.4 if is_night else (0.6 if is_dusk else 0.0)

func _place_on_track(obj: Node3D, u: float) -> void:
	var total_len := track_curve.get_baked_length()
	var w := fposmod(u, 1.0)
	var pos := track_curve.sample_baked(w * total_len)
	var ahead := track_curve.sample_baked(fposmod(w + 0.008, 1.0) * total_len)
	obj.position = pos
	obj.look_at(ahead, Vector3.UP)

func update_train(delta: float) -> void:
	# Smooth acceleration toward target_throttle
	var target_speed := target_throttle * 0.038
	if steam_pressure <= 2.0 and target_throttle > 0.0:
		target_speed = 0.006
	speed_u = lerpf(speed_u, target_speed, clampf(delta * 2.5, 0.0, 1.0))
	progress_u = fposmod(progress_u + delta * speed_u, 1.0)

	steam_pressure = clampf(steam_pressure - absf(speed_u) * 65.0 * delta + 1.8 * delta, 0.0, 100.0)

	_place_on_track(loco, progress_u)
	_place_on_track(carriages[0], progress_u - 0.020)
	_place_on_track(carriages[1], progress_u - 0.037)

	var wheel_spin := delta * (speed_u / 0.028) * 7.5
	rod_phase += wheel_spin
	for w in wheels:
		w.rotation.x -= wheel_spin
	for rod in side_rods:
		rod.position.y = 0.30 + sin(rod_phase) * 0.09
		rod.position.z = -0.25 + cos(rod_phase) * 0.09

	smoke_timer += delta * (0.4 + absf(speed_u) * 35.0)
	if smoke_timer > 0.14:
		smoke_timer = 0.0
		_spawn_smoke(1.0)

	for p in smoke_puffs:
		if not p.visible:
			continue
		var life: float = p.get_meta("life") + delta
		var max_life: float = p.get_meta("max_life")
		var t := life / max_life
		if t >= 1.0:
			p.visible = false
			continue
		p.set_meta("life", life)
		var vel: Vector3 = p.get_meta("vel")
		p.position += vel * delta
		p.scale = Vector3.ONE * (0.6 + t * 2.2)
		(p.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - t)

	# Synthesize whistle audio if active
	if whistle_time > 0.0 and whistle_playback:
		whistle_time -= delta
		var frames := whistle_playback.get_frames_available()
		for i in range(frames):
			var t := Time.get_ticks_msec() * 0.001 + float(i) / 22050.0
			var s := (sin(TAU * 523.25 * t) + 0.7 * sin(TAU * 659.25 * t) + 0.5 * sin(TAU * 783.99 * t)) * 0.25
			whistle_playback.push_frame(Vector2(s, s))
