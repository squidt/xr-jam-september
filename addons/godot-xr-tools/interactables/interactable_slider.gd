@tool
class_name XRToolsInteractableSlider
extends XRToolsInteractableHandleDriven

## XR Tools Interactable Slider script
##
## A transform node controlled by the user through [XRToolsInteractableHandle] instances.
##
## An example scene may be setup in the following way:
## XRSlider
##     SliderModel (A Firearm Bolt, or Door Handle)
##         GrabPointHandLeft
##     InteractableHandle
##         CollisionShape3D
##         GrabPointRedirectLeft (set to 'GrabPointHandLeft')
##
## The interactable slider is not a [RigidBody3D], and as such will not react
## to any collisions.

signal slider_moved(offset: float)

@export var enabled := true

## Start position for slide, can be positiv and negativ in values
@export var slider_limit_min: float = 0.0:
	set(v):
		slider_limit_min = minf(v, slider_limit_max)
		slider_position = slider_position

## End position for slide, can be positiv and negativ in values
@export var slider_limit_max: float = 1.0:
	set(v):
		slider_limit_max = maxf(v, slider_limit_min)
		slider_position = slider_position

## Signal for slider moved
## Slider step size (zero for no steps)
@export var slider_steps: float = 0.0:
	set(v):
		slider_steps = maxf(v, 0)

## Slider position - move to test the position setup
@export var slider_position: float = 0.0:
	set(v):
		if !enabled:
			return

		# Apply slider step-quantization
		if !is_zero_approx(slider_steps):
			v = roundf(v / slider_steps) * slider_steps

		# Clamp position
		v = clampf(v, slider_limit_min, slider_limit_max)

		# No change
		if is_equal_approx(slider_position, v):
			return

		# Set, Emit
		_is_driven_change = true
		position = _private_transform.origin - (v * slider_axis)
		slider_position = v
		slider_moved.emit(v)


## Default position
@export var default_position: float = 0.0

## If true, the slider moves to the default position when released
@export var default_on_release: bool = false

## Axis which the slider will slide on in the local coordinate system
@export var slider_local_axis := Vector3.FORWARD:
	set(v):
		slider_local_axis = v.normalized()

## Balls
var slider_axis: Vector3:
	get():
		return slider_local_axis * transform.basis.inverse()


# Add support for is_xr_class on XRTools classes
func is_xr_class(_name: String) -> bool:
	return _name == "XRToolsInteractableSlider" or super(_name)


func _ready() -> void:
	super()

	# Connect signals
	if released.connect(_on_released):
		push_error("Cannot connect slider released signal")


func _process(_delta: float) -> void:
	if !enabled:
		return

	# Get the total handle offsets
	var offset_sum := 0.0
	for item in grabbed_handles:
		var handle := item as XRToolsInteractableHandle
		var to_handle := Vector3(
			to_local(handle.global_position) * _private_transform.basis.inverse()
		)
		var to_handle_origin := Vector3(
			to_local(handle.handle_origin.global_position) * _private_transform
		)
		var dot1 = to_handle.dot(slider_axis)
		var dot2 = to_handle_origin.dot(slider_axis)

		# Subtracting these two dot products ensures that movement is relative to
		# handle_origin instead of the slider's origin
		offset_sum += dot1 - dot2

	slider_position -= offset_sum / grabbed_handles.size()


func _on_released(_interactable: Variant) -> void:
	if default_on_release:
		slider_position = default_position
