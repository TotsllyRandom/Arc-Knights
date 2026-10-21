extends Node3D

var tile_scene = preload("res://Scenes/tile.tscn")
var wall_scene = preload("res://Scenes/wall.tscn")

var tilemap = []
var sects = []

var max_room := 7
var max_strand := 5

var room_data = []

var base_sect = {
					"doors":[],
					"pos":Vector2i(0,0),
					"made":false,
					"room":-1,
					"strand":0
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
	make_tile_map()
	#var plrx := (float(len(tilemap[0])-1))/2
	#var plry := (float(len(tilemap)-1))/2
	#$Player.position = Vector3(
	#	(plrx-plry) * TILE_INCREMENT,
	#	5,
	#	(plrx+plry) * TILE_INCREMENT
	#)
	

func build_tiles():
	for y in range(len(tilemap)):
		for x in range(len(tilemap[y])):
			if tilemap[y][x] == " ":
				continue
			var new_tile : Node3D
			if tilemap[y][x] == "W":
				new_tile = wall_scene.instantiate()
				new_tile.type = "wall"
			elif tilemap[y][x] == "D":
				new_tile = wall_scene.instantiate()
				new_tile.type = "door"
			else:
				new_tile = tile_scene.instantiate()
			new_tile.position = Vector3(
				(x-y)*TILE_INCREMENT,
				0,
				(x+y)*TILE_INCREMENT,
			)
			$Ground.add_child(new_tile)
				

func get_sect(pos:Vector2i):
	var ret = -1
	for sect in range(len(sects)):
		if sects[sect]["pos"] == pos:
			ret = sect
	return ret

func make_tile_map() -> void:
	tilemap.clear()
	
	make_sect(Vector2i(0,0))
	
	var current_sect = 2
	while current_sect <= max_strand:
		for sect in sects:
			if sect["strand"] == current_sect:
				make_sect(sect["pos"])
		current_sect += 1
	
	print(sects)
	build_tiles()

func make_sect(pos):
	var sect_num = get_sect(pos)
	if sect_num == -1:
		sect_num = 0
		var app = base_sect.duplicate(true)
		app["room"] = len(room_data)
		room_data.append(1)
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
					new_sect["doors"].append(door)
				room_data[new_sect["room"]] += 1
				new_sect["strand"] = sect["strand"] + 1
				sects.append(new_sect)
	
