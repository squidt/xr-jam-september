class_name EnemyPather extends PathFollow3D

@export var health: float = 100.0:
	set(v):
		health = v
		if health <= 0.0:
			die()
@export var speed: float = .5

func die() -> void:
	# do something then
	queue_free()
