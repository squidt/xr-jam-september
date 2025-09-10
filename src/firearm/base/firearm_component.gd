class_name FirearmComponent extends Node3D

@export var firearm: Firearm:
	get():
		if firearm:
			return firearm
		return get_parent() as Firearm


func _get_configuration_warnings() -> PackedStringArray:
	if !get_parent() or get_parent() is not Firearm:
		return ["Must be the child of a [Firearm] node"]
	return []
