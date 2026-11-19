extends Node3D

const SAVE_PATH := "user://tiger_city_modern.save"
const TILE := 3.0
const SIZE := 17

var money := 35000
var population := 620
var jobs := 260
var happiness := 82
var power := 800
var water := 650
var level := 1
var xp := 0
var selected := "tower"
var occupied: Dictionary = {}
var units: Array[Dictionary] = []
var civilians: Array[Dictionary] = []
var missions: Array[Dictionary] = []
var mission_index := 0
var tick := 0.0
var day_time := 0.32

@onready var world := Node3D.new()
@onready var camera := Camera3D.new()
@onready var ui := CanvasLayer.new()
@onready var status := Label.new()
@onready var tigress := Label.new()
@onready var mission := Label.new()

func _ready() -> void:
	add_child(world)
	_build_world()
	_setup_camera()
	_setup_ui()
	_setup_missions()
	_seed_city()
	_spawn_army()
	_spawn_civilians(18)
	_update_mission()
	_update_status()

func _build_world() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE * TILE * 2, SIZE * TILE * 2)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("17251f")
	mat.roughness = 0.82
	ground.material_override = mat
	world.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.6
	add_child(sun)
	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("667f86")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cad7d4")
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color("789097")
	environment.fog_density = 0.003
	env_node.environment = environment
	add_child(env_node)
	for x in range(-8, 9):
		_add_pad(Vector3(x * TILE, 0.02, 0), Vector3(2.8, 0.06, 2.8), Color("25292a"))
	for z in range(-8, 9):
		_add_pad(Vector3(0, 0.025, z * TILE), Vector3(2.8, 0.06, 2.8), Color("25292a"))

func _setup_camera() -> void:
	camera.position = Vector3(31, 38, 34)
	camera.look_at(Vector3.ZERO)
	camera.fov = 46
	add_child(camera)

func _setup_ui() -> void:
	add_child(ui)
	var top := PanelContainer.new()
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 8
	top.offset_bottom = 75
	top.anchor_right = 1.0
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	top.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	status.add_theme_font_size_override("font_size", 15)
	box.add_child(status)
	mission.add_theme_font_size_override("font_size", 13)
	box.add_child(mission)
	ui.add_child(top)

	var hero := PanelContainer.new()
	hero.position = Vector2(8, 82)
	hero.size = Vector2(310, 118)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 12)
	hm.add_theme_constant_override("margin_right", 12)
	hm.add_theme_constant_override("margin_top", 8)
	hm.add_theme_constant_override("margin_bottom", 8)
	hero.add_child(hm)
	var hb := VBoxContainer.new()
	hm.add_child(hb)
	var title := Label.new()
	title.text = "TIGRESS  |  MAXIMO: Kamanda wa Jeshi"
	title.add_theme_font_size_override("font_size", 15)
	hb.add_child(title)
	tigress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMANT if TextServer.has_method("WRAP_WORD") else TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(tigress)
	ui.add_child(hero)

	var dock := PanelContainer.new()
	dock.anchor_left = 0.0
	dock.anchor_right = 1.0
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = 8
	dock.offset_right = -8
	dock.offset_top = -68
	dock.offset_bottom = -8
	var dm := MarginContainer.new()
	dock.add_child(dm)
	var row := HBoxContainer.new()
	dm.add_child(row)
	for item in ["House","Apartment","Shop","Bank","Hospital","School","Solar","Water","Road","Wall","Truck","Train","Drone","Soldier","Tank","Save","Load"]:
		var button := Button.new()
		button.text = item
		button.custom_minimum_size = Vector2(76, 42)
		button.pressed.connect(_choose.bind(item.to_lower()))
		row.add_child(button)
	ui.add_child(dock)

func _setup_missions() -> void:
	missions = [
		{"text":"Tigress: Karibu mji wa kisasa. Jenga nyumba 5 ili watu waanze kutulia.","goal":"house","need":5,"reward":5000},
		{"text":"Tigress: Jenga mifumo ya maji, shule na hospitali.","goal":"services","need":3,"reward":7500},
		{"text":"Maximo: Andaa jeshi, treni na magari ya vifaa.","goal":"army","need":5,"reward":10000},
		{"text":"Tigress: Tekeleza wilaya tatu na udumishe mpango wa jiji.","goal":"capture","need":3,"reward":15000}
	]

func _choose(kind: String) -> void:
	if kind == "save": _save_game(); return
	if kind == "load": _load_game(); return
	selected = kind
	_update_status()

