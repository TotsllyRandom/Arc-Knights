extends CanvasLayer

# The screen shown when the boss is defeated. It pauses the game, shows how the run went,
# and sends "continued" when the player presses a key or clicks. The dungeon then loads a new one.
# The look of the screen (text, sizes, colors) is in Scenes/end_screen.tscn.

signal continued

# The dungeon fills these in before adding this screen
var run_time_seconds := 0.0
var enemies_defeated := 0

# Seconds before the screen accepts input, so a click from fighting doesn't skip it
const INPUT_DELAY := 1.5
# 0 = wait for the player to press a key. Anything higher continues by itself after that many seconds.
const AUTO_CONTINUE_SECONDS := 0.0
const FADE_TIME := 0.6

var can_continue := false
var finished := false

@onready var root: Control = $Root
@onready var stats_label: Label = $Root/Center/Box/Stats
@onready var prompt_label: Label = $Root/Center/Box/Prompt


func _ready() -> void:
	# This scene keeps running while the rest of the game is paused (set in the scene's Process Mode)
	get_tree().paused = true

	var minutes := floori(run_time_seconds / 60.0)
	var seconds := int(run_time_seconds) % 60
	stats_label.text = "Time  %d:%02d\nEnemies defeated  %d" % [minutes, seconds, enemies_defeated]
	prompt_label.visible = false

	# Fade in
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, FADE_TIME)

	await get_tree().create_timer(INPUT_DELAY).timeout
	can_continue = true
	prompt_label.visible = true

	if AUTO_CONTINUE_SECONDS > 0.0:
		await get_tree().create_timer(AUTO_CONTINUE_SECONDS).timeout
		_finish()


func _input(event: InputEvent) -> void:
	if not can_continue or finished:
		return
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var pressed_click: bool = event is InputEventMouseButton and event.pressed
	if pressed_key or pressed_click:
		_finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	continued.emit()
