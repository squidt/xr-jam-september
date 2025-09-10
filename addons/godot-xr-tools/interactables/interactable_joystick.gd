@tool
class_name XRToolsInteractableJoystick
extends XRToolsInteractableHandleDriven


## XR Tools Interactable Joystick script
##
## The interactable joystick is a joystick transform node controlled by the
## player through [XRToolsInteractableHandle] instances.
##
## The joystick rotates itelf around its local X/Y axes, and so should be
## placed as a child of a node to translate and rotate as appropriate.
##
## The interactable joystick is not a [RigidBody3D], and as such will not react
## to any collisions.


## Signal for hinge moved
signal joystick_moved(x_angle, y_angle)


## Constant for flattening a vector horizontally (X/Z only)
const VECTOR_XZ := Vector3(1.0, 0.0, 1.0)

## Constant for flattening a vector vertically (Y/Z only)
const VECTOR_YZ := Vector3(0.0, 1.0, 1.0)


## Joystick X minimum limit
@export var joystick_x_limit_min : float = -45.0: set = _set_joystick_x_limit_min

## Joystick X maximum limit
@export var joystick_x_limit_max : float = 45.0: set = _set_joystick_x_limit_max

## Joystick Y minimum limit
@export var joystick_y_limit_min : float = -45.0: set = _set_joystick_y_limit_min

## Joystick Y maximum limit
@export var joystick_y_limit_max : float = 45.0: set = _set_joystick_y_limit_max

## Joystick X step size (zero for no steps)
@export var joystick_x_steps : float = 0.0: set = _set_joystick_x_steps

## Joystick Y step size (zero for no steps)
@export var joystick_y_steps : float = 0.0: set = _set_joystick_y_steps

## Joystick X position
@export var joystick_x_position : float = 0.0: set = _set_joystick_x_position

## Joystick Y position
@export var joystick_y_position : float = 0.0: set = _set_joystick_y_position

## Default X position
@export var default_x_position : float = 0.0: set = _set_default_x_position

## Default Y position
@export var default_y_position : float = 0.0: set = _set_default_y_position

## If true, the joystick moves to the default position when released
@export var default_on_release : bool = false


# Joystick values in radians
@onready var _joystick_x_limit_min_rad : float = deg_to_rad(joystick_x_limit_min)
@onready var _joystick_x_limit_max_rad : float = deg_to_rad(joystick_x_limit_max)
@onready var _joystick_y_limit_min_rad : float = deg_to_rad(joystick_y_limit_min)
@onready var _joystick_y_limit_max_rad : float = deg_to_rad(joystick_y_limit_max)
@onready var _joystick_x_steps_rad : float = deg_to_rad(joystick_x_steps)
@onready var _joystick_y_steps_rad : float = deg_to_rad(joystick_y_steps)
@onready var _joystick_x_position_rad : float = deg_to_rad(joystick_x_position)
@onready var _joystick_y_position_rad : float = deg_to_rad(joystick_y_position)
@onready var _default_x_position_rad : float = deg_to_rad(default_x_position)
@onready var _default_y_position_rad : float = deg_to_rad(default_y_position)


# Add support for is_xr_class on XRTools classes
func is_xr_class(name : String) -> bool:
	return name == "XRToolsInteractableJoystick" or super(name)


# Called when the node enters the scene tree for the first time.
func _ready():
	# In Godot 4 we must now manually call our super class ready function
	super()

	# Set the initial position to match the initial joystick position value
	transform = Transform3D(
		Basis.from_euler(Vector3(_joystick_y_position_rad, _joystick_x_position_rad, 0)),
		Vector3.ZERO)

	# Connect signals
	if released.connect(_on_joystick_released):
		push_error("Cannot connect joystick released signal")


# Called every frame when one or more handles are held by the player
func _process(_delta: float) -> void:
	# Do not process in the editor
	if Engine.is_editor_hint():
		return

	# Skip if no handles grabbed
	if grabbed_handles.is_empty():
		return


	var offset_sum := Vector2()
	var rotation_axis := Vector3(1.0, 1.0, 0.0).normalized()
	var handle : XRToolsInteractableHandle = grabbed_handles.keys().front()
	var handle_local = to_local(handle.global_position)
	var handle_origin_local = to_local(handle.handle_origin.global_position)
	var result = angle_between(global_position, handle_origin_local, handle_local)

	var shpeed = 15.0
	result.axis = (result.axis * Vector3(1.0, 1.0, 0.0)).normalized()

	# Move the joystick by the requested offset
	var curr = Vector3(_joystick_x_position_rad, _joystick_y_position_rad, 0.0)
	var v3 = curr + (result.axis * result.angle) * _delta * shpeed
	move_joystick(Vector2(v3.x, v3.y))


