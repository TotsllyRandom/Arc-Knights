extends Node

var revealed = []

func reveal(room):
	print("revealing room: " + str(room))
	if revealed.has(room):
		return
	revealed.append(room)
	reveal_room.emit(room)

signal reveal_room(room)

var sect_size := 7
var min_pos := Vector2i(0,0)
var max_pos := Vector2i(0,0)

# Each section is a block of (sect_size + 2) x (sect_size + 2) tiles. Neighbouring sections share their
# edge row or column of tiles. Tile letters in the map:
#   H = floor, E = exit room floor, W = wall, D = door, X = nothing (void)
#
# Halls are narrow corridors. A hall section has a floor block in its middle, plus a 3-tile-wide
# arm of floor out to each side that connects onward, so one section can be a straight piece, a
# corner, a T junction or a four-way junction. Walls run along both sides of the floor.
# A door between a room and a hall (or between two rooms) is a doorway 3 tiles wide in the middle
# of the shared edge, not the whole edge.
const DOORWAY_START := 3
const DOORWAY_END := 5
# The hall's floor block and arms occupy tiles 3 to 5 across
const HALL_FLOOR_START := 3
const HALL_FLOOR_END := 5


func make_empty_map(sects:Array):
	min_pos = Vector2i.ZERO
	max_pos = Vector2i.ZERO
	
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


# The tile coordinates of a section's top left corner
func sect_origin(sect) -> Vector2i:
	return (sect["pos"] - min_pos) * (sect_size + 1)


# Is this tile (x, y inside the section's block, 0 to sect_size + 1) floor in a hall section?
# A side connects onward when its door value isn't 1 (1 = wall).
func _is_hall_floor(sect, x: int, y: int) -> bool:
	var in_middle_x: bool = x >= HALL_FLOOR_START and x <= HALL_FLOOR_END
	var in_middle_y: bool = y >= HALL_FLOOR_START and y <= HALL_FLOOR_END
	if in_middle_x and in_middle_y:
		return true
	var sides = sect["doors"]
	if sides[0] != 1 and x <= HALL_FLOOR_START and in_middle_y:
		return true
	if sides[2] != 1 and x >= HALL_FLOOR_END and in_middle_y:
		return true
	if sides[1] != 1 and y <= HALL_FLOOR_START and in_middle_x:
		return true
	if sides[3] != 1 and y >= HALL_FLOOR_END and in_middle_x:
		return true
	return false


# The map is built in three passes over every section (floors, then walls, then doorways)
# so the result doesn't depend on which section happens to be handled first.

# Pass 1: floors. Rooms are floor all the way across; halls are only the middle block and arms.
func fill_floor(sect, tilemap):
	var origin := sect_origin(sect)
	var tiles_across: int = sect_size + 2
	var is_hall: bool = sect["type"] == "hall"

	for y in range(tiles_across):
		for x in range(tiles_across):
			if is_hall and not _is_hall_floor(sect, x, y):
				continue
			var target_y: int = origin.y + y
			var target_x: int = origin.x + x
			# Don't cover the exit room's special floor with an ordinary one
			if tilemap[target_y][target_x] == "E":
				continue
			tilemap[target_y][target_x] = "E" if sect["type"] == "exit" else "H"


# Pass 2: walls. Rooms are walled along every side that doesn't open into the same room.
# Halls get walls on every empty tile that touches their floor.
func fill_walls(sect, tilemap):
	var origin := sect_origin(sect)
	var last: int = sect_size + 1

	if sect["type"] == "hall":
		for y in range(sect_size + 2):
			for x in range(sect_size + 2):
				if _is_hall_floor(sect, x, y):
					continue
				# Is any tile around this one (inside this section) hall floor?
				var touches_floor := false
				for offset_y in range(-1, 2):
					for offset_x in range(-1, 2):
						var neighbour_x: int = x + offset_x
						var neighbour_y: int = y + offset_y
						if neighbour_x < 0 or neighbour_y < 0 or neighbour_x > last or neighbour_y > last:
							continue
						if _is_hall_floor(sect, neighbour_x, neighbour_y):
							touches_floor = true
				# Never build over floor that another section made
				if touches_floor and tilemap[origin.y + y][origin.x + x] == "X":
					tilemap[origin.y + y][origin.x + x] = "W"
		return

	for along in range(sect_size + 2):
		if sect["doors"][0] != 0:
			tilemap[origin.y + along][origin.x] = "W"
		if sect["doors"][1] != 0:
			tilemap[origin.y][origin.x + along] = "W"
		if sect["doors"][2] != 0:
			tilemap[origin.y + along][origin.x + last] = "W"
		if sect["doors"][3] != 0:
			tilemap[origin.y + last][origin.x + along] = "W"


# Pass 3: doorways, cut into the walls where one section connects to another room or hall.
# (Hall to hall connections inside the same hall are open, so they get no door.)
func fill_doorways(sect, tilemap):
	var origin := sect_origin(sect)
	var last: int = sect_size + 1

	for dir in range(4):
		if sect["doors"][dir] != 2:
			continue
		for along in range(DOORWAY_START, DOORWAY_END + 1):
			var x := 0
			var y := 0
			if dir == 0:
				x = 0
				y = along
			elif dir == 1:
				x = along
				y = 0
			elif dir == 2:
				x = last
				y = along
			else:
				x = along
				y = last
			tilemap[origin.y + y][origin.x + x] = "D"
