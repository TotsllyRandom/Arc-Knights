extends Node3D

var tile_scene = load("res://Scenes/tile.tscn")
var wall_scene = load("res://Scenes/wall.tscn")
const ENEMY_SCENE := preload("res://Scenes/enemy.tscn")
const BOSS_SCENE := preload("res://Scenes/boss.tscn")
const END_SCREEN_SCENE := preload("res://Scenes/end_screen.tscn")
const MINIMAP_SCENE := preload("res://Scenes/minimap.tscn")
const INVENTORY_SCREEN_SCENE := preload("res://Scenes/inventory_screen.tscn")
const LOOT_BOX_SCENE := preload("res://Scenes/loot_box.tscn")

# Which dungeon this is. It decides the dungeon's name on screen and which items its loot boxes
# drop (items list the dungeons they drop in, in Items.gd). Dungeons are defined in Items.DUNGEONS.
@export var dungeon_id := "test_dungeon"

# A treasure room this many sections or bigger gets 2 loot boxes instead of 1
const LOOT_BOX_BIG_ROOM_SECTS := 4
# The floor tiles' top surface is at y = 1.0
const LOOT_BOX_HEIGHT := 1.0

# Run stats for the end screen
var run_start_msec := 0
var enemies_defeated := 0
var boss_defeated := false

var tilemap = []
# Every section (a 7x7 block of floor) in the dungeon
var sects = []

# One entry per room or hall: {"sect_count": int, "type": String, "cells": Array of section positions}
# Room types: "enter", "exit", "enemy", "treasure", "rest", and "passthrough" (an empty 1x1 room
# between two halls). Halls are type "hall" (empty corridors, which can bend and branch).
var room_data = []

# ---------------------------------------------------------------- layout settings

# Rooms are rectangles of sections (width x height).
const START_ROOM_SIZES := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]
const ROOM_SIZES := [
	Vector2i(2, 2), Vector2i(2, 2),
	Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 3),
	Vector2i(1, 2), Vector2i(2, 1),
	Vector2i(1, 1), Vector2i(1, 1),
]
# How long each straight stretch of hall is, in sections. Most are short; long ones are rare.
const HALL_LENGTHS := [1, 1, 1, 1, 1, 2, 2, 3, 4]
# A hall is 1 to this many straight stretches, turning between them (so it can have corners)
const MAX_HALL_SEGMENTS := 3
# After one stretch of hall, the chance it carries on with another (turning a corner or going
# straight on). Most halls are just one short stretch, and long winding ones are uncommon.
const HALL_EXTEND_CHANCE := 0.3
# Chance, each time the dungeon grows, that the new hall branches off an existing hall
# (making a longer hall, a T junction or a four-way junction) instead of leaving a room
const HALL_BRANCH_CHANCE := 0.2
# Chance that a new room is attached straight onto a room, with no hall in between
const DIRECT_ROOM_CHANCE := 0.4
# Chance of building from one of the newest rooms (which stretches the dungeon out) instead of
# any room (which packs it in). Low = a denser dungeon.
const NEWEST_ROOM_BIAS := 0.3
# How many rooms to aim for (halls aren't counted). Sized so a full clear takes about 10 minutes.
const MIN_ROOM_COUNT := 10
const MAX_ROOM_COUNT := 13
# Fewer rooms than this and the layout is thrown away
const MIN_ROOMS := 9
# Growing gives up after this many placements that didn't fit
const MAX_GROWTH_FAILURES := 400

# The boss room (the exit room) must be at least this many sections big
const MIN_BOSS_ROOM_SECTS := 6

# Pool of room types used for every room that isn't "enter" or "exit"
const RANDOM_ROOM_TYPES = ["enemy", "treasure", "rest"]

# Guaranteed minimums (the rest of the rooms are fully random)
const REST_ROOMS_MIN := 1
const TREASURE_ROOMS_MIN := 3

# ---------------------------------------------------------------- enemies and locking

