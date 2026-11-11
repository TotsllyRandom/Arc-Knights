extends "res://Scripts/enemy.gd"

# The boss that waits in the exit room. It moves, gets knocked back and dies like any enemy
# (see enemy.gd), but it's bigger, slower and much tougher. Its stats are set in boss.tscn.
# When it dies it sends the "died" signal, which the dungeon uses to end the run.

@export var boss_name := "Exit Guardian"

var health_bar_layer: CanvasLayer
var health_bar: ProgressBar


# The boss's health bar appears when its room is revealed
func _activate() -> void:
	super._activate()
	if health_bar_layer == null:
		_create_health_bar()


func _health_changed() -> void:
	if health_bar != null:
		health_bar.value = health


# Name and health bar across the top of the screen
func _create_health_bar() -> void:
	health_bar_layer = CanvasLayer.new()
	add_child(health_bar_layer)

	var box := VBoxContainer.new()
	health_bar_layer.add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -320.0
	box.offset_right = 320.0
	box.offset_top = 20.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.text = boss_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(640, 22)
	health_bar.show_percentage = false
	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.1, 0.1)
	health_bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	health_bar.add_theme_stylebox_override("background", background)
	box.add_child(health_bar)
