extends ScrollContainer

# The scrolling area that holds the bag. Dropping an equipped item anywhere on it, even on the
# empty part, takes the item off and puts it in the bag. (Dropping onto an item swaps with it.)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("from")):
		return false
	# Only equipped items can be dropped here; items already in the bag have nothing to do
	return not Inventory.is_bag_slot(data["from"]) and Inventory.get_item(data["from"]) != null


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Inventory.unequip_to_bag(data["from"])
