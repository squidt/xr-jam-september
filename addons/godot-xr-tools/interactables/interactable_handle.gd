@tool
class_name XRToolsInteractableHandle
extends XRToolsPickable

## XR Tools Interactable Handle script
##
## The interactable handle is a (usually invisible) object extending from
## [XRToolsPickable] that can be grabbed by the player and is used to
## manipulate interactable objects.
##
## The interactible handle has an origin position of its parent. In order
## to position interactible handles on the interactible object, the handle
## should be placed under a parent handle-origin node, and the origin nodes
## position set as desired.
##
## When the handle is released, it snaps back to its parent origin. If the
## handle is pulled further than its snap distance, then the handle is
## automatically released.

## Distance from the handle origin to drop the grab
@export var snap_distance: float = 0.3

# Handle origin spatial node
@onready var handle_origin: Node3D = get_parent()
var _prev_transform: Transform3D


# Add support for is_xr_class on XRTools classes
func is_xr_class(name: String) -> bool:
	return name == "XRToolsInteractableHandle" or super(name)


# Called when this handle is added to the scene
func _ready() -> void:
	# In Godot 4 we must now manually call our super class ready function
	super()

	# Ensure we start at our origin
	transform = Transform3D.IDENTITY
	freeze = true
	freeze_mode = FreezeMode.FREEZE_MODE_STATIC

	# Turn off processing - it will be turned on only when held
	set_process(false)


# Called on every frame when the handle is held to check for snapping
func _process(_delta: float) -> void:
	# Skip if not picked up
	if not is_picked_up():
		return

	# If too far from the origin then drop the handle
	var origin_pos = handle_origin.global_transform.origin
	var handle_pos = global_transform.origin
	if handle_pos.distance_to(origin_pos) > snap_distance:
		pass#drop()


# Called when the handle is picked up
func pick_up(by) -> void:
	# Copy base class pickup code, however always use 'precise' pickup mode

	# Skip if not enabled
	if not enabled:
		return

	# Find the grabber information
	var grabber := Grabber.new(by)

	# Test if we're already picked up:
	if is_picked_up():
		# Ignore if we don't support second-hand grab
		if second_hand_grab == SecondHandGrab.IGNORE:
			print_verbose("%s> second-hand grab not enabled" % name)
			return

		# Ignore if either pickup isn't by a hand
		if not _grab_driver.primary.pickup or not grabber.pickup:
			return

		# Construct the second grab
		if second_hand_grab != SecondHandGrab.SWAP:
			# Grab the object
			var by_grab_point := _get_grab_point(by, _grab_driver.primary.point)
			var grab := Grab.new(grabber, self, by_grab_point, true)
			_grab_driver.add_grab(grab)

			# Report the secondary grab
			grabbed.emit(self, by)
			return

		# Swapping hands, let go with the primary grab
		print_verbose("%s> letting go to swap hands" % name)
		let_go(_grab_driver.primary.by, Vector3.ZERO, Vector3.ZERO)

	# Remember the mode before pickup
	match release_mode:
		ReleaseMode.UNFROZEN:
			restore_freeze = false

		ReleaseMode.FROZEN:
			restore_freeze = true

		_:
			restore_freeze = freeze

	# turn off physics on our pickable object
	freeze = true
	collision_layer = picked_up_layer
	collision_mask = 0

	# Find a suitable primary hand grab
	var by_grab_point := _get_grab_point(by, null)

	# Construct the grab driver
	if by.picked_up_ranged:
		if ranged_grab_method == RangedMethod.LERP:
			var grab := Grab.new(grabber, self, by_grab_point, false)
			_grab_driver = XRToolsGrabDriver.create_lerp(self, grab, ranged_grab_speed)
		else:
			var grab := Grab.new(grabber, self, by_grab_point, false)
			_grab_driver = XRToolsGrabDriver.create_snap(self, grab)
	else:
		# CRITICAL: Changed to always use 'precise' pickup mode
		# Leaves the grab handle in it's global_transform and moves from there
		# instead of applying weird transforms to a grab handle
		var grab := Grab.new(grabber, self, by_grab_point, true)
		_grab_driver = XRToolsGrabDriver.create_snap(self, grab)

	# Report picked up and grabbed
	picked_up.emit(self)
	grabbed.emit(self, by)

	# Enable the process function while held
	set_process(true)


# Called when the handle is dropped
func let_go(by: Node3D, _p_linear_velocity: Vector3, _p_angular_velocity: Vector3) -> void:
	# Call the base-class to perform the drop, but with no velocity
	super(by, Vector3.ZERO, Vector3.ZERO)

	# Disable the process function as no-longer held
	set_process(false)

	# Snap the handle back to the origin
	transform = Transform3D.IDENTITY


# Check handle configurationv
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if !transform.is_equal_approx(Transform3D.IDENTITY):
		warnings.append("Interactable handle must have no transform from its parent handle origin")

	return warnings
