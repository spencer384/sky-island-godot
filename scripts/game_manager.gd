extends Node3D

const SkyTerrain3D = preload("res://scripts/sky_terrain.gd")
const SkyVillage3D = preload("res://scripts/sky_village.gd")
const CK124Train3D = preload("res://scripts/ck124_train.gd")

@onready var world_env: WorldEnvironment = $"../WorldEnvironment"
@onready var sun_light: DirectionalLight3D = $"../DirectionalLight3D"
@onready var camera: Camera3D = $"../Camera3D"
@onready var hud_mission: Label = $"../CanvasLayer/HUD/MissionBox/MissionLabel"
@onready var hud_stats: Label = $"../CanvasLayer/HUD/StatsBox/StatsLabel"
@onready var hud_toast_box: PanelContainer = $"../CanvasLayer/HUD/ToastBox"
@onready var hud_toast: Label = $"../CanvasLayer/HUD/ToastBox/ToastLabel"

var terrain: SkyTerrain3D
var village: SkyVillage3D
var train: CK124Train3D
var clouds: Array[Node3D] = []

var cam_mode := "orbit" # orbit | train3rd | train1st | airship
var time_mode := "day"  # day | dusk | night
var orbit_yaw := 0.1
var orbit_pitch := 0.35
var orbit_dist := 78.0
var is_dragging := false

var elapsed := 0.0
var score := 0
var deliveries := 0
var combo := 1
var active_station_idx := 0
var has_cargo := false
var pickup_idx := 0
var dropoff_idx := 2
var toast_timer := 0.0

const CARGO_NAMES := ["高山茶葉箱", "天文星圖捲", "風車麵粉袋", "天空島郵件"]

func _ready() -> void:
	var curve := CK124Train3D.create_track_curve()

	terrain = SkyTerrain3D.new()
	add_child(terrain)
	terrain.build(curve)

	village = SkyVillage3D.new()
	add_child(village)
	village.build(curve)

	train = CK124Train3D.new()
	add_child(train)
	train.build(curve)

	_build_clouds()
	_set_time_mode("day")
	_assign_new_mission()

func _build_clouds() -> void:
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color.WHITE
	c_mat.roughness = 0.95
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 10
	sm.rings = 6

	for c in range(18):
		var cluster := Node3D.new()
		for p in range(4):
			var m := MeshInstance3D.new()
			m.mesh = sm
			m.material_override = c_mat
			var s := 2.8 + randf() * 2.8
			m.scale = Vector3(s * 1.25, s * 0.85, s)
			m.position = Vector3((p - 2) * 3.1, randf_range(-0.8, 0.8), randf_range(-1.0, 1.0))
			cluster.add_child(m)
		var ang := (float(c) / 18.0) * TAU
		var dist := 72.0 + randf() * 40.0
		var cy := -18.0 if (c % 3 == 0) else (16.0 + randf() * 18.0)
		cluster.position = Vector3(cos(ang) * dist, cy, sin(ang) * dist)
		cluster.set_meta("angle", ang)
		cluster.set_meta("dist", dist)
		cluster.set_meta("base_y", cy)
		add_child(cluster)
		clouds.append(cluster)

func _assign_new_mission() -> void:
	pickup_idx = randi() % village.stations.size()
	dropoff_idx = (pickup_idx + 1 + randi() % (village.stations.size() - 1)) % village.stations.size()
	has_cargo = false
	_update_station_rings()

func _update_station_rings() -> void:
	for i in range(village.stations.size()):
		var ring: Node3D = village.stations[i]["ring"]
		ring.visible = (i == pickup_idx and not has_cargo) or (i == dropoff_idx and has_cargo)

func _show_toast(msg: String) -> void:
	if hud_toast and hud_toast_box:
		hud_toast.text = msg
		hud_toast_box.visible = true
		toast_timer = 3.2

func _set_time_mode(mode: String) -> void:
	time_mode = mode
	village.set_time_mode(mode)
	train.set_time_mode(mode)
	var env := world_env.environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	if mode == "day":
		sky.sky_top_color = Color("#2c7cd1")
		sky.sky_horizon_color = Color("#b8e2ff")
		sky.ground_horizon_color = Color("#b8e2ff")
		sky.ground_bottom_color = Color("#89c4f4")
		sun_light.light_color = Color("#fff9ed")
		sun_light.light_energy = 1.45
		sun_light.rotation_degrees = Vector3(-48, 35, 0)
		env.ambient_light_color = Color("#9fd8ff")
		env.ambient_light_energy = 0.55
	elif mode == "dusk":
		sky.sky_top_color = Color("#4e4d7a")
		sky.sky_horizon_color = Color("#f7a474")
		sky.ground_horizon_color = Color("#f7a474")
		sky.ground_bottom_color = Color("#b86b52")
		sun_light.light_color = Color("#ff9955")
		sun_light.light_energy = 1.4
		sun_light.rotation_degrees = Vector3(-18, -125, 0)
		env.ambient_light_color = Color("#ffc599")
		env.ambient_light_energy = 0.5
	else:
		sky.sky_top_color = Color("#081024")
		sky.sky_horizon_color = Color("#1a2b4c")
		sky.ground_horizon_color = Color("#1a2b4c")
		sky.ground_bottom_color = Color("#081024")
		sun_light.light_color = Color("#9ec0ff")
		sun_light.light_energy = 0.45
		sun_light.rotation_degrees = Vector3(-55, -140, 0)
		env.ambient_light_color = Color("#3d5a8a")
		env.ambient_light_energy = 0.35

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_dist = maxf(18.0, orbit_dist - 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_dist = minf(125.0, orbit_dist + 4.0)
	elif event is InputEventMouseMotion and is_dragging and cam_mode == "orbit":
		orbit_yaw -= event.relative.x * 0.006
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.006, 0.08, 1.35)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: cam_mode = "orbit"
			KEY_2: cam_mode = "train3rd"
			KEY_3: cam_mode = "train1st"
			KEY_4: cam_mode = "airship"
			KEY_Q: _set_time_mode("day")
			KEY_W, KEY_UP:
				if event.keycode == KEY_W and event.shift_pressed:
					_set_time_mode("dusk")
				else:
					train.target_throttle = minf(1.2, train.target_throttle + 0.15)
			KEY_S, KEY_DOWN:
				train.target_throttle = maxf(-0.3, train.target_throttle - 0.15)
			KEY_E: _set_time_mode("night")
			KEY_R: _set_time_mode("dusk")
			KEY_SPACE:
				train.trigger_whistle()
				_check_station_interaction()

