class_name EnemyPather extends PathFollow3D

signal im_dying_tell_my_children_i


@export var health: float = 100.0:
	set(v):
		if v < health:
			speed *= .8

		health = v
		if health <= 0.0:
			die()
@export var speed: float = .5


func die() -> void:
	im_dying_tell_my_children_i.emit()
	# do something then
	queue_free()
