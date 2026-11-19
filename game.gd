extends Node3D

# TIGER CITY 3D — playable Godot 4 city-builder/strategy prototype.
# Combat is abstract, fictional gameplay; no real-world tactical simulation.

const GRID_SIZE := 18
const TILE_SIZE := 3.0
const SAVE_PATH := "user://tiger_city_save.json"
const ZONE_CELLS: Array[Vector2i] = [Vector2i(5, 4), Vector2i(-5, 5), Vector2i(6, -4)]

var money := 5000
var population := 0
var energy := 0
var water := 0
var selected := "road"
var occupied: Dictionary = {}
var units: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var simulation_timer := 0.0
var message := "Build, recruit, and capture the marked districts."

@onready var world := Node3D.new()
@onready var camera := Camera3D.new()
@onready var terrain := MeshInstance3D.new()
@onready var ui := CanvasLayer.new()
@onready var title_label := Label.new()
@onready var status := Label.new()
@onready var info := PanelContainer.new()

func _ready() -> void:
	add_child(world)
	world.name = "City"
	_build_terrain()
	_setup_camera()
	_setup_ui()
	_seed_city()
	_setup_zones()
	_spawn_enemy_base()
	_update_status()

func _build_terrain() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE)
	plane.subdivide_width = 36
	plane.subdivide_depth = 36
	terrain.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3d5a45")
	mat.roughness = 0.9
	terrain.material_override = mat
	terrain.position = Vector3(0, -0.05, 0)
	world.add_child(terrain)

	var light := DirectionalLight3D.new()
	light.position = Vector3(-20, 30, -20)
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.shadow_enabled = true
	add_child(light)
	var env_light := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("91aaa3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bac7c2")
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = Color("91aaa3")
	environment.fog_density = 0.006
	env_light.environment = environment
	add_child(env_light)

func _setup_camera() -> void:
	camera.position = Vector3(26, 33, 26)
	camera.look_at(Vector3.ZERO)
	camera.fov = 42
	add_child(camera)

func _setup_ui() -> void:
	add_child(ui)
	info.position = Vector2(16, 16)
	info.size = Vector2(650, 140)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	info.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	title_label.text = "TIGER CITY 3D"
	title_label.add_theme_font_size_override("font_size", 20)
	box.add_child(title_label)
	status.text = ""
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	var buttons := GridContainer.new()
	buttons.columns = 6
	box.add_child(buttons)
	for item in ["Road", "House", "Shop", "Hospital", "Tower", "Wall", "Soldier", "Tank", "Orders"]:
		var button := Button.new()
		button.text = item
		button.pressed.connect(_choose.bind(item.to_lower()))
		buttons.add_child(button)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_game)
	buttons.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_load_game)
	buttons.add_child(load_button)
	ui.add_child(info)

func _choose(name: String) -> void:
	selected = name
	match selected:
		"soldier", "tank": message = "Choose an empty tile to recruit a %s." % selected
		"orders": message = "Click a destination tile to order friendly units there."
		_: message = "Choose an empty tile to build a %s." % selected
	_update_status()

func _process(delta: float) -> void:
	_handle_camera(delta)
	_advance_units(delta)
	_advance_zones(delta)
	simulation_timer += delta
	if simulation_timer >= 5.0:
		simulation_timer -= 5.0
		money += 25 + _owned_zone_count() * 40
		_update_status()