# Return angle in radians
func angle_between(origin: Vector3, p1: Vector3, p2: Vector3) -> Dictionary:
	var v1 = (p1 - origin).normalized()
	var v2 = (p2 - origin).normalized()

	return { "axis":  v1.cross(v2).normalized(), "angle": acos(v1.dot(v2))}


# Move the joystick to the specified position
func move_joystick(_hinge_position: Vector2) -> void:
	# Do the move
	var result := _do_move_joystick(_hinge_position)

	# Update the current positon
	_joystick_x_position_rad = result.x
	_joystick_y_position_rad = result.y
	joystick_x_position = rad_to_deg(result.x)
	joystick_y_position = rad_to_deg(result.y)

	# Emit the joystick signal
	emit_signal("joystick_moved", joystick_x_position, joystick_y_position)


# Handle release of joystick
func _on_joystick_released(_interactable: XRToolsInteractableJoystick):
	if default_on_release:
		move_joystick(Vector2(_default_x_position_rad, _default_y_position_rad))


# Called when joystick_x_limit_min is set externally
func _set_joystick_x_limit_min(value: float) -> void:
	joystick_x_limit_min = value
	_joystick_x_limit_min_rad = deg_to_rad(value)


# Called when joystick_y_limit_min is set externally
func _set_joystick_y_limit_min(value: float) -> void:
	joystick_y_limit_min = value
	_joystick_y_limit_min_rad = deg_to_rad(value)


# Called when joystick_x_limit_max is set externally
func _set_joystick_x_limit_max(value: float) -> void:
	joystick_x_limit_max = value
	_joystick_x_limit_max_rad = deg_to_rad(value)


# Called when joystick_y_limit_max is set externally
func _set_joystick_y_limit_max(value: float) -> void:
	joystick_y_limit_max = value
	_joystick_y_limit_max_rad = deg_to_rad(value)


# Called when joystick_x_steps is set externally
func _set_joystick_x_steps(value: float) -> void:
	joystick_x_steps = value
	_joystick_x_steps_rad = deg_to_rad(value)


# Called when joystick_y_steps is set externally
func _set_joystick_y_steps(value: float) -> void:
	joystick_y_steps = value
	_joystick_y_steps_rad = deg_to_rad(value)


# Called when joystick_x_position is set externally
func _set_joystick_x_position(value: float) -> void:
	var position := Vector2(deg_to_rad(value), _joystick_y_position_rad)
	position = _do_move_joystick(position)
	joystick_x_position = rad_to_deg(position.x)
	_joystick_x_position_rad = position.x


# Called when joystick_y_position is set externally
func _set_joystick_y_position(value: float) -> void:
	var position := Vector2(_joystick_x_position_rad, deg_to_rad(value))
	position = _do_move_joystick(position)
	joystick_y_position = rad_to_deg(position.y)
	_joystick_y_position_rad = position.y


# Called when default_x_position is set externally
func _set_default_x_position(value: float) -> void:
	default_x_position = value
	_default_x_position_rad = deg_to_rad(value)


# Called when default_y_position is set externally
func _set_default_y_position(value: float) -> void:
	default_y_position = value
	_default_y_position_rad = deg_to_rad(value)


# Do the joystick move
func _do_move_joystick(_hinge_position: Vector2) -> Vector2:
	# Apply joystick step-quantization
	if _joystick_x_steps_rad:
		_hinge_position.x = round(_hinge_position.x / _joystick_x_steps_rad) * _joystick_x_steps_rad
	if _joystick_y_steps_rad:
		_hinge_position.y = round(_hinge_position.y / _joystick_y_steps_rad) * _joystick_y_steps_rad

	# Apply joystick limits
	_hinge_position.x = clamp(_hinge_position.x, _joystick_x_limit_min_rad, _joystick_x_limit_max_rad)
	_hinge_position.y = clamp(_hinge_position.y, _joystick_y_limit_min_rad, _joystick_y_limit_max_rad)

	# Move
	transform.basis = Basis.from_euler(Vector3(_hinge_position.x, _hinge_position.y, 0.0))

	# Return the updated _hinge_position
	return _hinge_position