# Enemies spawn per section (sect), so big rooms get more than small ones.
# They appear when the room's doors close.
const ENEMIES_PER_SECT_MIN := 1
const ENEMIES_PER_SECT_MAX := 2
# No room ever gets more enemies than this, however big it is, so fights stay a reasonable length
const MAX_ENEMIES_PER_ROOM := 8
# Enemies never appear closer to the player than this (world units)
const MIN_SPAWN_DISTANCE := 4.0
# The floor tiles' top surface is at y = 1.0, and the enemy's capsule starts at its origin
const ENEMY_SPAWN_HEIGHT := 1.0

# A room's doors lock once the player is at least this far from all of them (in world units),
# so a door never closes on top of the player
const LOCK_DOOR_DISTANCE := 1.8

const MAX_GENERATION_ATTEMPTS := 500

# Neighbour directions, in the same order as a sect's "doors" array:
# 0 = left, 1 = up, 2 = right, 3 = down
const DIRECTIONS := [
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
]

# While the dungeon is being built, a sect's "doors" is a list of the directions it connects
# onward in. assign_doors() then turns it into 4 values (left, up, right, down):
# 0 = open, 1 = wall, 2 = doorway
var base_sect = {
	"doors": [],
	"pos": Vector2i(0, 0),
	"made": false,
	"room": -1,
	"strand": 0,
	"type": "room"
}

const TILE_INCREMENT := 0.70710678118 # sqrt(0.5)

var current_player_room_id: int = -1

# Grid the enemies use to find their way around walls
var astar := AStarGrid2D.new()

# Every door in the dungeon: {"node": the door, "rooms": the room ids it touches}
var doors := []
# How many enemies are still alive in each room that has been locked (including the boss)
var room_enemies := {}
# Rooms whose doors are currently locked, and rooms that have been cleared
var locked_rooms := {}
var cleared_rooms := {}

# Sections the player has been in (keyed by section position), for the minimap
var visited_sects := {}


func _ready() -> void:
	make_tile_map("new")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Reset"):
		get_tree().reload_current_scene()
	check_player_room_tracking()
	update_room_locks()


func check_player_room_tracking() -> void:
	var coords := get_player_tilemap_xy()
	if coords == Vector2i(-1, -1):
		return
	var current_sect := get_room_from_tilemap_coords(coords.x, coords.y)
	if not current_sect.is_empty():
		# Remember where the player has been, for the minimap
		visited_sects[current_sect["pos"]] = true

		var room_id: int = current_sect.get("room", -1)
		if room_id != current_player_room_id:
			current_player_room_id = room_id
			if RoomMaker.has_method("reveal"):
				RoomMaker.reveal(room_id)
			on_room_entered(room_id)


func get_player_tilemap_xy() -> Vector2i:
	if not has_node("Player") or tilemap.is_empty():
		return Vector2i(-1, -1)
	return world_to_tile($Player.global_position)


# Where the player is on the minimap's grid: whole numbers are section corners,
# so the player standing in the middle of the first section is at (0.5, 0.5)
func get_player_map_position() -> Vector2:
	var tile := get_player_tilemap_xy()
	if tile == Vector2i(-1, -1):
		return Vector2(-1, -1)
	return Vector2(tile) / float(RoomMaker.sect_size + 1)


# The middle of the boss (exit) room on the minimap's grid, or (-1, -1) if there isn't one
func get_boss_map_position() -> Vector2:
	for room_id in range(room_data.size()):
		if room_data[room_id]["type"] != "exit":
			continue
		var cells: Array = room_data[room_id]["cells"]
		var total := Vector2.ZERO
		for cell in cells:
			total += Vector2(cell - RoomMaker.min_pos) + Vector2(0.5, 0.5)
		return total / float(cells.size())
	return Vector2(-1, -1)


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


# The tile in the middle of a section
func sect_middle_tile(sect: Dictionary) -> Vector2i:
	var step: int = RoomMaker.sect_size + 1
	return RoomMaker.sect_origin(sect) + Vector2i(floori(step / 2.0), floori(step / 2.0))


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
	doors.clear()
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
					# Remember which rooms this door belongs to, so rooms can lock and unlock it
					doors.append({"node": new_tile, "rooms": rooms_touching_tile(x, y)})
			else:
				if has_node("GridMap"):
					if tilemap[y][x] == "W":
						$GridMap.set_cell_item(Vector3i(-y, 0, x), 1)
					else:
						$GridMap.set_cell_item(Vector3i(-y, 0, x), 0)


