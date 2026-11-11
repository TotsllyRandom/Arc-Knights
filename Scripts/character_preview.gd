extends SubViewportContainer

# A slowly turning 3D model of the character, shown on the inventory screen. It's built from
# simple shapes (a torso, a head, two arms, two legs) in character_preview.tscn.
# Armor will go on it later: set_armor() tints a body part with an armor piece's color for now,
# and this is where real armor models would be attached.

const SKIN_COLOR := Color(0.75, 0.75, 0.8)
# How fast the model turns, in radians per second
const TURN_SPEED := 0.8

@onready var model: Node3D = $Viewport/Model
@onready var torso: MeshInstance3D = $Viewport/Model/Torso
# The body parts each armor slot covers
@onready var parts := {
	"head": [$Viewport/Model/Head],
	"arms": [$Viewport/Model/ArmLeft, $Viewport/Model/ArmRight],
	"legs": [$Viewport/Model/LegLeft, $Viewport/Model/LegRight],
}


func _ready() -> void:
	# Give every part its own material, so each can be tinted separately
	torso.material_override = _make_material(SKIN_COLOR)
	for part_list in parts.values():
		for part in part_list:
			part.material_override = _make_material(SKIN_COLOR)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


# Keeps turning, even while the game is paused behind the inventory screen
func _process(delta: float) -> void:
	model.rotate_y(delta * TURN_SPEED)


# Dresses a body part ("head", "arms" or "legs") in an armor color. Pass null to take it off.
func set_armor(slot_name: String, color: Variant) -> void:
	var tint: Color = SKIN_COLOR
	if color != null:
		tint = color
	for part in parts.get(slot_name, []):
		part.material_override.albedo_color = tint
