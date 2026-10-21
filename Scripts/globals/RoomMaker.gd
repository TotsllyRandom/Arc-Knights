extends Node

var sect_size := 7
var min_pos := Vector2i(0,0)
var max_pos := Vector2i(0,0)

func make_empty_map(sects:Array):
	
	for sect in sects:
		min_pos = Vector2i(min(min_pos.x, sect["pos"].x),min(min_pos.y, sect["pos"].y))
		max_pos = Vector2i(max(max_pos.x, sect["pos"].x),max(max_pos.y, sect["pos"].y))
	
	var ret = []
	for y in range(((max_pos.y - min_pos.y) * (sect_size + 1)) + (sect_size + 2)):
		var line = []
		for x in range(((max_pos.x - min_pos.x) * (sect_size + 1)) + (sect_size + 2)):
			line.append("X")
		ret.append(line)
	
	return ret

func append_sect(sect, tilemap):
	var starting_pos = Vector2i(0,0)
	starting_pos.x += (sect["pos"].x - min_pos.x) * (sect_size + 1)
	starting_pos.y += (sect["pos"].y - min_pos.y) * (sect_size + 1)
	
	for y in range(sect_size + 2):
		for x in range(sect_size + 2):
				
			
			var target_y = starting_pos.y + y
			var target_x = starting_pos.x + x
			
			if sect["type"] == "exit":
				tilemap[target_y][target_x] = "E"
			else:
				tilemap[target_y][target_x] = "H"
			
			if x == 0 && sect["doors"][0] != 0:
				if tilemap[target_y][target_x] != "W":
					if sect["doors"][0] == 1:
						tilemap[target_y][target_x] = "W"
					else:
						tilemap[target_y][target_x] = "D"
			if y == 0 && sect["doors"][1] != 0:
				if tilemap[target_y][target_x] != "W":
					if sect["doors"][1] == 1:
						tilemap[target_y][target_x] = "W"
					else:
						tilemap[target_y][target_x] = "D"
			if x == sect_size + 1 && sect["doors"][2] != 0:
				if tilemap[target_y][target_x] != "W":
					if sect["doors"][2] == 1:
						tilemap[target_y][target_x] = "W"
					else:
						tilemap[target_y][target_x] = "D"
			if y == sect_size + 1 && sect["doors"][3] != 0:
				if tilemap[target_y][target_x] != "W":
					if sect["doors"][3] == 1:
						tilemap[target_y][target_x] = "W"
					else:
						tilemap[target_y][target_x] = "D"
			
	return tilemap