func _check_station_interaction() -> void:
	var target_idx := dropoff_idx if has_cargo else pickup_idx
	var st_u: float = village.stations[target_idx]["u"]
	var du := absf(fposmod(train.progress_u - st_u + 0.5, 1.0) - 0.5)
	if du < 0.065:
		if not has_cargo:
			has_cargo = true
			train.steam_pressure = minf(100.0, train.steam_pressure + 35.0)
			_update_station_rings()
			_show_toast("✅ 已裝載貨物！前往「%s」卸貨 (+35%% 蒸汽)" % village.stations[dropoff_idx]["name"])
		else:
			deliveries += 1
			var night_bonus := 2 if time_mode == "night" else 1
			var pts := 100 * combo * night_bonus
			score += pts
			combo = mini(5, combo + 1)
			train.steam_pressure = minf(100.0, train.steam_pressure + 45.0)
			_show_toast("🎉 任務完成！送達「%s」 +%d 分 (連擊 x%d)" % [village.stations[dropoff_idx]["name"], pts, combo])
			_assign_new_mission()

func _process(delta: float) -> void:
	elapsed += delta
	terrain.update_terrain(delta, elapsed)
	village.update_village(delta, elapsed)
	train.update_train(delta)

	for c in clouds:
		var ang: float = c.get_meta("angle") + delta * 0.008
		var dist: float = c.get_meta("dist")
		c.set_meta("angle", ang)
		c.position = Vector3(cos(ang) * dist, c.get_meta("base_y") + sin(elapsed * 0.4 + ang) * 0.5, sin(ang) * dist)

	# Auto-pickup/dropoff if train slows down inside the station beacon
	var target_idx := dropoff_idx if has_cargo else pickup_idx
	var st_u: float = village.stations[target_idx]["u"]
	var du := absf(fposmod(train.progress_u - st_u + 0.5, 1.0) - 0.5)
	if du < 0.04 and absf(train.speed_u) < 0.020:
		_check_station_interaction()

	_update_camera(delta)
	_update_hud(delta, du)

func _update_camera(delta: float) -> void:
	if cam_mode == "orbit":
		var cx := sin(orbit_yaw) * cos(orbit_pitch) * orbit_dist
		var cy := sin(orbit_pitch) * orbit_dist + 4.0
		var cz := cos(orbit_yaw) * cos(orbit_pitch) * orbit_dist
		camera.position = camera.position.lerp(Vector3(cx, cy, cz), clampf(delta * 8.0, 0.0, 1.0))
		camera.look_at(Vector3(0, 3.0, 0), Vector3.UP)
	elif cam_mode == "train3rd":
		var tp := train.loco.to_global(Vector3(0, 4.2, 7.2))
		var tl := train.loco.to_global(Vector3(0, 1.5, -6.0))
		camera.position = camera.position.lerp(tp, clampf(delta * 6.0, 0.0, 1.0))
		camera.look_at(tl, Vector3.UP)
	elif cam_mode == "train1st":
		camera.position = train.loco.to_global(Vector3(0, 2.25, -0.5))
		camera.look_at(train.loco.to_global(Vector3(0, 1.6, -12.0)), Vector3.UP)
	elif cam_mode == "airship":
		var ap := village.airship_node.to_global(Vector3(-1.5, -3.3, 1.4))
		camera.position = camera.position.lerp(ap, clampf(delta * 5.0, 0.0, 1.0))
		camera.look_at(Vector3(0, 4.5, 0), Vector3.UP)

func _update_hud(delta: float, target_du := 1.0) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and hud_toast_box:
			hud_toast_box.visible = false

	var cargo_name: String = CARGO_NAMES[deliveries % CARGO_NAMES.size()]
	if hud_mission:
		var near_hint := "  🔔 已進站！請按 [空白鍵]！" if target_du < 0.065 else ""
		if not has_cargo:
			hud_mission.text = "📦 待取貨物：%s%s\n📍 前往「%s」減速或按空白鍵鳴笛裝載" % [cargo_name, near_hint, village.stations[pickup_idx]["name"]]
		else:
			hud_mission.text = "🚂 運送中：%s%s\n🎯 送往「%s」減速或按空白鍵鳴笛卸貨" % [cargo_name, near_hint, village.stations[dropoff_idx]["name"]]

	if hud_stats:
		var kmh := int(absf(train.speed_u) * 1400.0)
		hud_stats.text = "積分: %d  |  已送達: %d  |  蒸汽壓力: %d%%  |  時速: %d km/h\n操作: W/S 加減速 · 空白鍵 鳴笛/裝卸 · 1-4 視角 · Q/R/E 日/昏/夜" % [
			score, deliveries, int(train.steam_pressure), kmh
		]
