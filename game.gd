extends Node3D

const GRID_SIZE := 18
const TILE_SIZE := 3.0
const SAVE_PATH := "user://tiger_city_mobile.save"

var money := 18000
var population := 0
var level := 1
var xp := 0
var tax := 0
var trade := 0
var selected := "house"
var occupied: Dictionary = {}
var units: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var transport: Array[Dictionary] = []
var mission_index := 0
var mission_started := false
var elapsed := 0.0

@onready var world := Node3D.new()
@onready var camera := Camera3D.new()
@onready var terrain := MeshInstance3D.new()
@onready var ui := CanvasLayer.new()
@onready var status := Label.new()
@onready var dialogue := Label.new()
@onready var mission_label := Label.new()

var missions: Array[Dictionary] = [
	{"name":"Jenga ardhi mpya", "text":"Tigress: Karibu, Kamanda. Jenga nyumba 3 ili mji uanze.", "goal":"houses", "need":3, "reward":1800},
	{"name":"Wajumbe wa kwanza", "text":"Ajiri askari 2 na vifaru 1 kwa ulinzi.", "goal":"army", "need":3, "reward":2600},
	{"name":"Mfumo wa biashara", "text":"Jenga maduka 3 na usafirishaji ili mapato yawe thabiti.", "goal":"trade", "need":3, "reward":3500},
	{"name":"Ulinzi wa mji", "text":"Tekelea wilaya zote tatu kabla adui anavunja uzuri wa jiji.", "goal":"zones", "need":3, "reward":5000}
]

func _ready() -> void:
	InputMap.action_add_event("ui_left", _key(KEY_A))
	InputMap.action_add_event("ui_right", _key(KEY_D))
	InputMap.action_add_event("ui_up", _key(KEY_W))
	InputMap.action_add_event("ui_down", _key(KEY_S))
	add_child(world)
	world.name = "TIGER_CITY"
	_build_world()
	_setup_camera()
	_setup_ui()
	_seed_city()
	_setup_zones()
	_spawn_enemy_units()
	_update_dialogue()
	_update_status()

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event

func _build_world() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_SIZE * TILE_SIZE, GRID_SIZE * TILE_SIZE)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	terrain.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("111713")
	mat.roughness = 0.92
	terrain.material_override = mat
	world.add_child(terrain)

	var sun := DirectionalLight3D.new()
	sun.position = Vector3(-25, 34, -24)
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.35
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("171e25")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7fa0a1")
	environment.ambient_light_energy = 0.7
	environment.fog_enabled = true
	environment.fog_light_color = Color("24302f")
	environment.fog_density = 0.004
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	# City roads
	for x in range(-7, 8):
		_add_world_box(Vector3(x * TILE_SIZE, 0.015, 0), Vector3(2.7, 0.05, 2.7), Color("202020"), "road")
	for z in range(-6, 7):
		_add_world_box(Vector3(0, 0.02, z * TILE_SIZE), Vector3(2.7, 0.05, 2.7), Color("202020"), "road")

func _setup_camera() -> void:
	camera.position = Vector3(28, 35, 32)
	camera.look_at(Vector3.ZERO)
	camera.fov = 48
	add_child(camera)

