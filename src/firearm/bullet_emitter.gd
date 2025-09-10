class_name BulletEmitter extends Node3D

@onready var Muzzleflash := preload("uid://crj658urku6dq")
@onready var BulletScene := preload("uid://d0wq6vy45jc45")


func trigger() -> void:
	var muzz = Muzzleflash.instantiate()
	muzz.top_level = true
	muzz.global_transform = global_transform
	add_child(muzz)

	var bullet = BulletScene.instantiate()
	bullet.global_transform = global_transform
	bullet.top_level = true
	add_child(bullet)
