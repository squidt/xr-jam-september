extends Node

var steam_id: int = 0
var steam_username: String = ""


func _init():
	OS.set_environment("SteamAppID", str(480))
	OS.set_environment("SteamGameID", str(480))
