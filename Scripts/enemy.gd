extends CharacterBody3D

@export var room := 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	look_at(Vector3($"../../Player".position.x,position.y,$"../../Player".position.z))
	var direction = -global_transform.basis.z.normalized()
	
	velocity = direction
	move_and_slide()
