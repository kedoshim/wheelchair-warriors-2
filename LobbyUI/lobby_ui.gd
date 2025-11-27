extends Control

var username: String = ""

@onready var http := $CreateRoomRequest

func _ready():
	var url = "http://localhost:3000/rooms/create"
	var data = {
		"nome": "Gustavo",
		"score": 100
	}

	var headers = ["Content-Type: application/json"]
	var json_data = JSON.stringify(data)

	http.request(url, headers, HTTPClient.METHOD_POST, json_data)
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
	pass # Replace with function body.
