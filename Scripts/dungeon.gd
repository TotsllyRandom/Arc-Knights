extends Node3D

var tile_scene = load("res://Scenes/tile.tscn")
var wall_scene = load("res://Scenes/wall.tscn")
var tilemap = []
var sects = []
var max_room := 7
var max_strand := 20
var biggest_strand := 0

# Holds dictionaries: {"sect_count": int, "type": String}
var room_data = []

# Pool of intermediate room types
const RANDOM_ROOM_TYPES = ["enemy", "treasure", "rest"]

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
	var p_pos: Vector3 = $Player.global_position
	var x_minus_y: float = p_pos.x / TILE_INCREMENT
	var x_plus_y: float = p_pos.z / TILE_INCREMENT
	var x: int = roundi((x_plus_y + x_minus_y) / 2.0)
	var y: int = roundi((x_plus_y - x_minus_y) / 2.0)
	return Vector2i(x, y)


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


func make_tile_map(ver: String) -> void:
	minimum = Vector2i(0, 0)
	maximum = Vector2i(0, 0)
	sects.clear()
	room_data.clear()
	tilemap.clear()
	current_player_room_id = -1

	if has_node("Ground"):
		for child in $Ground.get_children():
			child.queue_free()

	make_sect(Vector2i(0, 0))
	var current_sect_idx = 2
	while current_sect_idx <= max_strand:
		for sect in sects.duplicate():
			if sect["strand"] == current_sect_idx:
				make_sect(sect["pos"])
		biggest_strand = current_sect_idx
		current_sect_idx += 1

	var rand_pos = []
	for sect in sects:
		if sect["strand"] == biggest_strand and sect["type"] == "room":
			rand_pos.append(sect["pos"])

	if rand_pos.is_empty() or biggest_strand <= max_strand - 5:
		make_tile_map("Remake")
		return

	var exit_sect_idx = get_sect(rand_pos[randi_range(0, rand_pos.size() - 1)])
	var exit_room_id := -1
	if exit_sect_idx != -1:
		exit_room_id = sects[exit_sect_idx]["room"]

	# Step 1: Assign room types randomly first
	for i in range(room_data.size()):
		if i == 0:
			room_data[i]["type"] = "enter"
		elif i == exit_room_id:
			room_data[i]["type"] = "exit"
		else:
			room_data[i]["type"] = RANDOM_ROOM_TYPES[randi_range(0, RANDOM_ROOM_TYPES.size() - 1)]

	# Step 2: Validate type balance criteria
	var enemy_count := 0
	var rest_count := 0
	var treasure_count := 0
	
	for r in room_data:
		if r["type"] == "enemy":
			enemy_count += 1
		elif r["type"] == "rest":
			rest_count += 1
		elif r["type"] == "treasure":
			treasure_count += 1

	# Enforce constraints: 1/3 are enemy rooms, at least 1 rest, at least 3 treasure rooms
	var required_enemy_rooms: int = floori(room_data.size() / 3.0)
	
	if enemy_count < required_enemy_rooms or rest_count < 1 or treasure_count < 3:
		# Does not fit validation properties, cycle generation safely
		make_tile_map("Remake")
		return

	# Step 3: Propagate verified room types down to individual map layout sectors
	for sect in sects:
		var r_id = sect["room"]
		if r_id >= 0 and r_id < room_data.size():
			sect["type"] = room_data[r_id]["type"]

	for sect in range(len(sects)):
		var new_doors = [0, 0, 0, 0]
		var pos = sects[sect]["pos"]
		var room_val = sects[sect]["room"]

		var s_left = get_sect(Vector2i(pos.x - 1, pos.y))
		if s_left == -1 or sects[s_left]["room"] != room_val:
			new_doors = 1

		var s_up = get_sect(Vector2i(pos.x, pos.y - 1))
		if s_up == -1 or sects[s_up]["room"] != room_val:
			new_doors = 1

		var s_right = get_sect(Vector2i(pos.x + 1, pos.y))
		if s_right == -1 or sects[s_right]["room"] != room_val:
			new_doors = 1

		var s_down = get_sect(Vector2i(pos.x, pos.y + 1))
		if s_down == -1 or sects[s_down]["room"] != room_val:
			new_doors = 1

		if not sects[sect]["doors"].is_empty():
			for door in sects[sect]["doors"]:
				if door >= 0 and door < 4:
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

	if has_node("Player"):
		$Player.position = Vector3(
			(plrx - plry) * TILE_INCREMENT,
			5.0,
			(plrx + plry) * TILE_INCREMENT
		)


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
