extends StaticBody3D

@export var type := "wall"
var target_height : int = 0

# While this is above 0 the door is held shut.
# The dungeon uses it to lock a room while its enemies are alive.
var lock_count := 0

func _ready() -> void:
	if type == "wall":
		set_process(false)


# Holds the door shut. Locks stack, so a door shared by two rooms stays shut until both release it.
func lock() -> void:
	lock_count += 1


# Releases one lock. Once nothing is holding it shut, the door opens and stays open.
func unlock() -> void:
	lock_count = maxi(lock_count - 1, 0)
	if lock_count == 0:
		type = "open"


# Opens the door and leaves it open (unless it's locked, in which case it opens once it's unlocked).
# Doors don't open on their own when the player walks up to them: the dungeon opens a room's doors
# when the player enters that room.
func open_door() -> void:
	type = "open"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	position.y = lerpf(position.y,target_height,0.2)

	# A locked door stays closed
	if lock_count > 0:
		target_height = 0
		return

	if type == "open":
		target_height = -3
	else:
		target_height = 0
