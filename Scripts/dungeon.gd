extends Node3D

var tile_scene = load("res://Scenes/tile.tscn")
var wall_scene = load("res://Scenes/wall.tscn")

var tilemap = []
var sects = []

var max_room := 7
var max_strand := 20
var biggest_strand := 0

var room_data = []

var base_sect = {
					"doors":[],
					"pos":Vector2i(0,0),
					"made":false,
					"room":-1,
					"strand":0,
					"type":"room"
				}

var base_room = {
					"doors":[-1,-1,-1,-1],
					"pos":Vector2i(0,0),
					"made":false,
					"seen":false,
					"room":-1
				}

var tiles_y = 0
var tiles_x = 0

var minimum : Vector2i
var maximum : Vector2i

var total_rooms := 0
const MIN_ROOMS := 5
const MAX_STRAND_LENGTH := 5

const TILE_INCREMENT := sqrt(0.5)

func _ready() -> void:
	make_tile_map("new")
	

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Reset"):
		SceneLoader.load_level("res://Scenes/dungeon.tscn")

func build_tiles():
	$GridMap.clear()
	for y in range(len(tilemap)):
		for x in range(len(tilemap[y])):
			if tilemap[y][x] == "X":
				continue
			var new_tile : Node3D
			if tilemap[y][x] == "D":
				new_tile = wall_scene.instantiate()
				new_tile.type = "door"
				new_tile.position = Vector3(
					(x-y)*TILE_INCREMENT,
					0,
					(x+y)*TILE_INCREMENT,
				)
				$Ground.add_child(new_tile)
			else:
				if tilemap[y][x] == "W":
					$GridMap.set_cell_item(Vector3i(-y,0,x),1)
				else:
					$GridMap.set_cell_item(Vector3i(-y,0,x),0)
				

func get_sect(pos:Vector2i):
	var ret = -1
	for sect in range(len(sects)):
		if sects[sect]["pos"] == pos:
			ret = sect
	return ret

func make_tile_map(Ver:String) -> void:
	minimum = Vector2i(0,0)
	maximum = Vector2i(0,0)
	sects.clear()
	room_data.clear()
	tilemap.clear()
	for child in $Ground.get_children():
		child.queue_free()
	
	make_sect(Vector2i(0,0))
	
	var current_sect = 2
	while current_sect <= max_strand:
		for sect in sects:
			if sect["strand"] == current_sect:
				make_sect(sect["pos"])
				biggest_strand = current_sect
		current_sect += 1
	
	var rand = []
	for sect in sects:
		if sect["strand"] == biggest_strand && sect["type"] == "room":
			rand.append(sect["pos"])
	
	if len(rand) == 0 || biggest_strand <= max_strand - 5:
		make_tile_map("Remake")
		return
	
	sects[get_sect(rand[randi_range(0,len(rand)-1)])]["type"] = "exit"
		
	for sect in range(len(sects)):
		var new_doors = [0,0,0,0,]
		var pos = sects[sect]["pos"]
		var room = sects[sect]["room"]
		
		if sects[get_sect(Vector2i(pos.x-1,pos.y))]["room"] != room || get_sect(Vector2i(pos.x-1,pos.y)) == -1:
			new_doors[0] = 1
		if sects[get_sect(Vector2i(pos.x,pos.y-1))]["room"] != room || get_sect(Vector2i(pos.x,pos.y-1)) == -1:
			new_doors[1] = 1
		if sects[get_sect(Vector2i(pos.x+1,pos.y))]["room"] != room || get_sect(Vector2i(pos.x+1,pos.y)) == -1:
			new_doors[2] = 1
		if sects[get_sect(Vector2i(pos.x,pos.y+1))]["room"] != room || get_sect(Vector2i(pos.x,pos.y+1)) == -1:
			new_doors[3] = 1
	
		if sects[sect]["doors"] != []:
			for door in sects[sect]["doors"]:
				new_doors[door] = 2
		sects[sect]["doors"] = new_doors
	
	tilemap = RoomMaker.make_empty_map(sects)
	for sect in sects:
		tilemap = RoomMaker.append_sect(sect, tilemap)
	
	build_tiles()
	
	var origin_start_x = (-RoomMaker.min_pos.x) * (RoomMaker.sect_size + 1)
	var origin_start_y = (-RoomMaker.min_pos.y) * (RoomMaker.sect_size + 1)
	
	var middle_offset = float(RoomMaker.sect_size + 1) / 2.0
	
	var plrx: float = origin_start_x + middle_offset
	var plry: float = origin_start_y + middle_offset
	
	$Player.position = Vector3(
		(plrx - plry) * TILE_INCREMENT,
		5.0,
		(plrx + plry) * TILE_INCREMENT
	)


func make_sect(pos):
	var sect_num = get_sect(pos)
	if sect_num == -1:
		sect_num = 0
		var app = base_sect.duplicate(true)
		app["room"] = len(room_data)
		room_data.append(1)
		app["type"] = "enter"
		app["strand"] = 1
		sects.append(app)
	var sect = sects[sect_num]

		
	var to_make = [
		Vector2i(pos.x-1,pos.y),
		Vector2i(pos.x,pos.y-1),
		Vector2i(pos.x+1,pos.y),
		Vector2i(pos.x,pos.y+1),
	]
	
	for door in range(4):
		if get_sect(to_make[door])==-1:
			if randi_range(0,1) == 1:
				var new_sect = base_sect.duplicate(true)
				new_sect["pos"] = to_make[door]
				new_sect["room"] = sect["room"]
				if room_data[new_sect["room"]] >= max_room:
					new_sect["room"] = len(room_data)
					room_data.append(0)
					var new_door = door + 2
					if new_door >= 4:
						new_door -= 4
					sects[sect_num]["doors"].append(door)
					new_sect["doors"].append(new_door)
				room_data[new_sect["room"]] += 1
				new_sect["strand"] = sect["strand"] + 1
				sects.append(new_sect)
	
