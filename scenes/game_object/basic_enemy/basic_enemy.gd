extends CharacterBody2D

@onready var visuals = $Visuals
@onready var velocity_componet = $VelocityComponet


func _ready():
	$HurtboxComponent.hit.connect(on_hit)


func _process(delta):
	velocity_componet.accelerate_to_player()
	velocity_componet.move(self)
	
	var move_sign = sign(velocity.x)
	if move_sign != 0 :
		visuals.scale = Vector2(move_sign, 1)
		
		
func on_hit():
	$HitRandomAudioPlayerComponent.play_random()
