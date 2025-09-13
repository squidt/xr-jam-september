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

@onready var Enemy = preload("uid://voe6qwp6kme4")  # enemy.tscn
@onready var paths := [$Center, $Left, $Right]
@onready var round_timer := $BetweenRounds


func _process(delta: float) -> void:
	if !is_multiplayer_authority():
		return

	_process_round(delta)

	_total_time += delta
	for e in _enemies:
		if e:
			e.progress += e.speed * delta

	_enemies = _enemies.filter(func(v): return is_instance_valid(v))


func _process_round(delta: float) -> void:
	if _spawn_remaining < 1:
		if round_timer.is_stopped():
			round_timer.start()
		return

	_spawn_delta_total += delta
	if _spawn_delta_total > _spawn_delay_rand:
		_spawn_delta_total = 0.0
		_spawn_delay_rand = randf_range(0.1, 1.0)
		spawn()


func increment_round() -> void:
	if is_multiplayer_authority():
		_round_count += 1
		@warning_ignore("narrowing_conversion")
		var sample = difficulty_curve.sample_baked(float(_round_count) / float(max_rounds))
		_spawn_remaining = sample * max_enemies
		#print_debug("round %s: spawning %s enemies" % [_round_count, _spawn_remaining])


func spawn() -> void:
	if !multiplayer.is_server():
		return

	_spawn_remaining -= 1
	var enemy = Enemy.instantiate()
	_enemies.append(enemy)
	paths.pick_random().add_child(enemy, true)
