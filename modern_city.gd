extends Node3D

const TILE := 3.0
const GRID_SIZE := 17
const SAVE_PATH := "user://tiger_city_modern.save"

var money := 35000
var population := 620
var jobs := 260
var happiness := 82
var power := 800
var water := 650
var level := 1
var xp := 0
var selected := "house"
var mission_index := 0
var tick := 0.0
var occupied: Dictionary = {}
var units: Array[Dictionary] = []
var civilians: Array[Dictionary] = []

@onready var world: Node3D = Node3D.new()
@onready var camera: Camera3D = Camera3D.new()
@onready var ui: CanvasLayer = CanvasLayer.new()
@onready var status: Label = Label.new()
@onready var mission: Label = Label.new()
@onready var tigress: Label = Label.new()

var missions: Array[Dictionary] = [
	{"text": "Tigress: Jenga nyumba 5 ili watu wapate makazi.", "goal": "house", "need": 5, "reward": 5000},
	{"text": "Tigress: Jenga shule, hospitali na mfumo wa maji.", "goal": "services", "need": 3, "reward": 7500},
	{"text": "Maximo: Andaa vikosi 5 kwa ulinzi wa jiji.", "goal": "army", "need": 5, "reward": 10000}
]

func _ready() -> void:
	add_child(world)
	_build_world()
	_setup_camera()
	_setup_ui()
	_seed_city()
	_spawn_army()
	_spawn_civilians(18)
	_update_mission()
	_update_status()

func _build_world() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_SIZE * TILE * 2.0, GRID_SIZE * TILE * 2.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("17251f")
	ground_material.roughness = 0.82
	ground.material_override = ground_material
	world.add_child(ground)

	var sun := DirectionalLight3D.new()
	sun.position = Vector3(-25, 34, -24)
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.4
	add_child(sun)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("667f86")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cad7d4")
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color("789097")
	environment.fog_density = 0.003
	environment_node.environment = environment
	add_child(environment_node)

	for x in range(-8, 9):
		_add_road(Vector3(x * TILE, 0.02, 0.0))
	for z in range(-8, 9):
		_add_road(Vector3(0.0, 0.02, z * TILE))

func _setup_camera() -> void:
	camera.position = Vector3(31.0, 38.0, 34.0)
	camera.look_at(Vector3.ZERO)
	camera.fov = 46.0
	add_child(camera)

func _setup_ui() -> void:
	add_child(ui)

	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 8.0
	top.offset_right = -8.0
	top.offset_top = 8.0
	top.offset_bottom = 76.0
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_margin.add_theme_constant_override("margin_top", 6)
	top_margin.add_theme_constant_override("margin_bottom", 6)
	top.add_child(top_margin)
	var top_box := VBoxContainer.new()
	top_margin.add_child(top_box)
	status.text = ""
	status.add_theme_font_size_override("font_size", 15)
	mission.text = ""
	mission.add_theme_font_size_override("font_size", 13)
	top_box.add_child(status)
	top_box.add_child(mission)
	ui.add_child(top)

	var hero := PanelContainer.new()
	hero.position = Vector2(8.0, 82.0)
	hero.size = Vector2(310.0, 118.0)
	var hero_margin := MarginContainer.new()
	hero_margin.add_theme_constant_override("margin_left", 12)
	hero_margin.add_theme_constant_override("margin_right", 12)
	hero_margin.add_theme_constant_override("margin_top", 8)
	hero_margin.add_theme_constant_override("margin_bottom", 8)
	hero.add_child(hero_margin)
	var hero_box := VBoxContainer.new()
	hero_margin.add_child(hero_box)
	var title := Label.new()
	title.text = "TIGRESS  |  MAXIMO: Kamanda wa Jeshi"
	title.add_theme_font_size_override("font_size", 15)
	hero_box.add_child(title)
	tigress.text = ""
	tigress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_box.add_child(tigress)
	ui.add_child(hero)

	var dock := PanelContainer.new()
	dock.anchor_left = 0.0
	dock.anchor_right = 1.0
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = 8.0
	dock.offset_right = -8.0
	dock.offset_top = -68.0
	dock.offset_bottom = -8.0
	var dock_margin := MarginContainer.new()
	dock.add_child(dock_margin)
	var row := HBoxContainer.new()
	dock_margin.add_child(row)
	for item in ["House", "Apartment", "Shop", "Bank", "Hospital", "School", "Solar", "Water", "Road", "Wall", "Truck", "Train", "Drone", "Soldier", "Tank", "Save", "Load"]:
		var button := Button.new()
		button.text = item
		button.custom_minimum_size = Vector2(76.0, 42.0)
		button.pressed.connect(_choose.bind(item.to_lower()))
		row.add_child(button)
	ui.add_child(dock)

