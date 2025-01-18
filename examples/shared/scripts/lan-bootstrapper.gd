extends Node

@export_category("UI")
@export var connect_ui: Control
@export var address_input: LineEdit
@export var port_input: LineEdit

func host_only() -> void:
	var brawler_spawner: BrawlerSpawner = %"Brawler Spawner"
	if brawler_spawner != null:
		brawler_spawner.spawn_host_avatar = false
	host()

func host() -> int:
	var host_dict := _parse_input()
	if host_dict.size() == 0:
		return ERR_CANT_RESOLVE

	var port : int = host_dict.port

	# Start host
	print("Starting host on port %s" % port)
	
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port) != OK:
		print("Failed to listen on port %s" % port)

	get_tree().get_multiplayer().multiplayer_peer = peer
	print("Listening on port %s" % port)
	
	# Wait for server to start
	await Async.condition(
		func() -> bool:
			return peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING
	)

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		OS.alert("Failed to start server!")
		return ERR_CONNECTION_ERROR
	
	print("Server started")
	get_tree().get_multiplayer().server_relay = true
	
	connect_ui.hide()
	
	# NOTE: This is not needed when using NetworkEvents
	# However, this script also runs in multiplayer-simple where NetworkEvents
	# are assumed to be absent, hence starting NetworkTime manually
	NetworkTime.start()
	return OK

func join() -> int:
	var host_dict := _parse_input()
	if host_dict.size() == 0:
		return ERR_CANT_RESOLVE
		
	var address : String = host_dict.address
	var port : int = host_dict.port

	# Connect
	print("Connecting to %s:%s" % [address, port])
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		OS.alert("Failed to create client, reason: %s" % error_string(err))
		return err

	get_tree().get_multiplayer().multiplayer_peer = peer
	
	# Wait for connection process to conclude
	await Async.condition(
		func() -> bool:
			return peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING
	)

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		OS.alert("Failed to connect to %s:%s" % [address, port])
		return ERR_CONNECTION_ERROR

	print("Client started")
	connect_ui.hide()
	
	# NOTE: This is not needed when using NetworkEvents
	# However, this script also runs in multiplayer-simple where NetworkEvents
	# are assumed to be absent, hence starting NetworkTime manually
	NetworkTime.start()
	return OK

func _parse_input() -> Dictionary:
	# Validate inputs
	var address := address_input.text
	var port_text := port_input.text
	
	if address == "":
		OS.alert("No host specified!")
		return {}
		
	if not port_text.is_valid_int():
		OS.alert("Invalid port!")
		return {}
	var port := port_text.to_int()

	return {
		"address": address,
		"port": port
	}
