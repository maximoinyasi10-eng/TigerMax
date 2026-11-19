extends Node3D

# TIGER CITY 3D — playable Godot 4 prototype
# A deliberately lightweight, mobile-friendly city/strategy sandbox.

const GRID_SIZE := 18
const TILE_SIZE := 3.0

var money := 5000
var population := 0
var energy := 0
var water := 0
var selected := "road"
var hover_pos := Vector2i.ZERO
var occupied := {}

@onready var world := Node3D.new()
@onready var camera := Camera3D.new()
@onready var terrain := MeshInstance3D.new()
@onready var ui := CanvasLayer.new()
@onready var label := Label.new()
@onready var status := Label.new()
@onready var info := PanelContainer.new()

func _ready() -> void:
	add_child(world)
	world.name = "City"
	_build_terrain()
	_setup_camera()
	_setup_ui()
	_seed_city()

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
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	info.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	label.text = "TIGER CITY 3D"
	label.add_theme_font_size_override("font_size", 20)
	box.add_child(label)
	status.text = ""
	box.add_child(status)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for item in ["Road", "House", "Shop", "Hospital", "Tower", "Tank", "Wall"]:
		var button := Button.new()
		button.text = item
		button.pressed.connect(_choose.bind(item.to_lower()))
		buttons.add_child(button)
	ui.add_child(info)

func _choose(name: String) -> void:
	selected = name
	status.text = "Selected: %s" % name.to_upper()

func _process(delta: float) -> void:
	_update_status()
	_handle_camera(delta)

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
	status.text = "MONEY %d  |  PEOPLE %d  |  POWER %d  |  WATER %d  |  BUILD: %s" % [money, population, energy, water, selected.to_upper()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.y = max(12.0, camera.position.y - 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.y = min(55.0, camera.position.y + 3.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_place_from_mouse()

func _place_from_mouse() -> void:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	var y := 0.0
	if abs(direction.y) < 0.001:
		return
	var distance := (y - origin.y) / direction.y
	var point := origin + direction * distance
	var gx := roundi(point.x / TILE_SIZE)
	var gz := roundi(point.z / TILE_SIZE)
	if abs(gx) > GRID_SIZE / 2 or abs(gz) > GRID_SIZE / 2:
		return
	var key := Vector2i(gx, gz)
	if occupied.has(key):
		return
	var cost := 40
	match selected:
		"house": cost = 220
		"shop": cost = 300
		"hospital": cost = 700
		"tower": cost = 600
		"tank": cost = 900
		"wall": cost = 120
	if money < cost:
		return
	money -= cost
	occupied[key] = selected
	_build_object(selected, Vector3(gx * TILE_SIZE, 0.0, gz * TILE_SIZE))

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
			money += 60
		"hospital":
			_add_box(root, Vector3(2.5, 2.2, 2.2), Color("e6ece7"), Vector3(0, 1.1, 0))
			_add_cross(root)
			population += 30
		"tower":
			_add_box(root, Vector3(1.7, 5.5, 1.7), Color("59666a"), Vector3(0, 2.75, 0))
			_add_box(root, Vector3(2.3, 0.35, 2.3), Color("9a4d3f"), Vector3(0, 5.65, 0))
		"tank":
			_add_box(root, Vector3(2.4, 0.65, 1.8), Color("65704d"), Vector3(0, 0.45, 0))
			_add_cylinder(root, 0.75, 1.8, Color("566143"), Vector3(0.3, 1.15, 0), Vector3(0, 0, 90))
			_add_cylinder(root, 0.35, 2.2, Color("3e4635"), Vector3(1.2, 1.15, 0), Vector3(0, 0, 90))
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

func _add_cylinder(parent: Node3D, radius: float, depth: float, color: Color, position: Vector3, rotation: Vector3) -> void:
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
	mesh_instance.rotation_degrees = rotation
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
