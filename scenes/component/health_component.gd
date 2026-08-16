extends Node
class_name HealthComponent

signal died
signal health_changed

@export var max_health: float = 10
var current_heath


func _ready() -> void:
	current_heath = max_health

func damage(damage_amount: float):
	current_heath = max(current_heath - damage_amount, 0)
	health_changed.emit()
	Callable(check_death).call_deferred()
		

func get_health_percent():
	if max_health <=0:
		return
	return min(current_heath / max_health , 1)

		
func check_death():
	if current_heath == 0 :
		died.emit()
		owner.queue_free()