func _handle_camera(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_action_pressed("ui_left"):
		move.x -= 1
	if Input.is_action_pressed("ui_right"):
		move.x += 1
	if Input.is_action_pressed("ui_up"):
		move.z -= 1
	if Input.is_action_pressed("ui_down"):
		move.z += 1
	if move != Vector3.ZERO:
		camera.position += move.normalized() * 18.0 * delta
		camera.look_at(Vector3.ZERO)

func _update_status() -> void:
	if not is_instance_valid(status):
		return
	status.text = "MONEY %d | PEOPLE %d | FRIENDLY %d | ENEMY %d | DISTRICTS %d/%d | %s" % [money, population, _unit_count("player"), _unit_count("enemy"), _owned_zone_count(), zones.size(), message]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.y = max(12.0, camera.position.y - 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.y = min(55.0, camera.position.y + 3.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_place_from_mouse()

func _mouse_to_cell() -> Variant:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	if abs(direction.y) < 0.001:
		return null
	var point := origin + direction * ((-origin.y) / direction.y)
	var cell := Vector2i(roundi(point.x / TILE_SIZE), roundi(point.z / TILE_SIZE))
	if abs(cell.x) > GRID_SIZE / 2 or abs(cell.y) > GRID_SIZE / 2:
		return null
	return cell

func _place_from_mouse() -> void:
	var cell_value: Variant = _mouse_to_cell()
	if cell_value == null:
		return
	var cell: Vector2i = cell_value
	if selected == "orders":
		_order_friendly_units(cell)
		return
	if selected == "soldier" or selected == "tank":
		_recruit(selected, cell)
		return
	if occupied.has(cell):
		return
	var cost := _building_cost(selected)
	if money < cost:
		message = "Not enough money for that build."
		_update_status()
		return
	money -= cost
	occupied[cell] = selected
	_build_object(selected, Vector3(cell.x * TILE_SIZE, 0.0, cell.y * TILE_SIZE))
	message = "%s built." % selected.capitalize()
	_update_status()

func _building_cost(type_name: String) -> int:
	match type_name:
		"house": return 220
		"shop": return 300
		"hospital": return 700
		"tower": return 600
		"wall": return 120
		_: return 40

func _build_object(type_name: String, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	world.add_child(root)
	match type_name:
		"road":
			_add_box(root, Vector3(2.7, 0.08, 2.7), Color("30373a"), Vector3.ZERO)
			_add_box(root, Vector3(0.12, 0.09, 2.7), Color("d1bd6c"), Vector3.ZERO)
		"house":
			_add_box(root, Vector3(2.0, 1.5, 2.0), Color("d9c7a2"), Vector3(0, 0.75, 0))
			_add_roof(root)
			population += 24
		"shop":
			_add_box(root, Vector3(2.2, 1.8, 2.0), Color("b98758"), Vector3(0, 0.9, 0))
			population += 8
		"hospital":
			_add_box(root, Vector3(2.5, 2.2, 2.2), Color("e6ece7"), Vector3(0, 1.1, 0))
			_add_cross(root)
			population += 30
		"tower":
			_add_box(root, Vector3(1.7, 5.5, 1.7), Color("59666a"), Vector3(0, 2.75, 0))
			_add_box(root, Vector3(2.3, 0.35, 2.3), Color("9a4d3f"), Vector3(0, 5.65, 0))
		"wall":
			_add_box(root, Vector3(2.8, 1.2, 0.55), Color("7c8179"), Vector3(0, 0.6, 0))

func _add_box(parent: Node3D, size: Vector3, color: Color, position: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh_instance.material_override = mat
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_cylinder(parent: Node3D, radius: float, depth: float, color: Color, position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	mesh_instance.material_override = mat
	mesh_instance.position = position
	parent.add_child(mesh_instance)

func _add_roof(parent: Node3D) -> void:
	var roof := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(2.25, 0.9, 2.25)
	roof.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("70483a")
	roof.material_override = mat
	roof.position = Vector3(0, 2.0, 0)
	roof.rotation_degrees = Vector3(0, 45, 0)
	parent.add_child(roof)

func _add_cross(parent: Node3D) -> void:
	_add_box(parent, Vector3(1.1, 0.22, 0.22), Color("b63f3f"), Vector3(0, 2.8, -1.12))
	_add_box(parent, Vector3(0.22, 1.1, 0.22), Color("b63f3f"), Vector3(0, 2.8, -1.12))

func _seed_city() -> void:
	for x in range(-3, 4):
		_build_object("road", Vector3(x * TILE_SIZE, 0, 0))
		occupied[Vector2i(x, 0)] = "road"
	for z in range(-3, 4):
		_build_object("road", Vector3(0, 0, z * TILE_SIZE))
		occupied[Vector2i(0, z)] = "road"
	for p in [Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(2, -2), Vector2i(2, 2), Vector2i(-2, 2)]:
		_build_object("house", Vector3(p.x * TILE_SIZE, 0, p.y * TILE_SIZE))
		occupied[p] = "house"
	_build_object("tower", Vector3(3 * TILE_SIZE, 0, 3 * TILE_SIZE))
	occupied[Vector2i(3, 3)] = "tower"

func _recruit(kind: String, cell: Vector2i) -> void:
	var cost := 180 if kind == "soldier" else 650
	if money < cost:
		message = "Not enough money to recruit."
		_update_status()
		return
	money -= cost
	_spawn_unit("player", kind, cell)
	message = "%s recruited. Select Orders and click a destination." % kind.capitalize()
	_update_status()

func _spawn_unit(team: String, kind: String, cell: Vector2i, health := -1.0) -> void:
	var root := Node3D.new()
	root.position = Vector3(cell.x * TILE_SIZE, 0.0, cell.y * TILE_SIZE)
	world.add_child(root)
	var color := Color("68834e") if team == "player" else Color("9c5145")
	var max_health := 100.0 if kind == "soldier" else 180.0
	if health > 0.0:
		max_health = health
	if kind == "tank":
		_add_box(root, Vector3(2.25, 0.6, 1.65), color, Vector3(0, 0.42, 0))
		_add_cylinder(root, 0.65, 0.8, color.darkened(0.12), Vector3(0, 0.9, 0))
		_add_box(root, Vector3(1.6, 0.18, 0.18), color.darkened(0.2), Vector3(0.95, 0.92, 0))
	else:
		_add_box(root, Vector3(0.55, 1.15, 0.48), color, Vector3(0, 0.62, 0))
		_add_cylinder(root, 0.25, 0.32, Color("c4a783"), Vector3(0, 1.35, 0))
		_add_box(root, Vector3(0.12, 0.7, 0.12), Color("393d38"), Vector3(0.27, 0.65, -0.18))
	units.append({"node": root, "team": team, "kind": kind, "health": max_health, "target": root.position, "cooldown": 0.0})

func _order_friendly_units(cell: Vector2i) -> void:
	var target := Vector3(cell.x * TILE_SIZE, 0.0, cell.y * TILE_SIZE)
	for unit in units:
		if unit["team"] == "player":
			unit["target"] = target
	message = "Orders issued to friendly units."
	_update_status()

func _advance_units(delta: float) -> void:
	for i in range(units.size() - 1, -1, -1):
		var unit: Dictionary = units[i]
		var node: Node3D = unit["node"]
		if not is_instance_valid(node):
			units.remove_at(i)
			continue
		unit["cooldown"] = maxf(0.0, float(unit["cooldown"]) - delta)
		var target_unit: Dictionary = _nearest_enemy(unit)
		if not target_unit.is_empty():
			var enemy_node: Node3D = target_unit["node"]
			var distance := node.position.distance_to(enemy_node.position)
			if distance <= 4.2:
				if float(unit["cooldown"]) <= 0.0:
					target_unit["health"] = float(target_unit["health"]) - (26.0 if unit["kind"] == "tank" else 14.0)
					unit["cooldown"] = 1.0
					if float(target_unit["health"]) <= 0.0:
						message = "%s unit defeated." % String(target_unit["team"]).capitalize()
						enemy_node.queue_free()
						units.erase(target_unit)
						_update_status()
				continue
			if unit["team"] == "enemy":
				unit["target"] = enemy_node.position
		var destination: Vector3 = unit["target"]
		var offset := destination - node.position
		offset.y = 0.0
		if offset.length() > 0.4:
			var speed := 4.0 if unit["kind"] == "tank" else 5.0
			node.position += offset.normalized() * speed * delta
			node.rotation.y = atan2(offset.x, offset.z)
		elif unit["team"] == "enemy":
			unit["target"] = _enemy_objective(node.position)

func _nearest_enemy(unit: Dictionary) -> Dictionary:
	var closest: Dictionary = {}
	var best_distance := 4.2
	var node: Node3D = unit["node"]
	for other in units:
		if other["team"] == unit["team"] or not is_instance_valid(other["node"]):
			continue
		var distance: float = node.position.distance_to((other["node"] as Node3D).position)
		if distance < best_distance:
			best_distance = distance
			closest = other
	return closest

func _enemy_objective(from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := INF
	for zone in zones:
		if zone["owner"] != "enemy":
			var candidate: Vector3 = zone["node"].position
			var distance := from.distance_to(candidate)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best

func _setup_zones() -> void:
	zones.clear()
	for cell in ZONE_CELLS:
		var root := Node3D.new()
		root.position = Vector3(cell.x * TILE_SIZE, 0.03, cell.y * TILE_SIZE)
		world.add_child(root)
		var pad := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 2.15
		mesh.bottom_radius = 2.15
		mesh.height = 0.08
		pad.mesh = mesh
		pad.material_override = _zone_material("neutral")
		root.add_child(pad)
		_add_box(root, Vector3(0.12, 2.0, 0.12), Color("d9d4bc"), Vector3(0, 1.0, 0))
		_add_box(root, Vector3(0.8, 0.45, 0.08), Color("d9d4bc"), Vector3(0, 1.65, 0.06))
		zones.append({"cell": cell, "node": root, "pad": pad, "owner": "neutral", "progress": 0.0})

func _zone_material(owner: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	match owner:
		"player": mat.albedo_color = Color("397ac0")
		"enemy": mat.albedo_color = Color("b7473f")
		_: mat.albedo_color = Color("b6a74b")
	mat.roughness = 0.8
	return mat

func _advance_zones(delta: float) -> void:
	for zone in zones:
		var center: Vector3 = zone["node"].position
		var player_near := false
		var enemy_near := false
		for unit in units:
			if not is_instance_valid(unit["node"]):
				continue
			if (unit["node"] as Node3D).position.distance_to(center) <= 3.2:
				if unit["team"] == "player": player_near = true
				else: enemy_near = true
		if player_near and not enemy_near:
			zone["progress"] = minf(100.0, float(zone["progress"]) + 22.0 * delta)
		elif enemy_near and not player_near:
			zone["progress"] = maxf(-100.0, float(zone["progress"]) - 22.0 * delta)
		if float(zone["progress"]) >= 100.0 and zone["owner"] != "player":
			zone["owner"] = "player"
			zone["pad"].material_override = _zone_material("player")
			message = "District captured! It now generates income."
			_update_status()
		elif float(zone["progress"]) <= -100.0 and zone["owner"] != "enemy":
			zone["owner"] = "enemy"
			zone["pad"].material_override = _zone_material("enemy")
			message = "An enemy captured a district."
			_update_status()

func _owned_zone_count() -> int:
	var count := 0
	for zone in zones:
		if zone["owner"] == "player": count += 1
	return count

func _spawn_enemy_base() -> void:
	_spawn_unit("enemy", "soldier", Vector2i(7, 7))
	_spawn_unit("enemy", "soldier", Vector2i(8, 7))
	_spawn_unit("enemy", "tank", Vector2i(7, 8))

func _unit_count(team: String) -> int:
	var count := 0
	for unit in units:
		if unit["team"] == team: count += 1
	return count

func _save_game() -> void:
	var building_data: Array = []
	for cell in occupied:
		building_data.append([cell.x, cell.y, occupied[cell]])
	var unit_data: Array = []
	for unit in units:
		if not is_instance_valid(unit["node"]):
			continue
		var p: Vector3 = unit["node"].position
		unit_data.append({"team": unit["team"], "kind": unit["kind"], "x": p.x, "z": p.z, "health": unit["health"]})
	var zone_data: Array = []
	for zone in zones:
		zone_data.append({"owner": zone["owner"], "progress": zone["progress"]})
	var data := {"version": 1, "money": money, "population": population, "energy": energy, "water": water, "buildings": building_data, "units": unit_data, "zones": zone_data}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		message = "Save failed: %s" % error_string(FileAccess.get_open_error())
	else:
		file.store_string(JSON.stringify(data))
		message = "Game saved on this device."
	file = null
	_update_status()

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		message = "No save file on this device yet."
		_update_status()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		message = "Could not open save file."
		_update_status()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file = null
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		message = "Save file is invalid or from an unsupported version."
		_update_status()
		return
	var data: Dictionary = parsed
	_clear_city()
	occupied.clear()
	units.clear()
	money = 5000
	population = 0
	energy = 0
	water = 0
	for entry in data.get("buildings", []):
		if entry is Array and entry.size() == 3:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			var kind := str(entry[2])
			occupied[cell] = kind
			_build_object(kind, Vector3(cell.x * TILE_SIZE, 0, cell.y * TILE_SIZE))
	money = int(data.get("money", 5000))
	population = int(data.get("population", population))
	energy = int(data.get("energy", 0))
	water = int(data.get("water", 0))
	_setup_zones()
	var saved_zones: Array = data.get("zones", [])
	for i in range(mini(zones.size(), saved_zones.size())):
		var zone: Dictionary = zones[i]
		var saved: Dictionary = saved_zones[i]
		zone["owner"] = str(saved.get("owner", "neutral"))
		zone["progress"] = clampf(float(saved.get("progress", 0.0)), -100.0, 100.0)
		zone["pad"].material_override = _zone_material(zone["owner"])
	for saved_unit in data.get("units", []):
		if saved_unit is Dictionary:
			var cell := Vector2i(roundi(float(saved_unit.get("x", 0.0)) / TILE_SIZE), roundi(float(saved_unit.get("z", 0.0)) / TILE_SIZE))
			_spawn_unit(str(saved_unit.get("team", "player")), str(saved_unit.get("kind", "soldier")), cell, float(saved_unit.get("health", 100.0)))
	message = "Saved city loaded."
	_update_status()

func _clear_city() -> void:
	for child in world.get_children():
		if child != terrain:
			child.free()

func _add_box_to_dummy() -> void:
	pass
