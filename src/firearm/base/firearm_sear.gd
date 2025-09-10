class_name FirearmSear extends Resource

signal dropped

enum FModes { safe = 1 << 0, semi = 1 << 1, burst = 1 << 2, full = 1 << 3, size = 1 << 4 }
@export var firemode: FModes = FModes.semi
@export_flags("safe", "semi", "burst", "full", "size") var firemodes = int(FModes.full)
var burst_size := 3
var burst_count := 0
var burst_reset := 1  ## Reset on trigger up, if at least this amount fired
var is_down := false
var _is_linked := true


func trigger_pressed():
	is_down = true


func trigger_released():
	is_down = false
	relink()


func use_link() -> bool:
	if _is_linked:
		_is_linked = false
		return true
	return false


func relink():
	_is_linked = true
	if firemodes & FModes.burst != 0:
		if burst_count >= burst_reset:
			burst_count = 0


## Called to test & progress sear state.
## Returns True if firing is successful, false otherwise
func try_fire() -> bool:
	if !is_down:
		return false
	match firemode:
		FModes.safe:
			return false
		FModes.semi:
			if use_link():
				dropped.emit()
				return true
			return false
		FModes.full:
			dropped.emit()
			return true
		FModes.burst:
			if !_is_linked:
				return false

			if burst_count >= burst_size:
				use_link()
			else:
				burst_count += 1
				dropped.emit()
				return true
			return false

	return true


func mode_next():
	for i in range(sqrt(FModes.size)):
		if firemode == FModes.size:
			firemode = FModes.safe

		if (firemode << 1) & firemodes != 0:
			firemode = FModes.find_key(firemode << 1)
