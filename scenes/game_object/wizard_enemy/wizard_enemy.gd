extends CharacterBody2D

@onready var velocity_componet: Node = $VelocityComponet
@onready var visuals: Node2D = $Visuals

var is_moving = false

func _ready():
	$HurtboxComponent.hit.connect(on_hit)

func _process(delta):
	if is_moving:
		velocity_componet.accelerate_to_player()
	else:
		velocity_componet.decelerate()
	
	velocity_componet.move(self)
	
	var move_sign = sign(velocity.x)
	if move_sign != 0 :
		visuals.scale = Vector2(move_sign, 1)


func set_is_moving(moving: bool):
	is_moving = moving

func on_hit():
	$HitRandomAudioPlayerComponent.play_random()
