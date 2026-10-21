extends StaticBody3D

@onready var player = $"../../Player"
@export var type := "wall"
var target_height : int = 0

func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	position.y = lerpf(position.y,target_height,0.2)
	if type == "door":
		if Vector2(position.x,position.z).distance_to(Vector2(player.position.x,player.position.z)) < 3:
			type = "open"
	if type == "open":
		target_height = -3
	else:
		target_height = 0
