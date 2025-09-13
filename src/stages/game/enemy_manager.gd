extends Node3D

signal round_increased

@export var difficulty_curve: Curve = Curve.new()
@export var max_enemies: int = 100
@export var max_rounds: int = 20

var _enemies: Array[EnemyPather] = []
var _round_count: int = 0
var _spawn_delay_rand := randf_range(0.1, 1.0)
var _spawn_delta_total := 0.0
var _spawn_remaining := 0

@onready var Enemy = preload("uid://voe6qwp6kme4")  # enemy.tscn
@onready var path := $Center
@onready var between_round_timer := $BetweenRounds

# Sounds
@onready var audio_player := $RoundStartSound
@onready var whistle := load("res://src/stages/game/162802__timgormly__toy-train-whistle2_reverb.wav")
@onready var bells := load("res://src/stages/game/479978__craigsmith__r04-35-brass-bell_reverb.wav")


func _ready() -> void:
	# prevents errors for some reason
	audio_player.play()


func _process(delta: float) -> void:
	if !is_multiplayer_authority():
		return

	_process_round(delta)

	for e in _enemies:
		if e:
			e.progress += e.speed * delta

			# Converge to center at the end
			if e.progress_ratio >= .65:
				_converge_x_axis(e, delta)

	_enemies = _enemies.filter(func(v): return is_instance_valid(v))
	if _enemies.is_empty() and between_round_timer.is_stopped():
		round_end()


func _process_round(delta: float) -> void:
	_spawn_delta_total += delta
	if _spawn_delta_total > _spawn_delay_rand:
		_spawn_delta_total = 0.0
		_spawn_delay_rand = randf_range(0.1, 1.0)

	if _spawn_remaining > 0:
		spawn()


func round_start() -> void:
	var playback = audio_player.get_stream_playback()
	playback.play_stream(bells)
	playback.play_stream(whistle)

	round_increased.emit()
	_round_count += 1
	@warning_ignore("narrowing_conversion")
	var sample = difficulty_curve.sample_baked(float(_round_count) / float(max_rounds))
	@warning_ignore("narrowing_conversion")
	_spawn_remaining = sample * max_enemies
	#print_debug("round %s: spawning %s enemies" % [_round_count, _spawn_remaining])


func round_end() -> void:
	between_round_timer.start()


func spawn() -> void:
	#print("  spawn #", _spawn_remaining)
	_spawn_remaining -= 1
	var enemy = Enemy.instantiate()
	enemy.im_dying_tell_my_children_i.connect(_on_enemy_death)
	_enemies.append(enemy)

	_randomize_x_axis(enemy)
	
	if _round_count > 10:
		enemy.speed = enemy.speed * (_round_count * .1)
		enemy.health = min(200.0, enemy.health + 10 * (_round_count / 10))
	
	path.add_child(enemy, true)


func _randomize_x_axis(node: PathFollow3D) -> void:
	node.h_offset += randf_range(-15.0, 15.0)


func _converge_x_axis(node: PathFollow3D, delta: float) -> void:
	var c = clampf(node.h_offset, -1.0, 1.0)
	node.h_offset = move_toward(node.h_offset, c, delta * 2.0)


func _on_enemy_death() -> void:
	MainStage.instance.player_wallet += 100
