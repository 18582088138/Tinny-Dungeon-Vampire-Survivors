extends CharacterBody2D

const MAX_SPEED: float = 125.0
const ACCELERATION_SMOOTHING = 25

@onready var damage_interval_timer = $DamageIntervalTimer
@onready var health_component = $HealthComponent
@onready var health_bar = $HealthBar

var number_colliding_bodies = 0

func _ready():
	$CollisionArea2D.body_entered.connect(on_body_entered)
	$CollisionArea2D.body_exited.connect(on_body_exited)
	damage_interval_timer.timeout.connect(on_damage_interval_timer_timeout)
	health_component.health_changed.connect(on_health_changed)
	update_health_display()

# move_and_slide() 依赖固定的物理步长，必须放在 _physics_process 而不是 _process，
# 否则移动速度会随显示器刷新率变化（144Hz 上会比 60Hz 快一倍多）。
# move_and_slide() relies on the fixed physics step, so it belongs in _physics_process,
# not _process — otherwise speed scales with monitor refresh rate.
func _physics_process(_delta: float) -> void:
	var movement_vector = get_movement_vector()
	var direction: Vector2 = movement_vector.normalized()
	var target_velocity = direction * MAX_SPEED
	velocity = velocity.lerp(target_velocity, 1 - exp(-_delta * ACCELERATION_SMOOTHING)) 
	move_and_slide()


# 读取四个方向 action 的强度，合成一个未归一化的方向向量。
# Read the four directional actions into a single un-normalized direction vector.
# 这里的 action 名由 tools/setup_input_map.gd 写入 project.godot；
# The action names are written into project.godot by tools/setup_input_map.gd;
# 缺失时 Godot 会报错并恒返回 0，表现为"按键完全无反应"。
# if they are missing Godot errors and always returns 0, which looks like dead keys.
func get_movement_vector() -> Vector2:
	var x_movement: float = (
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	)
	var y_movement: float = (
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return Vector2(x_movement, y_movement)


func check_deal_damage():
	if number_colliding_bodies == 0 || !damage_interval_timer.is_stopped():
		return 
	health_component.damage(1)
	damage_interval_timer.start()
	print(health_component.current_heath)
	

func update_health_display():
	health_bar.value = health_component.get_health_percent()

func on_body_entered(other_body: Node2D):
	number_colliding_bodies += 1
	check_deal_damage()
	
	
func on_body_exited(other_body: Node2D):
	number_colliding_bodies -= 1
	
	
func on_damage_interval_timer_timeout():
	check_deal_damage()


func on_health_changed():
	update_health_display()
