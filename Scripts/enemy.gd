extends CharacterBody3D

# Physics layers: 1 is the world (floor, walls, doors, player), 2 is active enemies
const WORLD_COLLISION_LAYER := 1
const ACTIVE_COLLISION_LAYER := 2

# How often the enemy works out a new route to the player
const REPATH_INTERVAL := 0.25
# How close to a waypoint counts as having reached it
const WAYPOINT_REACHED_DISTANCE := 0.35

@export var room := 0
@export var speed := 4.0
# How fast a hit shoves the enemy back, and how quickly that shove fades (units per second squared)
@export var knockback_speed := 10.0
@export var knockback_decay := 40.0

var active := false
var knockback := Vector3.ZERO
var path := PackedVector3Array()
var path_index := 0
var repath_timer := 0.0

var health = 20:
	set(new):
		if new <= 0:
			health = 0
		else:
			health = new
		if health == 0:
			queue_free()


func _ready() -> void:
	add_to_group("enemies")
	# Hidden and untouchable until the player reveals this enemy's room
	visible = false
	collision_layer = 0
	# Enemies now collide with the world (walls, doors, floor, player) and with each other
	collision_mask = WORLD_COLLISION_LAYER | ACTIVE_COLLISION_LAYER
	# Spread out the first route calculation so enemies don't all repath on the same frame
	repath_timer = randf() * REPATH_INTERVAL

	if RoomMaker.revealed.has(room):
		_activate()
	else:
		RoomMaker.reveal_room.connect(_on_room_revealed)


func _on_room_revealed(revealed_room: int) -> void:
	if revealed_room == room:
		_activate()


func _activate() -> void:
	if active:
		return
	active = true
	visible = true
	collision_layer = ACTIVE_COLLISION_LAYER
	if RoomMaker.reveal_room.is_connected(_on_room_revealed):
		RoomMaker.reveal_room.disconnect(_on_room_revealed)


# hit_direction is the direction the attack was travelling, which is the way the enemy gets shoved.
# knockback_scale lets weak hits shove less and heavy hits shove more.
func take_damage(amt, hit_direction: Vector3 = Vector3.ZERO, knockback_scale: float = 1.0) -> void:
	var flat := Vector3(hit_direction.x, 0.0, hit_direction.z)
	if flat.length() > 0.001:
		knockback = flat.normalized() * knockback_speed * knockback_scale
	health -= amt


func _physics_process(delta: float) -> void:
	if not active:
		return

	var player = get_node_or_null("../../Player")
	if player == null:
		return

	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = REPATH_INTERVAL
		_update_path(player)

	# Move on to the next waypoint once we're close enough to this one
	while path_index < path.size() and _flat_distance(global_position, path[path_index]) < WAYPOINT_REACHED_DISTANCE:
		path_index += 1

	var move_direction := Vector3.ZERO
	if path_index < path.size():
		move_direction = path[path_index] - global_position
		move_direction.y = 0.0
		move_direction = move_direction.normalized()

	# The harder the knockback, the less the enemy can steer
	var chase_strength := 1.0 - clampf(knockback.length() / knockback_speed, 0.0, 1.0)
	velocity.x = move_direction.x * speed * chase_strength + knockback.x
	velocity.z = move_direction.z * speed * chase_strength + knockback.z
	knockback = knockback.move_toward(Vector3.ZERO, knockback_decay * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += get_gravity().y * delta

	if move_direction != Vector3.ZERO:
		look_at(global_position + move_direction)

	move_and_slide()


func _update_path(player: Node3D) -> void:
	var target: Vector3 = player.global_position

	# If nothing is in the way, just walk straight at the player
	if _has_line_of_sight(player):
		path = PackedVector3Array([target])
		path_index = 0
		return

	# Otherwise ask the dungeon for a route around the walls
	var dungeon = get_node_or_null("../..")
	if dungeon != null and dungeon.has_method("find_path"):
		path = dungeon.find_path(global_position, target)
	else:
		path = PackedVector3Array([target])
	path_index = 0


func _has_line_of_sight(player: Node3D) -> bool:
	var from := global_position + Vector3.UP
	var to := player.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_COLLISION_LAYER)
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	# Hitting the player means nothing was in between; hitting anything else means a wall is
	return result.is_empty() or result.collider == player


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
