extends AudioStreamPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	finished.connect(on_finished)
	$Timer.timeout.connect(on_timer_timout)


func on_finished():
	$Timer.start()
	
func on_timer_timout():
	play()
