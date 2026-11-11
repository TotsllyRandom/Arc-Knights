extends Control

# A full-screen invisible area behind the inventory panels. It does nothing most of the time and
# lets mouse clicks through to the game. While you're dragging an item, it catches the drop, so
# letting go of an item anywhere outside the panels drops it on the ground.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# Godot tells every control when a drag starts and ends
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		mouse_filter = Control.MOUSE_FILTER_STOP
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Inventory.drop_item(data["from"])
