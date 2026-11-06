extends Node3D

var tile_scene = load("res://Scenes/tile.tscn")
var wall_scene = load("res://Scenes/wall.tscn")
const ENEMY_SCENE := preload("res://Scenes/enemy.tscn")

var tilemap = []
var sects = []
var max_room := 7
var max_strand := 20
var biggest_strand := 0

# Holds dictionaries: {"sect_count": int, "type": String}
var room_data = []

# Pool of room types used for every room that isn't "enter" or "exit"
const RANDOM_ROOM_TYPES = ["enemy", "treasure", "rest"]

# Guaranteed minimums (the rest of the rooms are fully random)
const REST_ROOMS_MIN := 1
const TREASURE_ROOMS_MIN := 3

# Enemies spawn per section (sect), so big rooms get more than small ones
const ENEMIES_PER_SECT_MIN := 1
const ENEMIES_PER_SECT_MAX := 2
# The floor tiles' top surface is at y = 1.0, and the enemy's capsule starts at its origin
const ENEMY_SPAWN_HEIGHT := 1.0

const MAX_GENERATION_ATTEMPTS := 500

# Neighbour directions, in the same order as a sect's "doors" array:
# 0 = left, 1 = up, 2 = right, 3 = down
const DIRECTIONS := [
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
]

var base_sect = {
	"doors": [],
	"pos": Vector2i(0, 0),
	"made": false,
	"room": -1,
	"strand": 0,
	"type": "room"
}

var base_room = {
	"doors": [-1, -1, -1, -1],
	"pos": Vector2i(0, 0),
	"made": false,
	"seen": false,
	"room": -1
}

var tiles_y = 0
var tiles_x = 0
var minimum: Vector2i
var maximum: Vector2i
var total_rooms := 0
const MIN_ROOMS := 5
const MAX_STRAND_LENGTH := 5
const TILE_INCREMENT := 0.70710678118 # sqrt(0.5)

var current_player_room_id: int = -1

# Grid the enemies use to find their way around walls
var astar := AStarGrid2D.new()


func _ready() -> void:
	make_tile_map("new")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Reset"):
		get_tree().reload_current_scene()
	check_player_room_tracking()


func check_player_room_tracking() -> void:
	var coords := get_player_tilemap_xy()
	if coords == Vector2i(-1, -1):
		return
	var current_sect := get_room_from_tilemap_coords(coords.x, coords.y)
	if not current_sect.is_empty():
		var room_id: int = current_sect.get("room", -1)
		if room_id != current_player_room_id:
			current_player_room_id = room_id
			if RoomMaker.has_method("reveal"):
				RoomMaker.reveal(room_id)


func get_player_tilemap_xy() -> Vector2i:
	if not has_node("Player") or tilemap.is_empty():
		return Vector2i(-1, -1)
	return world_to_tile($Player.global_position)


# Converts a world position to the tile coordinates used by tilemap[y][x]
func world_to_tile(p: Vector3) -> Vector2i:
	var x_minus_y: float = p.x / TILE_INCREMENT
	var x_plus_y: float = p.z / TILE_INCREMENT
	var x: int = roundi((x_plus_y + x_minus_y) / 2.0)
	var y: int = roundi((x_plus_y - x_minus_y) / 2.0)
	return Vector2i(x, y)


# The world position of the centre of a tile
func tile_to_world(tile: Vector2i, height: float) -> Vector3:
	return Vector3(
		(tile.x - tile.y) * TILE_INCREMENT,
		height,
		(tile.x + tile.y) * TILE_INCREMENT
	)


# Marks walls and empty space as solid so paths go around them.
# Door tiles stay walkable: the real door collision stops enemies until it opens.
func build_navigation() -> void:
	astar = AStarGrid2D.new()
	if tilemap.is_empty():
		return
	var grid_height: int = tilemap.size()
	var grid_width: int = tilemap[0].size()
	astar.region = Rect2i(0, 0, grid_width, grid_height)
	astar.cell_size = Vector2.ONE
	# Don't let paths cut diagonally across wall corners
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in range(grid_height):
		for x in range(grid_width):
			var tile: String = tilemap[y][x]
			if tile == "X" or tile == "W":
				astar.set_point_solid(Vector2i(x, y), true)


# Returns the world positions to walk through to get from one point to another.
# Falls back to a straight line if there's no path.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var from_tile := world_to_tile(from)
	var to_tile := world_to_tile(to)

	if not astar.region.has_point(from_tile) or not astar.region.has_point(to_tile):
		result.append(to)
		return result
	if astar.is_point_solid(from_tile) or astar.is_point_solid(to_tile):
		result.append(to)
		return result

	var id_path = astar.get_id_path(from_tile, to_tile)
	if id_path.is_empty():
		result.append(to)
		return result

	# Skip the first tile (the one the enemy is already on)
	for i in range(1, id_path.size()):
		result.append(tile_to_world(id_path[i], from.y))
	result.append(to)
	return result


