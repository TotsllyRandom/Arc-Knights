extends Control

# One square on the inventory screen. It can be a bag space or an equipment slot (head, arms,
# legs, a ring, or a weapon). It shows the item in it, and handles dragging items in and out.
#   - Drag an item onto another slot to move it (or swap it, if that slot has an item).
#   - Right-click an item to equip it, or to take it off if it's already equipped.
#   - Hover over an item to see its stars and pips.

# How big a slot is, in pixels. Smaller means a smaller inventory screen.
const SLOT_SIZE := 40.0

# Which slot this is: "bag0" to "bag49", or "head", "ring2", "weapon1" and so on (see Inventory.gd)
var slot_id := ""
# What the slot says while it's empty, like "Head"
var empty_text := ""

var hovered := false
# true for a bag item that's past the carry limit (it slows the player down)
var overloaded := false
var item_swatch: ColorRect
var name_label: Label
var count_label: Label
var stars_label: Label
var empty_label: Label


# Call this right after adding the slot to the screen
func setup(id: String, label_text: String) -> void:
	slot_id = id
	empty_text = label_text
	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	size = Vector2(SLOT_SIZE, SLOT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))

	# A colored square stands in for the item's picture until there's item art
	item_swatch = ColorRect.new()
	item_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_swatch.offset_left = 4.0
	item_swatch.offset_top = 4.0
	item_swatch.offset_right = -4.0
	item_swatch.offset_bottom = -4.0
	add_child(item_swatch)

	name_label = _make_label(9, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	_outline(name_label)
	add_child(name_label)

	count_label = _make_label(10, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	_outline(count_label)
	add_child(count_label)

	# One * for each star the item rolled
	stars_label = _make_label(11, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	stars_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_outline(stars_label)
	add_child(stars_label)

	empty_label = _make_label(9, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	empty_label.modulate = Color(1.0, 1.0, 1.0, 0.35)
	empty_label.text = empty_text
	add_child(empty_label)

	refresh()


func _make_label(font_size: int, horizontal: HorizontalAlignment, vertical: VerticalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.add_theme_font_size_override("font_size", font_size)
	return label


# A dark edge around text so it can be read on any color
func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)


func _set_hovered(value: bool) -> void:
	hovered = value
	queue_redraw()


# Redraws what's in this slot. Called whenever the inventory changes.
func refresh() -> void:
	var item = Inventory.get_item(slot_id)
	var has_item: bool = item != null
	item_swatch.visible = has_item
	name_label.visible = has_item
	empty_label.visible = not has_item and empty_text != ""

	if not has_item:
		overloaded = false
		queue_redraw()
		count_label.visible = false
		stars_label.visible = false
		tooltip_text = ""
		return

	# Items past your carry limit are marked in red
	overloaded = Inventory.is_bag_slot(slot_id) and Inventory.bag_index(slot_id) >= Inventory.get_carry_capacity()
	queue_redraw()

	item_swatch.color = item.get("color", Color.GRAY)
	name_label.text = item.get("name", "")
	var count: int = int(item.get("count", 1))
	count_label.visible = count > 1
	count_label.text = str(count)

	var stars: int = int(item.get("stars", 0))
	stars_label.visible = item.get("has_stars", false) and stars > 0
	stars_label.text = "*".repeat(stars)

	var tip: String = Items.tooltip(item)
	if Inventory.is_bag_slot(slot_id) and item.get("slot", "") != "":
		tip += "\n\nRight-click to equip"
	elif not Inventory.is_bag_slot(slot_id):
		tip += "\n\nRight-click to take off"
	if overloaded:
		tip += "\n\nOver your carry limit: this is slowing you down"
	tip += "\nDrag outside the inventory to drop it"
	tooltip_text = tip


# The square itself: a see-through dark box with a border. The border lights up when the mouse is
# over it, and is red for items past your carry limit.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.13, 0.6))
	var border := Color(1.0, 1.0, 1.0, 0.9) if hovered else Color(1.0, 1.0, 1.0, 0.25)
	if overloaded:
		border = Color(1.0, 0.3, 0.3, 0.9)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 2.0)


# Right-click equips or unequips
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		Inventory.quick_move(slot_id)
		accept_event()


# ---------------------------------------------------------------- dragging

# Picking up the item in this slot
func _get_drag_data(_at_position: Vector2) -> Variant:
	var item = Inventory.get_item(slot_id)
	if item == null:
		return null

	# The small picture that follows the mouse while dragging
	var preview := Control.new()
	var swatch := ColorRect.new()
	swatch.color = item.get("color", Color.GRAY)
	swatch.size = Vector2(SLOT_SIZE - 8.0, SLOT_SIZE - 8.0)
	swatch.position = -swatch.size / 2.0
	preview.add_child(swatch)
	var label := Label.new()
	label.text = item.get("name", "")
	label.add_theme_font_size_override("font_size", 9)
	_outline(label)
	label.position = swatch.position
	preview.add_child(label)
	set_drag_preview(preview)

	return {"from": slot_id}


# Is it OK to drop the dragged item on this slot? (It has to be allowed in this kind of slot.)
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from") and Inventory.can_move(data["from"], slot_id)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Inventory.move_item(data["from"], slot_id)
