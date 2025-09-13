@tool
class_name MainStage extends XRToolsStaging


@warning_ignore("unused_signal")
signal money_changed(new)


static var instance: MainStage

var lobby_2d = null
var game_health: int = 5:
	set(v):
		var was_empty = game_health <= 0
		game_health = v
		if !was_empty and game_health <= 0:
			game_over()
var player_wallet: int = 100:
	set(v):
		player_wallet = v
		money_changed.emit(player_wallet)


func _ready() -> void:
	instance = self
	super()


func game_over() -> void:
	_on_reset_scene({})
