
extends Node

var loading_screen = preload("res://Scenes/loading_screen.tscn")

func load_level(path: String) -> void:
	var screen = loading_screen.instantiate()
	get_tree().root.add_child(screen)

	screen.set_progress(0.0)

	# Give Godot time to display the loading screen
	await RenderingServer.frame_post_draw

	var error = ResourceLoader.load_threaded_request(path)

	if error != OK:
		screen.queue_free()
		push_error("Failed to start loading: " + path)
		return

	var progress = []

	while true:
		var status = ResourceLoader.load_threaded_get_status(
			path, progress
		)

		if progress.size() > 0:
			screen.set_progress(progress[0] * 100.0)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break

		if status == ResourceLoader.THREAD_LOAD_FAILED:
			screen.queue_free()
			push_error("Failed to load: " + path)
			return

		await get_tree().process_frame

	# Finish the progress bar
	screen.set_progress(100.0)

	var packed_scene = ResourceLoader.load_threaded_get(path)
	var new_scene = packed_scene.instantiate()

	# Replace the old scene
	var old_scene = get_tree().current_scene
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	if old_scene:
		old_scene.queue_free()

	screen.queue_free()