# The ids of every room or hall that has a section covering this tile. A door sits on the edge
# between two sections, so this gives the rooms on both sides of it.
func rooms_touching_tile(x: int, y: int) -> Array:
	var step: int = RoomMaker.sect_size + 1
	var found := []
	for sect in sects:
		var start_x: int = (sect["pos"].x - RoomMaker.min_pos.x) * step
		var start_y: int = (sect["pos"].y - RoomMaker.min_pos.y) * step
		if x >= start_x and x <= start_x + step and y >= start_y and y <= start_y + step:
			if not found.has(sect["room"]):
				found.append(sect["room"])
	return found


func get_sect(pos: Vector2i) -> int:
	for sect in range(len(sects)):
		if sects[sect]["pos"] == pos:
			return sect
	return -1


func make_tile_map(_ver: String = "new") -> void:
	current_player_room_id = -1

	# RoomMaker is an autoload, so its reveal list survives scene reloads.
	# Clear it so every new dungeon starts with nothing revealed.
	RoomMaker.revealed.clear()
	run_start_msec = Time.get_ticks_msec()
	enemies_defeated = 0
	boss_defeated = false
	room_enemies.clear()
	locked_rooms.clear()
	cleared_rooms.clear()
	visited_sects.clear()

	if has_node("Ground"):
		for child in $Ground.get_children():
			child.queue_free()

	# Remove any enemies already in the scene (like the one placed by hand in dungeon.tscn).
	# Enemies are only spawned later, when a room's doors close.
	if has_node("Enemies"):
		for child in $Enemies.get_children():
			child.queue_free()

	# Keep generating layouts until one is valid
	var attempts := 0
	while not generate_layout():
		attempts += 1
		if attempts >= MAX_GENERATION_ATTEMPTS:
			push_error("Dungeon generation failed after %d attempts" % attempts)
			return

	assign_doors()

	# Build the tile map in three passes: floors, then walls, then doorways
	tilemap = RoomMaker.make_empty_map(sects)
	for sect in sects:
		RoomMaker.fill_floor(sect, tilemap)
	for sect in sects:
		RoomMaker.fill_walls(sect, tilemap)
	for sect in sects:
		RoomMaker.fill_doorways(sect, tilemap)
	build_tiles()
	build_navigation()

	# The player starts in the middle of the first section
	var middle_tile := sect_middle_tile(sects[0])
	if has_node("Player"):
		$Player.position = tile_to_world(middle_tile, 5.0)

	create_minimap()
	create_inventory_screen()
	spawn_loot_boxes()
	show_dungeon_title()


# ---------------------------------------------------------------- generating the layout

