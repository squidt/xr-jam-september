class_name ActionSlideAuto extends ActionSlide

## Elective bolt component for semi/ burst/ full autos.
## Uses an XRInteractableSlider to achieve this goal

@export var rpm: int = 500
@export var cycle_curve: Curve  ## Curve of bolt animation

var _is_cycling := false
var _cycle_delta := 0.0
var _cycle_time: float:
	get():
		return 60.0 / float(rpm)


func _ready() -> void:
	super()
	firearm.fired.connect(_on_fired)


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
	if debug_print:
		print("ActionSlideAuto: Progress ( %s )" % [progress])
	moved.emit(progress)
	_cycle_animate(progress)

	if progress >= open_point and ActionState.CLOSE >= _state:
		_state = ActionState.OPEN
	if progress >= unload_point and ActionState.OPEN >= _state:
		_state = ActionState.UNLOAD
	if progress >= load_point and ActionState.UNLOAD >= _state:
		_state = ActionState.LOAD
	if progress >= 1.0 and ActionState.LOAD >= _state:
		_state = ActionState.CLOSE


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
