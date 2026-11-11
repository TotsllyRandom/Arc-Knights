extends Control

# A circular minimap. It starts small in the top right corner, and pressing M makes it bigger
# in the center of the screen (and M again shrinks it back).
# It follows the player: the player's dot stays in the middle, and the map slides and turns around
# it. The map rotates with the camera, so "up" on the minimap is always "up" on the screen.
# Only sections the player has already been in are shown. A red dot marks the boss room.
# The dungeon calls setup() once it has built the map.

# Small version (top right corner): the circle's radius and how many pixels one section is
const SMALL_RADIUS := 70.0
const SMALL_CELL_PIXELS := 22.0
# Big version (center of the screen)
const LARGE_RADIUS := 260.0
const LARGE_CELL_PIXELS := 30.0
# Distance of the small one from the corner of the screen
const MARGIN := 16.0

# The key that toggles the big map
const TOGGLE_KEY := KEY_M

# true = a red dot always shows where the boss room is (even though the room isn't on the map yet)
const SHOW_BOSS_MARKER := true

# Gap between neighbouring rooms, and the width of the current room's outline (in pixels)
const GAP_PIXELS := 1.5
const OUTLINE_PIXELS := 3.0

const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const PLAYER_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const BOSS_COLOR := Color(1.0, 0.1, 0.1, 1.0)
const ROOM_COLORS := {
	"hall": Color(0.6, 0.6, 0.75),
	"passthrough": Color(0.5, 0.5, 0.62),
	"enter": Color(0.35, 0.6, 1.0),
	"exit": Color(1.0, 0.25, 0.25),
	"enemy": Color(1.0, 0.55, 0.2),
	"treasure": Color(1.0, 0.85, 0.25),
	"rest": Color(0.4, 0.9, 0.5),
}

var dungeon
# The node the map is drawn on. It's cut off at the edge of the circle.
var content: Control
# true while the big version is showing
var enlarged := false
var radius := SMALL_RADIUS
var cell_pixels := SMALL_CELL_PIXELS


func setup(owner_dungeon) -> void:
	dungeon = owner_dungeon
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# This node draws the dark circle, and anything drawn by its child is clipped to that circle
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	content = Control.new()
	add_child(content)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.draw.connect(_draw_content)

	_apply_size()


# Pressing M switches between the small and big map
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == TOGGLE_KEY:
		enlarged = not enlarged
		_apply_size()


# Sizes and places the circle: top right corner when small, centered on the screen when big
func _apply_size() -> void:
	radius = LARGE_RADIUS if enlarged else SMALL_RADIUS
	cell_pixels = LARGE_CELL_PIXELS if enlarged else SMALL_CELL_PIXELS
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)

	if enlarged:
		anchor_left = 0.5
		anchor_right = 0.5
		anchor_top = 0.5
		anchor_bottom = 0.5
		offset_left = -radius
		offset_right = radius
		offset_top = -radius
		offset_bottom = radius
		grow_horizontal = Control.GROW_DIRECTION_BOTH
		grow_vertical = Control.GROW_DIRECTION_BOTH
	else:
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 0.0
		anchor_bottom = 0.0
		offset_right = -MARGIN
		offset_left = -MARGIN - radius * 2.0
		offset_top = MARGIN
		offset_bottom = MARGIN + radius * 2.0
		grow_horizontal = Control.GROW_DIRECTION_BEGIN
		grow_vertical = Control.GROW_DIRECTION_END
	queue_redraw()


func _process(_delta: float) -> void:
	if content != null:
		content.queue_redraw()


# The dark circle everything sits on
func _draw() -> void:
	draw_circle(Vector2(radius, radius), radius, BACKDROP_COLOR)


# Is the section next to this one (0 = left, 1 = up, 2 = right, 3 = down) part of the same room?
func _same_room_neighbour(sect: Dictionary, dir: int) -> bool:
	var neighbour_idx: int = dungeon.get_sect(sect["pos"] + dungeon.DIRECTIONS[dir])
	return neighbour_idx != -1 and dungeon.sects[neighbour_idx]["room"] == sect["room"]