func get_room_from_tilemap_coords(x: int, y: int) -> Dictionary:
	var sect_size_with_gap: int = RoomMaker.sect_size + 1
	var sect_x: int = floori(float(x) / sect_size_with_gap) + RoomMaker.min_pos.x
	var sect_y: int = floori(float(y) / sect_size_with_gap) + RoomMaker.min_pos.y
	var target_sect_pos := Vector2i(sect_x, sect_y)
	var sect_idx: int = get_sect(target_sect_pos)
	if sect_idx != -1:
		return sects[sect_idx]
	return {}


func build_tiles():
	if has_node("GridMap"):
		$GridMap.clear()
	for y in range(len(tilemap)):
		for x in range(len(tilemap[y])):
			if tilemap[y][x] == "X":
				continue
			var new_tile: Node3D
			if tilemap[y][x] == "D":
				new_tile = wall_scene.instantiate()
				new_tile.set("type", "door")
				new_tile.position = Vector3(
					(x - y) * TILE_INCREMENT,
					0,
					(x + y) * TILE_INCREMENT,
				)
				if has_node("Ground"):
					$Ground.add_child(new_tile)
			else:
				if has_node("GridMap"):
					if tilemap[y][x] == "W":
						$GridMap.set_cell_item(Vector3i(-y, 0, x), 1)
					else:
						$GridMap.set_cell_item(Vector3i(-y, 0, x), 0)


func get_sect(pos: Vector2i) -> int:
	for sect in range(len(sects)):
		if sects[sect]["pos"] == pos:
			return sect
	return -1


func make_tile_map(_ver: String = "new") -> void:
	minimum = Vector2i(0, 0)
	maximum = Vector2i(0, 0)
	current_player_room_id = -1

	# RoomMaker is an autoload, so its reveal list survives scene reloads.
	# Clear it so every new dungeon starts with nothing revealed.
	RoomMaker.revealed.clear()

	if has_node("Ground"):
		for child in $Ground.get_children():
			child.queue_free()

	# Keep generating layouts until one is valid
	var attempts := 0
	while not generate_layout():
		attempts += 1
		if attempts >= MAX_GENERATION_ATTEMPTS:
			push_error("Dungeon generation failed after %d attempts" % attempts)
			return

	assign_doors()

	tilemap = RoomMaker.make_empty_map(sects)
	for sect in sects:
		tilemap = RoomMaker.append_sect(sect, tilemap)
	build_tiles()
	build_navigation()

	var origin_start_x = (-RoomMaker.min_pos.x) * (RoomMaker.sect_size + 1)
	var origin_start_y = (-RoomMaker.min_pos.y) * (RoomMaker.sect_size + 1)
	var middle_offset = float(RoomMaker.sect_size + 1) / 2.0
	var plrx: float = origin_start_x + middle_offset
	var plry: float = origin_start_y + middle_offset

	if has_node("Player"):
		$Player.position = Vector3(
			(plrx - plry) * TILE_INCREMENT,
			5.0,
			(plrx + plry) * TILE_INCREMENT
		)

	spawn_enemies()


# Builds the sects and rooms, then gives every room a type.
# Returns false if the layout isn't usable, so the caller tries again.
func generate_layout() -> bool:
	sects.clear()
	room_data.clear()
	tilemap.clear()

	make_sect(Vector2i(0, 0))
	var current_strand := 2
	while current_strand <= max_strand:
		for sect in sects.duplicate():
			if sect["strand"] == current_strand:
				make_sect(sect["pos"])
		current_strand += 1

	# The furthest sects are the ones with the highest strand (distance from the start)
	biggest_strand = 0
	for sect in sects:
		biggest_strand = maxi(biggest_strand, sect["strand"])

	# Dungeon must be deep enough and have enough rooms
	if biggest_strand <= max_strand - 5 or room_data.size() < MIN_ROOMS:
		return false

	# Exit = the room that holds the furthest sect (pick one if several tie)
	var furthest_rooms := []
	for sect in sects:
		if sect["strand"] == biggest_strand:
			furthest_rooms.append(sect["room"])
	var exit_room_id: int = furthest_rooms.pick_random()

	# Room 0 is the starting room, so it can't also be the exit
	if exit_room_id == 0:
		return false

	# Every room except the start and the exit gets a random type
	var other_ids := []
	for room_id in range(1, room_data.size()):
		if room_id != exit_room_id:
			other_ids.append(room_id)

	var enemy_rooms_needed: int = floori(room_data.size() / 3.0)
	if other_ids.size() < enemy_rooms_needed + REST_ROOMS_MIN + TREASURE_ROOMS_MIN:
		return false

	room_data[0]["type"] = "enter"
	room_data[exit_room_id]["type"] = "exit"

	# Shuffle first so the guaranteed rooms land in random places, then
	# fill in the guaranteed minimums, then give every remaining room a random type
	other_ids.shuffle()
	for i in range(other_ids.size()):
		var room_type: String
		if i < enemy_rooms_needed:
			room_type = "enemy"
		elif i < enemy_rooms_needed + REST_ROOMS_MIN:
			room_type = "rest"
		elif i < enemy_rooms_needed + REST_ROOMS_MIN + TREASURE_ROOMS_MIN:
			room_type = "treasure"
		else:
			room_type = RANDOM_ROOM_TYPES.pick_random()
		room_data[other_ids[i]]["type"] = room_type

	# Pass each room's type down to its sects
	for sect in sects:
		var r_id: int = sect["room"]
		if r_id >= 0 and r_id < room_data.size():
			sect["type"] = room_data[r_id]["type"]

	return true