# Builds a dungeon out of rooms and halls, then gives every room a type.
# Returns false if the layout isn't usable, so the caller tries again.
func generate_layout() -> bool:
	sects.clear()
	room_data.clear()
	tilemap.clear()

	# Every section position that is already taken
	var grid := {}

	# The starting room goes at the origin
	var start_size: Vector2i = START_ROOM_SIZES.pick_random()
	var start_cells := []
	for y in range(start_size.y):
		for x in range(start_size.x):
			start_cells.append(Vector2i(x, y))
	add_structure(start_cells, false, 1, Vector2i(0, 0), grid)

	# Grow outward: each step adds a new room, usually with a hall leading to it
	var target_rooms := randi_range(MIN_ROOM_COUNT, MAX_ROOM_COUNT)
	var room_count := 1
	var failures := 0
	while room_count < target_rooms and failures < MAX_GROWTH_FAILURES:
		if try_grow(grid):
			room_count += 1
		else:
			failures += 1

	if room_count < MIN_ROOMS:
		return false

	# How deep each room reaches (the highest strand among its sections)
	var room_depths := {}
	for sect in sects:
		room_depths[sect["room"]] = maxi(room_depths.get(sect["room"], 0), sect["strand"])

	# Exit = the furthest room that is big enough for a boss fight (at least MIN_BOSS_ROOM_SECTS
	# sections). Room 0 is the starting room, so it can't also be the exit.
	var best_depth := -1
	var best_rooms := []
	for room_id in range(1, room_data.size()):
		if room_data[room_id]["type"] == "hall":
			continue
		if room_data[room_id]["sect_count"] < MIN_BOSS_ROOM_SECTS:
			continue
		var depth: int = room_depths[room_id]
		if depth > best_depth:
			best_depth = depth
			best_rooms = [room_id]
		elif depth == best_depth:
			best_rooms.append(room_id)
	if best_rooms.is_empty():
		return false
	var exit_room_id: int = best_rooms.pick_random()

	# Every other room (not halls) gets a type. A 1x1 room with exactly two halls leading
	# into it is just a passthrough: an empty room you walk through. Any other 1x1 room is
	# always a treasure room, since it's too small for a fight.
	var single_ids := []
	var other_ids := []
	var room_count_for_types := 0
	for room_id in range(room_data.size()):
		if room_data[room_id]["type"] == "hall":
			continue
		room_count_for_types += 1
		if room_id == 0 or room_id == exit_room_id:
			continue
		if room_data[room_id]["sect_count"] <= 1:
			if is_passthrough_room(room_id):
				room_data[room_id]["type"] = "passthrough"
			else:
				single_ids.append(room_id)
		else:
			other_ids.append(room_id)

	var enemy_rooms_needed: int = floori(room_count_for_types / 3.0)
	# Single-section treasure rooms already count toward the treasure minimum
	var treasure_rooms_needed: int = maxi(TREASURE_ROOMS_MIN - single_ids.size(), 0)
	if other_ids.size() < enemy_rooms_needed + REST_ROOMS_MIN + treasure_rooms_needed:
		return false

	room_data[0]["type"] = "enter"
	room_data[exit_room_id]["type"] = "exit"
	for room_id in single_ids:
		room_data[room_id]["type"] = "treasure"

	# Shuffle first so the guaranteed rooms land in random places, then
	# fill in the guaranteed minimums, then give every remaining room a random type
	other_ids.shuffle()
	for i in range(other_ids.size()):
		var room_type: String
		if i < enemy_rooms_needed:
			room_type = "enemy"
		elif i < enemy_rooms_needed + REST_ROOMS_MIN:
			room_type = "rest"
		elif i < enemy_rooms_needed + REST_ROOMS_MIN + treasure_rooms_needed:
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


# A 1x1 room with exactly two connections, both of them to halls
func is_passthrough_room(room_id: int) -> bool:
	var cells: Array = room_data[room_id]["cells"]
	if cells.size() != 1:
		return false
	var sect = sects[get_sect(cells[0])]
	var connections: Array = sect["doors"]
	if connections.size() != 2:
		return false
	for dir in connections:
		var neighbour_idx: int = get_sect(sect["pos"] + DIRECTIONS[dir])
		if neighbour_idx == -1 or sects[neighbour_idx]["type"] != "hall":
			return false
	return true


# Adds sections for a room or a hall, and returns the id of the room they belong to.
# base_strand and entry_cell give each section a distance-from-the-start number.
# Pass an existing hall's id as existing_room to add onto that hall instead of making a new one.
func add_structure(cells: Array, is_hall: bool, base_strand: int, entry_cell: Vector2i, grid: Dictionary, existing_room: int = -1) -> int:
	var room_id := existing_room
	if room_id == -1:
		room_id = room_data.size()
		room_data.append({
			"sect_count": 0,
			"type": "hall" if is_hall else "room",
			"cells": [],
		})
	for cell in cells:
		var sect = base_sect.duplicate(true)
		sect["pos"] = cell
		sect["room"] = room_id
		sect["strand"] = base_strand + absi(cell.x - entry_cell.x) + absi(cell.y - entry_cell.y)
		sect["type"] = "hall" if is_hall else "room"
		sects.append(sect)
		grid[cell] = true
		room_data[room_id]["cells"].append(cell)
		room_data[room_id]["sect_count"] += 1
	return room_id