# Draws the map. Everything is drawn in "section units" (one section = 1 x 1) and a transform
# turns that into pixels, so it can be moved, zoomed and rotated all at once.
func _draw_content() -> void:
	if dungeon == null:
		return
	var player_position: Vector2 = dungeon.get_player_map_position()
	if player_position.x < 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var center := Vector2(radius, radius)

	# Which way is "up" and "right" on the screen, as flat directions in the world
	var camera_basis := camera.global_transform.basis
	var up_world := Vector2(camera_basis.y.x, camera_basis.y.z).normalized()
	var right_world := Vector2(camera_basis.x.x, camera_basis.x.z).normalized()

	# The dungeon's grid is turned 45 degrees in the world: one step along the grid's x is
	# (1, 1) in the world, and one step along its y is (-1, 1)
	var grid_x_world := Vector2(1.0, 1.0).normalized()
	var grid_y_world := Vector2(-1.0, 1.0).normalized()

	# Where those two grid steps land on the minimap, which turns the map with the camera
	var x_axis := Vector2(grid_x_world.dot(right_world), -grid_x_world.dot(up_world)) * cell_pixels
	var y_axis := Vector2(grid_y_world.dot(right_world), -grid_y_world.dot(up_world)) * cell_pixels
	# Shift it so the player ends up in the middle
	var origin := center - (x_axis * player_position.x + y_axis * player_position.y)
	var to_screen := Transform2D(x_axis, y_axis, origin)

	content.draw_set_transform_matrix(to_screen)
	var gap := GAP_PIXELS / cell_pixels

	for sect in dungeon.sects:
		# Only sections the player has already been in are shown
		if not dungeon.visited_sects.has(sect["pos"]):
			continue

		# Skip sections that are far outside the circle
		var section_center: Vector2 = to_screen * (Vector2(sect["pos"] - RoomMaker.min_pos) + Vector2(0.5, 0.5))
		if section_center.distance_to(center) > radius + cell_pixels * 1.5:
			continue

		var room_type: String = dungeon.room_data[sect["room"]]["type"]
		var color: Color = ROOM_COLORS.get(room_type, Color.WHITE)
		var top_left := Vector2(sect["pos"] - RoomMaker.min_pos)

		if sect["type"] == "hall":
			_draw_hall_section(sect, top_left, color)
			continue

		# Leave a small gap on the sides that face another room or empty space, but none on the
		# sides that touch the same room, so a room is drawn as one solid shape
		var gaps := [gap, gap, gap, gap] # left, up, right, down
		for dir in range(4):
			if _same_room_neighbour(sect, dir):
				gaps[dir] = 0.0
		var rect_position := top_left + Vector2(gaps[0], gaps[1])
		var rect_size := Vector2(1.0 - gaps[0] - gaps[2], 1.0 - gaps[1] - gaps[3])
		content.draw_rect(Rect2(rect_position, rect_size), color)

	# Outline the whole room the player is in (halls are too thin to outline)
	var current := Vector2i(floori(player_position.x), floori(player_position.y)) + RoomMaker.min_pos
	var current_idx: int = dungeon.get_sect(current)
	if current_idx != -1 and dungeon.sects[current_idx]["type"] != "hall":
		_draw_room_outline(dungeon.sects[current_idx]["room"])

	# Boss marker: a red dot over the boss room. If it's off the edge of the map, it sits on the rim
	# pointing the way.
	var boss_position: Vector2 = dungeon.get_boss_map_position()
	var draw_boss: bool = SHOW_BOSS_MARKER and boss_position.x >= 0.0 and not dungeon.boss_defeated

	# Back to plain screen drawing for the boss marker, the player and the ring around the edge
	content.draw_set_transform_matrix(Transform2D.IDENTITY)

	if draw_boss:
		var marker := to_screen * boss_position
		var from_center := marker - center
		var rim := radius - 9.0
		if from_center.length() > rim:
			marker = center + from_center.normalized() * rim
		content.draw_circle(marker, 6.5, Color.WHITE)
		content.draw_circle(marker, 5.0, BOSS_COLOR)

	content.draw_circle(center, 5.0, PLAYER_COLOR)
	content.draw_arc(center, radius - 1.5, 0.0, TAU, 96, RING_COLOR, 3.0)


# Halls are thin: a small square in the middle with a narrow arm out to each side that
# connects onward, so corners and junctions show their real shape
func _draw_hall_section(sect: Dictionary, top_left: Vector2, color: Color) -> void:
	var near := 0.32
	var thickness := 0.36
	var sides = sect["doors"]
	# The middle block
	content.draw_rect(Rect2(top_left + Vector2(near, near), Vector2(thickness, thickness)), color)
	# An arm for each side that connects onward (anything other than a wall)
	if sides[0] != 1:
		content.draw_rect(Rect2(top_left + Vector2(0.0, near), Vector2(near + 0.01, thickness)), color)
	if sides[2] != 1:
		content.draw_rect(Rect2(top_left + Vector2(near + thickness - 0.01, near), Vector2(near + 0.01, thickness)), color)
	if sides[1] != 1:
		content.draw_rect(Rect2(top_left + Vector2(near, 0.0), Vector2(thickness, near + 0.01)), color)
	if sides[3] != 1:
		content.draw_rect(Rect2(top_left + Vector2(near, near + thickness - 0.01), Vector2(thickness, near + 0.01)), color)


# Draws a line along every edge of the room that faces something other than the same room,
# which traces the room's whole outer shape. Uses section units, like the rest of the map.
func _draw_room_outline(room_id: int) -> void:
	var width := OUTLINE_PIXELS / cell_pixels
	var inner := width / 2.0
	for sect in dungeon.sects:
		if sect["room"] != room_id:
			continue
		var top_left := Vector2(sect["pos"] - RoomMaker.min_pos)
		for dir in range(4):
			if _same_room_neighbour(sect, dir):
				continue
			var from_point: Vector2
			var to_point: Vector2
			if dir == 0: # left edge
				from_point = top_left + Vector2(inner, 0.0)
				to_point = top_left + Vector2(inner, 1.0)
			elif dir == 1: # top edge
				from_point = top_left + Vector2(0.0, inner)
				to_point = top_left + Vector2(1.0, inner)
			elif dir == 2: # right edge
				from_point = top_left + Vector2(1.0 - inner, 0.0)
				to_point = top_left + Vector2(1.0 - inner, 1.0)
			else: # bottom edge
				from_point = top_left + Vector2(0.0, 1.0 - inner)
				to_point = top_left + Vector2(1.0, 1.0 - inner)
			content.draw_line(from_point, to_point, OUTLINE_COLOR, width)