# Turns each sect's list of connections into a 4-slot array (left, up, right, down):
# 0 = open, 1 = wall, 2 = door
func assign_doors() -> void:
	for sect in sects:
		var connected: Array = sect["doors"]
		var new_doors := [0, 0, 0, 0]

		for dir in range(4):
			var neighbour_idx: int = get_sect(sect["pos"] + DIRECTIONS[dir])
			if neighbour_idx == -1:
				# Nothing there
				new_doors[dir] = 1
			elif sects[neighbour_idx]["room"] == sect["room"]:
				# Same room, so the space is open
				new_doors[dir] = 0
			elif connected.has(dir):
				# A different room that this sect connects to
				new_doors[dir] = 2
			else:
				new_doors[dir] = 1

		sect["doors"] = new_doors


# Spawns a few enemies in every enemy room. Each enemy hides itself until its room is revealed.
func spawn_enemies() -> void:
	if not has_node("Enemies"):
		return

	# Remove any enemies already in the scene (like the one placed by hand in dungeon.tscn)
	for child in $Enemies.get_children():
		child.queue_free()

	var step: int = RoomMaker.sect_size + 1
	var used_tiles := {}

	for room_id in range(room_data.size()):
		if room_data[room_id]["type"] != "enemy":
			continue

		var room_sects := []
		for sect in sects:
			if sect["room"] == room_id:
				room_sects.append(sect)
		if room_sects.is_empty():
			continue

		# Each sect in the room gets its own enemies, up to ENEMIES_PER_SECT_MAX
		for sect in room_sects:
			var count := randi_range(ENEMIES_PER_SECT_MIN, ENEMIES_PER_SECT_MAX)
			var spawned := 0
			var tries := 0
			while spawned < count and tries < count * 10:
				tries += 1
				# Only use interior tiles (1 to sect_size), not the edge tiles that hold walls and doors
				var tile_x: int = (sect["pos"].x - RoomMaker.min_pos.x) * step + randi_range(1, RoomMaker.sect_size)
				var tile_y: int = (sect["pos"].y - RoomMaker.min_pos.y) * step + randi_range(1, RoomMaker.sect_size)
				var key := Vector2i(tile_x, tile_y)
				if used_tiles.has(key):
					continue
				used_tiles[key] = true

				var enemy = ENEMY_SCENE.instantiate()
				enemy.room = room_id
				enemy.position = Vector3(
					(tile_x - tile_y) * TILE_INCREMENT,
					ENEMY_SPAWN_HEIGHT,
					(tile_x + tile_y) * TILE_INCREMENT
				)
				$Enemies.add_child(enemy)
				spawned += 1


func make_sect(pos: Vector2i):
	var sect_num = get_sect(pos)
	if sect_num == -1:
		sect_num = 0
		var app = base_sect.duplicate(true)
		app["room"] = room_data.size()
		room_data.append({"sect_count": 1, "type": "enter"})
		app["type"] = "enter"
		app["strand"] = 1
		app["pos"] = pos
		sects.append(app)
		sect_num = sects.size() - 1

	var sect = sects[sect_num]
	var to_make = [
		Vector2i(pos.x - 1, pos.y),
		Vector2i(pos.x, pos.y - 1),
		Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x, pos.y + 1),
	]

	for door in range(4):
		if get_sect(to_make[door]) == -1:
			if randi_range(0, 1) == 1:
				var new_sect = base_sect.duplicate(true)
				new_sect["pos"] = to_make[door]
				new_sect["room"] = sect["room"]

				if room_data[new_sect["room"]]["sect_count"] >= max_room:
					new_sect["room"] = room_data.size()
					room_data.append({"sect_count": 0, "type": "room"})

				var new_door = door + 2
				if new_door >= 4:
					new_door -= 4

				sects[sect_num]["doors"].append(door)
				new_sect["doors"].append(new_door)
				room_data[new_sect["room"]]["sect_count"] += 1
				new_sect["strand"] = sect["strand"] + 1
				sects.append(new_sect)