func _setup_ui() -> void:
	add_child(ui)

	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 8
	top.offset_bottom = 76
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
	top_box.add_child(status)
	mission_label.add_theme_font_size_override("font_size", 13)
	top_box.add_child(mission_label)
	ui.add_child(top)

	var character_card := PanelContainer.new()
	character_card.position = Vector2(10, 84)
	character_card.size = Vector2(270, 145)
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 12)
	cm.add_theme_constant_override("margin_right", 12)
	cm.add_theme_constant_override("margin_top", 10)
	cm.add_theme_constant_override("margin_bottom", 10)
	character_card.add_child(cm)
	var cb := VBoxContainer.new()
	cm.add_child(cb)
	var name_label := Label.new()
	name_label.text = "TIGRESS"
	name_label.add_theme_font_size_override("font_size", 18)
	cb.add_child(name_label)
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.text = ""
	cb.add_child(dialogue)
	var maximo := Label.new()
	maximo.text = "MAXIMO — Kamanda wa Jeshi"
	maximo.add_theme_font_size_override("font_size", 12)
	cb.add_child(maximo)
	ui.add_child(character_card)

	var menu := PanelContainer.new()
	menu.anchor_left = 0.0
	menu.anchor_right = 1.0
	menu.anchor_top = 1.0
	menu.anchor_bottom = 1.0
	menu.offset_left = 8
	menu.offset_right = -8
	menu.offset_top = -66
	menu.offset_bottom = -8
	var mm := MarginContainer.new()
	mm.add_theme_constant_override("margin_left", 5)
	mm.add_theme_constant_override("margin_right", 5)
	mm.add_theme_constant_override("margin_top", 5)
	mm.add_theme_constant_override("margin_bottom", 5)
	menu.add_child(mm)
	var row := HBoxContainer.new()
	mm.add_child(row)
	for item in ["House", "Shop", "Bank", "Tower", "Wall", "Truck", "Train", "Plane", "Soldier", "Tank", "Save", "Load"]:
		var button := Button.new()
		button.text = item
		button.custom_minimum_size = Vector2(82, 42)
		button.pressed.connect(_choose.bind(item.to_lower()))
		row.add_child(button)
	ui.add_child(menu)

	var touch := PanelContainer.new()
	touch.position = Vector2(10, get_viewport().get_visible_rect().size.y - 150)
	touch.size = Vector2(130, 78)
	var tl := Label.new()
	tl.text = "�� ▶\n● ◎"
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 20)
	tm.add_theme_constant_override("margin_top", 8)
	tm.add_child(tl)
	touch.add_child(tm)
	ui.add_child(touch)

func _choose(item: String) -> void:
	match item:
		"save": _save_game(); return
		"load": _load_game(); return
	selected = item
	update_mission_text()

func _process(delta: float) -> void:
	elapsed += delta
	_handle_camera(delta)
	_process_units(delta)
	_process_zones(delta)
	if int(elapsed) % 5 == 0:
		var old_second := int(elapsed - delta) % 5
		if old_second != 0:
			money += tax + trade
			update_status()
	_check_missions()
	update_status()

