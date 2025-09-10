extends Node3D

signal fired

enum ActionState
{
	CLOSED,
	OPENED,
	UNLOADED,
	LOADED
}

@export var slider: XRToolsInteractableSlider
@export var rpm: int = 500
@export var cycle_curve: Curve  ## Curve of bolt animation

var _state := ActionState.CLOSED: set = _set_action_state
var _loaded := true
var _can_try_loading := false
var _is_trigger_pressed := false
var _is_cycling := false
var _cycle_delta := 0.0
var _cycle_time: float:
	get():
		return 60.0 / float(rpm)


func trigger_pull() -> void:
	_is_trigger_pressed = true
	try_fire()


func trigger_release() -> void:
	_is_trigger_pressed = false


func try_fire() -> void:
	if _state == ActionState.CLOSED and _loaded:
		fired.emit()
		_loaded = false


func _process(_delta: float) -> void:
	if !_is_cycling:
		return

	# Calculate cycle deltas
	_cycle_delta += _delta
	var progress = _cycle_delta / _cycle_time

	# Finished
	if _cycle_delta >= _cycle_time:
		cycle_stop()
		progress = 1.0

	_update_auto_action(progress)


## Emits signals and sets vars for the full auto firearm mechanics [br]
## 'progress' is % of cycle completed 0.0 - 1.0
## the bolt's movement will reverse around the .5 position
func _update_auto_action(progress: float) -> void:
	_cycle_animate(progress)

	const OPEN_POINT = 0.01
	const UNLOAD_POINT = 0.6
	const LOAD_POINT = 0.4
	if progress >= OPEN_POINT and ActionState.CLOSED >= _state:
		_state = ActionState.OPENED
	if progress >= UNLOAD_POINT and ActionState.OPENED >= _state:
		_state = ActionState.UNLOADED
	if progress >= LOAD_POINT and ActionState.UNLOADED >= _state:
		_state = ActionState.LOADED
	if progress >= 1.0 and ActionState.LOADED >= _state:
		_state = ActionState.CLOSED

	if ActionState.CLOSED and _is_trigger_pressed:
		fired.emit()


## Animate bolt slider in code
func _cycle_animate(progress: float) -> void:
	var sample = cycle_curve.sample_baked(progress)
	slider.slider_position = sample * slider.slider_limit_max


## Start an automatic cycle
func cycle_start() -> void:
	_is_cycling = true
	_cycle_delta = 0.0


func cycle_stop() -> void:
	_is_cycling = false
	_cycle_delta = 0.0


func _on_fired() -> void:
	cycle_start()


func _set_action_state(v) -> void:
	if _state == v:
		return

	_state = v

	# On state enter code
	match _state:
		ActionState.CLOSED:
			pass
		ActionState.OPENED:
			pass
		ActionState.UNLOADED:
			_can_try_loading = true
			_loaded = false
		ActionState.LOADED:
			_can_try_loading = false
			_loaded = true
