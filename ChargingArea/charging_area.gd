extends Area3D

func _ready() -> void:
	body_exited.connect(_body_exited)
	body_entered.connect(_body_entered)
	
func _body_exited(body: Node3D) -> void:
	print("body exited. body is: " + body.name)
	if body.is_in_group("player"):
		body.is_charging = false
		print(body.name + " is no longer charging")
		

func _body_entered(body: Node3D) -> void:
	print("body entered. body is: " + body.name)
	if body.is_in_group("player"):
		body.is_charging = true
		print(body.name + " is charging")
