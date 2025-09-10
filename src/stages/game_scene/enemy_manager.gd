extends Node3D

@export var difficulty_curve: Curve = Curve.new()
@export var max_enemies: int = 100
@export var max_rounds: int = 20

var _enemies: Array[EnemyPather] = []
var _round_count: int = 1
var _total_time: float = 0.0
var _spawn_delay_rand := randf_range(0.1, 1.0)
var _spawn_delta_total := 0.0
var _spawn_remaining := 0

@onready var Enemy = preload("uid://voe6qwp6kme4") # enemy.tscn
@onready var paths := [$Center, $Left, $Right]
@onready var rounds := $Rounds


func _process(delta: float) -> void:
	_process_round(delta)

	_total_time += delta
	for e in _enemies:
		if e:
			e.progress += e.speed * delta


func _process_round(delta: float) -> void:
	if _spawn_remaining < 1:
		return

	_spawn_delta_total += delta
	if _spawn_delta_total > _spawn_delay_rand:
		_spawn_delta_total = 0.0
		_spawn_delay_rand = randf_range(0.1, 1.0)
		_spawn_remaining -= 1
		spawn()


func increment_round() -> void:
	_round_count += 1
	_spawn_remaining = difficulty_curve.sample_baked(float(_round_count) / float(max_rounds)) * max_enemies


func spawn() -> void:
	print("enemy_spawn@: ", _total_time)
	var enemy = Enemy.instantiate()
	_enemies.append(enemy)
	# Remove from list on free
	enemy.tree_exiting.connect(
		func(): 
			await get_tree().process_frame
			_enemies.erase(enemy))
	paths.pick_random().add_child(enemy)
