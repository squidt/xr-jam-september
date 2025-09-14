class_name AmmoBeltPart extends Node3D

signal try_attach

const OFFSET_START := 0.238
const OFFSET_END := 0.478

@onready var handle := $HandleOrigin/InteractableHandle
@onready var ammo_path := $"../Path3D"
@onready var start := $"../Start"
@onready var end := $"../End"

var is_gun_connected := false
var ammo_max := 100
var ammo_count := 100

var _grabbed_by : Node3D = null
var _total_dist := 0.0


func _ready() -> void:
	_total_dist = start.global_position.distance_to(end.global_position)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or !_grabbed_by:
		return

	var dist = end.global_position.x - _grabbed_by.global_position.x
	ammo_path.start_offset = remap(dist, _total_dist, 0.0, OFFSET_START, OFFSET_END+.05)

	# Snap to finish
	if ammo_path.start_offset >= OFFSET_END - .05:
		try_attach.emit()


func has_ammo() -> bool:
	return ammo_count > 0


func take_bullet() -> void:
	ammo_count -= 1

	# Hide the next unhidden model
	var idx = ammo_path.instances.find_custom(func(v): return v and v.visible)
	if idx != -1:
		ammo_path.instances[idx].visible = false

	if !has_ammo():
		ammo_path.hide()


func belt_attach() -> void:
	handle.drop()
	ammo_path.start_offset = OFFSET_END
	is_gun_connected = true


func belt_detach() -> void:
	ammo_path.start_offset = OFFSET_START
	is_gun_connected = false


func _on_handle_grabbed(_pickable: Variant, by: Variant) -> void:
	_grabbed_by = by
	is_gun_connected = false


func _on_handle_dropped(_pickable: Variant) -> void:
	_grabbed_by = null


# Enable when placed in correct snap zone
func _on_ammo_can_grabbed(_pickable: Variant, by: Variant) -> void:
	if by is XRToolsSnapZone:
		handle.enabled = true
		ammo_path.start_offset = OFFSET_START
	else:
		handle.enabled = false
		belt_detach()


# hide correct amount of bullets
func _on_path_3d_updated() -> void:
	var fired_count = ammo_max - ammo_count
	fired_count = min(fired_count, ammo_path.instances.size())
	for i in range(fired_count):
		ammo_path.instances[i].hide()
