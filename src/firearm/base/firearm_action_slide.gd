class_name ActionSlide extends FirearmComponent

## Firearm Action Manual
## Emits signals as slider passes '_point' properties

signal moved(bolt_spacing: float)
signal closed
signal opened

enum ActionState { CLOSE, OPEN, UNLOAD, LOAD }

@export var enabled := true
@export var slider: XRToolsInteractableSlider
## Bolt Action Points are between 0.0 - 1.0, bolt reverses at 0.5
@export var open_point := 0.005
## Bolt Action Points are between 0.0 - 1.0, bolt reverses at 0.5
## AKA 'Eject'
@export var unload_point := 0.4
## Bolt Action Points are between 0.0 - 1.0, bolt reverses at 0.5
@export var load_point := 0.6

@export var debug_print := false

var _state := ActionState.CLOSE:
	set = _set_state
var _bolt_spacing_on_released := 0.0
var _can_try_load := false
var _prev_offset := 0.0
var _prev_tick := 0.0


func _ready() -> void:
	if !slider.released.is_connected(_on_slider_released):
		slider.released.connect(_on_slider_released)
	if !slider.slider_moved.is_connected(_on_slider_moved):
		slider.slider_moved.connect(_on_slider_moved)


# Manual bolt control
func _on_slider_moved(_offset: float) -> void:
	# Only while charging handle is grabbed
	if !enabled or slider.grabbed_handles.is_empty():
		return

	# 1.0 is 100% open
	var speed = _get_bolt_velocity(_offset)
	var spacing = _remap_to_spacing(_offset, speed)
	#print("  speed: ", speed)
	#print("  spacing: ", spacing)

	_update_current_state(spacing)
	_bolt_spacing_on_released = spacing

	moved.emit(spacing)


#region State Code


## Set '_state' and execute code for entering states
func _set_state(v: ActionState) -> void:
	if _state == v:
		return

	if debug_print:
		print(
			(
				"ActionSlide::_set_state ln:70: State from (%s) to (%s)"
				% [ActionState.keys()[_state], ActionState.keys()[v]]
			)
		)

	_state = v

	# On state enter code
	match _state:
		ActionState.CLOSE:
			firearm.bolt_close(true)
			closed.emit()
		ActionState.OPEN:
			firearm.bolt_close(false)
			opened.emit()
		ActionState.UNLOAD:
			_can_try_load = true
			if firearm.is_bolt_loaded:
				firearm.bolt_eject()
		ActionState.LOAD:
			_can_try_load = false
			firearm.bolt_load()


func _update_current_state(spacing: float) -> void:
	match _state:
		ActionState.CLOSE:
			_update_close_state(spacing)
		ActionState.OPEN:
			_update_open_state(spacing)
		ActionState.UNLOAD:
			_update_unload_state(spacing)
		ActionState.LOAD:
			_update_load_state(spacing)


func _update_close_state(spacing: float) -> void:
	if _is_action_open(spacing):
		_state = ActionState.OPEN


func _update_open_state(spacing: float) -> void:
	if !_is_action_open(spacing):
		_state = ActionState.CLOSE
		return

	if _is_unloading(spacing):
		_state = ActionState.UNLOAD


func _update_unload_state(spacing: float) -> void:
	if _is_loading(spacing) and _can_try_load:
		_state = ActionState.LOAD


func _update_load_state(spacing: float) -> void:
	if _is_unloading(spacing) and !_can_try_load:
		_state = ActionState.UNLOAD
	elif !_is_action_open(spacing):
		_state = ActionState.CLOSE


#endregion

#region Helpers


func _is_action_open(spacing: float) -> bool:
	if spacing > 0.5:
		return spacing <= 1.0 - open_point
	if spacing < 0.5:
		return spacing >= open_point
	return true


func _is_loading(spacing: float) -> bool:
	return spacing >= load_point


func _is_unloading(spacing) -> bool:
	return spacing >= unload_point and spacing <= 0.5


## Sample and return bolt velocity based off of previous offsets
func _get_bolt_velocity(_offset: float) -> float:
	var distance = _offset - _prev_offset

	# get time elapsed
	var tick = Time.get_ticks_msec()
	var elapsed = tick - _prev_tick

	# set previouses
	_prev_tick = tick
	_prev_offset = _offset

	# get velocity
	if is_zero_approx(distance) or is_zero_approx(elapsed):
		return 0.0
	return distance / elapsed


## Returns if the bolt speed is moving away from the chamber
func _is_moving_away(speed: float) -> bool:
	return 0 < speed


## Remaps slider_position to bolt spacing depending on speed
func _remap_to_spacing(offset: float, speed: float) -> float:
	if _is_moving_away(speed):
		return remap(offset / slider.slider_limit_max, 0.0, 1.0, 0.0, 0.5)
	return remap(offset / slider.slider_limit_max, 0.0, 1.0, 1.0, 0.5)


#endregion


func _on_slider_released(_interactable: Variant) -> void:
	# Bolt just released
	if !firearm.is_bolt_loaded and (_state == ActionState.UNLOAD or _state == ActionState.OPEN):
		_state = ActionState.LOAD
		_state = ActionState.CLOSE
		moved.emit()
	elif slider.default_on_release:
		_state = ActionState.CLOSE
		moved.emit()
