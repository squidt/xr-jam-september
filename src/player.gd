extends XROrigin3D


func _ready() -> void:
	if is_multiplayer_authority():
		set_deferred("current", true)
		$XRCamera3D.set_deferred("current", true)
