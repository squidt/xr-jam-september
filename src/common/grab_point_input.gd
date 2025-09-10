class_name GrabPointInput extends Node

signal activated
signal deactivated

@export var pickable: XRToolsPickable
@export var deactivate_on_release := true
@export var conditions: Array[GrabPointInputCondition]
@export var debug_print := false

var is_activated := false
var _activated = {}


func _ready() -> void:
	var parent = get_parent()
	if parent is XRToolsGrabPoint and pickable:
		pickable.grabbed_point.connect(_on_point_grabbed)
		pickable.released_point.connect(_on_point_released)
	else:
		push_error("InputCondition Configuration error.")

	# Duplicate so that copied conditionals on one controller dont activate the other
	for c in conditions:
		c = c.duplicate()


func _get_configuration_warnings() -> PackedStringArray:
	if get_parent() is not XRToolsGrabPoint:
		return ["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
	return []


## Checks .primary if grab_point_id == 0, or .secondary if grab_point_id == 1
func _is_grab_point_valid(_pickable, grab_point_id: int) -> bool:
	if !_pickable or !_pickable._grab_driver:
		return false

	# Convert to always be 0 or 1
	# Check primary
	if 0 == (grab_point_id % 2):
		if _pickable._grab_driver.primary and _pickable._grab_driver.primary.point:
			return true
	if _pickable._grab_driver.secondary and _pickable._grab_driver.secondary.point:
		return true
	return false


func _connect_to_controller_inputs(controller: XRController3D):
	for con in conditions:
		if con:
			if debug_print:
				print("con (%s) connecting to ctrl (%s)" % [con, controller])
			if !con.activated.is_connected(_on_conditional_activated):
				con.activated.connect(_on_conditional_activated.bind(con))
			if !con.deactivated.is_connected(_on_conditional_deactivated):
				con.deactivated.connect(_on_conditional_deactivated.bind(con))
			con.subscribe(controller)


func _disconnect_to_controller_inputs(controller: XRController3D):
	for con in conditions:
		if con:
			con.activated.disconnect(_on_conditional_activated)
			con.deactivated.disconnect(_on_conditional_deactivated)
			con.unsubscribe(controller)


## Signals


func _on_conditional_activated(conditional) -> void:
	_activated[conditional] = 0
	if _activated.keys().size() == conditions.size():
		if debug_print:
			print(
				"controller: {0} | conditional: {1} | state: {2}".format(
					[conditional.controller, conditional.resource_name, "activated"]
				)
			)
		is_activated = true
		activated.emit()


func _on_conditional_deactivated(conditional) -> void:
	_activated.erase(conditional)
	if is_activated and _activated.keys().size() < conditions.size():
		if debug_print:
			print(
				"controller: {0} | conditional: {1} | state: {2}".format(
					[conditional.controller, conditional.resource_name, "deactivated"]
				)
			)
		is_activated = false
		deactivated.emit()


## 'by' is XRToolsFunctionPickup (or maybe snap zone)
## Connect to controller inputs if we are the point grabbed
func _on_point_grabbed(_pickable: XRToolsPickable, by: Node, point: XRToolsGrabPoint) -> void:
	by = by as XRToolsFunctionPickup
	# Gurantee params
	if !_pickable or !by or !point:
		return

	# We were chosen
	if debug_print:
		print("point (%s) grabbed by ctrl (%s)" % [point.name, by.get_controller()])
	if point == get_parent():
		_connect_to_controller_inputs(by.get_controller())


func _on_point_released(_pickable: XRToolsPickable, by: Node, point: XRToolsGrabPoint) -> void:
	by = by as XRToolsFunctionPickup
	# Gurantee params AND our parent was the point released
	if !_pickable or !by or !point or point != get_parent():
		return

	_disconnect_to_controller_inputs(by.get_controller())

	# Stop activating when dropped
	if deactivate_on_release and !_activated.is_empty():
		deactivated.emit()
