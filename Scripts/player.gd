extends CharacterBody3D

const Weapons = preload("res://Scripts/weapons.gd")

var gun_cd := 0.0:
	set(new):
		if new <= 0:
			gun_cd = 0.0
		else:
			gun_cd = new

@onready var cam_rotate = $RotateCamera
var bullet = preload("res://Scenes/bullet.tscn")

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var target_rotation : Vector3

# Height above the player's feet that shots come from, and how far in front of the player they start
const GUN_HEIGHT := 1.0
const MUZZLE_DISTANCE := 0.8
# A click this close before the weapon is ready still fires as soon as it is
const FIRE_BUFFER_TIME := 0.15
# Short pause after swapping so a swap can't also fire instantly
const WEAPON_SWITCH_DELAY := 0.2

var weapon_index := 0
var weapon: Dictionary = {}
var fire_buffer := 0.0
var mouse_was_down := false
var burst_shots_left := 0
var burst_timer := 0.0


func check_camera_controls():
	if Input.is_action_just_pressed("Player_Camera_Left"):
		target_rotation.y -= PI/4
	if Input.is_action_just_pressed("Player_Camera_Right"):
		target_rotation.y += PI/4
	if Input.is_action_just_pressed("Player_Camera_Up"):
		target_rotation.x -= PI/8
	if Input.is_action_just_pressed("Player_Camera_Down"):
		target_rotation.x += PI/8
	target_rotation.x = clamp(target_rotation.x, -PI/2,-PI/4)
	

func _ready() -> void:
	add_to_group("player")
	_ensure_weapon_input()
	rotation.y = 0
	target_rotation.y = rotation.y
	target_rotation.x = cam_rotate.rotation.x
	equip_weapon(0)

func _physics_process(delta: float) -> void:
	if position.y <= -5:
		position.y = 5
	gun_cd -= delta
	check_camera_controls()
	rotation.y = lerp_angle(rotation.y,target_rotation.y, .3)
	cam_rotate.rotation.x = lerp_angle(cam_rotate.rotation.x,target_rotation.x, .3)
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("Player_Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("Player_Move_Left", "Player_Move_Right", "Player_Move_Up", "Player_Move_Down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	handle_weapon(delta)


# ---------------------------------------------------------------- weapons

# Makes sure the swap control exists. It's also in the project's Input Map as
# "Player_Swap_Weapon"; this just covers the case where it isn't there.
func _ensure_weapon_input() -> void:
	if not InputMap.has_action("Player_Swap_Weapon"):
		InputMap.add_action("Player_Swap_Weapon")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_L
		InputMap.action_add_event("Player_Swap_Weapon", key)


# Switches to the next weapon in the list (wraps around)
func swap_weapon() -> void:
	equip_weapon(weapon_index + 1)


# Equips a weapon by its index in Weapons.LIST and updates the on-screen label.
# Later, the weapon types can be set from the character's gear by calling this.
func equip_weapon(index: int) -> void:
	weapon_index = wrapi(index, 0, Weapons.LIST.size())
	weapon = Weapons.LIST[weapon_index]
	# Cancel anything in progress from the old weapon
	burst_shots_left = 0
	fire_buffer = 0.0
	gun_cd = WEAPON_SWITCH_DELAY
	update_weapon_label()


# The label that used to say "End Run" now shows the current weapon
func update_weapon_label() -> void:
	var label = get_node_or_null("../InteractText/Label")
	if label != null:
		label.text = weapon.get("name", "")


func handle_weapon(delta: float) -> void:
	if Input.is_action_just_pressed("Player_Swap_Weapon"):
		swap_weapon()

	fire_buffer -= delta
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_down and not mouse_was_down:
		fire_buffer = FIRE_BUFFER_TIME
	mouse_was_down = mouse_down

	# Automatic weapons fire while the button is held; everything else fires on each click
	var wants_fire := fire_buffer > 0.0
	if weapon["mode"] == Weapons.Mode.AUTO:
		wants_fire = mouse_down

	if wants_fire and gun_cd <= 0.0 and burst_shots_left == 0:
		fire_buffer = 0.0
		start_attack()

	# Keep a burst going, one shot at a time
	if burst_shots_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			shoot_bullets(1)
			burst_shots_left -= 1
			burst_timer = weapon.get("burst_delay", 0.06)


func start_attack() -> void:
	var mode = weapon["mode"]
	var cooldown: float = weapon.get("cooldown", 0.3)

	if mode == Weapons.Mode.BURST:
		var count: int = weapon.get("burst_count", 3)
		var delay: float = weapon.get("burst_delay", 0.06)
		burst_shots_left = count
		burst_timer = 0.0 # the first shot goes out right away
		gun_cd = cooldown + delay * count
	elif mode == Weapons.Mode.SHOTGUN:
		shoot_bullets(weapon.get("pellets", 6))
		gun_cd = cooldown
	elif mode == Weapons.Mode.MELEE:
		melee_attack()
		gun_cd = cooldown
	else:
		# MANUAL and AUTO both fire a single bullet
		shoot_bullets(1)
		gun_cd = cooldown


# The direction (flat, no up or down) from the player toward the mouse
func get_aim_direction() -> Vector3:
	var cam: Camera3D = $RotateCamera/Hold/Camera3D
	var mousepos := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mousepos)
	var ray_direction := cam.project_ray_normal(mousepos)

	# Find where the mouse ray crosses the height the gun is held at, so aiming
	# is exact no matter which camera angle is used
	var gun_position := global_position + Vector3.UP * GUN_HEIGHT
	var hit = Plane(Vector3.UP, gun_position.y).intersects_ray(ray_origin, ray_direction)

	var aim := Vector3.ZERO
	if hit != null:
		aim = hit - gun_position
	aim.y = 0.0
	if aim.length() < 0.1:
		# Mouse is right on top of the player, so use the way they're facing
		aim = -global_transform.basis.z
		aim.y = 0.0
	return aim.normalized()


