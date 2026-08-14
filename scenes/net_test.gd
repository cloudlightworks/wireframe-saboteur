extends Node

func _ready() -> void:
	print("NetTest ready. Press H to Host, J to Join, C to chat.")
	NetworkManager.player_connected.connect(func(id): print("net_test saw player_connected: ", id))
	NetworkManager.connected_to_host.connect(func(): print("net_test saw connected_to_host"))
	ChatManager.message_received.connect(func(side, text, seq):
		print("CHAT [", side, "] #", seq, ": ", text))
	ChatManager.chat_rejected.connect(func(reason): print("CHAT REJECTED: ", reason))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H:
			NetworkManager.host_game()
		elif event.keycode == KEY_J:
			NetworkManager.join_game("127.0.0.1")
		elif event.keycode == KEY_C:
			ChatManager.send_message("hello from peer %d" % NetworkManager.my_id())
