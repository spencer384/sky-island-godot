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

# === 擴充遊戲機制 ===
var day_cycle_timer := 0.0
var auto_day_cycle := true # 自動日夜循環 (晴朗白晝 -> 金色黃昏 -> 星夜燈火)
var time_left := 45.0      # 任務倒數計時
var coin_items: Array[Node3D] = []
var sheep_animals: Array[Node3D] = []
var passenger_count := 0
var tourist_happiness := 100

const CARGO_LIST := [
	{ "name": "阿里山高山茶", "type": "cargo", "desc": "茶香四溢的珍貴茶箱" },
	{ "name": "天文星圖手稿", "type": "cargo", "desc": "紀錄天空島星系的古代星圖" },
	{ "name": "風車磨坊全麥粉", "type": "cargo", "desc": "村莊烘焙不可或缺的麵粉" },
	{ "name": "飛艇航空特快信件", "type": "cargo", "desc": "蓋有天空郵局戳印的加急信" },
	{ "name": "天空島觀光旅行團", "type": "passengers", "desc": "喜愛老火車與雲海風光的遊客" }
]

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
	_spawn_track_coins(curve)
	_spawn_village_sheep()
	_set_time_mode("day")
	_assign_new_mission()

func _spawn_track_coins(curve: Curve3D) -> void:
	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#ffd700")
	gold_mat.metallic = 0.8
	gold_mat.roughness = 0.25
	gold_mat.emission_enabled = true
	gold_mat.emission = Color("#ffaa00")
	gold_mat.emission_energy_multiplier = 0.8

	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 0.12
	cm.radial_segments = 12

	var total_len := curve.get_baked_length()
	for i in range(12):
		var u := (float(i) + 0.5) / 12.0
		var pos := curve.sample_baked(u * total_len) + Vector3(0, 0.65, 0)
		var coin := MeshInstance3D.new()
		coin.mesh = cm
		coin.material_override = gold_mat
		coin.position = pos
		coin.rotation.x = PI * 0.5
		coin.set_meta("u", u)
		coin.set_meta("active", true)
		add_child(coin)
		coin_items.append(coin)

func _spawn_village_sheep() -> void:
	var wool_mat := StandardMaterial3D.new()
	wool_mat.albedo_color = Color("#ffffff")
	wool_mat.roughness = 0.95
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Color("#222222")

	var coords := [
		Vector2(-5.0, 4.0),
		Vector2(2.5, 6.5),
		Vector2(-8.0, -8.0),
		Vector2(6.0, -2.0)
	]
	for pos in coords:
		var y := SkyTerrain3D.get_terrain_height(pos.x, pos.y)
		var sheep := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.55
		bm.height = 1.0
		body.mesh = bm
		body.material_override = wool_mat
		body.position.y = 0.55
		body.scale = Vector3(1.0, 0.9, 1.25)
		sheep.add_child(body)

		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.26
		hm.height = 0.5
		head.mesh = hm
		head.material_override = face_mat
		head.position = Vector3(0, 0.68, 0.55)
		sheep.add_child(head)

		sheep.position = Vector3(pos.x, y, pos.y)
		sheep.set_meta("base_y", y)
		sheep.set_meta("rot_speed", randf_range(0.2, 0.6))
		add_child(sheep)
		sheep_animals.append(sheep)

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
	time_left = 50.0 # 每次新任務提供 50 秒倒數
	var current_cargo: Dictionary = CARGO_LIST[deliveries % CARGO_LIST.size()]
	if current_cargo["type"] == "passengers":
		passenger_count = randi_range(6, 16)
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
		var cargo_info: Dictionary = CARGO_LIST[deliveries % CARGO_LIST.size()]
		if not has_cargo:
			has_cargo = true
			train.steam_pressure = minf(100.0, train.steam_pressure + 35.0)
			_update_station_rings()
			if cargo_info["type"] == "passengers":
				_show_toast("🚂 %d 位遊客已上車！開往「%s」觀光並鳴笛下車 (+35%% 蒸汽)" % [passenger_count, village.stations[dropoff_idx]["name"]])
			else:
				_show_toast("📦 已裝載「%s」！開往「%s」卸貨 (+35%% 蒸汽)" % [cargo_info["name"], village.stations[dropoff_idx]["name"]])
		else:
			deliveries += 1
			var night_bonus := 2 if time_mode == "night" else 1
			var speed_bonus := int(time_left * 5.0) # 速度獎勵
			var pts := (120 * combo * night_bonus) + speed_bonus
			score += pts
			combo = mini(5, combo + 1)
			train.steam_pressure = minf(100.0, train.steam_pressure + 45.0)
			_show_toast("🎉 準時送達「%s」！獲得 +%d 分 (連擊 x%d, 速度獎勵 +%d)" % [village.stations[dropoff_idx]["name"], pts, combo, speed_bonus])
			_assign_new_mission()

