extends Area3D

# A loot box in a treasure room. Walk into it to open it: it rolls one random item from the drop
# list of the dungeon it's in (see "drops" in Items.gd) and puts it in your inventory. A popup
# above the box says what you got. If your inventory is full, the box stays closed and says so,
# so you can make room and walk back into it.

# Which dungeon's drop list this box uses. The dungeon sets this when it places the box.
@export var dungeon_id := "test_dungeon"

const OPENED_COLOR := Color(0.25, 0.2, 0.1)

var opened := false
var popup_tween: Tween

@onready var mesh: MeshInstance3D = $Mesh
@onready var popup: Label3D = $Popup


func _ready() -> void:
	popup.visible = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if opened or not body.is_in_group("player"):
		return
	open()


func open() -> void:
	var item := Items.roll_drop(dungeon_id)
	if item.is_empty():
		# Nothing can drop in this dungeon
		_finish_opening("Empty")
		return

	if Inventory.add_item(item):
		_finish_opening(Items.pickup_text(item))
	else:
		# No room: the box stays closed so the player can try again
		_show_popup("Inventory full")


# The box is used up: it goes dark, and the popup says what was inside
func _finish_opening(message: String) -> void:
	opened = true
	var material := StandardMaterial3D.new()
	material.albedo_color = OPENED_COLOR
	mesh.material_override = material
	_show_popup(message)


# Shows a line of text above the box that drifts up and fades out
func _show_popup(message: String) -> void:
	if popup_tween != null:
		popup_tween.kill()
	popup.text = message
	popup.position = Vector3(0.0, 1.4, 0.0)
	popup.modulate.a = 1.0
	popup.visible = true
	popup_tween = create_tween().set_parallel(true)
	popup_tween.tween_property(popup, "position:y", 2.2, 1.5).set_delay(1.0)
	popup_tween.tween_property(popup, "modulate:a", 0.0, 1.5).set_delay(1.0)
	popup_tween.chain().tween_callback(popup.hide)
