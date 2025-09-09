extends Node

# Help from https://github.com/MichaelMacha/SteamMultiplayerPeerExample/tree/demo
# under MIT license

# Default game server port. Can be any number between 1024 and 49151.
# Not on the list of registered or common ports as of November 2020:
# https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
const DEFAULT_PORT = 10567

# Signals to let lobby GUI know what's going on.
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what : String)
signal game_log(what : String)

const PACKET_READ_LIMIT: int = 32

@export var world_scene: PackedScene

var peer : MultiplayerPeer = null

# Name for local player
var player_name: String = "Player1"
var players: Dictionary[int, String]
var players_ready := []

var is_host: bool = false
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 2


var steam_id: int = 0
var steam_username: String = ""


func _ready() -> void:
	Steam.steamInitEx(true, 480)
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()

	multiplayer.peer_connected.connect(
		func(id : int):
			# Tell the connected peer that we have also joined
			register_player.rpc_id(id, player_name)
	)
	multiplayer.peer_disconnected.connect(
		func(id : int):
			if is_game_in_progress():
				if multiplayer.is_server():
					game_error.emit("Player " + players[id] + " disconnected")
					end_game()
			else:
				# Unregister this player. This doesn't need to be called when the
				# server quits, because the whole player list is cleared anyway!
				unregister_player(id)
	)
	multiplayer.connected_to_server.connect(
		func():
			connection_succeeded.emit()	
	)
	multiplayer.connection_failed.connect(
		func():
			multiplayer.multiplayer_peer = null
			connection_failed.emit()
	)
	multiplayer.server_disconnected.connect(
		func():
			game_error.emit("Server disconnected")
			end_game()
	)
	
	Steam.lobby_joined.connect(
		func (new_lobby_id: int, _permissions: int, _locked: bool, response: int):
		if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
			lobby_id = new_lobby_id
			var id = Steam.getLobbyOwner(new_lobby_id)
			if id != Steam.getSteamID():
				connect_steam_socket(id)
				register_player.rpc(player_name)
				players[multiplayer.get_unique_id()] = player_name
		else:
			# Get the failure reason
			var FAIL_REASON: String
			match response:
				Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
					FAIL_REASON = "This lobby no longer exists."
				Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED:
					FAIL_REASON = "You don't have permission to join this lobby."
				Steam.CHAT_ROOM_ENTER_RESPONSE_FULL:
					FAIL_REASON = "The lobby is now full."
				Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR:
					FAIL_REASON = "Uh... something unexpected happened!"
				Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED:
					FAIL_REASON = "You are banned from this lobby."
				Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED:
					FAIL_REASON = "You cannot join due to having a limited account."
				Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED:
					FAIL_REASON = "This lobby is locked or disabled."
				Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN:
					FAIL_REASON = "This lobby is community locked."
				Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU:
					FAIL_REASON = "A user in the lobby has blocked you from joining."
				Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER:
					FAIL_REASON = "A user you have blocked is in the lobby."
			game_log.emit(FAIL_REASON)
	)
	Steam.lobby_created.connect(
		func(status: int, new_lobby_id: int):
			if status == 1:
				#lobby_id = new_lobby_id
				Steam.setLobbyData(new_lobby_id, "name", 
					str(Steam.getPersonaName(), "'s Spectabulous Test Server"))
				create_steam_socket()
			else:
				game_error.emit("Error on create lobby!")
	)


func _process(_delta: float) -> void:
	Steam.run_callbacks()

	if lobby_id > 0:
		read_all_p2p_packets()


#region SteamMultiplayerPeerExample code

@rpc("call_local", "any_peer")
func register_player(_player_name: String) -> void:
	var id = multiplayer.get_remote_sender_id()
	var count := players.values().count(_player_name) + 1
	players[id] = _player_name + str(count) if count > 1 else _player_name
	player_list_changed.emit()


func unregister_player(id):
	players.erase(id)
	player_list_changed.emit()

#endregion


@rpc("call_local")
func load_world():
	pass


# create_steam_socket and connect_steam_socket both create the multiplayer peer, instead
# of _ready, for the sake of compatibility with other networking services
# such as WebSocket, WebRTC, or Steam or Epic.

#region Steam Peer Management
func create_steam_socket():
	peer = SteamMultiplayerPeer.new()
	peer.create_host(0, [])
	multiplayer.set_multiplayer_peer(peer)

func connect_steam_socket(steam_id : int):
	peer = SteamMultiplayerPeer.new()
	peer.create_client(steam_id, 0, [])
	multiplayer.set_multiplayer_peer(peer)

#endregion

#region ENet Peer Management
func create_enet_host(new_player_name : String):
	peer = ENetMultiplayerPeer.new()
	(peer as ENetMultiplayerPeer).create_server(DEFAULT_PORT)
	player_name = new_player_name
	players[1] = new_player_name
	multiplayer.set_multiplayer_peer(peer)

func create_enet_client(new_player_name : String, address : String):
	peer = ENetMultiplayerPeer.new()
	(peer as ENetMultiplayerPeer).create_client(address, DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)
	await multiplayer.connected_to_server
	register_player.rpc(new_player_name)
	players[multiplayer.get_unique_id()] = new_player_name

#endregion

#region GameLoop


@rpc("call_local", "any_peer")
func get_player_name() -> String:
	return players[multiplayer.get_remote_sender_id()]


func is_game_in_progress() -> bool:
	return has_node("/root/World")


func end_game():
	if is_game_in_progress():
		get_node("/root/World").queue_free()
	
	game_ended.emit()
	players.clear()


#endregion

func create_lobby() -> void:
	if lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)


func join_lobby(_lobby_id: int) -> void:
	Steam.joinLobby(_lobby_id)


func update_lobby_members() -> void:
	lobby_members.clear()

	var lobby_members_count: int = Steam.getNumLobbyMembers(lobby_id)
	for member in range(0, lobby_members_count):
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, member)
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
		
		lobby_members.append({"steam_id": member_steam_id, "steam_name": member_steam_name})


func make_p2p_handshake() -> void:
	send_p2p_packet(0, {"message" : "handshake", "steam_id": Global.steam_id, "username": Global.steam_username})


func send_p2p_packet(_target: int, _data: Dictionary, _send_type: int = 0) -> void:
	var channel:int = 0
	var data: PackedByteArray
	data.append_array(var_to_bytes(_data))

	if _target == 0 and !lobby_members.is_empty():
		for member in lobby_members:
			if member["steam_id"] != Global.steam_id:
				Steam.sendP2PPacket(member["steam_id"], data, _send_type, channel)
	else:
		Steam.sendP2PPacket(_target, data, _send_type, channel)


func read_p2p_packet() -> void:
	var channel: int = 0
	var packet_size: int = Steam.getAvailableP2PPacketSize(channel)
	
	if packet_size > 0:
		var packet: Dictionary = Steam.readP2PPacket(packet_size, channel)
		var packet_raw_data: PackedByteArray = packet["data"]
		var packet_data: Dictionary = bytes_to_var(packet_raw_data)

		if packet_data.has("message"):
			match packet_data["message"]:
				"handshake":
					print_debug("PLAYER <%s> has joined the Lobby" % packet_data.get("steam_username", "NULL_NAME"))
					update_lobby_members()


func read_all_p2p_packets(_read_count: int = 0) -> void:
	if _read_count >= PACKET_READ_LIMIT:
		return

	var channel: int = 0
	if Steam.getAvailableP2PPacketSize(channel) > 0:
		read_p2p_packet()
		read_all_p2p_packets(_read_count + 1)