# Tries to add one more room onto the dungeon, usually with a hall leading to it. The hall can
# turn corners, and can branch off the side of an existing hall (making a longer hall or a
# T or four-way junction). Sometimes the new room is attached straight onto another room.
# Returns false if it didn't fit.
func try_grow(grid: Dictionary) -> bool:
	var anchor_cell: Vector2i
	var from_hall := false
	var d := randi_range(0, 3)
	var dir: Vector2i = DIRECTIONS[d]

	var hall_cells := []
	for sect in sects:
		if sect["type"] == "hall":
			hall_cells.append(sect["pos"])

	if not hall_cells.is_empty() and randf() < HALL_BRANCH_CHANCE:
		# Branch off a hall
		anchor_cell = hall_cells.pick_random()
		from_hall = true
	else:
		# Leave from a room. Usually one of the newest, so the dungeon stretches out; sometimes any.
		var room_ids := []
		for room_id in range(room_data.size()):
			if room_data[room_id]["type"] != "hall":
				room_ids.append(room_id)
		var parent_id: int
		if randf() < NEWEST_ROOM_BIAS:
			parent_id = room_ids[randi_range(maxi(room_ids.size() - 3, 0), room_ids.size() - 1)]
		else:
			parent_id = room_ids.pick_random()
		var parent_cells: Array = room_data[parent_id]["cells"]
		# A section on the side facing the direction we picked
		var edge_cells := []
		for cell in parent_cells:
			if not parent_cells.has(cell + dir):
				edge_cells.append(cell)
		anchor_cell = edge_cells.pick_random()

	# The section next to the anchor, in our direction, has to be empty
	if grid.has(anchor_cell + dir):
		return false

	# Work out the hall (a list of sections, possibly empty) and where the new room's entrance is
	var path_cells := []
	var entry_cell: Vector2i
	var final_dir := d
	var direct := (not from_hall) and randf() < DIRECT_ROOM_CHANCE
	if direct:
		# No hall: the new room sits right against the one we're leaving
		entry_cell = anchor_cell + dir
	else:
		var cursor := anchor_cell
		var cur_dir := d
		var segments := 1
		while segments < MAX_HALL_SEGMENTS and randf() < HALL_EXTEND_CHANCE:
			segments += 1
		for segment in range(segments):
			if segment > 0 and randi_range(0, 2) > 0:
				# Turn a corner (otherwise carry straight on, making the hall longer)
				if cur_dir == 0 or cur_dir == 2:
					cur_dir = [1, 3].pick_random()
				else:
					cur_dir = [0, 2].pick_random()
			var length: int = HALL_LENGTHS.pick_random()
			for i in range(length):
				cursor += DIRECTIONS[cur_dir]
				path_cells.append(cursor)
		final_dir = cur_dir
		entry_cell = cursor + DIRECTIONS[cur_dir]

	var room_cells := cells_for_room(entry_cell, final_dir, ROOM_SIZES.pick_random())
	if not piece_fits(path_cells, room_cells, anchor_cell, entry_cell, grid):
		return false

	# It fits, so build it
	var anchor_sect = sects[get_sect(anchor_cell)]
	var anchor_strand: int = anchor_sect["strand"]
	var anchor_room: int = anchor_sect["room"]
	if not path_cells.is_empty():
		# A hall that branches off another hall becomes part of that hall
		var join_hall := anchor_room if from_hall else -1
		add_structure(path_cells, true, anchor_strand + 1, path_cells[0], grid, join_hall)
	add_structure(room_cells, false, anchor_strand + path_cells.size() + 1, entry_cell, grid)

	# Join everything up in a chain: the anchor, the hall sections in order, then the new room
	var chain := [anchor_cell] + path_cells + [entry_cell]
	for i in range(chain.size() - 1):
		var step: Vector2i = chain[i + 1] - chain[i]
		var step_dir: int = DIRECTIONS.find(step)
		sects[get_sect(chain[i])]["doors"].append(step_dir)
		sects[get_sect(chain[i + 1])]["doors"].append((step_dir + 2) % 4)
	return true