func _process(delta: float) -> void:
	elapsed += delta
	terrain.update_terrain(delta, elapsed)
	village.update_village(delta, elapsed)
	train.update_train(delta)

	# 自動晝夜時間流轉
	if auto_day_cycle:
		day_cycle_timer += delta
		if day_cycle_timer > 35.0:
			day_cycle_timer = 0.0
			var next_mode := "dusk" if time_mode == "day" else ("night" if time_mode == "dusk" else "day")
			_set_time_mode(next_mode)
			_show_toast("☀️ 天色轉換：%s" % ("晴朗白晝" if next_mode == "day" else ("金色黃昏" if next_mode == "dusk" else "星夜燈火")))

	# 任務倒數計時
	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
		if time_left == 0.0 and combo > 1:
			combo = 1
			_show_toast("⚠️ 任務逾時！連擊倍率重置為 x1")

	# 動畫：鐵軌金幣旋轉與收集
	for coin in coin_items:
		if coin.get_meta("active"):
			coin.rotation.y += delta * 3.5
			var cu: float = coin.get_meta("u")
			var c_du := absf(fposmod(train.progress_u - cu + 0.5, 1.0) - 0.5)
			if c_du < 0.015:
				coin.set_meta("active", false)
				coin.visible = false
				score += 25
				train.steam_pressure = minf(100.0, train.steam_pressure + 8.0)
				_show_toast("🪙 獲得金幣！+25分 (+8% 蒸汽)")

	# 動畫：悠閒小羊微擺動
	for sheep in sheep_animals:
		var by: float = sheep.get_meta("base_y")
		sheep.position.y = by + absf(sin(elapsed * 2.0)) * 0.08
		sheep.rotation.y += delta * sheep.get_meta("rot_speed") * 0.3

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

	var cargo_info: Dictionary = CARGO_LIST[deliveries % CARGO_LIST.size()]
	if hud_mission:
		var near_hint := "  🔔 已進站！請按 [空白鍵]！" if target_du < 0.065 else ""
		var timer_str := "  ⏱️ 限時：%d秒" % int(time_left)
		var item_text: String = ""
		if not has_cargo:
			item_text = "%s (%s)" % [cargo_info["name"], cargo_info["desc"]]
			hud_mission.text = "📦 待取任務：%s%s\n📍 前往「%s」減速或按空白鍵裝載%s" % [
				item_text, timer_str, village.stations[pickup_idx]["name"], near_hint
			]
		else:
			if cargo_info["type"] == "passengers":
				item_text = "%s (%d 人)" % [cargo_info["name"], passenger_count]
			else:
				item_text = cargo_info["name"]
			hud_mission.text = "🚂 運送中：%s%s\n🎯 送往「%s」減速或按空白鍵卸貨%s" % [
				item_text, timer_str, village.stations[dropoff_idx]["name"], near_hint
			]

	if hud_stats:
		var kmh := int(absf(train.speed_u) * 1400.0)
		var mode_zh := "晴朗白晝" if time_mode == "day" else ("金色黃昏" if time_mode == "dusk" else "星夜燈火")
		hud_stats.text = "積分: %d  |  送達: %d次  |  連擊: x%d  |  蒸汽: %d%%  |  時速: %d km/h  |  天色: %s\n操作: W/S 加減速 · 空白鍵 鳴笛/裝卸 · 1-4 視角 · Q/R/E 手動切換天色" % [
			score, deliveries, combo, int(train.steam_pressure), kmh, mode_zh
		]