func _process(delta: float) -> void:
	tick += delta
	day_time = fmod(day_time + delta * 0.002, 1.0)
	_handle_camera(delta)
	_process_units(delta)
	_process_civilians(delta)
	_process_missions()
	if tick >= 6.0:
		tick = 0.0
		var tax := population / 25
		var trade := _count_kind("bank") * 350 + _count_kind("shop") * 130
		money += tax + trade
	_update_status()

func _handle_camera(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("left"): move.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("right"): move.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("up"): move.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("down"): move.z += 1
	if move != Vector3.ZERO:
		camera.position += move.normalized() * 18.0 * delta
		camera.look_at(Vector3.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.position.y = max(12.0, camera.position.y - 2.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.position.y = min(52.0, camera.position.y + 2.5)
		elif event.button_index == MOUSE_BUTTON_LEFT: _place()
	elif event is InputEventScreenTouch and event.pressed:
		_place()

func _screen_cell() -> Variant:
	var pos := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(pos)
	var direction := camera.project_ray_normal(pos)
	if abs(direction.y) < 0.001: return null
	var point := origin + direction * (-origin.y / direction.y)
	var cell := Vector2i(roundi(point.x / TILE), roundi(point.z / TILE))
	if abs(cell.x) > SIZE or abs(cell.y) > SIZE: return null
	return cell

func _place() -> void:
	var value: Variant = _screen_cell()
	if value == null: return
	var cell: Vector2i = value
	var cost := _cost(selected)
	if money < cost:
		mission.text = "Pesa hazitoshi kwa %s." % selected
		return
	if occupied.has(cell):
		for unit in units:
			if unit["team"] == "player": unit["target"] = Vector3(cell.x * TILE, 0, cell.y * TILE)
		return
	if selected in ["soldier","tank","drone"]:
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
	var pos := Vector3(cell.x * TILE, 0, cell.y * TILE)
	occupied[cell] = kind
	match kind:
		"house":
			_build_modern(pos, Vector3(2.2,2.2,2.2), Color("d1cfb8")); population += 55
		"apartment":
			_build_modern(pos, Vector3(2.8,8.0,2.6), Color("6f7b7a")); population += 220; jobs += 20
		"shop":
			_build_modern(pos, Vector3(2.5,2.8,2.2), Color("3d5955")); jobs += 35
		"bank":
			_build_modern(pos, Vector3(3.0,6.2,2.8), Color("1d2527")); jobs += 90
		"hospital":
			_build_modern(pos, Vector3(3.4,3.6,2.8), Color("deded2")); population += 20
		"school":
			_build_modern(pos, Vector3(3.4,3.1,2.8), Color("b4b89e")); happiness += 5
		"solar":
			_add_solar(pos); power += 500
		"water":
			_add_tower(pos); water += 400
		"road":
			_add_pad(pos, Vector3(2.8,0.08,2.8), Color("242829"))
		"wall":
			_add_pad(pos + Vector3(0,0.8,0), Vector3(2.8,1.6,0.45), Color("60645f"))
		"truck","train":"
			_spawn_transport(pos, kind)

func _build_modern(pos: Vector3, size: Vector3, color: Color) -> void:
	var root := Node3D.new(); root.position = pos; world.add_child(root)
	_add_box(root, size, color, Vector3(0,size.y/2,0))
	var roof := MeshInstance3D.new(); var geo := BoxMesh.new(); geo.size = Vector3(size.x+0.28,0.20,size.z+0.28)
	roof.mesh = geo; var mat := StandardMaterial3D.new(); mat.albedo_color=Color("090b0b"); mat.metallic=0.4; roof.material_override=mat
	roof.position=Vector3(0,size.y+0.1,0); root.add_child(roof)
	for i in range(-1,2):
		if size.y < 3: continue
		var win := MeshInstance3D.new(); var wg:=BoxMesh.new(); wg.size=Vector3(.42,min(.6,size.y/5),.05); win.mesh=wg
		var wm:=StandardMaterial3D.new(); wm.albedo_color=Color("91b5bb"); wm.emission_enabled=true; wm.emission=Color("5f9da7"); wm.emission_energy_multiplier=.35
		win.material_override=wm; win.position=Vector3(i*.65,size.y*.55,-size.z*.51); root.add_child(win)

func _add_solar(pos: Vector3) -> void:
	var root:=Node3D.new(); root.position=pos; world.add_child(root)
	for x in [-.8,0,.8]:
		var panel:=MeshInstance3D.new(); var geo:=BoxMesh.new(); geo.size=Vector3(.65,.05,1.8); panel.mesh=geo
		var mat:=StandardMaterial3D.new(); mat.albedo_color=Color("17384a"); mat.metallic=.6; panel.material_override=mat
		panel.position=Vector3(x,1.2,0); panel.rotation_degrees=Vector3(-28,0,0); root.add_child(panel)

func _add_tower(pos: Vector3) -> void:
	var root:=Node3D.new(); root.position=pos; world.add_child(root)
	_add_box(root,Vector3(2.0,5.5,2.0),Color("4d5c58"),Vector3(0,2.75,0))
	_add_box(root,Vector3(2.4,.5,2.4),Color("8b9a94"),Vector3(0,5.7,0))

func _add_pad(pos: Vector3,size:Vector3,color:Color) -> void:
	var root:=Node3D.new(); root.position=pos; world.add_child(root); _add_box(root,size,color,Vector3.ZERO)

func _add_box(parent:Node3D,size:Vector3,color:Color,position:Vector3) -> void:
	var mesh:=MeshInstance3D.new(); var geo:=BoxMesh.new(); geo.size=size; mesh.mesh=geo
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=.82; mesh.material_override=mat
	mesh.position=position; parent.add_child(mesh)

func _seed_city() -> void:
	for p in [Vector2i(-4,-3),Vector2i(-3,-3),Vector2i(3,-3),Vector2i(4,-2),Vector2i(-3,3),Vector2i(3,3),Vector2i(-5,4)]:
		occupied[p]="house"; _build_modern(Vector3(p.x*TILE,0,p.y*TILE),Vector3(2.2,2.2,2.2),Color("b7b69f")); population+=55
	for p in [Vector2i(5,-5),Vector2i(-6,-4)]:
		occupied[p]="shop"; _build_modern(Vector3(p.x*TILE,0,p.y*TILE),Vector3(2.5,2.8,2.2),Color("3d5955")); jobs+=35

func _spawn_army() -> void:
	for c in [Vector2i(7,7),Vector2i(7,6),Vector2i(8,7)]: _spawn_unit("enemy","tank" if c==Vector2i(8,7) else "soldier",c)
	_spawn_unit("player","tank",Vector2i(-7,-7)); _spawn_unit("player","soldier",Vector2i(-6,-7))

func _spawn_unit(team:String,kind:String,cell:Vector2i) -> void:
	var root:=Node3D.new(); root.position=Vector3(cell.x*TILE,0,cell.y*TILE); world.add_child(root)
	var color:=Color("536a50") if team=="player" else Color("93464a")
	if kind=="tank":
		_add_box(root,Vector3(2.2,.65,1.6),color,Vector3(0,.42,0)); _add_box(root,Vector3(.8,.45,.8),color.darkened(.15),Vector3(.2,.95,0)); _add_box(root,Vector3(1.5,.12,.12),color.darkened(.2),Vector3(1,.95,0))
	elif kind=="drone":
		_add_box(root,Vector3(.8,.18,1.6),color,Vector3(0,3.5,0)); _add_box(root,Vector3(1.8,.08,.12),color,Vector3(0,3.5,0)); root.position.y=3.5
	else:
		_add_box(root,Vector3(.55,1.12,.48),color,Vector3(0,.58,0)); _add_box(root,Vector3(.42,.42,.42),Color("b6a383"),Vector3(0,1.34,0))
	units.append({"node":root,"team":team,"kind":kind,"health":200.0 if kind=="tank" else 125.0,"target":root.position,"cooldown":0.0})

func _spawn_transport(pos:Vector3,kind:String) -> void:
	var root:=Node3D.new(); root.position=pos; world.add_child(root)
	if kind=="train":
		_add_box(root,Vector3(3.0,.8,1.2),Color("27383b"),Vector3(0,.5,0)); _add_box(root,Vector3(1.2,1.1,1.1),Color("42575a"),Vector3(.8,1.15,0)); jobs+=20
	else:
		_add_box(root,Vector3(2.3,.9,1.1),Color("26383b"),Vector3(0,.55,0)); _add_box(root,Vector3(.9,.8,1.2),Color("465a5c"),Vector3(.7,1.2,0)); jobs+=10

func _spawn_civilians(count:int) -> void:
	for i in range(count):
		var root:=Node3D.new(); root.position=Vector3(randf_range(-18,18),0.0,randf_range(-18,18)); world.add_child(root)
		_add_box(root,Vector3(.28,.8,.28),Color(["#68787a","#8a6f63","#596d83","#777756"][i%4]),Vector3(0,.4,0))
		civilians.append({"node":root,"target":Vector3(randf_range(-20,20),0,randf_range(-20,20)),"speed":randf_range(1.2,2.2)})

func _process_civilians(delta:float) -> void:
	for person in civilians:
		if not is_instance_valid(person["node"]): continue
		var node:Node3D=person["node"]; var delta_pos:Vector3=person["target"]-node.position; delta_pos.y=0
		if delta_pos.length()<1.0:
			person["target"]=Vector3(randf_range(-20,20),0,randf_range(-20,20))
		else:
			node.position+=delta_pos.normalized()*person["speed"]*delta
			node.rotation.y=atan2(delta_pos.x,delta_pos.z)

func _process_units(delta:float) -> void:
	for i in range(units.size()-1,-1,-1):
		var u:Dictionary=units[i]; var node:Node3D=u["node"]
		if not is_instance_valid(node): units.remove_at(i); continue
		var target:Dictionary=_nearest_enemy(u)
		if not target.is_empty():
			var enemy:Node3D=target["node"]; var distance:=node.position.distance_to(enemy.position)
			if distance<4.5:
				u["cooldown"] = max(0.0,float(u["cooldown"])-delta)
				if float(u["cooldown"])<=0:
					target["health"]-=30.0 if u["kind"]=="tank" or u["kind"]=="drone" else 15.0
					u["cooldown"]=.9
					if float(target["health"])<=0:
						enemy.queue_free(); units.erase(target); xp+=20
				continue
			if u["team"]=="enemy": u["target"] = enemy.position
		var offset:Vector3=u["target"]-node.position; offset.y=0
		if offset.length()>.5:
			var speed:=4.2 if u["kind"]=="tank" else 5.5
			node.position+=offset.normalized()*speed*delta
	_check_level()

func _nearest_enemy(unit:Dictionary) -> Dictionary:
	var node:Node3D=unit["node"]; var best:=4.5; var found:Dictionary={}
	for other in units:
		if other["team"]==unit["team"] or not is_instance_valid(other["node"]): continue
		var d:=node.position.distance_to(other["node"].position)
		if d<best: best=d; found=other
	return found

func _count_kind(kind:String)->int:
	var n:=0
	for c in occupied:
		if occupied[c]==kind:n+=1
	return n

func _process_missions() -> void:
	if mission_index>=missions.size(): return
	var m:Dictionary=missions[mission_index]; var done:=false
	match m["goal"]:
		"house": done=_count_kind("house")+_count_kind("apartment")>=m["need"]
		"services": done=_count_kind("hospital")+_count_kind("school")+_count_kind("water")>=m["need"]
		"army": done=_count_team("player")>=m["need"]
		"capture": done=level>=4
	if done:
		money+=int(m["reward"]); xp+=30; mission_index+=1; level+=1
		_update_mission()

func _count_team(team:String)->int:
	var n:=0
	for u in units:
		if u["team"]==team:n+=1
	return n

func _check_level() -> void:
	if xp>=100:
		xp-=100; level+=1; money+=2500; _update_mission()

func _update_mission() -> void:
	if mission_index>=missions.size():
		mission.text="Campaign complete — sandbox ya jiji na jeshi ipo wazi"
	else:
		mission.text="TASK %d: %s" % [mission_index+1,missions[mission_index]["text"]]
		igress.text=missions[mission_index]["text"]

func _update_status() -> void:
	status.text="TIGER CITY | LV %d | XP %d/100 | $%d | POP %d | JOBS %d | HAPPY %d%% | POWER %d | WATER %d | ARMY %d" % [level,xp%100,money,population,jobs,happiness,power,water,_count_team("player")]

func _save_game() -> void:
	var building_data:Array=[]
	for c in occupied: building_data.append([c.x,c.y,occupied[c]])
	var data={"money":money,"population":population,"jobs":jobs,"happiness":happiness,"power":power,"water":water,"level":level,"xp":xp,"mission":mission_index,"buildings":building_data}
	var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data)); mission.text="Game saved on this device"

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file:=FileAccess.open(SAVE_PATH,FileAccess.READ); if not file:return
	var parsed:=JSON.parse_string(file.get_as_text()); if not parsed is Dictionary:return
	var d:Dictionary=parsed
	occupied.clear(); money=int(d.get("money",35000)); population=int(d.get("population",620)); jobs=int(d.get("jobs",260)); happiness=int(d.get("happiness",82)); power=int(d.get("power",800)); water=int(d.get("water",650)); level=int(d.get("level",1)); xp=int(d.get("xp",0)); mission_index=int(d.get("mission",0))
	for child in world.get_children(): child.queue_free()
	for entry in d.get("buildings",[]):
		if entry is Array and entry.size()==3:
			var c:=Vector2i(int(entry[0]),int(entry[1])); occupied[c]=str(entry[2]); _add_structure(str(entry[2]),c)
	_update_mission(); _update_status(); mission.text="Game loaded"
