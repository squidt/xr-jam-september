class_name BulletEmitter extends Node3D


@export var firearm: Firearm

@onready var Muzzleflash := preload("uid://crj658urku6dq")
@onready var BulletScene := preload("uid://d0wq6vy45jc45")



func _ready() -> void:
	firearm.fired.connect(func(): trigger.rpc_id(1))


@rpc("any_peer", "call_local")
func trigger() -> void:
	var muzz = Muzzleflash.instantiate()
	muzz.top_level = true
	muzz.global_transform = global_transform
	add_child(muzz, true)

	var bullet = BulletScene.instantiate()
	bullet.global_transform = global_transform
	bullet.top_level = true
	add_child(bullet, true)
