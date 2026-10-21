extends Area3D

@export var speed: float = 20.0
var direction: Vector3 = Vector3.ZERO

@export var target : Vector3:
	set(new):
		target = new
		look_at(target, Vector3.UP)
		if direction == Vector3.ZERO:
			direction = -global_transform.basis.z.normalized()
			global_position += direction * 3


func _physics_process(delta: float) -> void:
	# If a custom direction wasn't assigned, default to its own local forward (-Z)
		
	# Standard directional movement
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(10)
	queue_free() # Destroy bullet on impact
