extends Area3D


@rpc("any_peer")
func report_hit(damage: float) -> void:
	if "health" in get_parent():
		get_parent().health -= damage
