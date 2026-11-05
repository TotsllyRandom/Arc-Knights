extends CharacterBody3D

@export var room := 0
var health = 10:
	set(new):
		if new <=0:
			health = 0
		else:
			health = new
		if health == 0:
			queue_free()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false


func take_damage(amt):
	health -= amt
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float):
	if not RoomMaker.revealed.has(room):
		return
	visible = true
	look_at(Vector3($"../../Player".position.x,position.y,$"../../Player".position.z))
	var direction = -global_transform.basis.z.normalized()
	
	velocity = direction * 4
	move_and_slide()
