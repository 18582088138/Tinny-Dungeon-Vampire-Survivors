extends CharacterBody2D

@onready var velocity_componet: Node = $VelocityComponet
@onready var visuals: Node2D = $Visuals

func _process(delta):
	velocity_componet.accelerate_to_player()
	velocity_componet.move(self)
	
	var move_sign = sign(velocity.x)
	if move_sign != 0 :
		visuals.scale = Vector2(-move_sign, 1)