func _choose(kind: String) -> void:
	if kind == "save":
		_save_game()
	elif kind == "load":
		_load_game()
	else:
		selected = kind
		_update_status()

func _process(delta: float) -> void:
	tick += delta
	_handle_camera(delta)
	_process_units(delta)
	_process_civilians(delta)
	_process_missions()
	if tick >= 6.0:
		tick = 0.0
		money += int(population / 25) + _count_kind("bank") * 350 + _count_kind("shop") * 130
	_update_status()

func _handle_camera(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_action_pressed("ui_left"):
		move.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		move.x += 1.0
	if Input.is_action_pressed("ui_up"):
		move.z -= 1.0
	if Input.is_action_pressed("ui_down"):
		move.z += 1.0
	if move != Vector3.ZERO:
		camera.position += move.normalized() * 18.0 * delta
		camera.look_at(Vector3.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.y = max(12.0, camera.position.y - 2.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.y = min(52.0, camera.position.y + 2.5)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_place()
	elif event is InputEventScreenTouch and event.pressed:
		_place()

func _screen_cell() -> Variant:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	if abs(direction.y) < 0.001:
		return null
	var point := origin + direction * (-origin.y / direction.y)
	var cell := Vector2i(roundi(point.x / TILE), roundi(point.z / TILE))
	if abs(cell.x) > GRID_SIZE or abs(cell.y) > GRID_SIZE:
		return null
	return cell

func _place() -> void:
	var value: Variant = _screen_cell()
	if value == null:
		return
	var cell: Vector2i = value
	if occupied.has(cell):
		for unit in units:
			if unit["team"] == "player":
				unit["target"] = Vector3(cell.x * TILE, 0.0, cell.y * TILE)
		return
	var cost := _cost(selected)
	if money < cost:
		mission.text = "Pesa hazitoshi kwa %s." % selected
		return
	if selected in ["soldier", "tank", "drone"]:
		_spawn_unit("player", selected, cell)
	else:
		_add_structure(selected, cell)
	money -= cost
	_update_status()

func _cost(kind: String) -> int:
	match kind:
		"house": return 900
		"apartment": return 1800
		"shop": return 1200
		"bank": return 3000
		"hospital": return 2600
		"school": return 2200
		"solar": return 2400
		"water": return 2000
		"road": return 120
		"wall": return 350
		"truck": return 1300
		"train": return 3200
		"drone": return 2200
		"soldier": return 850
		"tank": return 3800
		_: return 150

func _add_structure(kind: String, cell: Vector2i) -> void:
	var position := Vector3(cell.x * TILE, 0.0, cell.y * TILE)
	occupied[cell] = kind
	match kind:
		"house":
			_build_modern(position, Vector3(2.2, 2.2, 2.2), Color("d1cfb8")); population += 55
		"apartment":
			_build_modern(position, Vector3(2.8, 8.0, 2.6), Color("6f7b7a")); population += 220; jobs += 20
		"shop":
			_build_modern(position, Vector3(2.5, 2.8, 2.2), Color("3d5955")); jobs += 35
		"bank":
			_build_modern(position, Vector3(3.0, 6.2, 2.8), Color("1d2527")); jobs += 90
		"hospital":
			_build_modern(position, Vector3(3.4, 3.6, 2.8), Color("deded2")); population += 20
		"school":
			_build_modern(position, Vector3(3.4, 3.1, 2.8), Color("b4b89e")); happiness += 5
		"solar":
			_add_solar(position); power += 500
		"water":
			_add_water(position); water += 400
		"road":
			_add_road(position)
		"wall":
			_add_wall(position)
		"truck", "train":
			_spawn_transport(position, kind)

func _build_modern(position: Vector3, size: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.position = position
	world.add_child(root)
	_add_box(root, size, color, Vector3(0.0, size.y / 2.0, 0.0))
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(size.x + 0.28, 0.20, size.z + 0.28)
	roof.mesh = roof_mesh
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("090b0b")
	roof_material.metallic = 0.4
	roof.material_override = roof_material
	roof.position = Vector3(0.0, size.y + 0.1, 0.0)
	root.add_child(roof)

func _add_solar(position: Vector3) -> void:
	var root := Node3D.new()
	root.position = position
	world.add_child(root)
	for x in [-0.8, 0.0, 0.8]:
		var panel := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(0.65, 0.05, 1.8)
		panel.mesh = panel_mesh
		var panel_material := StandardMaterial3D.new()
		panel_material.albedo_color = Color("17384a")
		panel_material.metallic = 0.6
		panel.material_override = panel_material
		panel.position = Vector3(x, 1.2, 0.0)
		panel.rotation_degrees = Vector3(-28.0, 0.0, 0.0)
		root.add_child(panel)

func _add_water(position: Vector3) -> void:
	var root := Node3D.new()
	root.position = position
	world.add_child(root)
	_add_box(root, Vector3(2.0, 5.5, 2.0), Color("4d5c58"), Vector3(0.0, 2.75, 0.0))
	_add_box(root, Vector3(2.4, 0.5, 2.4), Color("8b9a94"), Vector3(0.0, 5.7, 0.0))

func _add_road(position: Vector3) -> void:
	_add_pad(position, Vector3(2.8, 0.06, 2.8), Color("25292a"))

func _add_wall(position: Vector3) -> void:
	_add_pad(position + Vector3(0.0, 0.8, 0.0), Vector3(2.8, 1.6, 0.45), Color("60645f"))

func _add_pad(position: Vector3, size: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.position = position
	world.add_child(root)
	_add_box(root, size, color, Vector3.ZERO)

func _add_box(parent: Node3D, size: Vector3, color: Color, position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material
	mesh_instance.position = position
	parent.add_child(mesh_instance)

func _seed_city() -> void:
	for cell in [Vector2i(-4,-3), Vector2i(-3,-3), Vector2i(3,-3), Vector2i(4,-2), Vector2i(-3,3), Vector2i(3,3), Vector2i(-5,4)]:
		occupied[cell] = "house"
		_build_modern(Vector3(cell.x * TILE, 0.0, cell.y * TILE), Vector3(2.2, 2.2, 2.2), Color("b7b69f"))
		population += 55
	for cell in [Vector2i(5,-5), Vector2i(-6,-4)]:
		occupied[cell] = "shop"
		_build_modern(Vector3(cell.x * TILE, 0.0, cell.y * TILE), Vector3(2.5, 2.8, 2.2), Color("3d5955"))
		jobs += 35

func _spawn_army() -> void:
	_spawn_unit("enemy", "tank", Vector2i(8, 7))
	_spawn_unit("enemy", "soldier", Vector2i(7, 7))
	_spawn_unit("enemy", "soldier", Vector2i(7, 6))
	_spawn_unit("player", "tank", Vector2i(-7, -7))
	_spawn_unit("player", "soldier", Vector2i(-6, -7))

func _spawn_unit(team: String, kind: String, cell: Vector2i) -> void:
	var root := Node3D.new()
	root.position = Vector3(cell.x * TILE, 0.0, cell.y * TILE)
	world.add_child(root)
	var color := Color("536a50") if team == "player" else Color("93464a")
	if kind == "tank":
		_add_box(root, Vector3(2.2, 0.65, 1.6), color, Vector3(0.0, 0.42, 0.0))
		_add_box(root, Vector3(0.8, 0.45, 0.8), color.darkened(0.15), Vector3(0.2, 0.95, 0.0))
	elif kind == "drone":
		_add_box(root, Vector3(0.8, 0.18, 1.6), color, Vector3(0.0, 3.5, 0.0))
		root.position.y = 3.5
	else:
		_add_box(root, Vector3(0.55, 1.12, 0.48), color, Vector3(0.0, 0.58, 0.0))
		_add_box(root, Vector3(0.42, 0.42, 0.42), Color("b6a383"), Vector3(0.0, 1.34, 0.0))
	units.append({"node": root, "team": team, "kind": kind, "health": 200.0 if kind == "tank" else 125.0, "target": root.position, "cooldown": 0.0})

func _spawn_transport(position: Vector3, kind: String) -> void:
	var root := Node3D.new()
	root.position = position
	world.add_child(root)
	if kind == "train":
		_add_box(root, Vector3(3.0, 0.8, 1.2), Color("27383b"), Vector3(0.0, 0.5, 0.0))
		_add_box(root, Vector3(1.2, 1.1, 1.1), Color("42575a"), Vector3(0.8, 1.15, 0.0))
	else:
		_add_box(root, Vector3(2.3, 0.9, 1.1), Color("26383b"), Vector3(0.0, 0.55, 0.0))
		_add_box(root, Vector3(0.9, 0.8, 1.2), Color("465a5c"), Vector3(0.7, 1.2, 0.0))

func _spawn_civilians(count: int) -> void:
	for i in range(count):
		var root := Node3D.new()
		root.position = Vector3(randf_range(-18.0, 18.0), 0.0, randf_range(-18.0, 18.0))
		world.add_child(root)
		_add_box(root, Vector3(0.28, 0.8, 0.28), [Color("68787a"), Color("8a6f63")][i % 2], Vector3(0.0, 0.4, 0.0))
		civilians.append({"node": root, "target": Vector3(randf_range(-20.0, 20.0), 0.0, randf_range(-20.0, 20.0)), "speed": randf_range(1.2, 2.2)})

func _process_civilians(delta: float) -> void:
	for person in civilians:
		if not is_instance_valid(person["node"]):
			continue
		var node: Node3D = person["node"]
		var offset: Vector3 = person["target"] - node.position
		offset.y = 0.0
		if offset.length() < 1.0:
			person["target"] = Vector3(randf_range(-20.0, 20.0), 0.0, randf_range(-20.0, 20.0))
		else:
			node.position += offset.normalized() * person["speed"] * delta
			node.rotation.y = atan2(offset.x, offset.z)

func _process_units(delta: float) -> void:
	for i in range(units.size() - 1, -1, -1):
		var unit: Dictionary = units[i]
		var node: Node3D = unit["node"]
		if not is_instance_valid(node):
			units.remove_at(i)
			continue
		var target: Dictionary = _nearest_enemy(unit)
		if not target.is_empty():
			var enemy: Node3D = target["node"]
			if node.position.distance_to(enemy.position) < 4.5:
				unit["cooldown"] = max(0.0, float(unit["cooldown"]) - delta)
				if float(unit["cooldown"]) <= 0.0:
					target["health"] = float(target["health"])- (30.0 if unit["kind"] == "tank" else 15.0)
					unit["cooldown"] = 0.9
					if float(target["health"]) <= 0.0:
						enemy.queue_free()
						units.erase(target)
						xp += 20
				continue
			if unit["team"] == "enemy":
				unit["target"] = enemy.position
		var offset: Vector3 = unit["target"] - node.position
		offset.y = 0.0
		if offset.length() > 0.5:
			var speed := 4.2 if unit["kind"] == "tank" else 5.5
			node.position += offset.normalized() * speed * delta
	_check_level()

func _nearest_enemy(unit: Dictionary) -> Dictionary:
	var node: Node3D = unit["node"]
	var found: Dictionary = {}
	var best := 4.5
	for other in units:
		if other["team"] == unit["team"] or not is_instance_valid(other["node"]):
			continue
		var distance := node.position.distance_to(other["node"].position)
		if distance < best:
			best = distance
			found = other
	return found

func _count_kind(kind: String) -> int:
	var count := 0
	for cell in occupied:
		if occupied[cell] == kind:
			count += 1
	return count

func _count_team(team: String) -> int:
	var count := 0
	for unit in units:
		if unit["team"] == team:
			count += 1
	return count

func _process_missions() -> void:
	if mission_index >= missions.size():
		return
	var mission_data: Dictionary = missions[mission_index]
	var complete := false
	match mission_data["goal"]:
		"house": complete = _count_kind("house") + _count_kind("apartment") >= mission_data["need"]
		"services": complete = _count_kind("hospital") + _count_kind("school") + _count_kind("water") >= mission_data["need"]
		"army": complete = _count_team("player") >= mission_data["need"]
	if complete:
		money += int(mission_data["reward"])
		xp += 30
		mission_index += 1
		level += 1
		_update_mission()

func _check_level() -> void:
	if xp >= 100:
		xp -= 100
		level += 1
		money += 2500
		_update_mission()

func _update_mission() -> void:
	if mission_index >= missions.size():
		mission.text = "Campaign complete - sandbox ya jiji na jeshi ipo wazi"
		igress.text = "Tigress: Jiji limeanza safari ya maendeleo."
	else:
		mission.text = "TASK %d: %s" % [mission_index + 1, missions[mission_index]["text"]]
		tigress.text = missions[mission_index]["text"]

func _update_status() -> void:
	status.text = "TIGER CITY | LV %d | XP %d/100 | $%d | POP %d | JOBS %d | HAPPY %d%% | POWER %d | WATER %d | ARMY %d" % [level, xp % 100, money, population, jobs, happiness, power, water, _count_team("player")]

func _save_game() -> void:
	var building_data: Array = []
	for cell in occupied:
		building_data.append([cell.x, cell.y, occupied[cell]])
	var data := {"money": money, "population": population, "jobs": jobs, "happiness": happiness, "power": power, "water": water, "level": level, "xp": xp, "mission": mission_index, "buildings": building_data}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		mission.text = "Game saved on this device"

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	occupied.clear()
	money = int(data.get("money", 35000))
	population = int(data.get("population", 620))
	jobs = int(data.get("jobs", 260))
	happiness = int(data.get("happiness", 82))
	power = int(data.get("power", 800))
	water = int(data.get("water", 650))
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	mission_index = int(data.get("mission", 0))
	for child in world.get_children():
		child.queue_free()
	for entry in data.get("buildings", []):
		if entry is Array and entry.size() == 3:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			occupied[cell] = str(entry[2])
			_add_structure(str(entry[2]), cell)
	_update_mission()
	_update_status()
	mission.text = "Game loaded"
