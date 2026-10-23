extends CharacterBody3D

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
	rotation.y = 0
	target_rotation.y = rotation.y
	target_rotation.x = cam_rotate.rotation.x

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
	
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) && gun_cd == 0.0:
		var cam = $RotateCamera/Hold/Camera3D
		var mousepos = get_viewport().get_mouse_position()
		
		var origin = cam.project_ray_origin(mousepos)
		var end = origin + cam.project_ray_normal(mousepos) * 1000
		
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = [get_rid()]
		
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		
		var target = end
		if result:
			target = result.position
		
		var b = bullet.instantiate()
		get_tree().current_scene.add_child(b)
		
		b.global_position = global_position + Vector3.UP
		b.target = target
		
		gun_cd = 1.0
		