# Checks that a new hall and room can be placed. Every new section must be free. A new hall may
# only touch the anchor it leaves from, and a new room may only touch other rooms (they just
# share a wall), never halls. The new sections must also not touch each other except where the
# pieces join up. Packing rooms against each other keeps the dungeon dense.
func piece_fits(path_cells: Array, room_cells: Array, anchor: Vector2i, entry: Vector2i, grid: Dictionary) -> bool:
	var new_cells := path_cells + room_cells
	var seen := {}
	for cell in new_cells:
		if grid.has(cell) or seen.has(cell):
			return false
		seen[cell] = true

	var first: Vector2i = path_cells[0] if not path_cells.is_empty() else entry
	for cell in new_cells:
		for neighbour_dir in DIRECTIONS:
			var neighbour: Vector2i = cell + neighbour_dir
			if grid.has(neighbour):
				# The first new section may touch the anchor it leaves from
				if cell == first and neighbour == anchor:
					continue
				# A new room may sit right up against other rooms
				if room_cells.has(cell) and sects[get_sect(neighbour)]["type"] != "hall":
					continue
				return false
			elif seen.has(neighbour):
				if not _may_touch(cell, neighbour, path_cells, entry):
					return false
	return true


# Two new sections next to each other are only allowed if they're in the same room, or
# neighbours along the hall, or the hall's last section and the room's entrance
func _may_touch(a: Vector2i, b: Vector2i, path_cells: Array, entry: Vector2i) -> bool:
	var index_a: int = path_cells.find(a)
	var index_b: int = path_cells.find(b)
	if index_a == -1 and index_b == -1:
		return true # both in the new room
	if index_a != -1 and index_b != -1:
		return absi(index_a - index_b) == 1 # next to each other along the hall
	var room_cell := b if index_a != -1 else a
	var hall_cell := a if index_a != -1 else b
	return room_cell == entry and hall_cell == path_cells.back()


# The section positions of a rectangular room whose edge touches the end of a hall.
# d is the direction the hall was travelling. The room slides a random amount along that
# edge so halls don't always meet a corner.
func cells_for_room(entry: Vector2i, d: int, size: Vector2i) -> Array:
	var min_x := entry.x
	var min_y := entry.y
	if d == 0: # travelling left, so the entry is on the room's right column
		min_x = entry.x - size.x + 1
		min_y = entry.y - randi_range(0, size.y - 1)
	elif d == 1: # travelling up, so the entry is on the room's bottom row
		min_y = entry.y - size.y + 1
		min_x = entry.x - randi_range(0, size.x - 1)
	elif d == 2: # travelling right, so the entry is on the room's left column
		min_x = entry.x
		min_y = entry.y - randi_range(0, size.y - 1)
	else: # travelling down, so the entry is on the room's top row
		min_y = entry.y
		min_x = entry.x - randi_range(0, size.x - 1)

	var cells := []
	for y in range(size.y):
		for x in range(size.x):
			cells.append(Vector2i(min_x + x, min_y + y))
	return cells


# Turns each sect's list of connections into a 4-slot array (left, up, right, down):
# 0 = open, 1 = wall, 2 = doorway
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
				# Same room or hall, so the space is open
				new_doors[dir] = 0
			elif connected.has(dir):
				# A different room or hall that this sect connects to
				new_doors[dir] = 2
			else:
				new_doors[dir] = 1

		sect["doors"] = new_doors


# ---------------------------------------------------------------- doors, locking and spawning enemies

# When the player walks into a room, every door of that room opens, so the way on to the next
# rooms is always clear. Rooms with a fight in them keep their doors shut instead, until the
# fight is won.
func on_room_entered(room_id: int) -> void:
	var room_type: String = room_data[room_id]["type"]
	var is_fight_room: bool = room_type == "enemy" or room_type == "exit"
	if is_fight_room and not cleared_rooms.has(room_id):
		return
	open_room_doors(room_id)


func open_room_doors(room_id: int) -> void:
	for door in doors:
		if door["rooms"].has(room_id) and is_instance_valid(door["node"]):
			door["node"].open_door()


