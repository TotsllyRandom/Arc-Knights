extends CanvasLayer

# The inventory screen. Press Tab to open it, and Tab or Escape to close it. The game pauses while it's open,
# but the screen is small and doesn't dim anything, so you can still see the game while you edit.
#   - Left side of the screen: the bag, 10 spaces across and 5 down.
#   - Right side: your light color, the armor slots (head, arms, legs), 4 ring slots, 2 weapon slots,
#     and the stats (pips) added up from everything you have equipped.
# The items themselves live in Inventory.gd and Items.gd; this screen just shows and edits them.
# How the screen looks (text, spacing, colors) is in Scenes/inventory_screen.tscn.

const InventorySlot := preload("res://Scripts/inventory_slot.gd")
const TOGGLE_KEY := KEY_TAB

const ARMOR_SLOTS := ["head", "arms", "legs"]
const RING_SLOTS := ["ring1", "ring2", "ring3", "ring4"]
const WEAPON_SLOTS := ["weapon1", "weapon2"]

@onready var light_swatch: ColorRect = %LightSwatch
@onready var light_label: Label = %LightLabel
@onready var armor_row: HBoxContainer = %ArmorSlots
@onready var ring_row: HBoxContainer = %RingSlots
@onready var weapon_row: HBoxContainer = %WeaponSlots
@onready var bag_grid: GridContainer = %BagGrid
@onready var stats_label: Label = %StatsLabel

# Every slot on the screen
var slots := []


func _ready() -> void:
	visible = false

	for slot_id in ARMOR_SLOTS:
		_add_slot(armor_row, slot_id)
	for slot_id in RING_SLOTS:
		_add_slot(ring_row, slot_id)
	for slot_id in WEAPON_SLOTS:
		_add_slot(weapon_row, slot_id)

	bag_grid.columns = Inventory.BAG_COLUMNS
		for i in range(Inventory.BAG_SIZE):
		_add_slot(bag_grid, Inventory.bag_slot_id(i))

	Inventory.changed.connect(refresh)
	refresh()


func _add_slot(parent: Control, slot_id: String) -> void:
	var slot = InventorySlot.new()
	parent.add_child(slot)
	slot.setup(slot_id, Inventory.SLOT_LABELS.get(slot_id, ""))
	slots.append(slot)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == TOGGLE_KEY:
		if visible:
			close()
		else:
			open()
		# Tab would otherwise also move the keyboard focus around
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and visible:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	# Something else (like the end screen) already has the game paused
	if get_tree().paused:
		return
	refresh()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


# Redraws every slot, the light color and the stats
func refresh() -> void:
	for slot in slots:
		slot.refresh()
	_refresh_light()
	_refresh_stats()


# The pips of everything equipped, added up
func _refresh_stats() -> void:
	var text: String = Items.totals_text(Inventory.get_total_pips())
	stats_label.text = text if text != "" else "None"


# Shows the color of the player's light
func _refresh_light() -> void:
	var color := Color(1.0, 0.0, 0.0)
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "light_color" in player:
		color = player.light_color
	light_swatch.color = color
	light_label.text = "Light: " + _light_name(color)


# A name for a light color. The design has green, white and black lights, plus the red default.
func _light_name(color: Color) -> String:
	if color.is_equal_approx(Color(1.0, 0.0, 0.0)):
		return "Red"
	if color.is_equal_approx(Color(0.0, 1.0, 0.0)):
		return "Green"
	if color.is_equal_approx(Color(1.0, 1.0, 1.0)):
		return "White"
	if color.is_equal_approx(Color(0.0, 0.0, 0.0)):
		return "Black"
	return "#" + color.to_html(false)
