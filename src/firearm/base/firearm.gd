class_name Firearm extends Node3D

## Firearm Class
##
## Used in combination with firearm components to create a functioning weapon [br]
##
## [code]Example:
## XRTooslPickable
##   - Firearm
##     - FirearmInput
##     - FirearmAutoAction
##     - FirearmMagazineZone
##     - FirearmProjectileEmitter
##     - FirearmEjectionParticle
## [/code]

signal fired
signal sear_dropped
signal bolt_loaded
signal bolt_ejected
signal bolt_closed
@warning_ignore("unused_signal")
signal magazine_loaded
signal magazine_ejected
@warning_ignore("unused_signal")
signal attachment_activate

@export_group("Firearm Settings")
@export var can_mag_drop := true
@export var sear := FirearmSear.new()

@export_group("Data")
@export var is_bolt_loaded := false
@export_range(0.0, 1.0) var bullet_velocity_modifier
@export_group("")
@export var debug_print := false

var is_bolt_closed := true
var is_bolt_fired := false


func _ready() -> void:
	if sear:
		sear.dropped.connect(sear_dropped.emit)
	if !is_in_group("EquipmentGun"):
		add_to_group("EquipmentGun")


## Returns true if the bolt is loaded and closed
func is_chambered() -> bool:
	return is_bolt_loaded and is_bolt_closed


## Returns true on successful firing [br]
## To fire: 'sear' allows it, 'chamber' has a round, round_data is set, !is_bolt_fired
func bolt_try_fire() -> bool:
	var sear_result = sear.try_fire()
	if debug_print:
		print(
			"Firearm ready (all true): (chambered? %s, !fired? %s, sear? %s)" % [is_chambered(), !is_bolt_fired, sear_result]
		)
	if is_chambered() and sear_result:
		if !is_bolt_fired:
			fired.emit()
			is_bolt_fired = true
			return true
	# otherwise
	return false


## Emits a signal for FirearmComponents to handle loading
func bolt_load() -> void:
	if debug_print:
		print("Firearm: bolt load")
	is_bolt_loaded = true
	is_bolt_fired = false
	bolt_loaded.emit()


## Emits a signal for FirearmComponents to handle ejecting [br]
## Sets is_bolt_loaded=false, round_data=null
func bolt_eject() -> void:
	if debug_print:
		print("Firearm: bolt eject")
	is_bolt_loaded = false
	bolt_ejected.emit()


## Emits a signal for FirearmComponents to handle bolt closing/ opening [br]
## Sets is_bolt_closed=is_closed [br]
## Attempts to fire full auto sears
func bolt_close(is_closed: bool) -> void:
	if is_closed == is_bolt_closed:
		return
	is_bolt_closed = is_closed
	if is_bolt_closed:
		if debug_print:
			print("Firearm: bolt closed")
		bolt_try_fire()
		bolt_closed.emit()
	else:
		if debug_print:
			print("Firearm: bolt opened")


# Controller responses


func trigger_press() -> void:
	sear.trigger_pressed()
	bolt_try_fire()


func trigger_release() -> void:
	sear.trigger_released()


func magazine_eject() -> void:
	if can_mag_drop:
		magazine_ejected.emit()