# Once the player is well inside an enemy room (or the boss room), shut every door of that room.
# The enemies appear at that moment.
func update_room_locks() -> void:
	var room_id := current_player_room_id
	if room_id < 0 or not has_node("Player"):
		return
	var room_type: String = room_data[room_id]["type"]
	if room_type != "enemy" and room_type != "exit":
		return
	if locked_rooms.has(room_id) or cleared_rooms.has(room_id):
		return

	# Wait until the player is clear of every door in the room, so none can close on them
	var player_pos: Vector3 = $Player.global_position
	for door in doors:
		if door["rooms"].has(room_id) and is_instance_valid(door["node"]):
			var door_pos: Vector3 = door["node"].global_position
			if Vector2(door_pos.x, door_pos.z).distance_to(Vector2(player_pos.x, player_pos.z)) < LOCK_DOOR_DISTANCE:
				return

	lock_room(room_id)


# Closes the room's doors, and then the enemies (or the boss) appear
func lock_room(room_id: int) -> void:
	locked_rooms[room_id] = true
	for door in doors:
		if door["rooms"].has(room_id) and is_instance_valid(door["node"]):
			door["node"].lock()

	var count := 0
	if room_data[room_id]["type"] == "exit":
		count = spawn_boss(room_id)
	else:
		count = spawn_enemy_group(room_id)
	room_enemies[room_id] = count
	# Nothing spawned, so there's nothing to fight: open straight back up
	if count == 0:
		clear_room(room_id)


# Spawns a few enemies in each section of the room, away from the player.
# Returns how many were spawned.
func spawn_enemy_group(room_id: int) -> int:
	if not has_node("Enemies") or not has_node("Player"):
		return 0

	var player_pos: Vector3 = $Player.global_position
	var used_tiles := {}
	var total := 0

	# Go through the room's sections in a random order, so if the cap is reached the
	# enemies aren't always missing from the same part of the room
	var room_sects := []
	for sect in sects:
		if sect["room"] == room_id:
			room_sects.append(sect)
	room_sects.shuffle()

	for sect in room_sects:
		if total >= MAX_ENEMIES_PER_ROOM:
			break

		# Each sect in the room gets its own enemies, up to ENEMIES_PER_SECT_MAX
		var count := mini(randi_range(ENEMIES_PER_SECT_MIN, ENEMIES_PER_SECT_MAX), MAX_ENEMIES_PER_ROOM - total)
		var spawned := 0
		var tries := 0
		var origin := RoomMaker.sect_origin(sect)
		while spawned < count and tries < count * 10:
			tries += 1
			# Only use interior tiles (1 to sect_size), not the edge tiles that hold walls and doors
			var tile := origin + Vector2i(randi_range(1, RoomMaker.sect_size), randi_range(1, RoomMaker.sect_size))
			if used_tiles.has(tile):
				continue
			var world_pos := tile_to_world(tile, ENEMY_SPAWN_HEIGHT)
			# Not right on top of the player
			if Vector2(world_pos.x, world_pos.z).distance_to(Vector2(player_pos.x, player_pos.z)) < MIN_SPAWN_DISTANCE:
				continue
			used_tiles[tile] = true

			var enemy = ENEMY_SCENE.instantiate()
			enemy.room = room_id
			enemy.position = world_pos
			$Enemies.add_child(enemy)
			enemy.died.connect(_on_enemy_died)
			spawned += 1
			total += 1
	return total


# Spawns the boss in the middle of the section of the exit room that is furthest from the player.
# Returns how many were spawned (1).
func spawn_boss(room_id: int) -> int:
	if not has_node("Enemies") or not has_node("Player"):
		return 0

	var player_pos: Vector3 = $Player.global_position
	var boss_tile := Vector2i(-1, -1)
	var best_distance := -1.0
	for sect in sects:
		if sect["room"] != room_id:
			continue
		var tile := sect_middle_tile(sect)
		var world_pos := tile_to_world(tile, ENEMY_SPAWN_HEIGHT)
		var distance := Vector2(world_pos.x, world_pos.z).distance_to(Vector2(player_pos.x, player_pos.z))
		if distance > best_distance:
			best_distance = distance
			boss_tile = tile
	if boss_tile == Vector2i(-1, -1):
		return 0

	var boss = BOSS_SCENE.instantiate()
	boss.room = room_id
	boss.position = tile_to_world(boss_tile, ENEMY_SPAWN_HEIGHT)
	$Enemies.add_child(boss)
	boss.died.connect(_on_boss_died)
	return 1


