extends Control

var username: String = ""

@onready var http := $CreateRoomRequest

func _ready():
	
	http.request_completed.connect(_on_request_completed)

func _on_request_completed(result, response_code, headers, body):
	print("Server respondeu:", response_code)
	print(body.get_string_from_utf8())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_line_edit_text_changed(new_text: String) -> void:
	username = new_text


func create_room() -> void:
	var url = "http://localhost:3000/rooms/create"

	var headers = ["Content-Type: application/json"]
	var json_data = JSON.new().stringify({
		"username": username,
	})

	http.request(url, headers, HTTPClient.METHOD_POST, json_data)
