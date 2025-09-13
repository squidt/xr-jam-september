extends Panel

var player_container: VBoxContainer
var _is_ready: bool = false
@export var row: PackedScene


func connect_lobby() -> void:
	if !NetworkManager.players_changed.is_connected(_on_players_changed):
		NetworkManager.players_changed.connect(_on_players_changed)
	if !$Panel/Exit.pressed.is_connected(NetworkManager._leave_lobby):
		$Panel/Exit.pressed.connect(NetworkManager._leave_lobby)
	if !$Panel/Ready.pressed.is_connected(_on_ready):
		$Panel/Ready.pressed.connect(_on_ready)
	if !$Panel/Start.pressed.is_connected(_on_start):
		$Panel/Start.pressed.connect(_on_start)

	_enter_tree()


func _on_start() -> void:
	print_debug("Starting lobby . . .")
	MainStage.instance.load_scene.rpc("uid://cvdkot2uim7wf") # game state


func _add_row(name_: String, id: int) -> void:
	var instance: HBoxContainer = row.instantiate()
	instance.get_node("Label").text = name_
	player_container.add_child(instance)
	NetworkManager.players[id]["object"] = instance


func _enter_tree() -> void:
	player_container = $Panel/VBoxContainer
	_on_players_changed()
	if !NetworkManager.players.is_empty():
		$Panel/RichTextLabel.text = NetworkManager.players[1]["name"] + "'s Lobby"


func _on_players_changed() -> void:
	_is_ready = false
	var i := 1
	var my_id: int = multiplayer.get_unique_id()
	for child: HBoxContainer in player_container.get_children():
		child.queue_free()
	for peer: int in NetworkManager.players:
		if NetworkManager.lan:
			if peer == my_id:
				NetworkManager.players[peer]["name"] = "Player " + str(i) + "(you)"
			else:
				NetworkManager.players[peer]["name"] = "Player " + str(i)
			i += 1
		_add_row(NetworkManager.players[peer]["name"], peer)
	if NetworkManager.players.size() == 1:
		$Panel/Start.disabled = false
	else:
		$Panel/Start.disabled = true


func _on_ready() -> void:
	_is_ready = !_is_ready
	_on_ready_remote.rpc(_is_ready)


@rpc("any_peer", "call_local")
func _on_ready_remote(_is_ready_remote: bool) -> void:
	var id = multiplayer.get_remote_sender_id()
	NetworkManager.players[id]["object"].get_node("Ready").visible = _is_ready_remote
	if multiplayer.is_server() and NetworkManager.players.size() > 1:
		for child: HBoxContainer in player_container.get_children():
			if not child.get_node("Ready").visible:
				$Panel/Start.disabled = true
				return
		$Panel/Start.disabled = false
