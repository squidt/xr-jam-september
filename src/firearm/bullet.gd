class_name Bullet extends Node3D

## Inspired by:
# https://www.youtube.com/watch?v=Qt3OLcxlIBM

signal lifetime_timeout
signal destroyed
signal contact(result: Dictionary)
signal ricochet(result: Dictionary)
signal penetration(result: Dictionary)

@export_group("Bullet Settings")
@export var damage := 30.0
@export var speed := 500.0
@export var ricochet_max := 2
## Maximum time the bullet can exist before being destroyed
@export_custom(0, "suffix:s") var lifetime := 10.0
## Maximum range the bullet can travel before being destroyed
@export_custom(0, "suffix:m") var range_max := 500.0
## 0 degrees is a perpendicular hit, 90 degrees is a hit along the plane
@export var ricochet_angle := 50
@export_custom(0, "suffix:m/s") var gravity := Vector3(0, -9.8, 0)
@export_flags_3d_physics var collision_mask := 7  # flags: 1, 2, 3

@export_category("Decals")
@export var decal_hitbox: PackedScene
@export var decal_terrain: PackedScene

@export_category("Sounds")
@export var sound_impact: AudioStream
@export var sound_ricochet: AudioStream

var exclude_add := []

# Ballistic data
var _prev_position := Vector3.ZERO
var _velocity := Vector3.ZERO
var _distance_travelled := 0.0

# Debug
var _debug_draw_lifetime := 10
var _debug_line_thickness := 0.0005
var _debug_line_color := Color.WHITE


func _ready() -> void:
	_velocity = -global_basis.z * speed
	_prev_position = global_position

	contact.connect(_handle_damage)
	destroyed.connect(_on_destroyed)
	lifetime_timeout.connect(_on_destroyed)
	get_tree().create_timer(lifetime).timeout.connect(func(): lifetime_timeout.emit())


func _physics_process(delta: float) -> void:
	# integration : simplified "Velocity Verlet"
	# Author/ Credit: Ilmari Karonen
	# https://gamedev.stackexchange.com/a/41917
	global_position += delta * (_velocity + (delta * gravity / 2.0))
	_velocity += delta * gravity

	var result = get_intersection(_prev_position, global_position)

	# Why do we do this, shouldn't this only be on a non-pen?
	if !result.is_empty():
		global_position = result.position

	# Set positions
	_prev_position = global_position


## Returns an intersect_ray return result after handling a contact
func get_intersection(prev_pos: Vector3, new_pos: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(prev_pos, new_pos, collision_mask, exclude_add)
	query.collide_with_areas = true

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var distance := prev_pos.distance_to(new_pos)

	if result.is_empty():
		return result

	contact.emit(result)

	if get_tree().debug_collisions_hint:
		DebugDraw3D.draw_arrow(
			result.position + result.position.direction_to(prev_pos) * 2.0,
			result.position,
			_debug_line_color,
			_debug_line_thickness,
			false,
			.5
		)

	# Max range met
	if _distance_travelled > range_max:
		destroyed.emit()

	# Update distance travelled
	_distance_travelled += distance
	return result


func _on_hit(result: Dictionary) -> void:
	var direction = _velocity.normalized()
	var angle := rad_to_deg(direction.angle_to(result.normal))
	angle = absf(angle - 180)

	# Valid ricochet
	if ricochet_max > 0 and angle >= ricochet_angle and _distance_travelled < range_max:
		# Handle ricochet
		exclude_add.append(result.collider)
		_velocity = _velocity.bounce(result.normal)
		ricochet_max -= 1
		look_at(global_position - direction, Vector3(1, 1, 0))

		# spawn ricochet sound
		_spawn_at_impact(result, decal_terrain)
		_instantiate_sound(result, sound_ricochet)

		ricochet.emit(result)
	# Or: handle penetration
	else:
		exclude_add.append(result.collider)
		penetration.emit(result)
		_instantiate_sound(result, sound_impact)
		_spawn_at_impact(result, decal_terrain)
		_debug_draw_penetration(result.position)


func _handle_damage(result: Dictionary) -> void:
	if result.collider.is_in_group("Hitbox"):
		result.collider.report_hit(damage)
		_spawn_at_impact(result, decal_hitbox)


func _instantiate_sound(result: Dictionary, sound: AudioStream):
	var stream := AudioStreamPlayer3D.new()
	result.collider.add_child(stream)
	stream.global_position = result.position
	stream.stream = sound
	stream.doppler_tracking = AudioStreamPlayer3D.DopplerTracking.DOPPLER_TRACKING_PHYSICS_STEP
	stream.play()


func _spawn_at_impact(_result: Dictionary, _scene: PackedScene) -> void:
	if !_scene or !_scene.can_instantiate():
		return

	var child = _scene.instantiate()
	get_tree().root.add_child(child)

	if _result.normal.is_equal_approx(Vector3.UP):
		child.look_at_from_position.call_deferred(
			_result.position, _result.position + _result.normal, Vector3.RIGHT
		)
	elif _result.normal.is_equal_approx(Vector3.DOWN):
		child.look_at_from_position.call_deferred(
			_result.position, _result.position + _result.normal, Vector3.BACK
		)
	else:
		child.look_at_from_position.call_deferred(
			_result.position, _result.position + _result.normal, Vector3.UP
		)

	child.rotate_object_local.call_deferred(Vector3.RIGHT, 90)
	child.rotate.call_deferred(_result.normal, randf_range(0, 2 * PI))


func _debug_draw_penetration(pos: Vector3) -> void:
	if get_tree().debug_collisions_hint:
		DebugDraw3D.draw_sphere(pos, .1, Color.LIGHT_SALMON, _debug_draw_lifetime)


func _on_destroyed():
	if is_inside_tree() and is_multiplayer_authority():
		queue_free()