func _handle_camera(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("left"): move.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("right"): move.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("forward"): move.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("back"): move.z += 1
	if move != Vector3.ZERO:
		camera.position += move.normalized() * 16.0 * delta
		camera.look_at(Vector3.ZERO)

func update_status() -> void:
	if not is_instance_valid(status): return
	status.text = "TIGER CITY  |  LEVEL %d  |  XP %d/100  |  SHL %d  |  POP %d  |  TAX %d  |  TRADE %d  |  ARMY %d  |  BUILD %s" % [level, xp % 100, money, population, tax, trade, count_team("player"), selected.to_upper()]

func update_mission_text() -> void:
	if mission_index >= missions.size():
		mission_label.text = "Tigress: Jiji lako limekamilisha kampeni ya kwanza. Endelea kukua!"
		return
	var mission: Dictionary = missions[mission_index]
	mission_label.text = "MISHAO: %s — %s" % [mission["name"], mission["text"]]

func _update_dialogue() -> void:
	var text := ""
	if mission_index == 0:
		text = "Tigress: Mimi ni Tigress. Nitakusimamia mpaka jiji lililomo katika level ya kwanza litekelezwe."
	elif mission_index == 1:
		text = "Tigress: Level %d! Maximo anashika uongozi wa jeshi. Jenga nguvu bila kuyaharibu raia." % level
	elif mission_index == 2:
		text = "Tigress: Tendo la biashara ndilo moyo wa ufalme. Jenga maduka na magari ya mizigo."
	elif mission_index == 3:
		text = "Tigress: Hatima ya jiji la TIGER imelingania. Tekeleza wilaya zote."
	else:
		text = "Tigress: Jiji limekua. Maximo: Vikosi ni tayari kwa majukumu mapya."
	dialogue.text = text

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.y = max(12.0, camera.position.y - 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.y = min(55.0, camera.position.y + 3.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_place_from_touch()
	elif event is InputEventScreenTouch and event.pressed:
		_place_from_touch()

func screen_to_cell() -> Variant:
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	if abs(direction.y) < 0.001: return null
	var distance := -origin.y / direction.y
	var point := origin + direction * distance
	var cell := Vector2i(roundi(point.x / TILE_SIZE), roundi(point.z / TILE_SIZE))
	if abs(cell.x) > 9 or abs(cell.y) > 9: return null
	return cell

func _place_from_touch() -> void:
	var value: Variant = screen_to_cell()
	if value == null: return
	var cell: Vector2i = value
	if occupied.has(cell):
		for unit in units:
			if unit["team"] == "player": unit["target"] = Vector3(cell.x * TILE_SIZE, 0, cell.y * TILE_SIZE)
		return
	var cost := building_cost(selected)
	if money < cost:
		return
	if selected in ["soldier", "tank"]:
		_recruit(selected, cell, cost)
	else:
		_build(selected, cell)
		money -= cost
		update_status()

func building_cost(kind: String) -> int:
	match kind:
		"house": return 800
		"shop": return 1200
		"bank": return 2200
		"tower": return 1600
		"wall": return 300
		"truck": return 900
		"train": return 2400
		"plane": return 3500
		"soldier": return 700
		"tank": return 1800
		_: return 180

func _build(kind: String, cell: Vector2i) -> void:
	var pos := Vector3(cell.x * TILE_SIZE, 0, cell.y * TILE_SIZE)
	occupied[cell] = kind
	match kind:
		"house":
			_add_building(pos, Vector3(2.2, 2.4, 2.2), Color("d7d0c1")); population += 40
		"shop":
			_add_building(pos, Vector3(2.5, 2.0, 2.2), Color("667f78")); trade += 120
		"bank":
			_add_building(pos, Vector3(3.0, 4.2, 2.6), Color("1f2527")); trade += 300
		"tower":
			_add_building(pos, Vector3(1.8, 7.0, 1.8), Color("30383a")); tax += 100
		"wall":
			_add_world_box(pos + Vector3(0, 0.8, 0), Vector3(2.8, 1.6, 0.5), Color("555a57"), "wall")
		"truck":
			_spawn_transport(pos, kind); trade += 180
		"train":
			_spawn_transport(pos, kind); trade += 400
		"plane":
			_spawn_transport(pos, kind); trade += 700
		"road":
			_add_world_box(pos, Vector3(2.8, 0.08, 2.8), Color("262626"), "road")

func _add_building(pos: Vector3, size: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	world.add_child(root)
	_add_box(root, size, color, Vector3(0, size.y * 0.5, 0))
	var crown := MeshInstance3D.new()
	var roof := BoxMesh.new()
	roof.size = Vector3(size.x + 0.3, 0.25, size.z + 0.3)
	crown.mesh = roof
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("080a0a"); mat.metallic = 0.35
	crown.material_override = mat
	crown.position = Vector3(0, size.y + 0.12, 0)
	root.add_child(crown)
	for i in range(-1, 2):
		var window_mesh := MeshInstance3D.new()
		var window_geo := BoxMesh.new(); window_geo.size = Vector3(0.28, 0.38, 0.05)
		window_mesh.mesh = window_geo
		var wm := StandardMaterial3D.new(); wm.albedo_color = Color("c0d4cc"); wm.emission_enabled = true; wm.emission = Color("5d8f88"); wm.emission_energy_multiplier = 0.4
		window_mesh.material_override = wm
		window_mesh.position = Vector3(i * 0.55, size.y * 0.55, -size.z * 0.51)
		root.add_child(window_mesh)

func _add_world_box(pos: Vector3, size: Vector3, color: Color, key: String) -> void:
	var root := Node3D.new(); root.position = pos; world.add_child(root)
	_add_box(root, size, color, Vector3.ZERO)

func _add_box(parent: Node3D, size: Vector3, color: Color, position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = 0.8
	mesh_instance.material_override = mat
	mesh_instance.position = position
	parent.add_child(mesh_instance)

func _seed_city() -> void:
	for x in range(-3, 4):
		occupied[Vector2i(x, 0)] = "road"
	for z in range(-3, 4):
		occupied[Vector2i(0, z)] = "road"
	for p in [Vector2i(-3,-3), Vector2i(-2,-3), Vector2i(2,-2), Vector2i(3,-2), Vector2i(-2,2), Vector2i(2,2), Vector2i(-3,3)]:
		occupied[p] = "house"
		_add_building(Vector3(p.x * TILE_SIZE, 0, p.y * TILE_SIZE), Vector3(2.2, 2.2, 2.2), Color("bbb69f") )
		population += 40

func _setup_zones() -> void:
	for c in [Vector2i(6,5), Vector2i(-6,5), Vector2i(7,-5)]:
		var root := Node3D.new(); root.position = Vector3(c.x*TILE_SIZE, 0.05, c.y*TILE_SIZE); world.add_child(root)
		var marker := MeshInstance3D.new(); var mesh := CylinderMesh.new(); mesh.top_radius=2.2; mesh.bottom_radius=2.2; mesh.height=0.08
		marker.mesh=mesh; var mat:=StandardMaterial3D.new(); mat.albedo_color=Color("b3a34b"); marker.material_override=mat
		root.add_child(marker)
		zones.append({"node":root,"marker":marker,"owner":"neutral","progress":0.0})

func _spawn_enemy_units() -> void:
	_spawn_unit("enemy", "soldier", Vector2i(8,8))
	_spawn_unit("enemy", "tank", Vector2i(8,7))

func _recruit(kind: String, cell: Vector2i, cost: int) -> void:
	if kind == "soldier" and population < 10: return
	money -= cost
	population = max(0, population - 10)
	_spawn_unit("player", kind, cell)

func _spawn_unit(team: String, kind: String, cell: Vector2i) -> void:
	var root := Node3D.new(); root.position=Vector3(cell.x*TILE_SIZE,0,cell.y*TILE_SIZE); world.add_child(root)
	var color:=Color("536b52") if team=="player" else Color("93494a")
	if kind=="tank":
		_add_box(root,Vector3(2.3,.65,1.7),color,Vector3(0,.4,0)); _add_cylinder(root,Vector3(.75,.75,.75),color,Vector3(0,1,0))
	else:
		_add_box(root,Vector3(.55,1.1,.48),color,Vector3(0,.55,0)); _add_cylinder(root,Vector3(.25,.32,.25),Color("bba17d"),Vector3(0,1.25,0))
	units.append({"node":root,"team":team,"kind":kind,"health":180.0 if kind=="tank" else 100.0,"target":root.position,"cooldown":0.0})

func _add_cylinder(parent: Node3D, size: Vector3, color: Color, position: Vector3) -> void:
	var m:=MeshInstance3D.new(); var g:=SphereMesh.new(); g.radius=size.x; g.height=size.y*2
	m.mesh=g; var mat:=StandardMaterial3D.new(); mat.albedo_color=color; m.material_override=mat; m.position=position; parent.add_child(m)

func _spawn_transport(pos: Vector3, kind: String) -> void:
	var root:=Node3D.new(); root.position=pos; world.add_child(root)
	var color:=Color("1d2d32")
	if kind=="train": _add_box(root,Vector3(3.0,.8,1.2),color,Vector3(0,.5,0)); _add_box(root,Vector3(1.1,1.2,1.1),Color("303d40"),Vector3(.8,1.2,0))
	elif kind=="plane": _add_box(root,Vector3(3.2,.25,.7),color,Vector3(0,3.5,0)); _add_box(root,Vector3(.8,.8,.8),color,Vector3(.5,3.5,0)); root.position.y=3.5
	else: _add_box(root,Vector3(2.2,.9,1.1),color,Vector3(0,.55,0)); _add_box(root,Vector3(.9,.8,1.2),Color("3d4c4c"),Vector3(.7,1.2,0))
	transport.append({"node":root,"kind":kind,"phase":randf()*TAU})

func _process_units(delta: float) -> void:
	for i in range(units.size()-1,-1,-1):
		var u:Dictionary=units[i]; var node:Node3D=u["node"]
		if not is_instance_valid(node): units.remove_at(i); continue
		var target:Dictionary=_nearest_opponent(u)
		if not target.is_empty():
			var tn:Node3D=target["node"]; var d:=node.position.distance_to(tn.position)
			if d<4.2:
				u["cooldown"]=max(0.0,float(u["cooldown"])-delta)
				if float(u["cooldown"])<=0:
					target["health"]=float(target["health"])-(28.0 if u["kind"]=="tank" else 15.0)
					u["cooldown"]=1.0
					if float(target["health"])<=0:
						tn.queue_free(); units.erase(target); xp+=20
				continue
			if u["team"]=="enemy": u["target"]=tn.position
		var offset:Vector3=Vector3(u["target"].x-node.position.x,0,u["target"].z-node.position.z)
		if offset.length()>0.5:
			var speed:=3.8 if u["kind"]=="tank" else 4.8
			node.position+=offset.normalized()*speed*delta
			node.rotation.y=atan2(offset.x,offset.z)
	_check_level()

func _nearest_opponent(u:Dictionary)->Dictionary:
	var near:Dictionary={}; var best:=4.3; var node:Node3D=u["node"]
	for o in units:
		if o["team"]==u["team"] or not is_instance_valid(o["node"]): continue
		var d:=node.position.distance_to(o["node"].position)
		if d<best: best=d; near=o
	return near

func _process_zones(delta:float)->void:
	for z in zones:
		var center:Vector3=z["node"].position; var p:=false; var e:=false
		for u in units:
			if not is_instance_valid(u["node"]): continue
			if u["node"].position.distance_to(center)<3.4:
				if u["team"]=="player": p=true
				else: e=true
		if p and not e: z["progress"]=min(100.0,float(z["progress"])+20*delta)
		elif e and not p: z["progress"]=max(-100.0,float(z["progress"])-20*delta)
		if float(z["progress"])>=100 and z["owner"]!="player":
			z["owner"]="player"; z["marker"].material_override=_zone_material("player"); tax+=250; xp+=15
		elif float(z["progress"])<=-100 and z["owner"]!="enemy":
			z["owner"]="enemy"; z["marker"].material_override=_zone_material("enemy")

func _zone_material(owner:String)->StandardMaterial3D:
	var mat:=StandardMaterial3D.new(); mat.albedo_color=Color("2878c7") if owner=="player" else Color("b33e3f") if owner=="enemy" else Color("b3a34b"); return mat

func count_team(team:String)->int:
	var n:=0
	for u in units:
		if u["team"]==team:n+=1
	return n

func _check_missions()->void:
	if mission_index>=missions.size(): return
	var m:Dictionary=missions[mission_index]; var done:=false
	match m["goal"]:
		"houses": done=_count_kind("house")>=m["need"]
		"army": done=count_team("player")>=m["need"]
		"trade": done=_count_kind("shop")+_count_kind("bank")>=m["need"]
		"zones": done=_captured_zones()>=m["need"]
	if done:
		money+=int(m["reward"]); xp+=25; level+=1; mission_index+=1
		_update_dialogue(); update_mission_text(); if mission_index>=missions.size(): mission_label.text="Campaign complete — continue sandbox mode"

func _count_kind(kind:String)->int:
	var n:=0
	for c in occupied:
		if occupied[c]==kind:n+=1
	return n

func _captured_zones()->int:
	var n:=0
	for z in zones:
		if z["owner"]=="player":n+=1
	return n

func _check_level()->void:
	if xp>=100:
		xp-=100; level+=1; money+=1000; _update_dialogue()

func _save_game()->void:
	var b:Array=[]
	for c in occupied:b.append([c.x,c.y,occupied[c]])
	var u:Array=[]
	for unit in units:
		if is_instance_valid(unit["node"]):
			var p:Vector3=unit["node"].position
			u.append({"team":unit["team"],"kind":unit["kind"],"x":p.x,"z":p.z,"health":unit["health"]})
	var z:Array=[]
	for zone in zones:z.append({"owner":zone["owner"],"progress":zone["progress"]})
	var data={"money":money,"population":population,"level":level,"xp":xp,"tax":tax,"trade":trade,"buildings":b,"units":u,"zones":z,"mission":mission_index}
	var f:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data)); mission_label.text="Game saved"

func _load_game()->void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f:=FileAccess.open(SAVE_PATH,FileAccess.READ); if not f:return
	var result:=JSON.parse_string(f.get_as_text()); if not result is Dictionary:return
	var d:Dictionary=result
	money=int(d.get("money",18000)); population=int(d.get("population",0)); level=int(d.get("level",1)); xp=int(d.get("xp",0)); tax=int(d.get("tax",0)); trade=int(d.get("trade",0)); mission_index=int(d.get("mission",0)); occupied.clear()
	for c in world.get_children():
		if c!=terrain:c.queue_free()
	units.clear(); zones.clear(); transport.clear()
	for entry in d.get("buildings",[]):
		if entry is Array and entry.size()==3:
			var c:=Vector2i(int(entry[0]),int(entry[1]))
			occupied[c]=str(entry[2]); _build(str(entry[2]),c)
	_setup_zones()
	var zone_data:Array=d.get("zones",[])
	for i in range(mini(zones.size(),zone_data.size())):
		zones[i]["owner"]=str(zone_data[i].get("owner","neutral")); zones[i]["progress"]=float(zone_data[i].get("progress",0)); zones[i]["marker"].material_override=_zone_material(zones[i]["owner"])
	for unit in d.get("units",[]):
		if unit is Dictionary:
			var c:=Vector2i(roundi(float(unit.get("x",0))/TILE_SIZE),roundi(float(unit.get("z",0))/TILE_SIZE)); _spawn_unit(str(unit.get("team","player")),str(unit.get("kind","soldier")),c)
	_update_dialogue(); update_mission_text(); mission_label.text="Game loaded"