# Opens every door of the room and leaves them open
func clear_room(room_id: int) -> void:
	cleared_rooms[room_id] = true
	var was_locked := locked_rooms.has(room_id)
	locked_rooms.erase(room_id)
	for door in doors:
		if door["rooms"].has(room_id) and is_instance_valid(door["node"]):
			# Release the lock this room put on the door (only if it did), then open it
			if was_locked and door["node"].lock_count > 0:
				door["node"].unlock()
			door["node"].open_door()


# Called whenever an enemy in a room dies. When the last one goes, the room is cleared.
func _enemy_removed(room_id: int) -> void:
	if not room_enemies.has(room_id):
		return
	room_enemies[room_id] -= 1
	if room_enemies[room_id] <= 0:
		clear_room(room_id)


func _on_enemy_died(enemy) -> void:
	enemies_defeated += 1
	_enemy_removed(enemy.room)


# Defeating the boss clears its room and ends the run
func _on_boss_died(boss) -> void:
	if boss_defeated:
		return
	boss_defeated = true
	enemies_defeated += 1
	_enemy_removed(boss.room)
	# Deferred, because this is called from inside a physics callback (the bullet hit)
	show_end_screen.call_deferred()


# ---------------------------------------------------------------- screens

# Shows the end screen, which pauses the game until the player continues
func show_end_screen() -> void:
	var screen = END_SCREEN_SCENE.instantiate()
	screen.run_time_seconds = (Time.get_ticks_msec() - run_start_msec) / 1000.0
	screen.enemies_defeated = enemies_defeated
	screen.continued.connect(_on_end_screen_continued)
	add_child(screen)


# Unpause, then load a brand new dungeon through the loading screen
func _on_end_screen_continued() -> void:
	get_tree().paused = false
	SceneLoader.load_level("res://Scenes/dungeon.tscn")


# The minimap at the top right of the screen (press M to enlarge it)
func create_minimap() -> void:
	var minimap_layer = MINIMAP_SCENE.instantiate()
	add_child(minimap_layer)
	var map = minimap_layer.get_node("Map")
	if not map.has_method("setup"):
		# Godot drops a script that doesn't compile, so check the Output panel for a parse error in minimap.gd
		push_error("The minimap script (Scripts/minimap.gd) didn't load. Check the Output panel for its error.")
		return
	map.setup(self)


# The inventory screen, hidden until the player presses Tab
func create_inventory_screen() -> void:
	add_child(INVENTORY_SCREEN_SCENE.instantiate())


# Puts a loot box in the middle of a random section of every treasure room (2 in big rooms)
func spawn_loot_boxes() -> void:
	var box_parent := Node3D.new()
	box_parent.name = "LootBoxes"
	add_child(box_parent)

	for room_id in range(room_data.size()):
		if room_data[room_id]["type"] != "treasure":
			continue
		var room_sects := []
		for sect in sects:
			if sect["room"] == room_id:
				room_sects.append(sect)
		room_sects.shuffle()

		var box_count := 2 if room_sects.size() >= LOOT_BOX_BIG_ROOM_SECTS else 1
		for i in range(mini(box_count, room_sects.size())):
			var box = LOOT_BOX_SCENE.instantiate()
			box.dungeon_id = dungeon_id
			box.position = tile_to_world(sect_middle_tile(room_sects[i]), LOOT_BOX_HEIGHT)
			box_parent.add_child(box)


# Shows the dungeon's name across the top of the screen when you arrive, then fades it out
func show_dungeon_title() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	var label := Label.new()
	label.text = Items.dungeon_name(dungeon_id).to_upper()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 90.0
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	label.modulate.a = 0.0
	layer.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.6)
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(layer.queue_free)
