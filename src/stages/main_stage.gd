@tool
class_name MainStage extends XRToolsStaging

static var instance: MainStage

var lobby_2d = null
@onready var stage_spawner = $Scene/MultiplayerSpawner

func _ready() -> void:
	instance = self
	super()
