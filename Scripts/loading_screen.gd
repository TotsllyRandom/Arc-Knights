extends Control

var progress: float = 0.0
var maxval: float = 100.0

func _ready() -> void:
	$ProgressBarTop.max_value = maxval
	$ProgressBarBottom.max_value = maxval
	set_progress(0.0)

func set_progress(i: float) -> void:
	progress = clampf(i, 0.0, maxval)
	$ProgressBarTop.value = progress
	$ProgressBarBottom.value = progress