func shoot_bullets(count: int) -> void:
	var aim := get_aim_direction()
	var origin := global_position + Vector3.UP * GUN_HEIGHT + aim * MUZZLE_DISTANCE
	var spread: float = weapon.get("spread", 0.0)

	for i in range(count):
		var angle := 0.0
		if count > 1:
			# Fan the pellets evenly across the spread, with a little randomness
			angle = lerpf(-spread / 2.0, spread / 2.0, float(i) / float(count - 1))
			angle += randf_range(-spread * 0.05, spread * 0.05)
		else:
			angle = randf_range(-spread / 2.0, spread / 2.0)

		var b = bullet.instantiate()
		get_tree().current_scene.add_child(b)
		b.launch(origin, aim.rotated(Vector3.UP, deg_to_rad(angle)), weapon)


# Hits every active enemy inside the swing's range and arc
func melee_attack() -> void:
	var aim := get_aim_direction()
	var reach: float = weapon.get("melee_range", 3.0)
	var arc: float = weapon.get("melee_arc", 120.0)
	var damage = weapon.get("damage", 10)
	var knockback_scale: float = weapon.get("knockback_scale", 1.0)

	show_melee_arc(aim, reach, arc)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.active:
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		# Enemies are about a tile wide, so let the swing reach a little further for them
		if offset.length() > reach + 0.5:
			continue
		var angle_to_enemy := rad_to_deg(aim.angle_to(offset.normalized()))
		if angle_to_enemy <= arc / 2.0 or offset.length() < 0.6:
			enemy.take_damage(damage, offset.normalized(), knockback_scale)


# A quick fading slash shape so melee swings are visible
func show_melee_arc(aim: Vector3, reach: float, arc: float) -> void:
	var half := deg_to_rad(arc) / 2.0
	var steps := 14
	var verts := PackedVector3Array()
	for i in range(steps):
		var a0 := -half + (half * 2.0) * float(i) / steps
		var a1 := -half + (half * 2.0) * float(i + 1) / steps
		verts.append(Vector3.ZERO)
		verts.append(aim.rotated(Vector3.UP, a0) * reach)
		verts.append(aim.rotated(Vector3.UP, a1) * reach)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	mesh.surface_set_material(0, material)

	var slash := MeshInstance3D.new()
	slash.mesh = mesh
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position + Vector3.UP * 0.4

	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(slash.queue_free)
