extends Node

const SPAWN_RADIUS = 330

@export var basic_enemy_scene: PackedScene
@export var wizard_enemy_scene: PackedScene
@export var arena_time_manager: Node

@onready var timer = $Timer

var base_spawn_time = 0
var enemy_table = WeightedTable.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	enemy_table.add_item(basic_enemy_scene, 10)
	base_spawn_time = timer.wait_time
	timer.timeout.connect(on_timer_timeout)
	arena_time_manager.arena_difficulty_increased.connect(on_arena_difficulty_increased)

func get_spawn_position():
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO
	
	var spawn_postion = Vector2.ZERO
	var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))

	# 转 8 次 45 度试满一圈；原来只试 4 个方向，很容易全被墙挡住。
	for i in 8:
		spawn_postion = player.global_position + (random_direction * SPAWN_RADIUS)

		var query_paramaters = PhysicsRayQueryParameters2D.create(player.global_position, spawn_postion, 1)
		var result = get_tree().root.world_2d.direct_space_state.intersect_ray(query_paramaters)

		if result.is_empty():
			return spawn_postion
		else :
			random_direction = random_direction.rotated(deg_to_rad(45))
	# 一圈都被挡住说明玩家离墙太近，没有合法落点。原来这里会把最后一个
	# 被挡住的点返回出去，怪就刷到墙外了 —— 现在改成返回一个哨兵值，本次不刷怪。
	return Vector2.INF

func on_timer_timeout():
	timer.start()
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return 
		
	# 先算落点再生成，找不到合法落点就跳过这一次，不要把怪生出来再丢到墙外。
	var spawn_postion = get_spawn_position()
	if spawn_postion == Vector2.INF:
		return

	var enemy_scene = enemy_table.pick_item()
	var enemy = enemy_scene.instantiate() as Node2D

	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	entities_layer.add_child(enemy)
	enemy.global_position = spawn_postion
	

func on_arena_difficulty_increased(arena_difficulty: int):
	var time_off = (.1 / 12) * arena_difficulty
	time_off = min(time_off, .7)
	timer.wait_time = base_spawn_time - time_off
	
	if arena_difficulty == 1:
		enemy_table.add_item(wizard_enemy_scene, 20)
