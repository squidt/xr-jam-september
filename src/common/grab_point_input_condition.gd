class_name GrabPointInputCondition extends Resource

signal activated
signal deactivated

@export_enum("BUTTON") var type := "BUTTON"
@export var action: String

var controller: XRController3D = null


func _init() -> void:
	resource_local_to_scene = true


func subscribe(_controller: XRController3D) -> void:
	controller = _controller
	_set_action(action)
	#_connect_if_not(controller.input_float_changed)
	#_connect_if_not(controller.input_vector2_changed)
	_connect_if_not(controller.button_pressed, _pressed)
	_connect_if_not(controller.button_released, _released)


func unsubscribe(_controller: XRController3D) -> void:
	#print_debug("unsub (%s) from (%s)" % [self, _controller])
	for connection in get_incoming_connections():
		#print("  discon signal(%s) from callable(%s)" % [connection.signal, connection.callable])
		connection.signal.disconnect(connection.callable)


func _pressed(a) -> void:
	if action == a:
		activated.emit()


func _released(a) -> void:
	if action == a:
		deactivated.emit()


func _set_action(_action: String) -> void:
	if _action == action:
		if controller.get_input(action):
			activated.emit()


static func _connect_if_not(sig: Signal, callable: Callable) -> void:
	if !sig.is_connected(callable):
		sig.connect(callable)
